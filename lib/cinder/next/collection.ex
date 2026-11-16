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
  alias Cinder.Next.{Config, RowSelection, State}
  alias Phoenix.LiveView.JS

  # In milliseconds, before a bulk action's confirm is taken as an answer
  @default_bulk_action_confirm_delay 500

  ## Building and rebuilding

  # Filter types render with a theme's classes, until theming is redone. A bulk
  # action is `:idle`, `{:confirming, bulk_action, asked_at}` (in milliseconds) or
  # `{:running, bulk_action, selected_count}`: one at a time.
  @impl true
  def mount(socket) do
    {:ok, assign(socket, theme: Cinder.Theme.merge("default"), bulk_action: :idle)}
  end

  # The fields' inner blocks are new on every parent render, so they're always
  # taken; only the fields that are columns have cells. The config is only rebuilt
  # when what's declared changes. Synced to the URL (`url_params` isn't `nil`), a
  # change to the URL's params is applied too.
  @impl true
  def update(assigns, socket) do
    declarations =
      Config.declarations(
        assigns.options,
        assigns.fields,
        assigns.arguments,
        assigns.bulk_actions
      )

    columns = Enum.reject(assigns.fields, &(&1[:column] == false))
    url_params = assigns.options[:url_state][:params]
    url_changed? = url_params != nil and url_params != socket.assigns[:url_params]
    declarations_changed? = declarations != socket.assigns[:declarations]
    socket = assign(socket, id: assigns.id, columns: columns, url_params: url_params)

    cond do
      declarations_changed? ->
        {:ok, rebuild(socket, assigns, declarations, if(url_changed?, do: url_params))}

      url_changed? ->
        {:ok, follow_url(socket, url_params)}

      true ->
        {:ok, socket}
    end
  end

  # On mount, or when the declarations change: the new config, then each piece of
  # state carried over to it, then the records read again only if what's read
  # changed. Anything kept from the old config must be checked against the new one
  # here. `new_url_params` are the URL's, when they changed too.
  defp rebuild(socket, assigns, declarations, new_url_params) do
    old = socket.assigns

    config =
      Config.build(assigns.options, assigns.fields, assigns.arguments, assigns.bulk_actions)

    query = query(old, config, new_url_params)

    socket =
      socket
      |> assign(
        declarations: declarations,
        config: config,
        bulk_action: bulk_action(old.bulk_action, config)
      )
      |> change_selection(selection(old, config))

    cond do
      !read_again?(old, config, query) -> after_read(socket)
      # A rebuild that moves the query (back to the first page, say) moves the URL too
      new_url_params == nil and query != old[:query] -> move(socket, query)
      true -> change_query(socket, query)
    end
  end

  # Only the URL changed (back, forward, or a link). A change to the app's own
  # params changes nothing here.
  defp follow_url(socket, url_params) do
    %{config: config, query: old} = socket.assigns
    query = from_url(url_params, config)
    if query == old, do: socket, else: change_query(socket, query)
  end

  # A rebuild after mount (see `State.carry_over/4`)
  defp query(%{config: old, query: query}, config, nil) do
    State.carry_over(query, old, config, same_records?(old, config))
  end

  # On mount, or when the URL changes with the declarations: what the URL says
  defp query(_assigns, config, url_params) when url_params != nil do
    from_url(url_params, config)
  end

  # The first build, on mount, before there's a config or query: a new collection
  # starts on page 1 with the default sort
  defp query(_assigns, config, nil), do: start(config)

  # A rebuild after mount (see `RowSelection.carry_over/4`). A new collection has
  # nothing selected.
  defp selection(%{config: old, selection: selection}, config) do
    same_records? = same_records?(old, config)
    RowSelection.carry_over(selection, config.selectable, config.primary_key, same_records?)
  end

  defp selection(_assigns, config), do: RowSelection.new(config.selectable, config.primary_key)

  # A waiting confirm asks about its action as now declared, and goes if the action
  # has. A running action is left to finish.
  defp bulk_action({:confirming, %{name: name}, asked_at}, config) do
    case Enum.find(config.bulk_actions, &(&1.name == name)) do
      nil -> :idle
      bulk_action -> {:confirming, bulk_action, asked_at}
    end
  end

  defp bulk_action(state, _config), do: state

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

  # A function declared inline (a bulk action's, or `selectable`) closes over the
  # parent's assigns, so it's new whenever they change. The new one is kept, but
  # unless it changes what the read is given, the records are the same.
  defp read_again?(%{config: old_config, query: old_query}, config, query) do
    read_inputs(old_config, old_query) != read_inputs(config, query)
  end

  defp read_again?(_new_collection, _config, _query), do: true

  # Whether two configs read the same records, given the same query
  defp same_records?(old, config) do
    keys = [:source, :action, :actor, :tenant, :scope, :query_opts]

    Map.take(old, keys) == Map.take(config, keys) and old.search[:fn] == config.search[:fn] and
      old.pagination[:mode] == config.pagination[:mode]
  end

  ## Events

  @impl true
  def handle_event("sort", %{"field" => field}, socket) do
    %{config: config, query: query} = socket.assigns

    # A field that isn't a sortable column (from a tampered event) is ignored
    case Enum.find(config.columns, &(&1.field == field and &1.sort != nil)) do
      nil ->
        {:noreply, socket}

      column ->
        sort = State.toggle_sort(query.sort, field, column.sort.cycle, config.sort.mode)
        {:noreply, request(socket, State.first_page(%{query | sort: sort}))}
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
    {:noreply, request(socket, query)}
  end

  # An offset page comes from the client, so one that isn't a positive number is
  # ignored. Each mode's events are ignored in the other (from tampering).
  def handle_event("page", %{"page" => page}, socket) do
    with %{mode: :offset} <- socket.assigns.config.pagination,
         {page, ""} when page > 0 <- Integer.parse(page) do
      {:noreply, request(socket, %{socket.assigns.query | page: page})}
    else
      _not_a_page -> {:noreply, socket}
    end
  end

  # Keyset pages go from the cursors of the page shown, kept on the server
  def handle_event(direction, _params, socket) when direction in ["next_page", "previous_page"] do
    %{config: config, page: page, query: query} = socket.assigns

    with %{mode: :keyset} <- config.pagination,
         {_direction, _cursor} = cursor <- cursor(page, direction) do
      {:noreply, request(socket, %{query | cursor: cursor})}
    else
      _no_page_that_way -> {:noreply, socket}
    end
  end

  # A forged id, or all matching when it isn't offered, changes nothing (see
  # `RowSelection`)
  def handle_event("select", %{"id" => id}, socket) do
    {:noreply, change_selection(socket, RowSelection.toggle(socket.assigns.selection, id))}
  end

  def handle_event("select_page", _params, socket) do
    {:noreply, change_selection(socket, RowSelection.toggle_page(socket.assigns.selection))}
  end

  def handle_event("select_all_matching", _params, socket) do
    selection = RowSelection.select_all_matching(socket.assigns.selection)
    {:noreply, change_selection(socket, selection)}
  end

  def handle_event("clear_selection", _params, socket) do
    {:noreply, change_selection(socket, RowSelection.clear(socket.assigns.selection))}
  end

  # An action that isn't declared, with nothing selected, or while one is running
  # or waiting to be confirmed (from tampering: the buttons are disabled) is
  # ignored. One with a confirm asks first.
  def handle_event("bulk_action", %{"name" => name}, socket) do
    %{bulk_action: state, config: config, selection: selection} = socket.assigns
    bulk_action = Enum.find(config.bulk_actions, &(&1.name == name))

    cond do
      !bulk_action or state != :idle or RowSelection.count(selection) == 0 ->
        {:noreply, socket}

      bulk_action.confirm ->
        {:noreply, assign(socket, :bulk_action, {:confirming, bulk_action, now()})}

      true ->
        {:noreply, run_bulk_action(socket, bulk_action)}
    end
  end

  # Too soon after asking is a slow double click on the action, not an answer, so
  # it's ignored and the question stays. With nothing waiting, or naming another
  # action than the one waiting, it's tampering.
  def handle_event("confirm_bulk_action", %{"name" => name}, socket) do
    with {:confirming, %{name: ^name} = bulk_action, asked_at} <- socket.assigns.bulk_action,
         true <- now() - asked_at >= confirm_delay(),
         true <- RowSelection.count(socket.assigns.selection) > 0 do
      {:noreply, run_bulk_action(socket, bulk_action)}
    else
      _not_an_answer -> {:noreply, socket}
    end
  end

  # Only a confirm can be cancelled: a running action isn't stopped
  def handle_event("cancel_bulk_action", _params, socket) do
    case socket.assigns.bulk_action do
      {:confirming, _bulk_action, _asked_at} -> {:noreply, assign(socket, :bulk_action, :idle)}
      _not_confirming -> {:noreply, socket}
    end
  end

  defp cursor(%{more?: true, last_cursor: cursor}, "next_page"), do: {:after, cursor}
  defp cursor(%{previous?: true, first_cursor: cursor}, "previous_page"), do: {:before, cursor}
  defp cursor(_page, _direction), do: nil

  ## Bulk actions

  defp confirm_delay do
    Application.get_env(:cinder, :bulk_action_confirm_delay, @default_bulk_action_confirm_delay)
  end

  # On the records selected, as they're read (see `Engine.run_bulk_action/6`)
  defp run_bulk_action(socket, bulk_action) do
    %{config: config, query: query, selection: selection} = socket.assigns
    {source, fields, query, opts} = read_inputs(config, query)
    opts = [action_opts: bulk_action.action_opts] ++ opts
    running = {:running, bulk_action, RowSelection.count(selection)}
    selection = RowSelection.to_engine(selection)

    socket
    |> assign(:bulk_action, running)
    |> start_async(:bulk_action, fn ->
      Engine.run_bulk_action(source, fields, query, bulk_action.action, selection, opts)
    end)
  end

  # After a success or a partial success, the selected records have changed, so
  # they're no longer what was selected. After an error nothing changed, so the
  # user can try again.
  @impl true
  def handle_async(:bulk_action, result, socket) do
    {status, value, errors} = bulk_result(result)
    %{config: config, bulk_action: {:running, bulk_action, count}, query: query} = socket.assigns

    if config.on_bulk_action_result do
      payload = %{
        bulk_action: bulk_action.name,
        status: status,
        selected_count: count,
        result: value,
        errors: errors,
        component_id: socket.assigns.id
      }

      send(self(), {config.on_bulk_action_result, payload})
    end

    socket = assign(socket, :bulk_action, :idle)

    if status == :error do
      {:noreply, socket}
    else
      selection = RowSelection.clear(socket.assigns.selection)
      socket = socket |> change_selection(selection) |> change_query(query)
      {:noreply, leave_emptied_page(socket)}
    end
  end

  # An action that empties the page shown (deleting its records, or changing them so
  # the read no longer reaches them) moves to the last page with records. Without a
  # count to say which that is (an uncounted read, or keyset pages, whose cursors
  # can't say), it's the first.
  defp leave_emptied_page(socket) do
    %{config: config, page: page, query: query} = socket.assigns

    if page.records == [] and (query.page > 1 or query.cursor != nil) do
      moved =
        if config.pagination[:mode] == :keyset do
          State.first_page(query)
        else
          %{query | page: last_page(page)}
        end

      move(socket, moved)
    else
      socket
    end
  end

  defp last_page(%Engine.Page{count: count, page_size: size}) when is_integer(count) do
    max(div(count + size - 1, size), 1)
  end

  defp last_page(_uncounted), do: 1

  defp now, do: System.monotonic_time(:millisecond)

  defp bulk_result({:ok, {:ok, value}}), do: {:success, value, []}
  defp bulk_result({:ok, {:partial_success, bulk}}), do: {:partial_success, bulk, bulk.errors}
  defp bulk_result({:ok, {:error, reason}}), do: {:error, nil, List.wrap(reason)}
  defp bulk_result({:exit, reason}), do: {:error, nil, [reason]}

  ## How what the user does reaches the page

  # Every change to the selection, and the reactions to it. The parent hears of each
  # change, if it asked to. A new collection has selected nothing, so mounting one
  # isn't a change.
  defp change_selection(socket, selection) do
    %{config: config, id: id} = socket.assigns
    old = socket.assigns[:selection] || selection

    if config.on_selection_change && RowSelection.changed?(old, selection) do
      payload = Map.put(RowSelection.payload(selection), :component_id, id)
      send(self(), {config.on_selection_change, payload})
    end

    # With nothing selected, a waiting confirm has nothing left to act on
    bulk_action =
      case {socket.assigns.bulk_action, RowSelection.count(selection)} do
        {{:confirming, _bulk_action, _asked_at}, 0} -> :idle
        {state, _count} -> state
      end

    assign(socket, selection: selection, bulk_action: bulk_action)
  end

  # A query the user asks for. Synced, it changes the URL, and the query changes when
  # the URL comes back, so the new records and the new URL arrive in one render.
  defp request(%{assigns: %{url_params: nil}} = socket, query), do: change_query(socket, query)

  defp request(socket, query) do
    patch_url(socket, query)
    socket
  end

  # A move the collection makes itself (a rebuild, or leaving an emptied page),
  # shown in this render. Synced, the URL follows: `patch_url/2` only asks the parent
  # to patch, changing nothing here. Unlike `request/2`, which waits for the URL,
  # this doesn't show the old records while it comes back, and the query that comes
  # back is the one shown, so it isn't read again.
  defp move(socket, query) do
    if socket.assigns.url_params, do: patch_url(socket, query)
    change_query(socket, query)
  end

  defp patch_url(%{assigns: %{config: config}}, query) do
    opts = [arguments: config.arguments]
    params = Params.to_url(query, config.fields, start(config), opts)
    UrlSync.patch(params, owns: Params.url_keys(config.fields, opts))
  end

  # Every new query (or the same one read again), and the reactions to it, then the
  # read
  defp change_query(socket, query) do
    old = socket.assigns[:query]

    # A new query can make the selection stale (see `RowSelection.for_query/3`); a
    # new collection has no query before it
    socket =
      if old do
        change_selection(socket, RowSelection.for_query(socket.assigns.selection, old, query))
      else
        socket
      end

    socket |> assign(:query, query) |> read() |> after_read()
  end

  # Every page read (or the same page, when a rebuild changes what can be done with
  # it), and the reactions to it: the selection takes which of its records can be
  # selected, and how many match
  defp after_read(%{assigns: %{page: page, selection: selection}} = socket) do
    assign(socket, :selection, RowSelection.for_page(selection, page))
  end

  ## Reading

  # Synchronous, and a failed read crashes, until the slices for loading states and
  # errors. The controls' values are worked out here, with the records, rather than
  # in `render/1`, where they'd be new on every render.
  defp read(socket) do
    %{config: config, query: query} = socket.assigns

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
      run(socket)
    end
  end

  # What a read is given: the same inputs read the same records
  defp read_inputs(config, query) do
    opts = Map.take(config, [:action, :actor, :tenant, :scope, :query_opts]) |> Enum.to_list()

    opts =
      [
        arguments: config.arguments,
        search_fn: config.search[:fn],
        pagination: config.pagination[:mode] || :offset,
        count?: config.pagination[:count?] == true
      ] ++ opts

    {config.source, config.fields, query, opts}
  end

  defp run(socket) do
    %{config: config, query: query} = socket.assigns
    {source, fields, query, opts} = read_inputs(config, query)

    case {Engine.run(source, fields, query, opts), query.cursor} do
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
        change_query(socket, State.first_page(query))
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

  ## Markup

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
        count={RowSelection.count(@selection)}
        everything?={RowSelection.everything?(@selection)}
        matching={RowSelection.all_matching_offer(@selection)}
        bulk_action={@bulk_action}
        confirm_component={@config.bulk_action_confirm || (&bulk_action_confirm/1)}
        target={@myself}
      />
      <table>
        <thead>
          <tr>
            <th :if={@config.selectable != false}>
              <input
                type="checkbox"
                aria-label={dgettext("cinder", "Select all on this page")}
                checked={RowSelection.page_selected?(@selection)}
                disabled={MapSet.size(@selection.page_ids) == 0}
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
                id={RowSelection.id(@selection, record)}
                collection_id={@id}
                selection={@selection}
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
        <p :if={!@everything?}>{dgettext("cinder", "%{count} selected", count: @count)}</p>
        <p :if={@everything?}>
          {dngettext("cinder", "All %{count} selected", "All %{count} selected", @count)}
        </p>
        <button
          :if={@matching}
          type="button"
          phx-click="select_all_matching"
          phx-target={@target}
        >
          {dngettext(
            "cinder",
            "Select all %{count} matching",
            "Select all %{count} matching",
            @matching
          )}
        </button>
        <button type="button" phx-click="clear_selection" phx-target={@target}>
          {dgettext("cinder", "Clear selection")}
        </button>
      </div>
      {confirm_prompt(assigns)}
      <button
        :for={bulk_action <- @bulk_actions}
        type="button"
        phx-click="bulk_action"
        phx-value-name={bulk_action.name}
        phx-target={@target}
        disabled={@count == 0 or @bulk_action != :idle}
      >
        {bulk_action.label}
      </button>
    </section>
    """
  end

  # The confirm component (the developer's, or Cinder's own) is given these assigns.
  # `component/3` is what `<.name>` compiles to, for a component held in a variable.
  defp confirm_prompt(%{bulk_action: {:confirming, bulk_action, _asked_at}} = assigns) do
    %{count: count, target: target} = assigns

    Phoenix.LiveView.TagEngine.component(
      assigns.confirm_component,
      [
        id: "#{assigns.id}-confirm",
        name: bulk_action.name,
        label: bulk_action.label,
        message: String.replace(bulk_action.confirm, "{count}", to_string(count)),
        count: count,
        confirm: JS.push("confirm_bulk_action", value: %{name: bulk_action.name}, target: target),
        cancel: JS.push("cancel_bulk_action", target: target)
      ],
      {__MODULE__, __ENV__.function, __ENV__.file, __ENV__.line}
    )
  end

  defp confirm_prompt(_not_confirming), do: nil

  # Rendered `open`, so it shows in place even in an app without Cinder's hooks; the
  # hook reopens it as a modal (on top, the page inert), and Esc runs `cancel`. Cancel
  # comes first and has focus, so Enter or Space cancels.
  defp bulk_action_confirm(assigns) do
    ~H"""
    <dialog id={@id} open phx-hook=".BulkActionConfirm" data-cancel={@cancel}>
      <script :type={Phoenix.LiveView.ColocatedHook} name=".BulkActionConfirm">
        export default {
          mounted() {
            this.el.addEventListener("cancel", (event) => {
              event.preventDefault()
              this.js().exec(this.el.dataset.cancel)
            })
            this.el.close()
            this.el.showModal()
          }
        }
      </script>
      <p>{@message}</p>
      <button type="button" phx-click={@cancel} autofocus>{dgettext("cinder", "Cancel")}</button>
      <button type="button" phx-click={@confirm}>{@label}</button>
    </dialog>
    """
  end

  defp row_box(assigns) do
    ~H"""
    <input
      type="checkbox"
      id={"#{@collection_id}-select-#{@id}"}
      aria-label={dgettext("cinder", "Select row")}
      checked={RowSelection.selected?(@selection, @id)}
      disabled={@id not in @selection.page_ids}
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
