defmodule GovernanceCore.LLM.AnthropicAdapter do
  @moduledoc """
  Anthropic Messages API adapter.
  """

  @spec chat(String.t(), String.t(), String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def chat(base_url, model, prompt, opts \\ []) when is_binary(base_url) and is_binary(model) do
    api_key = Keyword.get(opts, :api_key, "")
    system = Keyword.get(opts, :system)

    url = "#{String.trim_trailing(base_url, "/")}/v1/messages"

    body =
      %{
        model: model,
        max_tokens: 512,
        messages: [%{role: "user", content: prompt}]
      }
      |> maybe_add_system(system)

    headers =
      [
        {"x-api-key", api_key},
        {"anthropic-version", "2023-06-01"},
        {"content-type", "application/json"}
      ]

    case Req.post(url, json: body, headers: headers, receive_timeout: 60_000) do
      {:ok, %Req.Response{status: 200, body: resp}} ->
        content =
          resp
          |> get_in(["content", Access.at(0), "text"]) || ""

        {:ok, String.trim(content)}

      {:ok, %Req.Response{status: status, body: resp}} ->
        {:error, {:anthropic_error, status, resp}}

      {:error, reason} ->
        {:error, {:anthropic_unreachable, reason}}
    end
  end

  defp maybe_add_system(body, nil), do: body
  defp maybe_add_system(body, system), do: Map.put(body, :system, system)
end
