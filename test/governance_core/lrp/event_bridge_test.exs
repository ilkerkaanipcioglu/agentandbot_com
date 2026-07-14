defmodule GovernanceCore.LRP.EventBridgeTest do
  use ExUnit.Case, async: true

  alias GovernanceCore.LRP.EventBridge

  describe "available?/0" do
    test "returns false when LRP not configured" do
      refute EventBridge.available?()
    end
  end

  describe "forward_event/1" do
    test "returns :ok when LRP not configured" do
      event = %{
        id: "test-1",
        from_type: "agent",
        payload: %{"method" => "tools/call", "params" => %{"name" => "test"}},
        inserted_at: DateTime.utc_now()
      }

      assert :ok = EventBridge.forward_event(event)
    end
  end
end
