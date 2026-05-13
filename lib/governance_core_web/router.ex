defmodule GovernanceCoreWeb.Router do
  use GovernanceCoreWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {GovernanceCoreWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", GovernanceCoreWeb do
    pipe_through(:browser)

    live("/", SwarmHubLive)
    live("/agents", PersonaDirectoryLive)
    live("/personas", PersonaDirectoryLive)
    live("/tools", ProviderAppDirectoryLive)
    live("/listings/new", ListingNewLive)
    live("/listings/:id/edit", ListingNewLive, :edit)
    live("/listings/:id/clone", ListingNewLive, :clone)
    live("/listings/:id/configure", ListingConfigureLive)
    live("/scenarios", ScenarioBoardLive)
    live("/governance", GovernanceLive)
    get("/skills.json", AgentDiscoveryController, :skills)

    # Legacy / Utility
    get("/mcp", AgentDiscoveryController, :mcp_manifest)
    live("/agent/connect", AgentConnectLive)
    live("/agents/new", AgentCreateLive)
    live("/agents/:id/hire", AgentHireLive)
    live("/agents/:id", AgentDetailLive)
    get("/agents/:id/.well-known/agent-card.json", AgentDiscoveryController, :agent_card)
    get("/agents/:id/.well-known/skills.json", AgentDiscoveryController, :agent_skills)
    live("/agents/:id/cv", AgentDetailLive, :cv)
    live("/agents/:id/portfolio", AgentDetailLive, :portfolio)
  end

  # Payment Dashboard
  scope "/payment", GovernanceCoreWeb do
    pipe_through(:browser)
    live("/dashboard", PaymentDashboardLive)
  end

  scope "/.well-known", GovernanceCoreWeb do
    pipe_through(:api)

    get("/agent.json", AgentDiscoveryController, :show)
  end

  scope "/api", GovernanceCoreWeb do
    pipe_through(:api)

    # Agent CRUD
    get("/openapi.json", Api.OpenApiController, :show)
    get("/protocols", Api.ProtocolController, :index)
    get("/providers", Api.ProviderController, :index)
    get("/provider-apps", Api.ProviderController, :apps)
    post("/provider-apps/:id/ratings", Api.ProviderController, :rate_app)
    get("/listings", Api.ListingController, :index)
    get("/listings/:id", Api.ListingController, :show)
    post("/listings", Api.ListingController, :create)
    patch("/listings/:id", Api.ListingController, :update)
    post("/listings/:id/publish", Api.ListingController, :publish)
    post("/listings/:id/hire", Api.ListingController, :hire)
    post("/listings/:id/rent", Api.ListingController, :rent)
    get("/listings/:id/provider", Api.ListingController, :provider)
    get("/agents", Api.AgentController, :index)
    get("/agents/:id/cv", Api.AgentController, :cv)
    get("/agents/:id/portfolio", Api.AgentController, :portfolio)
    get("/agents/:id/protocol-profile", Api.AgentController, :protocol_profile)
    get("/agents/:id/identity", Api.AgentController, :identity)
    get("/agents/:id/commerce", Api.AgentController, :commerce)
    get("/agents/:id", Api.AgentController, :show)
    post("/agents", Api.AgentController, :create)

    # Tasks
    post("/tasks", Api.TaskController, :create)
    get("/tasks/:id", Api.TaskController, :show)
    post("/tasks/:id/events", Api.TaskController, :event)
    post("/tasks/:id/artifacts", Api.TaskController, :artifact)
    post("/tasks/:id/delegate", Api.TaskController, :delegate)
    post("/tasks/:id/messages", Api.TaskController, :message)
    post("/tasks/:id/commerce-intent", Api.TaskController, :commerce_intent)
    get("/credits/:account_id", Api.CreditController, :show)
    post("/credits/adjust", Api.CreditController, :adjust)

    # Comments (from remote — Jules/Comment Monitor)
    post("/comments", CommentController, :create)
  end

  scope "/api/v1", GovernanceCoreWeb do
    pipe_through(:api)

    get("/services", Api.ServiceController, :index)
    post("/services/register", Api.ServiceController, :create)
    get("/services/:slug/verify", Api.VerifyController, :info)
    post("/services/:slug/verify", Api.VerifyController, :verify)
    post("/payments/submit", Api.PaymentController, :submit)
  end

  # Enable LiveDashboard in development
  if Application.compile_env(:governance_core, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through(:browser)

      live_dashboard("/dashboard", metrics: GovernanceCoreWeb.Telemetry)
    end
  end
end
