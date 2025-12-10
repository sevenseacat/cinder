defmodule Cinder.Themes.Flowbite do
  @moduledoc """
  A Flowbite-compatible theme following Flowbite design system.

  Features:
  - Flowbite table styling with proper borders and spacing
  - Gray color scheme with hover states
  - Professional form inputs with Flowbite styling
  - Button components using Flowbite button classes
  - Consistent spacing and typography matching Flowbite docs
  - Proper z-index handling for dropdowns and filters
  """

  use Cinder.Theme

  component Cinder.Components.Table do
    set :container_class,
        "relative bg-white shadow-md dark:bg-gray-800 sm:rounded-lg border border-gray-200 dark:border-gray-700 [&>*:first-child]:sm:rounded-t-lg [&>*:last-child]:sm:rounded-b-lg"

    set :controls_class,
        "p-4 bg-gray-50 dark:bg-gray-800 border-b border-gray-200 dark:border-gray-700 relative z-20"

    set :table_wrapper_class, "overflow-x-auto"
    set :table_class, "w-full text-sm text-left text-gray-500 dark:text-gray-400"

    set :thead_class,
        "text-xs text-gray-700 uppercase bg-gray-50 dark:bg-gray-700 dark:text-gray-400"

    set :tbody_class, ""
    set :header_row_class, ""

    set :row_class,
        "bg-white border-b border-gray-200 dark:border-gray-700 dark:bg-gray-800 hover:bg-gray-50 dark:hover:bg-gray-600"

    set :th_class, "px-6 py-3 whitespace-nowrap font-medium"
    set :td_class, "px-6 py-4"
    set :loading_class, "text-center py-8 text-gray-500 dark:text-gray-400"
    set :empty_class, "text-center py-8 text-gray-500 dark:text-gray-400"

    set :error_container_class,
        "flex p-4 text-sm text-red-800 border border-red-300 rounded-lg bg-red-50 dark:bg-gray-800 dark:text-red-400 dark:border-red-800"

    set :error_message_class, ""

    # Bulk action button styling
    set :bulk_action_button_class,
        "flex items-center justify-center px-4 py-2 text-sm font-medium text-gray-500 bg-white border border-gray-300 rounded-lg hover:bg-gray-100 hover:text-gray-700 focus:z-10 focus:ring-4 focus:ring-gray-200 dark:bg-gray-800 dark:border-gray-700 dark:text-gray-400 dark:hover:bg-gray-700 dark:hover:text-white dark:focus:ring-gray-600"

    set :bulk_loading_class, "animate-pulse dark:animate-pulse"
  end

  component Cinder.Components.Filters do
    # Main filter container - styled like sort panel with border and padding
    set :filter_container_class,
        "bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg shadow-md p-4 mb-4 relative z-20"

    set :filter_header_class,
        "flex flex-col md:flex-row items-start md:items-center justify-between space-y-3 md:space-y-0 md:space-x-4 pb-4 border-b border-gray-200 dark:border-gray-700 mb-4"

    set :filter_title_class, "text-lg font-semibold text-gray-900 dark:text-white"

    set :filter_count_class,
        "bg-blue-100 text-blue-800 text-xs font-medium px-2.5 py-0.5 rounded dark:bg-blue-900 dark:text-blue-300 ml-2"

    set :filter_clear_all_class,
        "text-blue-700 hover:text-white border border-blue-700 hover:bg-blue-800 focus:ring-4 focus:outline-none focus:ring-blue-300 font-medium rounded-lg text-sm px-4 py-2 text-center dark:border-blue-500 dark:text-blue-500 dark:hover:text-white dark:hover:bg-blue-500 dark:focus:ring-blue-800"

    # Filter inputs - use flexbox for proper layout
    set :filter_inputs_class,
        "flex flex-wrap gap-x-6 gap-y-4"

    set :filter_input_wrapper_class, "space-y-2 min-w-0"

    set :filter_label_class,
        "block text-sm font-medium text-gray-900 dark:text-white whitespace-nowrap"

    set :filter_placeholder_class,
        "text-sm text-gray-500 dark:text-gray-400 italic p-2.5 border border-gray-300 rounded-lg bg-gray-50 dark:bg-gray-700 dark:border-gray-600"

    set :filter_clear_button_class,
        "text-gray-400 bg-transparent hover:bg-gray-200 hover:text-gray-900 rounded-lg text-sm p-1.5 ml-2 inline-flex items-center dark:hover:bg-gray-600 dark:hover:text-white"

    # Input styling - standard Flowbite inputs
    set :filter_text_input_class,
        "bg-gray-50 border border-gray-300 text-gray-900 text-sm rounded-lg focus:ring-blue-500 focus:border-blue-500 block w-full p-2.5 dark:bg-gray-700 dark:border-gray-600 dark:placeholder-gray-400 dark:text-white dark:focus:ring-blue-500 dark:focus:border-blue-500"

    set :filter_date_input_class,
        "bg-gray-50 border border-gray-300 text-gray-900 text-sm rounded-lg focus:ring-blue-500 focus:border-blue-500 block w-40 p-2.5 dark:bg-gray-700 dark:border-gray-600 dark:placeholder-gray-400 dark:text-white dark:focus:ring-blue-500 dark:focus:border-blue-500"

    set :filter_number_input_class,
        "bg-gray-50 border border-gray-300 text-gray-900 text-sm rounded-lg focus:ring-blue-500 focus:border-blue-500 block w-24 p-2.5 dark:bg-gray-700 dark:border-gray-600 dark:placeholder-gray-400 dark:text-white dark:focus:ring-blue-500 dark:focus:border-blue-500 [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none [-moz-appearance:textfield]"

    set :filter_select_input_class,
        "bg-gray-50 border border-gray-300 text-gray-900 text-sm rounded-lg focus:ring-blue-500 focus:border-blue-500 block w-48 p-2.5 dark:bg-gray-700 dark:border-gray-600 dark:placeholder-gray-400 dark:text-white dark:focus:ring-blue-500 dark:focus:border-blue-500"

    # Select filter (dropdown interface) - proper z-index for dropdowns
    set :filter_select_container_class, "relative z-30"

    set :filter_select_dropdown_class,
        "absolute z-50 w-full mt-1 bg-white border border-gray-200 rounded-lg shadow-lg dark:bg-gray-700 dark:border-gray-600 max-h-60 overflow-auto"

    set :filter_select_option_class,
        "px-4 py-2 hover:bg-gray-100 dark:hover:bg-gray-600 cursor-pointer text-gray-900 dark:text-white"

    set :filter_select_label_class,
        "text-sm font-medium text-gray-900 dark:text-white cursor-pointer select-none flex-1"

    set :filter_select_empty_class,
        "px-4 py-2 text-gray-500 dark:text-gray-400 italic text-sm"

    set :filter_select_placeholder_class,
        "text-gray-500 dark:text-gray-400"

    # Boolean filter
    set :filter_boolean_container_class, "flex items-center space-x-6 h-[42px]"
    set :filter_boolean_option_class, "flex items-center space-x-2"

    set :filter_boolean_radio_class,
        "w-4 h-4 text-blue-600 bg-gray-100 border-gray-300 focus:ring-blue-500 dark:focus:ring-blue-600 dark:ring-offset-gray-800 focus:ring-2 dark:bg-gray-700 dark:border-gray-600"

    set :filter_boolean_label_class,
        "ml-2 text-sm font-medium text-gray-900 dark:text-gray-300 cursor-pointer"

    # Checkbox filter - single checkbox with proper Flowbite styling
    set :filter_checkbox_container_class, "flex items-center min-h-[42px]"

    set :filter_checkbox_input_class,
        "w-4 h-4 text-blue-600 bg-white border-gray-300 rounded focus:ring-blue-500 dark:focus:ring-blue-600 dark:ring-offset-gray-800 focus:ring-2 dark:bg-gray-600 dark:border-gray-500"

    set :filter_checkbox_label_class,
        "ml-2 text-sm font-medium text-gray-900 dark:text-gray-300 cursor-pointer"

    # Multi-select filter (dropdown interface)
    set :filter_multiselect_container_class, "relative z-30"

    set :filter_multiselect_dropdown_class,
        "absolute z-50 w-full mt-1 bg-white border border-gray-200 rounded-lg shadow-lg dark:bg-gray-700 dark:border-gray-600 max-h-60 overflow-auto"

    set :filter_multiselect_option_class,
        "flex items-center px-4 py-2 hover:bg-gray-100 dark:hover:bg-gray-600 cursor-pointer"

    set :filter_multiselect_checkbox_class,
        "w-4 h-4 text-blue-600 bg-white border-gray-300 rounded focus:ring-blue-500 dark:focus:ring-blue-600 dark:ring-offset-gray-700 focus:ring-2 dark:bg-gray-600 dark:border-gray-500"

    set :filter_multiselect_label_class,
        "ml-2 text-sm font-medium text-gray-900 dark:text-white cursor-pointer select-none flex-1"

    set :filter_multiselect_empty_class,
        "px-4 py-2 text-gray-500 dark:text-gray-400 italic text-sm"

    # Multi-checkboxes filter - vertical stack of checkboxes
    set :filter_multicheckboxes_container_class, "flex flex-col space-y-2 py-1"
    set :filter_multicheckboxes_option_class, "flex items-center"

    set :filter_multicheckboxes_checkbox_class,
        "w-4 h-4 text-blue-600 bg-white border-gray-300 rounded focus:ring-blue-500 dark:focus:ring-blue-600 dark:ring-offset-gray-800 focus:ring-2 dark:bg-gray-600 dark:border-gray-500"

    set :filter_multicheckboxes_label_class,
        "ml-2 text-sm font-medium text-gray-900 dark:text-gray-300 cursor-pointer"

    # Range filters
    set :filter_range_container_class, "flex items-center space-x-2"
    set :filter_range_input_group_class, ""

    set :filter_range_separator_class,
        "flex items-center px-1 text-sm font-medium text-gray-500 dark:text-gray-400"
  end

  component Cinder.Components.Pagination do
    set :pagination_wrapper_class,
        "p-4 border-t border-gray-200 dark:border-gray-700"

    set :pagination_container_class,
        "flex flex-col md:flex-row items-center justify-between space-y-3 md:space-y-0"

    set :pagination_info_class, "text-sm font-normal text-gray-500 dark:text-gray-400"
    set :pagination_count_class, "font-semibold text-gray-900 dark:text-white"

    set :pagination_nav_class, "inline-flex items-center -space-x-px"

    set :pagination_button_class,
        "flex items-center justify-center px-3 h-8 leading-tight text-gray-500 bg-white border border-gray-300 hover:bg-gray-100 hover:text-gray-700 dark:bg-gray-800 dark:border-gray-700 dark:text-gray-400 dark:hover:bg-gray-700 dark:hover:text-white"

    set :pagination_current_class,
        "flex items-center justify-center px-3 h-8 leading-tight text-blue-600 border border-gray-300 bg-blue-50 hover:bg-blue-100 hover:text-blue-700 dark:border-gray-700 dark:bg-gray-700 dark:text-white"

    set :page_size_container_class, "flex items-center space-x-2"
    set :page_size_label_class, "text-sm font-medium text-gray-500 dark:text-gray-400"

    set :page_size_dropdown_class,
        "flex items-center px-3 py-2 text-sm font-medium text-gray-500 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 hover:text-gray-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-800 dark:text-gray-400 dark:border-gray-600 dark:hover:bg-gray-700 dark:hover:text-white cursor-pointer"

    set :page_size_dropdown_container_class,
        "bg-white border border-gray-200 rounded-lg shadow-lg dark:bg-gray-800 dark:border-gray-700"

    set :page_size_option_class,
        "w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 dark:text-gray-200 dark:hover:bg-gray-600 cursor-pointer"

    set :page_size_selected_class, "bg-blue-50 text-blue-600 dark:bg-blue-900 dark:text-blue-300"
  end

  component Cinder.Components.Search do
    set :search_container_class, "mb-4"
    set :search_wrapper_class, "relative"

    set :search_input_class,
        "block w-full p-2.5 pl-10 text-sm text-gray-900 border border-gray-300 rounded-lg bg-gray-50 focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-700 dark:border-gray-600 dark:placeholder-gray-400 dark:text-white dark:focus:ring-blue-500 dark:focus:border-blue-500"

    set :search_icon_class, "w-4 h-4 text-gray-500 dark:text-gray-400"

    set :search_label_class, "sr-only"
  end

  component Cinder.Components.Sorting do
    set :sort_indicator_class, "ml-1.5 inline-flex items-center align-baseline"
    set :sort_arrow_wrapper_class, "inline-flex items-center"
    set :sort_asc_icon_class, "w-3 h-3 text-gray-700 dark:text-gray-300"
    set :sort_desc_icon_class, "w-3 h-3 text-gray-700 dark:text-gray-300"
    set :sort_none_icon_class, "w-3 h-3 text-gray-400 dark:text-gray-500"
  end

  component Cinder.Components.Loading do
    set :loading_overlay_class, "absolute top-4 right-4 z-10"
    set :loading_container_class, "flex items-center text-sm text-gray-500 dark:text-gray-400"

    set :loading_spinner_class,
        "inline w-4 h-4 mr-2 text-gray-200 animate-spin dark:text-gray-600 fill-blue-600"

    set :loading_spinner_circle_class, "opacity-25"
    set :loading_spinner_path_class, "opacity-75"
  end

  component Cinder.Components.List do
    set :list_container_class, "divide-y divide-gray-200 dark:divide-gray-700"
    set :list_item_class, "py-4 px-4 text-gray-900 dark:text-white"

    set :list_item_clickable_class,
        "cursor-pointer hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors"

    # Sort container - card matching the overall style
    set :sort_container_class,
        "bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg shadow-md"

    # Sort controls - inner layout
    set :sort_controls_class, "flex items-center gap-3 p-4"

    set :sort_controls_label_class, "text-sm font-medium text-gray-700 dark:text-gray-300"
    set :sort_buttons_class, "flex flex-wrap gap-2"

    set :sort_button_class,
        "px-4 py-2 text-sm font-medium rounded-lg border transition-colors focus:outline-none focus:ring-2 focus:ring-blue-500"

    set :sort_button_active_class,
        "bg-blue-700 border-blue-700 text-white hover:bg-blue-800"

    set :sort_button_inactive_class,
        "bg-white dark:bg-gray-800 border-gray-300 dark:border-gray-600 text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700"

    set :sort_icon_class, "ml-1"
    set :sort_asc_icon, "↑"
    set :sort_desc_icon, "↓"
  end

  component Cinder.Components.Grid do
    set :grid_container_class, "grid gap-4 p-4"

    set :grid_item_class,
        "p-4 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg shadow-md text-gray-900 dark:text-white"

    set :grid_item_clickable_class,
        "cursor-pointer hover:shadow-lg transition-shadow"
  end
end
