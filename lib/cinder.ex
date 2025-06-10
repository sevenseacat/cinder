defmodule Cinder do
  @moduledoc """
   Cinder is a library for building interactive LiveView components with Ash Framework.

   ## Components

   * `Cinder.Table` - Interactive data tables for Ash queries with sorting, filtering, and pagination

   ## Usage

   Add Cinder to your Phoenix LiveView templates:

       <Cinder.Table.table
         id="my-table"
         query={MyApp.Album}
         current_user={@current_user}
         query_opts={[load: [:artist, :publisher]]}
         page_size={50}
       >
         <:col :let={album} key="title" label="Title" sortable searchable>
           {album.title}
         </:col>
         
         <:col :let={album} key="artist.name" label="Artist" sortable filterable>
           {album.artist.name}
         </:col>
         
         <:col :let={album} key="publisher" label="Label" sortable sort_fn={&sort_by_publisher/2}>
           {album.publisher.name}
         </:col>
         
         <:col :let={album} key="genre" label="Genre" filterable sortable>
           {album.genre}
         </:col>
       </Cinder.Table.table>

   ## Features

   * **Ash Integration** - Native support for Ash resources with actor authorization
   * **Async Data Loading** - Non-blocking data fetching with loading states
   * **Interactive Sorting** - Click column headers to sort, supports custom sort functions
   * **Pagination** - Built-in pagination with Previous/Next controls
   * **Theming** - Fully customizable CSS classes for all elements
   * **Required Columns** - Compile-time validation ensures all columns have required `key` attribute
   * **Query Options** - Support for Ash query options like load, select, filter
   * **Relationship Sorting** - Dot notation support for sorting by related fields (e.g., "artist.name")
   * **Customizable Sort Icons** - Use any heroicons or custom HTML for sort arrows

   ## Sorting Features

   * **Click-to-sort** - Sortable columns have clickable headers with visual feedback
   * **Three-state cycling** - Click toggles: none → ascending → descending → none
   * **Visual indicators** - Clear SVG arrows show current sort direction
   * **Multi-column support** - Sort by multiple columns simultaneously
   * **Custom sort functions** - Use `sort_fn` attribute for complex sorting logic
   * **Relationship sorting** - Sort by related fields using dot notation
   * **Auto page reset** - Returns to page 1 when sort changes
   * **Customizable arrows** - Use heroicons, custom CSS, or raw HTML for sort indicators

   ## Sort Arrow Customization

   Customize sort arrows using the theme attribute:

       # Use different heroicons
       theme = %{
         sort_asc_icon_name: "hero-arrow-up",
         sort_desc_icon_name: "hero-arrow-down", 
         sort_none_icon_name: "hero-arrows-up-down"
       }

       # Customize icon classes and colors
       theme = %{
         sort_asc_icon_class: "w-4 h-4 text-green-500",
         sort_desc_icon_class: "w-4 h-4 text-red-500",
         sort_none_icon_class: "w-4 h-4 text-gray-400"
       }

   Icons are rendered as `<span class={[icon_name, icon_class]} />` which works
   with Phoenix heroicons when you have heroicons CSS loaded.

   ## Phase Completion Status

   * ✅ Phase 1: Core Component Structure - Complete
   * ✅ Phase 2: Data Loading and Pagination - Complete with full Ash integration
   * ✅ Phase 3: Sorting Implementation - Complete with interactive sorting
   * 🚧 Phase 4: Filtering System - Coming next
  """
end
