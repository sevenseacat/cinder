# SPDX-FileCopyrightText: 2026 Cinder contributors <https://github.com/sevenseacat/cinder/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Cinder.Next.Collection do
  @moduledoc false
  # The LiveComponent behind `Cinder.Next.collection/1`: its config, what the user
  # has done (a `Cinder.Engine.Query`, for now), and the page of records it shows.

  use Phoenix.LiveComponent
  use Cinder.Messages

  alias Cinder.{Engine, Params, UrlSync}
  alias Cinder.Next.{Config, State}

  # Filter types render with a theme's classes, until theming is redone
  @impl true
  def mount(socket), do: {:ok, assign(socket, :theme, Cinder.Theme.merge("default"))}

  @impl true
  def update(assigns, socket) do
    # The fields' inner blocks are new on every parent render, so they're always
    # taken; the config is only rebuilt, and the records reloaded, when what's
    # declared changes. Only the fields that are columns have cells. Synced to the
    # URL (`url_params` isn't `nil`), a change to the URL's params is applied too.
    declarations =
      Config.declarations(
        assigns.options,
        assigns.fields,
        assigns.arguments,
        assigns.bulk_actions
      )

    columns = Enum.reject(assigns.fields, &(&1[:column] == false))
    url_params = assigns.options[:url_state][:params]
    old = socket.assigns
    url_changed? = url_params != nil and url_params != old[:url_params]
    socket = assign(socket, id: assigns.id, columns: columns, url_params: url_params)

    cond do
      declarations != old[:declarations] ->
        config =
          Config.build(assigns.options, assigns.fields, assigns.arguments, assigns.bulk_actions)

        query = query(old, config, if(url_changed?, do: url_params))

        socket =
          socket
          |> assign(declarations: declarations, config: config)
          |> select(selected(old, config))
          |> show(query)

        # A rebuild that moves the query (back to the first page, say) moves the URL too
        if url_params && !url_changed? && query != old.query, do: patch_url(socket, query)
        {:ok, socket}

      # A change to the app's own params changes nothing here
      url_changed? ->
        query = from_url(url_params, old.config)
        {:ok, if(query == old.query, do: socket, else: show(socket, query))}

      true ->
        {:ok, socket}
    end
  end

  # A rebuild, when the declarations change after mount: the user's sort, filters,
  # arguments and search carry over, and the page too if the records would be the same
  defp query(%{config: old, query: query}, config, nil) do
    sortable = for %Engine.Field{sortable?: true, name: name} <- config.fields, do: name
    filterable = for %{column: column} <- config.filters, do: column.field
    searchable = for %Engine.Field{searchable?: true, name: name} <- config.fields, do: name
    arguments = for %Engine.Argument{param: param} <- config.arguments, do: param
    sort = State.carry_over_sort(query.sort, old.sort.default, config.sort.default, sortable)

    carried = %{
      query
      | sort: sort,
        filters: State.carry_over_inputs(query.filters, filterable),
        arguments: State.carry_over_inputs(query.arguments, arguments),
        search: State.carry_over_search(query.search, searchable),
        page_size: config.pagination[:size]
    }

    State.carry_over_page(carried, query, read(old) == read(config))
  end

  # On mount, or when the URL changes with the declarations: what the URL says
  defp query(_assigns, config, url_params) when url_params != nil do
    from_url(url_params, config)
  end

  # The first build, on mount, before there's a config or query: a new collection
  # starts on page 1 with the default sort
  defp query(_assigns, config, nil), do: start(config)

  # The selection survives a rebuild that reads the same records, while records can
  # still be selected. A new collection has none.
  defp selected(%{config: old, selected: selected}, config) do
    if config.selectable != false and read(old) == read(config), do: selected, else: MapSet.new()
  end

  defp selected(_assigns, _config), do: MapSet.new()

  defp start(config) do
    %Engine.Query{sort: config.sort.default, page_size: config.pagination[:size]}
  end

  # Anything in the URL the collection can't use is left out: it's the user's to edit
  defp from_url(params, config) do
    opts = [
      search?: config.search != nil,
      pagination: config.pagination[:mode],
      arguments: config.arguments,
      sort_mode: config.sort.mode
    ]

    Params.from_url(params, config.fields, start(config), opts)
  end

  # What decides the records read, besides the query
  defp read(config) do
    {Map.take(config, [:source, :action, :actor, :tenant, :scope, :query_opts]),
     config.search[:fn], config.pagination[:mode]}
  end

  @impl true
  def handle_event("sort", %{"field" => field}, socket) do
    %{config: config, query: query} = socket.assigns

    # A field that isn't a sortable column (from a tampered event) is ignored
    case Enum.find(config.columns, &(&1.field == field and &1.sort != nil)) do
      nil ->
        {:noreply, socket}

      column ->
        sort = State.toggle_sort(query.sort, field, column.sort.cycle, config.sort.mode)
        {:noreply, change(socket, State.first_page(%{query | sort: sort}))}
    end
  end

  # The search box and the arguments' inputs are in the filter form. Input for fields
  # that aren't filtered or arguments that aren't declared (from a tampered event) is
  # left out, and a search without a box searches nothing.
  def handle_event("filter", params, socket) do
    %{config: config, query: query} = socket.assigns
    inputs = params["filters"] || %{}

    query = %{
      query
      | filters: Params.filters_from_params(inputs, config.fields),
        arguments: Params.filters_from_params(inputs, config.arguments),
        search: params["search"] || ""
    }

    query = State.first_page(query)
    {:noreply, change(socket, query)}
  end

  # An offset page comes from the client, so one that isn't a positive number is
  # ignored. Each mode's events are ignored in the other (from tampering).
  def handle_event("page", %{"page" => page}, socket) do
    with %{mode: :offset} <- socket.assigns.config.pagination,
         {page, ""} when page > 0 <- Integer.parse(page) do
      {:noreply, change(socket, %{socket.assigns.query | page: page})}
    else
      _not_a_page -> {:noreply, socket}
    end
  end

  # Keyset pages go from the cursors of the page shown, kept on the server
  def handle_event(direction, _params, socket) when direction in ["next_page", "previous_page"] do
    %{config: config, page: page, query: query} = socket.assigns

    with %{mode: :keyset} <- config.pagination,
         {_direction, _cursor} = cursor <- cursor(page, direction) do
      {:noreply, change(socket, %{query | cursor: cursor})}
    else
      _no_page_that_way -> {:noreply, socket}
    end
  end

  # Only the page shown's records that can be selected can be (`selectable_ids`), so a
  # forged id changes nothing
  def handle_event("select", %{"id" => id}, socket) do
    %{selected: selected, selectable_ids: selectable} = socket.assigns
    {:noreply, select(socket, State.toggle_selected(selected, id, selectable))}
  end

  # The page's box is checked when all of the page is selected, so clicking it clears
  # the page, and otherwise selects it
  def handle_event("select_page", _params, socket) do
    %{selected: selected, selectable_ids: selectable} = socket.assigns

    selected =
      if State.page_selected?(selected, selectable) do
        State.clear_page(selected, selectable)
      else
        State.select_page(selected, selectable)
      end

    {:noreply, select(socket, selected)}
  end

  def handle_event("clear_selection", _params, socket) do
    {:noreply, select(socket, MapSet.new())}
  end

  defp cursor(%{more?: true, last_cursor: cursor}, "next_page"), do: {:after, cursor}
  defp cursor(%{previous?: true, first_cursor: cursor}, "previous_page"), do: {:before, cursor}
  defp cursor(_page, _direction), do: nil

  # The parent hears of each change, if it asked to. A new collection has selected
  # nothing, so mounting one isn't a change.
  defp select(socket, selected) do
    %{config: config, id: id} = socket.assigns

    if config.on_selection_change && selected != (socket.assigns[:selected] || MapSet.new()) do
      count = MapSet.size(selected)
      payload = %{selected_ids: selected, selected_count: count, component_id: id}
      send(self(), {config.on_selection_change, payload})
    end

    assign(socket, :selected, selected)
  end

  # Synced, what the user does changes the URL, and shows when the URL comes back,
  # so the new records and the new URL arrive in one render
  defp change(%{assigns: %{url_params: nil}} = socket, query), do: show(socket, query)

  defp change(socket, query) do
    patch_url(socket, query)
    socket
  end

  defp patch_url(%{assigns: %{config: config}}, query) do
    opts = [arguments: config.arguments]
    params = Params.to_url(query, config.fields, start(config), opts)
    UrlSync.patch(params, owns: Params.url_keys(config.fields, opts))
  end

  defp show(socket, query), do: socket |> assign(:query, query) |> load() |> selectable_ids()

  # The ids of the page's records that can be selected: the only ones the boxes can
  # change. Ids are kept as the strings the boxes carry.
  defp selectable_ids(%{assigns: %{config: config, page: page}} = socket) do
    ids =
      for record <- page.records, selectable?(config.selectable, record), into: MapSet.new() do
        row_id(config, record)
      end

    assign(socket, :selectable_ids, ids)
  end

  defp selectable?(selectable, record) when is_function(selectable, 1), do: selectable.(record)
  defp selectable?(selectable, _record), do: selectable

  defp row_id(config, record), do: to_string(Map.fetch!(record, config.primary_key))

  # Synchronous, and a failed read crashes, until the slices for loading states and
  # errors. The controls' values are worked out here, with the records, rather than
  # in `render/1`, where they'd be new on every render.
  defp load(socket) do
    %{config: config, query: query} = socket.assigns
    opts = Map.take(config, [:action, :actor, :tenant, :scope, :query_opts]) |> Enum.to_list()

    opts =
      [
        search_fn: config.search[:fn],
        pagination: config.pagination[:mode] || :offset,
        count?: config.pagination[:count?] == true
      ] ++ opts

    socket =
      assign(socket,
        filter_values: Params.filter_values(query.filters, config.fields),
        argument_values: Params.filter_values(query.arguments, config.arguments)
      )

    # A read missing a required argument would fail, and a form doesn't say a field
    # is required before it's used
    if Enum.any?(config.arguments, &(&1.required? and !Map.has_key?(query.arguments, &1.param))) do
      assign(socket, page: %Engine.Page{}, argument_errors: %{})
    else
      run(socket, opts)
    end
  end

  defp run(socket, opts) do
    %{config: config, query: query} = socket.assigns
    opts = [arguments: config.arguments] ++ opts

    case {Engine.run(config.source, config.fields, query, opts), query.cursor} do
      {{:ok, page}, _cursor} ->
        assign(socket, page: page, argument_errors: %{})

      # What the user can fix: a value the action can't use. Ash's messages, until
      # they're translated.
      {{:error, %Engine.Error{reason: nil, inputs: inputs}}, _cursor} ->
        errors =
          Map.new(inputs, fn {name, errors} -> {name, Enum.map(errors, &interpolate/1)} end)

        assign(socket, page: %Engine.Page{}, argument_errors: errors)

      # Only a cursor from the URL can fail to read (the others are a page's own), and
      # what the user puts in the URL is dropped
      {{:error, _error}, {_direction, _cursor}} ->
        show(socket, State.first_page(query))
    end
  end

  defp interpolate({message, vars}) do
    Enum.reduce(vars, message, fn {key, value}, message ->
      String.replace(message, "%{#{key}}", var(value))
    end)
  end

  # Lists are chardata to `to_string/1`, so a list of values (`one_of`'s) is joined
  defp var(value) when is_list(value), do: Enum.map_join(value, ", ", &var/1)

  defp var(value) do
    if String.Chars.impl_for(value), do: to_string(value), else: inspect(value)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id}>
      <form
        :if={@config.filters != [] or @config.search != nil or @config.argument_inputs != []}
        id={"#{@id}-filters"}
        phx-change="filter"
        phx-target={@myself}
      >
        <div :for={%{column: column, module: module} <- @config.argument_inputs}>
          <label for={Cinder.Filter.filter_id(@id, column.field)}>{column.label}</label>
          {module.render(column, @argument_values[column.field], @theme, %{
            table_id: @id,
            target: @myself,
            filter_values: @argument_values
          })}
          <p :for={message <- @argument_errors[column.field] || []}>{message}</p>
        </div>
        <div :if={@config.search}>
          <label for={"#{@id}-search"}>{@config.search.label || dgettext("cinder", "Search")}</label>
          <input
            type="search"
            id={"#{@id}-search"}
            name="search"
            value={@query.search}
            placeholder={@config.search.placeholder || dgettext("cinder", "Search...")}
            phx-debounce="300"
          />
        </div>
        <div :for={%{column: column, module: module} <- @config.filters}>
          <label for={Cinder.Filter.filter_id(@id, column.field)}>{column.label}</label>
          {module.render(column, @filter_values[column.field], @theme, %{
            table_id: @id,
            target: @myself,
            filter_values: @filter_values
          })}
        </div>
      </form>
      <.bulk_bar
        :if={@config.bulk_actions != []}
        id={"#{@id}-bulk"}
        bulk_actions={@config.bulk_actions}
        count={MapSet.size(@selected)}
        target={@myself}
      />
      <table>
        <thead>
          <tr>
            <th :if={@config.selectable != false}>
              <input
                type="checkbox"
                aria-label={dgettext("cinder", "Select all on this page")}
                checked={State.page_selected?(@selected, @selectable_ids)}
                disabled={@selectable_ids == MapSet.new()}
                phx-click="select_page"
                phx-target={@myself}
              />
            </th>
            <th
              :for={column <- @config.columns}
              aria-sort={column.sort && aria_sort(direction(@query.sort, column.field))}
            >
              <%= if column.sort do %>
                <button
                  type="button"
                  phx-click="sort"
                  phx-value-field={column.field}
                  phx-target={@myself}
                >
                  {column.label}{indicator(direction(@query.sort, column.field))}
                </button>
              <% else %>
                {column.label}
              <% end %>
            </th>
          </tr>
        </thead>
        <tbody>
          <tr :for={record <- @page.records}>
            <td :if={@config.selectable != false}>
              <.row_box
                id={row_id(@config, record)}
                collection_id={@id}
                selected={@selected}
                selectable_ids={@selectable_ids}
                target={@myself}
              />
            </td>
            <td :for={column <- @columns}>{render_slot(column, record)}</td>
          </tr>
        </tbody>
      </table>
      <nav :if={@config.pagination && (@page.previous? or @page.more?)} aria-label="Pagination">
        <button
          type="button"
          phx-target={@myself}
          disabled={!@page.previous?}
          {page_click(@page, :previous)}
        >
          {dgettext("cinder", "Previous page")}
        </button>
        <span :if={@page.page}>{page_of(@page)}</span>
        <button type="button" phx-target={@myself} disabled={!@page.more?} {page_click(@page, :next)}>
          {dgettext("cinder", "Next page")}
        </button>
      </nav>
    </div>
    """
  end

  # Always shown, so selecting doesn't move the records; the count and clearing
  # appear once something's selected. Screen readers may not announce the count's
  # first appearance (a live region is only reliable once it's there), but the
  # selecting checkbox announces itself, and changes after that are announced.
  defp bulk_bar(assigns) do
    ~H"""
    <section id={@id} aria-label={dgettext("cinder", "Bulk actions")}>
      <div :if={@count > 0} id={"#{@id}-count"} aria-live="polite">
        <p>{dgettext("cinder", "%{count} selected", count: @count)}</p>
        <button type="button" phx-click="clear_selection" phx-target={@target}>
          {dgettext("cinder", "Clear selection")}
        </button>
      </div>
      <button :for={bulk_action <- @bulk_actions} type="button" disabled={@count == 0}>
        {bulk_action.label}
      </button>
    </section>
    """
  end

  defp row_box(assigns) do
    ~H"""
    <input
      type="checkbox"
      id={"#{@collection_id}-select-#{@id}"}
      aria-label={dgettext("cinder", "Select row")}
      checked={@id in @selected}
      disabled={@id not in @selectable_ids}
      phx-click="select"
      phx-value-id={@id}
      phx-target={@target}
    />
    """
  end

  # An offset page (numbered) says which page to go to; a keyset one only which way
  defp page_click(%{page: nil}, direction), do: ["phx-click": "#{direction}_page"]
  defp page_click(%{page: page}, :previous), do: ["phx-click": "page", "phx-value-page": page - 1]
  defp page_click(%{page: page}, :next), do: ["phx-click": "page", "phx-value-page": page + 1]

  # Without a count (the action can't count), there's no total
  defp page_of(%{count: nil, page: page}) do
    dgettext("cinder", "Page %{current}", current: page)
  end

  defp page_of(%{count: count, page: page, page_size: size}) do
    total = max(ceil(count / size), 1)
    dgettext("cinder", "Page %{current} of %{total}", current: page, total: total)
  end

  defp direction(sort, field) do
    case List.keyfind(sort, field, 0) do
      {^field, direction} when direction in [:asc, :asc_nils_first, :asc_nils_last] -> :asc
      {^field, _descending} -> :desc
      nil -> nil
    end
  end

  defp aria_sort(:asc), do: "ascending"
  defp aria_sort(:desc), do: "descending"
  defp aria_sort(nil), do: "none"

  defp indicator(:asc), do: " ▲"
  defp indicator(:desc), do: " ▼"
  defp indicator(nil), do: nil
end
