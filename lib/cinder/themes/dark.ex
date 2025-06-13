defmodule Cinder.Themes.Dark do
  @moduledoc """
  An elegant dark theme with smooth gradients and modern styling.

  Features:
  - Rich dark backgrounds with subtle gradients
  - Purple and blue accent colors
  - Smooth hover transitions
  - High contrast for excellent readability
  - Professional dark mode aesthetic
  """

  use Cinder.Theme

  component Cinder.Components.Table do
    set :container_class,
        "bg-gray-900 shadow-2xl rounded-xl border border-gray-700 overflow-hidden"

    set :controls_class,
        "p-6 bg-gradient-to-r from-gray-800 to-gray-900 border-b border-gray-700"

    set :table_wrapper_class, "overflow-x-auto bg-gray-900"
    set :table_class, "w-full border-collapse"
    set :thead_class, "bg-gradient-to-r from-purple-900/30 to-blue-900/30"
    set :tbody_class, "divide-y divide-gray-700"
    set :header_row_class, ""
    set :row_class, "hover:bg-gray-800/50 transition-colors duration-200"

    set :th_class,
        "px-6 py-4 text-left text-sm font-semibold text-gray-200 tracking-wide whitespace-nowrap"

    set :td_class, "px-6 py-4 text-sm text-gray-300"
    set :loading_class, "text-center py-12 text-gray-400"
    set :empty_class, "text-center py-12 text-gray-400 italic"

    set :error_container_class,
        "bg-red-900/50 border border-red-600/50 rounded-lg p-4 text-red-200"

    set :error_message_class, "text-sm"
  end

  component Cinder.Components.Filters do
    set :filter_container_class,
        "bg-gray-800 border border-gray-600 rounded-lg p-6 mb-6 shadow-xl"

    set :filter_header_class,
        "flex items-center justify-between mb-4 pb-3 border-b border-gray-600"

    set :filter_title_class, "text-lg font-semibold text-gray-200"

    set :filter_count_class,
        "text-sm text-gray-900 bg-purple-400 px-3 py-1 rounded-full font-medium"

    set :filter_clear_all_class,
        "text-sm text-purple-400 hover:text-purple-300 font-medium transition-colors"

    set :filter_inputs_class, "grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6"
    set :filter_input_wrapper_class, "space-y-2"
    set :filter_label_class, "block text-sm font-medium text-gray-300"

    set :filter_placeholder_class,
        "text-sm text-gray-500 italic p-3 border border-gray-600 rounded-lg bg-gray-700"

    set :filter_clear_button_class,
        "text-gray-400 hover:text-red-400 transition-colors duration-200 ml-2"

    # Input styling
    set :filter_text_input_class,
        "w-full px-4 py-3 border border-gray-600 rounded-lg text-sm bg-gray-700 text-gray-200 focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-purple-500 transition-all duration-200 placeholder-gray-400"

    set :filter_date_input_class,
        "w-full px-4 py-3 border border-gray-600 rounded-lg text-sm bg-gray-700 text-gray-200 focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-purple-500 transition-all duration-200"

    set :filter_number_input_class,
        "w-full px-4 py-3 border border-gray-600 rounded-lg text-sm bg-gray-700 text-gray-200 focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-purple-500 transition-all duration-200"

    set :filter_select_input_class,
        "w-full px-4 py-3 border border-gray-600 rounded-lg text-sm bg-gray-700 text-gray-200 focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-purple-500 transition-all duration-200"

    # Boolean filter
    set :filter_boolean_container_class, "flex space-x-6"
    set :filter_boolean_option_class, "flex items-center space-x-3"
    set :filter_boolean_radio_class, "h-4 w-4 text-purple-600 focus:ring-purple-500 focus:ring-2"
    set :filter_boolean_label_class, "text-sm font-medium text-gray-300 cursor-pointer"

    # Multi-select filter
    set :filter_multiselect_container_class, "space-y-3"
    set :filter_multiselect_option_class, "flex items-center space-x-3"

    set :filter_multiselect_checkbox_class,
        "h-4 w-4 text-purple-600 focus:ring-purple-500 focus:ring-2 rounded"

    set :filter_multiselect_label_class, "text-sm font-medium text-gray-300 cursor-pointer"

    # Range filters
    set :filter_range_container_class, "flex space-x-3"
    set :filter_range_input_group_class, "flex-1"
  end

  component Cinder.Components.Pagination do
    set :pagination_wrapper_class,
        "bg-gray-800 border border-gray-600 rounded-lg p-6 mt-6 shadow-xl"

    set :pagination_container_class, "flex items-center justify-between"

    set :pagination_button_class,
        "px-4 py-2 text-sm font-medium text-gray-300 bg-gray-800 border border-gray-600 rounded-lg hover:bg-gray-700 hover:border-gray-500 focus:outline-none focus:ring-2 focus:ring-purple-500 transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed"

    set :pagination_info_class, "text-sm text-gray-300 font-medium"
    set :pagination_count_class, "text-xs text-gray-400 ml-2"
  end

  component Cinder.Components.Sorting do
    set :sort_indicator_class, "ml-2 inline-flex items-center"
    set :sort_arrow_wrapper_class, "inline-flex items-center ml-1"
    set :sort_asc_icon_class, "w-4 h-4 text-purple-400"
    set :sort_desc_icon_class, "w-4 h-4 text-purple-400"
    set :sort_none_icon_class, "w-4 h-4 text-gray-500 opacity-50"
  end

  component Cinder.Components.Loading do
    set :loading_overlay_class, "absolute top-4 right-4"
    set :loading_container_class, "flex items-center text-sm text-purple-400 font-medium"
    set :loading_spinner_class, "animate-spin h-5 w-5 text-purple-400 mr-2"
    set :loading_spinner_circle_class, "opacity-25"
    set :loading_spinner_path_class, "opacity-75"
  end
end
