defmodule Cinder.Components.Grid do
  @moduledoc """
  Default theme configuration for the Grid component.

  These defaults provide styling for grid/card layouts including:
  - Responsive grid container with gap
  - Card-like item styling

  Sort controls use the same theme keys as List (`sort_container_class`, etc.)
  since they render identically in both layouts.
  """

  @doc """
  Returns the default theme map for Grid components.
  """
  def default_theme do
    %{
      # Grid container - responsive grid with gap
      grid_container_class: "grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4",

      # Grid item styling - card-like appearance
      grid_item_class: "p-4 bg-white border border-gray-200 rounded-lg shadow-sm",
      grid_item_clickable_class: "cursor-pointer hover:shadow-md transition-shadow"
    }
  end
end
