defmodule GovernanceCoreWeb.Api.RoomController do
  use GovernanceCoreWeb, :controller

  alias GovernanceCore.Agents.AgentGateway
  alias GovernanceCore.Rooms

  def index(conn, _params) do
    rooms = Rooms.list_rooms()

    json(conn, %{
      data: Enum.map(rooms, &room_summary/1),
      meta: %{total: length(rooms)}
    })
  end

  def show(conn, %{"id" => id}) do
    case Rooms.get_room(id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Room not found", id: id})

      room ->
        state = AgentGateway.get_room_state(id)

        json(conn, %{
          data: %{
            id: room.id,
            name: room.name,
            status: room.status,
            agents: AgentGateway.list_room_agents(id),
            state: state
          }
        })
    end
  end

  def create(conn, %{"name" => name} = params) do
    attrs = %{
      name: name,
      status: Map.get(params, "status", "active"),
      owner_id: Map.get(params, "owner_id")
    }

    case Rooms.create_room(attrs) do
      {:ok, room} ->
        conn
        |> put_status(:created)
        |> json(%{data: room_summary(room)})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_errors(changeset)})
    end
  end

  def join(conn, %{"id" => room_id, "agent_id" => agent_id} = params) do
    case AgentGateway.authenticate(agent_id, params["token"]) do
      {:ok, agent} ->
        case AgentGateway.join_room(room_id, agent) do
          :ok ->
            json(conn, %{
              data: %{
                room_id: room_id,
                agent_id: agent_id,
                status: "joined"
              }
            })

          {:error, :room_not_found} ->
            conn
            |> put_status(:not_found)
            |> json(%{error: "Room not found"})
        end

      {:error, reason} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: to_string(reason)})
    end
  end

  def leave(conn, %{"id" => room_id, "agent_id" => agent_id}) do
    AgentGateway.leave_room(room_id, agent_id)

    json(conn, %{
      data: %{
        room_id: room_id,
        agent_id: agent_id,
        status: "left"
      }
    })
  end

  def send_mcp(conn, %{"id" => room_id} = params) do
    payload = Map.get(params, "payload", %{})
    payload = Map.put(payload, "agent_id", params["agent_id"])

    AgentGateway.send_mcp(room_id, payload)

    json(conn, %{data: %{status: "sent", room_id: room_id}})
  end

  def send_human(conn, %{"id" => room_id} = params) do
    text = Map.get(params, "text", "")
    user_id = Map.get(params, "user_id", "anonymous")

    AgentGateway.send_human_message(room_id, text, user_id)

    json(conn, %{data: %{status: "sent", room_id: room_id}})
  end

  def agents(conn, %{"id" => room_id}) do
    agents = AgentGateway.list_room_agents(room_id)

    json(conn, %{data: agents, meta: %{total: length(agents)}})
  end

  def pause(conn, %{"id" => room_id}) do
    AgentGateway.pause_room(room_id)
    json(conn, %{data: %{room_id: room_id, status: "paused"}})
  end

  def resume(conn, %{"id" => room_id}) do
    AgentGateway.resume_room(room_id)
    json(conn, %{data: %{room_id: room_id, status: "resumed"}})
  end

  def request_approval(conn, %{"id" => room_id} = params) do
    attrs = Map.get(params, "request", %{})
    AgentGateway.request_approval(room_id, attrs)
    json(conn, %{data: %{status: "requested", room_id: room_id}})
  end

  defp room_summary(room) do
    %{
      id: room.id,
      name: room.name,
      status: room.status,
      owner_id: room.owner_id,
      inserted_at: room.inserted_at
    }
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
