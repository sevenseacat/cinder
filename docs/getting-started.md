<!--
SPDX-FileCopyrightText: 2026 Cinder contributors <https://github.com/sevenseacat/cinder/graphs/contributors>

SPDX-License-Identifier: MIT
-->

# Getting Started

This guide covers installing Cinder and building your first collections. Upgrading from an
older version? See the [Upgrading Guide](upgrading.md).

## Installation

### With Igniter

```bash
mix igniter.install cinder
```

This adds Cinder to your dependencies, sets up Tailwind with Cinder's CSS and the `daisy_ui`
theme, and registers Cinder's LiveView hook in `assets/js/app.js`. If it can't make a change
itself, it prints the steps to do by hand.

### By hand

1. Add Cinder to your dependencies in `mix.exs`, and run `mix deps.get`:

   ```elixir
   def deps do
     [{:cinder, "~> 0.18"}]
   end
   ```

2. Import Cinder's CSS, and the CSS of each built-in theme you use, in `assets/css/app.css`
   (Tailwind v4):

   ```css
   @import "tailwindcss";
   @import "../../deps/cinder/priv/cinder.css";
   @import "../../deps/cinder/priv/themes/daisy_ui.css";
   ```

   With Tailwind v3, add `"../deps/cinder/lib/**/*.*ex"` to the `content` list in
   `assets/tailwind.config.js` instead.

3. Register Cinder's hooks with your `LiveSocket` in `assets/js/app.js`:

   ```javascript
   import {hooks as cinderHooks} from "phoenix-colocated/cinder"

   const liveSocket = new LiveSocket("/live", Socket, {
     hooks: {...cinderHooks, ...colocatedHooks},
     // ...
   })
   ```

   The hook clears partly typed date and number filters. Apps generated with Phoenix 1.8
   already resolve `phoenix-colocated`; otherwise see the
   [0.18 upgrade notes](upgrading.md#upgrading-to-0-18-0).

4. Set the theme to use by default, in `config/config.exs`:

   ```elixir
   config :cinder, default_theme: "daisy_ui"
   ```

## Your First Collection

A collection reads an Ash resource and shows its records, in a table by default:

```heex
<Cinder.collection resource={MyApp.User} actor={@current_user}>
  <:col :let={user} field="name">{user.name}</:col>
  <:col :let={user} field="email">{user.email}</:col>
</Cinder.collection>
```

Add `filter` and `sort` to a column to filter and sort by it, and `search` to include it in the
search box:

```heex
<Cinder.collection resource={MyApp.User} actor={@current_user}>
  <:col :let={user} field="name" filter sort search>{user.name}</:col>
  <:col :let={user} field="email" filter search>{user.email}</:col>
  <:col :let={user} field="inserted_at" sort>{user.inserted_at}</:col>
</Cinder.collection>
```

Cinder picks each filter's type from the field's Ash type:

| Field type | Filter |
|---|---|
| String | Text |
| Boolean | True / false radio buttons |
| Date, datetime, time | Date range |
| Integer, decimal, float | Number range |
| Enum, or `one_of` constraint | Select, listing its values |
| Array | Multi-select (listing its values for an array of an enum) |
| Anything else | Text |

A column's `field` can reach through relationships (`department.name`) and into embedded
resources (`settings__country`), and Cinder loads whatever the column needs to show it,
including calculations and aggregates.

Each collection on a page needs its own `id`:

```heex
<Cinder.collection id="active-users" resource={MyApp.User} action={:active}>
  ...
</Cinder.collection>
```

## Layouts

Cinder has three layouts: **table** (the default), **list** and **grid**. They share filtering,
sorting, search and pagination.

In a table, each `<:col>` is a column, as above. In a list or grid, an `<:item>` slot shows
each record, and the `<:col>` slots only say which fields can be filtered, sorted and searched:

```heex
<Cinder.collection resource={MyApp.Product} actor={@current_user} layout={:grid}>
  <:col field="name" filter sort search />
  <:col field="category" filter />
  <:col field="price" sort />

  <:item :let={product}>
    <div class="p-4 border rounded-lg">
      <h3 class="font-bold">{product.name}</h3>
      <p>${product.price}</p>
    </div>
  </:item>
</Cinder.collection>
```

`layout={:list}` works the same way, with the items one under another. See
[Layout Options](advanced.md#layout-options) for grid columns, clickable rows and more.

## Columns

| Attribute | |
|---|---|
| `field` | The field to show, filter, sort or search by. |
| `label` | The column's heading. Defaults to one made from the field: `email_address` is "Email Address", `department.name` is "Department > Name". |
| `filter` | Filter by this column: `true`, a filter type like `:select`, or a list of options. See [Filters](filters.md). |
| `sort` | Sort by this column: `true`, or a list of options. See [Sorting](sorting.md). |
| `search` | Include this column in the search box. |
| `class` | Classes for this column's cells. |

A column with no `field` shows whatever you put in it, like buttons for each record:

```heex
<:col :let={user} label="Actions">
  <.link navigate={~p"/users/#{user.id}/edit"}>Edit</.link>
</:col>
```

## Resource or Query

Give a collection a `resource` to read it with its primary read action, or name another action
with `action`. Pass `actor`, `tenant`, or an Ash `scope`, as you would to `Ash.read`.

To start from a query of your own, like one with a filter every user should have, pass `query`
instead. Users' filters narrow it further. Build it in `mount`, so it isn't rebuilt on every
render:

```elixir
def mount(_params, _session, socket) do
  require Ash.Query
  {:ok, assign(socket, :engineers, Ash.Query.filter(MyApp.User, department == "Engineering"))}
end
```

```heex
<Cinder.collection query={@engineers} actor={@current_user}>
  ...
</Cinder.collection>
```

## Testing

Collections load their data after the page renders, so wait for it with `render_async/1`:

```elixir
test "lists users", %{conn: conn} do
  user = insert(:user)

  {:ok, view, _html} = live(conn, ~p"/users")

  assert render_async(view) =~ user.name
end
```

With `initial_load={:sync}` (or `config :cinder, default_initial_load: :sync`), the data is
already in the first render.

## Next Steps

- [Filters](filters.md): every filter type and its options, search, and laying out the filters yourself
- [Sorting](sorting.md): sort cycles, default sorts and tiebreakers
- [Advanced Features](advanced.md): pagination, keeping state in the URL, loading and empty
  states, refreshing, selection and bulk actions, telemetry
- [Theming](theming.md): the built-in themes and writing your own
- [Localization](localization.md): translations
