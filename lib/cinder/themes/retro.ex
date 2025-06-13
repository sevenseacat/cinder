defmodule Cinder.Themes.Retro do
  @moduledoc """
  A retro 80s-inspired theme with neon colors and bold styling.

  Features:
  - Dark backgrounds with neon accent colors
  - Bright cyan, magenta, and yellow highlights
  - Bold typography with strong contrast
  - Glowing effects and sharp corners
  - Classic 80s color palette
  """

  use Cinder.Theme

  component Cinder.Components.Table do
    set :container_class, "bg-gray-900 border-2 border-cyan-400 shadow-2xl shadow-cyan-400/20"

    set :controls_class,
        "p-6 bg-gradient-to-r from-purple-900 to-pink-900 border-b-2 border-cyan-400"

    set :table_wrapper_class, "overflow-x-auto bg-black"
    set :table_class, "w-full border-collapse"
    set :thead_class, "bg-gradient-to-r from-cyan-600 to-purple-600"
    set :tbody_class, "divide-y divide-cyan-400/30"
    set :header_row_class, ""

    set :row_class,
        "hover:bg-gradient-to-r hover:from-purple-900/50 hover:to-pink-900/50 transition-all duration-300"

    set :th_class,
        "px-6 py-4 text-left text-sm font-bold text-cyan-100 tracking-widest uppercase whitespace-nowrap border-b-2 border-cyan-400"

    set :td_class, "px-6 py-4 text-sm text-cyan-100 font-medium"
    set :loading_class, "text-center py-12 text-cyan-400 font-bold uppercase tracking-wide"
    set :empty_class, "text-center py-12 text-magenta-400 italic font-bold"

    set :error_container_class,
        "bg-red-900 border-2 border-red-400 p-4 text-red-100 shadow-lg shadow-red-400/30"

    set :error_message_class, "text-sm font-bold"
  end

  component Cinder.Components.Filters do
    set :filter_container_class,
        "bg-gray-900 border-2 border-magenta-400 p-6 mb-6 shadow-2xl shadow-magenta-400/20"

    set :filter_header_class,
        "flex items-center justify-between mb-4 pb-3 border-b-2 border-cyan-400"

    set :filter_title_class, "text-xl font-bold text-cyan-100 uppercase tracking-widest"

    set :filter_count_class,
        "text-sm text-black bg-yellow-400 px-3 py-1 font-bold uppercase tracking-wide"

    set :filter_clear_all_class,
        "text-sm text-magenta-400 hover:text-magenta-300 font-bold uppercase tracking-wide transition-colors border border-magenta-400 hover:border-magenta-300 px-3 py-1"

    set :filter_inputs_class, "grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6"
    set :filter_input_wrapper_class, "space-y-3"
    set :filter_label_class, "block text-sm font-bold text-cyan-100 uppercase tracking-wide"

    set :filter_placeholder_class,
        "text-sm text-gray-400 italic p-3 border-2 border-purple-600 bg-gray-800 font-bold"

    set :filter_clear_button_class,
        "text-yellow-400 hover:text-yellow-300 transition-colors duration-200 ml-2 font-bold"

    # Input styling
    set :filter_text_input_class,
        "w-full px-4 py-3 border-2 border-cyan-400 bg-gray-800 text-cyan-100 text-sm focus:outline-none focus:border-magenta-400 focus:shadow-lg focus:shadow-magenta-400/30 transition-all duration-200 font-bold placeholder-gray-500"

    set :filter_date_input_class,
        "w-full px-4 py-3 border-2 border-cyan-400 bg-gray-800 text-cyan-100 text-sm focus:outline-none focus:border-magenta-400 focus:shadow-lg focus:shadow-magenta-400/30 transition-all duration-200 font-bold"

    set :filter_number_input_class,
        "w-full px-4 py-3 border-2 border-cyan-400 bg-gray-800 text-cyan-100 text-sm focus:outline-none focus:border-magenta-400 focus:shadow-lg focus:shadow-magenta-400/30 transition-all duration-200 font-bold"

    set :filter_select_input_class,
        "w-full px-4 py-3 border-2 border-cyan-400 bg-gray-800 text-cyan-100 text-sm focus:outline-none focus:border-magenta-400 focus:shadow-lg focus:shadow-magenta-400/30 transition-all duration-200 font-bold"

    # Boolean filter
    set :filter_boolean_container_class, "flex space-x-8"
    set :filter_boolean_option_class, "flex items-center space-x-3"

    set :filter_boolean_radio_class,
        "h-5 w-5 text-magenta-400 focus:ring-magenta-400 focus:ring-2 border-2 border-cyan-400"

    set :filter_boolean_label_class,
        "text-sm font-bold text-cyan-100 cursor-pointer uppercase tracking-wide"

    # Multi-select filter
    set :filter_multiselect_container_class, "space-y-4"
    set :filter_multiselect_option_class, "flex items-center space-x-3"

    set :filter_multiselect_checkbox_class,
        "h-5 w-5 text-magenta-400 focus:ring-magenta-400 focus:ring-2 border-2 border-cyan-400 bg-gray-800"

    set :filter_multiselect_label_class,
        "text-sm font-bold text-cyan-100 cursor-pointer uppercase tracking-wide"

    # Range filters
    set :filter_range_container_class, "flex space-x-3"
    set :filter_range_input_group_class, "flex-1"
  end

  component Cinder.Components.Pagination do
    set :pagination_wrapper_class,
        "bg-gray-900 border-2 border-cyan-400 p-6 mt-6 shadow-2xl shadow-cyan-400/20 bg-gradient-to-r from-purple-900/50 to-pink-900/50"

    set :pagination_container_class, "flex items-center justify-between"

    set :pagination_button_class,
        "px-6 py-3 text-sm font-bold text-cyan-100 bg-gray-800 border-2 border-cyan-400 hover:bg-magenta-800 hover:border-magenta-400 hover:shadow-lg hover:shadow-magenta-400/30 focus:outline-none focus:ring-2 focus:ring-yellow-400 transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed uppercase tracking-wide"

    set :pagination_info_class, "text-sm text-cyan-100 font-bold uppercase tracking-wide"
    set :pagination_count_class, "text-xs text-yellow-400 ml-2 font-bold uppercase"
  end

  component Cinder.Components.Sorting do
    set :sort_indicator_class, "ml-2 inline-flex items-center"
    set :sort_arrow_wrapper_class, "inline-flex items-center ml-1"
    set :sort_asc_icon_class, "w-4 h-4 text-cyan-400 drop-shadow-lg"
    set :sort_desc_icon_class, "w-4 h-4 text-magenta-400 drop-shadow-lg"
    set :sort_none_icon_class, "w-4 h-4 text-gray-500 opacity-50"
  end

  component Cinder.Components.Loading do
    set :loading_overlay_class, "absolute top-4 right-4"

    set :loading_container_class,
        "flex items-center text-sm text-cyan-400 font-bold uppercase tracking-wide"

    set :loading_spinner_class, "animate-spin h-5 w-5 text-cyan-400 mr-2 drop-shadow-lg"
    set :loading_spinner_circle_class, "opacity-25"
    set :loading_spinner_path_class, "opacity-75"
  end
end
