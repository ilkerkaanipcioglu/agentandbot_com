defmodule GovernanceCoreWeb.Api.LLMController do
  use GovernanceCoreWeb, :controller

  alias GovernanceCore.LLM.Bridge

  def providers(conn, _params) do
    providers = Bridge.available_providers()
    default = Application.get_env(:governance_core, :llm, []) |> Keyword.get(:default_provider)

    json(conn, %{
      data: providers,
      meta: %{
        default: to_string(default),
        api_version: "v1"
      }
    })
  end

  def status(conn, _params) do
    config = Application.get_env(:governance_core, :llm, [])
    default = Keyword.get(config, :default_provider, "none")

    health =
      case default do
        "ollama" ->
          check_ollama(config)

        "openai" ->
          check_openai(config)

        "anthropic" ->
          check_anthropic(config)

        _ ->
          %{provider: default, status: "not_configured"}
      end

    json(conn, %{
      data: health
    })
  end

  @valid_providers ~w(ollama openai anthropic)

  def chat(conn, params) do
    provider_str = Map.get(params, "provider")
    prompt = Map.get(params, "prompt", "")
    model = Map.get(params, "model")
    system = Map.get(params, "system")

    if prompt == "" do
      conn
      |> put_status(:bad_request)
      |> json(%{error: "prompt required"})
    else
      provider = parse_provider(provider_str)

      if is_nil(provider) do
        conn
        |> put_status(:bad_request)
        |> json(%{error: "invalid provider, use: ollama, openai, anthropic"})
      else
        opts =
          [system: system]
          |> Keyword.put(:model, model)
          |> Enum.reject(fn {_k, v} -> is_nil(v) end)

        case Bridge.chat(provider, prompt, opts) do
          {:ok, response} ->
            json(conn, %{data: %{response: response, provider: to_string(provider)}})

          {:error, reason} ->
            conn
            |> put_status(:bad_gateway)
            |> json(%{error: to_string(reason)})
        end
      end
    end
  end

  defp parse_provider(nil), do: nil
  defp parse_provider(str) when str in @valid_providers, do: String.to_atom(str)
  defp parse_provider(_), do: nil

  defp check_ollama(config) do
    base_url = get_in(config, [:providers, :ollama, :base_url]) || "http://localhost:11434"
    url = "#{String.trim_trailing(base_url, "/")}/api/tags"

    case Req.get(url, receive_timeout: 5_000) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        models =
          body
          |> Map.get("models", [])
          |> Enum.map(& &1["name"])
          |> Enum.take(5)

        %{provider: "ollama", status: "connected", models: models}

      _ ->
        %{provider: "ollama", status: "unreachable"}
    end
  end

  defp check_openai(config) do
    api_key = resolve_api_key(get_in(config, [:providers, :openai, :api_key]))
    has_key = api_key != ""

    %{provider: "openai", status: if(has_key, do: "configured", else: "no_api_key")}
  end

  defp check_anthropic(config) do
    api_key = resolve_api_key(get_in(config, [:providers, :anthropic, :api_key]))
    has_key = api_key != ""

    %{provider: "anthropic", status: if(has_key, do: "configured", else: "no_api_key")}
  end

  defp resolve_api_key({:system, env_var}), do: System.get_env(env_var, "")
  defp resolve_api_key(key) when is_binary(key), do: key
  defp resolve_api_key(_), do: ""
end
