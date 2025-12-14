# Upgrading Guide

This guide covers breaking changes, deprecations, and migration paths for Cinder.

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
  <:item :let={product}>
    <div class="p-4 border rounded">{product.name}</div>
  </:item>
</Cinder.collection>
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

### Migration Checklist

1. [ ] Replace `<Cinder.Table.table>` with `<Cinder.collection>`
2. [ ] Update `import Cinder.Table.Refresh` to `import Cinder.Refresh`
3. [ ] Update `use Cinder.Table.UrlSync` to `use Cinder.UrlSync`
4. [ ] Run your test suite and fix any deprecation warnings

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

All deprecated features will be removed in version 1.0. To prepare:

1. Fix all deprecation warnings in your application
2. Run your test suite to catch any issues
3. Update any custom code that references deprecated modules

## Timeline

| Version | Changes |
|---------|---------|
| 0.5.4 | `filter_options` deprecated |
| 0.9.0 | `Cinder.Table.table` deprecated, module relocations |
| 1.0.0 | All deprecated features removed |
