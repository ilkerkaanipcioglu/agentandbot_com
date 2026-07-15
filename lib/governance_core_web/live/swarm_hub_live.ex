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
       current_path: "/dashboard"
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

  defp format_time_ago(nil), do: "az \u00F6nce"

  defp format_time_ago(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)

    cond do
      diff < 60 -> "#{diff}s \u00F6nce"
      diff < 3600 -> "#{div(diff, 60)}m \u00F6nce"
      diff < 86400 -> "#{div(diff, 3600)}s \u00F6nce"
      true -> "#{div(diff, 86400)}g \u00F6nce"
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
    <div id="swarm-hub" class="space-y-8">
      <%!-- STATS ROW --%>
      <section id="global-stats" class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <.stat_card
          icon="hero-robot"
          label="Ajanlar"
          value={@stats.total}
          detail={"{@stats.bots} bots / {@stats.humans} humans"}
          color="primary"
        />

        <.stat_card
          icon="hero-chat-bubble-left-right"
          label="Aktif Odalar"
          value={@active_room_count}
          detail="{length(@room_summaries)} oda \u00E7al\u0131\u015F\u0131yor"
          color="secondary"
        />

        <.stat_card
          icon="hero-signal"
          label="Aktif Ajanlar"
          value={@stats.active}
          detail="{@stats.total - @stats.active} pasif"
          color="accent"
        />

        <.stat_card
          icon="hero-currency-dollar"
          label="Ecospace Bakiye"
          value={format_currency(@stats.spend_cents)}
          detail="x402 protocol"
          color="success"
        />
      </section>

      <%!-- ROOMS + ACTIVITY GRID --%>
      <div class="grid grid-cols-1 lg:grid-cols-5 gap-6">
        <%!-- ROOMS (2 cols) --%>
        <section class="lg:col-span-2 space-y-4">
          <div class="flex items-center justify-between">
            <h3 class="text-sm font-bold uppercase tracking-wider text-base-content/50 flex items-center gap-2">
              <.icon name="hero-cpu-chip" class="size-4" /> Odalar
            </h3>

            <.link navigate={~p"/rooms"} class="btn btn-xs btn-ghost">
              T&uuml;m&uuml;n&uuml; G&ouml;r
            </.link>
          </div>

          <div class="space-y-3">
            <%= for summary <- @room_summaries do %>
              <.link
                navigate={~p"/rooms/#{summary.room.id}"}
                class="group block bg-base-200 p-4 rounded-xl border border-base-content/5 hover:border-primary/30 transition-all hover:shadow-lg"
              >
                <div class="flex items-center justify-between mb-1">
                  <span class="text-sm font-bold group-hover:text-primary transition-colors">
                    {summary.room.name}
                  </span>
                  <span class={
                    "text-[9px] font-bold uppercase px-2 py-0.5 rounded-full " <>
                    status_classes(summary.status)
                  }>
                    {to_string(summary.status)}
                  </span>
                </div>

                <div class="flex items-center gap-3 text-[10px] text-base-content/40">
                  <span>{summary.agent_count} ajan</span>
                  <span class="w-0.5 h-0.5 rounded-full bg-base-content/20"></span>
                  <span>{summary.room.status}</span>
                </div>
              </.link>
            <% end %>

            <%= if Enum.empty?(@room_summaries) do %>
              <div class="p-8 rounded-xl bg-base-200/50 border border-dashed border-base-content/10 flex flex-col items-center justify-center gap-3">
                <.icon name="hero-plus-circle" class="size-10 text-base-content/15" />
                <span class="text-xs text-base-content/30">Hen&uuml;z aktif oda yok</span>
                <.link navigate={~p"/rooms"} class="btn btn-xs btn-primary">
                  Oda Olu\u015Ftur
                </.link>
              </div>
            <% end %>
          </div>
        </section>

        <%!-- ACTIVITY FEED (3 cols) --%>
        <section class="lg:col-span-3 space-y-4">
          <h3 class="text-sm font-bold uppercase tracking-wider text-base-content/50 flex items-center gap-2">
            <.icon name="hero-bolt" class="size-4" /> Son Olaylar
          </h3>

          <div class="space-y-2">
            <%= if Enum.empty?(@recent_activity) do %>
              <div class="p-8 rounded-xl bg-base-200/50 border border-base-content/5 text-center">
                <.icon name="hero-inbox" class="size-10 text-base-content/15 mx-auto mb-2" />
                <p class="text-sm text-base-content/30">Hen&uuml;z olay kayd\u0131 yok</p>
                <p class="text-[10px] text-base-content/20 mt-1">
                  Odalarda ajanlar &ccedil;al\u0131\u015Ft\u0131k&ccedil;a olaylar burada g&ouml;r&uuml;necek
                </p>
              </div>
            <% else %>
              <div class="space-y-2">
                <div
                  :for={item <- @recent_activity}
                  class="flex gap-3 p-3 rounded-lg bg-base-200/50 border border-transparent hover:border-base-content/5 transition-all group"
                >
                  <div class="flex-none">
                    <div class={[
                      "size-7 rounded-lg flex items-center justify-center text-xs",
                      activity_icon_bg(item.type)
                    ]}>
                      <.icon
                        name={activity_icon(item.type)}
                        class="size-4"
                      />
                    </div>
                  </div>

                  <div class="flex-1 min-w-0">
                    <div class="flex items-center justify-between gap-2">
                      <div class="flex items-center gap-2 min-w-0">
                        <span class="text-xs font-semibold truncate">{item.persona}</span>
                        <%= if item.persona_role do %>
                          <span class="text-[8px] px-1.5 py-0.5 rounded bg-base-300/40 text-base-content/40 font-mono flex-shrink-0">
                            {item.persona_role}
                          </span>
                        <% end %>
                      </div>
                      <span class="text-[10px] text-base-content/30 flex-shrink-0">{item.time}</span>
                    </div>

                    <p class="text-[11px] text-base-content/50 mt-0.5">{item.text}</p>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </section>
      </div>

      <%!-- QUICK ACTIONS --%>
      <section class="grid grid-cols-2 sm:grid-cols-4 gap-3">
        <.quick_action
          icon="hero-chat-bubble-left-right"
          title="Odalara Git"
          desc="Ajan ileti\u015Fim merkezini a&ccedil;"
          href={~p"/rooms"}
        />

        <.quick_action
          icon="hero-plus-circle"
          title="Ajan Olu\u015Ftur"
          desc="Yeni bot / insan kimli\u011Fi yarat"
          href={~p"/agents/new"}
        />

        <.quick_action
          icon="hero-magnifying-glass"
          title="Ara"
          desc="Ajan, g&ouml;rev ve log ara"
          href={~p"/search"}
        />

        <.quick_action
          icon="hero-user-group"
          title="KADRO"
          desc="T&uuml;m ajanlar\u0131 g&ouml;r&uuml;nt&uuml;le"
          href={~p"/agents"}
        />
      </section>
    </div>
    """
  end

  attr(:icon, :string, required: true)
  attr(:label, :string, required: true)
  attr(:value, :any, required: true)
  attr(:detail, :string, required: true)
  attr(:color, :string, required: true)

  defp stat_card(assigns) do
    ~H"""
    <div class="bg-base-200 rounded-xl border border-base-content/5 p-5 hover:border-base-content/10 transition-colors">
      <div class="flex items-center justify-between mb-3">
        <span class="text-[10px] font-bold uppercase tracking-widest text-base-content/40">
          {@label}
        </span>
        <div class={"size-7 rounded-lg flex items-center justify-center bg-#{@color}/10 text-#{@color}"}>
          <.icon name={@icon} class="size-4" />
        </div>
      </div>

      <div class={"text-2xl font-black tracking-tight text-#{@color}"}>{@value}</div>

      <div class="text-[10px] text-base-content/40 mt-1">{@detail}</div>
    </div>
    """
  end

  attr(:icon, :string, required: true)
  attr(:title, :string, required: true)
  attr(:desc, :string, required: true)
  attr(:href, :string, required: true)

  defp quick_action(assigns) do
    ~H"""
    <.link
      navigate={@href}
      class="group flex items-center gap-3 p-4 rounded-xl bg-base-200 border border-base-content/5 hover:border-primary/20 hover:bg-base-300/50 transition-all"
    >
      <div class="size-9 rounded-lg bg-base-content/5 group-hover:bg-primary/10 flex items-center justify-center transition-colors">
        <.icon name={@icon} class="size-5 text-base-content/40 group-hover:text-primary transition-colors" />
      </div>

      <div class="min-w-0">
        <p class="text-xs font-bold truncate">{@title}</p>

        <p class="text-[10px] text-base-content/40 truncate">{@desc}</p>
      </div>
    </.link>
    """
  end

  defp format_currency(cents) when is_number(cents) do
    value = cents / 100
    "#{:erlang.float_to_binary(value, decimals: 2)} USDC"
  end

  defp format_currency(_), do: "0.00 USDC"

  defp status_classes(:active), do: "bg-success/10 text-success"
  defp status_classes(:paused), do: "bg-warning/10 text-warning"
  defp status_classes(:awaiting_approval), do: "bg-error/10 text-error"
  defp status_classes(_), do: "bg-base-300 text-base-content/40"

  defp activity_icon(:task_completed), do: "hero-check-circle"
  defp activity_icon(:task_failed), do: "hero-x-circle"
  defp activity_icon(:persona_joined), do: "hero-plus-circle"
  defp activity_icon(:persona_left), do: "hero-minus-circle"
  defp activity_icon(:approval_needed), do: "hero-shield-exclamation"
  defp activity_icon(:info), do: "hero-information-circle"

  defp activity_icon_bg(:task_completed), do: "bg-success/10 text-success"
  defp activity_icon_bg(:task_failed), do: "bg-error/10 text-error"
  defp activity_icon_bg(:persona_joined), do: "bg-info/10 text-info"
  defp activity_icon_bg(:persona_left), do: "bg-warning/10 text-warning"
  defp activity_icon_bg(:approval_needed), do: "bg-secondary/10 text-secondary"
  defp activity_icon_bg(:info), do: "bg-base-300 text-base-content/40"
end
