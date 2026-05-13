defmodule GovernanceCoreWeb.AgentProfileTest do
  use GovernanceCoreWeb.ConnCase, async: true

  alias GovernanceCore.Marketplace
  alias GovernanceCore.Personas.Persona
  alias GovernanceCore.Repo

  setup do
    agent =
      %Persona{}
      |> Persona.changeset(%{
        name: "Portfolio Worker",
        sub_type: "bot",
        access_group: "external",
        status: "active",
        owner: "worker_owner",
        runtime_kind: "google_agent",
        hosting_mode: "affiliate",
        skills: ["research", "deliver_artifact"],
        interop_standards: ["A2A", "Google ADK", "OpenAPI"],
        metadata: %{
          "identity" => %{
            "public_key_type" => "Ed25519",
            "identity_json_url" => "https://example.com/identity.json",
            "private_key" => "must-not-leak"
          }
        }
      })
      |> Repo.insert!()

    {:ok, _listing} =
      Marketplace.create_listing(%{
        persona_id: agent.id,
        seller_id: "seller",
        title: "Portfolio Worker",
        summary: "Research and artifact delivery.",
        runtime_kind: "google_agent",
        status: "published",
        required_skills: ["research", "deliver_artifact"],
        task_price_credits: 7,
        rental_price_credits: 70,
        metadata: %{
          "kadro_profile" => %{
            "p_no" => "T-200",
            "category" => "Core",
            "age" => 29,
            "gender" => "AI",
            "country" => "Turkiye",
            "profession" => "Research Analyst",
            "personality" => "Careful and concise.",
            "content" => "Market research and brief writing.",
            "headshot_url" => "/images/kadro/1001/1001_Ayse_Kaya_Vesikalik.png",
            "cv_url" => "/images/kadro/1001/1001_Ayse_Kaya_CV.html"
          }
        }
      })

    Marketplace.upsert_policy(%{
      persona_id: agent.id,
      allowed_skills: ["research", "deliver_artifact"],
      max_budget_credits: 100
    })

    Marketplace.adjust_credits("buyer", 50)

    {:ok, public_task} =
      Marketplace.create_task(%{
        agent_id: agent.id,
        created_by: "buyer",
        title: "Publishable research brief",
        required_skill: "research",
        expected_artifact: "A short research brief",
        budget_credits: 10
      })

    {:ok, _public_task} =
      Marketplace.submit_artifact(public_task.id, %{
        "actor" => agent.id,
        "artifact_url" => "https://example.com/research-brief",
        "artifact_type" => "brief",
        "summary" => "A public market research artifact.",
        "portfolio_public" => true,
        "skills_used" => ["research"]
      })

    {:ok, private_task} =
      Marketplace.create_task(%{
        agent_id: agent.id,
        created_by: "buyer",
        title: "Private client artifact",
        required_skill: "research",
        budget_credits: 5
      })

    {:ok, _private_task} =
      Marketplace.submit_artifact(private_task.id, %{
        "actor" => agent.id,
        "artifact_url" => "https://example.com/private",
        "portfolio_public" => false
      })

    {:ok, agent: agent}
  end

  test "agent profile, cv, and portfolio pages render", %{conn: conn, agent: agent} do
    profile_html = conn |> get(~p"/agents/#{agent.id}") |> html_response(200)
    assert profile_html =~ "AI worker persona"
    assert profile_html =~ "Professional profile"
    assert profile_html =~ "Published work"

    cv_html = conn |> get(~p"/agents/#{agent.id}/cv") |> html_response(200)
    assert cv_html =~ "Research Analyst"
    assert cv_html =~ "Open CV"

    portfolio_html = conn |> get(~p"/agents/#{agent.id}/portfolio") |> html_response(200)
    assert portfolio_html =~ "Publishable research brief"
    assert portfolio_html =~ "A public market research artifact."
    refute portfolio_html =~ "Private client artifact"
  end

  test "agent cv and portfolio APIs expose public data only", %{conn: conn, agent: agent} do
    cv = conn |> get(~p"/api/agents/#{agent.id}/cv") |> json_response(200)
    assert cv["data"]["headline"] == "Research Analyst"
    assert cv["data"]["links"]["portfolio"] == "/agents/#{agent.id}/portfolio"

    portfolio = conn |> get(~p"/api/agents/#{agent.id}/portfolio") |> json_response(200)
    titles = Enum.map(portfolio["data"]["entries"], & &1["title"])
    assert "Publishable research brief" in titles
    refute "Private client artifact" in titles
  end

  test "protocol, identity, and commerce APIs expose standards metadata", %{
    conn: conn,
    agent: agent
  } do
    protocols = conn |> get(~p"/api/protocols") |> json_response(200)
    assert Enum.any?(protocols["data"], &(&1["name"] == "AP2"))

    profile = conn |> get(~p"/api/agents/#{agent.id}/protocol-profile") |> json_response(200)
    assert profile["data"]["messaging"]["acp_compatible_envelope"] == true
    assert Enum.any?(profile["data"]["protocols"], &(&1["name"] == "A2A"))

    identity = conn |> get(~p"/api/agents/#{agent.id}/identity") |> json_response(200)
    assert identity["data"]["public_key_type"] == "Ed25519"
    refute Map.has_key?(identity["data"], "private_key")

    commerce = conn |> get(~p"/api/agents/#{agent.id}/commerce") |> json_response(200)

    assert commerce["data"]["commerce_protocols"] == [
             "UCP",
             "AP2",
             "x402-ready",
             "internal_credits"
           ]
  end
end
