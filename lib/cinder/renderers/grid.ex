defmodule Cinder.Renderers.Grid do
  @moduledoc """
  Renderer for grid/card layout.

  This module contains the render function for displaying data in a
  responsive grid format with sort controls rendered as a button group.
  """

  use Phoenix.Component
  use Cinder.Messages
  require Logger

  alias Cinder.Renderers.Pagination
  alias Cinder.Renderers.SortControls

  @doc """
  Renders the grid layout.
  """
  def render(assigns) do
    has_item_slot = Map.get(assigns, :item_slot, []) != []

    unless has_item_slot do
      Logger.warning("Cinder.Grid: No <:item> slot provided. Items will not be rendered.")
    end

    {container_class, container_data} =
      get_container_class(assigns.container_class, assigns.grid_columns, assigns.theme)

    {item_class, item_data} = get_item_classes(assigns.theme, assigns.item_click)

    assigns =
      assigns
      |> assign(:has_item_slot, has_item_slot)
      |> assign(:grid_container_class, container_class)
      |> assign(:grid_container_data, container_data)
      |> assign(:grid_item_class, item_class)
      |> assign(:grid_item_data, item_data)

    ~H"""
    <div class={[@theme.container_class, "relative"]} {@theme.container_data}>
      <!-- Bulk Action Buttons -->
      <div :if={Map.get(assigns, :bulk_actions, []) != []} class={Map.get(@theme, :bulk_actions_container_class, "flex justify-end gap-2 p-4")}>
        <button
          :for={action <- Map.get(assigns, :bulk_actions, [])}
          type="button"
          phx-click="bulk_action"
          phx-value-event={Map.get(action, :event, "bulk_action_all_ids")}
          phx-target={@myself}
          disabled={Map.get(assigns, :bulk_action_loading) != nil}
          class={[
            Map.get(@theme, :bulk_action_button_class, "px-4 py-2 text-sm font-medium rounded-lg border border-gray-300 bg-white text-gray-700 hover:bg-gray-50"),
            Map.get(assigns, :bulk_action_loading) == Map.get(action, :event) && Map.get(@theme, :bulk_loading_class, "animate-pulse")
          ]}
        >
          {Map.get(action, :label, "Action")}
        </button>
      </div>

      <!-- Controls Area (filters + sort) -->
      <div :if={@show_filters or (@show_sort && SortControls.has_sortable_columns?(@columns))} class={[@theme.controls_class, "!flex !flex-col"]} {@theme.controls_data}>
        <!-- Filter Controls (including search) -->
        <Cinder.FilterManager.render_filter_controls
          :if={@show_filters}
          columns={Map.get(assigns, :query_columns, @columns)}
          filters={@filters}
          theme={@theme}
          target={@myself}
          filters_label={@filters_label}
          search_term={@search_term}
          show_search={@search_enabled}
          search_label={@search_label}
          search_placeholder={@search_placeholder}
          raw_filter_params={Map.get(assigns, :raw_filter_params, %{})}
        />

        <!-- Sort Controls (button group since no table headers) -->
        <SortControls.render
          :if={@show_sort}
          columns={@columns}
          sort_by={@sort_by}
          sort_label={@sort_label}
          theme={@theme}
          myself={@myself}
        />
      </div>

      <!-- Grid Items Container -->
      <div class={@grid_container_class} {@grid_container_data}>
        <%= if @has_item_slot do %>
          <div
            :for={item <- @data}
            class={@grid_item_class}
            {@grid_item_data}
            phx-click={@item_click && @item_click.(item)}
          >
            {render_slot(@item_slot, item)}
          </div>
        <% else %>
          <!-- No item slot provided - render message -->
          <div :if={not @loading} class={@theme.empty_class} {@theme.empty_data}>
            No item template provided. Add an &lt;:item&gt; slot to render items.
          </div>
        <% end %>

        <!-- Empty State -->
        <div :if={@data == [] and not @loading and @has_item_slot} class={[@theme.empty_class, "col-span-full"]} {@theme.empty_data}>
          {@empty_message}
        </div>
      </div>

      <!-- Loading indicator -->
      <div :if={@loading} class={@theme.loading_overlay_class} {@theme.loading_overlay_data}>
        <div class={@theme.loading_container_class} {@theme.loading_container_data}>
          <svg class={@theme.loading_spinner_class} {@theme.loading_spinner_data} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
            <circle class={@theme.loading_spinner_circle_class} {@theme.loading_spinner_circle_data} cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class={@theme.loading_spinner_path_class} {@theme.loading_spinner_path_data} fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
          {@loading_message}
        </div>
      </div>

      <!-- Pagination -->
      <Pagination.render
        page={@page}
        page_size_config={@page_size_config}
        theme={@theme}
        myself={@myself}
        show_pagination={@show_pagination}
        pagination_mode={@pagination_mode}
      />
    </div>
    """
  end

  # ============================================================================
  # CONTAINER AND ITEM HELPERS
  # ============================================================================

  # Explicit container_class override takes precedence
  defp get_container_class(custom_class, _grid_columns, _theme) when is_binary(custom_class) do
    {custom_class, %{}}
  end

  # Build from theme base + grid_columns
  defp get_container_class(nil, grid_columns, theme) do
    base = Map.get(theme, :grid_container_class, "grid gap-4")
    data = Map.get(theme, :grid_container_data, %{})
    cols = build_grid_cols(grid_columns)
    {[base, cols], data}
  end

  defp build_grid_cols(cols) when is_binary(cols) do
    build_grid_cols(String.to_integer(cols))
  end

  defp build_grid_cols(cols) when is_integer(cols) and cols in 1..12 do
    "grid-cols-#{cols}"
  end

  # If an invalid number is provided, default to 3
  defp build_grid_cols(cols) when is_integer(cols), do: "grid-cols-3"

  defp build_grid_cols(cols) when is_list(cols) do
    Enum.map(cols, &breakpoint_class/1)
  end

  defp build_grid_cols(_), do: "grid-cols-3"

  defp breakpoint_class({:xs, cols}), do: "grid-cols-#{cols}"
  defp breakpoint_class({:sm, cols}), do: "sm:grid-cols-#{cols}"
  defp breakpoint_class({:md, cols}), do: "md:grid-cols-#{cols}"
  defp breakpoint_class({:lg, cols}), do: "lg:grid-cols-#{cols}"
  defp breakpoint_class({:xl, cols}), do: "xl:grid-cols-#{cols}"
  defp breakpoint_class({:"2xl", cols}), do: "2xl:grid-cols-#{cols}"
  defp breakpoint_class(_), do: nil

  defp get_item_classes(theme, item_click) do
    base =
      Map.get(theme, :grid_item_class, "p-4 bg-white border border-gray-200 rounded-lg shadow-sm")

    base_data = Map.get(theme, :grid_item_data, %{})

    if item_click do
      clickable =
        Map.get(
          theme,
          :grid_item_clickable_class,
          "cursor-pointer hover:shadow-md transition-shadow"
        )

      clickable_data = Map.get(theme, :grid_item_clickable_data, %{})
      {[base, clickable], Map.merge(base_data, clickable_data)}
    else
      {base, base_data}
    end
  end

  # Tailwind safelist - these classes are dynamically generated, keep them here for purge detection:
  # grid-cols-1 grid-cols-2 grid-cols-3 grid-cols-4 grid-cols-5 grid-cols-6 grid-cols-7 grid-cols-8 grid-cols-9 grid-cols-10 grid-cols-11 grid-cols-12
  # sm:grid-cols-1 sm:grid-cols-2 sm:grid-cols-3 sm:grid-cols-4 sm:grid-cols-5 sm:grid-cols-6
  # md:grid-cols-1 md:grid-cols-2 md:grid-cols-3 md:grid-cols-4 md:grid-cols-5 md:grid-cols-6
  # lg:grid-cols-1 lg:grid-cols-2 lg:grid-cols-3 lg:grid-cols-4 lg:grid-cols-5 lg:grid-cols-6
  # xl:grid-cols-1 xl:grid-cols-2 xl:grid-cols-3 xl:grid-cols-4 xl:grid-cols-5 xl:grid-cols-6
  # 2xl:grid-cols-1 2xl:grid-cols-2 2xl:grid-cols-3 2xl:grid-cols-4 2xl:grid-cols-5 2xl:grid-cols-6
end
