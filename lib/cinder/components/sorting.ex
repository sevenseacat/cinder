defmodule Cinder.Components.Sorting do
  @moduledoc """
  Theme properties for sorting components.

  This module defines all the theme properties that can be customized
  for the sorting system, including sort indicators, icons, and
  interactive elements.
  """

  @theme_properties [
    # Sort indicators
    :sort_indicator_class,
    :sort_arrow_wrapper_class,

    # Sort icons
    :sort_asc_icon_name,
    :sort_asc_icon_class,
    :sort_desc_icon_name,
    :sort_desc_icon_class,
    :sort_none_icon_name,
    :sort_none_icon_class
  ]

  @doc """
  Returns all theme properties available for sorting components.
  """
  def theme_properties, do: @theme_properties

  @doc """
  Returns the default theme values for sorting properties.
  Provides only the bare minimum classes needed for usability.
  """
  def default_theme do
    %{
      sort_indicator_class: "ml-1 inline-flex items-center align-baseline",
      sort_arrow_wrapper_class: "inline-flex items-center",
      sort_asc_icon_name: "hero-chevron-up",
      sort_asc_icon_class: "w-3 h-3",
      sort_desc_icon_name: "hero-chevron-down",
      sort_desc_icon_class: "w-3 h-3",
      sort_none_icon_name: "hero-chevron-up-down",
      sort_none_icon_class: "w-3 h-3 opacity-50"
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
