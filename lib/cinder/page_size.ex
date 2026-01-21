defmodule Cinder.PageSize do
  @moduledoc """
  Page size configuration for Cinder table components.

  ## Configuration

  Set a global default page size in your application configuration:

      # config/config.exs
      config :cinder, default_page_size: 50

      # Or with configurable options (shows dropdown selector)
      config :cinder, default_page_size: [default: 25, options: [10, 25, 50, 100]]

  Individual tables can override the global default:

  ```heex
  <Cinder.collection page_size={100} ...>
  </Cinder.collection>
  ```
  """

  @default_page_size 25

  @doc """
  Parses a page size value into a standardized config map.

  Accepts an integer, keyword list with `:default` and `:options` keys,
  or `nil` to use the global default.
  """
  def parse(nil), do: parse(get_default_page_size())

  def parse(value) when is_integer(value) do
    %{
      selected_page_size: value,
      page_size_options: [],
      default_page_size: value,
      configurable: false
    }
  end

  def parse(config) when is_list(config) do
    default = Keyword.get(config, :default, @default_page_size)
    options = Keyword.get(config, :options, [])

    valid_options =
      if is_list(options) and Enum.all?(options, &is_integer/1), do: options, else: []

    %{
      selected_page_size: default,
      page_size_options: valid_options,
      default_page_size: default,
      configurable: length(valid_options) > 1
    }
  end

  def parse(_invalid), do: parse(@default_page_size)

  @doc """
  Gets the raw default page size from application configuration.

  Returns the configured value or 25 if not set.
  """
  def get_default_page_size do
    Application.get_env(:cinder, :default_page_size, @default_page_size)
  end
end
