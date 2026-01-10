defmodule Cinder.Themes.Futuristic do
  @moduledoc """
  A futuristic theme with holographic effects and sci-fi styling.

  Features:
  - Dark space-like backgrounds with glowing accents
  - Holographic blue and green color scheme
  - Subtle gradients and glow effects
  - Minimalist typography with futuristic feel
  - Sharp geometric designs
  """

  use Cinder.Theme

  component Cinder.Components.Table do
    set :container_class,
        "bg-slate-950 border border-blue-500/30 shadow-2xl shadow-blue-500/10 backdrop-blur-sm"

    set :controls_class,
        "p-6 bg-gradient-to-r from-slate-900/80 to-blue-900/20 border-b border-blue-500/30 backdrop-blur-sm relative z-10"

    set :table_wrapper_class, "overflow-x-auto bg-slate-900/50"
    set :table_class, "w-full border-collapse"
    set :thead_class, "bg-gradient-to-r from-blue-900/60 to-green-900/60"
    set :tbody_class, "divide-y divide-blue-500/20"
    set :header_row_class, ""

    set :row_class,
        "hover:bg-gradient-to-r hover:from-blue-950/60 hover:to-green-950/60 hover:shadow-md hover:shadow-blue-500/10 transition-all duration-500"

    set :th_class,
        "px-6 py-4 text-left text-sm font-light text-blue-100 tracking-wider whitespace-nowrap border-b border-blue-500/30 bg-gradient-to-r from-transparent to-blue-500/5"

    set :td_class, "px-6 py-4 text-sm text-slate-200 font-light"
    set :loading_class, "text-center py-12 text-blue-400 font-light tracking-wider"
    set :empty_class, "text-center py-12 text-green-400 italic font-light tracking-wide"

    set :error_container_class,
        "bg-red-950/50 border border-red-500/50 p-4 text-red-200 shadow-lg shadow-red-500/20 backdrop-blur-sm"

    set :error_message_class, "text-sm font-light"

    # Bulk action button styling
    set :bulk_action_button_class,
        "px-4 py-2 text-sm font-medium text-blue-100 bg-slate-900/70 border border-blue-500/50 rounded-lg hover:bg-gradient-to-r hover:from-blue-900/70 hover:to-green-900/70 hover:border-green-400/70 hover:shadow-lg hover:shadow-blue-500/30 focus:outline-none focus:ring-2 focus:ring-green-400/60 transition-all duration-300 tracking-wide backdrop-blur-md"

    set :bulk_loading_class, "animate-pulse shadow-green-400/40"
  end

  component Cinder.Components.Filters do
    set :filter_container_class,
        "bg-slate-950/80 border border-green-500/30 p-6 shadow-2xl shadow-green-500/10 backdrop-blur-sm relative z-10"

    set :filter_header_class,
        "flex items-center justify-between mb-4 pb-3 border-b border-green-500/30"

    set :filter_title_class, "text-lg font-light text-green-100 tracking-wider"

    set :filter_count_class,
        "text-xs text-slate-900 bg-gradient-to-r from-blue-400 to-green-400 px-3 py-1 ml-1 font-medium tracking-wide shadow-md shadow-blue-500/20"

    set :filter_clear_all_class,
        "text-xs text-green-400 hover:text-green-300 font-light tracking-wide transition-colors border border-green-500/50 hover:border-green-400/70 px-3 py-1 hover:shadow-md hover:shadow-green-500/20"

    set :filter_inputs_class,
        "flow-root -mb-6"

    set :filter_input_wrapper_class, "space-y-3 float-left mr-6 mb-6"

    set :filter_label_class,
        "block text-sm font-light text-blue-100 tracking-wide whitespace-nowrap"

    set :filter_placeholder_class,
        "text-sm text-slate-400 italic p-3 border border-blue-500/30 bg-slate-900/50 font-light backdrop-blur-sm"

    set :filter_clear_button_class,
        "text-green-400 hover:text-green-300 transition-colors duration-300 ml-2 font-light hover:drop-shadow-sm hover:drop-shadow-green-400/50"

    # Input styling
    set :filter_text_input_class,
        "w-full px-4 py-3 border border-blue-500/40 bg-slate-900/60 text-blue-100 text-sm focus:outline-none focus:border-green-400/60 focus:shadow-lg focus:shadow-green-400/20 transition-all duration-300 font-light placeholder-slate-500 backdrop-blur-sm"

    set :filter_date_input_class,
        "w-40 px-4 py-3 border border-blue-500/40 bg-slate-900/60 text-blue-100 text-sm focus:outline-none focus:border-green-400/60 focus:shadow-lg focus:shadow-green-400/20 transition-all duration-300 font-light backdrop-blur-sm"

    set :filter_number_input_class,
        "w-20 px-4 py-3 border border-blue-500/40 bg-slate-900/60 text-blue-100 text-sm focus:outline-none focus:border-green-400/60 focus:shadow-lg focus:shadow-green-400/20 transition-all duration-300 font-light backdrop-blur-sm [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none [-moz-appearance:textfield]"

    set :filter_select_input_class,
        "w-48 px-4 py-3 border border-blue-500/40 bg-slate-900/60 text-blue-100 text-sm focus:outline-none focus:border-green-400/60 focus:shadow-lg focus:shadow-green-400/20 transition-all duration-300 font-light backdrop-blur-sm"

    # Select filter (dropdown interface)
    set :filter_select_container_class, "relative z-20"

    set :filter_select_dropdown_class,
        "absolute z-50 w-full mt-1 bg-slate-950 border border-blue-500/40 shadow-2xl shadow-blue-500/20 max-h-60 overflow-auto"

    set :filter_select_option_class,
        "px-3 py-2 hover:bg-blue-950/60 border-b border-blue-500/20 last:border-b-0 cursor-pointer"

    set :filter_select_label_class,
        "text-sm font-light text-blue-100 cursor-pointer tracking-wide select-none flex-1"

    set :filter_select_empty_class,
        "px-3 py-2 text-blue-300/70 italic font-light tracking-wide text-sm"

    set :filter_select_placeholder_class, "text-slate-400"

    # Boolean filter
    set :filter_boolean_container_class, "flex space-x-8 h-[48px] items-center"
    set :filter_boolean_option_class, "flex items-center space-x-2"

    set :filter_boolean_radio_class,
        "h-4 w-4 text-green-400 focus:ring-green-400/50 focus:ring-2 border border-blue-500/40 bg-slate-900/60"

    set :filter_boolean_label_class,
        "text-sm font-light text-blue-100 cursor-pointer tracking-wide"

    # Checkbox filter
    set :filter_checkbox_container_class, "flex items-center h-[48px]"

    set :filter_checkbox_input_class,
        "h-4 w-4 text-green-400 focus:ring-green-400/50 focus:ring-2 border border-blue-500/40 bg-slate-900/60 mr-2"

    set :filter_checkbox_label_class,
        "text-sm font-light text-blue-100 cursor-pointer tracking-wide"

    # Multi-select filter (dropdown interface)
    set :filter_multiselect_container_class, "relative z-20"

    set :filter_multiselect_dropdown_class,
        "absolute z-50 w-full mt-1 bg-slate-950 border border-blue-500/40 shadow-2xl shadow-blue-500/20 max-h-60 overflow-auto"

    set :filter_multiselect_option_class,
        "px-3 py-2 hover:bg-blue-950/60 border-b border-blue-500/20 last:border-b-0 cursor-pointer"

    set :filter_multiselect_checkbox_class,
        "h-4 w-4 text-green-400 focus:ring-green-400/50 focus:ring-2 border border-blue-500/40 bg-slate-900/60 mr-2"

    set :filter_multiselect_label_class,
        "text-sm font-light text-blue-100 cursor-pointer tracking-wide select-none flex-1"

    set :filter_multiselect_empty_class,
        "px-3 py-2 text-blue-300/70 italic font-light tracking-wide text-sm"

    # Multi-checkboxes filter
    set :filter_multicheckboxes_container_class, "space-y-3"
    set :filter_multicheckboxes_option_class, "flex items-center space-x-3"

    set :filter_multicheckboxes_checkbox_class,
        "h-4 w-4 text-green-400 focus:ring-green-400/50 focus:ring-2 border border-blue-500/40 bg-slate-900/60"

    set :filter_multicheckboxes_label_class,
        "text-sm font-light text-blue-100 cursor-pointer tracking-wide"

    # Range filters
    set :filter_range_container_class, "flex items-center space-x-2"
    set :filter_range_input_group_class, ""

    set :filter_range_separator_class,
        "flex items-center px-1 text-sm font-light text-blue-200 tracking-wide"
  end

  component Cinder.Components.Pagination do
    set :pagination_wrapper_class, "p-6"
    set :pagination_container_class, "flex items-center justify-between"

    set :pagination_info_class, "text-sm text-blue-100 font-light tracking-wide"
    set :pagination_count_class, "text-xs text-green-400 ml-2 font-light tracking-wider"

    set :pagination_nav_class, "flex items-center space-x-1"

    set :pagination_button_class,
        "px-3 py-1 text-sm font-light text-blue-100 bg-slate-900/60 border border-blue-500/40 rounded hover:bg-gradient-to-r hover:from-blue-900/60 hover:to-green-900/60 hover:border-green-400/60 hover:shadow-lg hover:shadow-blue-500/20 focus:outline-none focus:ring-2 focus:ring-green-400/50 transition-all duration-300 disabled:opacity-30 disabled:cursor-not-allowed tracking-wide backdrop-blur-sm"

    set :pagination_current_class,
        "px-3 py-1 text-sm font-light text-black bg-gradient-to-r from-green-400 to-blue-400 border border-green-400 rounded shadow-lg shadow-green-400/30"

    set :page_size_container_class, "flex items-center space-x-2"
    set :page_size_label_class, "text-sm text-blue-100 font-light tracking-wide"

    set :page_size_dropdown_class,
        "flex items-center px-3 py-1 text-sm font-light text-blue-100 bg-slate-900/60 border border-blue-500/40 rounded hover:bg-gradient-to-r hover:from-blue-900/60 hover:to-green-900/60 hover:border-green-400/60 hover:shadow-lg hover:shadow-blue-500/20 focus:outline-none focus:ring-2 focus:ring-green-400/50 transition-all duration-300 cursor-pointer tracking-wide backdrop-blur-sm"

    set :page_size_dropdown_container_class,
        "bg-slate-950 border border-blue-500/60 rounded shadow-xl shadow-blue-500/30 backdrop-blur-sm"

    set :page_size_option_class,
        "w-full text-left px-3 py-2 text-sm font-light text-blue-100 hover:bg-gradient-to-r hover:from-blue-900/60 hover:to-green-900/60 hover:text-green-400 cursor-pointer tracking-wide"

    set :page_size_selected_class,
        "bg-gradient-to-r from-green-900/80 to-blue-900/80 text-green-400"
  end

  component Cinder.Components.Sorting do
    set :sort_indicator_class, "ml-1 inline-flex items-center align-baseline"
    set :sort_arrow_wrapper_class, "inline-flex items-center"
    set :sort_asc_icon_class, "w-3 h-3 text-green-400 drop-shadow-sm drop-shadow-green-400/50"
    set :sort_desc_icon_class, "w-3 h-3 text-blue-400 drop-shadow-sm drop-shadow-blue-400/50"
    set :sort_none_icon_class, "w-3 h-3 text-slate-400 opacity-65"
  end

  component Cinder.Components.Search do
    set :search_container_class, ""
    set :search_wrapper_class, ""

    set :search_input_class,
        "w-full pl-10 px-4 py-3 border border-blue-500/40 bg-slate-900/60 text-blue-100 text-sm focus:outline-none focus:border-green-400/60 focus:shadow-lg focus:shadow-green-400/20 transition-all duration-300 font-light placeholder-slate-500 backdrop-blur-sm"

    set :search_icon_class, "w-4 h-4 text-blue-300"

    set :search_label_class, ""
  end

  component Cinder.Components.Loading do
    set :loading_overlay_class, "absolute top-4 right-4"

    set :loading_container_class,
        "flex items-center text-sm text-green-400 font-light tracking-wide"

    set :loading_spinner_class,
        "animate-spin h-5 w-5 text-green-400 mr-2 drop-shadow-sm drop-shadow-green-400/50"

    set :loading_spinner_circle_class, "opacity-25"
    set :loading_spinner_path_class, "opacity-75"
  end

  component Cinder.Components.List do
    set :list_container_class, "divide-y divide-green-500/20 border-b border-blue-500/30"
    set :list_item_class, "py-3 px-6 text-blue-100"

    set :list_item_clickable_class,
        "cursor-pointer hover:bg-green-500/10 transition-colors duration-200"

    # Sort container - card-like panel matching filter styling (relative z-0 so dropdowns appear above)
    set :sort_container_class,
        "bg-slate-950/80 border border-green-500/30 shadow-2xl shadow-green-500/10 backdrop-blur-sm mt-4 relative z-0"

    # Sort controls - inner flex layout
    set :sort_controls_class, "flex items-center gap-3 p-6"

    set :sort_controls_label_class, "text-sm font-light text-green-100 tracking-wide"
    set :sort_buttons_class, "flex gap-2"

    set :sort_button_class,
        "px-4 py-2 text-sm font-light border tracking-wide transition-all duration-300 backdrop-blur-sm"

    set :sort_button_active_class,
        "bg-green-500/20 border-green-400/60 text-green-300 shadow-lg shadow-green-500/20"

    set :sort_button_inactive_class,
        "bg-slate-900/60 border-blue-500/40 text-blue-100 hover:border-green-400/60 hover:text-green-400"

    set :sort_icon_class, "ml-1"
    set :sort_asc_icon, "↑"
    set :sort_desc_icon, "↓"
  end

  component Cinder.Components.Grid do
    set :grid_container_class, "grid gap-4 p-6"

    set :grid_item_class,
        "p-4 bg-slate-950/80 text-blue-100 border border-green-500/30 shadow-2xl shadow-green-500/10 backdrop-blur-sm"

    set :grid_item_clickable_class,
        "cursor-pointer hover:border-green-400/60 hover:shadow-green-500/20 transition-all duration-300"
  end
end
