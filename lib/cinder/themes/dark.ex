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
        "bg-gray-800 border border-gray-600 rounded-lg p-6 shadow-xl"

    set :filter_header_class,
        "flex items-center justify-between mb-4 pb-3 border-b border-gray-600"

    set :filter_title_class, "text-lg font-semibold text-gray-200"

    set :filter_count_class,
        "text-sm text-gray-900 bg-purple-400 px-3 py-1 rounded-full font-medium"

    set :filter_clear_all_class,
        "text-sm text-purple-400 hover:text-purple-300 font-medium transition-colors"

    set :filter_inputs_class,
        "flow-root -mb-6"

    set :filter_input_wrapper_class, "space-y-2 float-left mr-6 mb-6"

    set :filter_label_class,
        "block text-sm font-medium text-gray-300 whitespace-nowrap"

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
        "w-20 px-4 py-3 border border-gray-600 rounded-lg text-sm bg-gray-700 text-gray-200 focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-purple-500 transition-all duration-200 [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none [-moz-appearance:textfield]"

    set :filter_select_input_class,
        "w-full px-4 py-3 border border-gray-600 rounded-lg text-sm bg-gray-700 text-gray-200 focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-purple-500 transition-all duration-200"

    # Boolean filter
    set :filter_boolean_container_class, "flex space-x-6 h-[42px] items-center"
    set :filter_boolean_option_class, "flex items-center space-x-2"
    set :filter_boolean_radio_class, "h-4 w-4 text-purple-400 focus:ring-purple-500 focus:ring-2"
    set :filter_boolean_label_class, "text-sm font-medium text-gray-300 cursor-pointer"

    # Multi-select filter (dropdown interface)
    set :filter_multiselect_container_class, "relative"

    set :filter_multiselect_dropdown_class,
        "absolute z-50 w-full mt-1 bg-gray-800 border border-gray-600 rounded-lg shadow-xl max-h-60 overflow-auto"

    set :filter_multiselect_option_class,
        "px-3 py-2 hover:bg-purple-900/50 border-b border-gray-700 last:border-b-0 cursor-pointer"

    set :filter_multiselect_checkbox_class,
        "h-4 w-4 text-purple-400 focus:ring-purple-500 focus:ring-2 rounded mr-2"

    set :filter_multiselect_label_class,
        "text-sm font-medium text-gray-300 cursor-pointer select-none flex-1"

    set :filter_multiselect_empty_class, "px-3 py-2 text-gray-400 italic text-sm"

    # Multi-checkboxes filter
    set :filter_multicheckboxes_container_class, "space-y-3"
    set :filter_multicheckboxes_option_class, "flex items-center space-x-3"

    set :filter_multicheckboxes_checkbox_class,
        "h-4 w-4 text-purple-600 focus:ring-purple-500 focus:ring-2 rounded"

    set :filter_multicheckboxes_label_class, "text-sm font-medium text-gray-300 cursor-pointer"

    # Range filters
    set :filter_range_container_class, "flex items-center space-x-2"
    set :filter_range_input_group_class, ""
    set :filter_range_separator_class, "flex items-center px-1 text-sm font-medium text-gray-400"
  end

  component Cinder.Components.Pagination do
    set :pagination_wrapper_class, "p-6 mt-4"
    set :pagination_container_class, "flex items-center justify-between"

    set :pagination_info_class, "text-sm text-gray-300 font-medium"
    set :pagination_count_class, "text-xs text-gray-400 ml-2"

    set :pagination_nav_class, "flex items-center space-x-1"

    set :pagination_button_class,
        "px-3 py-1 text-sm font-medium text-gray-300 bg-gray-800 border border-gray-600 rounded hover:bg-gray-700 hover:border-gray-500 focus:outline-none focus:ring-2 focus:ring-purple-500 transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed"

    set :pagination_current_class,
        "px-3 py-1 text-sm font-medium text-white bg-purple-600 border border-purple-600 rounded"
  end

  component Cinder.Components.Cards do
    set :container_class,
        "bg-gray-900 shadow-2xl rounded-xl border border-gray-700 overflow-hidden"

    set :controls_class, "p-6 bg-gradient-to-r from-gray-800 to-gray-900 border-b border-gray-700"
    set :cards_wrapper_class, "p-6 bg-gray-900"
    set :cards_grid_class, "grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6"

    set :card_class,
        "bg-gray-800 border border-gray-600 rounded-lg p-6 shadow-xl hover:shadow-2xl hover:border-purple-500/50 transition-all duration-200 cursor-pointer"

    # Sort controls
    set :sort_controls_class, "px-6 pb-4 border-b border-gray-700"
    set :sort_controls_container_class, "flex items-center space-x-4"
    set :sort_label_class, "text-sm font-semibold text-gray-300"
    set :sort_buttons_class, "flex flex-wrap gap-2"

    set :sort_button_class,
        "px-4 py-2 text-sm font-medium border border-gray-600 rounded-lg bg-gray-800 text-gray-300 hover:bg-purple-900/30 hover:border-purple-500/50 transition-all duration-200 cursor-pointer select-none"

    set :sort_button_active_class,
        "bg-purple-900/50 border-purple-500/50 text-purple-300 shadow-lg"

    # Sort indicators
    set :sort_indicator_class, "ml-2 inline-flex items-center align-baseline"
    set :sort_arrow_wrapper_class, "inline-flex items-center"
    set :sort_asc_icon_name, "hero-chevron-up"
    set :sort_asc_icon_class, "w-3 h-3 text-purple-400"
    set :sort_desc_icon_name, "hero-chevron-down"
    set :sort_desc_icon_class, "w-3 h-3 text-purple-400"
    set :sort_none_icon_name, "hero-chevron-up-down"
    set :sort_none_icon_class, "w-3 h-3 text-gray-500 opacity-50"

    set :loading_class, "text-center py-12 text-gray-400"

    set :loading_overlay_class,
        "absolute inset-0 bg-gray-900 bg-opacity-90 flex items-center justify-center rounded-xl"

    set :loading_spinner_class, "text-purple-400 text-lg font-medium"
    set :empty_class, "text-center py-20 text-gray-400 italic col-span-full"

    set :error_container_class,
        "bg-red-900/50 border border-red-600/50 rounded-lg p-4 text-red-200"

    set :error_message_class, "text-sm"
    set :pagination_wrapper_class, "p-6"
  end

  component Cinder.Components.Sorting do
    set :sort_indicator_class, "ml-1 inline-flex items-center align-baseline"
    set :sort_arrow_wrapper_class, "inline-flex items-center"
    set :sort_asc_icon_class, "w-3 h-3 text-purple-400"
    set :sort_desc_icon_class, "w-3 h-3 text-purple-400"
    set :sort_none_icon_class, "w-3 h-3 text-gray-400 opacity-75"
  end

  component Cinder.Components.Loading do
    set :loading_overlay_class, "absolute top-4 right-4"
    set :loading_container_class, "flex items-center text-sm text-purple-400 font-medium"
    set :loading_spinner_class, "animate-spin h-5 w-5 text-purple-400 mr-2"
    set :loading_spinner_circle_class, "opacity-25"
    set :loading_spinner_path_class, "opacity-75"
  end
end
