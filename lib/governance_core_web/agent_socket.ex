defmodule GovernanceCoreWeb.AgentSocket do
  @moduledoc """
  WebSocket socket for agent room communication.

  Agents connect to topic "agent_room:{room_id}" and exchange
  MCP messages in real-time.

  Usage:
    socket "/agent", GovernanceCoreWeb.AgentSocket,
      websocket: true,
      connect_info: [session: @session_options]
  """

  use Phoenix.Socket

  channel "agent_room:*", GovernanceCoreWeb.AgentRoomChannel

  @impl true
  def id(_socket), do: nil
end
