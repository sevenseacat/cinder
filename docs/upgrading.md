<!--
SPDX-FileCopyrightText: 2025 Cinder contributors <https://github.com/sevenseacat/cinder/graphs/contributors>

SPDX-License-Identifier: MIT
-->

# Upgrading Guide

This guide covers breaking changes, deprecations, and migration paths for Cinder.

## Upgrading to 0.18.0

### Changed: Cinder requires LiveView 1.1 and ships a JS hook

Cinder now includes a [colocated hook](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.ColocatedHook.html)
that clears partially typed date and number filters. It requires `phoenix_live_view ~> 1.1`,
and your `LiveSocket` has to register Cinder's hooks.

**This affects every app using Cinder.** Without the hook, filters still work, but partially
typed values are not cleared and LiveView logs an "unknown hook" error in the browser console.

#### Automatic Migration

```bash
mix cinder.upgrade 0.17.0 0.18.0
```

This edits `assets/js/app.js` when it finds the usual Phoenix 1.8 `LiveSocket` setup. If it
can't, it prints the manual steps below instead.

#### Manual Migration

```javascript
import {hooks as cinderHooks} from "phoenix-colocated/cinder"

const liveSocket = new LiveSocket("/live", Socket, {
  hooks: {...cinderHooks, ...colocatedHooks},
  // ...
})
```

Your bundler must resolve `phoenix-colocated`. Apps generated with Phoenix 1.8 already do;
otherwise add `Mix.Project.build_path()` to esbuild's `NODE_PATH` (see the
[ColocatedJS docs](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.ColocatedJS.html#module-internals)).
In release builds, run `mix compile` before `mix assets.deploy`.

### Changed: Cinder requires Ash 3.24.5

Text filters' `:starts_with` and `:ends_with` operators now use Ash's `string_starts_with` and
`string_ends_with`, which arrived in Ash 3.24.5. (They used to match anywhere in the value, like
`:contains`.) Apps using `ash_sql` (through `ash_postgres`, for example) also need `ash_sql` 0.6.3
or later. If Hex reports a conflict, run `mix deps.update ash ash_sql ash_postgres`.

### Changed: `use Cinder.UrlSync` must come after `use Phoenix.LiveView`

`use Cinder.UrlSync` now handles `handle_params/3` for you, so it has to come after
`use MyAppWeb, :live_view` (or `use Phoenix.LiveView`). If it comes first, compiling
fails with an error saying so.

A `handle_params/3` that only calls `Cinder.UrlSync.handle_params/3` can be removed, but
it still works if you keep it.

### Changed: bulk actions only act on records still in the collection's `query`

A bulk action now acts only on the selected records that are still in the collection's
`query`, and the selection is cleared when the `query` changes. A bulk action that partly
fails now sends your `on_error` message, with `partial: true` in its payload, instead of
`on_success`.

**This only affects you if you change a collection's `query` while records are selected, or
handle partly failed bulk actions in `on_success`.**

### Changed: a filter that can't be applied shows the error state

A filter that fails to build now shows the collection's error state, instead of showing
unfiltered results. Filter values that can't be used, like an invalid date in the URL, are
ignored. If a collection that used to show data now shows its error state, check your logs for
the filter that failed.

### Changed: URL parameters are checked against the collection

Sorts in the URL are ignored unless their field is a sortable column, page numbers are capped at
1,000,000, and multi-select values are trimmed to the filter's options (or to 100 when it has
none). **This only affects you if you link to URLs that sort by fields that aren't sortable
columns.** Add `sort` to those columns.

### Changed: sorting, filtering or searching a column that can't support it warns

A column with `sort` or `filter` on a field that can't be sorted or filtered by (one that
doesn't exist, an in-memory calculation, or a calculation that needs arguments) still gets
neither, but now logs a warning. So does a column with `search` on such a field, which the
search skips, unless the collection has its own search function (`search={[fn: ...]}`). In
1.0 these raise, so fix any you see: remove the option, or use a field that supports it.

### Removed: date filters' `format` option

It never did anything: browser date inputs always show dates in the user's locale. Remove it
from your `<:filter>` slots.

### Deprecated: `Cinder.UrlManager.validate_url_params/1`

Cinder never called it, and it's removed in 1.0. URL params are bounded where they're
decoded instead: sorts are kept only for declared sortable columns, filters only for
declared filterable columns (with multi-select values trimmed to the filter's options),
page sizes only from the configured options, and pages are capped. If you call it
yourself, check what you rely on it for: its limits (50 params, 1,000 characters each) can
reject legitimate URLs.

### Deprecated: `Cinder.QueryBuilder`'s field helpers

`validate_field_existence/2`, `field_exists_on_resource?/2`, `resolve_field_resource/2`,
`get_calculation_info/2` and `calculation_sortable?/1` are removed in 1.0. Cinder no longer
uses them. They no longer accept the bracket notation (`profile[:first_name]`).

### Deprecated: `Cinder.Table.table/1` now warns

It was deprecated in 0.9, and calls to it now warn when they're compiled. It's removed in
1.0: see [the 0.9 notes](#new-unified-collection-api) to switch to
`Cinder.collection`. `Cinder.Table`'s `process_columns/2`, `process_filter_slots/2`,
`build_query_columns/2` and `process_search_config/2` are deprecated too: call them on
`Cinder.Collection` instead.

### Deprecated: `Cinder.setup/0`

Custom filters are read from `config :cinder, :filters` when they're used, so there's nothing
to set up: remove the call from your `Application.start/2`.
`Cinder.Filters.Registry.register_filter/2` is deprecated for the same reason.

### Deprecated: other functions removed in 1.0

- `Cinder.UrlManager.decode_sort/1`: use `decode_sort/2`, which keeps only the sortable
  columns' fields.
- `Cinder.UrlSync.extract_table_state/1`: use `extract_collection_state/1`.
- `Cinder.Theme.validate/1`, `Cinder.Theme.valid_property?/1` and
  `Cinder.Messages.gettext_backend/0`: Cinder never called them.

## Upgrading to 0.17.0

### Changed: a custom filter named `:date` clashes with the new built-in

0.17 adds a built-in `:date` filter. A custom filter configured as `date:` in
`config :cinder, :filters` still takes precedence, but logs a "Cannot override built-in filter
type" warning. Rename it, or switch to the built-in.

## Upgrading to 0.16.0

### Removed: Unicode sort-glyph theme keys

List and grid layouts now render the same Heroicon sort indicators as the table, so the
text-glyph properties they used are gone:

| Removed key | Replacement |
|-------------|-------------|
| `sort_asc_icon` | `sort_asc_icon_name` / `sort_asc_icon_class` |
| `sort_desc_icon` | `sort_desc_icon_name` / `sort_desc_icon_class` |
| `sort_icon_class` | `sort_arrow_wrapper_class` |

**This only affects you if you have custom themes that set these keys.** The replacement
properties already drove the table renderer, so any value you set there now applies to every
layout. Remove the old keys from your custom theme:

```elixir
# Before
set :sort_asc_icon, "↑"
set :sort_desc_icon, "↓"
set :sort_icon_class, "ml-1"

# After — style the Heroicons instead (these likely already exist in your theme)
set :sort_asc_icon_name, "hero-chevron-up"
set :sort_desc_icon_name, "hero-chevron-down"
set :sort_asc_icon_class, "w-3 h-3"
set :sort_desc_icon_class, "w-3 h-3"
```

## Upgrading to 0.15.0

### Changed: custom filters receive embedded fields in double-underscore notation

Custom filters that implement `build_query/3` now receive embedded fields in
double-underscore notation (`profile__first_name`) — the same notation used everywhere else
(column definitions, URLs, forms). Previously the field arrived in bracket notation
(`profile[:first_name]`), an internal-only representation.

**This only affects custom filters on embedded fields that parse the field string
themselves.** Built-in filters, and any custom filter that delegates to
`Cinder.Filter.Helpers.build_ash_filter/5`, are unaffected — the helper accepts both
notations.

```elixir
# If your custom filter parsed the field itself, e.g.:
def build_query(query, field, filter_value) do
  [embed, sub] = field |> String.trim_trailing("]") |> String.split("[:")  # bracket-specific
  # ...
end

# Switch to double-underscore handling, or simply delegate:
def build_query(query, field, %{value: value, operator: operator}) do
  Cinder.Filter.Helpers.build_ash_filter(query, field, value, operator)
end
```

Bracket notation is also now deprecated wherever it is still accepted (e.g. a bracket string
passed directly to `build_ash_filter/5` or `parse_field_notation/1`); it logs a warning and
will be removed in Cinder 1.0. Use double-underscore notation instead.

## Upgrading to 0.14.0

### Changed: Tailwind setup imports Cinder's CSS

Cinder's Tailwind setup now imports only the built-in themes you use, instead of scanning all of
Cinder's code.

#### Automatic Migration

```bash
mix cinder.upgrade 0.13.0 0.14.0
```

This replaces `@source "../../deps/cinder";` in `assets/css/app.css` (Tailwind v4), or the
`deps/cinder` entry in `assets/tailwind.config.js` (v3), with `@import` lines for Cinder's CSS and
the theme set as your `default_theme`.

If you use other built-in themes through `theme=` on individual collections, add an `@import`
line for each of them too (see [Tailwind setup](theming.md#tailwind-setup)).

### Changed: bulk action functions get the collection's authorization options as given

A function-form bulk action (`<:bulk_action action={&MyApp.archive/2}>`) now receives `:scope`,
`:actor` and `:tenant` exactly as they were given to the collection, to pass on to Ash.

**This only affects you if your function reads `opts[:actor]` when the collection was only given
`scope`.** Pass `opts` on to your Ash call, which applies the scope, or call
`Ash.Scope.to_opts(opts[:scope])`.

### Changed: an invalid `scope` raises

A `scope` that doesn't implement `Ash.Scope.ToOpts` (like a bare atom or integer) now raises
`Protocol.UndefinedError` from Ash, instead of being ignored.

## Upgrading to 0.10.0

### Renamed: `filter_boolean_*` Theme Keys

The boolean filter theme keys have been renamed to `filter_radio_group_*`:

| Old Key | New Key |
|---------|---------|
| `filter_boolean_container_class` | `filter_radio_group_container_class` |
| `filter_boolean_option_class` | `filter_radio_group_option_class` |
| `filter_boolean_radio_class` | `filter_radio_group_radio_class` |
| `filter_boolean_label_class` | `filter_radio_group_label_class` |

**This only affects you if you have custom themes that set these keys.**

#### Automatic Migration

Run the upgrade task to automatically rename the keys in your custom themes:

```bash
mix cinder.upgrade 0.9.1 0.10.0
```

#### Manual Migration

If you prefer to migrate manually, rename the keys in your custom theme module:

```elixir
# Before
set :filter_boolean_container_class, "flex space-x-6"
set :filter_boolean_radio_class, "h-4 w-4"

# After
set :filter_radio_group_container_class, "flex space-x-6"
set :filter_radio_group_radio_class, "h-4 w-4"
```

### Removed: `_data` Theme Keys

Theme maps no longer contain `_data` companion keys. Previously, every `_class` key had an auto-generated `_data` counterpart (e.g. `container_data`, `filter_text_input_data`) that was spread in templates to produce `data-key` attributes for browser inspector debugging. These `data-key` attributes are now hardcoded directly in templates.

**This only affects you if you have custom filter modules that reference `_data` theme keys.** If you only use built-in filters and themes, no changes are needed.

#### Custom filter templates

If your custom filter's `render/4` function spreads `_data` theme keys, replace them with hardcoded `data-key` attributes:

```heex
<%!-- Before --%>
<input
  class={@theme.filter_text_input_class}
  {@theme.filter_text_input_data}
/>

<%!-- After --%>
<input
  class={@theme.filter_text_input_class}
  data-key="filter_text_input_class"
/>
```

The `data-key` value is always the name of the corresponding `_class` key.

#### Custom themes

If your custom theme sets `_data` keys, remove them — they are no longer recognized:

```elixir
# Before
set :filter_text_input_class, "my-input-class"
set :filter_text_input_data, %{"data-key" => "filter_text_input_class"}  # remove this

# After
set :filter_text_input_class, "my-input-class"
```

## Upgrading to 0.9.0

### New Unified Collection API

Cinder 0.9 introduces `Cinder.collection`, a unified component that supports table, list, and grid layouts. This replaces the separate `Cinder.Table.table` component.

#### `Cinder.Table.table` → `Cinder.collection`

**Deprecated:** Use `Cinder.collection` instead.

```heex
<!-- OLD (deprecated) -->
<Cinder.Table.table resource={MyApp.User} actor={@current_user}>
  <:col :let={user} field="name" filter sort>{user.name}</:col>
  <:col :let={user} field="email" filter>{user.email}</:col>
</Cinder.Table.table>

<!-- NEW -->
<Cinder.collection resource={MyApp.User} actor={@current_user}>
  <:col :let={user} field="name" filter sort>{user.name}</:col>
  <:col :let={user} field="email" filter>{user.email}</:col>
</Cinder.collection>
```

The table layout is the default, so no `layout` attribute is needed. For other layouts:

```heex
<!-- List layout -->
<Cinder.collection resource={MyApp.User} actor={@current_user} layout={:list}>
  <:col field="name" filter sort />
  <:item :let={user}>
    <div>{user.name}</div>
  </:item>
</Cinder.collection>

<!-- Grid layout -->
<Cinder.collection resource={MyApp.User} actor={@current_user} layout={:grid}>
  <:col field="name" filter sort />
  <:item :let={user}>
    <div class="p-4 border rounded">{user.name}</div>
  </:item>
</Cinder.collection>
```

#### `row_click` → `click`

The `row_click` attribute has been renamed to `click`:

```heex
<!-- OLD -->
<Cinder.Table.table resource={MyApp.User} actor={@current_user} row_click={&JS.navigate("/users/#{&1.id}")}>

<!-- NEW -->
<Cinder.collection resource={MyApp.User} actor={@current_user} click={&JS.navigate("/users/#{&1.id}")}>
```

### Module Relocations

The following modules have been moved to cleaner namespaces:

#### `Cinder.Table.Refresh` → `Cinder.Refresh`

```elixir
# OLD (deprecated)
import Cinder.Table.Refresh
refresh_table(socket, "my-table")

# NEW
import Cinder.Refresh
refresh_table(socket, "my-table")

# Or use top-level delegates (recommended)
Cinder.refresh_table(socket, "my-table")
Cinder.refresh_tables(socket, ["table-1", "table-2"])
```

#### `Cinder.Table.UrlSync` → `Cinder.UrlSync`

```elixir
# OLD (deprecated)
use Cinder.Table.UrlSync
Cinder.Table.UrlSync.handle_params(params, uri, socket)

# NEW
use Cinder.UrlSync
Cinder.UrlSync.handle_params(params, uri, socket)
```

### Simplified Theme DSL

The theme DSL has been simplified. The `component/2` wrapper blocks are now deprecated in favor of flat `set` calls. (The `component` blocks did not have any functional purpose — they were purely cosmetic.)

```elixir
# OLD (deprecated)
defmodule MyApp.CustomTheme do
  use Cinder.Theme

  component Cinder.Components.Table do
    set :container_class, "bg-white shadow rounded-lg"
    set :th_class, "px-4 py-2 text-left font-semibold"
  end
end

# NEW
defmodule MyApp.CustomTheme do
  use Cinder.Theme

  # Table
  set :container_class, "bg-white shadow rounded-lg"
  set :th_class, "px-4 py-2 text-left font-semibold"
end
```

#### Automatic Migration

Run the upgrade task to automatically convert your theme files:

```bash
mix cinder.upgrade 0.8.1 0.9.0
```

The old `component/2` syntax will continue to work but shows deprecation warnings at compile time.

### Removed: `pastel` Theme

The `pastel` theme has been removed. If you were using it, switch to another theme or create a custom theme with similar styling.

```elixir
# If you were using pastel, switch to another theme
theme="modern"  # or any other available theme
```

Available themes: `modern`, `retro`, `futuristic`, `dark`, `daisy_ui`, `flowbite`, `compact`

### Migration Checklist

1. [ ] Replace `<Cinder.Table.table>` with `<Cinder.collection>`
2. [ ] Rename `row_click` attribute to `click`
3. [ ] Update `import Cinder.Table.Refresh` to `import Cinder.Refresh`
4. [ ] Update `use Cinder.Table.UrlSync` to `use Cinder.UrlSync`
5. [ ] Replace `theme="pastel"` with another theme
6. [ ] Migrate custom themes: `mix cinder.upgrade 0.8.1 0.9.0`
7. [ ] Run your test suite and fix any deprecation warnings

## Upgrading to 0.5.4

### Unified Filter API

#### `filter_options` → unified `filter` attribute

**Deprecated:** The `filter_options` attribute is deprecated. Use the unified `filter` attribute instead.

```heex
<!-- OLD (deprecated) -->
<:col field="status" filter={:select} filter_options={[options: [{"Active", "active"}, {"Inactive", "inactive"}]]}>

<!-- NEW -->
<:col field="status" filter={[type: :select, options: [{"Active", "active"}, {"Inactive", "inactive"}]]}>
```

The unified `filter` attribute accepts:
- A boolean (`true`/`false`) for auto-detected filtering
- An atom (`:select`, `:text`, etc.) for explicit filter type
- A keyword list for full configuration: `[type: :select, options: [...], fn: &custom_filter/2]`

## Preparing for 1.0

Everything deprecated is removed in 1.0. To prepare:

1. Fix every deprecation warning: at compile time, and in your logs (the `filter_options`
   attribute, bracket notation and the theme `component/2` macro warn as they're used).
2. Fix every column warning about `sort`, `filter` or `search` on a field that can't support it
   (see [0.18](#changed-sorting-filtering-or-searching-a-column-that-can-t-support-it-warns)):
   these raise in 1.0.
3. Run your test suite.

## Timeline

| Version | Changes |
|---------|---------|
| 0.5.4 | `filter_options` deprecated |
| 0.9.0 | `Cinder.Table.table` deprecated, module relocations, `pastel` theme removed, theme `component/2` syntax deprecated |
| 0.10.0 | `_data` theme keys removed, `filter_boolean_*` theme keys renamed to `filter_radio_group_*` |
| 0.14.0 | Tailwind setup imports Cinder's CSS, bulk action functions get authorization options as given, an invalid `scope` raises |
| 0.15.0 | Custom filters get embedded fields in `__` notation, bracket notation deprecated |
| 0.16.0 | Unicode sort-glyph theme keys removed |
| 0.17.0 | Built-in `:date` filter clashes with a custom one of the same name |
| 0.18.0 | LiveView 1.1 and Cinder's JS hook required, Ash 3.24.5 required, `use Cinder.UrlSync` after `use Phoenix.LiveView`, bulk actions only act on records in `query`, failed filters show the error state, URL parameters checked, unsupported column options warn, date `format` removed, `Cinder.Table.table` warns, `Cinder.setup/0` and other functions deprecated |
| 1.0.0 | All deprecated features removed |
