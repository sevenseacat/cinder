defmodule Cinder.Themes.Vintage do
  @moduledoc """
  A vintage theme with warm browns, classic typography, and timeless design.

  Features:
  - Warm sepia and brown color palette
  - Classic serif-inspired styling
  - Vintage paper-like backgrounds
  - Elegant borders and traditional spacing
  - Nostalgic design elements
  """

  use Cinder.Theme

  component Cinder.Components.Table do
    set :container_class,
        "bg-amber-50 border-2 border-amber-800 shadow-lg overflow-hidden"

    set :controls_class,
        "p-6 bg-gradient-to-r from-amber-100 to-yellow-50 border-b-2 border-amber-700"

    set :table_wrapper_class, "overflow-x-auto bg-amber-50"
    set :table_class, "w-full border-collapse"
    set :thead_class, "bg-gradient-to-r from-amber-200 to-yellow-100"
    set :tbody_class, "divide-y divide-amber-200"
    set :header_row_class, ""

    set :row_class,
        "hover:bg-amber-100/70 transition-colors duration-200 border-b border-amber-200"

    set :th_class,
        "px-6 py-4 text-left text-lg font-bold text-amber-900 tracking-wide whitespace-nowrap border-b-2 border-amber-700"

    set :td_class, "px-6 py-4 text-base text-amber-800"
    set :loading_class, "text-center py-12 text-amber-700 font-medium"
    set :empty_class, "text-center py-12 text-amber-600 italic font-medium"

    set :error_container_class,
        "bg-red-100 border-2 border-red-600 p-4 text-red-800 shadow-md"

    set :error_message_class, "text-base font-medium"
  end

  component Cinder.Components.Filters do
    set :filter_container_class,
        "bg-amber-50 border-2 border-amber-700 p-6 mb-6 shadow-lg"

    set :filter_header_class,
        "flex items-center justify-between mb-4 pb-3 border-b-2 border-amber-600"

    set :filter_title_class, "text-xl font-bold text-amber-900"

    set :filter_count_class,
        "text-sm text-amber-900 bg-yellow-200 px-3 py-1 font-bold border border-amber-600"

    set :filter_clear_all_class,
        "text-base text-amber-700 hover:text-amber-900 font-bold transition-colors border-2 border-amber-600 hover:border-amber-800 px-4 py-2 bg-yellow-100 hover:bg-yellow-200"

    set :filter_inputs_class, "grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6"
    set :filter_input_wrapper_class, "space-y-3"
    set :filter_label_class, "block text-base font-bold text-amber-900"

    set :filter_placeholder_class,
        "text-base text-amber-600 italic p-3 border-2 border-amber-600 bg-yellow-50 font-medium"

    set :filter_clear_button_class,
        "text-amber-600 hover:text-red-700 transition-colors duration-200 ml-2 font-bold"

    # Input styling
    set :filter_text_input_class,
        "w-full px-4 py-3 border-2 border-amber-600 bg-yellow-50 text-amber-900 text-base focus:outline-none focus:border-amber-800 focus:bg-white transition-all duration-200 font-medium placeholder-amber-500"

    set :filter_date_input_class,
        "w-full px-4 py-3 border-2 border-amber-600 bg-yellow-50 text-amber-900 text-base focus:outline-none focus:border-amber-800 focus:bg-white transition-all duration-200 font-medium"

    set :filter_number_input_class,
        "w-full px-4 py-3 border-2 border-amber-600 bg-yellow-50 text-amber-900 text-base focus:outline-none focus:border-amber-800 focus:bg-white transition-all duration-200 font-medium"

    set :filter_select_input_class,
        "w-full px-4 py-3 border-2 border-amber-600 bg-yellow-50 text-amber-900 text-base focus:outline-none focus:border-amber-800 focus:bg-white transition-all duration-200 font-medium"

    # Boolean filter
    set :filter_boolean_container_class, "flex space-x-8"
    set :filter_boolean_option_class, "flex items-center space-x-3"

    set :filter_boolean_radio_class,
        "h-5 w-5 text-amber-700 focus:ring-amber-600 focus:ring-2 border-2 border-amber-600"

    set :filter_boolean_label_class,
        "text-base font-bold text-amber-900 cursor-pointer"

    # Multi-select filter
    set :filter_multiselect_container_class, "space-y-3"
    set :filter_multiselect_option_class, "flex items-center space-x-3"

    set :filter_multiselect_checkbox_class,
        "h-5 w-5 text-amber-700 focus:ring-amber-600 focus:ring-2 border-2 border-amber-600 bg-yellow-50"

    set :filter_multiselect_label_class,
        "text-base font-bold text-amber-900 cursor-pointer"

    # Range filters
    set :filter_range_container_class, "flex space-x-3"
    set :filter_range_input_group_class, "flex-1"
  end

  component Cinder.Components.Pagination do
    set :pagination_wrapper_class,
        "bg-amber-50 border-2 border-amber-700 p-6 mt-6 shadow-lg"

    set :pagination_container_class, "flex items-center justify-between"

    set :pagination_button_class,
        "px-6 py-3 text-base font-bold text-amber-800 bg-yellow-100 border-2 border-amber-600 hover:bg-yellow-200 hover:border-amber-800 focus:outline-none focus:ring-2 focus:ring-amber-600 transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed"

    set :pagination_info_class, "text-base text-amber-800 font-bold"
    set :pagination_count_class, "text-sm text-amber-600 ml-2 font-medium"
  end

  component Cinder.Components.Sorting do
    set :sort_indicator_class, "ml-2 inline-flex items-center"
    set :sort_arrow_wrapper_class, "inline-flex items-center ml-1"
    set :sort_asc_icon_class, "w-5 h-5 text-amber-700"
    set :sort_desc_icon_class, "w-5 h-5 text-amber-700"
    set :sort_none_icon_class, "w-5 h-5 text-amber-500 opacity-60"
  end

  component Cinder.Components.Loading do
    set :loading_overlay_class, "absolute top-4 right-4"
    set :loading_container_class, "flex items-center text-base text-amber-700 font-bold"
    set :loading_spinner_class, "animate-spin h-6 w-6 text-amber-700 mr-2"
    set :loading_spinner_circle_class, "opacity-25"
    set :loading_spinner_path_class, "opacity-75"
  end
end
