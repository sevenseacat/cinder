defmodule Cinder.Components.Grid do
  @moduledoc """
  Theme properties for the Grid component.

  This module defines all the theme properties that can be customized
  for grid/card layouts including the responsive grid container and
  card-like item styling.

  Sort controls use the same theme keys as List (`sort_container_class`, etc.)
  since they render identically in both layouts.
  """

  @theme_properties [
    # Grid container (base styling - grid-cols are added by grid_columns attribute)
    :grid_container_class,

    # Grid item styling
    :grid_item_class,
    :grid_item_clickable_class
  ]

  @doc """
  Returns all theme properties available for the grid component.
  """
  def theme_properties, do: @theme_properties

  @doc """
  Returns the default theme values for grid properties.
  """
  def default_theme do
    %{
      # Grid container base styling (grid-cols classes added via grid_columns attribute)
      grid_container_class: "grid gap-4",

      # Grid item styling - card-like appearance
      grid_item_class: "p-4 bg-white border border-gray-200 rounded-lg shadow-sm",
      grid_item_clickable_class: "cursor-pointer hover:shadow-md transition-shadow"
    }
  end

  @doc """
  Validates that a theme property key is valid for this component.
  """
  def valid_property?(key) when is_atom(key) do
    key in @theme_properties
  end

  def valid_property?(_), do: false
end
