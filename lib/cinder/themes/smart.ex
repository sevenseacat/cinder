defmodule Cinder.Themes.Smart do
  @moduledoc """
  A smart theme for displaying more information to knowledgeable users.

  Similar to the Cinder theme "compact".

  Features:
  - Minimal padding and margins for tight layouts (same as compact theme)
  - No borders, no shadows, no filter labels
  - Perfect for dashboards and data-heavy interfaces
  """

  use Cinder.Theme

  component Cinder.Components.Table do
    set :container_class,
        ""

    set :controls_class,
        "py-2 bg-gray-50 border-b border-gray-300"

    set :table_wrapper_class, "overflow-x-auto"
    set :table_class, "w-full border-collapse"
    set :thead_class, "bg-gray-100"
    set :tbody_class, "divide-y divide-gray-200"
    set :header_row_class, "display: none"

    set :row_class,
        "hover:bg-gray-50 transition-colors duration-100"

    set :th_class,
        "px-3 py-2 text-left text-xs font-semibold text-gray-700 tracking-wider whitespace-nowrap border-b border-gray-300"

    set :td_class, "px-3 py-2 text-sm text-gray-900"
    set :loading_class, "text-center py-6 text-gray-500 text-sm"
    set :empty_class, "text-center py-6 text-gray-500 text-sm italic"

    set :error_container_class,
        "bg-red-50 border border-red-200 p-3 text-red-700 text-sm"

    set :error_message_class, "text-sm"
  end

  component Cinder.Components.Filters do
    set :filter_container_class, ""

    set :filter_header_class, "hidden"

    set :filter_title_class, "hidden"

    set :filter_count_class, "hidden"

    set :filter_clear_all_class, "hidden"

    set :filter_inputs_class,
        "flow-root -mb-3"

    set :filter_input_wrapper_class, "space-y-1 float-left mr-3 mb-3"

    set :filter_label_class, "hidden"

    set :filter_placeholder_class,
        "text-xs text-gray-400 italic p-2 border border-gray-300 bg-gray-50"

    set :filter_clear_button_class,
        "text-gray-400 hover:text-red-500 transition-colors ml-1 text-xs"

    # Input styling
    set :filter_text_input_class,
        "w-full px-2 py-1.5 border border-gray-300 text-sm focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500 transition-all duration-150"

    set :filter_date_input_class,
        "w-32 px-2 py-1.5 border border-gray-300 text-sm focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500 transition-all duration-150"

    set :filter_number_input_class,
        "w-16 px-2 py-1.5 border border-gray-300 text-sm focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500 transition-all duration-150 [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none [-moz-appearance:textfield]"

    set :filter_select_input_class,
        "w-[160px] px-2 py-1.5 border border-gray-300 text-sm focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500 transition-all duration-150 leading-5"

    # Select filter (dropdown interface)
    set :filter_select_container_class, "relative"

    set :filter_select_dropdown_class,
        "absolute z-50 w-full mt-1 bg-white border border-gray-300 rounded shadow-md max-h-48 overflow-auto"

    set :filter_select_option_class,
        "px-2 py-1.5 hover:bg-blue-50 border-b border-gray-100 last:border-b-0 cursor-pointer text-xs"

    set :filter_select_label_class,
        "text-xs font-medium text-gray-700 cursor-pointer select-none flex-1"

    set :filter_select_empty_class, "px-2 py-1.5 text-gray-500 italic text-xs"

    # Boolean filter
    set :filter_boolean_container_class, "flex space-x-4 h-[34px] items-center"
    set :filter_boolean_option_class, "flex items-center space-x-1"
    set :filter_boolean_radio_class, "h-3 w-3 text-blue-600 focus:ring-blue-500 focus:ring-1"
    set :filter_boolean_label_class, "text-xs font-medium text-gray-700 cursor-pointer"

    # Checkbox filter
    set :filter_checkbox_container_class, "flex items-center h-[34px]"

    set :filter_checkbox_input_class,
        "h-3 w-3 text-blue-600 focus:ring-blue-500 focus:ring-1 rounded mr-1"

    set :filter_checkbox_label_class, "text-xs font-medium text-gray-700 cursor-pointer"

    # Multi-select filter (tag-based interface)
    set :filter_multiselect_container_class, "relative"

    set :filter_multiselect_dropdown_class,
        "absolute z-50 w-full mt-1 bg-white border border-gray-300 rounded shadow-md max-h-48 overflow-auto"

    set :filter_multiselect_option_class,
        "px-2 py-1.5 hover:bg-blue-50 border-b border-gray-100 last:border-b-0 cursor-pointer text-xs"

    set :filter_multiselect_checkbox_class,
        "h-3 w-3 text-blue-600 focus:ring-blue-500 focus:ring-1 rounded mr-2"

    set :filter_multiselect_label_class,
        "text-xs font-medium text-gray-700 cursor-pointer select-none flex-1"

    set :filter_multiselect_empty_class, "px-2 py-1.5 text-gray-500 italic text-xs"

    # Multi-checkboxes filter
    set :filter_multicheckboxes_container_class, "space-y-1"
    set :filter_multicheckboxes_option_class, "flex items-center space-x-1"

    set :filter_multicheckboxes_checkbox_class,
        "h-3 w-3 text-blue-600 focus:ring-blue-500 focus:ring-1"

    set :filter_multicheckboxes_label_class, "text-xs font-medium text-gray-700 cursor-pointer"

    # Range filters
    set :filter_range_container_class, "flex items-center space-x-2"
    set :filter_range_input_group_class, ""
    set :filter_range_separator_class, "flex items-center px-1 text-xs font-medium text-gray-500"
  end

  component Cinder.Components.Pagination do
    set :pagination_wrapper_class, "p-3 mt-3"
    set :pagination_container_class, "flex items-center justify-between"

    set :pagination_info_class, "text-xs text-gray-600 font-medium"
    set :pagination_count_class, "text-xs text-gray-500 ml-1"

    set :pagination_nav_class, "flex items-center space-x-0.5"

    set :pagination_button_class,
        "px-2 py-1 text-xs font-medium text-gray-700 bg-white border border-gray-300 hover:bg-gray-50 hover:border-gray-400 focus:outline-none focus:ring-1 focus:ring-blue-500 transition-all duration-150 disabled:opacity-50 disabled:cursor-not-allowed"

    set :pagination_current_class,
        "px-2 py-1 text-xs font-medium text-white bg-blue-600 border border-blue-600"

    set :page_size_container_class, "flex items-center space-x-1"
    set :page_size_label_class, "text-xs text-gray-600 font-medium"

    set :page_size_dropdown_class,
        "flex items-center px-2 py-1 text-xs font-medium text-gray-700 bg-white border border-gray-300 hover:bg-gray-50 hover:border-gray-400 focus:outline-none focus:ring-1 focus:ring-blue-500 transition-all duration-150 cursor-pointer"

    set :page_size_dropdown_container_class, "bg-white border border-gray-300 rounded shadow-lg"

    set :page_size_option_class,
        "w-full text-left px-2 py-1 text-xs text-gray-700 hover:bg-gray-100 hover:text-gray-900 cursor-pointer"

    set :page_size_selected_class, "bg-blue-50 text-blue-700"
  end

  component Cinder.Components.Sorting do
    set :sort_indicator_class, "ml-1 inline-flex items-center align-baseline"
    set :sort_arrow_wrapper_class, "inline-flex items-center"
    set :sort_asc_icon_class, "w-3 h-3 text-blue-600"
    set :sort_desc_icon_class, "w-3 h-3 text-blue-600"
    set :sort_none_icon_class, "w-3 h-3 text-gray-500 opacity-70"
  end

  component Cinder.Components.Search do
    set :search_container_class, ""
    set :search_wrapper_class, ""

    set :search_input_class,
        "w-full pl-8 px-2 py-1.5 border border-gray-300 text-sm focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500 transition-all duration-150"

    set :search_icon_class, "w-3 h-3 text-gray-400"

    set :search_label_class, ""
  end

  component Cinder.Components.Loading do
    set :loading_overlay_class, "absolute top-2 right-2"
    set :loading_container_class, "flex items-center text-xs text-blue-600 font-medium"
    set :loading_spinner_class, "animate-spin h-3 w-3 text-blue-600 mr-1"
    set :loading_spinner_circle_class, "opacity-25"
    set :loading_spinner_path_class, "opacity-75"
  end
end
