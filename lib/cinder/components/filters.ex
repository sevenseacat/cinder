defmodule Cinder.Components.Filters do
  @moduledoc """
  Theme properties for filter components.

  This module defines all the theme properties that can be customized
  for the filter system, including the filter container, inputs, and
  all filter type specific styling.
  """

  @theme_properties [
    # Filter container and structure
    :filter_container_class,
    :filter_header_class,
    :filter_title_class,
    :filter_count_class,
    :filter_clear_all_class,
    :filter_inputs_class,
    :filter_input_wrapper_class,
    :filter_label_class,
    :filter_placeholder_class,
    :filter_clear_button_class,

    # Text filter
    :filter_text_input_class,

    # Date filter
    :filter_date_input_class,

    # Number filter
    :filter_number_input_class,

    # Select filter
    :filter_select_input_class,

    # Select filter (dropdown interface)
    :filter_select_container_class,
    :filter_select_dropdown_class,
    :filter_select_option_class,
    :filter_select_label_class,
    :filter_select_empty_class,

    # Boolean filter
    :filter_boolean_container_class,
    :filter_boolean_option_class,
    :filter_boolean_radio_class,
    :filter_boolean_label_class,

    # Multi-select filter (dropdown interface)
    :filter_multiselect_container_class,
    :filter_multiselect_dropdown_class,
    :filter_multiselect_option_class,
    :filter_multiselect_checkbox_class,
    :filter_multiselect_label_class,
    :filter_multiselect_empty_class,

    # Multi-checkboxes filter
    :filter_multicheckboxes_container_class,
    :filter_multicheckboxes_option_class,
    :filter_multicheckboxes_checkbox_class,
    :filter_multicheckboxes_label_class,

    # Range filters (date and number)
    :filter_range_container_class,
    :filter_range_input_group_class,
    :filter_range_separator_class
  ]

  @doc """
  Returns all theme properties available for filter components.
  """
  def theme_properties, do: @theme_properties

  @doc """
  Returns the default theme values for filter properties.
  Provides only the bare minimum classes needed for usability.
  """
  def default_theme do
    %{
      # Filter container and structure
      filter_container_class: "",
      filter_header_class: "",
      filter_title_class: "",
      filter_count_class: "",
      filter_clear_all_class: "",
      filter_inputs_class: "",
      filter_input_wrapper_class: "",
      filter_label_class: "",
      filter_placeholder_class: "",
      filter_clear_button_class: "",

      # Text filter
      filter_text_input_class: "",

      # Date filter
      filter_date_input_class: "",

      # Number filter
      filter_number_input_class:
        "[&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none [-moz-appearance:textfield]",

      # Select filter
      filter_select_input_class: "",

      # Select filter (dropdown interface)
      filter_select_container_class: "",
      filter_select_dropdown_class: "",
      filter_select_option_class: "",
      filter_select_label_class: "",
      filter_select_empty_class: "",

      # Boolean filter
      filter_boolean_container_class: "",
      filter_boolean_option_class: "",
      filter_boolean_radio_class: "",
      filter_boolean_label_class: "",

      # Multi-select filter (dropdown interface)
      filter_multiselect_container_class: "",
      filter_multiselect_dropdown_class: "",
      filter_multiselect_option_class: "",
      filter_multiselect_checkbox_class: "",
      filter_multiselect_label_class: "",
      filter_multiselect_empty_class: "",

      # Multi-checkboxes filter
      filter_multicheckboxes_container_class: "",
      filter_multicheckboxes_option_class: "",
      filter_multicheckboxes_checkbox_class: "",
      filter_multicheckboxes_label_class: "",

      # Range filters (date and number)
      filter_range_container_class: "",
      filter_range_input_group_class: "",
      filter_range_separator_class: "flex items-center px-2 text-sm text-gray-500"
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
