defmodule Cinder.Next.ThemeCss do
  @moduledoc """
  Spike: converts an Elixir theme (`Cinder.Theme`) into a CSS theme for
  `Cinder.Next`, as a stopgap for upgrading apps. Each theme key that has a part in
  the new shell becomes a rule on its `cinder-*` class that `@apply`s the key's
  Tailwind classes; anyone with an Elixir theme already uses Tailwind, so `@apply`
  is fine here (the themes Cinder ships are plain CSS instead). Keys with no part
  are listed in a comment at the end, so nothing is dropped silently.

  The output needs a look in the browser, not just a build: classes that relied on
  the old markup's structure (`divide-y` on a body, `[&>*:first-child]:...` on the
  container) compile, but may not land where they did.
  """

  # Theme key => the selector it styles in the new shell. Several keys can style
  # one part (a button's base and variant); their rules come out in this order.
  @selectors [
    container_class: ".cinder",
    controls_class: ".cinder-toolbar",
    filter_inputs_class: ".cinder-toolbar",
    filter_input_wrapper_class: ":is(.cinder-filter, .cinder-search, .cinder-sort-select)",
    filter_label_class: ":is(.cinder-filter, .cinder-search, .cinder-sort-select) > label",
    filter_clear_button_class: ":is(.cinder-filter-clear, .cinder-search-clear)",
    search_input_class: ".cinder-search input",
    filter_text_input_class: ".cinder-filter > input",
    filter_select_input_class: ":is(.cinder-filter, .cinder-sort-select) select",
    filter_number_input_class: ".cinder-filter-range input",
    filter_range_container_class: ".cinder-filter-range",
    filter_range_separator_class: ".cinder-filter-range > span",
    filter_multicheckboxes_container_class: "fieldset.cinder-filter",
    filter_multicheckboxes_option_class: ".cinder-filter-option",
    filter_multicheckboxes_checkbox_class: ".cinder-filter-option input",
    table_class: ".cinder-table",
    thead_class: ".cinder-table thead",
    tbody_class: ".cinder-table tbody",
    header_row_class: ".cinder-table thead tr",
    th_class: ".cinder-header-cell",
    td_class: ".cinder-cell",
    row_class: ".cinder-row",
    selected_row_class: ".cinder-row[data-selected]",
    sort_indicator_class: ".cinder-sort-indicator",
    sort_none_icon_class: ".cinder-sort-indicator:not([data-direction])",
    sort_asc_icon_class: ".cinder-sort-indicator[data-direction=\"asc\"]",
    sort_desc_icon_class: ".cinder-sort-indicator[data-direction=\"desc\"]",
    empty_class: ".cinder-empty",
    error_container_class: ".cinder-error",
    grid_container_class: ".cinder-grid",
    grid_item_class: ".cinder-item",
    selected_item_class: ".cinder-item[data-selected]",
    selection_checkbox_class: ":is(.cinder-select, .cinder-select-page)",
    bulk_actions_container_class: ".cinder-bulk-bar",
    pagination_wrapper_class: ".cinder-pagination",
    pagination_container_class: ".cinder-pagination",
    pagination_info_class: ".cinder-summary",
    pagination_button_class: "button.cinder-page",
    pagination_current_class: ".cinder-page[data-active]",
    button_class:
      "button:is(.cinder-layout, .cinder-bulk-action, .cinder-clear-selection, .cinder-confirm, .cinder-cancel)",
    button_secondary_class:
      "button:is(.cinder-layout, .cinder-bulk-action, .cinder-clear-selection, .cinder-cancel)",
    button_danger_class: "button.cinder-confirm",
    button_disabled_class: "button:is(.cinder-layout, .cinder-bulk-action):disabled"
  ]

  @doc """
  The CSS theme for `theme` (anything `Cinder.Theme.merge/1` takes), scoped to
  `[data-cinder-theme="<scope>"]`, or unscoped when `scope` is nil.
  """
  def convert(theme, opts \\ []) do
    classes = Cinder.Theme.merge(theme)
    scope = opts[:scope]

    rules =
      for {key, selector} <- @selectors, value = classes[key], is_binary(value), value != "" do
        "#{selector} {\n  @apply #{value};\n}\n"
      end

    unmapped =
      classes
      |> Enum.reject(fn {key, value} ->
        Keyword.has_key?(@selectors, key) or value in [nil, ""]
      end)
      |> Enum.sort()

    body = Enum.join(rules, "\n")
    body = if scope, do: "[data-cinder-theme=\"#{scope}\"] {\n#{indent(body)}}\n", else: body

    """
    /* Converted from #{inspect(theme)} by `mix cinder.next.convert_theme`. Check it in
     * the browser: some classes relied on the old markup's structure. */
    @layer cinder {
    #{indent(body)}}

    /* Not carried over (no part in the new shell):
    #{Enum.map_join(unmapped, "\n", fn {key, value} -> " * #{key}: #{value}" end)}
     */
    """
  end

  defp indent(text),
    do: text |> String.split("\n") |> Enum.map_join("\n", &if(&1 == "", do: "", else: "  " <> &1))
end
