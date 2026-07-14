defmodule GovernanceCore.Agents.AgentGateway do
  @moduledoc """
  External agent access layer for AgentAndBot rooms.

  Provides a unified API for WebSocket channels and HTTP controllers to
  authenticate agents, join/leave rooms, and send MCP messages.

  All operations go through RoomServer, ensuring the existing Broadway
  pipeline, tracing, and dual PubSub model work seamlessly.
  """

  alias GovernanceCore.Agents
  alias GovernanceCore.Rooms
  alias GovernanceCore.Rooms.RoomServer
  alias GovernanceCore.Rooms.RoomSupervisor

  @type auth_result :: {:ok, map()} | {:error, :not_found | :invalid_token}

  @doc """
  Authenticates an agent by ID and optional token.

  In v1, authentication is permissive: any valid agent_id is accepted.
  Token validation is a future enhancement (Phase 2 - Ed25519).
  """
  @spec authenticate(String.t(), String.t() | nil) :: auth_result()
  def authenticate(agent_id, _token \\ nil) do
    case Agents.get_agent(agent_id) do
      nil -> {:error, :not_found}
      agent -> {:ok, agent}
    end
  end

  @doc """
  Joins an authenticated agent to a room.

  Returns :ok if the room exists and the agent was successfully added.
  """
  @spec join_room(String.t(), map()) :: :ok | {:error, :room_not_found}
  def join_room(room_id, agent) do
    case Rooms.get_room(room_id) do
      nil ->
        {:error, :room_not_found}

      _room ->
        ensure_room_server(room_id)
        RoomServer.join_agent(room_id, agent)
        :ok
    end
  end

  @doc """
  Sends an MCP message to a room on behalf of an agent.

  The message flows through RoomServer → dual PubSub → Broadway pipeline.
  """
  @spec send_mcp(String.t(), map()) :: :ok
  def send_mcp(room_id, payload) do
    RoomServer.send_mcp_message(room_id, payload)
  end

  @doc """
  Sends a human message to a room.
  """
  @spec send_human_message(String.t(), String.t(), String.t()) :: :ok
  def send_human_message(room_id, text, user_id) do
    {:ok, message} =
      Rooms.create_message(%{
        room_id: room_id,
        from_type: "human",
        from_id: user_id,
        channel: "human_channel",
        summary: text,
        payload: %{"text" => text}
      })

    Phoenix.PubSub.broadcast(
      GovernanceCore.PubSub,
      "human:room:#{room_id}",
      {:human_message, message}
    )

    Phoenix.PubSub.broadcast(
      GovernanceCore.PubSub,
      "agent:room:#{room_id}",
      {:human_message, message}
    )

    :ok
  end

  @doc """
  Removes an agent from a room.
  """
  @spec leave_room(String.t(), String.t()) :: :ok
  def leave_room(room_id, agent_id) do
    RoomServer.leave_agent(room_id, agent_id)
  end

  @doc """
  Lists all agents currently in a room.
  """
  @spec list_room_agents(String.t()) :: [map()]
  def list_room_agents(room_id) do
    case Registry.lookup(GovernanceCore.Rooms.RoomRegistry, room_id) do
      [{_pid, _}] ->
        state = RoomServer.get_state(room_id)
        Map.values(state.agents)

      _ ->
        []
    end
  end

  @doc """
  Gets the current state of a room.
  """
  @spec get_room_state(String.t()) :: map() | nil
  def get_room_state(room_id) do
    case Registry.lookup(GovernanceCore.Rooms.RoomRegistry, room_id) do
      [{_pid, _}] -> RoomServer.get_state(room_id)
      _ -> nil
    end
  end

  @doc """
  Pauses a room (stops agent message processing).
  """
  @spec pause_room(String.t()) :: :ok
  def pause_room(room_id) do
    RoomServer.pause(room_id)
  end

  @doc """
  Resumes a paused room.
  """
  @spec resume_room(String.t()) :: :ok
  def resume_room(room_id) do
    RoomServer.resume(room_id)
  end

  @doc """
  Requests human approval from an agent.
  """
  @spec request_approval(String.t(), map()) :: :ok
  def request_approval(room_id, attrs) do
    RoomServer.request_approval(room_id, attrs)
  end

  defp ensure_room_server(room_id) do
    case Registry.lookup(GovernanceCore.Rooms.RoomRegistry, room_id) do
      [] ->
        room = Rooms.get_room!(room_id)
        RoomSupervisor.start_room(%{room_id: room.id, owner_id: room.owner_id})

      _ ->
        :ok
    end
  end
end
