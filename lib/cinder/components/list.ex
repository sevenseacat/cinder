defmodule Cinder.Components.List do
  @moduledoc """
  Theme properties for the List component.

  This module defines all the theme properties that can be customized
  for list layouts including the list container, item styling, and
  sort controls (button group for sorting since lists don't have table headers).
  """

  @theme_properties [
    # List container
    :list_container_class,

    # List item styling
    :list_item_class,
    :list_item_clickable_class,

    # Sort controls
    :sort_container_class,
    :sort_controls_class,
    :sort_controls_label_class,
    :sort_buttons_class,
    :sort_button_class,
    :sort_button_active_class,
    :sort_button_inactive_class,
    :sort_icon_class,
    :sort_asc_icon,
    :sort_desc_icon
  ]

  @doc """
  Returns all theme properties available for the list component.
  """
  def theme_properties, do: @theme_properties

  @doc """
  Returns the default theme values for list properties.
  """
  def default_theme do
    %{
      # List container - controls layout (list vs grid is just CSS!)
      list_container_class: "divide-y divide-gray-200",

      # List item styling - sensible defaults for vertical lists
      list_item_class: "py-3 px-4 text-gray-900",
      list_item_clickable_class: "cursor-pointer hover:bg-gray-50 transition-colors",

      # Sort container - card-like panel matching filter styling
      sort_container_class: "bg-white border border-gray-200 rounded-lg shadow-sm mt-4",
      # Sort controls - inner flex layout
      sort_controls_class: "flex items-center gap-2 p-4",
      sort_controls_label_class: "text-sm text-gray-600 font-medium",
      sort_buttons_class: "flex gap-1",
      sort_button_class: "px-3 py-1 text-sm border rounded transition-colors",
      sort_button_active_class: "bg-blue-50 border-blue-300 text-blue-700",
      sort_button_inactive_class: "bg-white border-gray-300 hover:bg-gray-50",
      sort_icon_class: "ml-1",
      sort_asc_icon: "↑",
      sort_desc_icon: "↓"
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
