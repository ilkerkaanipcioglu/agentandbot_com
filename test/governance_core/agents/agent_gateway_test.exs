defmodule GovernanceCore.Agents.AgentGatewayTest do
  use GovernanceCore.DataCase, async: false

  alias GovernanceCore.Agents.AgentGateway
  alias GovernanceCore.Rooms
  alias GovernanceCore.Rooms.RoomServer

  describe "authenticate/2" do
    test "returns error for unknown agent_id" do
      assert {:error, :not_found} = AgentGateway.authenticate("nonexistent-id")
    end

    test "returns agent when agent exists" do
      {:ok, agent} = GovernanceCore.Agents.create_agent(%{
        name: "Test Agent",
        role: "tester",
        status: "active"
      })

      assert {:ok, found} = AgentGateway.authenticate(agent.id)
      assert found.id == agent.id
      assert found.name == "Test Agent"
    end

    test "accepts nil token (v1 permissive auth)" do
      {:ok, agent} = GovernanceCore.Agents.create_agent(%{
        name: "Tokenless Agent",
        role: "tester",
        status: "active"
      })

      assert {:ok, _} = AgentGateway.authenticate(agent.id, nil)
    end
  end

  describe "join_room/2" do
    setup do
      {:ok, room} = Rooms.create_room(%{name: "gateway-test-room", status: "active"})
      {:ok, agent} = GovernanceCore.Agents.create_agent(%{
        name: "Room Agent",
        role: "worker",
        status: "active"
      })

      start_room_server(room)

      {:ok, room: room, agent: agent}
    end

    test "joins agent to existing room", %{room: room, agent: agent} do
      assert :ok = AgentGateway.join_room(room.id, agent)
    end

    test "returns error for nonexistent room" do
      assert {:error, :room_not_found} = AgentGateway.join_room("fake-id", %{})
    end
  end

  describe "send_mcp/2" do
    setup do
      {:ok, room} = Rooms.create_room(%{name: "mcp-gateway-test", status: "active"})
      {:ok, agent} = GovernanceCore.Agents.create_agent(%{
        name: "MCP Agent",
        role: "worker",
        status: "active"
      })

      start_room_server(room)

      Phoenix.PubSub.subscribe(GovernanceCore.PubSub, "human:room:#{room.id}")

      {:ok, room: room, agent: agent}
    end

    test "broadcasts to human channel via Broadway pipeline", %{room: room, agent: agent} do
      AgentGateway.send_mcp(room.id, %{
        "method" => "tools/call",
        "agent_id" => agent.id,
        "params" => %{"name" => "test_tool"}
      })

      assert_receive {:summaries, [%GovernanceCore.Rooms.Message{} = msg]}, 5000
      assert msg.room_id == room.id
      assert msg.from_id == agent.id
      assert msg.summary =~ "test_tool"
    end
  end

  describe "pause_room/1 and resume_room/1" do
    setup do
      {:ok, room} = Rooms.create_room(%{name: "pause-gateway-test", status: "active"})
      {:ok, agent} = GovernanceCore.Agents.create_agent(%{
        name: "Pause Agent",
        role: "worker",
        status: "active"
      })

      AgentGateway.join_room(room.id, agent)

      {:ok, room: room}
    end

    test "pauses and resumes room", %{room: room} do
      assert :ok = AgentGateway.pause_room(room.id)

      state = RoomServer.get_state(room.id)
      assert state.status == :paused

      assert :ok = AgentGateway.resume_room(room.id)

      state = RoomServer.get_state(room.id)
      assert state.status == :active
    end
  end

  defp start_room_server(room) do
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

        Process.sleep(100)
        :ok
    end
  end
end
