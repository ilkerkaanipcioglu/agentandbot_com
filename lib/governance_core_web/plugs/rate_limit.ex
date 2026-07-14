defmodule GovernanceCoreWeb.Plugs.RateLimit do
  @moduledoc """
  Token-bucket rate limiter plug for API endpoints.

  Uses ETS-backed counters per client identity (IP or API key).
  Configurable max_requests and window_seconds via options.

  Options:
    - max_requests: integer (default 60)
    - window_seconds: integer (default 60)
  """
  import Plug.Conn
  import Phoenix.Controller

  @table :api_rate_limits

  def init(opts) do
    %{
      max_requests: Keyword.get(opts, :max_requests, 60),
      window_seconds: Keyword.get(opts, :window_seconds, 60)
    }
  end

  def call(conn, opts) do
    ensure_table()
    client_id = client_identity(conn)
    now = System.system_time(:second)
    window = opts.window_seconds

    case :ets.lookup(@table, client_id) do
      [{^client_id, count, window_start}] when now - window_start < window ->
        if count >= opts.max_requests do
          conn
          |> put_status(:too_many_requests)
          |> put_resp_header("x-ratelimit-limit", to_string(opts.max_requests))
          |> put_resp_header("x-ratelimit-remaining", "0")
          |> put_resp_header("x-ratelimit-reset", to_string(window_start + window))
          |> json(%{error: "Rate limit exceeded"})
          |> halt()
        else
          :ets.insert(@table, {client_id, count + 1, window_start})

          conn
          |> put_resp_header("x-ratelimit-limit", to_string(opts.max_requests))
          |> put_resp_header("x-ratelimit-remaining", to_string(opts.max_requests - count - 1))
          |> put_resp_header("x-ratelimit-reset", to_string(window_start + window))
        end

      _ ->
        :ets.insert(@table, {client_id, 1, now})

        conn
        |> put_resp_header("x-ratelimit-limit", to_string(opts.max_requests))
        |> put_resp_header("x-ratelimit-remaining", to_string(opts.max_requests - 1))
        |> put_resp_header("x-ratelimit-reset", to_string(now + window))
    end
  end

  defp client_identity(conn) do
    case conn.assigns[:api_key] do
      nil -> remote_ip(conn) |> to_string()
      key -> "key:#{key}"
    end
  end

  defp remote_ip(conn) do
    conn.remote_ip
    |> Tuple.to_list()
    |> Enum.join(".")
  end

  defp ensure_table do
    try do
      :ets.new(@table, [:set, :public, :named_table])
    rescue
      ArgumentError -> :ok
    end
  end
end
