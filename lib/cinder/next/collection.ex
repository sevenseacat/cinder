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
  alias Cinder.Next.{BulkActionState, Config, ReadState, RowSelection, State}
  alias Phoenix.LiveView.JS

  # In milliseconds, before a bulk action's confirm is taken as an answer
  @default_bulk_action_confirm_delay 500

  ## Building and rebuilding

  # Filter types render with a theme's classes, until theming is redone. The read's
  # state is `Cinder.Next.ReadState`'s, and the bulk actions' `BulkActionState`'s.
  # Until the first read, there are no records to show.
  @impl true
  def mount(socket) do
    {:ok,
     assign(socket,
       theme: Cinder.Theme.merge("default"),
       bulk_action: :idle,
       read: :unread,
       page: %Engine.Page{}
     )}
  end

  # The fields' inner blocks, and the other slots, are new on every parent render, so
  # they're always taken; only the fields that are columns have cells. The config is only rebuilt
  # when what's declared changes. Synced to the URL (`url_state`, the parent's
  # `@url_state`, isn't `nil`), a change to the URL's params is applied too.
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
    url_state = assigns.options[:url_state]
    url_params = url_state[:params]
    url_changed? = url_params != nil and url_params != socket.assigns[:url_state][:params]
    declarations_changed? = declarations != socket.assigns[:declarations]

    socket =
      assign(socket,
        id: assigns.id,
        columns: columns,
        empty_slot: assigns.empty_slot,
        loading_slot: assigns.loading_slot,
        error_slot: assigns.error_slot,
        url_state: url_state
      )

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
        bulk_action: BulkActionState.carry_over(old.bulk_action, config.bulk_actions)
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
    query = State.from_url(url_params, config)
    if query == old, do: socket, else: change_query(socket, query)
  end

  # A rebuild after mount (see `State.carry_over/4`)
  defp query(%{config: old, query: query}, config, nil) do
    State.carry_over(query, old, config, Config.same_records?(old, config))
  end

  # On mount, or when the URL changes with the declarations: what the URL says
  defp query(_assigns, config, url_params) when url_params != nil do
    State.from_url(url_params, config)
  end

  # The first build, on mount, before there's a config or query
  defp query(_assigns, config, nil), do: State.start(config)

  # A rebuild after mount (see `RowSelection.carry_over/4`). A new collection has
  # nothing selected.
  defp selection(%{config: old, selection: selection}, config) do
    same_records? = Config.same_records?(old, config)
    RowSelection.carry_over(selection, config.selectable, config.primary_key, same_records?)
  end

  defp selection(_assigns, config), do: RowSelection.new(config.selectable, config.primary_key)

  # A function declared inline (a bulk action's, or `selectable`) closes over the
  # parent's assigns, so it's new whenever they change. The new one is kept, but
  # unless it changes what the read is given, the records are the same.
  defp read_again?(%{config: old_config, query: old_query}, config, query) do
    read_inputs(old_config, old_query) != read_inputs(config, query)
  end

  defp read_again?(_new_collection, _config, _query), do: true

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

  # Which sizes can be chosen, and what one does to the page, are `State`'s
  def handle_event("page_size", %{"page_size" => size}, socket) do
    case State.change_page_size(socket.assigns.query, size, socket.assigns.config) do
      {:ok, query} -> {:noreply, request(socket, query)}
      :ignore -> {:noreply, socket}
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

  # When each is ignored, asks first, or runs is `BulkActionState`'s
  def handle_event("bulk_action", %{"name" => name}, socket) do
    %{bulk_action: state, config: config, selection: selection} = socket.assigns
    bulk_action = Enum.find(config.bulk_actions, &(&1.name == name))

    case BulkActionState.ask(state, bulk_action, RowSelection.count(selection), now()) do
      {:confirming, state} -> {:noreply, assign(socket, :bulk_action, state)}
      {:run, bulk_action} -> {:noreply, run_bulk_action(socket, bulk_action)}
      :ignore -> {:noreply, socket}
    end
  end

  def handle_event("confirm_bulk_action", %{"name" => name}, socket) do
    %{bulk_action: state, selection: selection} = socket.assigns
    count = RowSelection.count(selection)

    case BulkActionState.answer(state, name, count, now(), confirm_delay()) do
      {:run, bulk_action} -> {:noreply, run_bulk_action(socket, bulk_action)}
      :ignore -> {:noreply, socket}
    end
  end

  def handle_event("cancel_bulk_action", _params, socket) do
    {:noreply, assign(socket, :bulk_action, BulkActionState.cancel(socket.assigns.bulk_action))}
  end

  def handle_event("retry", _params, socket) do
    {:noreply, if(ReadState.failed?(socket.assigns.read), do: read(socket), else: socket)}
  end

  defp cursor(%{more?: true, last_cursor: cursor}, "next_page"), do: {:after, cursor}
  defp cursor(%{previous?: true, first_cursor: cursor}, "previous_page"), do: {:before, cursor}
  defp cursor(_page, _direction), do: nil

  # What's done in the background: a read, or a bulk action
  @impl true
  def handle_async(:read, {:ok, result}, socket), do: {:noreply, read_done(socket, result)}
  def handle_async(:read, exit, socket), do: {:noreply, read_done(socket, exit)}
  def handle_async(:bulk_action, result, socket), do: {:noreply, bulk_action_done(socket, result)}

  ## Bulk actions

  defp confirm_delay do
    Application.get_env(:cinder, :bulk_action_confirm_delay, @default_bulk_action_confirm_delay)
  end

  # On the records selected, as they're read (see `Engine.run_bulk_action/6`)
  defp run_bulk_action(socket, bulk_action) do
    %{config: config, query: query, selection: selection} = socket.assigns
    {source, fields, query, opts} = read_inputs(config, query)
    opts = [action_opts: bulk_action.action_opts] ++ opts
    running = BulkActionState.running(bulk_action, RowSelection.count(selection))
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
  defp bulk_action_done(socket, result) do
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
      socket
    else
      selection = RowSelection.clear(socket.assigns.selection)
      socket |> change_selection(selection) |> change_query(query)
    end
  end

  # Where to is `State`'s
  defp leave_emptied_page(socket) do
    %{config: config, page: page, query: query} = socket.assigns

    case State.leave_emptied_page(query, page, config) do
      {:move, query} -> move(socket, query)
      :stay -> socket
    end
  end

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

    bulk_action =
      BulkActionState.for_selection(socket.assigns.bulk_action, RowSelection.count(selection))

    assign(socket, selection: selection, bulk_action: bulk_action)
  end

  # A query the user asks for, from an event. Synced, it changes the URL, and the
  # query changes when the URL comes back, which it has before the next event (see
  # `UrlSync.patch/4`), so a quick second change starts from this one.
  defp request(%{assigns: %{url_state: nil}} = socket, query), do: change_query(socket, query)

  defp request(%{assigns: %{config: config, url_state: url_state}} = socket, query) do
    UrlSync.patch(socket, url_state.uri, State.to_url(query, config),
      owns: State.url_keys(config)
    )
  end

  # A move the collection makes itself (a rebuild, or leaving an emptied page), shown
  # at once. Synced, the URL follows, and the query that comes back is the one shown,
  # so it isn't read again. A move can be made while the collection is updated, so
  # the URL is patched after this event (`UrlSync.patch_later/2`). A click already
  # waiting comes first, and the move's URL then undoes it: rare, as moves don't come
  # from clicking.
  defp move(%{assigns: %{config: config}} = socket, query) do
    if socket.assigns.url_state do
      UrlSync.patch_later(State.to_url(query, config), owns: State.url_keys(config))
    end

    change_query(socket, query)
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

    socket |> assign(:query, query) |> read()
  end

  # Every page read (or the same page, when a rebuild changes what can be done with
  # it), and the reactions to it: the selection takes which of its records can be
  # selected, and how many match
  defp after_read(%{assigns: %{page: page, selection: selection}} = socket) do
    assign(socket, :selection, RowSelection.for_page(selection, page))
  end

  ## Reading

  # In the background, so the records shown stay until the new ones arrive, and a
  # later read supersedes one still running, unless it's read first (see
  # `ReadState.read_first?/3`). The controls' values are worked out here, rather than
  # in `render/1`, where they'd be new on every render.
  defp read(socket) do
    %{config: config, query: query, read: state} = socket.assigns

    socket =
      assign(socket,
        filter_values: Params.filter_values(query.filters, config.fields),
        argument_values: Params.filter_values(query.arguments, config.arguments),
        applied: State.applied(query, config)
      )

    {source, fields, query, opts} = read_inputs(config, query)
    run = fn -> Engine.run(source, fields, query, opts) end

    disable_async? = Application.get_env(:ash, :disable_async?) == true

    cond do
      # A read missing a required argument would fail; it's invalid, with nothing to
      # say yet
      Enum.any?(config.arguments, &(&1.required? and !Map.has_key?(query.arguments, &1.param))) ->
        read_done(socket, {:error, %Engine.Error{}})

      ReadState.read_first?(state, config.initial_load, disable_async?) ->
        read_done(socket, run.())

      true ->
        socket |> assign(:read, :loading) |> start_async(:read, run)
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

  # A read's result (see `ReadState.done/1`), and the reactions to it: the selection
  # takes which of its records can be selected and how many match, and a page past
  # the first that came back empty (its records deleted by a bulk action, a URL
  # asking for a page past the last, argument values that can't be read, or a cursor
  # that isn't one) moves to the last with records, or the first by keyset. A failed
  # page stays, to be tried again.
  defp read_done(socket, result) do
    {state, page} = ReadState.done(result, socket.assigns.config.translate_error)
    socket = socket |> assign(read: state, page: page) |> after_read()
    if ReadState.failed?(state), do: socket, else: leave_emptied_page(socket)
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
          <p :for={message <- ReadState.errors(@read)[column.field] || []}>{message}</p>
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
      <table aria-busy={ReadState.loading?(@read) && "true"}>
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
      <div :if={ReadState.loaded?(@read) and @page.records == []}>
        <%= if @empty_slot != [] do %>
          {render_slot(@empty_slot, @applied)}
        <% else %>
          {dgettext("cinder", "No results found")}
        <% end %>
      </div>
      <div :if={ReadState.failed?(@read)} role="alert">
        <%= if @error_slot != [] do %>
          {render_slot(@error_slot, %{retry: JS.push("retry", target: @myself)})}
        <% else %>
          <p>{dgettext("cinder", "An error occurred while loading data")}</p>
          <button type="button" phx-click="retry" phx-target={@myself}>
            {dgettext("cinder", "Try again")}
          </button>
        <% end %>
      </div>
      <%!-- Always there, so it's a live region before its content changes. Until
      theming puts it over the table, what's below moves as it fills and empties. --%>
      <div id={"#{@id}-loading"} role="status">
        <%= if ReadState.loading?(@read) do %>
          <%= if @loading_slot != [] do %>
            {render_slot(@loading_slot)}
          <% else %>
            {dgettext("cinder", "Loading...")}
          <% end %>
        <% end %>
      </div>
      <%!-- The page size can be chosen even on one page, so a user who chose more can go back to fewer --%>
      <nav
        :if={@config.pagination && (@page.previous? or @page.more? or size_choice?(@config))}
        aria-label="Pagination"
      >
        <div :if={@page.previous? or @page.more?}>
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
        </div>
        <.page_size
          :if={size_choice?(@config)}
          id={"#{@id}-page-size"}
          sizes={@config.pagination.size_options}
          size={@query.page_size}
          target={@myself}
        />
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

  defp size_choice?(%{pagination: %{size_options: [_, _ | _]}}), do: true
  defp size_choice?(_config), do: false

  # Split, so a translation can put the size where its language needs it
  defp page_size(assigns) do
    [before, after_sizes] =
      String.split(dgettext("cinder", "Show {selector} per page"), "{selector}")

    assigns = assign(assigns, before: before, after_sizes: after_sizes)

    ~H"""
    <form id={@id} phx-change="page_size" phx-target={@target}>
      <label>
        {@before}
        <select name="page_size">
          <option :for={size <- @sizes} value={size} selected={size == @size}>{size}</option>
        </select>
        {@after_sizes}
      </label>
    </form>
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
