defmodule Cinder.Renderers.SortControls do
  @moduledoc """
  Shared sort controls component for List and Grid renderers.

  Renders a button group for sorting since these layouts don't have table headers.
  """

  use Phoenix.Component

  alias Cinder.QueryBuilder
  alias Cinder.Renderers.SortIcon

  @doc """
  Renders sort controls as a button group.

  ## Required assigns
  - `columns` - List of column definitions
  - `sort_by` - Current sort state (list of {field, direction} tuples)
  - `sort_label` - Label for the sort controls (e.g., "Sort by:")
  - `theme` - Theme configuration map
  - `myself` - LiveComponent reference for event targeting

  ## Optional assigns
  - `loading` - Whether data is currently loading (defaults to `false`)
  """
  def render(assigns) do
    # Pair each sortable column with its current direction once, so the button
    # styling and the icon don't each recompute it.
    sortable_columns =
      assigns.columns
      |> Enum.filter(& &1.sortable)
      |> Enum.map(fn column ->
        {column, QueryBuilder.get_sort_direction(assigns.sort_by, column.field)}
      end)

    assigns =
      assigns
      |> assign(:sortable_columns, sortable_columns)
      |> assign_new(:loading, fn -> false end)

    ~H"""
    <div :if={@sortable_columns != []} class={get_container_class(@theme)}>
      <div class={get_controls_class(@theme)}>
        <span class={get_label_class(@theme)}>{@sort_label}</span>
        <div class={get_buttons_class(@theme)}>
          <button
            :for={{column, direction} <- @sortable_columns}
            type="button"
            class={get_button_class(direction, @theme)}
            phx-click="toggle_sort"
            phx-value-key={column.field}
            phx-target={@myself}
          >
            {column.label}
            <span class={get_indicator_class(@theme)} data-key="sort_indicator_class">
              <SortIcon.sort_icon sort_direction={direction} theme={@theme} loading={@loading} />
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

  defp get_indicator_class(theme) do
    Map.get(theme, :sort_indicator_class, "ml-1 inline-flex items-center align-baseline")
  end

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

  defp get_button_class(direction, theme) do
    base =
      Map.get(theme, :sort_button_class, "px-3 py-1 text-sm border rounded transition-colors")

    active = Map.get(theme, :sort_button_active_class, "bg-blue-50 border-blue-300 text-blue-700")

    inactive =
      Map.get(theme, :sort_button_inactive_class, "bg-white border-gray-300 hover:bg-gray-50")

    if direction, do: [base, active], else: [base, inactive]
  end
end
