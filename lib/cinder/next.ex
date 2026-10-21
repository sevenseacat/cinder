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

  The other components here (`search/1`, `filter/1`, `table/1`,
  `pagination/1`) are the default renderings of each region, from its view-model.
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

  slot :sort, doc: "Declares a sortable field" do
    attr :field, :string, required: true
    attr :label, :string
    attr :cycle, :list
  end

  slot :item, doc: "A grid layout's card for each record, via `:let`"

  # Region slots replace one region of the default page. Like `:page`, they receive the whole collection view-model via `:let`.
  slot :toolbar, doc: "Replaces the region above the results (search, filters, sort)"
  slot :pagination, doc: "Replaces the pagination below the results"

  slot :page,
    doc: """
    Replaces the whole default page (toolbar, results, pagination), receiving the
    collection view-model via `:let`. Compose it from the components in this module
    and your own markup, rendering the records as `c.layout` says (`:table`/`:grid`).
    It places the filter form itself, `<form {c.form_attrs}>`, around its inputs;
    inputs that can't go inside it (like a teleported modal's) join it with
    `form={c.form_id}`.
    """

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
      {merge(%{"data-part" => "toolbar"}, @class, @rest)}
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
    <div :if={@layouts != []} {merge(%{"data-part" => "layout-switch", "role" => "group"}, @class, @rest)}>
      <button :for={layout <- @layouts} {layout.attrs}>{layout.label}</button>
    </div>
    """
  end

  attr :search, :map, required: true
  attr :class, :any, default: nil
  attr :rest, :global

  def search(assigns) do
    ~H"""
    <div {merge(@search.attrs, @class, @rest)}>
      <label for={@search.input_attrs["id"]}>{@search.label}</label>
      <input {@search.input_attrs} />
      <button {@search.clear_attrs}>×</button>
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

  # A group of checkboxes is labelled by a legend, not a label pointing at one input
  def filter(%{filter: %{type: type}} = assigns)
      when type in [:multi_select, :multi_checkboxes] do
    ~H"""
    <fieldset {merge(@filter.attrs, @class, @rest)}>
      <legend>{@filter.label}</legend>
      <label :for={option <- @filter.options} data-part="filter-option">
        <input {option.input_attrs} /> {option.label}
      </label>
      <button {@filter.clear_attrs}>×</button>
      <p :if={@filter.help} {@filter.help_attrs}>{@filter.help}</p>
    </fieldset>
    """
  end

  def filter(assigns) do
    ~H"""
    <div {merge(@filter.attrs, @class, @rest)}>
      <label {@filter.label_attrs}>{@filter.label}<span :if={@filter.required?} aria-hidden="true"> *</span></label>
      <input :if={@filter.type == :text} {@filter.input_attrs} />
      <select :if={@filter.type == :select} {@filter.input_attrs}>
        <option :for={option <- @filter.options} {option.attrs}>{option.label}</option>
      </select>
      <span :if={@filter.type == :autocomplete} data-part="filter-autocomplete">
        <input {@filter.input_attrs} />
        <label :for={option <- @filter.options} data-part="filter-option">
          <input {option.input_attrs} /> {option.label}
        </label>
      </span>
      <span :if={@filter.type == :number_range} data-part="filter-range">
        <input {@filter.input_attrs.min} />
        <span>{dgettext("cinder", "to")}</span>
        <input {@filter.input_attrs.max} />
      </span>
      <button {@filter.clear_attrs}>×</button>
      <p :if={@filter.help} {@filter.help_attrs}>{@filter.help}</p>
      <p :if={@filter.errors != []} {@filter.error_attrs}>{Enum.join(@filter.errors, ", ")}</p>
    </div>
    """
  end

  attr :sort_select, :map, required: true
  attr :class, :any, default: nil
  attr :rest, :global

  @doc "An exclusive sort as a dropdown: the default for layouts without column headers."
  def sort_select(assigns) do
    ~H"""
    <div {merge(@sort_select.attrs, @class, @rest)}>
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
    <ul {merge(@collection.grid_attrs, @class, @rest)}>
      <li :for={row <- @collection.rows} {row.attrs}>
        <input :if={row.select_attrs} {row.select_attrs} />
        {render_slot(if(@inner_block != [], do: @inner_block, else: @collection.item_slot), row.record)}
      </li>
    </ul>
    <p :if={@collection.rows == [] and @collection.status == :idle} data-part="empty">
      {dgettext("cinder", "No results found")}
    </p>
    <p :if={@collection.status == :error} data-part="error">
      {dgettext("cinder", "An error occurred while loading data")}
    </p>
    """
  end

  attr :collection, :map, required: true
  attr :class, :any, default: nil
  attr :rest, :global

  def table(assigns) do
    ~H"""
    <table {merge(%{"data-part" => "table"}, @class, @rest)}>
      <thead>
        <tr>
          <th :if={@collection.selection} data-part="select-cell">
            <input {@collection.selection.page_attrs} />
          </th>
          <th :for={column <- @collection.columns} {column.attrs}>
            <%= if column.sortable? do %>
              <button {column.sort_attrs}>
                {column.label}<span {column.indicator_attrs}></span>
              </button>
            <% else %>
              {column.label}
            <% end %>
          </th>
        </tr>
      </thead>
      <tbody>
        <tr :for={row <- @collection.rows} {row.attrs}>
          <td :if={row.select_attrs} data-part="select-cell"><input {row.select_attrs} /></td>
          <td :for={column <- @collection.columns} data-part="cell" data-field={column.field}>
            <%= if column.slot[:inner_block] do %>
              {render_slot(column.slot, row.record)}
            <% else %>
              {View.field_value(row.record, column.field)}
            <% end %>
          </td>
        </tr>
        <tr :if={@collection.rows == [] and @collection.status == :idle} data-part="empty">
          <td colspan={length(@collection.columns) + if(@collection.selection, do: 1, else: 0)}>{dgettext("cinder", "No results found")}</td>
        </tr>
        <tr :if={@collection.status == :error} data-part="error">
          <td colspan={length(@collection.columns) + if(@collection.selection, do: 1, else: 0)}>
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
      {merge(%{"data-part" => "bulk-bar"}, @class, @rest)}
    >
      <span data-part="selection-count">{@collection.selection.summary}</span>
      <button :for={action <- @collection.bulk_actions} {action.attrs}>{action.label}</button>
      <button {@collection.selection.clear_attrs}>{dgettext("cinder", "Clear all")}</button>
      <div :if={@collection.confirmation} {@collection.confirmation.attrs}>
        <p>{@collection.confirmation.message}</p>
        <button {@collection.confirmation.confirm_attrs}>{@collection.confirmation.action}</button>
        <button {@collection.confirmation.cancel_attrs}>{dgettext("cinder", "Cancel")}</button>
      </div>
    </div>
    """
  end

  attr :collection, :map, required: true
  attr :class, :any, default: nil
  attr :rest, :global

  @doc "The whole pagination region: summary, previous/next and page links"
  def pagination(assigns) do
    ~H"""
    <nav :if={@collection.pagination} {merge(@collection.pagination.attrs, @class, @rest)}>
      <span :if={@collection.pagination.summary} data-part="summary">
        {@collection.pagination.summary}
      </span>
      <button {@collection.pagination.prev.attrs}>{@collection.pagination.prev.label}</button>
      <%= for page <- @collection.pagination.pages do %>
        <span :if={page.kind == :gap} {page.attrs}>{page.label}</span>
        <button :if={page.kind != :gap} {page.attrs}>{page.label}</button>
      <% end %>
      <button {@collection.pagination.next.attrs}>{@collection.pagination.next.label}</button>
    </nav>
    """
  end

  # A component's own attrs plus whatever the caller passed: classes are added,
  # and the caller's attrs win, except where Cinder's own value for one of these
  # is what its wiring and styling depend on
  @protected ["data-part", "id", "name", "form", "phx-target"]

  defp merge(ours, class, rest) do
    theirs = Map.new(rest, fn {key, value} -> {to_string(key), value} end)

    # Cinder's own value wins only where it has one
    ours
    |> Map.merge(theirs, fn key, our_value, their_value ->
      if key in @protected, do: our_value, else: their_value
    end)
    |> Map.update("class", class, &[&1, class])
  end
end
