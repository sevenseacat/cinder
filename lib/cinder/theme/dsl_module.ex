defmodule Cinder.Theme.DslModule do
  @moduledoc """
  Simplified DSL module for creating custom Cinder themes.

  This module provides the `use Cinder.Theme` functionality that allows
  users to define custom themes using a simple macro-based DSL.

  ## Usage

      defmodule MyApp.CustomTheme do
        use Cinder.Theme

        component Cinder.Components.Table do
          set :container_class, "my-custom-table-container"
          set :row_class, "my-custom-row hover:bg-blue-50"
        end

        component Cinder.Components.Filters do
          set :container_class, "my-filter-container"
          set :text_input_class, "my-text-input"
        end
      end

  ## Theme Inheritance

      defmodule MyApp.DarkTheme do
        use Cinder.Theme
        extends :modern

        component Cinder.Components.Table do
          set :container_class, "bg-gray-900 text-white"
          set :row_class, "border-gray-700 hover:bg-gray-800"
        end
      end

  """

  defmacro __using__(_opts) do
    quote do
      @behaviour Cinder.Theme.Behaviour
      @theme_overrides []
      @base_theme nil
      @before_compile Cinder.Theme.DslModule

      import Cinder.Theme.DslModule, only: [component: 2, extends: 1, set: 2]

      def resolve_theme do
        __theme_config()
      end

      defoverridable resolve_theme: 0
    end
  end

  @doc """
  Macro for extending from another theme.
  """
  defmacro extends(base_theme) do
    quote do
      @base_theme unquote(base_theme)
    end
  end

  @doc """
  Macro for defining component customizations.
  """
  defmacro component(component, do: block) do
    quote do
      @current_component unquote(component)
      @current_properties []
      unquote(block)

      @theme_overrides [
        %{component: @current_component, properties: Enum.reverse(@current_properties)}
        | @theme_overrides
      ]
    end
  end

  @doc """
  Macro for setting theme properties within an override block.
  """
  defmacro set(key, value) do
    quote do
      @current_properties [{unquote(key), unquote(value)} | @current_properties]
    end
  end

  @doc """
  Before compile callback to generate the theme configuration function.
  """
  defmacro __before_compile__(env) do
    base_theme = Module.get_attribute(env.module, :base_theme)
    overrides = Module.get_attribute(env.module, :theme_overrides) || []

    quote do
      def __theme_config do
        base_theme = unquote(Macro.escape(resolve_base_theme(base_theme)))
        overrides = unquote(Macro.escape(Enum.reverse(overrides)))

        theme_map = base_theme || Cinder.Theme.default()
        apply_overrides(theme_map, overrides)
      end

      defp apply_overrides(theme_map, overrides) do
        Enum.reduce(overrides, theme_map, fn %{properties: properties}, acc ->
          Enum.reduce(properties, acc, fn {key, value}, theme_acc ->
            Map.put(theme_acc, key, value)
          end)
        end)
      end
    end
  end

  @doc """
  Resolves a theme module's DSL configuration into a theme map.
  """
  def resolve_theme(theme_module) do
    if function_exported?(theme_module, :__theme_config, 0) do
      theme_module.__theme_config()
    else
      raise ArgumentError, "Theme module #{theme_module} was not compiled with Cinder.Theme DSL"
    end
  end

  @doc """
  Resolves a base theme at compile time.
  """
  def resolve_base_theme(nil), do: nil

  def resolve_base_theme(base_preset) when is_atom(base_preset) do
    # Handle built-in theme presets
    case base_preset do
      :default ->
        Cinder.Theme.default()

      :modern ->
        Cinder.Themes.Modern.resolve_theme()

      :retro ->
        Cinder.Themes.Retro.resolve_theme()

      :futuristic ->
        Cinder.Themes.Futuristic.resolve_theme()

      :dark ->
        Cinder.Themes.Dark.resolve_theme()

      :daisy_ui ->
        Cinder.Themes.DaisyUI.resolve_theme()

      :flowbite ->
        Cinder.Themes.Flowbite.resolve_theme()

      :vintage ->
        Cinder.Themes.Vintage.resolve_theme()

      :compact ->
        Cinder.Themes.Compact.resolve_theme()

      :pastel ->
        Cinder.Themes.Pastel.resolve_theme()

      base_module when is_atom(base_module) ->
        if function_exported?(base_module, :resolve_theme, 0) do
          base_module.resolve_theme()
        else
          raise ArgumentError, "Unknown base theme: #{base_preset}"
        end
    end
  end

  @doc """
  Validates that all overrides in a theme module are valid.
  """
  def validate_theme(theme_module) do
    try do
      # Try to resolve the theme to check for basic compilation issues
      _theme = resolve_theme(theme_module)
      :ok
    rescue
      error -> {:error, "Unable to validate theme module #{theme_module}: #{inspect(error)}"}
    end
  end
end
