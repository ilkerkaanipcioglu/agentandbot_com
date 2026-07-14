defmodule GovernanceCore.LLM.OpenAIAdapter do
  @moduledoc """
  OpenAI Chat Completions API adapter.
  """

  @spec chat(String.t(), String.t(), String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def chat(base_url, model, prompt, opts \\ []) when is_binary(base_url) and is_binary(model) do
    api_key = Keyword.get(opts, :api_key, "")
    system = Keyword.get(opts, :system)

    url = "#{String.trim_trailing(base_url, "/")}/chat/completions"

    messages = build_messages(prompt, system)

    body = %{
      model: model,
      messages: messages,
      max_tokens: 512
    }

    headers =
      [{"Authorization", "Bearer #{api_key}"}]

    case Req.post(url, json: body, headers: headers, receive_timeout: 60_000) do
      {:ok, %Req.Response{status: 200, body: resp}} ->
        content =
          resp
          |> get_in(["choices", Access.at(0), "message", "content"]) || ""

        {:ok, String.trim(content)}

      {:ok, %Req.Response{status: status, body: resp}} ->
        {:error, {:openai_error, status, resp}}

      {:error, reason} ->
        {:error, {:openai_unreachable, reason}}
    end
  end

  defp build_messages(prompt, nil), do: [%{role: "user", content: prompt}]
  defp build_messages(prompt, system) do
    [%{role: "system", content: system}, %{role: "user", content: prompt}]
  end
end
