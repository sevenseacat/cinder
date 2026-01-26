defmodule Cinder.Theme.DslModule do
  @moduledoc """
  DSL module for creating custom Cinder themes.

  This module provides the `use Cinder.Theme` functionality that allows
  users to define custom themes using a simple macro-based DSL.

  ## Usage

      defmodule MyApp.CustomTheme do
        use Cinder.Theme

        # Table
        set :container_class, "my-custom-table-container"
        set :row_class, "my-custom-row hover:bg-blue-50"

        # Filters
        set :filter_container_class, "my-filter-container"
        set :filter_text_input_class, "my-text-input"
      end

  ## Theme Inheritance

  You can extend built-in theme presets:

      defmodule MyApp.DarkTheme do
        use Cinder.Theme
        extends :modern

        # Override just what you need
        set :container_class, "bg-gray-900 text-white"
        set :row_class, "border-gray-700 hover:bg-gray-800"
      end

  Or extend your own custom themes:

      defmodule MyApp.BaseTheme do
        use Cinder.Theme

        set :container_class, "my-base-container"
        set :row_class, "my-base-row"
      end

      defmodule MyApp.SpecializedTheme do
        use Cinder.Theme
        extends MyApp.BaseTheme

        # Override container, inherit row_class from BaseTheme
        set :container_class, "my-specialized-container"
      end

  **Note**: When extending custom themes, make sure the base theme module is
  compiled before the extending theme. In Phoenix applications, define your
  base themes before themes that extend them, or place them in separate files
  with appropriate compilation order.

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
  Deprecated: component grouping is no longer needed.

  This macro is kept for backwards compatibility but does nothing.
  Run `mix cinder.migrate.theme` to update your themes to the new flat syntax.
  """
  defmacro component(_component, do: block) do
    IO.warn(
      "component/2 is deprecated in Cinder themes and will be removed in a future version. " <>
        "Run `mix cinder.migrate.theme` to update your theme files.",
      Macro.Env.stacktrace(__CALLER__)
    )

    quote do
      unquote(block)
    end
  end

  @doc """
  Macro for setting a theme property.
  """
  defmacro set(key, value) do
    quote do
      @theme_overrides [{unquote(key), unquote(value)} | @theme_overrides]
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

        theme_map = Cinder.Theme.theme_or_default(base_theme)
        apply_overrides(theme_map, overrides)
      end

      defp apply_overrides(theme_map, overrides) do
        Enum.reduce(overrides, theme_map, fn {key, value}, acc ->
          Map.put(acc, key, value)
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

      :compact ->
        Cinder.Themes.Compact.resolve_theme()

      base_module when is_atom(base_module) ->
        # Try to ensure the module is loaded first
        case Code.ensure_loaded(base_module) do
          {:module, ^base_module} ->
            if function_exported?(base_module, :resolve_theme, 0) do
              base_module.resolve_theme()
            else
              raise ArgumentError,
                    "Module #{inspect(base_module)} does not implement resolve_theme/0. " <>
                      "Custom themes must use `use Cinder.Theme` to be extended."
            end

          {:error, :nofile} ->
            raise ArgumentError,
                  "Module #{inspect(base_module)} not found. " <>
                    "Make sure the module is defined and compiled before extending it."

          {:error, reason} ->
            raise ArgumentError,
                  "Failed to load module #{inspect(base_module)}: #{inspect(reason)}"
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
