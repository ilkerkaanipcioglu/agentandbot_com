defmodule GovernanceCoreWeb.HealthController do
  use GovernanceCoreWeb, :controller

  alias GovernanceCore.Repo

  def check(conn, _params) do
    json(conn, %{
      status: "ok",
      version: version(),
      time: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  def live(conn, _params) do
    db_ok = repo_alive?()

    conn
    |> put_status(if(db_ok, do: 200, else: 503))
    |> json(%{
      status: if(db_ok, do: "ok", else: "degraded"),
      database: if(db_ok, do: "connected", else: "unreachable"),
      version: version()
    })
  end

  def ready(conn, _params) do
    db_ok = repo_alive?()
    pubsub_ok = pubsub_alive?()

    all_ok = db_ok and pubsub_ok

    conn
    |> put_status(if(all_ok, do: 200, else: 503))
    |> json(%{
      status: if(all_ok, do: "ready", else: "not_ready"),
      checks: %{
        database: if(db_ok, do: "pass", else: "fail"),
        pubsub: if(pubsub_ok, do: "pass", else: "fail")
      },
      version: version()
    })
  end

  defp repo_alive? do
    try do
      Repo.query("SELECT 1")
      true
    rescue
      _ -> false
    end
  end

  defp pubsub_alive? do
    try do
      Phoenix.PubSub.broadcast(GovernanceCore.PubSub, "health:ping", :health_pong)
      true
    rescue
      _ -> false
    end
  end

  defp version do
    Application.spec(:governance_core)[:vsn] |> to_string()
  end
end
