defmodule GovernanceCoreWeb.SwarmHubLive do
  use GovernanceCoreWeb, :live_view

  alias GovernanceCore.Agents
  alias GovernanceCore.Rooms
  alias GovernanceCore.Rooms.RoomServer
  alias GovernanceCore.Rooms.EventTaxonomy

  @impl true
  def mount(_params, _session, socket) do
    stats = Agents.swarm_stats()
    agents = Agents.list_agents()
    rooms = Rooms.list_rooms()
    active_rooms = Enum.filter(rooms, &(&1.status == "active"))

    room_summaries =
      Enum.map(active_rooms, fn room ->
        server_state = safe_get_state(room.id)

        %{
          room: room,
          agent_count: map_size(server_state.agents),
          status: server_state.status,
          stats: Map.get(server_state, :stats, %{})
        }
      end)

    recent_events = fetch_recent_activity(10)

    recent_activity =
      recent_events
      |> Enum.map(fn event ->
        agent = Enum.find(agents, &(&1.id == event.agent_id))
        event_type = event.event_type || "unknown"

        %{
          id: event.id,
          type: classify_activity(event_type),
          persona: if(agent, do: agent.name, else: "Sistem"),
          persona_role: if(agent, do: agent.role, else: nil),
          text: EventTaxonomy.label(event_type),
          event_type: event_type,
          time: format_time_ago(event.inserted_at),
          room_id: event.room_id
        }
      end)

    {:ok,
     assign(socket,
       stats: stats,
       room_summaries: room_summaries,
       recent_activity: recent_activity,
       active_room_count: length(active_rooms),
       page_title: "Command Hub",
       current_path: "/"
     )}
  end

  defp classify_activity("agent_connected"), do: :persona_joined
  defp classify_activity("agent_disconnected"), do: :persona_left
  defp classify_activity("task_completed"), do: :task_completed
  defp classify_activity("task_failed"), do: :task_failed
  defp classify_activity("tool_call_completed"), do: :task_completed
  defp classify_activity("approval_requested"), do: :approval_needed
  defp classify_activity("approval_granted"), do: :task_completed
  defp classify_activity(_), do: :info

  defp format_time_ago(nil), do: "az önce"

  defp format_time_ago(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)

    cond do
      diff < 60 -> "#{diff}s önce"
      diff < 3600 -> "#{div(diff, 60)}m önce"
      diff < 86400 -> "#{div(diff, 3600)}s önce"
      true -> "#{div(diff, 86400)}g önce"
    end
  end

  defp fetch_recent_activity(limit) do
    import Ecto.Query

    GovernanceCore.Rooms.AgentEvent
    |> order_by(desc: :inserted_at)
    |> limit(^limit)
    |> GovernanceCore.Repo.all()
  rescue
    _ -> []
  end

  defp safe_get_state(room_id) do
    try do
      RoomServer.get_state(room_id)
    rescue
      _ -> %{agents: %{}, status: :unknown, stats: %{}}
    catch
      :exit, _ -> %{agents: %{}, status: :unknown, stats: %{}}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="swarm-hub" class="space-y-10">
      <section id="global-stats" class="grid grid-cols-1 md:grid-cols-4 gap-6">
        <div class="stats shadow bg-base-200 border border-base-content/5">
          <div class="stat">
            <div class="stat-title text-[10px] font-bold uppercase tracking-widest">
              Ajanlar
            </div>

            <div class="stat-value text-primary leading-none mt-2">{@stats.total}</div>

            <div class="stat-desc text-[10px] mt-1">{@stats.bots} bots / {@stats.humans} humans</div>
          </div>
        </div>

        <div class="stats shadow bg-base-200 border border-base-content/5">
          <div class="stat">
            <div class="stat-title text-[10px] font-bold uppercase tracking-widest">
              Aktif Odalar
            </div>

            <div class="stat-value text-secondary leading-none mt-2">{@active_room_count}</div>

            <div class="stat-desc text-[10px] mt-1 text-secondary">
              {length(@room_summaries)} oda çalışıyor
            </div>
          </div>
        </div>

        <div class="stats shadow bg-base-200 border border-base-content/5">
          <div class="stat">
            <div class="stat-title text-[10px] font-bold uppercase tracking-widest">
              Aktif Ajanlar
            </div>

            <div class="stat-value text-success leading-none mt-2">
              {@stats.active}
            </div>

            <div class="stat-desc text-[10px] mt-1">{@stats.total - @stats.active} pasif</div>
          </div>
        </div>

        <div class="stats shadow bg-base-200 border border-base-content/5">
          <div class="stat">
            <div class="stat-title text-[10px] font-bold uppercase tracking-widest">
              Ecospace Bakiye
            </div>

            <div class="stat-value leading-none mt-2">
              {@stats.spend_cents / 100} <span class="text-xs opacity-50">USDC</span>
            </div>

            <div class="stat-desc text-[10px] mt-1 text-warning">x402 protocol</div>
          </div>
        </div>
      </section>

      <section id="component-grid" class="space-y-4">
        <div class="flex items-center justify-between px-2">
          <h3 class="text-sm font-bold uppercase tracking-widest opacity-50 flex items-center gap-2">
            <.icon name="hero-cpu-chip" class="size-4" /> Odalar
          </h3>

          <.link navigate={~p"/rooms"} class="btn btn-xs btn-ghost">
            Tümünü Gör
          </.link>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <%= for summary <- @room_summaries do %>
            <.link
              navigate={~p"/rooms/#{summary.room.id}"}
              class="bg-base-200 p-4 rounded-xl border border-base-content/5 hover:border-primary/30 transition-colors block"
            >
              <div class="flex items-center justify-between mb-2">
                <span class="text-sm font-bold">{summary.room.name}</span>
                <span class={
                  "text-[8px] font-bold uppercase px-2 py-0.5 rounded-full " <>
                  case summary.status do
                    :active -> "bg-success/10 text-success"
                    :paused -> "bg-warning/10 text-warning"
                    :awaiting_approval -> "bg-error/10 text-error"
                    _ -> "bg-base-300 text-base-content/50"
                  end
                }>
                  {to_string(summary.status)}
                </span>
              </div>
              <div class="flex items-center gap-4 text-[10px] opacity-60">
                <span>{summary.agent_count} ajan</span>
                <span>{summary.room.status}</span>
              </div>
            </.link>
          <% end %>

          <%= if Enum.empty?(@room_summaries) do %>
            <div class="bg-base-300/30 p-4 rounded-xl border border-dashed border-base-content/10 flex flex-col items-center justify-center gap-2 col-span-full">
              <.icon name="hero-plus-circle" class="size-8 opacity-20" />
              <span class="text-xs opacity-40">Henüz aktif oda yok</span>
              <.link navigate={~p"/rooms"} class="btn btn-xs btn-primary mt-1">
                Oda Oluştur
              </.link>
            </div>
          <% end %>
        </div>
      </section>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-10">
        <section id="activity-feed" class="lg:col-span-2 space-y-6">
          <h3 class="text-sm font-bold uppercase tracking-widest opacity-50 px-2 flex items-center gap-2">
            <.icon name="hero-bolt" class="size-4" /> Son Olaylar
          </h3>

          <div class="space-y-4">
            <%= if Enum.empty?(@recent_activity) do %>
              <div class="p-6 rounded-xl bg-base-200 border border-base-content/5 text-center">
                <.icon name="hero-inbox" class="size-10 opacity-20 mx-auto mb-2" />
                <p class="text-sm opacity-40">Henüz olay kaydı yok</p>
                <p class="text-[10px] opacity-30 mt-1">Odalarda ajanlar çalıştıkça olaylar burada görünecek</p>
              </div>
            <% else %>
              <div
                :for={item <- @recent_activity}
                class="flex gap-4 p-4 rounded-xl bg-base-200 border border-base-content/5 hover:border-base-content/10 transition-colors"
              >
                <div class="flex-none">
                  <div class={[
                    "size-8 rounded-full flex items-center justify-center",
                    item.type == :task_completed && "bg-success/10 text-success",
                    item.type == :task_failed && "bg-error/10 text-error",
                    item.type == :persona_joined && "bg-info/10 text-info",
                    item.type == :persona_left && "bg-warning/10 text-warning",
                    item.type == :approval_needed && "bg-secondary/10 text-secondary",
                    item.type == :info && "bg-base-300 text-base-content/60"
                  ]}>
                    <.icon
                      name={
                        case item.type do
                          :task_completed -> "hero-check-circle"
                          :task_failed -> "hero-x-circle"
                          :persona_joined -> "hero-plus-circle"
                          :persona_left -> "hero-minus-circle"
                          :approval_needed -> "hero-shield-exclamation"
                          :info -> "hero-information-circle"
                        end
                      }
                      class="size-5"
                    />
                  </div>
                </div>

                <div class="flex-1 min-w-0">
                  <div class="flex items-center justify-between gap-2">
                    <div class="flex items-center gap-2 min-w-0">
                      <p class="text-sm font-bold tracking-tight truncate">{item.persona}</p>
                      <%= if item.persona_role do %>
                        <span class="text-[8px] px-1.5 py-0.5 rounded bg-base-300/50 opacity-50 font-mono flex-shrink-0">
                          {item.persona_role}
                        </span>
                      <% end %>
                    </div>
                    <span class="text-[10px] opacity-40 flex-shrink-0">{item.time}</span>
                  </div>

                  <p class="text-xs opacity-70 mt-0.5">{item.text}</p>
                </div>
              </div>
            <% end %>
          </div>
        </section>

        <section id="quick-links" class="space-y-6">
          <h3 class="text-sm font-bold uppercase tracking-widest opacity-50 px-2 flex items-center gap-2">
            <.icon name="hero-rocket-launch" class="size-4" /> Hızlı İşlemler
          </h3>

          <div class="flex flex-col gap-3">
            <.link
              navigate={~p"/rooms"}
              class="btn btn-block btn-lg bg-base-200 hover:bg-base-300 border-base-content/10 flex items-center justify-between gap-4"
            >
              <div class="flex items-center gap-4">
                <.icon name="hero-chat-bubble-left-right" class="size-6 opacity-50" />
                <div class="text-left">
                  <p class="text-sm font-black">Odalara Git</p>

                  <p class="text-[10px] opacity-50">Ajan iletişim merkezini aç</p>
                </div>
              </div>
              <.icon name="hero-chevron-right" class="size-4 opacity-50" />
            </.link>
            <.link
              navigate={~p"/agents/new"}
              class="btn btn-block btn-lg bg-base-200 hover:bg-base-300 border-base-content/10 flex items-center justify-between gap-4"
            >
              <div class="flex items-center gap-4">
                <.icon name="hero-plus-circle" class="size-6 opacity-50" />
                <div class="text-left">
                  <p class="text-sm font-black">Ajan Oluştur</p>

                  <p class="text-[10px] opacity-50">Yeni bot / insan kimliği yarat</p>
                </div>
              </div>
              <.icon name="hero-chevron-right" class="size-4 opacity-50" />
            </.link>
            <.link
              navigate={~p"/search"}
              class="btn btn-block btn-lg bg-base-200 hover:bg-base-300 border-base-content/10 flex items-center justify-between gap-4"
            >
              <div class="flex items-center gap-4">
                <.icon name="hero-magnifying-glass" class="size-6 opacity-50" />
                <div class="text-left">
                  <p class="text-sm font-black">Aran</p>

                  <p class="text-[10px] opacity-50">Ajan, görev ve log ara</p>
                </div>
              </div>
              <.icon name="hero-chevron-right" class="size-4 opacity-50" />
            </.link>
            <.link
              navigate={~p"/agents"}
              class="btn btn-block btn-lg bg-base-200 hover:bg-base-300 border-base-content/10 flex items-center justify-between gap-4"
            >
              <div class="flex items-center gap-4">
                <.icon name="hero-users" class="size-6 opacity-50" />
                <div class="text-left">
                  <p class="text-sm font-black">KADRO</p>

                  <p class="text-[10px] opacity-50">Tüm ajanları ve personaları görüntüle</p>
                </div>
              </div>
              <.icon name="hero-chevron-right" class="size-4 opacity-50" />
            </.link>
          </div>
        </section>
      </div>
    </div>
    """
  end
end
