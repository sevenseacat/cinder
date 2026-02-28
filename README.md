# Cinder

A powerful, intelligent data collection component for Ash Framework resources in Phoenix LiveView.

## What is Cinder?

Cinder transforms complex data table requirements into simple, declarative markup. With automatic type inference and intelligent defaults, you can build feature-rich tables, lists, and grids with minimal configuration.

```heex
<Cinder.collection resource={MyApp.User} actor={@current_user}>
  <:col :let={user} field="name" filter sort>{user.name}</:col>
  <:col :let={user} field="email" filter>{user.email}</:col>
  <:col :let={user} field="department.name" filter sort>{user.department.name}</:col>
  <:col :let={user} field="settings__country" filter>{user.settings.country}</:col>
</Cinder.collection>
```

Cinder automatically provides:
- ✅ Intelligent filter types based on your Ash resource (enums become selects, dates become range pickers, etc.)
- ✅ Interactive sorting with visual indicators
- ✅ Pagination with efficient queries
- ✅ Relationship and embedded resource support
- ✅ URL state management for bookmarkable views

## Key Features

- **📋 Multiple Layouts**: Table, List, and Grid with shared filtering, sorting, and pagination
- **🧠 Intelligent Defaults**: Automatic filter type detection from Ash attributes
- **🔗 URL State Management**: Filters, pagination, and sorting synchronized with browser URL
- **🌐 Relationship Support**: Dot notation for related fields (`user.department.name`)
- **📦 Embedded Resources**: Double underscore notation (`profile__country`) with automatic enum detection
- **🎨 Theming**: 9 built-in themes plus DSL for custom themes
- **🌍 Internationalization**: Built-in translations (English, Dutch, Swedish)

## Installation

### Using Igniter (Recommended)

```bash
mix igniter.install cinder
```

### Manual Installation

Add to `mix.exs`:

```elixir
def deps do
  [{:cinder, "~> 0.9"}]
end
```

Then run:

```bash
mix deps.get
mix cinder.install  # Configure Tailwind CSS
```

## Quick Start

```heex
<Cinder.collection resource={MyApp.User} actor={@current_user}>
  <:col :let={user} field="name" filter sort>{user.name}</:col>
  <:col :let={user} field="email" filter>{user.email}</:col>
  <:col :let={user} field="role" filter>{user.role}</:col>
</Cinder.collection>
```

For list or grid layouts:

```heex
<Cinder.collection resource={MyApp.Product} actor={@current_user} layout={:grid} grid_columns={3}>
  <:col field="name" filter sort />
  <:item :let={product}>
    <div class="p-4 border rounded">{product.name}</div>
  </:item>
</Cinder.collection>
```

## Documentation

- **[Getting Started](docs/getting-started.md)** - Basic usage, layouts, column configuration, and theming
- **[Filters](docs/filters.md)** - Filter types, search, and custom controls layout
- **[Sorting](docs/sorting.md)** - Sort cycles, modes, and defaults
- **[Advanced Features](docs/advanced.md)** - URL state, relationships, refresh, performance, and bulk actions
- **[Theming Guide](docs/theming.md)** - Built-in themes and custom theme creation
- **[Localization Guide](docs/localization.md)** - Internationalization support
- **[Upgrading Guide](docs/upgrading.md)** - Migration instructions from older versions
- **[HexDocs](https://hexdocs.pm/cinder)** - Full API reference

## Requirements

- Phoenix LiveView 1.0+
- Ash Framework 3.0+
- Elixir 1.17+

## License

MIT License - see LICENSE file for details.