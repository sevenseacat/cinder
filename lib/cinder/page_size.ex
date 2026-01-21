defmodule Cinder.PageSize do
  @moduledoc """
  Page size configuration for Cinder table components.

  Provides utilities for retrieving the default page size from application configuration.

  ## Configuration

  You can set a default page size for all Cinder tables in your application configuration:

      # config/config.exs
      config :cinder, default_page_size: 50

      # Or with configurable options
      config :cinder, default_page_size: [default: 25, options: [10, 25, 50, 100]]

  Individual tables can still override the configured default:

  ```heex
  <Cinder.collection page_size={100} ...>
    <!-- This table uses page_size 100, ignoring the configured default -->
  </Cinder.collection>
  ```
  """

  @doc """
  Gets the configured default page size from application configuration.

  Returns the page size configured via `config :cinder, default_page_size: ...`
  or falls back to 25 if no configuration is set.

  ## Examples

      # With configuration
      Application.put_env(:cinder, :default_page_size, 50)
      Cinder.PageSize.get_default_page_size()
      #=> 50

      # With keyword list configuration
      Application.put_env(:cinder, :default_page_size, [default: 25, options: [10, 25, 50, 100]])
      Cinder.PageSize.get_default_page_size()
      #=> [default: 25, options: [10, 25, 50, 100]]

      # Without configuration
      Cinder.PageSize.get_default_page_size()
      #=> 25

  """
  def get_default_page_size do
    case Application.get_env(:cinder, :default_page_size) do
      nil -> 25
      page_size -> page_size
    end
  end
end
