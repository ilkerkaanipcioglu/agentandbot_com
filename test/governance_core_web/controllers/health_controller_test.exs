defmodule GovernanceCoreWeb.HealthControllerTest do
  use GovernanceCoreWeb.ConnCase, async: true

  describe "GET /health" do
    test "returns ok status", %{conn: conn} do
      conn = get(conn, "/health/")

      assert %{"status" => "ok", "version" => _} = json_response(conn, 200)
    end
  end

  describe "GET /health/live" do
    test "returns database status", %{conn: conn} do
      conn = get(conn, "/health/live")

      assert %{"database" => db_status} = json_response(conn, 200)
      assert db_status in ["connected", "unreachable"]
    end
  end

  describe "GET /health/ready" do
    test "returns readiness check", %{conn: conn} do
      conn = get(conn, "/health/ready")

      assert %{"checks" => checks} = json_response(conn, 200)
      assert Map.has_key?(checks, "database")
      assert Map.has_key?(checks, "pubsub")
    end
  end
end
