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
  end

  slot :sort, doc: "Declares a sortable field" do
    attr :field, :string, required: true
    attr :label, :string
    attr :cycle, :list
  end

  slot :pagination,
    doc: "Replaces the default pagination. Receives the pagination view-model via `:let`."

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

  # `Cinder.UrlSync.handle_params/3` keeps the raw URL params under `:filters`
  defp url_params(%{filters: params}), do: params
  defp url_params(_url_state), do: nil

  attr :search, :map, required: true

  def search(assigns) do
    ~H"""
    <div {@search.attrs}>
      <label for={@search.input_attrs["id"]}>{@search.label}</label>
      <input {@search.input_attrs} />
      <button {@search.clear_attrs}>×</button>
    </div>
    """
  end

  attr :filter, :map, required: true

  @doc """
  A filter: its `<:filter>` slot's content if it has any, otherwise the default
  markup for its type. Either way it gets the filter's view-model.
  """
  def filter(%{filter: %{render: render}} = assigns) when render != nil do
    ~H"""
    {render_slot(@filter.render, @filter)}
    """
  end

  def filter(assigns) do
    ~H"""
    <div {@filter.attrs}>
      <label {@filter.label_attrs}>{@filter.label}</label>
      <input :if={@filter.type == :text} {@filter.input_attrs} />
      <select :if={@filter.type == :select} {@filter.input_attrs}>
        <option :for={option <- @filter.options} {option.attrs}>{option.label}</option>
      </select>
      <button {@filter.clear_attrs}>×</button>
      <p :if={@filter.help} {@filter.help_attrs}>{@filter.help}</p>
    </div>
    """
  end

  attr :view, :map, required: true

  def table(assigns) do
    ~H"""
    <table data-part="grid">
      <thead>
        <tr>
          <th :for={column <- @view.columns} {column.attrs}>
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
        <tr :for={row <- @view.rows} {row.attrs}>
          <td :for={column <- @view.columns} data-part="cell" data-field={column.field}>
            <%= if column.slot[:inner_block] do %>
              {render_slot(column.slot, row.record)}
            <% else %>
              {View.field_value(row.record, column.field)}
            <% end %>
          </td>
        </tr>
        <tr :if={@view.rows == [] and @view.status == :idle} data-part="empty">
          <td colspan={length(@view.columns)}>{dgettext("cinder", "No results found")}</td>
        </tr>
        <tr :if={@view.status == :error} data-part="error">
          <td colspan={length(@view.columns)}>
            {dgettext("cinder", "An error occurred while loading data")}
          </td>
        </tr>
      </tbody>
    </table>
    """
  end

  attr :pagination, :map, required: true

  def pagination(assigns) do
    ~H"""
    <nav {@pagination.attrs}>
      <span :if={@pagination.summary} data-part="summary">{@pagination.summary}</span>
      <button {@pagination.prev.attrs}>{@pagination.prev.label}</button>
      <%= for page <- @pagination.pages do %>
        <span :if={page.kind == :gap} {page.attrs}>{page.label}</span>
        <button :if={page.kind != :gap} {page.attrs}>{page.label}</button>
      <% end %>
      <button {@pagination.next.attrs}>{@pagination.next.label}</button>
    </nav>
    """
  end
end
