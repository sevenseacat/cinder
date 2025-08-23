defmodule Cinder.Filters.Checkbox do
  @moduledoc """
  Checkbox filter implementation for Cinder tables.

  Provides single checkbox filtering for boolean and non-boolean fields.
  When checked, applies an equality filter with the configured value.
  When unchecked, no filter is applied (shows all records).

  ## Examples

      # Boolean field - value defaults to true
      <:col field="published" filter={[type: :checkbox, label: "Show published only"]} />

      # Non-boolean field - explicit value required
      <:col field="status" filter={[type: :checkbox, value: "published", label: "Show published only"]} />

      # Legacy format (still supported)
      <:col field="active" filter={:checkbox} filter_options={[value: true, label: "Active accounts only"]} />

  ## Filter Options

  - `value` - The value to filter by when checked (defaults to `true` for boolean fields)
  - `label` - Display text for the checkbox (required)
  """

  @behaviour Cinder.Filter
  use Phoenix.Component

  require Ash.Query
  import Cinder.Filter

  @impl true
  def render(column, current_value, theme, _assigns) do
    filter_options = Map.get(column, :filter_options, [])
    explicit_label = get_option(filter_options, :label, "")

    # Use explicit label if provided, otherwise use column label as fallback
    label =
      case explicit_label do
        "" -> Map.get(column, :label, "")
        provided_label -> provided_label
      end

    if label == "" do
      raise ArgumentError, """
      Checkbox filter requires either a 'label' option or column must have a label.

      Example: filter={[type: :checkbox, label: "Show published only"]}
      Or: <:col field="published" label="Published" filter={[type: :checkbox]} />
      """
    end

    # Determine if checkbox should be checked based on current value
    filter_value = get_filter_value(filter_options, column)
    checked = current_value != nil and to_string(current_value) == to_string(filter_value)

    assigns = %{
      column: column,
      label: label,
      checked: checked,
      filter_value: filter_value,
      theme: theme
    }

    ~H"""
    <div class={@theme.filter_checkbox_container_class} {@theme.filter_checkbox_container_data}>
      <label class="flex items-center cursor-pointer">
        <input
          type="checkbox"
          name={field_name(@column.field)}
          value={to_string(@filter_value)}
          checked={@checked}
          class={@theme.filter_checkbox_input_class}
          {@theme.filter_checkbox_input_data}
        />
        <span class={@theme.filter_checkbox_label_class} {@theme.filter_checkbox_label_data}>
          {@label}
        </span>
      </label>
    </div>
    """
  end

  @impl true
  def process(raw_value, column) when is_binary(raw_value) do
    trimmed = String.trim(raw_value)

    if trimmed == "" do
      nil
    else
      filter_options = Map.get(column, :filter_options, [])
      filter_value = get_filter_value(filter_options, column)

      # Only process if the raw value matches our expected filter value
      if to_string(trimmed) == to_string(filter_value) do
        %{
          type: :checkbox,
          value: filter_value,
          operator: :equals
        }
      else
        nil
      end
    end
  end

  def process(_raw_value, _column), do: nil

  @impl true
  def validate(value) do
    case value do
      %{type: :checkbox, value: _val, operator: :equals} ->
        true

      _ ->
        false
    end
  end

  @impl true
  def default_options do
    [
      label: "",
      value: true
    ]
  end

  @impl true
  def empty?(value) do
    case value do
      nil -> true
      "" -> true
      %{value: nil} -> true
      _ -> false
    end
  end

  @impl true
  def build_query(query, field, filter_value) do
    %{value: value} = filter_value

    # Use the centralized helper which supports direct, relationship, and embedded fields
    # Convert field to string as expected by the helper
    field_string = if is_atom(field), do: Atom.to_string(field), else: field
    Cinder.Filter.Helpers.build_ash_filter(query, field_string, value, :equals)
  end

  # Private helper to determine the filter value
  # For boolean fields, defaults to true unless explicitly specified
  # For non-boolean fields, requires explicit value
  defp get_filter_value(filter_options, column) do
    explicit_value = get_option(filter_options, :value, nil)

    case explicit_value do
      nil ->
        # No explicit value - infer based on field type
        if is_boolean_field?(column) do
          true
        else
          raise ArgumentError, """
          Checkbox filter for non-boolean field '#{column.field}' requires explicit 'value' option.

          Example: filter={[type: :checkbox, value: "published", label: "Show published only"]}
          """
        end

      value ->
        value
    end
  end

  # Check if this is a boolean field by looking at filter_type
  defp is_boolean_field?(column) do
    Map.get(column, :filter_type) == :boolean
  end
end
