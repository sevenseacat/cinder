defmodule Cinder.Theme do
  @moduledoc """
  Theme management for Cinder table components.

  Provides default themes and utilities for merging custom theme configurations.
  """

  @type theme :: %{atom() => String.t()}

  @doc """
  Returns the default theme configuration.
  """
  def default do
    %{
      container_class: "cinder-table-container",
      controls_class: "cinder-table-controls mb-4",
      table_wrapper_class: "cinder-table-wrapper overflow-x-auto",
      table_class: "cinder-table w-full border-collapse",
      thead_class: "cinder-table-head",
      tbody_class: "cinder-table-body",
      header_row_class: "cinder-table-header-row",
      row_class: "cinder-table-row border-b",
      th_class: "cinder-table-th px-4 py-2 text-left font-medium border-b",
      td_class: "cinder-table-td px-4 py-2",
      sort_indicator_class: "cinder-sort-indicator ml-1",
      loading_class: "cinder-table-loading text-center py-8 text-gray-500",
      empty_class: "cinder-table-empty text-center py-8 text-gray-500",
      pagination_wrapper_class: "cinder-pagination-wrapper mt-4",
      pagination_container_class: "cinder-pagination-container flex items-center justify-between",
      pagination_button_class:
        "cinder-pagination-button px-3 py-1 border rounded hover:bg-gray-100",
      pagination_info_class: "cinder-pagination-info text-sm text-gray-600",
      pagination_count_class: "cinder-pagination-count text-xs text-gray-500",
      # Sort icon customization
      sort_arrow_wrapper_class: "inline-block ml-1",
      sort_asc_icon_name: "hero-chevron-up",
      sort_asc_icon_class: "w-3 h-3 inline-block",
      sort_desc_icon_name: "hero-chevron-down",
      sort_desc_icon_class: "w-3 h-3 inline-block",
      sort_none_icon_name: "hero-chevron-up-down",
      sort_none_icon_class: "w-3 h-3 inline-block opacity-30",
      # Filter customization
      filter_container_class: "cinder-filter-container border rounded-lg p-4 mb-4 bg-gray-50",
      filter_header_class: "cinder-filter-header flex items-center justify-between mb-3",
      filter_title_class: "cinder-filter-title text-sm font-medium text-gray-700",
      filter_count_class: "cinder-filter-count text-xs text-gray-500",
      filter_clear_all_class:
        "cinder-filter-clear-all text-xs text-blue-600 hover:text-blue-800 underline",
      filter_inputs_class:
        "cinder-filter-inputs grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4",
      filter_input_wrapper_class: "cinder-filter-input-wrapper",
      filter_label_class: "cinder-filter-label block text-sm font-medium text-gray-700 mb-1",
      filter_placeholder_class:
        "cinder-filter-placeholder text-xs text-gray-400 italic p-2 border rounded",
      filter_text_input_class:
        "w-full px-3 py-2 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500",
      filter_date_input_class:
        "w-full px-3 py-2 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500",
      filter_number_input_class:
        "w-full px-3 py-2 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500",
      filter_select_input_class:
        "cinder-filter-select-input w-full px-3 py-2 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500",
      filter_clear_button_class:
        "cinder-filter-clear-button text-gray-400 hover:text-gray-600 text-sm font-medium px-2 py-1 rounded hover:bg-gray-100",
      # Boolean filter styling
      filter_boolean_container_class: "cinder-filter-boolean-container flex space-x-4",
      filter_boolean_option_class: "cinder-filter-boolean-option flex items-center",
      filter_boolean_radio_class: "cinder-filter-boolean-radio mr-1",
      filter_boolean_label_class: "cinder-filter-boolean-label text-sm",
      # Multi-select filter styling
      filter_multiselect_container_class: "cinder-filter-multiselect-container space-y-2",
      filter_multiselect_option_class:
        "cinder-filter-multiselect-option flex items-center space-x-2",
      filter_multiselect_checkbox_class: "cinder-filter-multiselect-checkbox mr-2",
      filter_multiselect_label_class: "cinder-filter-multiselect-label text-sm",
      # Range filter styling (date and number)
      filter_range_container_class: "cinder-filter-range-container flex space-x-2",
      filter_range_input_group_class: "cinder-filter-range-input-group flex-1",
      # Loading indicator styling
      loading_overlay_class: "cinder-loading-overlay absolute top-0 right-0 mt-2 mr-2",
      loading_container_class: "cinder-loading-container flex items-center text-sm text-gray-500",
      loading_spinner_class:
        "cinder-loading-spinner animate-spin -ml-1 mr-2 h-4 w-4 text-gray-500",
      loading_spinner_circle_class: "cinder-loading-spinner-circle opacity-25",
      loading_spinner_path_class: "cinder-loading-spinner-path opacity-75",
      # Error message styling
      error_container_class: "cinder-error-container text-red-600 text-sm mt-1",
      error_message_class: "cinder-error-message"
    }
  end

  @doc """
  Returns a modern theme with updated styling.
  """
  def modern do
    default()
    |> Map.merge(%{
      container_class: "cinder-table-container bg-white shadow-sm rounded-lg",
      table_wrapper_class: "cinder-table-wrapper overflow-x-auto rounded-lg",
      table_class: "cinder-table w-full border-collapse bg-white",
      th_class:
        "cinder-table-th px-6 py-4 text-left font-semibold text-gray-900 bg-gray-50 border-b border-gray-200",
      td_class: "cinder-table-td px-6 py-4 text-gray-900",
      row_class: "cinder-table-row border-b border-gray-100 hover:bg-gray-50 transition-colors",
      pagination_button_class:
        "cinder-pagination-button px-4 py-2 border border-gray-300 rounded-md hover:bg-gray-50 transition-colors font-medium",
      filter_container_class:
        "cinder-filter-container border border-gray-200 rounded-lg p-6 mb-6 bg-white shadow-sm",
      # Modern filter styling
      filter_boolean_container_class: "cinder-filter-boolean-container flex space-x-6",
      filter_boolean_option_class: "cinder-filter-boolean-option flex items-center space-x-2",
      filter_boolean_radio_class:
        "cinder-filter-boolean-radio h-4 w-4 text-blue-600 focus:ring-blue-500",
      filter_boolean_label_class: "cinder-filter-boolean-label text-sm font-medium text-gray-700",
      filter_multiselect_container_class: "cinder-filter-multiselect-container space-y-3",
      filter_multiselect_option_class:
        "cinder-filter-multiselect-option flex items-center space-x-3",
      filter_multiselect_checkbox_class:
        "cinder-filter-multiselect-checkbox h-4 w-4 text-blue-600 focus:ring-blue-500 rounded",
      filter_multiselect_label_class:
        "cinder-filter-multiselect-label text-sm font-medium text-gray-700",
      loading_container_class:
        "cinder-loading-container flex items-center text-sm text-blue-600 font-medium"
    })
  end

  @doc """
  Returns a minimal theme with reduced styling.
  """
  def minimal do
    default()
    |> Map.merge(%{
      container_class: "cinder-table-container",
      controls_class: "cinder-table-controls mb-2",
      table_wrapper_class: "cinder-table-wrapper",
      table_class: "cinder-table w-full",
      th_class: "cinder-table-th px-2 py-1 text-left font-medium",
      td_class: "cinder-table-td px-2 py-1",
      row_class: "cinder-table-row",
      pagination_button_class: "cinder-pagination-button px-2 py-1 hover:underline",
      filter_container_class: "cinder-filter-container p-2 mb-2",
      # Minimal filter styling
      filter_boolean_container_class: "cinder-filter-boolean-container flex space-x-2",
      filter_boolean_option_class: "cinder-filter-boolean-option flex items-center",
      filter_boolean_radio_class: "cinder-filter-boolean-radio mr-1",
      filter_boolean_label_class: "cinder-filter-boolean-label text-xs",
      filter_multiselect_container_class: "cinder-filter-multiselect-container space-y-1",
      filter_multiselect_option_class:
        "cinder-filter-multiselect-option flex items-center space-x-1",
      filter_multiselect_checkbox_class: "cinder-filter-multiselect-checkbox mr-1",
      filter_multiselect_label_class: "cinder-filter-multiselect-label text-xs",
      filter_range_container_class: "cinder-filter-range-container flex space-x-1",
      loading_overlay_class: "cinder-loading-overlay absolute top-0 right-0 m-1",
      loading_container_class: "cinder-loading-container flex items-center text-xs text-gray-400"
    })
  end

  @doc """
  Merges a custom theme configuration with the default theme.

  ## Examples

      iex> Cinder.Theme.merge(%{container_class: "my-custom-class"})
      %{container_class: "my-custom-class", ...}

      iex> Cinder.Theme.merge("modern")
      %{container_class: "cinder-table-container bg-white shadow-sm rounded-lg", ...}

  """
  def merge(theme_config)

  def merge(theme_config) when is_map(theme_config) do
    default()
    |> Map.merge(theme_config)
  end

  def merge("default"), do: default()
  def merge("modern"), do: modern()
  def merge("minimal"), do: minimal()
  def merge(nil), do: default()

  def merge(theme_name) when is_binary(theme_name) do
    raise ArgumentError,
          "Unknown theme preset: #{theme_name}. Available presets: default, modern, minimal"
  end

  def merge(theme_config) do
    raise ArgumentError, "Theme must be a map or string, got: #{inspect(theme_config)}"
  end

  @doc """
  Returns a list of available theme presets.
  """
  def presets do
    ["default", "modern", "minimal"]
  end
end
