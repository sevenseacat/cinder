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
  attr(:url_filters, :map, default: %{}, doc: "Filter parameters from URL for state restoration")
  attr(:url_page, :string, doc: "Page number from URL for state restoration")

  attr(:on_state_change, :atom,
    doc:
      "Callback atom for state change notifications including filters and pagination (e.g., :state_changed)"
  )

  slot :col, required: true, doc: "Column definition" do
    attr(:key, :string, required: true, doc: "Column identifier (attribute name or dot notation)")
    attr(:label, :string, doc: "Column header text")
    attr(:sortable, :boolean, doc: "Enable sorting for this column")
    attr(:searchable, :boolean, doc: "Include this column in text search")
    attr(:filterable, :boolean, doc: "Enable filtering for this column")

    attr(:filter_type, :atom,
      doc: "Filter type (:text, :select, :multi_select, :boolean, :date_range, :number_range)"
    )

    attr(:filter_options, :list, doc: "Filter configuration options")
    attr(:filter_fn, :any, doc: "Custom filter function")
    attr(:options, :list, doc: "Custom filter options (list of values)")
    attr(:display_field, :atom, doc: "Field to display for relationship columns")
    attr(:sort_fn, :any, doc: "Custom sort function")
    attr(:search_fn, :any, doc: "Custom search function")
    attr(:class, :string, doc: "Custom CSS classes for the column")
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

  ## URL State Management

  The table component supports URL synchronization for both filters and pagination state.
  This enables shareable URLs, browser back/forward navigation, and state persistence on page refresh.

  Example usage:

      # In your LiveView, handle state change notifications
      def handle_info({:state_changed, table_id, state}, socket) do
        url_filters = Map.drop(state, [:page])
        url_page = Map.get(state, :page)

        params = if url_page do
          Map.put(url_filters, "page", url_page)
        else
          url_filters
        end

        {:noreply, push_patch(socket, to: ~p"/albums?\#{params}")}
      end

      # Pass URL parameters back to table component
      def mount(params, _session, socket) do
        url_filters = Map.drop(params, ["page"])
        url_page = Map.get(params, "page")

        socket = assign(socket, url_filters: url_filters, url_page: url_page)
        {:ok, socket}
      end

  In your template:

      <.table
        id="albums-table"
        query={MyApp.Album}
        current_user={@current_user}
        url_filters={@url_filters}
        url_page={@url_page}
        on_state_change={:state_changed}
      >
        <!-- columns -->
      </.table>

  ## Sort Arrow Customization

  You can customize sort arrows via the theme attribute:

      <.table
        id="my-table"
        query={MyApp.Album}
        current_user={@current_user}
        theme={%{
          # Use custom heroicons
          sort_asc_icon_name: "hero-arrow-up",
          sort_desc_icon_name: "hero-arrow-down",
          sort_none_icon_name: "hero-arrows-up-down",

          # Customize icon classes
          sort_asc_icon_class: "w-4 h-4 text-green-500",
          sort_desc_icon_class: "w-4 h-4 text-red-500",
          sort_none_icon_class: "w-4 h-4 text-gray-400"
        }}
      >
        <!-- columns -->
      </.table>

  The icons are rendered as `<span class={[icon_name, icon_class]} />` which works
  with Phoenix heroicons when you have heroicons CSS loaded.
  """
  def table(assigns) do
    ~H"""
    <.live_component
      module={Cinder.Table.LiveComponent}
      {assigns}
    />
    """
  end
end
