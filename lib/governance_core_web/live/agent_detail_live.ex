defmodule GovernanceCoreWeb.AgentDetailLive do
  use GovernanceCoreWeb, :live_view

  alias GovernanceCore.Agents
  alias GovernanceCore.Marketplace

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    agent = Agents.get_agent(id)
    cv = Marketplace.agent_cv(id)
    portfolio = Marketplace.agent_portfolio(id)
    protocol_profile = Marketplace.agent_protocol_profile(id)

    {:ok,
     assign(socket,
       agent: agent,
       cv: cv,
       portfolio: portfolio,
       protocol_profile: protocol_profile,
       agent_id: id,
       page_title: page_title(agent, socket.assigns[:live_action]),
       current_path: "/agents/#{id}"
     )}
  end

  defp page_title(nil, _action), do: "Agent Not Found"
  defp page_title(agent, :cv), do: "#{agent.name} CV"
  defp page_title(agent, :portfolio), do: "#{agent.name} Portfolio"
  defp page_title(agent, _action), do: agent.name

  defp profile(assigns), do: get_in(assigns, [:cv, :profile]) || %{}
  defp profile_value(assigns, key), do: Map.get(profile(assigns), key)

  defp headline(assigns) do
    get_in(assigns, [:cv, :headline]) || assigns.agent.role || assigns.agent.category ||
      "AI worker persona"
  end

  defp summary(assigns) do
    get_in(assigns, [:cv, :summary]) || assigns.agent.description || "Skill-first AI worker."
  end

  defp location(assigns) do
    [profile_value(assigns, "city"), profile_value(assigns, "country")]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join(", ")
  end

  defp demographics(assigns) do
    [location(assigns), age_text(profile_value(assigns, "age")), profile_value(assigns, "gender")]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join(" / ")
  end

  defp age_text(nil), do: nil
  defp age_text(age), do: "#{age} yas"

  defp initials(name) do
    name
    |> to_string()
    |> String.split(" ", trim: true)
    |> Enum.map_join("", &String.first/1)
    |> String.slice(0, 2)
    |> String.upcase()
  end

  defp action_active?(nil, :show), do: true
  defp action_active?(live_action, expected), do: live_action == expected

  defp portfolio_entries(%{portfolio: %{entries: entries}}), do: entries
  defp portfolio_entries(_assigns), do: []

  defp skills(%{cv: %{skills: skills}}) when is_list(skills), do: skills
  defp skills(%{agent: agent}), do: agent.skills || []

  defp standards(%{cv: %{standards: standards}}) when is_list(standards) and standards != [] do
    standards
  end

  defp standards(_assigns), do: ["A2A", "MCP", "OpenAPI", "x402-ready"]

  defp standard_description("A2A"), do: "Agent-to-agent discovery and delegation."
  defp standard_description("MCP"), do: "Tool and data access contract."
  defp standard_description("ACP"), do: "Message envelope compatibility."
  defp standard_description("ANP"), do: "Network discovery metadata."
  defp standard_description("UCP"), do: "Commerce intent metadata."
  defp standard_description("AP2"), do: "Payment mandate metadata."
  defp standard_description("DID"), do: "Public decentralized identity."
  defp standard_description("Ed25519"), do: "Public key identity metadata."
  defp standard_description("OpenAPI 3.1"), do: "HTTP API contract."
  defp standard_description("JSON Schema"), do: "Typed skill inputs and outputs."
  defp standard_description("x402-ready"), do: "Future machine-payment readiness."
  defp standard_description(_standard), do: "Runtime compatibility marker."

  defp price_text(%{cv: %{pricing: pricing}}) do
    task = pricing[:task_price_credits] || pricing["task_price_credits"]
    rent = pricing[:rental_price_credits] || pricing["rental_price_credits"]

    cond do
      task && rent -> "#{task} cr task / #{rent} cr monthly"
      task -> "#{task} cr task"
      rent -> "#{rent} cr monthly"
      true -> "Pricing by task"
    end
  end

  defp price_text(_assigns), do: "Pricing by task"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="worker-market agent-profile-page">
      <%= if @agent do %>
        <section class="agent-profile-hero">
          <div class="agent-profile-photo">
            <%= if profile_value(assigns, "headshot_url") do %>
              <img src={profile_value(assigns, "headshot_url")} alt={"#{@agent.name} headshot"} />
            <% else %>
              <span>{initials(@agent.name)}</span>
            <% end %>
          </div>

          <div class="agent-profile-main">
            <div class="worker-no">
              <span>{profile_value(assigns, "p_no") || String.slice(@agent.id, 0, 8)}</span>
              <b>{profile_value(assigns, "category") || @agent.category || "Agent"}</b>
            </div>
            <h1>{@agent.name}</h1>
            <p class="agent-profile-headline">{headline(assigns)}</p>
            <p class="agent-profile-summary">{summary(assigns)}</p>
            <div class="agent-profile-meta">
              <span class="worker-ai-badge static">AI worker persona</span>
              <span>{demographics(assigns)}</span>
              <span>{price_text(assigns)}</span>
            </div>
          </div>

          <div class="agent-profile-actions">
            <a href={"/agents/#{@agent.id}/hire"} class="worker-main-btn">Hire</a>
            <a href={"/agents/#{@agent.id}/portfolio"}>Portfolio</a>
            <a href={"/agents/#{@agent.id}/cv"}>CV</a>
            <a
              href={"/agents/#{@agent.id}/.well-known/agent-card.json"}
              target="_blank"
              rel="noopener"
            >
              Agent card
            </a>
          </div>
        </section>

        <nav class="agent-profile-tabs">
          <a href={"/agents/#{@agent.id}"} class={action_active?(@live_action, :show) && "active"}>
            Overview
          </a>
          <a href={"/agents/#{@agent.id}/cv"} class={action_active?(@live_action, :cv) && "active"}>
            CV
          </a>
          <a
            href={"/agents/#{@agent.id}/portfolio"}
            class={action_active?(@live_action, :portfolio) && "active"}
          >
            Portfolio
          </a>
          <a href={"/agents/#{@agent.id}/.well-known/skills.json"} target="_blank" rel="noopener">
            Skills JSON
          </a>
        </nav>

        <%= case @live_action do %>
          <% :cv -> %>
            <.cv_section assigns={assigns} />
          <% :portfolio -> %>
            <.portfolio_section entries={portfolio_entries(assigns)} />
          <% _ -> %>
            <div class="agent-profile-layout">
              <.cv_section assigns={assigns} compact />
              <.portfolio_section entries={portfolio_entries(assigns)} compact />
            </div>
        <% end %>
      <% else %>
        <section class="agent-profile-empty">
          <h1>Agent not found.</h1>
          <p>This worker profile is missing or unpublished.</p>
          <a href="/agents" class="worker-main-btn">Browse marketplace</a>
        </section>
      <% end %>
    </div>
    """
  end

  attr :assigns, :map, required: true
  attr :compact, :boolean, default: false

  def cv_section(assigns) do
    ~H"""
    <section class="agent-profile-panel">
      <div class="agent-panel-head">
        <div>
          <p class="worker-kicker">CV</p>
          <h2>Professional profile</h2>
        </div>
        <%= if profile_value(@assigns, "cv_url") do %>
          <a href={profile_value(@assigns, "cv_url")} target="_blank" rel="noopener">Open CV</a>
        <% end %>
      </div>

      <div class="agent-cv-grid">
        <div>
          <h3>Summary</h3>
          <p>{summary(@assigns)}</p>
        </div>
        <div>
          <h3>Work focus</h3>
          <p>{profile_value(@assigns, "content") || "Task delivery through skill contracts."}</p>
        </div>
        <div>
          <h3>Runtime</h3>
          <p>{get_in(@assigns, [:cv, :runtime, :kind]) || @assigns.agent.runtime_kind}</p>
        </div>
        <div>
          <h3>Hosting</h3>
          <p>{get_in(@assigns, [:cv, :hosting]) || @assigns.agent.hosting_mode}</p>
        </div>
      </div>

      <div class="agent-chip-block">
        <h3>Skills</h3>
        <div class="worker-pill-row">
          <span :for={skill <- Enum.take(skills(@assigns), 10)}>{skill}</span>
        </div>
      </div>

      <div class="agent-chip-block">
        <h3>Standards</h3>
        <div class="worker-pill-row">
          <span :for={standard <- standards(@assigns)}>{standard}</span>
        </div>
        <div class="agent-standard-list">
          <div :for={standard <- Enum.take(standards(@assigns), 8)}>
            <b>{standard}</b>
            <small>{standard_description(standard)}</small>
          </div>
        </div>
        <div class="agent-standards-links">
          <a href={"/api/agents/#{@assigns.agent.id}/protocol-profile"} target="_blank" rel="noopener">
            Protocol profile
          </a>
          <a href={"/api/agents/#{@assigns.agent.id}/identity"} target="_blank" rel="noopener">
            Identity JSON
          </a>
          <a href={"/api/agents/#{@assigns.agent.id}/commerce"} target="_blank" rel="noopener">
            Commerce JSON
          </a>
        </div>
      </div>
    </section>
    """
  end

  attr :entries, :list, required: true
  attr :compact, :boolean, default: false

  def portfolio_section(assigns) do
    ~H"""
    <section class="agent-profile-panel">
      <div class="agent-panel-head">
        <div>
          <p class="worker-kicker">Portfolio</p>
          <h2>Published work</h2>
        </div>
        <span>{@entries |> length()} public items</span>
      </div>

      <%= if @entries == [] do %>
        <div class="agent-portfolio-empty">
          <h3>No public work yet.</h3>
          <p>Completed tasks published by this worker will appear here.</p>
        </div>
      <% else %>
        <div class="agent-portfolio-grid">
          <article :for={entry <- @entries} class="agent-portfolio-card">
            <%= if entry.thumbnail_url do %>
              <img src={entry.thumbnail_url} alt={entry.title} />
            <% end %>
            <div>
              <span>{entry.artifact_type}</span>
              <h3>{entry.title}</h3>
              <p>{entry.summary}</p>
            </div>
            <div class="agent-portfolio-foot">
              <small>{entry.skill}</small>
              <small>{entry.credits} cr</small>
            </div>
            <a href={entry.artifact_url} target="_blank" rel="noopener">Open artifact</a>
          </article>
        </div>
      <% end %>
    </section>
    """
  end
end
