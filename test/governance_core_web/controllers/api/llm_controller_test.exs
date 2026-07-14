defmodule GovernanceCoreWeb.Api.LLMControllerTest do
  use GovernanceCoreWeb.ConnCase, async: true

  describe "GET /api/llm/providers" do
    test "returns available providers list", %{conn: conn} do
      conn = get(conn, ~p"/api/llm/providers")

      assert %{"data" => providers, "meta" => %{"default" => default}} = json_response(conn, 200)
      assert is_list(providers)
      assert default in ["ollama", "openai", "anthropic"]
    end
  end

  describe "GET /api/llm/status" do
    test "returns provider health status", %{conn: conn} do
      conn = get(conn, ~p"/api/llm/status")

      assert %{"data" => health} = json_response(conn, 200)
      assert Map.has_key?(health, "provider")
      assert Map.has_key?(health, "status")
    end
  end

  describe "POST /api/llm/chat" do
    test "returns error when prompt is empty", %{conn: conn} do
      conn = post(conn, ~p"/api/llm/chat", %{"prompt" => ""})

      assert %{"error" => "prompt required"} = json_response(conn, 400)
    end

    test "returns error when no prompt provided", %{conn: conn} do
      conn = post(conn, ~p"/api/llm/chat", %{})

      assert %{"error" => "prompt required"} = json_response(conn, 400)
    end

    test "returns error when provider not configured", %{conn: conn} do
      conn =
        post(conn, ~p"/api/llm/chat", %{
          "prompt" => "hello",
          "provider" => "nonexistent"
        })

      assert %{"error" => _reason} = json_response(conn, 400)
    end
  end
end
