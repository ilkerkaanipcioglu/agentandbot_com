defmodule GovernanceCore.Rooms.EventTaxonomyTest do
  use ExUnit.Case, async: true

  alias GovernanceCore.Rooms.EventTaxonomy

  describe "classify/1" do
    test "classifies initialize" do
      assert "agent_connected" = EventTaxonomy.classify(%{"method" => "initialize"})
    end

    test "classifies tools/call" do
      assert "tool_call_started" = EventTaxonomy.classify(%{"method" => "tools/call"})
    end

    test "classifies task/complete" do
      assert "task_completed" = EventTaxonomy.classify(%{"method" => "task/complete"})
    end

    test "classifies result payload" do
      assert "tool_call_completed" = EventTaxonomy.classify(%{"result" => %{}})
    end

    test "classifies error payload" do
      assert "tool_call_failed" = EventTaxonomy.classify(%{"error" => %{}})
    end

    test "classifies unknown method" do
      assert "action_custom_method" = EventTaxonomy.classify(%{"method" => "custom_method"})
    end

    test "classifies non-map" do
      assert "unknown" = EventTaxonomy.classify("string")
    end
  end

  describe "terminal?/1" do
    test "task_completed is terminal" do
      assert EventTaxonomy.terminal?("task_completed")
    end

    test "tool_call_started is not terminal" do
      refute EventTaxonomy.terminal?("tool_call_started")
    end
  end

  describe "label/1" do
    test "returns Turkish labels" do
      assert "Ajan bağlandı" = EventTaxonomy.label("agent_connected")
      assert "Görev tamamlandı" = EventTaxonomy.label("task_completed")
      assert "Araç çağrıldı" = EventTaxonomy.label("tool_call_started")
    end

    test "returns event type for unknown events" do
      assert "some_custom_event" = EventTaxonomy.label("some_custom_event")
    end
  end

  describe "mcp_event_types/0" do
    test "returns non-empty list" do
      types = EventTaxonomy.mcp_event_types()
      assert length(types) > 10
    end
  end
end
