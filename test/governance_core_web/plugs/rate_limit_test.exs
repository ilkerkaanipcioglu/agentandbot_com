defmodule GovernanceCoreWeb.Plugs.RateLimitTest do
  use GovernanceCoreWeb.ConnCase, async: true

  alias GovernanceCoreWeb.Plugs.RateLimit

  describe "rate limiting" do
    test "allows requests under limit", %{conn: conn} do
      opts = RateLimit.init(max_requests: 5, window_seconds: 60)

      conn =
        conn
        |> RateLimit.call(opts)

      refute conn.halted
      remaining = get_resp_header(conn, "x-ratelimit-remaining") |> List.first()
      assert remaining == "4"
    end

    test "blocks requests over limit", %{conn: conn} do
      opts = RateLimit.init(max_requests: 3, window_seconds: 60)

      conn =
        Enum.reduce(1..4, conn, fn _i, acc ->
          RateLimit.call(acc, opts)
        end)

      assert conn.halted
      assert conn.status == 429
    end

    test "uses api_key as identity when assigned", %{conn: conn} do
      opts = RateLimit.init(max_requests: 2, window_seconds: 60)

      conn1 =
        conn
        |> assign(:api_key, "key_aaa")
        |> RateLimit.call(opts)

      conn2 =
        build_conn()
        |> assign(:api_key, "key_bbb")
        |> RateLimit.call(opts)

      refute conn1.halted
      refute conn2.halted
    end
  end
end
