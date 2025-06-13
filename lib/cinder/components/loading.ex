defmodule Cinder.Components.Loading do
  @moduledoc """
  Theme properties for loading components.

  This module defines all the theme properties that can be customized
  for loading indicators, spinners, and loading states throughout
  the table component.
  """

  @theme_properties [
    # Loading overlay and container
    :loading_overlay_class,
    :loading_container_class,

    # Loading spinner
    :loading_spinner_class,
    :loading_spinner_circle_class,
    :loading_spinner_path_class
  ]

  @doc """
  Returns all theme properties available for loading components.
  """
  def theme_properties, do: @theme_properties

  @doc """
  Returns the default theme values for loading properties.
  Provides only the bare minimum classes needed for usability.
  """
  def default_theme do
    %{
      loading_overlay_class: "",
      loading_container_class: "",
      loading_spinner_class: "",
      loading_spinner_circle_class: "",
      loading_spinner_path_class: ""
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
