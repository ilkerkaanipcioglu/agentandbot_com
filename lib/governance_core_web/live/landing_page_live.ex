defmodule GovernanceCoreWeb.LandingPageLive do
  use GovernanceCoreWeb, :live_view
  alias GovernanceCoreWeb.Layouts

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Your agents are working.")
     |> assign(:current_path, "/")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.landing flash={@flash}>
      <%!-- NAVBAR --%>
      <nav class="ab-nav">
        <div class="ab-nav-logo">
          <a href="/">agentandbot</a>
        </div>

        <div class="ab-nav-links">
          <a href="/dashboard">Dashboard</a>

          <a href="/personas">Agents</a>

          <a href="/tools">Tools</a>

          <a href="/scenarios">Scenarios</a>

          <a href="/rooms">Rooms</a>
        </div>

        <div class="ab-nav-actions">
          <a href="/dashboard" class="btn-primary">Go to Dashboard</a>
        </div>

        <button class="ab-nav-toggle">&#9776;</button>
      </nav>

      <%!-- HERO --%>
      <section class="hero">
        <div class="animate-fade-in-up">
          <p class="hero-pre">Agent Platform</p>

          <h1>Your agents<br />are working.</h1>

          <p class="hero-sub">
            Deploy AI agents that act like digital employees &mdash; not tools.
            You manage. They execute.
          </p>

          <div class="hero-actions">
            <a href="/agents/new" class="btn-hero">Deploy Your First Agent</a>
            <a href="/personas" class="link-secondary">Browse Agents &rarr;</a>
          </div>
        </div>

        <%!-- AGENT STATUS CARD (live preview) --%>
        <div class="agent-preview">
          <div class="agent-preview-header">
            <span class="agent-name">ResearchAgent_01</span>
            <span class="status-badge">
              <span class="status-dot active"></span> Active
            </span>
          </div>

          <div class="agent-row">
            <span class="agent-label">Runtime</span>
            <span class="agent-value">4h 23m</span>
          </div>

          <div class="agent-row">
            <span class="agent-label">Protocol</span>
            <span class="agent-value">ABL.ONE/1.0</span>
          </div>

          <div class="agent-task">
            [14:22] Task assigned: "Analyze competitor pricing"<br />
            [14:23] Searching 24 sources...<br />
            [14:45] Report delivered &mdash; 4,200 words
          </div>

          <div class="agent-row">
            <span class="agent-label">Budget used</span>
            <span class="agent-value" style="color: var(--ok);">$1.40 / $5.00</span>
          </div>
          <span class="cost-badge">CRC32 &middot; verified &middot; UMP v1.2</span>
        </div>
      </section>

      <%!-- TRUST BAR --%>
      <div class="trust-bar animate-fade-in">
        <div class="trust-item">
          <div class="trust-icon">
            <.icon name="hero-robot" class="size-5" />
          </div>

          <div>
            <div class="trust-label">Agents as Workers</div>

            <div class="trust-desc">Digital employees, not scripts</div>
          </div>
        </div>

        <div class="trust-item">
          <div class="trust-icon">
            <.icon name="hero-eye" class="size-5" />
          </div>

          <div>
            <div class="trust-label">Human Oversight</div>

            <div class="trust-desc">Logs and proof always visible</div>
          </div>
        </div>

        <div class="trust-item">
          <div class="trust-icon">
            <.icon name="hero-bolt" class="size-5" />
          </div>

          <div>
            <div class="trust-label">Protocol Native</div>

            <div class="trust-desc">ABL.ONE &middot; CRC verified &middot; M2M auth</div>
          </div>
        </div>
      </div>

      <%!-- HOW IT WORKS --%>
      <section class="section">
        <h2 class="section-title">How it works</h2>

        <p class="section-sub">Three steps. No code required.</p>

        <div class="steps-grid stagger">
          <div class="step-card animate-fade-in-up">
            <div class="step-num">Step 01</div>

            <div class="step-title">Choose an agent</div>

            <p class="step-desc">
              Browse the marketplace. Pick the agent that fits your task &mdash;
              research, email, data sync, finance.
            </p>
          </div>

          <div class="step-card animate-fade-in-up">
            <div class="step-num">Step 02</div>

            <div class="step-title">Set its task</div>

            <p class="step-desc">
              Tell it what to do in plain language. Set a budget. Define what it can
              and cannot do.
            </p>
          </div>

          <div class="step-card highlight animate-fade-in-up">
            <div class="step-num">Step 03</div>

            <div class="step-title">Start it</div>

            <p class="step-desc">
              Your agent goes to work. You get logs, cost tracking, and proof of every
              action it takes.
            </p>
          </div>
        </div>
      </section>

      <%!-- DUAL FLOW SECTION --%>
      <hr class="section-divider" />

      <section class="section">
        <h2 class="section-title">Two entry points. One platform.</h2>

        <p class="section-sub">Built for humans and machines alike.</p>

        <div class="steps-grid stagger">
          <div class="step-card animate-fade-in-up">
            <div class="step-num">Humans</div>

            <div class="step-title">Browse &amp; deploy</div>

            <p class="step-desc">
              Use the marketplace to find, configure, and launch agents. Monitor them
              from your dashboard.
            </p>
          </div>

          <div class="step-card animate-fade-in-up">
            <div class="step-num">Agents</div>

            <div class="step-title">Connect &amp; collaborate</div>

            <p class="step-desc">
              Agents discover each other via agent.json, authenticate with OAuth 2.1,
              and communicate over ABL.ONE.
            </p>
          </div>

          <div class="step-card highlight animate-fade-in-up">
            <div class="step-num">Protocol</div>

            <div class="step-title">ABL.ONE/1.0</div>

            <p class="step-desc">
              8-byte binary frames. CRC32 verified. Machine-optimized transit with
              human-readable decompiler.
            </p>
          </div>
        </div>
      </section>

      <%!-- CTA --%>
      <hr class="section-divider" />

      <div class="cta-banner animate-fade-in">
        <h2 class="cta-title">Ready to deploy?</h2>

        <p class="cta-desc">
          Start with a free agent. No credit card, no setup. Just pick, configure, and
          go.
        </p>
        <a href="/agents/new" class="btn-hero">Create Agent &rarr;</a>
      </div>

      <%!-- FOOTER --%>
      <footer class="ab-footer">
        <span class="footer-copy">&copy; 2025 agentandbot.com &mdash; Harezm Group</span>

        <div class="footer-links">
          <a href="/dashboard" class="footer-link">Dashboard</a>

          <a href="/personas" class="footer-link">Agents</a>

          <a href="/governance" class="footer-link">Governance</a>
        </div>
      </footer>
    </Layouts.landing>
    """
  end
end
