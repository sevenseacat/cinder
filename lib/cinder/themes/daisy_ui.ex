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
    set :controls_class, "card-body pb-4"
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
    set :filter_inputs_class, "grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 px-6 pb-6"
    set :filter_input_wrapper_class, "form-control w-full"
    set :filter_label_class, "label"

    set :filter_placeholder_class,
        "text-base-content/40 italic p-3 border border-base-300 rounded bg-base-200"

    set :filter_clear_button_class, "btn btn-ghost btn-xs ml-2"

    # Input styling
    set :filter_text_input_class, "input input-bordered w-full"
    set :filter_date_input_class, "input input-bordered w-full"
    set :filter_number_input_class, "input input-bordered w-full"
    set :filter_select_input_class, "select select-bordered w-full"

    # Boolean filter
    set :filter_boolean_container_class, "flex gap-4"
    set :filter_boolean_option_class, "flex items-center gap-2"
    set :filter_boolean_radio_class, "radio radio-primary"
    set :filter_boolean_label_class, "label-text cursor-pointer"

    # Multi-select filter
    set :filter_multiselect_container_class, "space-y-2"
    set :filter_multiselect_option_class, "flex items-center gap-2"
    set :filter_multiselect_checkbox_class, "checkbox checkbox-primary"
    set :filter_multiselect_label_class, "label-text cursor-pointer"

    # Range filters
    set :filter_range_container_class, "flex gap-2"
    set :filter_range_input_group_class, "flex-1"
  end

  component Cinder.Components.Pagination do
    set :pagination_wrapper_class, "card bg-base-100 shadow-lg mt-6 p-6"
    set :pagination_container_class, "flex items-center justify-between"
    set :pagination_button_class, "btn btn-outline btn-sm"
    set :pagination_info_class, "text-base-content/70 text-sm"
    set :pagination_count_class, "text-base-content/50 text-xs ml-2"
  end

  component Cinder.Components.Sorting do
    set :sort_indicator_class, "ml-2 inline-flex items-center"
    set :sort_arrow_wrapper_class, "inline-flex items-center ml-1"
    set :sort_asc_icon_class, "w-4 h-4 text-primary"
    set :sort_desc_icon_class, "w-4 h-4 text-primary"
    set :sort_none_icon_class, "w-4 h-4 text-base-content/30"
  end

  component Cinder.Components.Loading do
    set :loading_overlay_class, "absolute top-4 right-4"
    set :loading_container_class, "flex items-center text-sm text-primary"
    set :loading_spinner_class, "loading loading-spinner loading-sm mr-2"
    set :loading_spinner_circle_class, ""
    set :loading_spinner_path_class, ""
  end
end
