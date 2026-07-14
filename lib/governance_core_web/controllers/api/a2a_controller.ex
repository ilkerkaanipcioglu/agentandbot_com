defmodule GovernanceCoreWeb.Api.A2AController do
  use GovernanceCoreWeb, :controller

  alias GovernanceCore.Agents
  alias GovernanceCore.Agents.AgentGateway

  @doc """
  A2A Agent Card — returns the agent's capabilities as per the A2A protocol.
  GET /api/a2a/.well-known/agent.json
  """
  def agent_card(conn, %{"agent_id" => agent_id}) do
    case Agents.get_agent(agent_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Agent not found"})

      agent ->
        card = %{
          name: agent.name,
          url: "https://agentandbot.com/agents/#{agent.id}",
          version: "1.0.0",
          protocol_version: "0.2",
          capabilities: %{
            streaming: false,
            push_notifications: false,
            state_transition_history: true
          },
          skills: Enum.map(agent.skills, &skill_entry/1),
          default_input_modes: ["text/plain", "application/json"],
          default_output_modes: ["text/plain", "application/json"],
          description: agent.description || "AgentAndBot agent",
          provider: %{
            organization: "AgentAndBot",
            url: "https://agentandbot.com"
          },
          metadata: %{
            protocol: agent.protocol,
            runtime_kind: agent.runtime_kind,
            runtime_provider: agent.runtime_provider,
            hosting_mode: agent.hosting_mode,
            interop_standards: agent.interop_standards,
            trust_score: agent.trust_score,
            status: agent.status,
            category: agent.category
          }
        }

        conn
        |> put_resp_header("content-type", "application/json")
        |> json(card)
    end
  end

  @doc """
  A2A Task send — sends a task to an agent via MCP message.
  POST /api/a2a/agents/:agent_id/tasks
  """
  def create_task(conn, %{"agent_id" => agent_id} = params) do
    case Agents.get_agent(agent_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Agent not found"})

      _agent ->
        room_id = Map.get(params, "room_id")
        payload = Map.get(params, "payload", %{})

        if room_id do
          case AgentGateway.authenticate(agent_id, params["token"]) do
            {:ok, agent} ->
              case AgentGateway.join_room(room_id, agent) do
                :ok ->
                  mcp_payload =
                    payload
                    |> Map.put("agent_id", agent_id)
                    |> Map.put("method", Map.get(payload, "method", "tasks/send"))

                  AgentGateway.send_mcp(room_id, mcp_payload)

                  conn
                  |> put_status(:accepted)
                  |> json(%{
                    data: %{
                      task_id: Ecto.UUID.generate(),
                      status: "submitted",
                      agent_id: agent_id,
                      room_id: room_id
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
        else
          conn
          |> put_status(:bad_request)
          |> json(%{error: "room_id required"})
        end
    end
  end

  @doc """
  A2A Task cancel — cancels a task for an agent.
  POST /api/a2a/agents/:agent_id/tasks/:task_id/cancel
  """
  def cancel_task(conn, %{"agent_id" => agent_id, "task_id" => task_id} = params) do
    room_id = Map.get(params, "room_id")

    if room_id do
      payload = %{
        "agent_id" => agent_id,
        "method" => "tasks/cancel",
        "params" => %{"task_id" => task_id}
      }

      AgentGateway.send_mcp(room_id, payload)

      json(conn, %{
        data: %{
          task_id: task_id,
          status: "cancelled",
          agent_id: agent_id
        }
      })
    else
      conn
      |> put_status(:bad_request)
      |> json(%{error: "room_id required"})
    end
  end

  @doc """
  A2A Message send — sends a message to an agent in a room context.
  POST /api/a2a/agents/:agent_id/message
  """
  def send_message(conn, %{"agent_id" => agent_id} = params) do
    room_id = Map.get(params, "room_id")

    if room_id do
      payload = %{
        "agent_id" => agent_id,
        "method" => "messages/send",
        "params" => %{
          "content" => Map.get(params, "content", ""),
          "content_type" => Map.get(params, "content_type", "text/plain"),
          "task_id" => params["task_id"]
        }
      }

      AgentGateway.send_mcp(room_id, payload)

      conn
      |> put_status(:accepted)
      |> json(%{
        data: %{
          status: "sent",
          agent_id: agent_id,
          room_id: room_id
        }
      })
    else
      conn
      |> put_status(:bad_request)
      |> json(%{error: "room_id required"})
    end
  end

  defp skill_entry(skill) when is_binary(skill) do
    %{id: skill, name: skill, description: skill}
  end

  defp skill_entry(skill) when is_map(skill) do
    %{
      id: Map.get(skill, "id", ""),
      name: Map.get(skill, "name", ""),
      description: Map.get(skill, "description", ""),
      tags: Map.get(skill, "tags", [])
    }
  end
end
