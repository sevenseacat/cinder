# Cinder

A powerful, intelligent data table component for Phoenix LiveView applications with seamless Ash Framework integration.

## What is Cinder?

Cinder transforms complex data table requirements into simple, declarative markup. With automatic type inference and intelligent defaults, you can build feature-rich tables with minimal configuration.

```elixir
<Cinder.Table.table resource={MyApp.User} actor={@current_user}>
  <:col :let="user" field="name" filter sort>{user.name}</:col>
  <:col :let="user" field="email" filter>{user.email}</:col>
  <:col :let="user" field="department.name" filter sort>{user.department.name}</:col>
  <:col :let="user" field="tags" filter={:multi_select}>{Enum.join(user.tags, ", ")}</:col>
</Cinder.Table.table>
```

That's it! Cinder automatically provides:
- ✅ Intelligent filter types based on your Ash resource
- ✅ Interactive sorting with visual indicators
- ✅ Pagination with efficient queries
- ✅ Relationship support via dot notation
- ✅ URL state management for bookmarkable views
- ✅ Responsive design with flexible theming

## Key Features

- **🧠 Intelligent Defaults**: Automatic filter type detection from Ash resource attributes
- **⚡ Minimal Configuration**: 70% fewer attributes required compared to traditional table components
- **🔗 Complete URL State Management**: Filters, pagination, and sorting synchronized with browser URL
- **🌐 Relationship Support**: Dot notation for related fields (e.g., `user.department.name`)
- **🎨 Advanced Theming**: 10 built-in themes (default, modern, retro, futuristic, dark, daisy_ui, flowbite, vintage, compact, pastel) plus powerful DSL for custom themes
- **🔧 Developer Experience**: Data attributes on every element make theme development and debugging effortless
- **⚡ Real-time Filtering**: Six filter types with debounced updates
- **📱 Responsive Design**: Mobile-friendly with loading states
- **🔐 Ash Integration**: Native support for Ash Framework resources and authorization

## Installation

Add `cinder` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:cinder, "~> 0.1.0"}
  ]
end
```

## Quick Start

### Basic Table

```elixir
<Cinder.Table.table resource={MyApp.User} actor={@current_user}>
  <:col :let="user" field="name" filter sort>{user.name}</:col>
  <:col :let="user" field="email" filter>{user.email}</:col>
  <:col :let="user" field="skills" filter={:multi_select}>{Enum.join(user.skills, ", ")}</:col>
  <:col :let="user" field="created_at" sort>{user.created_at}</:col>
</Cinder.Table.table>
```

### With URL State Management

First, add the URL sync helper to your LiveView:

```elixir
defmodule MyAppWeb.UsersLive do
  use MyAppWeb, :live_view
  use Cinder.Table.UrlSync

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :current_user, get_current_user())}
  end

  def handle_params(params, uri, socket) do
    socket = Cinder.Table.UrlSync.handle_params(socket, params, uri)
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <Cinder.Table.table
      resource={MyApp.User}
      actor={@current_user}
      url_state={@url_state}
    >
      <:col :let="user" field="name" filter sort>{user.name}</:col>
      <:col :let="user" field="email" filter>{user.email}</:col>
      <:col :let="user" field="department.name" filter sort>{user.department.name}</:col>
      <:col :let="user" field="roles" filter={:multi_checkboxes}>{Enum.join(user.roles, ", ")}</:col>
    </Cinder.Table.table>
    """
  end
end
```

This enables bookmarkable URLs like:
```
/users?name=john&department.name=engineering&roles=admin,user&page=2&sort=-created_at
```

## Filter Types

Cinder automatically detects the right filter type:

- **String fields** → Text search
- **Enum fields** → Select dropdown
- **Boolean fields** → True/false/any radio buttons
- **Date/DateTime fields** → Date range picker
- **Integer/Decimal fields** → Number range inputs
- **Array fields** → Multi-select tag interface

### Multi-Select Options

For multiple selection filtering, choose between two interfaces:

- **`:multi_select`** - Modern tag-based interface with dropdown (default for arrays)
  - Selected items displayed as removable tags
  - Dropdown shows available options to add
  - Better for long option lists
  
- **`:multi_checkboxes`** - Traditional checkbox interface
  - All options displayed as checkboxes
  - Better for short, familiar option lists

```elixir
<!-- Use tag interface (default for array fields) -->
<:col field="tags" filter={:multi_select} />

<!-- Use checkbox interface -->
<:col field="categories" filter={:multi_checkboxes} />
```

## Documentation

- **[Complete Examples](docs/examples.md)** - Comprehensive usage examples
- **[Theming Guide](docs/theming.md)** - How to develop and use table themes
- **[Module Documentation](https://hexdocs.pm/cinder)** - Full API reference
- **[Hex Package](https://hex.pm/packages/cinder)** - Package information

## Requirements

- Phoenix LiveView 1.0+
- Ash Framework 3.0+
- Elixir 1.17+

## Contributing

Contributions are welcome! Please read our contributing guidelines and submit pull requests to our GitHub repository.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
