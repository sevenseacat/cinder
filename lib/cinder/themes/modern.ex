defmodule Cinder.Themes.Modern do
  @moduledoc """
  A modern, professional theme with clean lines and subtle shadows.

  Features:
  - Clean white backgrounds with subtle shadows
  - Professional blue accent colors
  - Smooth hover transitions
  - Well-spaced typography
  - Subtle borders and rounded corners
  """

  use Cinder.Theme

  component Cinder.Components.Table do
    set :container_class, "bg-white shadow-lg rounded-xl border border-gray-100"
    set :controls_class, "p-6 bg-gradient-to-r from-gray-50 to-white"
    set :table_wrapper_class, "overflow-x-auto bg-white"
    set :table_class, "w-full border-collapse"
    set :thead_class, "bg-gradient-to-r from-blue-50 to-indigo-50"
    set :tbody_class, "divide-y divide-gray-100"
    set :header_row_class, ""
    set :row_class, "hover:bg-blue-50/30 transition-colors duration-150"

    set :th_class,
        "px-6 py-4 text-left text-sm font-semibold text-gray-900 tracking-wide whitespace-nowrap"

    set :td_class, "px-6 py-4 text-sm text-gray-700"
    set :loading_class, "text-center py-12 text-gray-500"
    set :empty_class, "text-center py-12 text-gray-500 italic"
    set :error_container_class, "bg-red-50 border border-red-200 rounded-lg p-4 text-red-700"
    set :error_message_class, "text-sm"
  end

  component Cinder.Components.Filters do
    set :filter_container_class, "bg-white border border-gray-200 rounded-lg p-6 mb-6 shadow-sm"

    set :filter_header_class,
        "flex items-center justify-between mb-4 pb-3 border-b border-gray-100"

    set :filter_title_class, "text-lg font-semibold text-gray-900"
    set :filter_count_class, "text-sm text-blue-600 bg-blue-100 px-2 py-1 rounded-full"

    set :filter_clear_all_class,
        "text-sm text-blue-600 hover:text-blue-800 font-medium transition-colors"

    set :filter_inputs_class, "grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6"
    set :filter_input_wrapper_class, "space-y-2"
    set :filter_label_class, "block text-sm font-medium text-gray-700"

    set :filter_placeholder_class,
        "text-sm text-gray-400 italic p-3 border border-gray-200 rounded-lg bg-gray-50"

    set :filter_clear_button_class,
        "text-gray-400 hover:text-red-500 transition-colors duration-150 ml-2"

    # Input styling
    set :filter_text_input_class,
        "w-full px-4 py-3 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-all duration-150"

    set :filter_date_input_class,
        "w-full px-4 py-3 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-all duration-150"

    set :filter_number_input_class,
        "w-full px-4 py-3 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-all duration-150"

    set :filter_select_input_class,
        "w-full px-4 py-3 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-all duration-150 bg-white"

    # Boolean filter
    set :filter_boolean_container_class, "flex space-x-6"
    set :filter_boolean_option_class, "flex items-center space-x-3"
    set :filter_boolean_radio_class, "h-4 w-4 text-blue-600 focus:ring-blue-500 focus:ring-2"
    set :filter_boolean_label_class, "text-sm font-medium text-gray-700 cursor-pointer"

    # Multi-select filter
    set :filter_multiselect_container_class, "space-y-3"
    set :filter_multiselect_option_class, "flex items-center space-x-3"

    set :filter_multiselect_checkbox_class,
        "h-4 w-4 text-blue-600 focus:ring-blue-500 focus:ring-2 rounded"

    set :filter_multiselect_label_class, "text-sm font-medium text-gray-700 cursor-pointer"

    # Range filters
    set :filter_range_container_class, "flex space-x-3"
    set :filter_range_input_group_class, "flex-1"
  end

  component Cinder.Components.Pagination do
    set :pagination_wrapper_class, "bg-white border border-gray-100 rounded-xl p-6 mt-6 shadow-lg"
    set :pagination_container_class, "flex items-center justify-between"

    set :pagination_button_class,
        "px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 hover:border-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 transition-all duration-150 disabled:opacity-50 disabled:cursor-not-allowed"

    set :pagination_info_class, "text-sm text-gray-600 font-medium"
    set :pagination_count_class, "text-xs text-gray-500 ml-2"
  end

  component Cinder.Components.Sorting do
    set :sort_indicator_class, "ml-2 inline-flex items-center"
    set :sort_arrow_wrapper_class, "inline-flex items-center ml-1"
    set :sort_asc_icon_class, "w-4 h-4 text-blue-600"
    set :sort_desc_icon_class, "w-4 h-4 text-blue-600"
    set :sort_none_icon_class, "w-4 h-4 text-gray-400 opacity-50"
  end

  component Cinder.Components.Loading do
    set :loading_overlay_class, "absolute top-4 right-4"
    set :loading_container_class, "flex items-center text-sm text-blue-600 font-medium"
    set :loading_spinner_class, "animate-spin h-5 w-5 text-blue-600 mr-2"
    set :loading_spinner_circle_class, "opacity-25"
    set :loading_spinner_path_class, "opacity-75"
  end
end
