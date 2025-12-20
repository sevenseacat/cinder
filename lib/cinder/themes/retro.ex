defmodule Cinder.Themes.Retro do
  @moduledoc """
  A retro 80s-inspired theme with neon colors and bold styling.

  Features:
  - Dark backgrounds with neon accent colors
  - Bright cyan, fuchsia, and yellow highlights
  - Bold typography with strong contrast
  - Glowing effects and sharp corners
  - Classic 80s color palette
  """

  use Cinder.Theme

  component Cinder.Components.Table do
    set :container_class, "bg-gray-900 border-2 border-cyan-400 shadow-2xl shadow-cyan-400/20"

    set :controls_class, ""

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

    set :empty_class,
        "text-center py-12 text-cyan-100 italic font-bold bg-gray-800/50 border border-cyan-400"

    set :error_container_class,
        "bg-red-900 border-2 border-red-400 p-4 text-red-100 shadow-lg shadow-red-400/30"

    set :error_message_class, "text-sm font-bold"

    # Bulk action button styling
    set :bulk_action_button_class,
        "px-6 py-3 text-sm font-bold text-cyan-100 bg-gray-800 border-2 border-cyan-400 rounded-lg hover:bg-magenta-800 hover:border-magenta-400 hover:shadow-xl hover:shadow-magenta-400/40 focus:outline-none focus:ring-2 focus:ring-yellow-400 transition-all duration-200 uppercase tracking-wider shadow-lg shadow-cyan-400/20"

    set :bulk_loading_class, "animate-pulse shadow-yellow-400/30"
  end

  component Cinder.Components.Filters do
    set :filter_container_class,
        "bg-gray-900 border-2 border-fuchsia-400 p-6 shadow-2xl shadow-fuchsia-400/20"

    set :filter_header_class,
        "flex items-center justify-between mb-4 pb-3 border-b-2 border-cyan-400"

    set :filter_title_class, "text-xl font-bold text-cyan-100 uppercase tracking-widest"

    set :filter_count_class,
        "text-xs text-black bg-yellow-400 px-3 py-1 font-bold uppercase tracking-wide"

    set :filter_clear_all_class,
        "text-xs text-cyan-100 bg-fuchsia-600 hover:bg-fuchsia-500 font-bold uppercase tracking-wide transition-colors border-2 border-cyan-400 hover:border-yellow-400 px-4 py-2 shadow-lg shadow-fuchsia-400/30"

    set :filter_inputs_class,
        "flow-root -mb-6"

    set :filter_input_wrapper_class, "space-y-3 float-left mr-6 mb-6"

    set :filter_label_class,
        "block text-sm font-bold text-cyan-100 uppercase tracking-wide whitespace-nowrap"

    set :filter_placeholder_class,
        "text-sm text-gray-400 italic p-3 border-2 border-purple-600 bg-gray-800 font-bold"

    set :filter_clear_button_class,
        "text-yellow-400 hover:text-yellow-300 transition-colors duration-200 ml-2 font-bold"

    # Input styling
    set :filter_text_input_class,
        "w-full px-4 py-3 border-2 border-cyan-400 bg-gray-800 text-cyan-100 text-sm focus:outline-none focus:border-fuchsia-400 focus:shadow-lg focus:shadow-fuchsia-400/30 transition-all duration-200 font-bold placeholder-gray-500"

    set :filter_date_input_class,
        "w-40 px-4 py-3 border-2 border-cyan-400 bg-gray-800 text-cyan-100 text-sm focus:outline-none focus:border-fuchsia-400 focus:shadow-lg focus:shadow-fuchsia-400/30 transition-all duration-200 font-bold"

    set :filter_number_input_class,
        "w-20 px-4 py-3 border-2 border-cyan-400 bg-gray-800 text-cyan-100 text-sm focus:outline-none focus:border-fuchsia-400 focus:shadow-lg focus:shadow-fuchsia-400/30 transition-all duration-200 font-bold [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none [-moz-appearance:textfield]"

    set :filter_select_input_class,
        "w-48 px-4 py-3 border-2 border-cyan-400 bg-gray-800 text-cyan-100 text-sm focus:outline-none focus:border-fuchsia-400 focus:shadow-lg focus:shadow-fuchsia-400/30 transition-all duration-200 font-bold"

    # Select filter (dropdown interface)
    set :filter_select_container_class, "relative"

    set :filter_select_dropdown_class,
        "absolute z-50 w-full mt-1 bg-gray-800 border-2 border-cyan-400 shadow-2xl shadow-cyan-400/20 max-h-60 overflow-auto"

    set :filter_select_option_class,
        "px-3 py-2 hover:bg-fuchsia-800 hover:shadow-lg hover:shadow-fuchsia-400/30 border-b border-cyan-400/50 last:border-b-0 cursor-pointer"

    set :filter_select_label_class,
        "text-sm font-bold text-cyan-100 cursor-pointer uppercase tracking-wide select-none flex-1"

    set :filter_select_empty_class,
        "px-3 py-2 text-fuchsia-300 italic font-bold uppercase tracking-wide text-sm"

    set :filter_select_placeholder_class, "text-gray-400"

    set :filter_select_placeholder_class, "text-gray-400"

    # Boolean filter
    set :filter_boolean_container_class, "flex space-x-8 h-[48px] items-center"
    set :filter_boolean_option_class, "flex items-center space-x-2"

    set :filter_boolean_radio_class,
        "h-5 w-5 text-fuchsia-400 focus:ring-fuchsia-400 focus:ring-2 border-2 border-cyan-400"

    set :filter_boolean_label_class,
        "text-sm font-bold text-cyan-100 cursor-pointer uppercase tracking-wide"

    # Checkbox filter
    set :filter_checkbox_container_class, "flex items-center h-[48px]"

    set :filter_checkbox_input_class,
        "h-5 w-5 text-fuchsia-400 focus:ring-fuchsia-400 focus:ring-2 border-2 border-cyan-400 bg-gray-800 mr-2"

    set :filter_checkbox_label_class,
        "text-sm font-bold text-cyan-100 cursor-pointer uppercase tracking-wide"

    # Multi-select filter (dropdown interface)
    set :filter_multiselect_container_class, "relative"

    set :filter_multiselect_dropdown_class,
        "absolute z-50 w-full mt-1 bg-gray-800 border-2 border-cyan-400 shadow-2xl shadow-cyan-400/20 max-h-60 overflow-auto"

    set :filter_multiselect_option_class,
        "px-3 py-2 hover:bg-fuchsia-800 hover:shadow-lg hover:shadow-fuchsia-400/30 border-b border-cyan-400/50 last:border-b-0 cursor-pointer"

    set :filter_multiselect_checkbox_class,
        "h-4 w-4 text-yellow-400 focus:ring-yellow-400/50 focus:ring-2 border-2 border-cyan-400 bg-gray-800 mr-2"

    set :filter_multiselect_label_class,
        "text-sm font-bold text-cyan-100 cursor-pointer uppercase tracking-wide select-none flex-1"

    set :filter_multiselect_empty_class,
        "px-3 py-2 text-fuchsia-300 italic font-bold uppercase tracking-wide text-sm"

    # Multi-checkboxes filter
    set :filter_multicheckboxes_container_class, "space-y-4"
    set :filter_multicheckboxes_option_class, "flex items-center space-x-3"

    set :filter_multicheckboxes_checkbox_class,
        "h-5 w-5 text-fuchsia-400 focus:ring-fuchsia-400 focus:ring-2 border-2 border-cyan-400 bg-gray-800"

    set :filter_multicheckboxes_label_class,
        "text-sm font-bold text-cyan-100 cursor-pointer uppercase tracking-wide"

    # Range filters
    set :filter_range_container_class, "flex items-center space-x-2"
    set :filter_range_input_group_class, ""

    set :filter_range_separator_class,
        "text-xs flex items-center px-1 text-sm font-bold text-cyan-300 uppercase tracking-wide"
  end

  component Cinder.Components.Pagination do
    set :pagination_wrapper_class, "p-6"
    set :pagination_container_class, "flex items-center justify-between"

    set :pagination_info_class, "text-sm text-cyan-100 font-bold uppercase tracking-wide"
    set :pagination_count_class, "text-xs text-yellow-400 ml-2 font-bold uppercase"

    set :pagination_nav_class, "flex items-center space-x-1"

    set :pagination_button_class,
        "px-4 py-2 text-sm font-bold text-cyan-100 bg-gray-800 border-2 border-cyan-400 rounded hover:bg-fuchsia-800 hover:border-fuchsia-400 hover:shadow-lg hover:shadow-fuchsia-400/30 focus:outline-none focus:ring-2 focus:ring-yellow-400 transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed uppercase tracking-wide"

    set :pagination_current_class,
        "px-4 py-2 text-sm font-bold text-black bg-gradient-to-r from-cyan-400 to-fuchsia-400 border-2 border-yellow-400 rounded shadow-lg shadow-yellow-400/30 uppercase tracking-wide"

    set :page_size_container_class, "flex items-center space-x-2"
    set :page_size_label_class, "text-sm text-cyan-100 font-bold uppercase tracking-wide"

    set :page_size_dropdown_class,
        "flex items-center px-4 py-2 text-sm font-bold text-cyan-100 bg-gray-800 border-2 border-cyan-400 rounded hover:bg-fuchsia-800 hover:border-fuchsia-400 hover:shadow-lg hover:shadow-fuchsia-400/30 focus:outline-none focus:ring-2 focus:ring-yellow-400 transition-all duration-200 cursor-pointer uppercase tracking-wide"

    set :page_size_dropdown_container_class,
        "bg-gray-800 border-2 border-cyan-400 rounded shadow-lg shadow-cyan-400/20"

    set :page_size_option_class,
        "w-full text-left px-4 py-2 text-sm font-bold text-cyan-100 hover:bg-fuchsia-800 hover:border-fuchsia-400 hover:text-yellow-400 cursor-pointer uppercase tracking-wide"

    set :page_size_selected_class, "bg-gradient-to-r from-cyan-800 to-fuchsia-800 text-yellow-400"
  end

  component Cinder.Components.Search do
    set :search_container_class, ""
    set :search_wrapper_class, ""

    set :search_input_class,
        "w-full pl-10 px-4 py-3 border-2 border-cyan-400 bg-gray-800 text-cyan-100 text-sm focus:outline-none focus:border-fuchsia-400 focus:shadow-lg focus:shadow-fuchsia-400/30 transition-all duration-200 font-bold placeholder-gray-500"

    set :search_icon_class, "w-4 h-4 text-cyan-400"

    set :search_label_class, ""
  end

  component Cinder.Components.Sorting do
    set :sort_indicator_class, "ml-1 inline-flex items-center align-baseline"
    set :sort_arrow_wrapper_class, "inline-flex items-center"
    set :sort_asc_icon_class, "w-3 h-3 text-cyan-400 drop-shadow-lg"
    set :sort_desc_icon_class, "w-3 h-3 text-fuchsia-400 drop-shadow-lg"
    set :sort_none_icon_class, "w-3 h-3 text-gray-400 opacity-75"
  end

  component Cinder.Components.Loading do
    set :loading_overlay_class, "absolute top-4 right-4"

    set :loading_container_class,
        "flex items-center text-sm text-cyan-400 font-bold uppercase tracking-wide"

    set :loading_spinner_class, "animate-spin h-5 w-5 text-cyan-400 mr-2 drop-shadow-lg"
    set :loading_spinner_circle_class, "opacity-25"
    set :loading_spinner_path_class, "opacity-75"
  end

  component Cinder.Components.List do
    set :list_container_class, "divide-y divide-pink-500/30 border-b-2 border-cyan-400 "
    set :list_item_class, "py-3 px-6 text-cyan-100"

    set :list_item_clickable_class,
        "cursor-pointer hover:bg-pink-500/10 transition-colors duration-150"

    # Sort container - card-like panel matching filter styling
    set :sort_container_class,
        "bg-gray-900 border-2 border-fuchsia-400 shadow-2xl shadow-fuchsia-400/20 mt-4"

    # Sort controls - inner flex layout
    set :sort_controls_class, "flex items-center gap-3 p-6"

    set :sort_controls_label_class, "text-sm font-bold text-cyan-100 uppercase tracking-wider"
    set :sort_buttons_class, "flex gap-2"

    set :sort_button_class,
        "px-4 py-2 text-sm font-bold border-2 uppercase tracking-wide transition-all duration-150"

    set :sort_button_active_class,
        "bg-fuchsia-600 border-yellow-400 text-cyan-100 shadow-lg shadow-fuchsia-400/30"

    set :sort_button_inactive_class,
        "bg-gray-800 border-cyan-400 text-cyan-100 hover:bg-fuchsia-800 hover:border-fuchsia-400 hover:shadow-lg hover:shadow-fuchsia-400/30"

    set :sort_icon_class, "ml-1"
    set :sort_asc_icon, "↑"
    set :sort_desc_icon, "↓"
  end

  component Cinder.Components.Grid do
    set :grid_container_class, "grid gap-4 p-6"

    set :grid_item_class,
        "p-4 bg-gray-900 text-cyan-100 border-2 border-fuchsia-400 shadow-2xl shadow-fuchsia-400/20"

    set :grid_item_clickable_class,
        "cursor-pointer hover:border-yellow-400 hover:shadow-yellow-400/30 transition-all duration-150"
  end
end
