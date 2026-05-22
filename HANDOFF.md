# GovernanceCore Agent Handoff

Last updated: 2026-05-22 10:05 +03:00

This file is the coordination note for AI agents working on `agentandbot/governance_core`. Read it before changing code.

## Current State

The project is the Phoenix LiveView core for agentandbot.com. It now includes:

- AI worker marketplace and persona directory.
- KADRO scenario board for task assignment, escrow-style completion, XP, levels, and achievements.
- Agent detail profile pages with CV, portfolio, activity, channels, services, deploy, and Brain Sync tabs.
- Brain Sync / DNA portability UI for JSON export and import.
- 1-click managed sandbox deploy simulation and Hostinger VPS outbound setup path.
- Tool Directory, Feed, Payment Dashboard, and shared Swarm OS shell navigation.
- Swarm-wide search page for agents, tasks, feed posts, provider tools, and payment services.
- Payment API and service verification docs in `API_DOCS.md`.
- Brand token distribution from the root `brand/manifest.toml`.

Validation status from the last run:

```text
mix test
74 tests, 0 failures
```

Dev database status:

```text
$env:TEMP='C:\tmp'; $env:TMP='C:\tmp'; mix ecto.migrate
Migrations already up
```

Known local environment note:

- On this Windows machine, Mix can fail if `TEMP` points at `C:\Users\ilker\AppData\Local\Temp`. Use `C:\tmp` for migration/server commands.
- Phoenix LiveView may warn about a Windows symlink permission for colocated JS. This warning did not break compile or tests.

## What Was Done In The Latest Stabilization Pass

Navigation and layout:

- `use Phoenix.LiveView` now uses the shared app layout in `lib/governance_core_web.ex`.
- Shared shell navigation was expanded in `lib/governance_core_web/components/layouts.ex`.
- Sidebar now exposes Command Hub, Personas, Tool Directory, Feed, Scenarios, Wallet & AP2, and Payments.
- Active route detection now works for nested paths such as `/agents/:id/brain_sync` and `/feed/:slug`.
- Page heading uses `page_title` when available.
- Main content has `overflow-x-hidden` to reduce horizontal scroll noise from wide worker pages.

Dashboard:

- `SwarmHubLive` quick actions now navigate to real pages:
  - Search Swarm -> `/search`
  - Spawn Persona -> `/agents/new`
  - Initiate Scenario -> `/scenarios`

Swarm-wide Search:

- Added `GovernanceCore.SwarmSearch` in `lib/governance_core/swarm_search.ex`.
- Added `/search` LiveView in `lib/governance_core_web/live/swarm_search_live.ex`.
- Search currently covers:
  - Personas/agents via `Agents.search/1`
  - Marketplace tasks via `Marketplace.list_tasks/1`
  - Feed posts via `Feed.list_posts/1`
  - Provider apps via `Marketplace.provider_apps/0`
  - Payment services via `Payments.list_services/0`
- Updated `Agents.search/1` to avoid SQLite-unsupported `ilike`; it now uses portable `lower(coalesce(...)) LIKE`.
- Added Search to the shared sidebar and page heading fallback.
- Added tests in `test/governance_core/swarm_search_test.exs`.
- Browser smoke test passed for `http://127.0.0.1:4001/search`.

Route/page metadata:

- Added or normalized `page_title` and `current_path` assigns for:
  - `SwarmHubLive`
  - `GovernanceLive`
  - `PaymentDashboardLive`
  - `FeedLive`
  - `FeedNewLive`
  - `FeedShowLive`
  - `ScenarioBoardLive`
  - `AgentCareerPostLive`
  - `AgentImageGeneratorLive`

Tests:

- `test/governance_core_web/controllers/page_controller_test.exs` now checks that the shell renders the key navigation links.

KADRO work already present from the other agent:

- Persona career/deployment migration:
  - `priv/repo/migrations/20260522061840_add_career_and_deployment_to_personas.exs`
- Persona schema fields:
  - `level`
  - `xp`
  - `achievements`
  - `memory_keys_count`
  - `deployed_endpoint`
- Marketplace task reward logic:
  - `Marketplace.list_tasks/1`
  - `Marketplace.complete_task_and_reward/2`
  - `Marketplace.calculate_achievements/3`
- KADRO scenario board:
  - Kanban-style task states.
  - Launch Agent terminal simulation.
  - Approve & Pay reward flow.
  - Refund/cancel path.
- Agent detail:
  - Deploy tab.
  - Brain Sync tab.
  - DNA export/import UI.
- Tests:
  - `test/governance_core/persona_development_test.exs`

## Immediate Next Work

Recommended order:

1. Stabilization commit
   - Review the dirty worktree.
   - Keep related changes grouped.
   - Do not mix new feature work into the stabilization commit.
   - Run `mix test` before commit.

2. Search polish and command actions
   - Add deep links for tasks once there is a task detail route or selected-task query support on `/scenarios`.
   - Add keyboard shortcut/focus behavior for search after the shell JS strategy is settled.
   - Consider search result highlighting and per-group limits in the UI.

3. Real task runtime adapter
   - Replace or complement the KADRO simulated task execution with a minimal runtime adapter.
   - First adapter should be a custom HTTP/webhook task endpoint.
   - Keep simulation available as demo mode.
   - Persist runtime result, logs, artifact URL, and error state.

4. Brain Sync API
   - Add agent-readable endpoints for DNA export/import.
   - Suggested shape:
     - `GET /api/agents/:id/dna`
     - `POST /api/agents/:id/dna`
   - Validate level/xp/achievements/memory fields.
   - Do not expose secrets or private identity material.

5. Payment and escrow polish
   - Make the user story explicit:
     - Buy/top up credits.
     - Hire or assign a task.
     - Escrow credits.
     - Approve release or refund.
   - Align KADRO board, Payment Dashboard, and API docs around the same terms.

6. Brand automation verification
   - Add a lightweight check for `node brand/generate_tokens.mjs`.
   - Confirm token outputs land in Phoenix and Astro targets.
   - Avoid manual edits to generated token files unless regenerating from `brand/manifest.toml`.

## Important Constraints For Future Agents

- Do not revert unrelated dirty changes. This repo often has multiple agents working at once.
- Prefer `rg` for searching.
- For Phoenix changes, run `mix format` and `mix test`.
- Use `Req` for HTTP clients. Do not introduce HTTPoison/Tesla/httpc.
- Avoid raw inline `<script>` in HEEx. Prefer app JS hooks or LiveView colocated hooks.
- Do not add another design language. Follow existing `worker-*`, `agent-profile-*`, and shared layout patterns unless deliberately refactoring.
- Do not hardcode production-only secrets or wallets.
- Keep KADRO simulation and real execution separated. Demo mode should remain useful.

## Useful Commands

```powershell
cd B:\DEV\HAREZM_EKOSISTEMI\agentandbot\governance_core
mix format
mix test
$env:TEMP='C:\tmp'; $env:TMP='C:\tmp'; mix ecto.migrate
$env:TEMP='C:\tmp'; $env:TMP='C:\tmp'; $env:PORT='4001'; mix phx.server
```

## Useful URLs In Dev

- `http://127.0.0.1:4001/`
- `http://127.0.0.1:4001/search`
- `http://127.0.0.1:4001/agents`
- `http://127.0.0.1:4001/scenarios`
- `http://127.0.0.1:4001/tools`
- `http://127.0.0.1:4001/feed`
- `http://127.0.0.1:4001/payment/dashboard`
- `http://127.0.0.1:4001/api/openapi.json`

## Open Questions

- Should KADRO task cancellation/refund stay manual, or become automatic on runtime failure?
- Which runtime adapter should ship first: custom HTTP webhook, n8n, Activepieces, or Windmill?
- Should DNA import be allowed to lower an agent's XP/level, or only merge upward?
- What authentication should protect Brain Sync API in the first production release?
- Should the shared shell chat drawer become functional now, or stay visual until search/runtime work lands?
