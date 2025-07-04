defmodule Cinder.Components.Pagination do
  @moduledoc """
  Theme properties for pagination components.

  This module defines all the theme properties that can be customized
  for the pagination system, including the pagination wrapper, buttons,
  and info displays.
  """

  @theme_properties [
    # Pagination structure
    :pagination_wrapper_class,
    :pagination_container_class,
    :pagination_button_class,
    :pagination_info_class,
    :pagination_count_class,
    :pagination_controls_class,
    :pagination_nav_class,
    :pagination_current_class,
    :pagination_active_class,
    :pagination_icon_class
  ]

  @doc """
  Returns all theme properties available for pagination components.
  """
  def theme_properties, do: @theme_properties

  @doc """
  Returns the default theme values for pagination properties.
  Provides only the bare minimum classes needed for usability.
  """
  def default_theme do
    %{
      pagination_wrapper_class: "",
      pagination_container_class: "",
      pagination_button_class: "",
      pagination_info_class: "",
      pagination_count_class: "",
      pagination_controls_class: "flex items-center space-x-1",
      pagination_nav_class: "",
      pagination_current_class: "",
      pagination_active_class: "",
      pagination_icon_class: "w-4 h-4"
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
