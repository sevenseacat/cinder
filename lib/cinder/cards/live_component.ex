defmodule Cinder.Cards.LiveComponent do
  @moduledoc """
  LiveComponent for interactive card layouts with Ash query execution.

  Handles state management, data loading, and pagination for the cards component.
  Uses shared functionality from BaseLiveComponent for consistency with Table component.
  """

  use Cinder.Components.BaseLiveComponent
  import Cinder.Components.Shared

  # Cards-specific render function
  @impl true
  def render(assigns) do
    ~H"""
    <div class={[@theme.container_class, "relative"]} {@theme.container_data}>
      <!-- Filter Controls -->
      <div class={@theme.controls_class} {@theme.controls_data}>
        <Cinder.FilterManager.render_filter_controls
          columns={@columns}
          filters={@filters}
          theme={@theme}
          target={@myself}
        />
      </div>

      <!-- Sort Controls -->
      <div :if={show_sort_controls?(@columns)} class={@theme.sort_controls_class}>
        <div class={@theme.sort_controls_container_class}>
          <span class={@theme.sort_label_class}>Sort by:</span>
          <div class={@theme.sort_buttons_class}>
            <button :for={column <- get_sortable_columns(@columns)}
                    class={get_sort_button_classes(column, @sort_by, @theme)}
                    phx-click="toggle_sort"
                    phx-value-key={column.field}
                    phx-target={@myself}>
              {column.label}
              <span class={@theme.sort_indicator_class}>
                <.sort_arrow sort_direction={Cinder.QueryBuilder.get_sort_direction(@sort_by, column.field)} 
                             theme={@theme} 
                             loading={@loading} />
              </span>
            </button>
          </div>
        </div>
      </div>

      <!-- Cards Grid -->
      <div class={@theme.cards_wrapper_class} {@theme.cards_wrapper_data}>
        <div class={@theme.cards_grid_class} {@theme.cards_grid_data}>
          <div :for={item <- @data}
               class={get_card_classes(@theme.card_class, @card_click)}
               {@theme.card_data}
               phx-click={@card_click && @card_click.(item)}>
            {render_slot(@card_slot, item)}
          </div>
        </div>

        <!-- Empty State -->
        <div :if={@data == [] and not @loading} class={@theme.empty_class} {@theme.empty_data}>
          {@empty_message}
        </div>
      </div>

      <!-- Loading indicator -->
      <div :if={@loading} class={@theme.loading_overlay_class} {@theme.loading_overlay_data}>
        <div class={@theme.loading_spinner_class}>
          <div class={@theme.loading_text_class}>
            {@loading_message}
          </div>
        </div>
      </div>

      <!-- Pagination -->
      <div :if={@show_pagination and @page_info.total_pages > 1} class={@theme.pagination_wrapper_class}>
        <.pagination_controls 
          page_info={@page_info} 
          theme={@theme} 
          target={@myself} />
      </div>
    </div>
    """
  end

  # Cards-specific helper function implementation
  defp get_columns_from_slots(assigns) do
    # Convert Cards props to column format for QueryBuilder compatibility
    props = Map.get(assigns, :props, [])
    
    Enum.map(props, fn prop ->
      %{
        field: prop.field,
        label: prop.label,
        filterable: prop.filterable,
        filter_type: prop.filter_type,
        filter_options: prop.filter_options,
        sortable: prop.sortable,
        class: "",
        filter_fn: Map.get(prop, :filter_fn, nil)
      }
    end)
  end

  # Cards-specific UI helper functions
  defp show_sort_controls?(columns) do
    Enum.any?(columns, & &1.sortable)
  end

  defp get_sortable_columns(columns) do
    Enum.filter(columns, & &1.sortable)
  end

  defp get_sort_button_classes(column, sort_by, theme) do
    current_direction = Cinder.QueryBuilder.get_sort_direction(sort_by, column.field)
    
    base_classes = theme.sort_button_class
    
    case current_direction do
      nil -> [base_classes, theme.sort_button_inactive_class]
      _ -> [base_classes, theme.sort_button_active_class]
    end
  end

  defp get_card_classes(base_classes, card_click) do
    if card_click do
      [base_classes, "cursor-pointer"]
    else
      base_classes
    end
  end
end