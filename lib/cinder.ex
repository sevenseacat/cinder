defmodule Cinder do
  @moduledoc """
  Cinder is a library for building interactive LiveView components with Ash Framework.

  ## Components

  * `Cinder.Table` - Interactive data tables for Ash queries with sorting, filtering, and pagination

  ## Quick Start

  Add Cinder to your Phoenix LiveView templates:

      <Cinder.Table.table resource={MyApp.User} current_user={@current_user}>
        <:col field="name" filter sort>Name</:col>
        <:col field="email" filter>Email</:col>
        <:col field="created_at" sort>Created</:col>
      </Cinder.Table.table>

  ## Advanced Usage

      <Cinder.Table.table
        resource={MyApp.Album}
        current_user={@current_user}
        url_state={@url_state}
        page_size={50}
        theme="modern"
      >
        <:col field="title" filter sort class="w-1/2">
          Title
        </:col>
        <:col field="artist.name" filter sort>
          Artist
        </:col>
        <:col field="release_date" filter={:date_range} sort>
          Released
        </:col>
        <:col field="status" filter={:select} sort>
          Status
        </:col>
        <:col field="actions" class="text-center">
          <.link navigate={~p"/albums/\#{album.id}"}>View</.link>
        </:col>
      </Cinder.Table.table>

  ## Key Features

  * **Intelligent Defaults** - Automatic type inference from Ash resources
  * **Ash Integration** - Native support for Ash resources with actor authorization
  * **URL State Management** - Browser back/forward support with automatic URL synchronization
  * **Modular Filtering** - Six filter types with automatic detection
  * **Interactive Sorting** - Click column headers to sort with visual feedback
  * **Relationship Support** - Dot notation for related fields (e.g., `artist.name`)
  * **Flexible Theming** - Built-in presets (default, modern, minimal) and full customization
  * **Responsive Design** - Mobile-friendly with configurable CSS classes
  * **Async Data Loading** - Non-blocking data fetching with loading states

  ## Filter Types

  Cinder automatically detects the appropriate filter type based on your Ash resource attributes:

  * **Text** - For string fields
  * **Select** - For enum fields with options
  * **Multi-select** - For multi-value selections
  * **Boolean** - For true/false fields
  * **Date Range** - For date/datetime fields
  * **Number Range** - For integer/decimal fields

  ## Relationship Support

  Use dot notation to display and filter by related fields:

      <:col field="artist.name" filter sort>Artist</:col>
      <:col field="publisher.country" filter>Country</:col>

  ## Theming

  Choose from built-in themes or create custom styling:

      # Built-in themes
      <Cinder.Table.table theme="modern" ...>
      <Cinder.Table.table theme="minimal" ...>

      # Custom theme
      <Cinder.Table.table theme={%{
        table_class: "custom-table",
        header_class: "custom-header"
      }} ...>

  ## URL State Management

  Enable automatic URL synchronization to preserve table state:

      <Cinder.Table.table url_sync ...>

  This keeps filters, sorting, and pagination in the URL, enabling:
  * Browser back/forward navigation
  * Bookmarkable filtered views
  * Shareable links with current state

  ## Configuration

  Cinder requires minimal configuration:

  * `resource` - Your Ash resource (required)
  * `current_user` - For authorization (required)
  * `url_sync` - Enable URL state management (optional)
  * `page_size` - Items per page (default: 25)
  * `theme` - Styling preset or custom theme (optional)

  Column configuration is equally simple:

      <:col field="field_name" filter sort>Label</:col>

  * `field` - Ash resource attribute name (required)
  * `filter` - Enable filtering (optional)
  * `sort` - Enable sorting (optional)
  * `label` - Override auto-generated label (optional)

  ## Architecture

  Cinder 2.0 features a modular architecture with focused, testable components:

  * **Theme System** - Centralized styling with smart defaults
  * **URL Manager** - State serialization and browser integration
  * **Query Builder** - Ash query construction and optimization
  * **Column System** - Intelligent type inference and configuration
  * **Filter Registry** - Pluggable filter types with consistent interface
  * **Table Component** - Lightweight coordinator that orchestrates all systems

  This modular design enables easy extension and customization while maintaining
  simplicity for common use cases.
  """
end
