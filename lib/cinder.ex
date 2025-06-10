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
       >
         <:col :let={album} key="title" label="Title" sortable>
           {album.title}
         </:col>
       </Cinder.Table.table>
  """
end
