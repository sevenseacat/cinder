defmodule Cinder.Theme.Docs do
  @moduledoc """
  Auto-generates theme documentation by extracting theme properties from component modules.

  This module provides functionality to automatically update the theming guide with
  current theme properties, similar to how AshAuthenticationPhoenix handles override
  documentation.
  """

  @component_modules [
    Cinder.Components.Table,
    Cinder.Components.List,
    Cinder.Components.Grid,
    Cinder.Components.Filters,
    Cinder.Components.Pagination,
    Cinder.Components.Search,
    Cinder.Components.Sorting,
    Cinder.Components.Loading
  ]

  @theming_file "docs/theming.md"
  @docs_start_comment "<!-- theme-properties-begin -->"
  @docs_end_comment "<!-- theme-properties-end -->"

  @doc """
  Updates the theming guide with auto-generated component reference documentation.
  """
  def write_docs! do
    [prelude, _ | rest] =
      @theming_file
      |> File.read!()
      |> String.split([@docs_start_comment, @docs_end_comment])

    [prelude, @docs_start_comment, "\n\n", component_docs(), "\n\n", @docs_end_comment]
    |> Enum.concat(rest)
    |> Enum.join()
    |> then(&File.write!(@theming_file, &1))
  end

  defp component_docs do
    Enum.map_join(@component_modules, "\n", &component_doc/1)
  end

  defp component_doc(component_module) do
    component_name = format_component_name(component_module)
    description = get_component_description(component_module)
    properties = get_theme_properties(component_module)
    default_values = get_default_theme(component_module)

    """
    ### #{component_name} Component
    #{description}

    ```elixir
    component #{inspect(component_module)} do
    #{format_properties(properties, default_values)}
    end
    ```
    """
  end

  defp format_component_name(module) do
    module
    |> Module.split()
    |> List.last()
    |> String.replace("Components.", "")
  end

  defp get_component_description(component_module) do
    case Code.fetch_docs(component_module) do
      {:docs_v1, _, _, _, %{"en" => docs}, _, _} ->
        docs
        |> String.split("\n\n", parts: 2, trim: true)
        |> Enum.at(0)

      _ ->
        "Theme properties for the #{format_component_name(component_module)} component."
    end
  end

  defp get_theme_properties(component_module) do
    Code.ensure_loaded(component_module)

    if function_exported?(component_module, :theme_properties, 0) do
      component_module.theme_properties()
    else
      []
    end
  end

  defp get_default_theme(component_module) do
    Code.ensure_loaded(component_module)

    if function_exported?(component_module, :default_theme, 0) do
      component_module.default_theme()
    else
      %{}
    end
  end

  defp format_properties(properties, default_values) do
    Enum.map_join(properties, "\n", fn property ->
      default_value = Map.get(default_values, property, "\"\"")

      formatted_default =
        if is_binary(default_value), do: "\"#{default_value}\"", else: inspect(default_value)

      "  set :#{property}, #{formatted_default}"
    end)
  end
end
