<!--
SPDX-FileCopyrightText: 2026 Cinder contributors <https://github.com/sevenseacat/cinder/graphs/contributors>

SPDX-License-Identifier: MIT
-->

# Filters

This guide covers every filter type, filters without a column, search, and laying out the filters
yourself. For a first collection, see [Getting Started](getting-started.md).

## Table of Contents

- [Choosing a Filter Type](#choosing-a-filter-type)
- [Filter Types](#filter-types)
- [What Can Be Filtered](#what-can-be-filtered)
- [Filters Without a Column](#filters-without-a-column)
- [Collapsible Filters](#collapsible-filters)
- [Search](#search)
- [Custom Filter Functions](#custom-filter-functions)
- [Laying Out the Filters Yourself](#laying-out-the-filters-yourself)

**See also:** [Sorting](sorting.md) | [Custom Filters](custom-filters.md)

## Choosing a Filter Type

`filter` on its own picks the filter type from the field's Ash type:

| Ash type | Filter type |
|---|---|
| `:string`, `:ci_string` | `:text` |
| `:boolean` | `:boolean` |
| `:date`, `:datetime`, `:utc_datetime`, `:naive_datetime`, `:time` | `:date_range` |
| `:integer`, `:decimal`, `:float` | `:number_range` |
| An `Ash.Type.Enum`, or a `one_of` constraint | `:select` |
| `{:array, _}` | `:multi_select` |
| Anything else | `:text` |

To choose the type, give it instead of `true`, as an atom or a string:

```heex
<:col :let={user} field="status" filter={:radio_group}>{user.status}</:col>
```

To give options as well, pass a keyword list with the type under `type`:

```heex
<:col :let={user} field="status" filter={[type: :select, options: [{"Active", "active"}, {"Suspended", "suspended"}]]}>
  {user.status}
</:col>
```

Every filter takes a `label` option, which changes the filter's label without changing the
column's heading: `filter={[type: :text, label: "Title contains"]}`.

Filters that offer a list of options (select, multi-select, multi-checkboxes, radio group and
autocomplete) take them as `{label, value}` tuples. On an enum field, or an array of one, they
list the enum's values when you don't give `options`.

## Filter Types

### Text

Matches values containing the text, ignoring case:

```heex
<:col :let={article} field="title" filter>{article.title}</:col>

<:col :let={article} field="content" filter={[type: :text, placeholder: "Search content..."]}>
  {article.content}
</:col>
```

| Option | |
|---|---|
| `operator` | `:contains` (default), `:starts_with`, `:ends_with` or `:equals` |
| `case_sensitive` | `true` to match case (default `false`) |
| `placeholder` | The input's placeholder text |

### Select

A dropdown for choosing one value:

```heex
<:col :let={user} field="role" filter>{user.role}</:col>

<:col :let={user} field="department" filter={[type: :select, options: @departments, prompt: "All departments"]}>
  {user.department}
</:col>
```

| Option | |
|---|---|
| `options` | `{label, value}` tuples (the enum's values on an enum field) |
| `prompt` | The text for "no value chosen" (default "All *label*") |

### Multi-Select and Multi-Checkboxes

Both choose any number of values: `:multi_select` as a dropdown of checkboxes, and
`:multi_checkboxes` as a list of checkboxes.

```heex
<:col :let={product} field="tags" filter={[type: :multi_select, options: @tags]}>
  {Enum.join(product.tags, ", ")}
</:col>

<:col :let={user} field="role" filter={[type: :multi_checkboxes, options: [{"Admin", "admin"}, {"Editor", "editor"}]]}>
  {user.role}
</:col>
```

On a single-value field, a record matches if its value is one of those chosen. On an array field
(including a `list` aggregate, or an array through a relationship like `albums.tags`), a record
matches if its array holds any of them, or all of them with `match_mode: :all`:

```heex
<:col field="tags" filter={[type: :multi_select, options: @tags, match_mode: :all]} />
```

| Option | |
|---|---|
| `options` | `{label, value}` tuples |
| `match_mode` | For arrays: `:any` (default) or `:all` of the chosen values |
| `prompt` | The dropdown's text when nothing is chosen (`:multi_select` only) |

### Boolean

Radio buttons for true and false. With neither chosen, records aren't filtered by it:

```heex
<:col :let={user} field="verified" filter={[type: :boolean, labels: %{true: "Verified", false: "Unverified"}]}>
  {user.verified}
</:col>
```

| Option | |
|---|---|
| `labels` | The text for each button: a map with `true` and `false` keys (default "True" and "False") |

### Radio Group

Radio buttons for choosing one value from a short list:

```heex
<:col :let={order} field="status" filter={[type: :radio_group, options: [{"Pending", "pending"}, {"Shipped", "shipped"}, {"Delivered", "delivered"}]]}>
  {order.status}
</:col>
```

| Option | |
|---|---|
| `options` | `{label, value}` tuples (the enum's values on an enum field) |

### Checkbox

A single checkbox, for "only show these":

```heex
<!-- On a boolean field, checking it shows the true ones -->
<:col :let={article} field="published" filter={[type: :checkbox, label: "Published only"]}>
  {article.published}
</:col>

<!-- On any other field, checking it shows those with the value -->
<:col :let={article} field="priority" filter={[type: :checkbox, value: "high", label: "High priority only"]}>
  {article.priority}
</:col>
```

| Option | |
|---|---|
| `label` | The checkbox's text, and the filter's label (default the column's label) |
| `value` | The value to match when checked (default `true`) |

### Date

A single date picker that matches one day: the whole day, on a datetime field. Date and datetime
fields get a date range by default, so choose this one:

```heex
<:col :let={order} field="delivered_on" filter={:date}>{order.delivered_on}</:col>
```

### Date Range

From and to date pickers. Either can be left empty for an open-ended range:

```heex
<:col :let={order} field="shipped_at" filter={[type: :date_range, include_time: true]}>
  {order.shipped_at}
</:col>
```

| Option | |
|---|---|
| `include_time` | `true` to pick a time as well as a date |

### Number Range

Minimum and maximum inputs. Either can be left empty:

```heex
<:col :let={product} field="quantity" filter={[type: :number_range, min: 0, max: 10000, step: 10]}>
  {product.quantity}
</:col>
```

| Option | |
|---|---|
| `min`, `max`, `step` | Limits for both inputs, for the browser's number input to enforce |

### Autocomplete

A text box that lists matching options as you type, for when there are too many for a dropdown:

```heex
<:col :let={order} field="customer_id" filter={[type: :autocomplete, options: @customers, max_results: 15]}>
  {order.customer.name}
</:col>
```

| Option | |
|---|---|
| `options` | `{label, value}` tuples (the enum's values on an enum field) |
| `placeholder` | The input's placeholder text |
| `max_results` | How many matching options to list (default 10) |

## What Can Be Filtered

A column can filter by an attribute, a field through relationships (`artist.name`), a field of an
embedded resource (`profile__country`), an aggregate, or a calculation the data layer can run (an
expression calculation). See [Advanced Features](advanced.md#relationship-fields) for more on
relationship and embedded fields.

A column with `filter` on a field that can't be filtered by gets no filter, and logs a warning.
That's a field that doesn't exist, a calculation run in Elixir rather than the data layer, or a
calculation that needs arguments. In 1.0 this raises.

Values that don't fit a filter are ignored rather than used, like a date that isn't a date in a
hand-edited URL, or a choice that isn't one of the filter's options. Multi-select filters with no
options keep at most 100 values.

## Filters Without a Column

A `<:filter>` slot adds a filter for a field that has no column, like a date you filter by but
don't show:

```heex
<Cinder.collection resource={MyApp.Order} actor={@current_user}>
  <:col :let={order} field="order_number">{order.order_number}</:col>
  <:col :let={order} field="total">{order.total}</:col>

  <:filter field="inserted_at" type={:date_range} label="Order date" />
  <:filter field="status" type={:select} options={[{"Pending", "pending"}, {"Shipped", "shipped"}]} />
  <:filter field="customer_name" placeholder="Customer name..." />
</Cinder.collection>
```

A field can't have both a `<:filter>` slot and a column with `filter`.

| Attribute | |
|---|---|
| `field` | The field to filter by (required) |
| `type` | The filter type (picked from the field's type if not given) |
| `label` | The filter's label |
| `fn` | A [custom filter function](#custom-filter-functions) |

It also takes any of the filter types' options as attributes: `options`, `prompt`, `operator`,
`case_sensitive`, `placeholder`, `labels`, `value`, `match_mode`, `include_time`, `min`, `max`,
`step` and `max_results`.

## Collapsible Filters

With many filters, the filter inputs can start hidden. The header, with the active filter count
and "Clear all", stays visible, with a button that shows and hides the inputs without a trip to
the server:

```heex
<!-- Starts hidden -->
<Cinder.collection resource={MyApp.User} actor={@current_user} show_filters={:toggle}>
  ...
</Cinder.collection>

<!-- Starts shown -->
<Cinder.collection resource={MyApp.User} actor={@current_user} show_filters={:toggle_open}>
  ...
</Cinder.collection>
```

| `show_filters` | |
|---|---|
| `nil` (default) | Shown when there are filters or search |
| `true` | Always shown |
| `false` | Never shown |
| `:toggle` | Can be hidden, and starts hidden |
| `:toggle_open` | Can be hidden, and starts shown |

String values (`"toggle"`) work too. Set the default for every collection in your config:

```elixir
config :cinder, show_filters: :toggle
```

## Search

The search box filters across every column with `search` at once, showing records where any of
them contains the text, ignoring case:

```heex
<Cinder.collection resource={MyApp.User} actor={@current_user}>
  <:col :let={user} field="name" filter search>{user.name}</:col>
  <:col :let={user} field="email" filter search>{user.email}</:col>
  <:col :let={user} field="role" filter>{user.role}</:col>
</Cinder.collection>
```

The search box appears when a column has `search`. Change its label and placeholder, or turn it
off, with the collection's `search` attribute:

```heex
<Cinder.collection resource={MyApp.Album} search={[label: "Find albums", placeholder: "Title or artist..."]}>
  <:col :let={album} field="title" search>{album.title}</:col>
  <:col :let={album} field="artist.name" search>{album.artist.name}</:col>
</Cinder.collection>

<Cinder.collection resource={MyApp.Album} search={false}>
  ...
</Cinder.collection>
```

A column with `search` on a field that can't be searched logs a warning, like `filter` does.

### Custom Search

To search your own way, pass a function as `fn`. It receives the query, the columns with
`search`, and the text, and returns the query with your filter. It's only called when at least
one column has `search`:

```heex
<Cinder.collection resource={MyApp.Album} search={[fn: &MyApp.AlbumSearch.search/3]}>
  <:col :let={album} field="title" search>{album.title}</:col>
</Cinder.collection>
```

```elixir
defmodule MyApp.AlbumSearch do
  require Ash.Query

  # An exact catalogue number, or part of the title
  def search(query, _columns, text) do
    Ash.Query.filter(query, catalogue_number == ^text or contains(title, ^text))
  end
end
```

## Custom Filter Functions

To filter in a way the built-in filters can't, give a filter a `fn`. It receives the query and
the filter's value, and returns the query with your filter:

```heex
<:col :let={invoice} field="status" filter={[type: :select, options: @statuses, fn: &filter_status/2]}>
  {invoice.status}
</:col>
```

```elixir
require Ash.Query

# "Overdue" isn't a status: it's a pending invoice past its due date
def filter_status(query, %{value: "overdue"}) do
  today = Date.utc_today()
  Ash.Query.filter(query, status == "pending" and due_date < ^today)
end

def filter_status(query, %{value: status}) do
  Ash.Query.filter(query, status == ^status)
end
```

The value is a map with the filter's `:type`, `:value` and `:operator`, plus `:case_sensitive`
for text filters and `:match_mode` for multi-value ones.

## Laying Out the Filters Yourself

The `:controls` slot replaces how the filters and search box are laid out, while Cinder still
handles their state, the URL, and the query:

```heex
<Cinder.collection resource={MyApp.User} actor={@current_user}>
  <:col :let={user} field="name" filter sort search>{user.name}</:col>
  <:col :let={user} field="status" filter={:select}>{user.status}</:col>

  <:controls :let={controls}>
    <div class="flex items-center gap-4 mb-4">
      <Cinder.Controls.render_search search={controls.search} theme={controls.theme} target={controls.target} />
      <button type="button" phx-click="export">Export</button>
    </div>
    <div class="grid grid-cols-2 gap-4">
      <Cinder.Controls.render_filter
        :for={{_field, filter} <- controls.filters}
        filter={filter}
        theme={controls.theme}
        target={controls.target}
        raw_filter_params={controls.raw_filter_params}
      />
    </div>
  </:controls>
</Cinder.collection>
```

Cinder wraps the slot in its filter form, so inputs named like Cinder's own
(`filters[status]` for a field called `status`) work without anything else. That means you can
mix the helpers with your own inputs:

```heex
<:controls :let={controls}>
  <Cinder.Controls.render_header {controls} />
  <div class="flex gap-4">
    <Cinder.Controls.render_filter filter={controls.filters[:name]} theme={controls.theme} target={controls.target} />
    <.my_select
      name="filters[status]"
      value={controls.filters[:status].value}
      options={[{"Active", "active"}, {"Inactive", "inactive"}]}
    />
  </div>
</:controls>
```

### Helpers

- `Cinder.Controls.render_filter/1`: one filter, with its label, input and clear button. Pass
  `raw_filter_params` for autocomplete filters, so they keep what's been typed.
- `Cinder.Controls.render_search/1`: the search box.
- `Cinder.Controls.render_header/1`: the header, with the label, active filter count, "Clear all"
  and the show/hide toggle.

### What the Slot Receives

| Key | |
|---|---|
| `filters` | Each filter, in column order, as a keyword list keyed by field (`controls.filters[:status]`; a relationship field is `controls.filters[:"artist.name"]`). Each holds its `field`, `label`, `type`, `value`, `options`, input `name` and `id`. |
| `search` | The search box's `value`, `name`, `label`, `placeholder` and `id`, or `nil` when there's no search |
| `active_filter_count` | How many filters are in use |
| `target` | The collection, for `phx-target` |
| `theme` | The theme |
| `table_id` | The collection's DOM id |
| `filters_label` | The filters section's label |
| `filter_mode` | The `show_filters` setting |
| `filter_values` | Every filter's current value |
| `raw_filter_params` | The form's raw values, for autocomplete filters |
