defmodule Cinder.Table do
  @moduledoc """
  A LiveView component for rendering interactive data tables from Ash queries.

  Supports sorting, filtering, searching, and pagination with customizable theming.
  """

  use Phoenix.Component

  attr(:query, :any, required: true, doc: "The Ash resource or query to display")

  attr(:query_opts, :list,
    default: [],
    doc: "Options to pass to the Ash query (e.g., `[load: [:artist]]`)"
  )

  attr(:current_user, :any, required: true, doc: "The current user for authorization")
  attr(:page_size, :integer, default: 25, doc: "Number of items per page")
  attr(:id, :string, required: true, doc: "Required unique identifier for the component")
  attr(:theme, :map, default: %{}, doc: "Custom theme classes")

  slot :col, required: true, doc: "Column definition" do
    attr(:key, :string, required: true, doc: "Column identifier (attribute name or dot notation)")
    attr(:label, :string, doc: "Column header text")
    attr(:sortable, :boolean, doc: "Enable sorting for this column")
    attr(:searchable, :boolean, doc: "Include this column in text search")
    attr(:filterable, :boolean, doc: "Enable filtering for this column")
    attr(:options, :list, doc: "Custom filter options (list of values)")
    attr(:display_field, :atom, doc: "Field to display for relationship columns")
    attr(:sort_fn, :any, doc: "Custom sort function")
    attr(:search_fn, :any, doc: "Custom search function")
  end

  @doc """
  Renders an interactive data table for Ash resources.

  ## Example

      <.table
        id="album-catalog"
        query={MyApp.Album}
        query_opts={[load: [:artist, :publisher, :category]]}
        current_user={@current_user}
        page_size={50}
      >
        <:col :let={album} key="title" label="Title" sortable searchable>
          {album.title}
        </:col>

        <:col :let={album} key="artist" label="Artist" filterable sortable>
          {album.artist.name}
        </:col>
      </.table>
  """
  def table(assigns) do
    assigns =
      assigns
      |> assign_defaults()
      |> assign_column_definitions()
      |> assign_initial_state()

    ~H"""
    <div class={@theme.container_class}>
      <!-- Filters and Search will go here in later phases -->
      <div class={@theme.controls_class}>
        <!-- Placeholder for filters and search -->
      </div>
      
    <!-- Main table -->
      <div class={@theme.table_wrapper_class}>
        <table class={@theme.table_class}>
          <thead class={@theme.thead_class}>
            <tr class={@theme.header_row_class}>
              <th :for={column <- @columns} class={@theme.th_class}>
                {column.label}
                <span :if={column.sortable} class={@theme.sort_indicator_class}>
                  <!-- Sort arrows will be added in Phase 3 -->
                </span>
              </th>
            </tr>
          </thead>
          <tbody class={@theme.tbody_class}>
            <tr :if={@loading}>
              <td colspan={length(@columns)} class={@theme.loading_class}>
                Loading...
              </td>
            </tr>
            <tr :for={item <- @data} :if={not @loading} class={@theme.row_class}>
              <td :for={column <- @columns} class={@theme.td_class}>
                {render_slot(column.slot, item)}
              </td>
            </tr>
            <tr :if={@data == [] and not @loading}>
              <td colspan={length(@columns)} class={@theme.empty_class}>
                No results found
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      
    <!-- Pagination will go here in Phase 2 -->
      <div class={@theme.pagination_wrapper_class}>
        <!-- Placeholder for pagination -->
      </div>
    </div>
    """
  end

  # Private functions

  defp assign_defaults(assigns) do
    assigns
    |> Map.put(:page_size, assigns[:page_size] || 25)
    |> Map.put(:current_page, 1)
    |> Map.put(:loading, false)
    |> Map.put(:data, [])
    |> Map.put(:sort_by, [])
    |> Map.put(:filters, %{})
    |> Map.put(:search_term, "")
    |> Map.put(:theme, merge_theme(assigns[:theme] || %{}))
  end

  defp assign_column_definitions(assigns) do
    columns =
      assigns.col
      |> Enum.map(&parse_column_definition/1)

    Map.put(assigns, :columns, columns)
  end

  defp assign_initial_state(assigns) do
    # Initial state setup - actual data loading will be implemented in Phase 2
    assigns
    |> Map.put(:total_count, 0)
    |> Map.put(:page_info, %{
      current_page: 1,
      total_pages: 1,
      has_next_page: false,
      has_previous_page: false
    })
  end

  defp parse_column_definition(slot) do
    %{
      key: slot.key,
      label: Map.get(slot, :label, to_string(slot.key)),
      sortable: Map.get(slot, :sortable, false),
      searchable: Map.get(slot, :searchable, false),
      filterable: Map.get(slot, :filterable, false),
      options: Map.get(slot, :options, []),
      display_field: Map.get(slot, :display_field),
      sort_fn: Map.get(slot, :sort_fn),
      search_fn: Map.get(slot, :search_fn),
      slot: slot
    }
  end

  defp merge_theme(custom_theme) do
    default_theme()
    |> Map.merge(custom_theme)
  end

  defp default_theme do
    %{
      container_class: "cinder-table-container",
      controls_class: "cinder-table-controls mb-4",
      table_wrapper_class: "cinder-table-wrapper overflow-x-auto",
      table_class: "cinder-table w-full border-collapse",
      thead_class: "cinder-table-head",
      tbody_class: "cinder-table-body",
      header_row_class: "cinder-table-header-row",
      row_class: "cinder-table-row border-b",
      th_class: "cinder-table-th px-4 py-2 text-left font-medium border-b",
      td_class: "cinder-table-td px-4 py-2",
      sort_indicator_class: "cinder-sort-indicator ml-1",
      loading_class: "cinder-table-loading text-center py-8 text-gray-500",
      empty_class: "cinder-table-empty text-center py-8 text-gray-500",
      pagination_wrapper_class: "cinder-pagination-wrapper mt-4"
    }
  end
end
