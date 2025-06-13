defmodule Cinder.Theme do
  @moduledoc """
  Theme management for Cinder table components.

  Provides default themes and utilities for merging custom theme configurations.
  Also supports the new Spark DSL for defining modular themes.

  ## Basic Usage (Map-based themes)

      # Using built-in themes
      theme = Cinder.Theme.merge("modern")

      # Using custom map
      theme = Cinder.Theme.merge(%{
        container_class: "my-custom-container",
        table_class: "my-custom-table"
      })

  ## Advanced Usage (DSL-based themes)

      defmodule MyApp.CustomTheme do
        use Cinder.Theme

        override Cinder.Components.Table do
          set :container_class, "my-custom-table-container"
          set :row_class, "my-custom-row hover:bg-blue-50"
        end
      end

      theme = Cinder.Theme.merge(MyApp.CustomTheme)

  """

  @type theme :: %{atom() => String.t()}

  # Re-export the DSL functionality
  defmacro __using__(opts) do
    quote do
      require Cinder.Theme.DslModule
      Cinder.Theme.DslModule.__using__(unquote(opts))
    end
  end

  @doc """
  Returns the default theme configuration.
  """
  def default do
    complete_default()
  end

  @doc """
  Merges a custom theme configuration with the default theme.

  ## Examples

      iex> Cinder.Theme.merge(%{container_class: "my-custom-class"})
      %{container_class: "my-custom-class", ...}

      iex> Cinder.Theme.merge("modern")
      %{container_class: "bg-white shadow-lg rounded-xl border border-gray-100 overflow-hidden", ...}

  """
  def merge(theme_config)

  def merge(theme_config) when is_map(theme_config) do
    default()
    |> Map.merge(theme_config)
    |> apply_theme_property_mapping()
  end

  def merge("default"), do: default() |> apply_theme_property_mapping()
  def merge("modern"), do: merge(Cinder.Themes.Modern)
  def merge("retro"), do: merge(Cinder.Themes.Retro)
  def merge("futuristic"), do: merge(Cinder.Themes.Futuristic)
  def merge("dark"), do: merge(Cinder.Themes.Dark)
  def merge("daisy_ui"), do: merge(Cinder.Themes.DaisyUI)
  def merge("flowbite"), do: merge(Cinder.Themes.Flowbite)
  def merge("vintage"), do: merge(Cinder.Themes.Vintage)
  def merge("compact"), do: merge(Cinder.Themes.Compact)
  def merge("pastel"), do: merge(Cinder.Themes.Pastel)
  def merge(nil), do: default() |> apply_theme_property_mapping()

  def merge(theme_module) when is_atom(theme_module) do
    # Check if it's a DSL-based theme module
    try do
      theme_module.resolve_theme()
      |> apply_theme_property_mapping()
    rescue
      UndefinedFunctionError ->
        raise ArgumentError, "Theme module #{theme_module} does not implement resolve_theme/0"
    end
  end

  def merge(theme_name) when is_binary(theme_name) do
    raise ArgumentError,
          "Unknown theme preset: #{theme_name}. Available presets: #{Enum.join(presets(), ", ")}"
  end

  def merge(theme_config) do
    raise ArgumentError,
          "Theme must be a map, string, or theme module, got: #{inspect(theme_config)}"
  end

  @doc """
  Returns a list of available theme presets.
  """
  def presets do
    [
      "default",
      "modern",
      "retro",
      "futuristic",
      "dark",
      "daisy_ui",
      "flowbite",
      "vintage",
      "compact",
      "pastel"
    ]
  end

  @doc """
  Validates a theme configuration.

  Returns :ok if the theme is valid, or {:error, reason} if invalid.
  """
  def validate(theme_config) when is_map(theme_config) do
    # For map-based themes, just check that all values are strings
    invalid_keys =
      Enum.filter(theme_config, fn {_key, value} -> not is_binary(value) end)
      |> Enum.map(fn {key, _value} -> key end)

    if Enum.empty?(invalid_keys) do
      :ok
    else
      {:error, "Theme values must be strings. Invalid keys: #{inspect(invalid_keys)}"}
    end
  end

  def validate(theme_module) when is_atom(theme_module) do
    if function_exported?(theme_module, :resolve_theme, 0) do
      # For DSL-based themes, use the DSL validation
      Cinder.Theme.DslModule.validate_theme(theme_module)
    else
      {:error, "Theme module #{theme_module} does not implement resolve_theme/0"}
    end
  end

  def validate(theme_name) when is_binary(theme_name) do
    if theme_name in presets() do
      :ok
    else
      {:error, "Unknown theme preset: #{theme_name}"}
    end
  end

  def validate(_theme_config) do
    {:error, "Theme must be a map, string, or theme module"}
  end

  @doc """
  Gets all available theme properties across all components.
  """
  def all_theme_properties do
    [
      Cinder.Components.Table,
      Cinder.Components.Filters,
      Cinder.Components.Pagination,
      Cinder.Components.Sorting,
      Cinder.Components.Loading
    ]
    |> Enum.flat_map(& &1.theme_properties())
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc """
  Gets the complete default theme by merging all component defaults.
  """
  def complete_default do
    table_theme = Cinder.Components.Table.default_theme()
    filters_theme = Cinder.Components.Filters.default_theme()
    pagination_theme = Cinder.Components.Pagination.default_theme()
    sorting_theme = Cinder.Components.Sorting.default_theme()
    loading_theme = Cinder.Components.Loading.default_theme()

    [
      table_theme,
      filters_theme,
      pagination_theme,
      sorting_theme,
      loading_theme
    ]
    |> Enum.reduce(%{}, &Map.merge/2)
  end

  @doc """
  Applies theme property mapping for backwards compatibility.

  Currently a no-op since all properties are properly namespaced.
  """
  def apply_theme_property_mapping(theme) do
    theme
  end
end
