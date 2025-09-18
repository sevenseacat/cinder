defmodule Cinder.Components.Table do
  @moduledoc """
  Theme properties for the main table component.

  This module defines all the theme properties that can be customized
  for the table structure itself, including the container, table element,
  headers, rows, and cells.
  """

  @theme_properties [
    # Container and wrapper
    :container_class,
    :controls_class,
    :table_wrapper_class,

    # Table structure
    :table_class,
    :thead_class,
    :tbody_class,
    :header_row_class,
    :row_class,
    :th_class,
    :td_class,

    # States
    :loading_class,
    :empty_class,
    :error_container_class,
    :error_message_class,

    # Bulk action button
    :bulk_action_button_class,
    :bulk_loading_class
  ]

  @doc """
  Returns all theme properties available for the table component.
  """
  def theme_properties, do: @theme_properties

  @doc """
  Returns the default theme values for table properties.
  Provides only the bare minimum classes needed for usability.
  """
  def default_theme do
    %{
      container_class: "",
      controls_class: "",
      table_wrapper_class: "overflow-x-auto",
      table_class: "w-full border-collapse",
      thead_class: "",
      tbody_class: "",
      header_row_class: "",
      row_class: "",
      th_class: "text-left whitespace-nowrap",
      td_class: "",
      loading_class: "text-center py-4",
      empty_class: "text-center py-4",
      error_container_class: "text-red-600 text-sm",
      error_message_class: "",
      bulk_action_button_class:
        "px-3 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500",
      bulk_loading_class: ""
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
