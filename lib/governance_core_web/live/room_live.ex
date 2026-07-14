defmodule GovernanceCoreWeb.RoomLive do
  @moduledoc """
  Discord-style premium web interface for Agent Rooms.
  """
  use GovernanceCoreWeb, :live_view

  alias GovernanceCore.Rooms
  alias GovernanceCore.Rooms.EventTaxonomy
  alias GovernanceCore.Rooms.RoomSupervisor
  alias GovernanceCore.Rooms.RoomServer
  alias GovernanceCore.Agents

  @impl true
  def mount(_params, _session, socket) do
    rooms = Rooms.list_rooms()
    agents = Agents.list_agents()

    # Seed a default room if none exists so user doesn't see a blank page
    rooms =
      if Enum.empty?(rooms) do
        {:ok, default_room} = Rooms.create_room(%{name: "general-swarm", status: "active"})
        [default_room]
      else
        rooms
      end

    {:ok,
     socket
     |> assign(:rooms, rooms)
     |> assign(:agents, agents)
     |> assign(:active_room, nil)
     |> assign(:room_status, :active)
     # :summary | :raw | :events
     |> assign(:view_mode, :summary)
     |> assign(:pending_approvals, [])
     |> assign(:room_agents, [])
     |> assign(:room_stats, %{
       packets_processed: 0,
       compression_ratio: "95%",
       avg_latency: "280ms",
       last_event: "CONNECTED"
     })
     |> assign(:page_title, "Agent Rooms")
     |> assign(:current_path, "/rooms")
     |> assign(:event_filters, %{agent_id: nil, event_type: nil, trace_id: nil})
     |> assign(:event_search, "")
     |> assign(:room_tasks, [])
     |> stream(:messages, [])
     |> stream(:agent_events, [])}
  end

  @impl true
  def handle_params(params, _url, socket) do
    case Map.get(params, "id") do
      nil ->
        # Redirect to the first room if available
        case socket.assigns.rooms do
          [first_room | _] ->
            {:noreply, push_patch(socket, to: ~p"/rooms/#{first_room.id}")}

          _ ->
            {:noreply, socket}
        end

      room_id ->
        room = Rooms.get_room!(room_id)

        # Unsubscribe from previous room if exists
        if socket.assigns.active_room do
          Phoenix.PubSub.unsubscribe(
            GovernanceCore.PubSub,
            "human:room:#{socket.assigns.active_room.id}"
          )
        end

        # Ensure RoomServer GenServer is running
        ensure_room_server_started(room)

        # Subscribe to human speed PubSub
        Phoenix.PubSub.subscribe(GovernanceCore.PubSub, "human:room:#{room.id}")

        # Fetch room messages and active approvals
        messages = Rooms.list_messages_for_room(room.id)
        approvals = Rooms.list_pending_approvals_for_room(room.id)

        # Fetch active room state from GenServer
        server_state = RoomServer.get_state(room.id)

        {:noreply,
         socket
         |> assign(:active_room, room)
         |> assign(:room_status, server_state.status)
         |> assign(:pending_approvals, approvals)
         |> assign(:room_agents, Map.values(server_state.agents))
         |> assign(
           :room_stats,
           Map.get(server_state, :stats, %{
             packets_processed: 0,
             compression_ratio: "95%",
             avg_latency: "280ms",
             last_event: "CONNECTED"
           })
         )
         |> assign(:event_filters, %{agent_id: nil, event_type: nil, trace_id: nil})
         |> assign(:event_search, "")
         |> assign(:room_tasks, Rooms.list_room_tasks(room.id))
         |> stream(:messages, messages, reset: true)
         |> refresh_events_stream()}
    end
  end

  # --- Handle PubSub Broadcasts ---

  @impl true
  def handle_info({:summaries, messages}, socket) do
    # Broadway produced summaries and batched them
    socket =
      Enum.reduce(messages, socket, fn msg, acc ->
        stream_insert(acc, :messages, msg)
      end)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:human_message, msg}, socket) do
    {:noreply, stream_insert(socket, :messages, msg)}
  end

  @impl true
  def handle_info({:agent_joined, agent}, socket) do
    updated_agents = [agent | socket.assigns.room_agents] |> Enum.uniq_by(& &1.id)
    {:noreply, assign(socket, :room_agents, updated_agents)}
  end

  @impl true
  def handle_info({:agent_left, agent_id}, socket) do
    updated_agents = Enum.reject(socket.assigns.room_agents, &(&1.id == agent_id))
    {:noreply, assign(socket, :room_agents, updated_agents)}
  end

  @impl true
  def handle_info({:room_status_changed, status}, socket) do
    {:noreply, assign(socket, :room_status, status)}
  end

  @impl true
  def handle_info({:room_stats_updated, stats}, socket) do
    {:noreply, assign(socket, :room_stats, stats)}
  end

  @impl true
  def handle_info({:approval_needed, req}, socket) do
    updated_approvals = [req | socket.assigns.pending_approvals] |> Enum.uniq_by(& &1.id)

    {:noreply,
     socket
     |> assign(:pending_approvals, updated_approvals)
     |> assign(:room_status, :awaiting_approval)}
  end

  @impl true
  def handle_info({:approval_resolved, approval_id, _decision}, socket) do
    remaining_approvals = Enum.reject(socket.assigns.pending_approvals, &(&1.id == approval_id))
    next_status = if Enum.empty?(remaining_approvals), do: :active, else: :awaiting_approval

    {:noreply,
     socket
     |> assign(:pending_approvals, remaining_approvals)
     |> assign(:room_status, next_status)}
  end

  @impl true
  def handle_info({:agent_event_logged, event}, socket) do
    filters = socket.assigns.event_filters
    search = socket.assigns.event_search

    if event_matches_filters?(event, filters, search) do
      {:noreply, stream_insert(socket, :agent_events, event, at: 0)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:room_task_created, task}, socket) do
    if socket.assigns.active_room && task.room_id == socket.assigns.active_room.id do
      updated_tasks =
        if Enum.any?(socket.assigns.room_tasks, &(&1.id == task.id)) do
          socket.assigns.room_tasks
        else
          socket.assigns.room_tasks ++ [task]
        end

      {:noreply, assign(socket, :room_tasks, updated_tasks)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:room_task_updated, task}, socket) do
    if socket.assigns.active_room && task.room_id == socket.assigns.active_room.id do
      updated_tasks =
        if Enum.any?(socket.assigns.room_tasks, &(&1.id == task.id)) do
          Enum.map(socket.assigns.room_tasks, fn t ->
            if t.id == task.id, do: task, else: t
          end)
        else
          socket.assigns.room_tasks ++ [task]
        end

      {:noreply, assign(socket, :room_tasks, updated_tasks)}
    else
      {:noreply, socket}
    end
  end

  # --- Handle UI Events ---

  def handle_event("send_message", %{"message" => %{"text" => text}}, socket) do
    if String.trim(text) != "" do
      {:ok, message} =
        Rooms.create_message(%{
          room_id: socket.assigns.active_room.id,
          from_type: "human",
          from_id: "local_user",
          channel: "human_channel",
          summary: text,
          payload: %{"text" => text}
        })

      # Broadcast to human speed PubSub (for UI)
      Phoenix.PubSub.broadcast(
        GovernanceCore.PubSub,
        "human:room:#{socket.assigns.active_room.id}",
        {:human_message, message}
      )

      # Broadcast to raw agent PubSub (for agents)
      Phoenix.PubSub.broadcast(
        GovernanceCore.PubSub,
        "agent:room:#{socket.assigns.active_room.id}",
        {:human_message, message}
      )

      # Record stats event
      RoomServer.record_stats_event(socket.assigns.active_room.id, "HUMAN COMMAND")
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("pause", _, socket) do
    RoomServer.pause(socket.assigns.active_room.id)
    {:noreply, socket}
  end

  @impl true
  def handle_event("resume", _, socket) do
    RoomServer.resume(socket.assigns.active_room.id)
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_mode", %{"mode" => mode}, socket) do
    view_mode =
      case mode do
        "raw" -> :raw
        "events" -> :events
        "tasks" -> :tasks
        _ -> :summary
      end

    socket =
      socket
      |> assign(:view_mode, view_mode)
      |> case do
        %{assigns: %{view_mode: :events}} = s ->
          refresh_events_stream(s)

        %{assigns: %{view_mode: :tasks}} = s ->
          assign(s, :room_tasks, Rooms.list_room_tasks(s.assigns.active_room.id))

        s ->
          refresh_messages_stream(s)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("create_room", %{"room" => %{"name" => name}}, socket) do
    case Rooms.create_room(%{name: name, status: "active"}) do
      {:ok, room} ->
        # Start RoomServer
        ensure_room_server_started(room)
        # Update list and redirect
        {:noreply,
         socket
         |> assign(:rooms, Rooms.list_rooms())
         |> push_patch(to: ~p"/rooms/#{room.id}")}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, "Oda oluşturulamadı: #{inspect(changeset.errors)}")}
    end
  end

  @impl true
  def handle_event("run_autonomous_demo", _, socket) do
    case socket.assigns.room_agents do
      [first_agent | _] ->
        GovernanceCore.Rooms.DemoAgentSwarm.start_demo(
          socket.assigns.active_room.id,
          first_agent.id
        )

        {:noreply, socket}

      _ ->
        {:noreply, put_flash(socket, :error, "Önce odaya en az bir ajan davet etmelisiniz!")}
    end
  end

  @impl true
  def handle_event("join_agent", %{"agent_id" => agent_id}, socket) do
    agent = Agents.get_agent!(agent_id)
    RoomServer.join_agent(socket.assigns.active_room.id, agent)
    {:noreply, socket}
  end

  @impl true
  def handle_event("leave_agent", %{"agent_id" => agent_id}, socket) do
    RoomServer.leave_agent(socket.assigns.active_room.id, agent_id)
    {:noreply, socket}
  end

  @impl true
  def handle_event("resolve_approval", %{"id" => approval_id, "decision" => decision_str}, socket) do
    decision = if decision_str == "approved", do: :approved, else: :rejected

    RoomServer.resolve_approval(
      socket.assigns.active_room.id,
      approval_id,
      decision,
      "local_user"
    )

    {:noreply, socket}
  end

  # Dynamic injection tool for testing/simulation
  @impl true
  def handle_event("inject_agent_mcp", %{"agent_id" => agent_id, "type" => type}, socket) do
    agent = Agents.get_agent!(agent_id)

    payload =
      case type do
        "init" ->
          %{
            "method" => "initialize",
            "agent_id" => agent.id,
            "params" => %{"capabilities" => ["read", "write"]}
          }

        "tool_call" ->
          %{
            "method" => "tools/call",
            "agent_id" => agent.id,
            "params" => %{
              "name" => "search_web",
              "arguments" => %{"query" => "Harezm A.Ş. Elixir development"}
            }
          }

        "result" ->
          %{
            "result" => %{
              "content" => [%{"text" => "Found 3 active projects matching your request."}]
            },
            "agent_id" => agent.id
          }

        "delegate" ->
          # Find last task to use as parent if present
          parent_task_id =
            case socket.assigns.room_tasks do
              [] -> nil
              tasks -> List.last(tasks).id
            end

          task_id = Ecto.UUID.generate()

          to_agent =
            Enum.reject(socket.assigns.room_agents, &(&1.id == agent.id)) |> List.first() || agent

          %{
            "method" => "delegated_task",
            "agent_id" => agent.id,
            "params" => %{
              "task_id" => task_id,
              "parent_task_id" => parent_task_id,
              "to_agent_id" => to_agent.id,
              "task" =>
                "Yapay zeka modülü test entegrasyonu (Task ID: #{String.slice(task_id, 0, 6)})"
            }
          }

        "task_complete" ->
          case Enum.filter(socket.assigns.room_tasks, &(&1.status == "running")) |> List.last() do
            nil ->
              nil

            task ->
              %{
                "method" => "task/complete",
                "agent_id" => agent.id,
                "params" => %{
                  "task_id" => task.id,
                  "result" => %{
                    "output" => "Modül testleri başarıyla tamamlandı. 12 senaryo yeşil."
                  }
                }
              }
          end

        "task_fail" ->
          case Enum.filter(socket.assigns.room_tasks, &(&1.status == "running")) |> List.last() do
            nil ->
              nil

            task ->
              %{
                "method" => "task/fail",
                "agent_id" => agent.id,
                "params" => %{
                  "task_id" => task.id,
                  "error" => "Ecto.ConstraintError: foreign key violation in database."
                }
              }
          end

        "approval" ->
          # Send approval request to GenServer
          RoomServer.request_approval(socket.assigns.active_room.id, %{
            agent_id: agent.id,
            description:
              "Ajan '#{agent.name}' dizindeki tüm geçici dosyaları silmek istiyor. Onaylıyor musunuz?",
            options: ["Onayla", "Reddet"],
            context: %{"directory" => "/tmp/clean"}
          })

          nil
      end

    if payload do
      RoomServer.send_mcp_message(socket.assigns.active_room.id, payload)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_event_type", params, socket) do
    type = Map.get(params, "type") || Map.get(params, "value")
    type = if type in [nil, "", "all"], do: nil, else: type
    filters = Map.put(socket.assigns.event_filters, :event_type, type)
    {:noreply, socket |> assign(:event_filters, filters) |> refresh_events_stream()}
  end

  @impl true
  def handle_event("filter_agent", params, socket) do
    agent_id = Map.get(params, "agent_id") || Map.get(params, "value")
    agent_id = if agent_id in [nil, "", "all"], do: nil, else: agent_id
    filters = Map.put(socket.assigns.event_filters, :agent_id, agent_id)
    {:noreply, socket |> assign(:event_filters, filters) |> refresh_events_stream()}
  end

  @impl true
  def handle_event("filter_trace", params, socket) do
    trace_id = Map.get(params, "trace_id") || Map.get(params, "value")
    trace_id = if trace_id in [nil, "", "all"], do: nil, else: trace_id
    filters = Map.put(socket.assigns.event_filters, :trace_id, trace_id)
    {:noreply, socket |> assign(:event_filters, filters) |> refresh_events_stream()}
  end

  @impl true
  def handle_event("search_events", params, socket) do
    query =
      cond do
        is_map(params) ->
          Map.get(params, "value") || Map.get(params, "q") || Map.get(params, "search") ||
            get_in(params, ["filter", "search"]) || ""

        true ->
          ""
      end

    {:noreply, socket |> assign(:event_search, query) |> refresh_events_stream()}
  end

  @impl true
  def handle_event("clear_event_filters", _, socket) do
    {:noreply,
     socket
     |> assign(:event_filters, %{agent_id: nil, event_type: nil, trace_id: nil})
     |> assign(:event_search, "")
     |> refresh_events_stream()}
  end

  # --- Helper functions ---

  defp refresh_events_stream(socket) do
    room_id = socket.assigns.active_room.id
    filters = socket.assigns.event_filters
    search = socket.assigns.event_search

    any_filter_active? =
      filters.agent_id != nil or
        filters.event_type != nil or
        filters.trace_id != nil or
        String.trim(search) != ""

    events =
      if any_filter_active? do
        db_filters = Map.put(filters, :search, String.trim(search))

        Rooms.list_agent_events_for_room(room_id, db_filters)
        |> Enum.reverse()
      else
        GovernanceCore.EventCache.recent(room_id, 100)
      end

    stream(socket, :agent_events, events, reset: true)
  end

  defp event_matches_filters?(event, filters, search) do
    matches_agent? = is_nil(filters.agent_id) or event.agent_id == filters.agent_id
    matches_type? = is_nil(filters.event_type) or event.event_type == filters.event_type
    matches_trace? = is_nil(filters.trace_id) or event.trace_id == filters.trace_id

    matches_search? =
      if String.trim(search) == "" do
        true
      else
        search_lower = String.downcase(search)
        event_type_match = String.contains?(String.downcase(event.event_type || ""), search_lower)
        trace_id_match = String.contains?(String.downcase(event.trace_id || ""), search_lower)
        span_id_match = String.contains?(String.downcase(event.span_id || ""), search_lower)
        event_type_match or trace_id_match or span_id_match
      end

    matches_agent? and matches_type? and matches_trace? and matches_search?
  end

  defp ensure_room_server_started(room) do
    case Registry.lookup(GovernanceCore.Rooms.RoomRegistry, room.id) do
      [] ->
        case RoomSupervisor.start_room(%{room_id: room.id, owner_id: room.owner_id}) do
          {:ok, pid} ->
            if room.name == "general-swarm" do
              case Agents.list_agents() do
                [] ->
                  :ok

                agents ->
                  agents
                  |> Enum.take(2)
                  |> Enum.each(fn agent ->
                    RoomServer.join_agent(room.id, agent)
                  end)
              end
            end

            {:ok, pid}

          other ->
            other
        end

      _ ->
        # Already running
        :ok
    end
  end

  defp refresh_messages_stream(socket) do
    messages = Rooms.list_messages_for_room(socket.assigns.active_room.id)
    stream(socket, :messages, messages, reset: true)
  end

  def event_status_color("agent_connected"), do: {"rgba(34,197,94,0.12)", "#4ade80", "rgba(34,197,94,0.2)"}
  def event_status_color("agent_disconnected"), do: {"rgba(239,68,68,0.12)", "#f87171", "rgba(239,68,68,0.2)"}
  def event_status_color("agent_ready"), do: {"rgba(34,197,94,0.12)", "#4ade80", "rgba(34,197,94,0.2)"}
  def event_status_color("heartbeat"), do: {"rgba(16,185,129,0.12)", "#34d399", "rgba(16,185,129,0.2)"}
  def event_status_color("tool_call_started"), do: {"rgba(99,102,241,0.12)", "#818cf8", "rgba(99,102,241,0.2)"}
  def event_status_color("tool_call_completed"), do: {"rgba(34,197,94,0.12)", "#4ade80", "rgba(34,197,94,0.2)"}
  def event_status_color("tool_call_failed"), do: {"rgba(239,68,68,0.12)", "#f87171", "rgba(239,68,68,0.2)"}
  def event_status_color("approval_requested"), do: {"rgba(168,85,247,0.12)", "#c084fc", "rgba(168,85,247,0.2)"}
  def event_status_color("approval_granted"), do: {"rgba(34,197,94,0.12)", "#4ade80", "rgba(34,197,94,0.2)"}
  def event_status_color("approval_rejected"), do: {"rgba(239,68,68,0.12)", "#f87171", "rgba(239,68,68,0.2)"}
  def event_status_color("room_paused"), do: {"rgba(245,158,11,0.12)", "#f59e0b", "rgba(245,158,11,0.2)"}
  def event_status_color("room_resumed"), do: {"rgba(34,197,94,0.12)", "#4ade80", "rgba(34,197,94,0.2)"}
  def event_status_color("task_launched"), do: {"rgba(99,102,241,0.12)", "#818cf8", "rgba(99,102,241,0.2)"}
  def event_status_color("task_completed"), do: {"rgba(34,197,94,0.12)", "#4ade80", "rgba(34,197,94,0.2)"}
  def event_status_color("task_failed"), do: {"rgba(239,68,68,0.12)", "#f87171", "rgba(239,68,68,0.2)"}
  def event_status_color("task_delegated"), do: {"rgba(168,85,247,0.12)", "#c084fc", "rgba(168,85,247,0.2)"}
  def event_status_color(_), do: {"rgba(107,114,128,0.12)", "#9ca3af", "rgba(107,114,128,0.2)"}

  attr :tasks, :list, required: true
  attr :parent_id, :any, default: nil
  attr :depth, :integer, default: 0
  attr :agents, :list, required: true

  def task_tree(assigns) do
    node_tasks = Enum.filter(assigns.tasks, &(&1.parent_task_id == assigns.parent_id))
    assigns = assign(assigns, :node_tasks, node_tasks)

    ~H"""
    <div
      class="task-tree-level"
      style={"display: flex; flex-direction: column; gap: 14px; margin-left: #{if @depth > 0, do: 24, else: 0}px; border-left: #{if @depth > 0, do: "2px dashed #2d3748", else: "none"}; padding-left: #{if @depth > 0, do: 16, else: 0}px;"}
    >
      <%= for task <- @node_tasks do %>
        <div
          class="task-node"
          style="position: relative; background: #111318; border: 1px solid #252b36; border-radius: 12px; padding: 14px; transition: all 0.2s ease;"
        >
          <%!-- Connector point --%>
          <%= if @depth > 0 do %>
            <div style="position: absolute; left: -18px; top: 22px; width: 16px; height: 2px; background: #2d3748;">
            </div>
          <% end %>

          <%!-- Header --%>
          <div style="display: flex; align-items: center; justify-content: space-between; gap: 12px; margin-bottom: 8px;">
            <div style="display: flex; align-items: center; gap: 8px;">
              <%!-- Status Badge --%>
              <%= case task.status do %>
                <% "completed" -> %>
                  <span style="font-size: 10px; font-weight: 800; text-transform: uppercase; padding: 3px 8px; border-radius: 6px; background: rgba(34,197,94,0.12); color: #4ade80; border: 1px solid rgba(34,197,94,0.2);">
                    ✓ Tamamlandı
                  </span>
                <% "failed" -> %>
                  <span style="font-size: 10px; font-weight: 800; text-transform: uppercase; padding: 3px 8px; border-radius: 6px; background: rgba(239,68,68,0.12); color: #f87171; border: 1px solid rgba(239,68,68,0.2);">
                    ⚠ Başarısız
                  </span>
                <% "running" -> %>
                  <span style="font-size: 10px; font-weight: 800; text-transform: uppercase; padding: 3px 8px; border-radius: 6px; background: rgba(99,102,241,0.12); color: #818cf8; border: 1px solid rgba(99,102,241,0.2); animation: pulse 2s infinite;">
                    ⚡ Çalışıyor
                  </span>
                <% _ -> %>
                  <span style="font-size: 10px; font-weight: 800; text-transform: uppercase; padding: 3px 8px; border-radius: 6px; background: rgba(107,114,128,0.12); color: #9ca3af; border: 1px solid rgba(107,114,128,0.2);">
                    ⌛ Beklemede
                  </span>
              <% end %>
            </div>

            <%!-- Assigned Agent --%>
            <%= if task.assigned_agent_id do %>
              <div style="display: flex; align-items: center; gap: 6px; background: #161b22; padding: 3px 8px; border-radius: 20px; border: 1px solid #252b36;">
                <div style="width: 14px; height: 14px; border-radius: 50%; background: #4f46e5; color: white; display: flex; align-items: center; justify-content: center; font-size: 8px; font-weight: 800;">
                  <%= case Enum.find(@agents, &(&1.id == task.assigned_agent_id)) do %>
                    <% nil -> %>
                      ?
                    <% agent -> %>
                      {String.at(agent.name, 0) |> String.upcase()}
                  <% end %>
                </div>
                <span style="font-size: 10px; color: #a5b4fc; font-weight: 600;">
                  <%= case Enum.find(@agents, &(&1.id == task.assigned_agent_id)) do %>
                    <% nil -> %>
                      Ajan
                    <% agent -> %>
                      {agent.name}
                  <% end %>
                </span>
              </div>
            <% end %>
          </div>

          <%!-- Description --%>
          <div style="font-size: 13px; color: #f1f5f9; font-weight: 500; line-height: 1.4; margin-bottom: 6px;">
            {task.description}
          </div>

          <%!-- ID & Timestamp --%>
          <div style="font-size: 10px; font-family: monospace; color: #4b5563; display: flex; justify-content: space-between; align-items: center;">
            <span>ID: {String.slice(task.id, 0, 8)}</span>
            <span>{Calendar.strftime(task.inserted_at || DateTime.utc_now(), "%H:%M:%S")}</span>
          </div>

          <%!-- Details / Result --%>
          <%= if task.result && map_size(task.result) > 0 do %>
            <details style="margin-top: 8px; border-top: 1px dashed #252b36; padding-top: 8px;">
              <summary style="font-size: 10px; font-weight: 700; color: #6b7280; cursor: pointer; user-select: none; outline: none;">
                Çıktı Detaylarını Göster
              </summary>
              <pre style="margin-top: 6px; background: #0d1117; border: 1px solid #252b36; border-radius: 6px; padding: 8px; font-size: 10px; font-family: monospace; color: #a5b4fc; overflow-x: auto; white-space: pre-wrap; margin: 0;"><%= Jason.encode!(task.result, pretty: true) %></pre>
            </details>
          <% end %>
        </div>

        <%!-- Render subtasks recursively --%>
        <.task_tree tasks={@tasks} parent_id={task.id} depth={@depth + 1} agents={@agents} />
      <% end %>
    </div>
    """
  end
end
