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
         
         <:col :let={album} key="artist" label="Artist" filterable>
           {album.artist.name}
         </:col>
         
         <:col :let={album} key="genre" label="Genre" filterable sortable>
           {album.genre}
         </:col>
       </Cinder.Table.table>

   ## Features

   * **Ash Integration** - Native support for Ash resources with actor authorization
   * **Async Data Loading** - Non-blocking data fetching with loading states
   * **Pagination** - Built-in pagination with Previous/Next controls
   * **Theming** - Fully customizable CSS classes for all elements
   * **Required Columns** - Compile-time validation ensures all columns have required `key` attribute
   * **Query Options** - Support for Ash query options like load, select, filter

   ## Phase Completion Status

   * ✅ Phase 1: Core Component Structure - Complete
   * ✅ Phase 2: Data Loading and Pagination - Complete with full Ash integration
   * 🚧 Phase 3: Sorting Implementation - Coming next
  """
end
