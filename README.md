# Cinder

A powerful, intelligent data table component for Ash Framework resources, in your Phoenix LiveView applications.

## What is Cinder?

Cinder transforms complex data table requirements into simple, declarative markup. With automatic type inference and intelligent defaults, you can build feature-rich tables for Ash resources and queries, with minimal configuration.

```elixir
<Cinder.Table.table resource={MyApp.User} actor={@current_user}>
  <:col :let={user} field="name" filter sort>{user.name}</:col>
  <:col :let={user} field="email" filter>{user.email}</:col>
  <:col :let={user} field="department.name" filter sort>{user.department.name}</:col>
</Cinder.Table.table>
```

That's it! Cinder automatically provides:
- ✅ Intelligent filter types based on your Ash resource
- ✅ Interactive sorting with visual indicators
- ✅ Pagination with efficient queries
- ✅ Relationship support via dot notation
- ✅ URL state management for bookmarkable views
- ✅ Responsive design with flexible theming

<video controls width="100%">
  <source src="./docs/screenshots/demo.mp4" type="video/mp4">
  <source src="./screenshots/demo.mp4" type="video/mp4">
</video>

*Sort and filter by calculations, aggregates, attributes, or even relationship data!*

## Key Features

- **🧠 Intelligent Defaults**: Automatic filter type detection from Ash resource attributes
- **⚡ Minimal Configuration**: 70% fewer attributes required compared to traditional table components
- **🔗 Complete URL State Management**: Filters, pagination, and sorting synchronized with browser URL
- **🌐 Relationship Support**: Dot notation for related fields (e.g., `user.department.name`)
- **🎨 Advanced Theming**: 8 built-in themes (modern, retro, futuristic, dark, daisy_ui, flowbite, vintage, compact, pastel) plus powerful DSL for custom themes
- **🔧 Developer Experience**: Data attributes on every element make theme development and debugging effortless
- **⚡ Real-time Filtering**: Six filter types with debounced updates
- **📱 Responsive Design**: Mobile-friendly with loading states
- **🔐 Ash Integration**: Native support for Ash Framework resources and authorization

## Installation

### Using Igniter (Recommended)

If you're using [Igniter](https://hexdocs.pm/igniter) in your project:

```bash
mix igniter.install cinder
```

This will automatically:
- Add Cinder to your dependencies
- Configure Tailwind CSS to include Cinder's styles
- Provide setup instructions and examples

### Manual Installation

Add `cinder` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:cinder, "~> 0.1.0"}
  ]
end
```

Then run:

```bash
mix deps.get
mix cinder.install  # Configure Tailwind CSS
```

The installer will automatically update your Tailwind configuration to include Cinder's CSS classes. If automatic configuration fails, it will provide manual setup instructions.

## Quick Start

### Basic Table

```elixir
<Cinder.Table.table resource={MyApp.User} actor={@current_user}>
  <:col :let={user} field="name" filter sort>{user.name}</:col>
  <:col :let={user} field="email" filter>{user.email}</:col>
  <:col :let={user} field="created_at" sort>{user.created_at}</:col>
</Cinder.Table.table>
```

### Advanced Query Usage

For complex requirements, use the `query` parameter:

```elixir
<Cinder.Table.table query={MyApp.User |> Ash.Query.filter(active: true)} actor={@current_user}>
  <:col :let={user} field="name" filter sort>{user.name}</:col>
  <:col :let={user} field="email" filter>{user.email}</:col>
</Cinder.Table.table>
```

### URL State Management

Use `Cinder.Table.UrlSync` for bookmarkable table states.

Add `UrlSync.handle_params` to your `handle_params` function, which adds a `url_state` assign to pass through to the table. Everything else is handled for you!

```elixir
defmodule MyAppWeb.UsersLive do
  use MyAppWeb, :live_view
  use Cinder.Table.UrlSync

  def handle_params(params, uri, socket) do
    socket = Cinder.Table.UrlSync.handle_params(socket, params, uri)
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <Cinder.Table.table resource={MyApp.User} actor={@current_user} url_state={@url_state}>
      <:col :let={user} field="name" filter sort>{user.name}</:col>
    </Cinder.Table.table>
    """
  end
end
```

## Documentation

- **[Complete Examples](docs/examples.md)** - Comprehensive usage examples for all features
- **[Theming Guide](docs/theming.md)** - How to develop and use table themes
- **[Module Documentation](https://hexdocs.pm/cinder)** - Full API reference
- **[Hex Package](https://hex.pm/packages/cinder)** - Package information

For detailed examples of filters, sorting, theming, relationships, and advanced query usage, see the [examples documentation](docs/examples.md).

## Requirements

- Phoenix LiveView 1.0+
- Ash Framework 3.0+
- Elixir 1.17+

## Contributing

Contributions are welcome! Please submit pull requests to our GitHub repository.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
