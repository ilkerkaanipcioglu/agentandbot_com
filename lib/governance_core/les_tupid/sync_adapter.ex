defmodule GovernanceCore.LesTupid.SyncAdapter do
  alias GovernanceCore.Agents
  alias GovernanceCore.Personas.Persona

  @doc """
  Converts an AgentAndBot persona to LRP entity format.
  """
  @spec to_lrp_entity(Persona.t()) :: map()
  def to_lrp_entity(%Persona{} = persona) do
    %{
      name: persona.name,
      type: "agent",
      source: "agentandbot",
      external_id: persona.id,
      metadata: %{
        role: persona.role,
        type: persona.type,
        sub_type: persona.sub_type,
        protocol: persona.protocol,
        trust_score: persona.trust_score,
        status: persona.status
      }
    }
  end

  @doc """
  Creates or updates an AgentAndBot persona from an LRP entity.
  """
  @spec sync_from_lrp(String.t() | nil, map()) :: {:ok, Persona.t()} | {:error, Ecto.Changeset.t()}
  def sync_from_lrp(nil, lrp_entity) do
    attrs = %{
      name: Map.get(lrp_entity, "name", "Imported Agent"),
      role: Map.get(lrp_entity, "metadata", %{}) |> Map.get("role", "worker"),
      type: Map.get(lrp_entity, "metadata", %{}) |> Map.get("type", "picoclaw"),
      sub_type: Map.get(lrp_entity, "metadata", %{}) |> Map.get("sub_type", "bot"),
      protocol: Map.get(lrp_entity, "metadata", %{}) |> Map.get("protocol", "ABL.ONE/1.0"),
      status: "active"
    }

    Agents.create_agent(attrs)
  end

  def sync_from_lrp(persona_id, lrp_entity) do
    case Agents.get_agent(persona_id) do
      nil ->
        sync_from_lrp(nil, lrp_entity)

      persona ->
        meta = Map.get(lrp_entity, "metadata", %{})

        attrs =
          %{}
          |> maybe_put(:name, Map.get(lrp_entity, "name"))
          |> maybe_put(:role, Map.get(meta, "role"))
          |> maybe_put(:trust_score, Map.get(meta, "trust_score"))
          |> maybe_put(:status, Map.get(meta, "status"))

        Agents.update_agent(persona, attrs)
    end
  end

  @doc """
  Lists all personas that were synced from LRP.
  """
  @spec list_synced() :: [Persona.t()]
  def list_synced do
    Agents.list_agents()
    |> Enum.filter(&(&1.metadata["source"] == "lrp"))
  end

  @doc """
  Checks if LRP sync is configured (shared PubSub available).
  """
  @spec lrp_available?() :: boolean()
  def lrp_available? do
    Application.get_env(:lrp, :pubsub_server) != nil
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
