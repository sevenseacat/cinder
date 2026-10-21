defmodule Cinder.Next.Collection do
  @moduledoc """
  Spike: one collection, as a value. The config, the `Cinder.Next.State`, the
  loaded page and its status, with every event as a function returning the new
  collection and the effects to carry out:

    * `:load`: run `load_fun/1` (async or not) and hand the result to `loaded/2`
    * `{:url, params}`: patch the URL; the params come back through `apply_url/2`

  Nothing here touches a socket, so the same core can live in a LiveComponent
  (`Cinder.Next.Component`) or in a LiveView's assigns.
  """
  alias Cinder.Next.{State, View}
  alias Cinder.{FilterManager, QueryBuilder}

  defstruct [
    :id,
    :config,
    :state,
    page: nil,
    status: :loading,
    bulk_result: nil,
    url_synced?: false
  ]

  @type effect :: :load | {:url, map()}

  @doc """
  A new collection, loading. `url_params` are the URL's params when it's URL-synced,
  or `nil`.
  """
  def new(id, config, url_params) do
    state =
      State.new(
        page_size: config.page_size,
        layout: config.default_layout,
        layouts: config.layouts,
        sort: QueryBuilder.extract_query_sorts(config.query, config.engine_columns)
      )

    collection = %__MODULE__{id: id, config: config, state: state, url_synced?: url_params != nil}
    {%{collection | state: from_url(collection, state, url_params)}, [:load]}
  end

  @doc """
  The URL changed (our own patch coming back, or browser back/forward). Loads only
  if the query changed.
  """
  def apply_url(collection, nil), do: {collection, []}

  def apply_url(collection, params) do
    new = from_url(collection, collection.state, params)

    if State.query_changed?(collection.state, new) do
      {%{collection | state: new}, [:load]}
    else
      # The rest of the state stays (raw input in particular), but the layout is
      # in the URL too
      {%{collection | state: %{collection.state | layout: new.layout}}, []}
    end
  end

  def handle_event(collection, "sort", %{"field" => field}) do
    case collection.config.fields[field] do
      %{sort: %{cycle: cycle}} -> commit(collection, &State.toggle_sort(&1, field, cycle))
      _not_sortable -> {collection, []}
    end
  end

  def handle_event(%{config: config} = collection, "filter", params) do
    raw = Map.get(params, "filters", %{})
    filters = FilterManager.params_to_filters(raw, config.engine_columns)
    search = Map.get(params, "search", collection.state.search)
    sort = parse_sort(params["sort_by"], config)

    commit(collection, fn state ->
      state =
        state
        |> State.set_filters(filters, search, raw)
        |> State.set_arguments(Map.new(config.argument_fields, &{&1, raw[&1]}))

      if sort, do: State.set_sort(state, sort), else: state
    end)
  end

  def handle_event(collection, "clear_all", _params),
    do: commit(collection, &State.clear_all/1)

  def handle_event(collection, "clear_filter", %{"field" => field}),
    do: commit(collection, &State.clear_filter(&1, field))

  def handle_event(collection, "go_to_page", %{"page" => page}) do
    case Integer.parse(page) do
      {number, ""} -> commit(collection, &State.go_to_page(&1, number))
      _ -> {collection, []}
    end
  end

  def handle_event(collection, "set_layout", %{"layout" => layout}),
    do: commit(collection, &State.set_layout(&1, layout))

  def handle_event(collection, "go_to_cursor", %{"after" => cursor}),
    do: commit(collection, &State.go_to_cursor(&1, :after, cursor))

  def handle_event(collection, "go_to_cursor", %{"before" => cursor}),
    do: commit(collection, &State.go_to_cursor(&1, :before, cursor))

  def handle_event(collection, "toggle_select", %{"id" => id}) do
    ids = selectable_ids(collection)
    commit(collection, &State.toggle_selected(&1, id, ids))
  end

  def handle_event(collection, "toggle_select_page", _params) do
    ids = selectable_ids(collection)
    commit(collection, &State.toggle_page_selected(&1, ids))
  end

  def handle_event(collection, "clear_selection", _params),
    do: commit(collection, &State.clear_selected/1)

  # Found by name, so an unknown one does nothing. One with a `confirm` only asks;
  # it runs from "confirm_action", which only runs the action that's pending.
  def handle_event(collection, "bulk_action", %{"name" => name}) do
    case bulk_action(collection, name) do
      nil -> {collection, []}
      %{confirm: nil} = action -> run_bulk_action(collection, action)
      _confirm -> commit(collection, &State.request_action(&1, name))
    end
  end

  def handle_event(collection, "confirm_action", _params) do
    case bulk_action(collection, collection.state.pending_action) do
      nil -> {collection, []}
      action -> run_bulk_action(collection, action)
    end
  end

  def handle_event(collection, "cancel_action", _params),
    do: commit(collection, &State.cancel_action/1)

  def handle_event(collection, _event, _params), do: {collection, []}

  @doc "A function that runs the collection's query, for `start_async` or a direct call."
  def load_fun(%{config: config, state: state}) do
    opts =
      [
        scope: config.scope,
        action: config.action,
        query_opts: config.query_opts,
        columns: config.engine_columns,
        search_fn: config.search[:fn],
        pagination_mode: config.pagination
      ] ++ State.query_options(state)

    fn -> QueryBuilder.build_and_execute(config.query, opts) end
  end

  def loading(collection), do: %{collection | status: :loading}

  def loaded(collection, {:ok, page}),
    do: %{collection | page: page, status: :idle, state: %{collection.state | errors: %{}}}

  # Errors about an argument filter belong on that filter, not the whole collection.
  # When every error does, the collection is `:invalid` (waiting on better input)
  # rather than `:error`.
  def loaded(collection, {:error, error}) do
    arguments = collection.config.argument_fields

    {field_errors, other} =
      error
      |> List.wrap()
      |> Enum.flat_map(&Map.get(&1, :errors, [&1]))
      |> Enum.split_with(&(to_string(Map.get(&1, :field)) in arguments))

    errors =
      field_errors
      |> Enum.map(&AshPhoenix.FormData.Error.to_form_error/1)
      |> Enum.group_by(&to_string(elem(&1, 0)), &interpolate/1)

    status = if field_errors != [] and other == [], do: :invalid, else: :error
    %{collection | page: nil, status: status, state: %{collection.state | errors: errors}}
  end

  def loaded(collection, _exit), do: %{collection | status: :error}

  @doc """
  The view-model, with events sent to `target`: a LiveComponent's `@myself`, or
  `{:live_view, name}` for a collection kept in a LiveView's assigns. There, each
  event is named `cinder:<name>:<event>` with no `phx-target`, so the LiveView's
  hook can tell which collection it's for, and the app's own events don't clash.
  """
  def view(collection, {:live_view, name}) do
    prefix = "cinder:#{name}:"
    %{rewire(view(collection, nil), prefix) | event_prefix: prefix}
  end

  def view(collection, target) do
    View.build(%{
      config: collection.config,
      state: collection.state,
      page: collection.page,
      status: collection.status,
      bulk_result: collection.bulk_result,
      myself: target
    })
  end

  # Every attribute map in the view-model, wherever it is: records and other structs
  # are left alone, apart from the filters, which hold view-models of their own
  defp rewire(%Cinder.Next.Filters{list: list}, prefix),
    do: Cinder.Next.Filters.new(Enum.map(list, &rewire(&1, prefix)))

  defp rewire(%_{} = struct, _prefix), do: struct
  defp rewire(list, prefix) when is_list(list), do: Enum.map(list, &rewire(&1, prefix))

  defp rewire(map, prefix) when is_map(map) do
    map = Map.new(map, fn {key, value} -> {key, rewire(value, prefix)} end)

    if Map.has_key?(map, "phx-target") do
      ["phx-click", "phx-change", "phx-submit"]
      |> Enum.reduce(Map.delete(map, "phx-target"), fn key, map ->
        case map do
          %{^key => event} when is_binary(event) -> %{map | key => prefix <> event}
          _ -> map
        end
      end)
    else
      map
    end
  end

  defp rewire(other, _prefix), do: other

  # The one path for every user-driven state change. When URL-synced, the URL is
  # the source of truth: only the new params go out, and the state is applied (and
  # loaded) in `apply_url/2` when they come back. Applying it here too would render
  # twice, because the patch re-renders the parent, and slot closures capture the
  # parent's assigns, so every cell would be sent again with the same rows.
  #
  # Raw form input isn't part of the query, so it's kept straight away either way.
  defp commit(collection, transition) do
    old = collection.state
    new = transition.(old)

    filter_order = collection.config.filter_order
    params = State.to_url_params(new, filter_order)

    cond do
      # Anything the URL holds (the query, the layout) goes through it
      collection.url_synced? and params != State.to_url_params(old, filter_order) ->
        {%{collection | state: %{old | raw: new.raw}}, [{:url, params}]}

      State.query_changed?(old, new) ->
        {%{collection | state: new}, [:load]}

      true ->
        {%{collection | state: new}, []}
    end
  end

  defp from_url(_collection, state, nil), do: state

  defp from_url(%{config: config}, state, params),
    do: State.from_url_params(state, params, config.engine_columns, config.argument_fields)

  # The ids of the records served on this page that can be selected: the only ones a
  # client may add to the selection
  defp selectable_ids(%{config: config, page: %{results: results}}) do
    for record <- results, View.selectable?(config.selectable, record), do: to_string(record.id)
  end

  defp selectable_ids(_collection), do: []

  defp bulk_action(collection, name),
    do: Enum.find(collection.config.bulk_actions, &(&1.name == name))

  # Spike: through the existing executor, on the selected ids. Scoping to the base
  # query, and "all matching", are engine work with their own tickets. Unlike the
  # rest of this module it has a side effect (the action itself), run here because
  # its result decides the new state.
  defp run_bulk_action(%{config: config, state: state} = collection, action) do
    ids = MapSet.to_list(state.selected)

    result =
      Cinder.BulkActionExecutor.execute(action.action,
        resource: config.resource || config.query.resource,
        ids: ids,
        scope: config.scope,
        action_opts: action.action_opts
      )

    case result do
      # Some records failed: keep the selection, so they can be retried
      {:ok, %Ash.BulkResult{status: :partial_success, errors: errors}} ->
        result = %{status: :partial, action: action.label, errors: errors}
        {%{collection | bulk_result: result, state: State.cancel_action(state)}, [:load]}

      {:ok, _result} ->
        result = %{status: :ok, action: action.label, count: length(ids)}
        {%{collection | bulk_result: result, state: State.clear_selected(state)}, [:load]}

      {:error, reason} ->
        result = %{status: :error, action: action.label, errors: List.wrap(reason)}
        {%{collection | bulk_result: result, state: State.cancel_action(state)}, []}
    end
  end

  # The dropdown's value, in the URL's encoding: "" for none, "-field" for descending.
  # Only declared sorts are accepted; anything else leaves the sort alone.
  defp parse_sort(nil, _config), do: nil
  defp parse_sort("", _config), do: []

  defp parse_sort(value, config) do
    {field, direction} =
      case value do
        "-" <> field -> {field, :desc}
        field -> {field, :asc}
      end

    if field in config.sort_order, do: [{field, direction}]
  end

  # A real version would hand these to the app's error translation, as forms do
  defp interpolate({_field, message, vars}) do
    Enum.reduce(vars, message, fn {key, value}, message ->
      String.replace(message, "%{#{key}}", to_string(value))
    end)
  end
end
