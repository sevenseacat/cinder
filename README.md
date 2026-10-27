<!--
SPDX-FileCopyrightText: 2025 Cinder contributors <https://github.com/sevenseacat/cinder/graphs/contributors>

SPDX-License-Identifier: MIT
-->

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
- **🌍 Internationalization**: Built-in translations ([eight languages](https://hexdocs.pm/cinder/localization.html#available-translations) and counting!)

## Installation

### Using Igniter (Recommended)

```bash
mix igniter.install cinder
```

### Manual Installation

Add to `mix.exs`:

```elixir
def deps do
  [{:cinder, "~> 0.17"}]
end
```

Then run:

```bash
mix deps.get
mix cinder.install  # Configure Tailwind CSS and LiveView hooks
```

Without Igniter, register Cinder's LiveView hooks by hand as shown in the [Upgrading Guide](https://cinder.hexdocs.pm/upgrading.html#upgrading-to-0-18-0).

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

- **[Getting Started](https://cinder.hexdocs.pm/getting-started.html)** - Basic usage, layouts, column configuration, and theming
- **[Filters](https://cinder.hexdocs.pm/filters.html)** - Filter types, search, and custom controls layout
- **[Sorting](https://cinder.hexdocs.pm/sorting.html)** - Sort cycles, modes, and defaults
- **[Advanced Features](https://cinder.hexdocs.pm/advanced.html)** - URL state, relationships, refresh, performance, and bulk actions
- **[Theming Guide](https://cinder.hexdocs.pm/theming.html)** - Built-in themes and custom theme creation
- **[Localization Guide](https://cinder.hexdocs.pm/localization.html)** - Internationalization support
- **[Upgrading Guide](https://cinder.hexdocs.pm/upgrading.html)** - Migration instructions from older versions
- **[HexDocs](https://cinder.hexdocs.pm/)** - Full API reference

## Requirements

- Phoenix LiveView 1.1+
- Ash Framework 3.24.5+
- Elixir 1.17+

## Contributing

`dev/` holds a Phoenix app for trying out Cinder's features by hand: each layout, every filter type, pagination, selection and bulk actions, and the custom slots, with a switcher for the built-in themes. It uses Cinder from this repo, so changes to `lib/` reload in the browser without a restart.

```bash
cd dev
mix setup
iex -S mix phx.server
```

Then visit [localhost:4000](http://localhost:4000). `mix check`, run from the repo root, also runs the dev app's tests.

## License

MIT License - see LICENSE file for details.
