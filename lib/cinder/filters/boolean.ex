defmodule Cinder.Filters.Boolean do
  @moduledoc """
  Boolean filter implementation for Cinder tables.

  Provides boolean filtering with radio button inputs for true/false options.
  Delegates rendering to `Cinder.Filters.RadioGroup` with hardcoded true/false options.
  """

  @behaviour Cinder.Filter
  use Cinder.Messages

  import Cinder.Filter

  alias Cinder.Filters.RadioGroup

  @impl true
  def render(column, current_value, theme, assigns) do
    filter_options = Map.get(column, :filter_options, [])
    labels = get_option(filter_options, :labels, %{})

    true_label = Map.get(labels, true, dgettext("cinder", "True"))
    false_label = Map.get(labels, false, dgettext("cinder", "False"))

    # Delegate to RadioGroup with boolean-specific options
    radio_column =
      Map.put(column, :filter_options, options: [{true_label, "true"}, {false_label, "false"}])

    RadioGroup.render(radio_column, current_value, theme, assigns)
  end

  @impl true
  def process(raw_value, _column) when is_binary(raw_value) do
    trimmed = String.trim(raw_value)

    case trimmed do
      "true" ->
        %{
          type: :boolean,
          value: true,
          operator: :equals
        }

      "false" ->
        %{
          type: :boolean,
          value: false,
          operator: :equals
        }

      _ ->
        nil
    end
  end

  def process(_raw_value, _column), do: nil

  @impl true
  def validate(value) do
    case value do
      %{type: :boolean, value: val, operator: :equals} when is_boolean(val) ->
        true

      _ ->
        false
    end
  end

  @impl true
  def default_options do
    [
      labels: %{
        true: dgettext("cinder", "True"),
        false: dgettext("cinder", "False")
      }
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

    Cinder.Filter.Helpers.build_ash_filter(query, field, value, :equals)
  end
end
