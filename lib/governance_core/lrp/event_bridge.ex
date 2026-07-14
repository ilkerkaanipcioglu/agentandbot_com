defmodule GovernanceCore.LRP.EventBridge do
  @moduledoc """
  Bridges AgentAndBot room events to LRP's event system.

  When an LRP instance is available (shared PubSub or HTTP webhook),
  room events are forwarded in LRP's event format:

      %{
        event_type: "agent_tool_call_started",
        tenant_id: "...",
        source: "agentandbot",
        payload: %{...},
        tier: "HOT",
        actor_confidence: 1.0
      }

  Without LRP, this module is a no-op (graceful degradation).
  """

  alias GovernanceCore.Rooms.EventTaxonomy

  @doc """
  Forwards a room event to LRP if available.
  """
  @spec forward_event(map()) :: :ok | {:error, term()}
  def forward_event(room_event) do
    pubsub = Application.get_env(:lrp, :pubsub_server)
    tenant = Application.get_env(:governance_core, :lrp_tenant_id)

    cond do
      is_nil(pubsub) ->
        :ok

      is_nil(tenant) ->
        :ok

      true ->
        lrp_event = to_lrp_event(room_event, tenant)

        case Code.ensure_loaded?(Phoenix.PubSub) do
          true ->
            Phoenix.PubSub.broadcast(pubsub, "tenant:#{tenant}:events", {:lrp_event, lrp_event})
            :ok

          false ->
            :ok
        end
    end
  end

  @doc """
  Checks if LRP bridge is available and configured.
  """
  @spec available?() :: boolean()
  def available? do
    pubsub = Application.get_env(:lrp, :pubsub_server)
    tenant = Application.get_env(:governance_core, :lrp_tenant_id)
    is_binary(pubsub) and is_binary(tenant)
  end

  defp to_lrp_event(room_event, tenant) do
    event_type =
      room_event
      |> Map.get(:payload, %{})
      |> EventTaxonomy.classify()

    source =
      case room_event.from_type do
        "agent" -> "agentandbot_agent"
        "human" -> "agentandbot_human"
        _ -> "agentandbot_system"
      end

    %{
      event_type: event_type,
      tenant_id: tenant,
      source: source,
      occurred_at: room_event.inserted_at || DateTime.utc_now(),
      payload: room_event.payload || %{},
      tier: "HOT",
      actor_confidence: if(room_event.from_type == "agent", do: 1.0, else: nil),
      idempotency_key: generate_idempotency_key(room_event)
    }
  end

  defp generate_idempotency_key(%{id: id, inserted_at: at}) when is_binary(id) and not is_nil(at) do
    "#{id}:#{DateTime.to_iso8601(at)}"
  end

  defp generate_idempotency_key(_) do
    Ecto.UUID.generate()
  end
end
