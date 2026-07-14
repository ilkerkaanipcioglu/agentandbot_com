defmodule GovernanceCore.LesTupid.SyncAdapterTest do
  use GovernanceCore.DataCase, async: true

  alias GovernanceCore.Agents
  alias GovernanceCore.LesTupid.SyncAdapter

  describe "to_lrp_entity/1" do
    test "converts persona to LRP entity format" do
      {:ok, agent} = Agents.create_agent(%{name: "Sync Test", role: "worker", status: "active"})

      lrp = SyncAdapter.to_lrp_entity(agent)

      assert lrp.source == "agentandbot"
      assert lrp.external_id == agent.id
      assert lrp.name == "Sync Test"
    end
  end

  describe "sync_from_lrp/2" do
    test "creates new persona from LRP entity when id is nil" do
      lrp_entity = %{
        "name" => "LRP Imported",
        "metadata" => %{"role" => "orchestrator", "type" => "megahawk"}
      }

      {:ok, persona} = SyncAdapter.sync_from_lrp(nil, lrp_entity)

      assert persona.name == "LRP Imported"
      assert persona.role == "orchestrator"
      assert persona.type == "megahawk"
    end

    test "creates new persona when id not found (fallback)" do
      lrp_entity = %{
        "name" => "Fallback Import",
        "metadata" => %{"role" => "worker"}
      }

      {:ok, persona} = SyncAdapter.sync_from_lrp("nonexistent-id", lrp_entity)

      assert persona.name == "Fallback Import"
    end

    test "updates existing persona from LRP entity" do
      {:ok, agent} = Agents.create_agent(%{name: "Before", role: "worker", status: "active"})

      lrp_entity = %{
        "name" => "Updated",
        "metadata" => %{"trust_score" => 99, "status" => "active"}
      }

      {:ok, updated} = SyncAdapter.sync_from_lrp(agent.id, lrp_entity)

      assert updated.name == "Updated"
      assert updated.trust_score == 99
    end
  end

  describe "lrp_available?/0" do
    test "returns false when LRP not configured" do
      refute SyncAdapter.lrp_available?()
    end
  end
end
