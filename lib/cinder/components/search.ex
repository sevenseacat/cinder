defmodule Cinder.Components.Search do
  @moduledoc """
  Theme properties for the global search component.

  This module defines all the theme properties that can be customized
  for the search input field, including the wrapper, input field,
  icons, and buttons.
  """

  @theme_properties [
    # Container and wrapper
    :search_container_class,
    :search_wrapper_class,

    # Input field
    :search_input_class,

    # Icons and buttons
    :search_icon_class,

    # Labels and placeholder
    :search_label_class
  ]

  @doc """
  Returns all theme properties available for the search component.
  """
  def theme_properties, do: @theme_properties

  @doc """
  Returns the default theme values for search properties.
  Provides only the bare minimum classes needed for usability.
  """
  def default_theme do
    %{
      search_container_class: "",
      search_wrapper_class: "relative",
      search_input_class: "w-full px-3 py-2 border rounded",
      search_icon_class: "w-4 h-4",
      search_label_class: ""
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
