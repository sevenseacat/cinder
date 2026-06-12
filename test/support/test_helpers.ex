defmodule Cinder.TestHelpers do
  @moduledoc """
  Shared helpers for Cinder's test suite.
  """

  @doc """
  Disables Cinder's async data loading for the duration of a test, restoring the
  previous value afterward. Designed to be used as an ExUnit setup callback:

      setup {Cinder.TestHelpers, :disable_async_loading}

  With async loading off, `Cinder.LiveComponent.load_data/1` runs the query
  inline, so a rendered view reflects the result on the first render and tests
  don't need to poll for async results.

  Only use this in `async: false` modules: it toggles the global `:ash`
  `:disable_async?` application env, and ExUnit runs synchronous modules in
  isolation from `async: true` ones, which keeps the toggle race-free.
  """
  def disable_async_loading(_context) do
    put_async_loading(false)
  end

  @doc """
  Opts back into Cinder's async data loading for the duration of a test,
  restoring the previous value afterward. The inverse of `disable_async_loading/1`
  — use it to cover the real `start_async` cycle:

      setup {Cinder.TestHelpers, :enable_async_loading}

  Same `async: false` constraint applies (see `disable_async_loading/1`).
  """
  def enable_async_loading(_context) do
    put_async_loading(true)
  end

  defp put_async_loading(async_enabled?) do
    prev = Application.get_env(:ash, :disable_async?)
    Application.put_env(:ash, :disable_async?, !async_enabled?)
    ExUnit.Callbacks.on_exit(fn -> Application.put_env(:ash, :disable_async?, prev) end)
    :ok
  end
end
