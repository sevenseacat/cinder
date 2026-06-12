defmodule Cinder.ConnCase do
  @moduledoc """
  Case template for LiveView integration tests.
  """
  use ExUnit.CaseTemplate

  using do
    quote do
      import PhoenixTest
      import Cinder.Generator
      # For the ~H sigil used to supply Cinder.TestLive.Fixture's template.
      import Phoenix.Component

      @endpoint Cinder.TestEndpoint
    end
  end

  # Integration cases are `async: false`, so they run in isolation from the
  # `async: true` component tests. That lets us load Cinder data synchronously —
  # the rendered view reflects the query result on the first render, so tests
  # don't need to poll for async results. The async path itself is covered by
  # Cinder.Integration.AsyncLoadTest, which opts back in.
  setup {Cinder.TestHelpers, :disable_async_loading}

  setup _tags do
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
