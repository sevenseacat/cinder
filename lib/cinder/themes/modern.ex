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
    set :filter_container_class, "bg-white border border-gray-200 rounded-lg p-6 shadow-sm"

    set :filter_header_class,
        "flex items-center justify-between mb-4 pb-3 border-b border-gray-100"

    set :filter_title_class, "text-lg font-semibold text-gray-900"
    set :filter_count_class, "text-sm text-blue-600 bg-blue-100 px-2 py-1 rounded-full"

    set :filter_clear_all_class,
        "text-sm text-blue-600 hover:text-blue-800 font-medium transition-colors"

    set :filter_inputs_class,
        "flow-root -mb-6"

    set :filter_input_wrapper_class, "space-y-2 float-left mr-6 mb-6"

    set :filter_label_class,
        "block text-sm font-medium text-gray-700 whitespace-nowrap"

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
        "w-20 px-4 py-3 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-all duration-150 [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none [-moz-appearance:textfield]"

    set :filter_select_input_class,
        "w-full px-4 py-3 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-all duration-150 bg-white"

    # Boolean filter
    set :filter_boolean_container_class, "flex space-x-6 h-[42px] items-center"
    set :filter_boolean_option_class, "flex items-center space-x-2"
    set :filter_boolean_radio_class, "h-4 w-4 text-blue-600 focus:ring-blue-500 focus:ring-2"
    set :filter_boolean_label_class, "text-sm font-medium text-gray-700 cursor-pointer"

    # Multi-select filter (dropdown interface)
    set :filter_multiselect_container_class, "relative"

    set :filter_multiselect_dropdown_class,
        "absolute z-50 w-full mt-1 bg-white border border-gray-300 rounded-lg shadow-lg max-h-60 overflow-auto"

    set :filter_multiselect_option_class,
        "px-3 py-2 hover:bg-blue-50 border-b border-gray-100 last:border-b-0 flex items-center space-x-2 cursor-pointer"

    set :filter_multiselect_checkbox_class,
        "h-4 w-4 text-blue-600 focus:ring-blue-500 focus:ring-2 rounded"

    set :filter_multiselect_label_class,
        "text-sm font-medium text-gray-700 cursor-pointer select-none flex-1"

    set :filter_multiselect_empty_class, "px-4 py-3 text-gray-500 italic text-sm"

    # Multi-checkboxes filter (traditional checkbox interface)
    set :filter_multicheckboxes_container_class, "space-y-3"
    set :filter_multicheckboxes_option_class, "flex items-center space-x-3"

    set :filter_multicheckboxes_checkbox_class,
        "h-4 w-4 text-blue-600 focus:ring-blue-500 focus:ring-2 rounded"

    set :filter_multicheckboxes_label_class, "text-sm font-medium text-gray-700 cursor-pointer"

    # Range filters
    set :filter_range_container_class, "flex items-center space-x-2"
    set :filter_range_input_group_class, ""
    set :filter_range_separator_class, "flex items-center px-2 text-sm font-medium text-gray-500"
  end

  component Cinder.Components.Cards do
    set :container_class, "bg-white shadow-lg rounded-xl border border-gray-100"
    set :controls_class, "p-6 bg-gradient-to-r from-gray-50 to-white"
    set :cards_wrapper_class, "p-6"
    set :cards_grid_class, "grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6"
    
    set :card_class,
        "bg-white border border-gray-200 rounded-lg p-6 shadow-sm hover:shadow-md hover:border-blue-200 transition-all duration-200 cursor-pointer"
    
    # Sort controls
    set :sort_controls_class, "px-6 pb-4 border-b border-gray-200"
    set :sort_controls_container_class, "flex items-center space-x-4"
    set :sort_label_class, "text-sm font-semibold text-gray-700"
    set :sort_buttons_class, "flex flex-wrap gap-2"
    set :sort_button_class, "px-4 py-2 text-sm font-medium border border-gray-300 rounded-lg hover:bg-blue-50 hover:border-blue-300 transition-all duration-150 cursor-pointer select-none"
    set :sort_button_active_class, "bg-blue-50 border-blue-300 text-blue-700 shadow-sm"
    
    # Sort indicators
    set :sort_indicator_class, "ml-2 inline-flex items-center align-baseline"
    set :sort_arrow_wrapper_class, "inline-flex items-center"
    set :sort_asc_icon_name, "hero-chevron-up"
    set :sort_asc_icon_class, "w-3 h-3 text-blue-600"
    set :sort_desc_icon_name, "hero-chevron-down"
    set :sort_desc_icon_class, "w-3 h-3 text-blue-600"
    set :sort_none_icon_name, "hero-chevron-up-down"
    set :sort_none_icon_class, "w-3 h-3 text-gray-400 opacity-50"
    
    set :loading_class, "text-center py-12 text-gray-500"
    set :loading_overlay_class, "absolute inset-0 bg-white bg-opacity-90 flex items-center justify-center rounded-xl"
    set :loading_spinner_class, "text-blue-600 text-lg font-medium"
    set :empty_class, "text-center py-20 text-gray-500 italic col-span-full"
    set :error_container_class, "bg-red-50 border border-red-200 rounded-lg p-4 text-red-700"
    set :error_message_class, "text-sm"
    set :pagination_wrapper_class, "px-6 pb-6"
  end

  component Cinder.Components.Pagination do
    set :pagination_wrapper_class, "p-6 mt-4"
    set :pagination_container_class, "flex items-center justify-between"

    set :pagination_info_class, "text-sm text-gray-600 font-medium"
    set :pagination_count_class, "text-xs text-gray-500 ml-2"

    set :pagination_nav_class, "flex items-center space-x-1"

    set :pagination_button_class,
        "px-3 py-1 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded hover:bg-gray-50 hover:border-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 transition-all duration-150 disabled:opacity-50 disabled:cursor-not-allowed"

    set :pagination_current_class,
        "px-3 py-1 text-sm font-medium text-white bg-blue-600 border border-blue-600 rounded"
  end

  component Cinder.Components.Sorting do
    set :sort_indicator_class, "ml-1 inline-flex items-center align-baseline"
    set :sort_arrow_wrapper_class, "inline-flex items-center"
    set :sort_asc_icon_class, "w-3 h-3 text-blue-600"
    set :sort_desc_icon_class, "w-3 h-3 text-blue-600"
    set :sort_none_icon_class, "w-3 h-3 text-gray-500 opacity-75"
  end

  component Cinder.Components.Loading do
    set :loading_overlay_class, "absolute top-4 right-4"
    set :loading_container_class, "flex items-center text-sm text-blue-600 font-medium"
    set :loading_spinner_class, "animate-spin h-5 w-5 text-blue-600 mr-2"
    set :loading_spinner_circle_class, "opacity-25"
    set :loading_spinner_path_class, "opacity-75"
  end
end
