defmodule GovernanceCore.LLM.OllamaAdapter do
  @moduledoc """
  Ollama API adapter for local LLM inference.
  """

  @spec chat(String.t(), String.t(), String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def chat(base_url, model, prompt, opts \\ []) when is_binary(base_url) and is_binary(model) do
    system = Keyword.get(opts, :system)
    url = "#{String.trim_trailing(base_url, "/")}/api/chat"

    messages = build_messages(prompt, system)

    body = %{
      model: model,
      messages: messages,
      stream: false
    }

    case Req.post(url, json: body, receive_timeout: 60_000) do
      {:ok, %Req.Response{status: 200, body: resp}} ->
        content = get_in(resp, ["message", "content"]) || ""
        {:ok, String.trim(content)}

      {:ok, %Req.Response{status: status, body: resp}} ->
        {:error, {:ollama_error, status, resp}}

      {:error, reason} ->
        {:error, {:ollama_unreachable, reason}}
    end
  end

  defp build_messages(prompt, nil), do: [%{role: "user", content: prompt}]
  defp build_messages(prompt, system) do
    [%{role: "system", content: system}, %{role: "user", content: prompt}]
  end
end
