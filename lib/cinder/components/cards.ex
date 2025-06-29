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
      loading_class: "text-center py-4",
      loading_overlay_class: "absolute inset-0 bg-white bg-opacity-75 flex items-center justify-center",
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