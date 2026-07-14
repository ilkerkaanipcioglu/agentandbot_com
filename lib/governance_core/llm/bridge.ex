defmodule GovernanceCore.LLM.Bridge do
  @moduledoc """
  Multi-provider LLM bridge for agent summarization and tool responses.

  Supports Ollama (local), OpenAI, and Anthropic via a unified interface.
  Provider is selected via application config or per-request override.

  ## Usage

      iex> GovernanceCore.LLM.Bridge.chat("ollama", "Summarize: hello world")
      {:ok, "Summary: hello world"}

      iex> GovernanceCore.LLM.Bridge.chat("openai", "Translate to Turkish: hello")
      {:ok, "merhaba"}
  """

  alias GovernanceCore.LLM.{OllamaAdapter, OpenAIAdapter, AnthropicAdapter}

  @type provider :: :ollama | :openai | :anthropic
  @type result :: {:ok, String.t()} | {:error, term()}

  @spec chat(provider(), String.t(), keyword()) :: result()
  def chat(provider \\ nil, prompt, opts \\ [])

  def chat(nil, prompt, opts) do
    default = Application.get_env(:governance_core, :llm)[:default_provider] || :ollama
    chat(default, prompt, opts)
  end

  def chat(:ollama, prompt, opts) do
    config = get_provider_config(:ollama)
    model = Keyword.get(opts, :model, config[:model])
    system = Keyword.get(opts, :system)

    base_url = config[:base_url]

    if is_binary(base_url) and is_binary(model) do
      OllamaAdapter.chat(base_url, model, prompt, system: system)
    else
      {:error, :ollama_not_configured}
    end
  end

  def chat(:openai, prompt, opts) do
    config = get_provider_config(:openai)
    model = Keyword.get(opts, :model, config[:model])
    api_key = resolve_api_key(config[:api_key])
    system = Keyword.get(opts, :system)

    base_url = config[:base_url]

    if is_binary(base_url) and is_binary(model) do
      OpenAIAdapter.chat(base_url, model, prompt,
        api_key: api_key,
        system: system
      )
    else
      {:error, :openai_not_configured}
    end
  end

  def chat(:anthropic, prompt, opts) do
    config = get_provider_config(:anthropic)
    model = Keyword.get(opts, :model, config[:model])
    api_key = resolve_api_key(config[:api_key])
    system = Keyword.get(opts, :system)

    base_url = config[:base_url]

    if is_binary(base_url) and is_binary(model) do
      AnthropicAdapter.chat(base_url, model, prompt,
        api_key: api_key,
        system: system
      )
    else
      {:error, :anthropic_not_configured}
    end
  end

  @spec summarize(provider(), String.t()) :: result()
  def summarize(provider \\ nil, text) do
    system = "You are a concise summarizer. Summarize the given text in 1-2 sentences."
    chat(provider, "Summarize this: #{text}", system: system)
  end

  @spec available_providers() :: [map()]
  def available_providers do
    config = Application.get_env(:governance_core, :llm, [])

    config
    |> Keyword.get(:providers, %{})
    |> Enum.map(fn {name, settings} ->
      %{
        name: to_string(name),
        model: settings[:model],
        base_url: String.replace_trailing(settings[:base_url] || "", "/", "")
      }
    end)
  end

  defp get_provider_config(provider) do
    :governance_core
    |> Application.get_env(:llm, [])
    |> Keyword.get(:providers, %{})
    |> Map.get(provider, %{})
  end

  defp resolve_api_key({:system, env_var}) do
    System.get_env(env_var) || ""
  end

  defp resolve_api_key(key) when is_binary(key), do: key
  defp resolve_api_key(_), do: ""
end
