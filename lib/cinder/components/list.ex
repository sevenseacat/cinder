defmodule Cinder.Components.List do
  @moduledoc """
  Default theme configuration for the List component.

  These defaults provide styling for list/card layouts including:
  - List container (controls layout via CSS)
  - Sort controls (button group for sorting since no table headers)
  - Item styling
  """

  @doc """
  Returns the default theme map for List components.
  """
  def default_theme do
    %{
      # List container - controls layout (list vs grid is just CSS!)
      list_container_class: "divide-y divide-gray-200",

      # List item styling (minimal - users control via <:item> slot)
      list_item_class: "",
      list_item_clickable_class: "cursor-pointer hover:bg-gray-50 transition-colors",

      # Sort controls (button group for list layouts)
      sort_controls_class: "flex items-center gap-2 p-3 border-b bg-gray-50",
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
end
