defmodule GovernanceCoreWeb.AgentRoomChannel do
  @moduledoc """
  Phoenix Channel for external agent room communication.

  External agents (Hermes, Claude, GPT, custom runtimes) connect to
  this channel to participate in AgentAndBot rooms via WebSocket.

  ## Join

  Topic: "agent_room:{room_id}"
  Payload: %{"agent_id" => "xxx", "token" => "optional_token"}

  ## Events (client → server)

  - "mcp_message"  %{"payload" => {...}}  — Send MCP message to room
  - "ping"        %{}                      — Heartbeat

  ## Pushes (server → client)

  - "mcp_packet"           %{"message" => msg}    — Other agent MCP messages
  - "human_message"        %{"message" => msg}    — Human messages
  - "approval_needed"     %{"request" => req}     — Approval request from agent
  - "approval_resolved"   %{"id" => id, "decision" => decision} — Approval resolved
  - "room_status_changed"  %{"status" => status}   — Room paused/resumed
  - "agent_joined"         %{"agent" => agent}      — Another agent joined
  - "agent_left"           %{"agent_id" => id}       — Agent left room
  - "room_stats"           %{"stats" => stats}       — Room statistics
  """

  use Phoenix.Channel

  alias GovernanceCore.Agents.AgentGateway

  @impl true
  def join("agent_room:" <> room_id, params, socket) do
    agent_id = Map.get(params, "agent_id")
    token = Map.get(params, "token")

    if is_nil(agent_id) or agent_id == "" do
      {:error, %{reason: "agent_id required"}}
    else
      case AgentGateway.authenticate(agent_id, token) do
        {:ok, agent} ->
          case AgentGateway.join_room(room_id, agent) do
            :ok ->
              socket =
                socket
                |> assign(:room_id, room_id)
                |> assign(:agent_id, agent_id)
                |> assign(:agent, agent)

              send(self(), {:after_join, room_id, agent_id})

              {:ok, socket}

            {:error, :room_not_found} ->
              {:error, %{reason: "room not found"}}
          end

        {:error, reason} ->
          {:error, %{reason: to_string(reason)}}
      end
    end
  end

  @impl true
  def handle_in("mcp_message", %{"payload" => payload}, socket) do
    room_id = socket.assigns.room_id
    agent_id = socket.assigns.agent_id

    payload =
      payload
      |> Map.put("agent_id", agent_id)
      |> maybe_add_trace_meta(socket)

    AgentGateway.send_mcp(room_id, payload)

    {:noreply, socket}
  end

  @impl true
  def handle_in("ping", _payload, socket) do
    {:reply, :ok, socket}
  end

  @impl true
  def handle_info({:after_join, room_id, agent_id}, socket) do
    push(socket, "joined", %{
      room_id: room_id,
      agent_id: agent_id,
      status: "connected"
    })

    Phoenix.PubSub.subscribe(GovernanceCore.PubSub, "agent:room:#{room_id}")
    Phoenix.PubSub.subscribe(GovernanceCore.PubSub, "human:room:#{room_id}")

    {:noreply, socket}
  end

  @impl true
  def handle_info({:mcp_packet, message}, socket) do
    if message.from_id != socket.assigns.agent_id do
      push(socket, "mcp_packet", %{message: message})
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:human_message, message}, socket) do
    push(socket, "human_message", %{message: message})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:summaries, messages}, socket) do
    push(socket, "summaries", %{messages: messages})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:approval_needed, req}, socket) do
    push(socket, "approval_needed", %{request: req})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:approval_resolved, approval_id, decision}, socket) do
    push(socket, "approval_resolved", %{id: approval_id, decision: decision})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:room_status_changed, status}, socket) do
    push(socket, "room_status_changed", %{status: status})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:agent_joined, agent}, socket) do
    push(socket, "agent_joined", %{agent: agent})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:agent_left, agent_id}, socket) do
    push(socket, "agent_left", %{agent_id: agent_id})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:room_stats_updated, stats}, socket) do
    push(socket, "room_stats", %{stats: stats})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:room_task_created, task}, socket) do
    push(socket, "task_created", %{task: task})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:room_task_updated, task}, socket) do
    push(socket, "task_updated", %{task: task})
    {:noreply, socket}
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  @impl true
  def terminate(_reason, socket) do
    room_id = socket.assigns.room_id
    agent_id = socket.assigns.agent_id

    Phoenix.PubSub.unsubscribe(GovernanceCore.PubSub, "agent:room:#{room_id}")
    Phoenix.PubSub.unsubscribe(GovernanceCore.PubSub, "human:room:#{room_id}")

    AgentGateway.leave_room(room_id, agent_id)
  end

  defp maybe_add_trace_meta(payload, _socket) do
    if Map.has_key?(payload, "meta") do
      payload
    else
      Map.put(payload, "meta", %{
        "trace_id" => Ecto.UUID.generate(),
        "span_id" => Ecto.UUID.generate(),
        "source" => "websocket_channel"
      })
    end
  end
end
