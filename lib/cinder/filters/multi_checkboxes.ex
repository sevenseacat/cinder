defmodule Cinder.Filters.MultiCheckboxes do
  @moduledoc """
  Multi-checkbox filter implementation for Cinder tables.

  Provides multiple selection filtering with a checkbox for each option. Apart from how it
  renders, it works exactly like `Cinder.Filters.MultiSelect`: the same options
  (`options`, `match_mode`), the same handling of values from the client, and the same
  matching on array fields and through relationships.

      <:col
        field="tags"
        filter={[
          type: :multi_checkboxes,
          options: [{"Fiction", "fiction"}, {"Bestseller", "bestseller"}],
          match_mode: :all
        ]}
      />
  """

  @behaviour Cinder.Filter
  use Phoenix.Component

  import Cinder.Filter

  alias Cinder.Filters.MultiSelect

  @impl true
  def render(column, current_value, theme, _assigns) do
    filter_options = Map.get(column, :filter_options, [])
    options = get_option(filter_options, :options, [])
    selected_values = current_value || []

    assigns = %{
      column: column,
      selected_values: selected_values,
      options: options,
      theme: theme
    }

    ~H"""
    <div class={@theme.filter_multicheckboxes_container_class} data-key="filter_multicheckboxes_container_class">
      <div :for={{label, value} <- @options} class={@theme.filter_multicheckboxes_option_class} data-key="filter_multicheckboxes_option_class">
        <label class="flex items-center cursor-pointer">
          <input
            type="checkbox"
            name={field_name(@column.field) <> "[]"}
            value={to_string(value)}
            checked={to_string(value) in Enum.map(@selected_values, &to_string/1)}
            class={@theme.filter_multicheckboxes_checkbox_class}
            data-key="filter_multicheckboxes_checkbox_class"
          />
          <span class={@theme.filter_multicheckboxes_label_class} data-key="filter_multicheckboxes_label_class">{label}</span>
        </label>
      </div>
    </div>
    """
  end

  @impl true
  def process(raw_value, column), do: MultiSelect.process(raw_value, column, :multi_checkboxes)

  @impl true
  def validate(value), do: MultiSelect.validate(value, :multi_checkboxes)

  # No prompt: there's no dropdown to show one in
  @impl true
  def default_options, do: Keyword.delete(MultiSelect.default_options(), :prompt)

  @impl true
  defdelegate empty?(value), to: MultiSelect

  @impl true
  defdelegate build_query(query, field, filter_value), to: MultiSelect
end
