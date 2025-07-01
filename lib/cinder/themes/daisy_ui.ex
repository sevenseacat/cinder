defmodule Cinder.Themes.DaisyUI do
  @moduledoc """
  A DaisyUI-compatible theme following daisyUI design system.

  Features:
  - Clean, semantic class names compatible with daisyUI
  - Consistent spacing and typography
  - Table components using daisyUI table classes
  - Form inputs using daisyUI input classes
  - Button styling with daisyUI button classes
  """

  use Cinder.Theme

  component Cinder.Components.Table do
    set :container_class, "card bg-base-100 shadow-xl"
    set :controls_class, "pb-4"
    set :table_wrapper_class, "overflow-x-auto"
    set :table_class, "table table-zebra w-full"
    set :thead_class, ""
    set :tbody_class, ""
    set :header_row_class, ""
    set :row_class, ""
    set :th_class, "text-left font-semibold whitespace-nowrap"
    set :td_class, ""
    set :loading_class, "text-center py-8 loading loading-spinner loading-md"
    set :empty_class, "text-center py-8 text-base-content/60"
    set :error_container_class, "alert alert-error"
    set :error_message_class, ""
  end

  component Cinder.Components.Filters do
    set :filter_container_class, "card bg-base-100 shadow-lg mb-6"
    set :filter_header_class, "card-body pb-4 flex flex-row items-center justify-between"
    set :filter_title_class, "card-title"
    set :filter_count_class, "badge badge-primary badge-sm"
    set :filter_clear_all_class, "btn btn-ghost btn-xs"

    set :filter_inputs_class,
        "flow-root px-6 pb-2"

    set :filter_input_wrapper_class, "form-control float-left mr-4 mb-4"

    set :filter_label_class, "label whitespace-nowrap"

    set :filter_placeholder_class,
        "text-base-content/40 italic p-3 border border-base-300 rounded bg-base-200"

    set :filter_clear_button_class, "btn btn-ghost btn-xs ml-2"

    # Input styling
    set :filter_text_input_class, "input input-bordered w-full"
    set :filter_date_input_class, "input input-bordered w-full"

    set :filter_number_input_class,
        "input input-bordered w-20 [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none [-moz-appearance:textfield]"

    set :filter_select_input_class, "select select-bordered w-full"

    # Boolean filter
    set :filter_boolean_container_class, "flex space-x-4 h-[48px] items-center"
    set :filter_boolean_option_class, "flex items-center space-x-2"
    set :filter_boolean_radio_class, "radio radio-sm radio-primary"
    set :filter_boolean_label_class, "text-sm cursor-pointer"

    # Multi-select filter (dropdown interface)
    set :filter_multiselect_container_class, "relative"

    set :filter_multiselect_dropdown_class,
        "absolute z-50 w-full mt-1 bg-base-100 border border-base-300 rounded-box shadow-lg max-h-60 overflow-auto"

    set :filter_multiselect_option_class,
        "px-3 py-2 hover:bg-base-200 border-b border-base-300 last:border-b-0 cursor-pointer"

    set :filter_multiselect_checkbox_class, "checkbox checkbox-sm checkbox-primary mr-2"
    set :filter_multiselect_label_class, "label-text cursor-pointer select-none flex-1"
    set :filter_multiselect_empty_class, "px-3 py-2 text-base-content/50 italic text-sm"

    # Multi-checkboxes filter
    set :filter_multicheckboxes_container_class, "space-y-2"
    set :filter_multicheckboxes_option_class, "flex items-center gap-2"
    set :filter_multicheckboxes_checkbox_class, "checkbox checkbox-primary"
    set :filter_multicheckboxes_label_class, "label-text cursor-pointer"

    # Range filters
    set :filter_range_container_class, "flex items-center gap-2"
    set :filter_range_input_group_class, ""

    set :filter_range_separator_class,
        "flex items-center px-1 text-sm font-medium text-base-content/60"
  end

  component Cinder.Components.Pagination do
    set :pagination_wrapper_class, "p-6 mt-4"
    set :pagination_container_class, "flex items-center justify-between"

    set :pagination_info_class, "text-base-content/70 text-sm"
    set :pagination_count_class, "text-base-content/50 text-xs ml-2"

    set :pagination_nav_class, "flex items-center space-x-1"

    set :pagination_button_class, "btn btn-outline btn-sm"

    set :pagination_current_class, "btn btn-primary btn-sm"
  end

  component Cinder.Components.Cards do
    set :container_class, "card bg-base-100 shadow-xl"
    set :controls_class, "card-body pb-4"
    set :cards_wrapper_class, "card-body pt-0"
    set :cards_grid_class, "grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4"

    set :card_class,
        "card bg-base-100 shadow hover:shadow-lg transition-shadow cursor-pointer"

    # Sort controls
    set :sort_controls_class, "pb-4 border-b border-base-300"
    set :sort_controls_container_class, "flex items-center gap-4"
    set :sort_label_class, "text-base font-semibold text-base-content"
    set :sort_buttons_class, "flex flex-wrap gap-2"
    set :sort_button_class, "btn btn-outline btn-sm"
    set :sort_button_active_class, "btn btn-primary btn-sm"

    # Sort indicators
    set :sort_indicator_class, "ml-2 inline-flex items-center align-baseline"
    set :sort_arrow_wrapper_class, "inline-flex items-center"
    set :sort_asc_icon_name, "hero-chevron-up"
    set :sort_asc_icon_class, "w-3 h-3 text-primary"
    set :sort_desc_icon_name, "hero-chevron-down"
    set :sort_desc_icon_class, "w-3 h-3 text-primary"
    set :sort_none_icon_name, "hero-chevron-up-down"
    set :sort_none_icon_class, "w-3 h-3 text-base-content/60"

    set :loading_class, "text-center py-8 loading loading-spinner loading-md"

    set :loading_overlay_class,
        "absolute inset-0 bg-base-100 bg-opacity-75 flex items-center justify-center rounded-2xl"

    set :loading_spinner_class, "loading loading-spinner loading-lg"
    set :empty_class, "text-center py-16 text-base-content/60 col-span-full"
    set :error_container_class, "alert alert-error"
    set :error_message_class, ""
    set :pagination_wrapper_class, "p-6 mt-4"
  end

  component Cinder.Components.Sorting do
    set :sort_indicator_class, "ml-1 inline-flex items-center align-baseline"
    set :sort_arrow_wrapper_class, "inline-flex items-center"
    set :sort_asc_icon_class, "w-3 h-3 text-primary"
    set :sort_desc_icon_class, "w-3 h-3 text-primary"
    set :sort_none_icon_class, "w-3 h-3 text-base-content/60"
  end

  component Cinder.Components.Loading do
    set :loading_overlay_class, "absolute top-4 right-4"
    set :loading_container_class, "flex items-center text-sm text-primary"
    set :loading_spinner_class, "loading loading-spinner loading-sm mr-2"
    set :loading_spinner_circle_class, ""
    set :loading_spinner_path_class, ""
  end
end
