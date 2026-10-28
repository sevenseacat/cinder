<!--
SPDX-FileCopyrightText: 2026 Cinder contributors <https://github.com/sevenseacat/cinder/graphs/contributors>

SPDX-License-Identifier: MIT
-->

# Sorting

This guide covers sorting a collection. For a first collection, see
[Getting Started](getting-started.md).

## Sortable Columns

Add `sort` to a column to sort by it. In a table, users click its heading; in a list or grid,
they click its button in the row of sort buttons above the items:

```heex
<Cinder.collection resource={MyApp.User} actor={@current_user}>
  <:col :let={user} field="name" sort>{user.name}</:col>
  <:col :let={user} field="email">{user.email}</:col>
  <:col :let={user} field="inserted_at" sort>{user.inserted_at}</:col>
</Cinder.collection>
```

In a list or grid, change the sort buttons' label with `sort_label`, or hide them with
`show_sort={false}`.

A column can sort by an attribute, a field through relationships (`artist.name`), a field of an
embedded resource (`profile__last_name`), an aggregate, or a calculation the data layer can run
(an expression calculation). A column with `sort` on anything else, like a calculation run in
Elixir or one that needs arguments, isn't sortable and logs a warning. In 1.0 this raises.

## Sort Cycles

Each click moves a column on to its next direction: unsorted, then ascending, then descending,
then unsorted again. Change the order with `cycle`:

```heex
<!-- Newest first -->
<:col field="inserted_at" sort={[cycle: [:desc, :asc, nil]]} />

<!-- Always sorted, never unsorted -->
<:col field="name" sort={[cycle: [:asc, :desc]]} />

<!-- With Ash's directions for where empty values go -->
<:col field="completed_at" sort={[cycle: [:desc_nils_last, :asc_nils_first, nil]]} />
```

A cycle without `nil` can't be unsorted, so the collection starts sorted by that column, in the
cycle's first direction. All of Ash's directions work: `:asc`, `:desc`, `:asc_nils_first`,
`:asc_nils_last`, `:desc_nils_first` and `:desc_nils_last`.

## Sorting by Several Columns

Clicking a second column adds to the sort: sorted by the first column, then by the second.
With `sort_mode={:exclusive}` (or `"exclusive"`), clicking a column replaces the sort instead:

```heex
<Cinder.collection resource={MyApp.User} actor={@current_user} sort_mode={:exclusive}>
  <:col :let={user} field="name" sort>{user.name}</:col>
  <:col :let={user} field="inserted_at" sort>{user.inserted_at}</:col>
</Cinder.collection>
```

## Tiebreakers

`then` lists fields to sort by after a column, to put the records it leaves tied into a
predictable order:

```heex
<!-- Stops in the same position stay in the order they were added -->
<:col field="position" sort={[then: ["inserted_at"]]} />
```

They follow the column's direction, and go after all the user's sorts, so they only order what
those leave tied. A tiebreaker the user sorts by themselves keeps the user's direction. One that
can't be sorted by is left out, with a warning.

## Default Sort

To sort a collection before the user does, give it a `query` with a sort:

```heex
<Cinder.collection query={Ash.Query.sort(MyApp.User, inserted_at: :desc)} actor={@current_user}>
  <:col :let={user} field="name" sort>{user.name}</:col>
  <:col :let={user} field="inserted_at" sort>{user.inserted_at}</:col>
</Cinder.collection>
```

If the query sorts by a sortable column's field, ascending or descending, that column shows as
sorted, and the user's clicks carry on from there. Once the collection has a sort of its own,
from the user or from such a column, it replaces the query's sorts entirely.

To sort by an embedded field by default, use `Cinder.QueryBuilder.apply_sorting/2`, which knows
the `__` notation:

```heex
<Cinder.collection query={Cinder.QueryBuilder.apply_sorting(MyApp.User, [{"profile__last_name", :asc}])}>
  <:col :let={user} field="profile__last_name" sort>{user.profile.last_name}</:col>
</Cinder.collection>
```

## Sorting in the URL

With [URL sync](advanced.md#url-state-management), the sort is kept in the URL as
`sort=-inserted_at,name`: fields in order, with `-` for descending. Ash's other directions use
`--` (descending, empty last), `++` (ascending, empty first), `-+` (ascending, empty last) and
`+-` (descending, empty first). Fields that aren't sortable columns are ignored.
