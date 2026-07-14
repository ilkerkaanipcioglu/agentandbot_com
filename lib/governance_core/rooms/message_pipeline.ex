defmodule GovernanceCore.Rooms.MessagePipeline do
  @moduledoc """
  Broadway pipeline that processes raw agent messages, generates summaries,
  updates the database, and broadcasts them to the human topic.
  """
  use Broadway

  alias Broadway.Message
  alias GovernanceCore.Repo

  def start_link(_opts) do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module: {GovernanceCore.Rooms.RoomProducer, []},
        concurrency: 1
      ],
      processors: [
        default: [concurrency: 2, max_demand: 10]
      ],
      batchers: [
        human_summary: [concurrency: 1, batch_size: 5, batch_timeout: 500]
      ]
    )
  end

  @impl true
  def handle_message(_processor, %Message{data: room_msg} = msg, _context) do
    summary = summarize(room_msg.payload)

    # Save summary to DB
    {:ok, updated_msg} =
      room_msg
      |> Ecto.Changeset.change(%{summary: summary})
      |> Repo.update()

    # Async LLM enhancement if enabled
    if llm_summarize_enabled?() do
      spawn(fn ->
        llm_summary = GovernanceCore.LLM.Bridge.summarize(summary)

        case llm_summary do
          {:ok, enhanced} ->
            updated_msg
            |> Ecto.Changeset.change(%{summary: enhanced})
            |> Repo.update()

          _ ->
            :ok
        end
      end)
    end

    # Process dynamic room task if applicable
    if room_msg.from_type == "agent" do
      GovernanceCore.Rooms.process_task_from_mcp(room_msg.room_id, room_msg.payload)
    end

    # Log tracing event in agent_events
    if room_msg.from_type == "agent" do
      meta = Map.get(room_msg.payload, "meta", %{})
      trace_id = Map.get(meta, "trace_id") || Map.get(meta, :trace_id) || Ecto.UUID.generate()
      span_id = Map.get(meta, "span_id") || Map.get(meta, :span_id) || Ecto.UUID.generate()
      parent_span_id = Map.get(meta, "parent_span_id") || Map.get(meta, :parent_span_id)

       event_type = GovernanceCore.Rooms.EventTaxonomy.classify(room_msg.payload)

      # Calculate duration if it's a completed/failed tool call
      duration =
        if event_type in ["tool_call_completed", "tool_call_failed"] and parent_span_id do
          import Ecto.Query

          query =
            from(e in GovernanceCore.Rooms.AgentEvent,
              where:
                e.room_id == ^room_msg.room_id and e.span_id == ^parent_span_id and
                  e.event_type == "tool_call_started",
              select: e.inserted_at,
              limit: 1
            )

          case Repo.one(query) do
            nil ->
              nil

            inserted_at ->
              DateTime.diff(DateTime.utc_now(), inserted_at, :millisecond)
          end
        end

      # Record using Tracing module
      GovernanceCore.Tracing.record_span(%{
        room_id: room_msg.room_id,
        agent_id: if(room_msg.from_type == "human", do: nil, else: room_msg.from_id),
        trace_id: trace_id,
        span_id: span_id,
        parent_span_id: parent_span_id,
        event_type: event_type,
        payload: room_msg.payload,
        duration_ms: duration
      })
    end

    # Pass the updated message to batcher
    msg
    |> Message.update_data(fn _ -> updated_msg end)
    |> Message.put_batcher(:human_summary)
  end

  @impl true
  def handle_batch(:human_summary, messages, _batch_info, _context) do
    # Group messages by room_id and broadcast
    messages
    |> Enum.map(& &1.data)
    |> Enum.group_by(& &1.room_id)
    |> Enum.each(fn {room_id, room_messages} ->
      Phoenix.PubSub.broadcast(
        GovernanceCore.PubSub,
        "human:room:#{room_id}",
        {:summaries, room_messages}
      )
    end)

    messages
  end

  # High-fidelity MCP / JSON-RPC parser and summarizer
  defp summarize(payload) when is_map(payload) do
    cond do
      method = Map.get(payload, "method") ->
        case method do
          "initialize" ->
            "Initializing connection with client credentials..."

          "tools/list" ->
            "Requesting list of available tools..."

          "tools/call" ->
            tool_name = get_in(payload, ["params", "name"]) || "unknown"
            args = get_in(payload, ["params", "arguments"])
            "Calling tool: `#{tool_name}` with arguments: #{inspect(args)}"

          "task/launch" ->
            task_title = get_in(payload, ["params", "title"]) || "unknown"
            "Launching autonomous task: '#{task_title}'"

          "task/complete" ->
            result_val = get_in(payload, ["params", "result"]) || %{}

            output =
              Map.get(result_val, "output") || Map.get(result_val, "content") ||
                inspect(result_val)

            "Ajan görevi başarıyla tamamladı. Çıktı: #{output}"

          "task/fail" ->
            error_val = get_in(payload, ["params", "error"]) || "Bilinmeyen hata"
            "Ajan görevi tamamlayamadı (Başarısız). Hata: #{inspect(error_val)}"

          "delegated_task" ->
            to_agent_id = get_in(payload, ["params", "to_agent_id"]) || "unknown"
            task_desc = get_in(payload, ["params", "task"]) || "görev"

            to_agent_name =
              case GovernanceCore.Agents.get_agent(to_agent_id) do
                nil -> to_agent_id
                persona -> persona.name
              end

            "Orkestrasör ajan, '#{task_desc}' görevini #{to_agent_name} isimli ajana delege etti."

          other ->
            "Executing action: `#{other}`"
        end

      result = Map.get(payload, "result") ->
        cond do
          tools = Map.get(result, "tools") ->
            names = Enum.map(tools, &Map.get(&1, "name"))
            "Found available tools: #{Enum.join(names, ", ")}"

          content = Map.get(result, "content") ->
            text = Enum.map(content, &Map.get(&1, "text")) |> Enum.join(" ")
            "Result: #{String.slice(text, 0, 150)}..."

          true ->
            "Action finished. Result: #{String.slice(inspect(result), 0, 150)}..."
        end

      error = Map.get(payload, "error") ->
        message = Map.get(error, "message") || "Unknown error"
        "Error encountered: #{message}"

      text = Map.get(payload, "text") ->
        text

      true ->
        "Raw payload: #{inspect(payload)}"
    end
  end

  defp summarize(_), do: "Empty or invalid message packet."

  defp llm_summarize_enabled? do
    Application.get_env(:governance_core, :llm, [])
    |> Keyword.get(:summarize_with_llm, false)
  end
end
