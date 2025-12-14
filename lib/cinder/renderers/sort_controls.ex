defmodule Cinder.Renderers.SortControls do
  @moduledoc """
  Shared sort controls component for List and Grid renderers.

  Renders a button group for sorting since these layouts don't have table headers.
  """

  use Phoenix.Component

  @doc """
  Renders sort controls as a button group.

  ## Required assigns
  - `columns` - List of column definitions
  - `sort_by` - Current sort state (list of {field, direction} tuples)
  - `sort_label` - Label for the sort controls (e.g., "Sort by:")
  - `theme` - Theme configuration map
  - `myself` - LiveComponent reference for event targeting
  """
  def render(assigns) do
    sortable_columns = Enum.filter(assigns.columns, & &1.sortable)
    assigns = assign(assigns, :sortable_columns, sortable_columns)

    ~H"""
    <div :if={@sortable_columns != []} class={get_container_class(@theme)}>
      <div class={get_controls_class(@theme)}>
        <span class={get_label_class(@theme)}>{@sort_label}</span>
        <div class={get_buttons_class(@theme)}>
          <button
            :for={column <- @sortable_columns}
            type="button"
            class={get_button_class(column, @sort_by, @theme)}
            phx-click="toggle_sort"
            phx-value-key={column.field}
            phx-target={@myself}
          >
            {column.label}
            <span :if={get_sort_direction(@sort_by, column.field)} class={get_icon_class(@theme)}>
              {get_sort_icon(get_sort_direction(@sort_by, column.field), @theme)}
            </span>
          </button>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Returns true if any columns are sortable.
  """
  def has_sortable_columns?(columns) do
    Enum.any?(columns, & &1.sortable)
  end

  # ============================================================================
  # PRIVATE HELPERS
  # ============================================================================

  defp get_sort_direction(sort_by, field) when is_list(sort_by) do
    case Enum.find(sort_by, fn {f, _dir} -> f == field end) do
      {_, dir} -> dir
      nil -> nil
    end
  end

  defp get_sort_direction(_, _), do: nil

  defp get_container_class(theme) do
    Map.get(
      theme,
      :sort_container_class,
      "bg-white border border-gray-200 rounded-lg shadow-sm mt-4"
    )
  end

  defp get_controls_class(theme) do
    Map.get(theme, :sort_controls_class, "flex items-center gap-2 p-4")
  end

  defp get_label_class(theme) do
    Map.get(theme, :sort_controls_label_class, "text-sm text-gray-600 font-medium")
  end

  defp get_buttons_class(theme) do
    Map.get(theme, :sort_buttons_class, "flex gap-1")
  end

  defp get_button_class(column, sort_by, theme) do
    base =
      Map.get(theme, :sort_button_class, "px-3 py-1 text-sm border rounded transition-colors")

    active = Map.get(theme, :sort_button_active_class, "bg-blue-50 border-blue-300 text-blue-700")

    inactive =
      Map.get(theme, :sort_button_inactive_class, "bg-white border-gray-300 hover:bg-gray-50")

    if get_sort_direction(sort_by, column.field) do
      [base, active]
    else
      [base, inactive]
    end
  end

  defp get_icon_class(theme) do
    Map.get(theme, :sort_icon_class, "ml-1")
  end

  defp get_sort_icon(:asc, theme), do: Map.get(theme, :sort_asc_icon, "↑")
  defp get_sort_icon(:desc, theme), do: Map.get(theme, :sort_desc_icon, "↓")
  defp get_sort_icon(_, _), do: ""
end
