defmodule GovernanceCoreWeb.ChannelCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      import Phoenix.ChannelTest
      import GovernanceCoreWeb.ChannelCase

      @endpoint GovernanceCoreWeb.Endpoint
    end
  end

  setup tags do
    GovernanceCore.DataCase.setup_sandbox(tags)
    :ok
  end
end
