# Sorting

This guide covers sorting configuration and behavior. For basic setup, see [Getting Started](getting-started.md).

## Basic Sorting

Add `sort` to make columns sortable. Click column headers to cycle through sort states:

```heex
<Cinder.collection resource={MyApp.User} actor={@current_user}>
  <:col :let={user} field="name" sort>{user.name}</:col>
  <:col :let={user} field="email">{user.email}</:col>
  <:col :let={user} field="created_at" sort>{user.created_at}</:col>
</Cinder.collection>
```

## Sort Cycles

The default cycle is: unsorted → ascending → descending → unsorted

Customize with `cycle`:

```heex
<!-- No neutral state: always sorted one way or the other -->
<:col field="name" sort={[cycle: [:asc, :desc]]} />

<!-- Start descending (good for dates where newest-first is common) -->
<:col field="created_at" sort={[cycle: [:desc, :asc, nil]]} />

<!-- Ash null-handling directions -->
<:col field="completed_at" sort={[cycle: [:desc_nils_last, :asc_nils_first, nil]]} />
```

## Sort Mode

By default, clicking multiple column headers creates multi-column sorting ("sort by A, then by B"). Use `sort_mode` to change this behavior:

```heex
<!-- Default: additive sorting (clicking B while sorted by A gives "A then B") -->
<Cinder.collection resource={MyApp.User} actor={@current_user}>
  <:col :let={user} field="name" sort>{user.name}</:col>
  <:col :let={user} field="created_at" sort>{user.created_at}</:col>
</Cinder.collection>

<!-- Exclusive: clicking a column replaces existing sorts -->
<Cinder.collection resource={MyApp.User} actor={@current_user} sort_mode="exclusive">
  <:col :let={user} field="name" sort>{user.name}</:col>
  <:col :let={user} field="created_at" sort>{user.created_at}</:col>
</Cinder.collection>
```

Sort modes:
- `"additive"` (default) - New sorts are added to existing ones
- `"exclusive"` - Clicking a column replaces all existing sorts

## Default Sort Order

Provide a default sort via the `query` parameter. User sorting replaces (not adds to) the default:

```heex
<Cinder.collection
  query={MyApp.User |> Ash.Query.sort(created_at: :desc)}
  actor={@current_user}
>
  <:col :let={user} field="name" sort>{user.name}</:col>
  <:col :let={user} field="created_at" sort>{user.created_at}</:col>
</Cinder.collection>
```

### Default Sort on Embedded Fields

For embedded fields, use `Cinder.QueryBuilder.apply_sorting/2` with the double underscore notation:

```heex
<Cinder.collection
  query={MyApp.User |> Cinder.QueryBuilder.apply_sorting([{"profile__last_name", :asc}])}
  actor={@current_user}
>
  <:col :let={user} field="profile__last_name" sort>{user.profile.last_name}</:col>
</Cinder.collection>
```
