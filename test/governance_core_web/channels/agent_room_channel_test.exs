defmodule GovernanceCoreWeb.AgentRoomChannelTest do
  use GovernanceCoreWeb.ChannelCase, async: false

  alias GovernanceCore.Rooms
  alias GovernanceCore.Agents

  setup do
    {:ok, room} = Rooms.create_room(%{name: "channel-test-room", status: "active"})
    {:ok, agent} = Agents.create_agent(%{
      name: "Channel Agent",
      role: "worker",
      status: "active"
    })

    {:ok, room: room, agent: agent}
  end

  describe "join" do
    test "rejects join without agent_id" do
      {:error, %{reason: "agent_id required"}} =
        socket(GovernanceCoreWeb.AgentSocket, "", %{})
        |> subscribe_and_join(GovernanceCoreWeb.AgentRoomChannel, "agent_room:nonexistent")
    end

    test "rejects join with nonexistent agent", %{room: room} do
      {:error, %{reason: reason}} =
        socket(GovernanceCoreWeb.AgentSocket, "", %{})
        |> subscribe_and_join(GovernanceCoreWeb.AgentRoomChannel, "agent_room:#{room.id}", %{"agent_id" => "ghost-id"})

      assert reason in ["agent not found", "not_found"]
    end

    test "joins with valid agent_id when room server exists", %{room: room, agent: agent} do
      ensure_room_server(room)

      {:ok, _reply, socket} =
        socket(GovernanceCoreWeb.AgentSocket, "", %{})
        |> subscribe_and_join(GovernanceCoreWeb.AgentRoomChannel, "agent_room:#{room.id}", %{"agent_id" => agent.id})

      assert socket.assigns.room_id == room.id
      assert socket.assigns.agent_id == agent.id
    end
  end

  describe "mcp_message" do
    test "sends MCP message via gateway", %{room: room, agent: agent} do
      ensure_room_server(room)

      {:ok, _, socket} =
        socket(GovernanceCoreWeb.AgentSocket, "", %{})
        |> subscribe_and_join(GovernanceCoreWeb.AgentRoomChannel, "agent_room:#{room.id}", %{"agent_id" => agent.id})

      push(socket, "mcp_message", %{"payload" => %{"method" => "ping"}})

      assert_receive %Phoenix.Socket.Message{event: "room_stats"}
    end
  end

  describe "ping" do
    test "responds to ping", %{room: room, agent: agent} do
      ensure_room_server(room)

      {:ok, _, socket} =
        socket(GovernanceCoreWeb.AgentSocket, "", %{})
        |> subscribe_and_join(GovernanceCoreWeb.AgentRoomChannel, "agent_room:#{room.id}", %{"agent_id" => agent.id})

      ref = push(socket, "ping", %{})
      assert_reply ref, :ok, %{}
    end
  end

  defp ensure_room_server(room) do
    case Registry.lookup(GovernanceCore.Rooms.RoomRegistry, room.id) do
      [{_pid, _}] ->
        :ok

      [] ->
        room = Rooms.get_room!(room.id)

        case Process.whereis(GovernanceCore.Rooms.RoomSupervisor) do
          pid when is_pid(pid) ->
            {:ok, _} =
              DynamicSupervisor.start_child(pid,
                {GovernanceCore.Rooms.RoomServer, %{room_id: room.id, owner_id: room.owner_id}}
              )

          nil ->
            :ok
        end

        :ok
    end
  end
end
