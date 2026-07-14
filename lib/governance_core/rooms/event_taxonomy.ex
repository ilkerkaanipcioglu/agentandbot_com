defmodule GovernanceCore.Rooms.EventTaxonomy do
  @moduledoc """
  Standardized event taxonomy for agent communication.

  Maps MCP methods and payload patterns to human-readable event types
  used across PubSub, tracing, and A2A protocol.
  """

  @type event_type :: String.t()

  @mcp_events %{
    "initialize" => "agent_connected",
    "initialized" => "agent_ready",
    "notifications/initialized" => "agent_ready",
    "ping" => "heartbeat",
    "tools/list" => "tools_requested",
    "tools/call" => "tool_call_started",
    "tools/cancel" => "tool_call_cancelled",
    "prompts/list" => "prompts_requested",
    "prompts/get" => "prompt_retrieved",
    "resources/list" => "resources_requested",
    "resources/read" => "resource_read",
    "resources/subscribe" => "resource_subscribed",
    "completion/complete" => "completion_generated",
    "logging/setLevel" => "log_level_changed",
    "sampling/createMessage" => "sampling_requested"
  }

  @task_events %{
    "task/launch" => "task_launched",
    "task/complete" => "task_completed",
    "task/fail" => "task_failed",
    "task/cancel" => "task_cancelled",
    "task/progress" => "task_progress",
    "delegated_task" => "task_delegated"
  }

  @doc """
  Classifies an MCP payload into a standardized event type.
  """
  @spec classify(map()) :: event_type()
  def classify(payload) when is_map(payload) do
    cond do
      method = Map.get(payload, "method") ->
        Map.get(@mcp_events, method) || Map.get(@task_events, method) || "action_#{method}"

      Map.has_key?(payload, "result") ->
        "tool_call_completed"

      Map.has_key?(payload, "error") ->
        "tool_call_failed"

      Map.has_key?(payload, "content") ->
        "content_delivered"

      true ->
        "mcp_message"
    end
  end

  def classify(_), do: "unknown"

  @doc """
  Returns all known MCP event types.
  """
  @spec mcp_event_types() :: [{String.t(), event_type()}]
  def mcp_event_types, do: Map.to_list(@mcp_events)

  @doc """
  Returns all known task event types.
  """
  @spec task_event_types() :: [{String.t(), event_type()}]
  def task_event_types, do: Map.to_list(@task_events)

  @doc """
  Checks if an event type is terminal (no further action expected).
  """
  @spec terminal?(event_type()) :: boolean()
  def terminal?(event) do
    event in [
      "task_completed",
      "task_failed",
      "task_cancelled",
      "tool_call_completed",
      "tool_call_failed",
      "tool_call_cancelled",
      "agent_disconnected"
    ]
  end

  @doc """
  Returns human-readable label for an event type (Turkish).
  """
  @spec label(event_type()) :: String.t()
  def label("agent_connected"), do: "Ajan bağlandı"
  def label("agent_ready"), do: "Ajan hazır"
  def label("heartbeat"), do: "Kalp atışı"
  def label("tools_requested"), do: "Araçlar listelendi"
  def label("tool_call_started"), do: "Araç çağrıldı"
  def label("tool_call_completed"), do: "Araç tamamlandı"
  def label("tool_call_failed"), do: "Araç hata verdi"
  def label("tool_call_cancelled"), do: "Araç iptal edildi"
  def label("task_launched"), do: "Görev başlatıldı"
  def label("task_completed"), do: "Görev tamamlandı"
  def label("task_failed"), do: "Görev başarısız"
  def label("task_cancelled"), do: "Görev iptal edildi"
  def label("task_progress"), do: "Görev ilerliyor"
  def label("task_delegated"), do: "Görev devredildi"
  def label("content_delivered"), do: "İçerik iletildi"
  def label("agent_disconnected"), do: "Ajan ayrıldı"
  def label(other), do: other
end
