defmodule Cinder.Next do
  @moduledoc """
  Spike: a new collection shell on Cinder's existing query engine (7CC-158).

  `collection/1` declares what the collection can be queried by and how it's
  displayed, separately:

    * `<:filter>` and `<:sort>` declare query capabilities. `filter`, `sort` and
      `search` on a `<:col>` are shorthands for "this field, with defaults".
    * `<:col>` only describes a table column's display.

  The slots are normalised into a `Cinder.Next.Config` here, in a function
  component, and only that config reaches `Cinder.Next.Component`. Raw slots are
  never passed to the LiveComponent as top-level assigns, which crashes after a
  `push_patch`.

  The other components here are the default renderings, each from its part of the
  view-model: whole regions (`toolbar/1`, `results/1` with `table/1` or `grid/1`,
  `bulk_bar/1`, `pagination/1`) and single parts (`search/1`, `filter/1`,
  `sort_select/1`, `layout_switch/1`, `group_header/1`). `sort_command/2` is for
  components that take a JS command per column.
  """
  use Phoenix.Component
  use Cinder.Messages

  alias Cinder.Next.{Config, View}

  attr :id, :string, default: "cinder-collection"
  attr :resource, :atom, default: nil
  attr :query, :any, default: nil
  attr :action, :atom, default: nil
  attr :scope, :any, default: nil, doc: "An `Ash.Scope.ToOpts` scope"
  attr :actor, :any, default: nil, doc: "Shorthand for `scope={%{actor: …}}`"
  attr :tenant, :any, default: nil, doc: "Shorthand for `scope={%{tenant: …}}`"
  attr :query_opts, :list, default: []
  attr :page_size, :integer, default: 25
  attr :url_state, :any, default: false

  # Spike: `pagination` is taken by the region slot
  attr :pagination_mode, :any,
    default: :offset,
    values: [:offset, :keyset, "offset", "keyset"],
    doc: "`:keyset` pages by cursor (previous and next only), for actions that support it"

  attr :layout, :any,
    default: :table,
    values: [:table, :grid, :list, "table", "grid", "list"],
    doc: "How records show (to start with, if it can switch). `:list` is a one-column `:grid`."

  attr :grid_columns, :any,
    default: nil,
    doc: "Grid columns: a number, or breakpoints like `[xs: 1, md: 3]`. Default: as many as fit."

  attr :search, :any,
    default: nil,
    doc: "`false`, or options: `fields`, `label`, `placeholder`, `fn`"

  slot :col, doc: "A table column. Its content renders each cell." do
    attr :field, :string, required: true
    attr :label, :string
    attr :sort, :boolean, doc: "Shorthand for a `<:sort>` with defaults"
    attr :filter, :boolean, doc: "Shorthand for a `<:filter>` with an inferred type"
    attr :search, :boolean, doc: "Include this field in search"
  end

  slot :filter,
    doc: "Declares a filter. Its content, if any, replaces the filter's default markup." do
    attr :field, :string, required: true
    # Atom-valued attrs also take their string form (`type="select"`). `type` can't
    # have a `values:` list because it also takes custom filter modules, so it's
    # checked when the collection mounts instead.
    attr :type, :any, doc: "A built-in type (atom or string), or a custom filter module"
    attr :label, :string
    attr :help, :string
    attr :options, :list
    attr :prompt, :string
    attr :placeholder, :string
    attr :operator, :any
    attr :match_mode, :any, values: [:any, :all, "any", "all"]
    attr :case_sensitive, :boolean
    attr :max_results, :integer, doc: "Autocomplete: how many matching options to show"
    attr :include_time, :boolean, doc: "Date range: dates and times, not only dates"
    attr :labels, :map, doc: "Boolean: the choices' labels, `%{true: \"Yes\", false: \"No\"}`"
    attr :value, :any, doc: "Checkbox: the value it filters by when checked (default `true`)"
  end

  slot :argument,
    doc: """
    An input for one of the read action's arguments, rendered and cleared like a
    filter. Its type, options and whether it's required come from the action.
    """ do
    attr :name, :string, required: true
    attr :label, :string
    attr :help, :string
    attr :type, :any, doc: "Overrides the type inferred from the argument"
    attr :options, :list
    attr :prompt, :string
    attr :placeholder, :string
  end

  attr :selectable, :any,
    default: false,
    doc: "Rows can be selected: `true`, or a function of the record saying whether it can be"

  slot :bulk_action, doc: "An action on the selected records, found by its `name`" do
    attr :name, :string, required: true
    attr :action, :any, required: true, doc: "An Ash action name, or a function of (query, opts)"
    attr :label, :string
    attr :confirm, :string, doc: "Asks first, with `{count}` for the number selected"
    attr :action_opts, :list
  end

  slot :group,
    doc: """
    Groups the rows on each page by a field, kept together by sorting on it first
    (behind the user's sorts, not in the controls or the URL). Its content, if any,
    is each group's header, via `:let` (`value` and `items`).
    """ do
    attr :field, :string, required: true

    attr :sort, :any,
      values: [:asc, :desc, "asc", "desc"],
      doc: "The groups' order (default `:asc`)"
  end

  slot :header,
    doc: """
    A column's header content, instead of its label: icons, tooltips, any markup,
    via `:let` (the column's view-model). Declared by field, like `<:filter>`. On
    a sortable column it goes inside the sort button, so it shouldn't hold links
    or buttons of its own.
    """ do
    attr :field, :string, required: true
  end

  slot :sort, doc: "Declares a sortable field" do
    attr :field, :string, required: true
    attr :label, :string
    attr :cycle, :list
  end

  slot :item, doc: "A grid layout's card for each record, via `:let`"

  # Region slots replace one region of the default page, receiving the whole
  # collection view-model via `:let`. For a page arranged freely, keep the collection
  # in the LiveView instead (`Cinder.Next.LiveView`).
  slot :toolbar, doc: "Replaces the region above the results (search, filters, sort)"
  slot :pagination, doc: "Replaces the pagination below the results"

  def collection(assigns) do
    assigns = assign(assigns, :config, Config.build(assigns))

    ~H"""
    <.live_component
      module={Cinder.Next.Component}
      id={@id}
      config={@config}
      url_params={url_params(@url_state)}
    />
    """
  end

  @doc """
  Sorts by `field` (the next step in its cycle), as a JS command. For components
  that take a command per column rather than attribute maps, like Petal's table:
  `on_sort={&Cinder.Next.sort_command(c, &1)}`.
  """
  def sort_command(collection, field) do
    Phoenix.LiveView.JS.push(collection.event_prefix <> "sort",
      target: collection.target,
      value: %{field: field}
    )
  end

  # `Cinder.UrlSync.handle_params/3` keeps the raw URL params under `:filters`
  defp url_params(%{filters: params}), do: params
  defp url_params(_url_state), do: nil

  # ===========================================================================
  # Default components. Region-level ones (`toolbar`, `table`, `grid`,
  # `pagination`) take the whole `collection` view-model and render nothing when
  # their region is empty, so layouts need no guards. Element-level ones take
  # their own piece of it. All of them take `class` and any other attributes,
  # merged onto their root element.
  # ===========================================================================

  attr :collection, :map, required: true
  attr :class, :any, default: nil
  attr :rest, :global

  @doc "Search, filters, (for grids) the sort dropdown, and a layout switcher if there's a choice"
  def toolbar(assigns) do
    ~H"""
    <div
      :if={
        @collection.search || Enum.any?(@collection.filters) || grid_sort?(@collection) ||
          @collection.layouts != []
      }
      {merge(%{}, "toolbar", @class, @rest)}
    >
      <.search :if={@collection.search} search={@collection.search} />
      <.filter :for={filter <- @collection.filters} filter={filter} />
      <.sort_select :if={grid_sort?(@collection)} sort_select={@collection.sort_select} />
      <.layout_switch layouts={@collection.layouts} />
    </div>
    """
  end

  # Tables sort from their column headers; grids get the dropdown
  defp grid_sort?(collection), do: collection.layout == :grid and collection.sort_select != nil

  attr :layouts, :list, required: true
  attr :class, :any, default: nil
  attr :rest, :global

  @doc "Buttons to switch between the collection's layouts. Renders nothing without a choice."
  def layout_switch(assigns) do
    ~H"""
    <div :if={@layouts != []} {merge(%{"role" => "group"}, "layout-switch", @class, @rest)}>
      <button :for={layout <- @layouts} {styled(layout.attrs, "layout")}>{layout.label}</button>
    </div>
    """
  end

  attr :search, :map, required: true
  attr :class, :any, default: nil
  attr :rest, :global

  def search(assigns) do
    ~H"""
    <div {merge(@search.attrs, "search", @class, @rest)}>
      <label for={@search.input_attrs["id"]}>{@search.label}</label>
      <input {@search.input_attrs} />
      <button {styled(@search.clear_attrs, "search-clear")}>×</button>
    </div>
    """
  end

  attr :filter, :map,
    default: nil,
    doc: "The filter's view-model, e.g. in a loop over `c.filters`"

  attr :collection, :map, default: nil, doc: "With `field`, instead of `filter`"
  attr :field, :string, default: nil, doc: "Places the collection's filter for this field"
  attr :class, :any, default: nil
  attr :rest, :global

  @doc """
  A filter: its `<:filter>` slot's content if it has any, otherwise the default
  markup for its type. Either way it gets the filter's view-model.

  Takes the view-model itself (`filter={f}`), or a collection and the field to
  place (`collection={c} field="price"`).
  """
  def filter(%{filter: nil, collection: %{filters: filters}, field: field} = assigns) do
    case filters[field] do
      nil ->
        raise ArgumentError,
              "no filter is declared for #{inspect(field)}; the declared ones are " <>
                inspect(Enum.map(filters, & &1.field))

      filter ->
        filter(assign(assigns, :filter, filter))
    end
  end

  def filter(%{filter: %{render: render}} = assigns) when render != nil do
    ~H"""
    {render_slot(@filter.render, @filter)}
    """
  end

  # A group of inputs (checkboxes, radios) is labelled by a legend; one input, by a label
  def filter(assigns) do
    ~H"""
    <fieldset :if={@filter.group?} {merge(@filter.attrs, "filter", @class, @rest)}>
      <legend>{@filter.label}<.required filter={@filter} /></legend>
      <.filter_parts filter={@filter} />
    </fieldset>
    <div :if={!@filter.group?} {merge(@filter.attrs, "filter", @class, @rest)}>
      <label {@filter.label_attrs}>{@filter.label}<.required filter={@filter} /></label>
      <.filter_parts filter={@filter} />
    </div>
    """
  end

  defp required(assigns) do
    ~H"""
    <span :if={@filter.required?} aria-hidden="true"> *</span>
    """
  end

  defp filter_parts(assigns) do
    ~H"""
    <.filter_control filter={@filter} />
    <button {styled(@filter.clear_attrs, "filter-clear")}>×</button>
    <p :if={@filter.help} {styled(@filter.help_attrs, "filter-help")}>{@filter.help}</p>
    <p :if={@filter.errors != []} {styled(@filter.error_attrs, "filter-error")}>{Enum.join(@filter.errors, ", ")}</p>
    """
  end

  attr :filter, :map, required: true

  @doc """
  A filter's controls alone, with no label or help: its type's `control/1`, or
  `@filter.input_attrs` as an `<input>`.
  """
  def filter_control(%{filter: %{control: control}} = assigns) when control != nil,
    do: control.(assigns)

  def filter_control(assigns) do
    ~H"""
    <input {@filter.input_attrs} />
    """
  end

  attr :sort_select, :map, required: true
  attr :class, :any, default: nil
  attr :rest, :global

  @doc "An exclusive sort as a dropdown: the default for layouts without column headers."
  def sort_select(assigns) do
    ~H"""
    <div {merge(@sort_select.attrs, "sort-select", @class, @rest)}>
      <label for={@sort_select.select_attrs["id"]}>{@sort_select.label}</label>
      <select {@sort_select.select_attrs}>
        <option :for={option <- @sort_select.options} {option.attrs}>{option.label}</option>
      </select>
    </div>
    """
  end

  attr :collection, :map, required: true
  attr :class, :any, default: nil
  attr :rest, :global

  @doc "The results in the collection's layout: `table/1` or `grid/1`"
  def results(assigns) do
    ~H"""
    <.grid :if={@collection.layout == :grid} collection={@collection} class={@class} {@rest} />
    <.table :if={@collection.layout != :grid} collection={@collection} class={@class} {@rest} />
    """
  end

  attr :collection, :map, required: true
  attr :class, :any, default: nil
  attr :rest, :global

  slot :inner_block, doc: "Each card, via `:let`, if not the collection's `<:item>`"

  @doc """
  Cards as a list (a one-column grid is a list): from the inner block, or the
  collection's `<:item>` slot.
  """
  def grid(assigns) do
    ~H"""
    <ul :if={!@collection.groups} {merge(@collection.grid_attrs, "grid", @class, @rest)}>
      <.grid_item :for={row <- @collection.rows} row={row} item={@inner_block} collection={@collection} />
    </ul>
    <%!-- Each group starts its own grid, so it starts a fresh row --%>
    <section :for={group <- @collection.groups || []} {styled(group.attrs, "group")}>
      <.group_header group={group} />
      <ul {merge(Map.merge(@collection.grid_attrs, group.items_attrs), "grid", @class, @rest)}>
        <.grid_item :for={row <- group.items} row={row} item={@inner_block} collection={@collection} />
      </ul>
    </section>
    <p :if={@collection.rows == [] and @collection.status == :idle} class="cinder-empty">
      {dgettext("cinder", "No results found")}
    </p>
    <p :if={@collection.status == :error} class="cinder-error">
      {dgettext("cinder", "An error occurred while loading data")}
    </p>
    """
  end

  attr :collection, :map, required: true
  attr :class, :any, default: nil
  attr :rest, :global

  slot :col,
    doc: """
    The table's own columns, instead of the collection's `<:col>`s: how a template
    gives a collection kept in a LiveView (which has no slots) its columns. Each is
    matched to the collection's sort for its field.
    """ do
    attr :field, :string, required: true
    attr :label, :string
  end

  @doc "The records as a table, with the collection's columns or its own `:col`s"
  def table(assigns) do
    assigns = assign(assigns, :columns, table_columns(assigns.col, assigns.collection))

    ~H"""
    <table {merge(%{}, "table", @class, @rest)}>
      <thead>
        <tr>
          <th :if={@collection.selection} class="cinder-select-cell">
            <input {styled(@collection.selection.page_attrs, "select-page")} />
          </th>
          <th :for={column <- @columns} {styled(column.attrs, "header-cell")}>
            <%= if column.sort do %>
              <button {styled(column.sort.attrs, "sort")}>
                <.header_content column={column} /><span {styled(column.sort.indicator_attrs, "sort-indicator")}></span>
              </button>
            <% else %>
              <.header_content column={column} />
            <% end %>
          </th>
        </tr>
      </thead>
      <%!-- Grouped: a header body and an items body per group, since a <tbody>
           can't hold another container to collapse --%>
      <%= for group <- @collection.groups || [] do %>
        <tbody {styled(group.attrs, "group")}>
          <tr class="cinder-group-header">
            <th colspan={column_count(@columns, @collection)} scope="colgroup">
              <.group_header group={group} />
            </th>
          </tr>
        </tbody>
        <tbody {styled(group.items_attrs, "group-items")}>
          <.table_row :for={row <- group.items} row={row} columns={@columns} />
        </tbody>
      <% end %>
      <tbody>
        <%= if !@collection.groups do %>
          <.table_row :for={row <- @collection.rows} row={row} columns={@columns} />
        <% end %>
        <tr :if={@collection.rows == [] and @collection.status == :idle} class="cinder-empty">
          <td colspan={column_count(@columns, @collection)}>{dgettext("cinder", "No results found")}</td>
        </tr>
        <tr :if={@collection.status == :error} class="cinder-error">
          <td colspan={column_count(@columns, @collection)}>
            {dgettext("cinder", "An error occurred while loading data")}
          </td>
        </tr>
      </tbody>
    </table>
    """
  end

  attr :collection, :map, required: true
  attr :class, :any, default: nil
  attr :rest, :global

  @doc """
  The selection and its bulk actions: a count, the actions, clear, a pending
  action's confirmation, and what the last action did. Renders nothing while
  nothing's selected and nothing's pending.
  """
  def bulk_bar(assigns) do
    ~H"""
    <div
      :if={@collection.selection && (@collection.selection.count > 0 || @collection.confirmation)}
      {merge(%{}, "bulk-bar", @class, @rest)}
    >
      <span class="cinder-selection-count">{@collection.selection.summary}</span>
      <button :for={action <- @collection.bulk_actions} {styled(action.attrs, "bulk-action")}>{action.label}</button>
      <button {styled(@collection.selection.clear_attrs, "clear-selection")}>{dgettext("cinder", "Clear all")}</button>
      <div :if={@collection.confirmation} {styled(@collection.confirmation.attrs, "confirmation")}>
        <p>{@collection.confirmation.message}</p>
        <button {styled(@collection.confirmation.confirm_attrs, "confirm")}>{@collection.confirmation.action}</button>
        <button {styled(@collection.confirmation.cancel_attrs, "cancel")}>{dgettext("cinder", "Cancel")}</button>
      </div>
    </div>
    """
  end

  defp table_columns([], collection), do: collection.columns

  defp table_columns(cols, collection) do
    for col <- cols do
      column = %{
        field: col.field,
        label: col[:label] || Cinder.Filter.Helpers.humanize_embedded_field(col.field),
        slot: col
      }

      View.column(column, collection.sorts[col.field])
    end
  end

  # Columns plus the selection column, for cells that span the whole table
  defp column_count(columns, collection),
    do: length(columns) + if(collection.selection, do: 1, else: 0)

  attr :column, :map, required: true

  # A column's `<:header>` content if it has one, else its label
  defp header_content(%{column: %{header: nil}} = assigns), do: ~H"{@column.label}"
  defp header_content(assigns), do: ~H"{render_slot(@column.header, @column)}"

  attr :row, :map, required: true
  attr :columns, :list, required: true

  defp table_row(assigns) do
    ~H"""
    <tr {styled(@row.attrs, "row")}>
      <td :if={@row.select_attrs} class="cinder-select-cell"><input {styled(@row.select_attrs, "select")} /></td>
      <td :for={column <- @columns} class="cinder-cell" data-field={column.field}>
        <%= if column.slot[:inner_block] do %>
          {render_slot(column.slot, @row.record)}
        <% else %>
          {View.field_value(@row.record, column.field)}
        <% end %>
      </td>
    </tr>
    """
  end

  attr :row, :map, required: true
  attr :item, :list, required: true
  attr :collection, :map, required: true

  defp grid_item(assigns) do
    ~H"""
    <li {styled(@row.attrs, "item")}>
      <input :if={@row.select_attrs} {styled(@row.select_attrs, "select")} />
      {render_slot(if(@item != [], do: @item, else: @collection.item_slot), @row.record)}
    </li>
    """
  end

  attr :group, :map, required: true

  @doc """
  A group's header: the collapse toggle, and the group's `<:group>` content (with
  `value` and the group's records as `items`), or its value.
  """
  def group_header(assigns) do
    ~H"""
    <button {styled(@group.toggle_attrs, "group-toggle")}><span aria-hidden="true">▾</span></button>
    <span id={@group.label_id} class="cinder-group-label">
      <%= if @group.slot[:inner_block] do %>
        {render_slot(@group.slot, %{value: @group.value, items: Enum.map(@group.items, & &1.record)})}
      <% else %>
        {@group.value}
      <% end %>
    </span>
    """
  end

  attr :collection, :map, required: true
  attr :class, :any, default: nil
  attr :rest, :global

  @doc "The whole pagination region: summary, previous/next and page links"
  def pagination(assigns) do
    ~H"""
    <nav :if={@collection.pagination} {merge(@collection.pagination.attrs, "pagination", @class, @rest)}>
      <span :if={@collection.pagination.summary} class="cinder-summary">
        {@collection.pagination.summary}
      </span>
      <button {styled(@collection.pagination.prev.attrs, "page")}>{@collection.pagination.prev.label}</button>
      <%= for page <- @collection.pagination.pages do %>
        <span :if={page.kind == :gap} {styled(page.attrs, "page")}>{page.label}</span>
        <button :if={page.kind != :gap} {styled(page.attrs, "page")}>{page.label}</button>
      <% end %>
      <button {styled(@collection.pagination.next.attrs, "page")}>{@collection.pagination.next.label}</button>
    </nav>
    """
  end

  # A component's own attrs plus whatever the caller passed: classes are added,
  # and the caller's attrs win, except where Cinder's own value for one of these
  # is what its wiring and styling depend on
  @protected ["id", "name", "form", "phx-target"]

  defp merge(ours, part, class, rest) do
    theirs = Map.new(rest, fn {key, value} -> {to_string(key), value} end)

    # Cinder's own value wins only where it has one
    ours
    |> styled(part)
    |> Map.merge(theirs, fn key, our_value, their_value ->
      if key in @protected, do: our_value, else: their_value
    end)
    |> Map.update("class", class, &[&1, class])
  end

  # What these components render gets a `cinder-<part>` class: the part's name, and
  # what Cinder's CSS styles. Attribute maps carry no name or class, so your own
  # markup spreading them is never styled by Cinder. Public for filter types' controls.
  @doc false
  def styled(attrs, part),
    do: Map.update(attrs, "class", "cinder-" <> part, &["cinder-" <> part, &1])
end
