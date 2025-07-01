defmodule Cinder.Components.Cards do
  @moduledoc """
  Theme properties for the cards component.

  This module defines all the theme properties that can be customized
  for the cards layout, including the container, cards grid, individual cards,
  and states like loading and empty.
  """

  @theme_properties [
    # Container and wrapper
    :container_class,
    :controls_class,
    :cards_wrapper_class,

    # Cards grid layout
    :cards_grid_class,
    :card_class,

    # Sort controls
    :sort_controls_class,
    :sort_controls_container_class,
    :sort_label_class,
    :sort_buttons_class,
    :sort_button_class,
    :sort_button_active_class,

    # Sort indicators (reused from existing Sorting component)
    :sort_indicator_class,
    :sort_arrow_wrapper_class,
    :sort_asc_icon_name,
    :sort_asc_icon_class,
    :sort_desc_icon_name,
    :sort_desc_icon_class,
    :sort_none_icon_name,
    :sort_none_icon_class,

    # States
    :loading_class,
    :loading_overlay_class,
    :loading_spinner_class,
    :empty_class,
    :error_container_class,
    :error_message_class,

    # Pagination (reused from table)
    :pagination_wrapper_class
  ]

  @doc """
  Returns all theme properties available for the cards component.
  """
  def theme_properties, do: @theme_properties

  @doc """
  Returns the default theme values for cards properties.
  Provides responsive grid layout and basic card styling.
  """
  def default_theme do
    %{
      container_class: "",
      controls_class: "mb-4",
      cards_wrapper_class: "",
      cards_grid_class: "grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4",
      card_class: "border rounded-lg p-4 hover:shadow-md transition-shadow",

      # Sort controls
      sort_controls_class: "mb-4 pb-4 border-b border-gray-200",
      sort_controls_container_class: "flex items-center space-x-4",
      sort_label_class: "text-sm font-medium text-gray-700",
      sort_buttons_class: "flex flex-wrap gap-2",
      sort_button_class:
        "px-3 py-1 text-sm border border-gray-300 rounded hover:bg-gray-50 transition-colors cursor-pointer select-none",
      sort_button_active_class: "bg-blue-50 border-blue-300 text-blue-700",

      # Sort indicators
      sort_indicator_class: "ml-1 inline-flex items-center align-baseline",
      sort_arrow_wrapper_class: "inline-flex items-center",
      sort_asc_icon_name: "hero-chevron-up",
      sort_asc_icon_class: "w-3 h-3 text-blue-600",
      sort_desc_icon_name: "hero-chevron-down",
      sort_desc_icon_class: "w-3 h-3 text-blue-600",
      sort_none_icon_name: "hero-chevron-up-down",
      sort_none_icon_class: "w-3 h-3 text-gray-400 opacity-50",
      loading_class: "text-center py-4",
      loading_overlay_class:
        "absolute inset-0 bg-white bg-opacity-75 flex items-center justify-center",
      loading_spinner_class: "text-gray-600",
      empty_class: "text-center py-8 text-gray-500",
      error_container_class: "text-red-600 text-sm",
      error_message_class: "",
      pagination_wrapper_class: "mt-6"
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
