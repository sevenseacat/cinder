defmodule Cinder do
  @moduledoc """
  Cinder is a powerful, intelligent data table component for Phoenix LiveView applications with seamless Ash Framework integration.

  ## Quick Start

  The simplest table requires only a resource (or query) and actor:

      # Using resource parameter
      <Cinder.Table.table resource={MyApp.User} actor={@current_user}>
        <:col :let={user} field="name" filter sort>{user.name}</:col>
        <:col :let={user} field="email" filter>{user.email}</:col>
        <:col :let={user} field="created_at" sort>{user.created_at}</:col>
      </Cinder.Table.table>

      # Using query parameter
      <Cinder.Table.table query={MyApp.User} actor={@current_user}>
        <:col :let={user} field="name" filter sort>{user.name}</:col>
        <:col :let={user} field="email" filter>{user.email}</:col>
        <:col :let={user} field="created_at" sort>{user.created_at}</:col>
      </Cinder.Table.table>

      # Advanced query usage
      <Cinder.Table.table query={MyApp.User |> Ash.Query.filter(active: true)} actor={@current_user}>
        <:col :let={user} field="name" filter sort>{user.name}</:col>
        <:col :let={user} field="email" filter>{user.email}</:col>
        <:col :let={user} field="created_at" sort>{user.created_at}</:col>
      </Cinder.Table.table>

  ## Key Features

  - **Intelligent Defaults**: Automatic filter type detection from Ash resource attributes
  - **Minimal Configuration**: 70% fewer attributes required compared to traditional table components
  - **URL State Management**: Filters, pagination, and sorting synchronized with browser URL
  - **Relationship Support**: Dot notation for related fields (e.g., `user.department.name`)
  - **Flexible Theming**: Built-in presets and full customization
  - **Ash Integration**: Native support for Ash Framework resources and authorization

  ## Main Components

  - `Cinder.Table` - The main table component
  - `Cinder.Table.UrlSync` - URL state management helper

  For comprehensive examples and documentation, see the [README](readme.html) and [Examples](examples.html).
  """
end
