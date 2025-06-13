defmodule Cinder.Themes.Flowbite do
  @moduledoc """
  A Flowbite-compatible theme following Flowbite design system for advanced tables.

  Features:
  - Flowbite table styling with proper borders and spacing
  - Gray color scheme with hover states
  - Professional form inputs with Flowbite styling
  - Button components using Flowbite button classes
  - Consistent spacing and typography matching Flowbite docs
  """

  use Cinder.Theme

  component Cinder.Components.Table do
    set :container_class,
        "relative overflow-hidden bg-white shadow-md dark:bg-gray-800 sm:rounded-lg"

    set :controls_class,
        "flex flex-col md:flex-row items-center justify-between space-y-3 md:space-y-0 md:space-x-4 p-4"

    set :table_wrapper_class, "overflow-x-auto"
    set :table_class, "w-full text-sm text-left text-gray-500 dark:text-gray-400"

    set :thead_class,
        "text-xs text-gray-700 uppercase bg-gray-50 dark:bg-gray-700 dark:text-gray-400"

    set :tbody_class, ""
    set :header_row_class, ""
    set :row_class, "border-b dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-600"
    set :th_class, "px-4 py-3 whitespace-nowrap"
    set :td_class, "px-4 py-3"
    set :loading_class, "text-center py-8 text-gray-500 dark:text-gray-400"
    set :empty_class, "text-center py-8 text-gray-500 dark:text-gray-400"

    set :error_container_class,
        "flex items-center p-4 mb-4 text-sm text-red-800 border border-red-300 rounded-lg bg-red-50 dark:bg-gray-800 dark:text-red-400 dark:border-red-800"

    set :error_message_class, ""
  end

  component Cinder.Components.Filters do
    set :filter_container_class,
        "bg-white dark:bg-gray-800 relative shadow-md rounded-lg mb-4 w-full"

    set :filter_header_class,
        "flex flex-col md:flex-row items-center justify-between space-y-3 md:space-y-0 md:space-x-4 p-4 border-b border-gray-200 dark:border-gray-700"

    set :filter_title_class, "text-lg font-semibold text-gray-900 dark:text-white"

    set :filter_count_class,
        "bg-blue-100 text-blue-800 text-xs font-medium mr-2 px-2.5 py-0.5 rounded dark:bg-blue-900 dark:text-blue-300"

    set :filter_clear_all_class,
        "text-white bg-blue-700 hover:bg-blue-800 focus:ring-4 focus:ring-blue-300 font-medium rounded-lg text-sm px-5 py-2.5 dark:bg-blue-600 dark:hover:bg-blue-700 focus:outline-none dark:focus:ring-blue-800"

    set :filter_inputs_class, "grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 p-4"
    set :filter_input_wrapper_class, "space-y-2"
    set :filter_label_class, "block mb-2 text-sm font-medium text-gray-900 dark:text-white"

    set :filter_placeholder_class,
        "text-sm text-gray-500 dark:text-gray-400 italic p-3 border border-gray-300 rounded-lg bg-gray-50 dark:bg-gray-700 dark:border-gray-600"

    set :filter_clear_button_class,
        "text-gray-400 bg-transparent hover:bg-gray-200 hover:text-gray-900 rounded-lg text-sm p-1.5 ml-auto inline-flex items-center dark:hover:bg-gray-600 dark:hover:text-white"

    # Input styling
    set :filter_text_input_class,
        "bg-gray-50 border border-gray-300 text-gray-900 text-sm rounded-lg focus:ring-blue-500 focus:border-blue-500 block w-full p-2.5 dark:bg-gray-700 dark:border-gray-600 dark:placeholder-gray-400 dark:text-white dark:focus:ring-blue-500 dark:focus:border-blue-500"

    set :filter_date_input_class,
        "bg-gray-50 border border-gray-300 text-gray-900 text-sm rounded-lg focus:ring-blue-500 focus:border-blue-500 block w-full p-2.5 dark:bg-gray-700 dark:border-gray-600 dark:placeholder-gray-400 dark:text-white dark:focus:ring-blue-500 dark:focus:border-blue-500"

    set :filter_number_input_class,
        "bg-gray-50 border border-gray-300 text-gray-900 text-sm rounded-lg focus:ring-blue-500 focus:border-blue-500 block w-full p-2.5 dark:bg-gray-700 dark:border-gray-600 dark:placeholder-gray-400 dark:text-white dark:focus:ring-blue-500 dark:focus:border-blue-500"

    set :filter_select_input_class,
        "bg-gray-50 border border-gray-300 text-gray-900 text-sm rounded-lg focus:ring-blue-500 focus:border-blue-500 block w-full p-2.5 dark:bg-gray-700 dark:border-gray-600 dark:placeholder-gray-400 dark:text-white dark:focus:ring-blue-500 dark:focus:border-blue-500"

    # Boolean filter
    set :filter_boolean_container_class, "flex items-center space-x-6"
    set :filter_boolean_option_class, "flex items-center"

    set :filter_boolean_radio_class,
        "w-4 h-4 text-blue-600 bg-gray-100 border-gray-300 focus:ring-blue-500 dark:focus:ring-blue-600 dark:ring-offset-gray-800 focus:ring-2 dark:bg-gray-700 dark:border-gray-600"

    set :filter_boolean_label_class,
        "ml-2 text-sm font-medium text-gray-900 dark:text-gray-300 cursor-pointer"

    # Multi-select filter
    set :filter_multiselect_container_class, "space-y-3"
    set :filter_multiselect_option_class, "flex items-center"

    set :filter_multiselect_checkbox_class,
        "w-4 h-4 text-blue-600 bg-gray-100 border-gray-300 rounded focus:ring-blue-500 dark:focus:ring-blue-600 dark:ring-offset-gray-800 focus:ring-2 dark:bg-gray-700 dark:border-gray-600"

    set :filter_multiselect_label_class,
        "ml-2 text-sm font-medium text-gray-900 dark:text-gray-300 cursor-pointer"

    # Range filters
    set :filter_range_container_class, "flex items-center space-x-3"
    set :filter_range_input_group_class, "flex-1"
  end

  component Cinder.Components.Pagination do
    set :pagination_wrapper_class,
        "bg-white dark:bg-gray-800 shadow-md rounded-lg p-4 mt-4 border border-gray-200 dark:border-gray-700"

    set :pagination_container_class,
        "flex flex-col md:flex-row justify-between items-start md:items-center space-y-3 md:space-y-0 w-full"

    set :pagination_button_class,
        "flex items-center justify-center px-3 h-8 ml-0 leading-tight text-gray-500 bg-white border border-gray-300 hover:bg-gray-100 hover:text-gray-700 dark:bg-gray-800 dark:border-gray-700 dark:text-gray-400 dark:hover:bg-gray-700 dark:hover:text-white"

    set :pagination_info_class, "text-sm font-normal text-gray-500 dark:text-gray-400"
    set :pagination_count_class, "font-semibold text-gray-900 dark:text-white"
  end

  component Cinder.Components.Sorting do
    set :sort_indicator_class, "ml-1 inline-flex items-center"
    set :sort_arrow_wrapper_class, "inline-flex items-center ml-1"
    set :sort_asc_icon_class, "w-3 h-3 text-gray-500 dark:text-gray-400"
    set :sort_desc_icon_class, "w-3 h-3 text-gray-500 dark:text-gray-400"
    set :sort_none_icon_class, "w-3 h-3 text-gray-400 opacity-50 dark:text-gray-600"
  end

  component Cinder.Components.Loading do
    set :loading_overlay_class, "absolute top-4 right-4"
    set :loading_container_class, "flex items-center text-sm text-gray-500 dark:text-gray-400"

    set :loading_spinner_class,
        "inline w-4 h-4 mr-2 text-gray-200 animate-spin dark:text-gray-600 fill-blue-600"

    set :loading_spinner_circle_class, ""
    set :loading_spinner_path_class, ""
  end
end
