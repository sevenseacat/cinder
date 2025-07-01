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
        "bg-gradient-to-br from-pink-50 to-purple-50 border border-pink-200 shadow-lg rounded-2xl overflow-hidden"

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
        "bg-red-50 border border-red-200 rounded-xl p-4 text-red-600 shadow-sm"

    set :error_message_class, "text-sm"
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
        "w-full px-4 py-3 border border-purple-200 rounded-xl text-sm bg-white/80 text-gray-700 focus:outline-none focus:ring-2 focus:ring-purple-300 focus:border-purple-400 transition-all duration-200 font-medium shadow-sm"

    set :filter_number_input_class,
        "w-20 px-4 py-3 border border-purple-200 rounded-xl text-sm bg-white/80 text-gray-700 focus:outline-none focus:ring-2 focus:ring-purple-300 focus:border-purple-400 transition-all duration-200 font-medium shadow-sm [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none [-moz-appearance:textfield]"

    set :filter_select_input_class,
        "w-full px-4 py-3 border border-purple-200 rounded-xl text-sm bg-white/80 text-gray-700 focus:outline-none focus:ring-2 focus:ring-purple-300 focus:border-purple-400 transition-all duration-200 font-medium shadow-sm"

    # Boolean filter
    set :filter_boolean_container_class, "flex space-x-6 h-[42px] items-center"
    set :filter_boolean_option_class, "flex items-center space-x-2"

    set :filter_boolean_radio_class,
        "h-4 w-4 text-pink-500 focus:ring-pink-400 focus:ring-2 border border-pink-300"

    set :filter_boolean_label_class,
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
  end

  component Cinder.Components.Cards do
    set :container_class, "bg-gradient-to-br from-blue-50 to-purple-50 shadow-xl rounded-3xl border border-purple-100"
    set :controls_class, "p-6 bg-gradient-to-r from-purple-50 via-pink-50 to-blue-50 rounded-t-3xl border-b border-purple-100"
    set :cards_wrapper_class, "p-6"
    set :cards_grid_class, "grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6"
    
    set :card_class,
        "bg-white/80 backdrop-blur-sm border border-purple-200 rounded-2xl p-6 shadow-lg hover:shadow-xl hover:border-purple-300 hover:scale-105 transition-all duration-300 cursor-pointer"
    
    # Sort controls
    set :sort_controls_class, "px-6 pb-4 border-b border-purple-100"
    set :sort_controls_container_class, "flex items-center space-x-4"
    set :sort_label_class, "text-sm font-semibold text-purple-700"
    set :sort_buttons_class, "flex flex-wrap gap-2"
    set :sort_button_class, "px-4 py-2 text-sm font-medium text-purple-700 bg-white/80 border border-purple-200 rounded-xl hover:bg-purple-50 hover:border-purple-300 transition-all duration-200 cursor-pointer select-none shadow-sm"
    set :sort_button_active_class, "bg-gradient-to-r from-purple-500 to-pink-500 text-white border-purple-500 shadow-md"
    
    # Sort indicators
    set :sort_indicator_class, "ml-2 inline-flex items-center align-baseline"
    set :sort_arrow_wrapper_class, "inline-flex items-center"
    set :sort_asc_icon_name, "hero-chevron-up"
    set :sort_asc_icon_class, "w-3 h-3 text-purple-500"
    set :sort_desc_icon_name, "hero-chevron-down"
    set :sort_desc_icon_class, "w-3 h-3 text-pink-500"
    set :sort_none_icon_name, "hero-chevron-up-down"
    set :sort_none_icon_class, "w-3 h-3 text-gray-500 opacity-75"
    
    set :loading_class, "text-center py-16 text-purple-600 font-medium"
    set :loading_overlay_class, "absolute inset-0 bg-white/80 backdrop-blur-sm flex items-center justify-center rounded-3xl"
    set :loading_spinner_class, "text-purple-500 text-lg font-medium"
    set :empty_class, "text-center py-24 text-gray-500 italic col-span-full bg-white/50 rounded-2xl border-2 border-dashed border-purple-200"
    set :error_container_class, "bg-red-50 border border-red-200 rounded-2xl p-4 text-red-700 shadow-sm"
    set :error_message_class, "text-sm"
    set :pagination_wrapper_class, "p-6"
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
