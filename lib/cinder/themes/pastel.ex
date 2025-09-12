defmodule Cinder.Themes.Pastel do
  @moduledoc """
  A pastel theme with soft colors and gentle styling for a calm, pleasant interface.

  Features:
  - Soft pastel color palette (pinks, blues, purples, greens)
  - Gentle gradients and subtle shadows
  - Rounded corners and smooth transitions
  - Light, airy feeling with plenty of whitespace
  - Soothing design for comfortable viewing
  """

  use Cinder.Theme

  component Cinder.Components.Table do
    set :container_class,
        "bg-gradient-to-br from-pink-50 to-purple-50 border border-pink-200 shadow-lg rounded-2xl"

    set :controls_class,
        "p-6 bg-gradient-to-r from-blue-50 via-purple-50 to-pink-50 border-b border-pink-200"

    set :table_wrapper_class, "overflow-x-auto bg-white/80"
    set :table_class, "w-full border-collapse"
    set :thead_class, "bg-gradient-to-r from-purple-100 to-pink-100"
    set :tbody_class, "divide-y divide-pink-100"
    set :header_row_class, ""

    set :row_class,
        "hover:bg-gradient-to-r hover:from-blue-50/50 hover:to-purple-50/50 transition-all duration-300"

    set :th_class,
        "px-6 py-4 text-left text-sm font-medium text-purple-800 tracking-wide whitespace-nowrap rounded-t-lg"

    set :td_class, "px-6 py-4 text-sm text-gray-700"
    set :loading_class, "text-center py-12 text-purple-600 font-medium"
    set :empty_class, "text-center py-12 text-pink-500 italic font-medium"

    set :error_container_class,
        "bg-pink-50 border border-pink-200 rounded-xl p-4 text-pink-800 shadow-sm"

    set :error_message_class, "text-sm"

    # Bulk action button styling
    set :bulk_action_button_class,
        "px-4 py-2 text-sm font-semibold text-purple-700 bg-white/90 border border-purple-200 rounded-xl hover:bg-purple-50 hover:border-purple-300 focus:outline-none focus:ring-2 focus:ring-purple-300 focus:ring-offset-1 transition-all duration-200 shadow-sm backdrop-blur-sm"

    set :bulk_loading_class, "animate-pulse bg-purple-100/80"
  end

  component Cinder.Components.Filters do
    set :filter_container_class,
        "bg-gradient-to-br from-blue-50 to-green-50 border border-blue-200 rounded-2xl p-6 shadow-lg"

    set :filter_header_class,
        "flex items-center justify-between mb-4 pb-3 border-b border-blue-200"

    set :filter_title_class, "text-lg font-medium text-blue-800"

    set :filter_count_class,
        "text-sm text-purple-700 bg-purple-100 px-3 py-1 rounded-full font-medium shadow-sm"

    set :filter_clear_all_class,
        "text-sm text-pink-600 hover:text-pink-700 font-medium transition-colors bg-pink-100 hover:bg-pink-200 px-3 py-2 rounded-full"

    set :filter_inputs_class,
        "flow-root -mb-6"

    set :filter_input_wrapper_class, "space-y-2 float-left mr-6 mb-6"

    set :filter_label_class,
        "block text-sm font-medium text-purple-700 whitespace-nowrap"

    set :filter_placeholder_class,
        "text-sm text-gray-400 italic p-3 border border-pink-200 rounded-xl bg-pink-50/50 font-medium"

    set :filter_clear_button_class,
        "text-pink-400 hover:text-red-500 transition-colors duration-200 ml-2"

    # Input styling
    set :filter_text_input_class,
        "w-full px-4 py-3 border border-purple-200 rounded-xl text-sm bg-white/80 text-gray-700 focus:outline-none focus:ring-2 focus:ring-purple-300 focus:border-purple-400 transition-all duration-200 font-medium placeholder-purple-400 shadow-sm"

    set :filter_date_input_class,
        "w-40 px-4 py-3 border border-purple-200 rounded-xl text-sm bg-white/80 text-gray-700 focus:outline-none focus:ring-2 focus:ring-purple-300 focus:border-purple-400 transition-all duration-200 font-medium placeholder-purple-400 shadow-sm"

    set :filter_number_input_class,
        "w-20 px-4 py-3 border border-purple-200 rounded-xl text-sm bg-white/80 text-gray-700 focus:outline-none focus:ring-2 focus:ring-purple-300 focus:border-purple-400 transition-all duration-200 font-medium shadow-sm [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none [-moz-appearance:textfield]"

    set :filter_select_input_class,
        "w-48 px-4 py-3 border border-purple-200 rounded-xl text-sm bg-white/80 text-gray-700 focus:outline-none focus:ring-2 focus:ring-purple-300 focus:border-purple-400 transition-all duration-200 font-medium shadow-sm"

    # Select filter (dropdown interface)
    set :filter_select_container_class, "relative"

    set :filter_select_dropdown_class,
        "absolute z-50 w-full mt-1 bg-gradient-to-r from-green-50 to-blue-50 border border-purple-200 rounded-2xl shadow-lg max-h-60 overflow-auto"

    set :filter_select_option_class,
        "px-3 py-2 hover:bg-purple-50 border-b border-purple-200 last:border-b-0 cursor-pointer"

    set :filter_select_label_class,
        "text-sm font-medium text-purple-700 cursor-pointer select-none flex-1"

    set :filter_select_empty_class, "px-3 py-2 text-green-600 italic text-sm"

    # Boolean filter
    set :filter_boolean_container_class, "flex space-x-6 h-[42px] items-center"
    set :filter_boolean_option_class, "flex items-center space-x-2"

    set :filter_boolean_radio_class,
        "h-4 w-4 text-pink-500 focus:ring-pink-400 focus:ring-2 border border-pink-300"

    set :filter_boolean_label_class,
        "text-sm font-medium text-purple-700 cursor-pointer"

    # Checkbox filter
    set :filter_checkbox_container_class, "flex items-center h-[42px]"

    set :filter_checkbox_input_class,
        "h-4 w-4 text-pink-500 focus:ring-pink-400 focus:ring-2 rounded border border-pink-300 mr-2"

    set :filter_checkbox_label_class,
        "text-sm font-medium text-purple-700 cursor-pointer"

    # Multi-select filter (dropdown interface)
    set :filter_multiselect_container_class, "relative"

    set :filter_multiselect_dropdown_class,
        "absolute z-50 w-full mt-1 bg-gradient-to-r from-green-50 to-blue-50 border border-purple-200 rounded-2xl shadow-lg max-h-60 overflow-auto"

    set :filter_multiselect_option_class,
        "px-3 py-2 hover:bg-purple-50 border-b border-purple-200 last:border-b-0 cursor-pointer"

    set :filter_multiselect_checkbox_class,
        "h-4 w-4 text-purple-600 focus:ring-purple-500 focus:ring-2 rounded mr-2"

    set :filter_multiselect_label_class,
        "text-sm font-medium text-purple-700 cursor-pointer select-none flex-1"

    set :filter_multiselect_empty_class, "px-3 py-2 text-green-600 italic text-sm"

    # Multi-checkboxes filter
    set :filter_multicheckboxes_container_class, "space-y-3"
    set :filter_multicheckboxes_option_class, "flex items-center space-x-3"

    set :filter_multicheckboxes_checkbox_class,
        "h-4 w-4 text-pink-500 focus:ring-pink-400 focus:ring-2 rounded border border-pink-300 bg-white/80"

    set :filter_multicheckboxes_label_class,
        "text-sm font-medium text-purple-700 cursor-pointer"

    # Range filters
    set :filter_range_container_class, "flex items-center space-x-2"
    set :filter_range_input_group_class, ""

    set :filter_range_separator_class,
        "flex items-center px-2 text-sm font-medium text-purple-400"
  end

  component Cinder.Components.Pagination do
    set :pagination_wrapper_class, "p-6 mt-4"
    set :pagination_container_class, "flex items-center justify-between"

    set :pagination_info_class, "text-sm text-blue-700 font-medium"
    set :pagination_count_class, "text-xs text-green-600 ml-2"

    set :pagination_nav_class, "flex items-center space-x-1"

    set :pagination_button_class,
        "px-3 py-1 text-sm font-medium text-purple-700 bg-white/80 border border-purple-200 rounded-xl hover:bg-purple-50 hover:border-purple-300 focus:outline-none focus:ring-2 focus:ring-purple-300 transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed shadow-sm"

    set :pagination_current_class,
        "px-3 py-1 text-sm font-medium text-white bg-gradient-to-r from-purple-500 to-pink-500 border border-purple-500 rounded-xl shadow-sm"

    set :page_size_container_class, "flex items-center space-x-2"
    set :page_size_label_class, "text-sm text-blue-700 font-medium"

    set :page_size_dropdown_class,
        "flex items-center px-3 py-1 text-sm font-medium text-purple-700 bg-white/80 border border-purple-200 rounded-xl hover:bg-purple-50 hover:border-purple-300 focus:outline-none focus:ring-2 focus:ring-purple-300 transition-all duration-200 cursor-pointer shadow-sm"

    set :page_size_dropdown_container_class,
        "bg-white border border-purple-200 rounded-xl shadow-lg"

    set :page_size_option_class,
        "w-full text-left px-3 py-2 text-sm font-medium text-purple-700 hover:bg-purple-50 hover:text-purple-800 cursor-pointer"

    set :page_size_selected_class, "bg-gradient-to-r from-purple-100 to-pink-100 text-purple-800"
  end

  component Cinder.Components.Search do
    set :search_container_class, ""
    set :search_wrapper_class, ""

    set :search_input_class,
        "w-full pl-10 px-4 py-3 border border-purple-200 rounded-xl text-sm bg-white/80 text-gray-700 focus:outline-none focus:ring-2 focus:ring-purple-300 focus:border-purple-400 transition-all duration-200 font-medium placeholder-purple-400 shadow-sm"

    set :search_icon_class, "w-4 h-4 text-purple-400"

    set :search_label_class, ""
  end

  component Cinder.Components.Sorting do
    set :sort_indicator_class, "ml-1 inline-flex items-center align-baseline"
    set :sort_arrow_wrapper_class, "inline-flex items-center"
    set :sort_asc_icon_class, "w-3 h-3 text-purple-500"
    set :sort_desc_icon_class, "w-3 h-3 text-pink-500"
    set :sort_none_icon_class, "w-3 h-3 text-gray-500 opacity-75"
  end

  component Cinder.Components.Loading do
    set :loading_overlay_class, "absolute top-4 right-4"
    set :loading_container_class, "flex items-center text-sm text-purple-600 font-medium"
    set :loading_spinner_class, "animate-spin h-5 w-5 text-purple-500 mr-2"
    set :loading_spinner_circle_class, "opacity-25"
    set :loading_spinner_path_class, "opacity-75"
  end
end
