# SPDX-FileCopyrightText: 2026 Cinder contributors <https://github.com/sevenseacat/cinder/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Cinder.Next do
  @moduledoc """
  Cinder 1.0's collection, being built alongside `Cinder.collection/1`.

  When it's finished, it becomes `Cinder.collection/1` and the old one is removed. Until
  then it's only on `main`, not in a release, and its API may change.
  """

  use Phoenix.Component

  attr :id, :string, required: true, doc: "The collection's id, unique on the page"
  attr :resource, :atom, doc: "The Ash resource to read (or give a `query`)"
  attr :query, :any, doc: "The Ash query to read (or give a `resource`)"

  attr :action, :any,
    doc: "The read action, if not the query's or the primary read (atom or string)"

  attr :actor, :any, doc: "The actor to read as"
  attr :tenant, :any, doc: "The tenant to read in"
  attr :scope, :any, doc: "An Ash scope"

  attr :query_opts, :list,
    default: [],
    doc: "More options for the read, as `Ash.read/2` takes them"

  attr :sort, :list,
    default: [],
    doc: "How the collection sorts: `[mode: :additive | :exclusive]`"

  attr :search, :list,
    default: [],
    doc: "How the collection searches: `[label: ..., placeholder: ..., fn: ...]`"

  attr :pagination, :list, default: [], doc: "How the collection pages: `[mode: ..., size: ...]`"

  attr :url_state, :map,
    doc: "The LiveView's `@url_state` (`use Cinder.UrlSync`), to keep its state in the URL"

  attr :selectable, :any,
    default: false,
    doc: "Whether records can be selected: `true`, or a function given each record"

  attr :on_selection_change, :atom,
    doc: "A message to send the LiveView when the selection changes"

  attr :on_bulk_action_result, :atom,
    doc: "A message to send the LiveView when a bulk action has run"

  attr :bulk_action_confirm, :any,
    doc: "A function component asking the user to confirm a bulk action"

  slot :field,
    required: true,
    doc: "A field, shown as a column with its content for each record" do
    attr :name, :string,
      required: true,
      doc:
        "An attribute, calculation or aggregate, or a path through relationships " <>
          "(`artist.name`) or embedded resources (`details__label`)"

    attr :label, :string, doc: "The column's heading. Defaults to the humanised name."

    attr :column, :boolean,
      doc: "Whether it's a column (default `true`). One that isn't can still be filtered."

    attr :sort, :any, doc: "Sort by the field: `true`, or `[cycle: [...]]`"

    attr :filter, :any,
      doc:
        "Filter by the field: `true`, or `[type: ..., label: ..., ...]` with the type's options"

    attr :search, :boolean, doc: "Search the field from the search box"
  end

  slot :argument,
    doc:
      "A read action argument, with an input for its value. Unlike a filter's, a new " <>
        "value clears the selection, as it changes what the action reads." do
    attr :name, :string, required: true, doc: "The read action's argument"
    attr :param, :string, doc: "What it goes by in the form and the URL, if not its name"

    attr :input, :list,
      doc: "Its input, as a filter's: `[type: ..., label: ..., ...]` with the type's options"
  end

  slot :bulk_action, doc: "An action to run on the selected records, with a button" do
    attr :action, :any,
      required: true,
      doc: "An update or destroy action, or a function given a query for the selected records"

    attr :name, :string, doc: "What it goes by in events. Defaults to the action's name."
    attr :label, :string, doc: "Its button's text. Defaults to the humanised name."
    attr :confirm, :string, doc: "A question to confirm before it runs, with `{count}`"

    attr :action_opts, :list,
      doc: "More options for the action: Ash's bulk update or destroy options, or the function's"
  end

  @doc """
  Shows an Ash resource's records in a table, for the user to sort, filter, search and
  page through.

  ```heex
  <Cinder.Next.collection id="albums" resource={MyApp.Album} actor={@current_user}>
    <:field :let={album} name="title" sort filter search>{album.title}</:field>
    <:field :let={album} name="artist.name" sort>{album.artist.name}</:field>
    <:field :let={album} name="release_date" label="Released" sort filter>
      {album.release_date}
    </:field>
  </Cinder.Next.collection>
  ```

  It reads with the resource's primary read action, as the `actor`, and loads what each
  `<:field>` names, relationships included. It's a LiveComponent, so it goes in a LiveView.

  [INSERT LVATTRDOCS]

  ## Fields

  ```heex
  <:field :let={album} name="artist.name" label="Band">{album.artist.name}</:field>
  <:field name="genre" filter column={false} />
  ```

  A `<:field>` names an attribute, calculation or aggregate, or a path through
  relationships (`artist.name`) or embedded resources (`details__label`), and Cinder
  loads it. Its column's heading is its `label`, or the humanised name ("Artist > Name"),
  and its cells are its content, given each record with `:let`. A field with
  `column={false}` has no column and needs no content, but can still be filtered or
  searched. Each field is declared once.

  ## Sorting

  ```heex
  <Cinder.Next.collection id="albums" resource={MyApp.Album} sort={[mode: :exclusive]}>
    <:field :let={album} name="title" sort>{album.title}</:field>
    <:field :let={album} name="release_date" sort={[cycle: [:desc, :asc]]}>
      {album.release_date}
    </:field>
  </Cinder.Next.collection>
  ```

  Clicking a sortable column's heading steps through its `cycle`: ascending, descending,
  then unsorted, by default. A cycle without `nil` is never unsorted, so the collection
  starts sorted by that column. The collection also starts with its query's own sorts.

  By default (`mode: :additive`), the column clicked last is the main sort, and the
  ones clicked before it break ties. With `mode: :exclusive`, it's the only sort.

  ## Filters

  ```heex
  <:field :let={album} name="title" filter>{album.title}</:field>
  <:field name="genre" filter={[type: :radio_group, label: "Style", prompt: "Any"]} column={false} />
  ```

  Each filtered field gets a control above the table. Its type is inferred from the
  field (text for a string, a select of an enum's values, a date range for a date), or
  given as `type`. Its label is the column's, or `label`, and any other keys are the
  type's own options. Changing a filter goes back to the first page.

  ## Search

  ```heex
  <Cinder.Next.collection id="albums" resource={MyApp.Album} search={[placeholder: "Title or artist"]}>
    <:field :let={album} name="title" search>{album.title}</:field>
    <:field name="artist.name" search column={false} />
  </Cinder.Next.collection>
  ```

  The collection has a search box when any field has `search`. A record matches when
  any searchable field contains the text, ignoring case. To search another way, give
  `search={[fn: &MyApp.Search.albums/3]}`: it's called with the `Ash.Query`, the
  searchable fields (`%{name: "artist.name", expr: ...}`, with an Ash expression for
  each) and the text, and returns the query. Give a named function, as here, rather
  than one written in the template: a new search function could find other records,
  so the collection goes back to the first page and clears the selection, and one
  written in the template is new each time the collection renders.

  ## Pagination

  ```heex
  <Cinder.Next.collection id="albums" resource={MyApp.Album} pagination={[mode: :keyset, size: 10]}>
  ```

  A collection pages when its read action can: by offset if it can, or else by keyset,
  25 records a page. Offset pages show "Page 2 of 13" when the action can count. An
  action that can't page shows every record, and giving `pagination` for it, or a mode
  it can't page by, is an error.

  ## Keeping it in the URL

  ```elixir
  defmodule MyAppWeb.AlbumsLive do
    use MyAppWeb, :live_view
    use Cinder.UrlSync

    def render(assigns) do
      ~H\"""
      <Cinder.Next.collection id="albums" resource={MyApp.Album} url_state={@url_state}>
        <:field :let={album} name="title" sort filter>{album.title}</:field>
      </Cinder.Next.collection>
      \"""
    end
  end
  ```

  With `use Cinder.UrlSync` and `url_state={@url_state}`, the sort, filters, search,
  argument values and page are kept in the URL, so they can be bookmarked and shared,
  and back and forward work. The app's own params are kept. For now, only one
  collection on a page can be kept in the URL.

  ## Read action arguments

  ```heex
  <Cinder.Next.collection id="albums" resource={MyApp.Album} action={:by_genre}>
    <:field :let={album} name="title">{album.title}</:field>
    <:argument name="genre" input={[prompt: "Choose a genre"]} />
  </Cinder.Next.collection>
  ```

  Each `<:argument>` gets an input above the filters for the read action's argument,
  its type inferred as a filter's is. Name the action with `action`, rather than in a
  prepared `query`, for its arguments to be given. While a required argument has no
  value, nothing is read. A value the action can't use shows Ash's message under the
  input. `param` gives the argument another name in the form and the URL, for one
  that's taken (by a field, or one of the collection's own params, such as `search`).

  ## Selection

  ```heex
  <Cinder.Next.collection
    id="albums"
    resource={MyApp.Album}
    selectable={&(&1.genre != :classical)}
    on_selection_change={:albums_selected}
  >
  ```

  With `selectable`, each row gets a checkbox, and the heading's selects the page. A
  function says which records can be. Records are told apart by their primary key,
  which must be a single attribute. The selection stays through paging, sorting,
  filtering and search, so it can include records that aren't shown. A new argument
  value clears it, as it changes what's read.

  `on_selection_change` sends the LiveView
  `{name, %{selected_ids: MapSet, selected_count:, component_id:}}`, with the ids as
  strings, each time the selection changes.

  ## Bulk actions

  ```heex
  <Cinder.Next.collection
    id="albums"
    resource={MyApp.Album}
    selectable
    on_bulk_action_result={:bulk_action_done}
  >
    <:field :let={album} name="title">{album.title}</:field>
    <:bulk_action action={:remaster} />
    <:bulk_action action={:destroy} label="Delete" confirm="Delete {count} albums?" />
    <:bulk_action name="export" action={&MyApp.Exports.albums/2} />
  </Cinder.Next.collection>
  ```

  Each bulk action gets a button in a bar above the table, for the selected records.
  `action` is an update or destroy action, or a function given an `Ash.Query` for the
  selected records and the options a code interface takes (`actor`, `tenant`, `scope`,
  and `action_opts` as `bulk_options`). It runs within what the collection reads (its
  query, action, argument values, actor, tenant and scope), but not its filters or
  search, which only hide records: a selected record they hide is still acted on.

  After a success, or a partial success, the selection is cleared and the records are
  read again. After an error the selection is kept, to try again.

  ### The result

  `on_bulk_action_result` sends the LiveView
  `{name, %{bulk_action:, status:, selected_count:, result:, errors:, component_id:}}`.
  `status` is `:success`, `:partial_success` (some records failed, and the rest
  changed) or `:error`. Cinder doesn't show the user anything after a failure, so show
  it from here:

  ```elixir
  def handle_info({:bulk_action_done, %{status: :success}}, socket) do
    {:noreply, put_flash(socket, :info, "Done")}
  end

  def handle_info({:bulk_action_done, %{bulk_action: name}}, socket) do
    {:noreply, put_flash(socket, :error, "\#{name} didn't work for every album")}
  end
  ```

  `selected_count` is how many records were selected, not how many changed: a selected
  record the read no longer reaches is skipped. For how many changed, give the action
  `action_opts={[return_records?: true]}` and count `result.records`.

  ### Confirming

  An action with a `confirm` asks first, in a modal `<dialog>`, with `{count}` filled
  in. The modal needs [Cinder's hooks](getting-started.md#by-hand) registered: without
  them, the question shows in place. A confirm less than 500ms after the question shows
  is ignored, as a slow double click on the action. To change that:

  ```elixir
  config :cinder, bulk_action_confirm_delay: 300
  ```

  To ask with your own component, give it as `bulk_action_confirm`, or for every
  collection:

  ```elixir
  config :cinder, bulk_action_confirm: &MyAppWeb.Confirm.bulk_action/1
  ```

  It's given `id`, `name`, `label`, `message` (the `confirm`, with `{count}` filled
  in), `count`, and `confirm` and `cancel` (commands for `phx-click`):

  ```elixir
  def bulk_action(assigns) do
    ~H\"""
    <div id={@id} role="alertdialog" aria-label={@label}>
      <p>{@message}</p>
      <button type="button" phx-click={@cancel}>Cancel</button>
      <button type="button" phx-click={@confirm}>{@label}</button>
    </div>
    \"""
  end
  ```
  """
  # Runs on every parent render, so it only hands everything on: the collection
  # works out what's changed. The id is checked here, as the LiveComponent can't
  # exist without one.
  def collection(assigns) do
    if !assigns[:id] do
      raise ArgumentError, "<Cinder.Next.collection> needs an `id`, unique on the page"
    end

    ~H"""
    <.live_component
      module={Cinder.Next.Collection}
      id={@id}
      options={assigns_to_attributes(assigns, [:field, :argument, :bulk_action])}
      fields={@field}
      arguments={@argument}
      bulk_actions={@bulk_action}
    />
    """
  end
end
