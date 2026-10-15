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
    put_app_env(:ash, :disable_async?, !async_enabled?)
  end

  @doc """
  Sets an application env value for the duration of a test, restoring the
  original afterward (or deleting the key again if it was unset). Works in a
  `setup` block or inline in a test:

      setup do
        put_app_env(:filters, [])
      end

  Calling it several times for the same key in one test is fine: each call
  registers its own restore, and they run in reverse order, so the value from
  before the first call wins.

  Only use this in `async: false` modules. Application env is global, so an
  `async: true` module would leak the value into tests running alongside it.
  """
  def put_app_env(app \\ :cinder, key, value) do
    restore_app_env_on_exit(app, key)
    Application.put_env(app, key, value)
  end

  @doc """
  Unsets an application env value for the duration of a test, restoring the
  original afterward. Same `async: false` constraint as `put_app_env/3`.
  """
  def delete_app_env(app \\ :cinder, key) do
    restore_app_env_on_exit(app, key)
    Application.delete_env(app, key)
  end

  defp restore_app_env_on_exit(app, key) do
    original = Application.fetch_env(app, key)

    ExUnit.Callbacks.on_exit(fn ->
      case original do
        {:ok, value} -> Application.put_env(app, key, value)
        :error -> Application.delete_env(app, key)
      end
    end)
  end
end
