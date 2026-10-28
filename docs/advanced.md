<!--
SPDX-FileCopyrightText: 2026 Cinder contributors <https://github.com/sevenseacat/cinder/graphs/contributors>

SPDX-License-Identifier: MIT
-->

# Advanced Features

This guide covers everything beyond a first collection. For that, see
[Getting Started](getting-started.md).

## Table of Contents

- [Layout Options](#layout-options)
- [URL State Management](#url-state-management)
- [Relationship Fields](#relationship-fields)
- [Embedded Resources](#embedded-resources)
- [Pagination](#pagination)
- [Loading, Empty & Error States](#loading-empty-error-states)
- [Initial Data Loading](#initial-data-loading)
- [Refreshing and Updating](#refreshing-and-updating)
- [Loading Less Data](#loading-less-data)
- [Query Access](#query-access)
- [Selection & Bulk Actions](#selection-bulk-actions)
- [Telemetry & Tracing](#telemetry-tracing)

**See also:** [Filters](filters.md) | [Sorting](sorting.md)

## Layout Options

### Grid Columns

Set a grid's number of columns with `grid_columns`, as a number or by breakpoint (`xs`, `sm`,
`md`, `lg`, `xl`, `2xl`):

```heex
<Cinder.collection resource={MyApp.Product} layout={:grid} grid_columns={4}>
  ...
</Cinder.collection>

<Cinder.collection resource={MyApp.Product} layout={:grid} grid_columns={[xs: 1, sm: 2, md: 3, lg: 4]}>
  ...
</Cinder.collection>
```

Or replace the classes on the grid (or list) container entirely with `container_class`:

```heex
<Cinder.collection resource={MyApp.Product} layout={:grid} container_class="grid grid-cols-2 lg:grid-cols-4 gap-8">
  ...
</Cinder.collection>
```

### Sort Buttons

Lists and grids have no column headings to click, so they sort with a row of buttons above the
items. Change its label with `sort_label`, or hide it with `show_sort={false}`:

```heex
<Cinder.collection resource={MyApp.User} layout={:list} sort_label="Order by:">
  ...
</Cinder.collection>
```

### Clickable Rows and Items

`click` takes a function from the record to a `Phoenix.LiveView.JS` command, run when its row or
item is clicked. Clickable rows and items get a pointer cursor:

```heex
<Cinder.collection resource={MyApp.User} click={fn user -> JS.navigate(~p"/users/#{user.id}") end}>
  <:col :let={user} field="name" filter sort>{user.name}</:col>
</Cinder.collection>
```

Commands can be chained:

```heex
click={fn user ->
  JS.push("select_user", value: %{id: user.id})
  |> JS.add_class("selected", to: "#user-#{user.id}")
end}
```

### Row and Item Classes

`item_class` adds classes to each row or item, as a string or a function of the record:

```heex
<Cinder.collection resource={MyApp.User} item_class={fn user -> if user.archived, do: "opacity-50" end}>
  ...
</Cinder.collection>
```

## URL State Management

URL sync keeps a collection's filters, sorting, search and page in the URL, so they can be
bookmarked, shared, and moved through with the browser's back button.

### Setup

Add `use Cinder.UrlSync` to the LiveView, after `use MyAppWeb, :live_view`, and pass the
collection `url_state={@url_state}`:

```elixir
defmodule MyAppWeb.UsersLive do
  use MyAppWeb, :live_view
  use Cinder.UrlSync

  def render(assigns) do
    ~H"""
    <Cinder.collection id="users" resource={MyApp.User} actor={@current_user} url_state={@url_state}>
      <:col :let={user} field="name" filter sort>{user.name}</:col>
      <:col :let={user} field="email" filter>{user.email}</:col>
      <:col :let={user} field="is_active" filter>{user.is_active}</:col>
    </Cinder.collection>
    """
  end
end
```

Your LiveView can still have its own `handle_params/3`: `@url_state` is assigned before it runs.
Only one collection on a page can sync to the URL.

### The URL Format

Each filter is a parameter named after its field. Values with two parts (ranges) or several
(multi-select) are separated by commas, and either end of a range can be left empty:

```
/users?name=john                          a text filter
/users?is_active=true                     a boolean filter
/users?tags=admin,editor                  a multi-select filter
/users?inserted_at=2024-01-01,2024-12-31  a date range
/users?age=18,                            a number range with only a minimum
/users?department.name=Sales              a relationship field
/users?profile__country=NZ                an embedded field
/users?search=smith                       the search box
/users?sort=-inserted_at,name             sorted by inserted_at descending, then name
/users?page=3&page_size=50                the page, and a page size other than the default
/users?after=g3QAAAABZAAC...              keyset pagination's position
```

Parameters that don't apply to the collection, like a filter on a field that isn't filterable or
a sort on a field that isn't sortable, are ignored.

## Relationship Fields

A column's `field` can reach through relationships with dots, to show, filter and sort by a
related record's field:

```heex
<Cinder.collection resource={MyApp.User} actor={@current_user}>
  <:col :let={user} field="name" filter sort>{user.name}</:col>
  <:col :let={user} field="department.name" filter sort>{user.department.name}</:col>
  <:col :let={user} field="office.building.address" filter>{user.office.building.address}</:col>
</Cinder.collection>
```

Cinder loads what each column's `field` needs to show it: the relationships in its path, and any
calculation or aggregate it names. Load anything else your slots show with
`query_opts={[load: ...]}` ([Loading Less Data](#loading-less-data)). A `<:filter>` slot's field
isn't loaded, since nothing shows it.

A filter on a relationship field picks its type from the related field. To give it options,
configure it as on any other column: `filter={[type: :select, options: @department_names]}`.

## Embedded Resources

Reach into an embedded resource (or a map attribute) with a double underscore:

```heex
<Cinder.collection resource={MyApp.User} actor={@current_user}>
  <:col :let={user} field="profile__country" filter sort>{user.profile.country}</:col>
  <:col :let={user} field="settings__address__city" filter>{user.settings.address.city}</:col>
</Cinder.collection>
```

Embedded fields filter and sort like any other: an embedded enum gets a select filter with its
values. To sort by one by default, see [Sorting](sorting.md#default-sort).

## Pagination

Collections show 25 records a page. Change it with `page_size`, or let users choose from a list:

```heex
<Cinder.collection resource={MyApp.User} page_size={50}>
  ...
</Cinder.collection>

<Cinder.collection resource={MyApp.User} page_size={[default: 25, options: [10, 25, 50, 100]]}>
  ...
</Cinder.collection>
```

Set the default for every collection, in either form, in your config:

```elixir
config :cinder, default_page_size: [default: 25, options: [10, 25, 50, 100]]
```

### Counting Records

Each page read also counts the matching records, for the "Page 2 of 10" and "showing 11-20 of
100" footer. On large tables that count can cost more than the page itself, so change it with
`pagination`'s `count` option:

- `count: true` (the default): counted with each page.
- `count: :async`: counted in the background after the page loads. The last total stays on screen
  until the new one arrives.
- `count: false`: never counted. Users can only move to the previous and next pages.

```heex
<Cinder.collection resource={MyApp.Event} pagination={[count: :async]}>
  ...
</Cinder.collection>
```

### Keyset Pagination

By default, pages are numbered, and users can jump to any page. That gets slower the further in
the page is, since the data layer reads past every record before it. Keyset pagination only
moves to the previous and next pages, but each is as fast as the first:

```heex
<Cinder.collection resource={MyApp.Event} pagination={:keyset}>
  ...
</Cinder.collection>

<Cinder.collection resource={MyApp.Event} pagination={[mode: :keyset, count: false]}>
  ...
</Cinder.collection>
```

### Paginating the Action

Give the read action pagination, so pages are read from the data layer. Without it, the whole
collection is loaded at once, with no pages (and a warning if you've set a `page_size`). With the
default `count: true`, it must be `countable`:

```elixir
actions do
  read :read do
    pagination offset?: true, keyset?: true, countable: true, default_limit: 25
  end
end
```

## Loading, Empty & Error States

Change the text shown while loading, when nothing matches, and when the read fails:

```heex
<Cinder.collection
  resource={MyApp.User}
  loading_message="Fetching users..."
  empty_message="No users yet"
  error_message="Users couldn't be loaded"
>
  <:col :let={user} field="name">{user.name}</:col>
</Cinder.collection>
```

Or replace them with your own content, using the `<:loading>`, `<:empty>` and `<:error>` slots,
which take precedence over the messages:

```heex
<Cinder.collection id="users" resource={MyApp.User} actor={@current_user}>
  <:col :let={user} field="name" filter sort search>{user.name}</:col>

  <:loading>
    <div class="flex justify-center p-8">Fetching users...</div>
  </:loading>

  <:empty :let={context}>
    <p :if={context.filtered?}>No users match your filters.</p>
    <p :if={!context.filtered?}>No users yet. <.link navigate={~p"/users/new"}>Add one</.link></p>
  </:empty>

  <:error>
    <p>Users couldn't be loaded.</p>
    <button type="button" phx-click="retry">Try again</button>
  </:error>
</Cinder.collection>
```

```elixir
def handle_event("retry", _params, socket) do
  {:noreply, Cinder.refresh_table(socket, "users")}
end
```

The `<:empty>` slot receives:

- `filtered?`: whether a filter or search is in use, to tell "nothing matches" from "nothing yet"
- `filters`: the filters in use, by field
- `search_term`: the search box's text

While loading, the current rows stay on screen under the loading state. An error replaces them.

## Initial Data Loading

A collection reads its data after the page renders, so the first HTML has the table but not its
rows. With `initial_load={:sync}`, it reads its first page before rendering instead, so the rows
are in the server-rendered HTML, for pages that need to be crawlable or readable without
JavaScript:

```heex
<Cinder.collection resource={MyApp.Article} initial_load={:sync}>
  <:col :let={article} field="title">{article.title}</:col>
</Cinder.collection>
```

Only the first load changes: filtering, sorting, paging and refreshing stay asynchronous. Any
state in the URL applies to the first render.

The cost is waiting for the query twice, once before the page is sent and again before it
connects, so a slow query delays the page appearing and then becoming interactive. You can change
the default for every collection, but it's usually better to use it only where it's needed:

```elixir
config :cinder, default_initial_load: :sync
```

## Refreshing and Updating

### Refreshing

After changing records, re-read a collection with `refresh_table/2`. It keeps the current
filters, sorting and page:

```elixir
def handle_event("delete_user", %{"id" => id}, socket) do
  MyApp.User
  |> Ash.get!(id, actor: socket.assigns.current_user)
  |> Ash.destroy!(actor: socket.assigns.current_user)

  {:noreply, Cinder.refresh_table(socket, "users")}
end
```

Refresh several at once with `refresh_tables(socket, ["users", "audit-log"])`.

Normally a refresh shows the loading state. With `silent: true`, the current rows stay as they
are until the new ones arrive, with no loading indicator, and if the refresh fails, the current
rows stay and the error is only logged. That suits refreshing whenever a PubSub notification
arrives:

```elixir
def handle_info(%Ash.Notifier.Notification{}, socket) do
  {:noreply, Cinder.refresh_table(socket, "users", silent: true)}
end
```

### Updating Rows in Place

When you already have the changed data, like from a PubSub message, change the rows on screen
without re-reading the collection:

```elixir
def mount(_params, _session, socket) do
  if connected?(socket), do: Phoenix.PubSub.subscribe(MyApp.PubSub, "users")
  {:ok, socket}
end

def handle_info({:user_status_changed, user_id, new_status}, socket) do
  {:noreply, Cinder.update_item(socket, "users", user_id, &%{&1 | status: new_status})}
end

def handle_info({:users_deactivated, user_ids}, socket) do
  {:noreply, Cinder.update_items(socket, "users", user_ids, &%{&1 | active: false})}
end
```

When the message carries bare records, missing the relationships or calculations the collection
shows, use `update_if_visible/4` or `update_items_if_visible/4`. Your function is only called for
records on the current page, so you only load what's shown:

```elixir
def handle_info({:user_updated, user}, socket) do
  {:noreply,
   Cinder.update_if_visible(socket, "users", user, fn user ->
     Ash.load!(user, [:department, :manager])
   end)}
end
```

The new record replaces the one on screen, so it needs everything the columns show loaded, as
the collection would have.

### Removing Rows

`remove_item/3` and `remove_items/3` take rows off the page, like after a delete. They also leave
the selection, and the total count goes down by the number removed:

```elixir
def handle_info({:users_deleted, user_ids}, socket) do
  {:noreply, Cinder.remove_items(socket, "users", user_ids)}
end
```

Rows from the next page don't move up to fill the gap. If the page ends up empty, the collection
reads it again (or the page before, if it was the last).

### What Updates Don't Do

Updating and removing rows only changes what's on screen. To get any of these, use
`refresh_table/2` instead:

- Calculations and aggregates aren't recalculated.
- Rows aren't re-sorted, so a row whose sorted field changes stays where it is.
- Filters and search aren't re-applied, so a row that no longer matches stays.
- Rows can't be added: new records only appear on a refresh.

Updates for records that aren't on the current page are ignored.

## Loading Less Data

Columns load what their fields need. To load anything else your slots show, or to read only some
attributes, use `query_opts`:

```heex
<Cinder.collection
  resource={MyApp.User}
  query_opts={[load: [:avatar_url], select: [:id, :name, :email, :inserted_at]]}
>
  ...
</Cinder.collection>
```

`select` must list every attribute your columns and slots show, and the primary key: attributes
left out are `nil`.

Give slow queries more time with `query_opts={[timeout: 30_000]}`.

## Query Access

`on_query_change` sends your LiveView the collection's query after each load, with its filters,
search and sorting but no pagination, for exporting the same records, say:

```heex
<Cinder.collection id="users" resource={MyApp.User} actor={@current_user} on_query_change={:users_query}>
  <:col :let={user} field="name" filter sort search>{user.name}</:col>
</Cinder.collection>
```

```elixir
def handle_info({:users_query, %{query: query, count: count, id: "users"}}, socket) do
  {:noreply, assign(socket, users_query: query, users_count: count)}
end

def handle_event("export", _params, socket) do
  users = Ash.read!(socket.assigns.users_query, actor: socket.assigns.current_user)
  # ...turn them into a CSV and send it to the user
  {:noreply, socket}
end
```

Read it with the same `actor`, `tenant` or `scope` you gave the collection. `count` is the total
that the footer shows, so showing it elsewhere costs no extra query:

```heex
<h1>Users <span :if={@users_count}>({@users_count})</span></h1>
```

It's `nil` when nothing is counted. With `count: :async`, the message is sent twice: once when the
page loads, with a `nil` count, and again when the count arrives.

## Selection & Bulk Actions

### Selecting Records

`selectable` adds a checkbox to each row or item, and a "select all" for the page:

```heex
<Cinder.collection resource={MyApp.User} actor={@current_user} selectable>
  <:col :let={user} field="name" filter sort>{user.name}</:col>
</Cinder.collection>
```

Without a `click` handler, clicking a row or item also selects it.

To make only some records selectable, pass a function instead of `true`. The others get a
disabled checkbox, and "select all" skips them. This is checked on the server too:

```heex
<Cinder.collection resource={MyApp.User} selectable={&(&1.status == :active)}>
  ...
</Cinder.collection>
```

Cinder keeps track of the selection itself. To know about it as well, use
`on_selection_change`:

```heex
<Cinder.collection resource={MyApp.User} selectable on_selection_change={:selection_changed}>
  ...
</Cinder.collection>
```

```elixir
def handle_info({:selection_changed, %{selected_ids: ids, selected_count: count}}, socket) do
  {:noreply, assign(socket, :selected_count, count)}
end
```

The message also has the collection's `component_id`, and an `action`: `:select`, `:deselect`,
`:select_all`, `:clear` or `:remove`.

### Bulk Actions

A `<:bulk_action>` slot is a button that runs an action on the selected records. With `label` and
`variant` (`:primary`, `:secondary` or `:danger`), it's styled by the theme:

```heex
<Cinder.collection resource={MyApp.User} actor={@current_user} selectable>
  <:col :let={user} field="name" filter sort>{user.name}</:col>

  <:bulk_action action={:archive} label="Archive ({count})" />
  <:bulk_action action={:destroy} label="Delete" variant={:danger} confirm="Delete {count} users?" />
</Cinder.collection>
```

`{count}` in the label or confirmation is the number selected. Buttons are disabled when nothing
is selected. `confirm` asks in the browser before running: it's a prompt for the user, not a
security check.

For your own button, put it in the slot instead of a `label`. The slot receives the
`selected_count` and `selected_ids`:

```heex
<:bulk_action :let={selection} action={:archive}>
  <button class="btn" disabled={selection.selected_count == 0}>Archive selected</button>
</:bulk_action>
```

### What Actions Run

An atom is an action on the resource, run with `Ash.bulk_update` or `Ash.bulk_destroy`, depending
on its type. Pass more options to it with `action_opts`:

```heex
<:bulk_action action={:archive} label="Archive" action_opts={[notify?: true]} />
```

A function is called with a query for the selected records, and options with the collection's
`actor`, `tenant` and `scope`, like a code interface function:

```heex
<:bulk_action action={&MyApp.Accounts.archive_users/2} label="Archive" />
```

Either way, the action only reaches selected records that are still in the collection's `query`,
with its filters, tenant and read action. Changing the collection's `query`, `actor`, `tenant` or
`scope` clears the selection. Whether the actor may run the action is up to your Ash policies:
Cinder adds no authorization of its own.

### After an Action

When an action succeeds, the selection is cleared and the collection re-read. To act on the
result, name messages to send your LiveView:

```heex
<:bulk_action action={:archive} label="Archive" on_success={:users_archived} on_error={:archive_failed} />
```

```elixir
def handle_info({:users_archived, %{count: count}}, socket) do
  {:noreply, put_flash(socket, :info, "Archived #{count} users")}
end

def handle_info({:archive_failed, %{reason: reason}}, socket) do
  {:noreply, put_flash(socket, :error, "Archiving failed: #{inspect(reason)}")}
end
```

`on_success` gets the `component_id`, `action`, `count` and Ash's `result`. `on_error` gets the
`component_id`, `action`, `reason`, and `partial`. If some records were changed and some failed,
`on_error` is sent with `partial: true` and the errors as `reason`, and the selection is cleared,
since the changed records are no longer what was selected. For atom actions, Cinder asks Ash for
the errors (`return_errors?: true`); pass `action_opts={[return_errors?: false]}` to skip that
for very large selections.

## Telemetry & Tracing

Each time a collection loads its data, Cinder emits a [`:telemetry`](https://hexdocs.pm/telemetry) span, so you can see which collection is slow, and with what filters:

- `[:cinder, :query, :start | :stop | :exception]` around reading a page of data
- `[:cinder, :count, :start | :stop | :exception]` around the separate count query of `pagination={[count: :async]}`

Measurements are the standard span ones: `system_time` and `monotonic_time` on start, and `duration` (in native time units) on stop.

Metadata:

- `id` - the collection's `id`
- `resource`, `action` - what was read
- `filters` - the applied filters, by field
- `search_term` - the search box's value
- `sort_by`, `page_size`, `current_page`, `pagination_mode` - on `:query` events only
- `result` - on stop, `:ok` or `:error` (a failed read is a stop, not an exception)

Ash's own `[:ash, ...]` events still fire for each read inside these spans, so you can attach to whichever you need. For example, to log slow loads:

```elixir
defmodule MyApp.SlowCollections do
  require Logger

  # Call from your application's start/2
  def attach do
    :telemetry.attach("slow-collections", [:cinder, :query, :stop], &__MODULE__.handle_event/4, nil)
  end

  def handle_event(_event, %{duration: duration}, metadata, _config) do
    ms = System.convert_time_unit(duration, :native, :millisecond)

    if ms > 500 do
      Logger.warning("#{metadata.id} took #{ms}ms with filters #{inspect(metadata.filters)}")
    end
  end
end
```

### Sensitive fields

Filter values and search terms are things your users typed. As Ash does for errors, a filter on a field marked `sensitive?: true` (an attribute, calculation or aggregate, including through relationships) has its value replaced with `"**redacted**"`, and so does the search term when any searchable column is sensitive. Set `config :ash, :show_sensitive?, true` to see them, in development for example.

### Tracing

Cinder also opens an [`Ash.Tracer`](https://hexdocs.pm/ash/Ash.Tracer.html) span around each load, named `cinder:<id>:query` (or `:count`), using the same tracers as Ash: `config :ash, :tracer`, and any `tracer:` in `query_opts`. With a tracer like [`opentelemetry_ash`](https://hexdocs.pm/opentelemetry_ash), Ash's spans for the read appear nested inside Cinder's, so a trace shows which collection a query belongs to.
