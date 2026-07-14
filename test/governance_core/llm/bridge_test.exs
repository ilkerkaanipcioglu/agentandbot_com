defmodule GovernanceCore.LLM.BridgeTest do
  use GovernanceCore.DataCase, async: true

  alias GovernanceCore.LLM.Bridge

  describe "chat/3" do
    test "returns not_configured when ollama config missing" do
      result = Bridge.chat(:ollama, "hello", model: "test")
      assert {:error, :ollama_not_configured} = result
    end

    test "returns not_configured when openai config missing" do
      result = Bridge.chat(:openai, "hello", api_key: "test")
      assert {:error, :openai_not_configured} = result
    end

    test "returns not_configured when anthropic config missing" do
      result = Bridge.chat(:anthropic, "hello", api_key: "test")
      assert {:error, :anthropic_not_configured} = result
    end
  end

  describe "available_providers/0" do
    test "returns list" do
      providers = Bridge.available_providers()
      assert is_list(providers)
    end
  end

  describe "summarize/2" do
    test "delegates to chat with summarization prompt" do
      result = Bridge.summarize(:ollama, "test content")
      assert {:error, :ollama_not_configured} = result
    end
  end
end
