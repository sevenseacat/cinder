defmodule Cinder.Next.FilterView do
  @moduledoc """
  Spike: a filter's view-model, and the helpers its type uses to add to it.

  Every filter gets the same view-model: its label, help, errors, value and state,
  and attribute maps for its wrapper, label, help, errors and clear button, plus one
  generic text input (`input_attrs`, `form_field`). A filter type with nothing more
  to say renders as that input.

  A type adds its own parts with the optional `c:Cinder.Filter.view/2` callback,
  which gets the view-model and this module's context (below), and returns the
  view-model with its additions: a slider sets `"type" => "range"` and its bounds
  on `input_attrs`; a select adds `options` from `choices/4`; a range replaces
  `input_attrs` and `form_field` with one per bound. The optional
  `c:Cinder.Filter.control/1` function component renders the type's controls
  from `@filter`; without one, the default markup renders `input_attrs` as an
  `<input>`.

  The context: `name` (the field), `label`, `options` (the declared options),
  `input_id`, `form_id`, `described_by`, `invalid?`, `errors`, `used?`,
  `required?`, `raw` (the form's raw params) and `filter_value` (the processed
  filter, or nil).
  """
  use Cinder.Messages

  alias Cinder.Next.State

  @doc "The view-model for the field `name`'s filter."
  def build(config, name, state, event, target) do
    %{label: label, filter: filter} = config.fields[name]
    input_id = Cinder.Filter.filter_id(config.form_id, name)
    help_id = "#{input_id}-help"
    error_id = "#{input_id}-error"
    argument? = filter.source == :argument

    # An argument's value goes to the read action, not into the filters
    active? = Map.has_key?(if(argument?, do: state.arguments, else: state.filters), name)

    # Like Phoenix's `used_input?/1`: errors show only once the input has been
    # used (or has a value), so nothing is flagged before anyone has typed
    used? = active? or used_input?(state.raw, name)
    errors = if used?, do: Map.get(state.errors, name, []), else: []

    described_by =
      [filter.help && help_id, errors != [] && error_id]
      |> Enum.filter(& &1)
      |> Enum.join(" ")
      |> then(&if(&1 == "", do: nil, else: &1))

    ctx = %{
      name: name,
      label: label,
      options: filter.options,
      input_id: input_id,
      form_id: config.form_id,
      described_by: described_by,
      invalid?: errors != [],
      errors: errors,
      used?: used?,
      required?: filter.required?,
      raw: state.raw,
      filter_value: state.filters[name]
    }

    value =
      if argument?,
        do: state.raw[name] || state.arguments[name] || "",
        else: text_value(ctx)

    module = Cinder.Filters.Registry.get_filter(filter.type)

    %{
      field: name,
      # The param name, for components that build their own inputs from it (a
      # checkbox group appends `[]`; a range, `_min` and `_max`)
      name: Cinder.Filter.field_name(name),
      label: label,
      type: filter.type,
      value: value,
      active?: active?,
      required?: filter.required?,
      used?: used?,
      help: filter.help,
      errors: errors,
      render: filter.render,
      # The type's `control/1`, if it has one, for the default markup
      control: control(module),
      # A group of inputs (checkboxes, radios) is labelled by a legend, not a label
      group?: false,
      options: [],
      attrs: %{
        "data-field" => name,
        "data-filter-type" => filter.type,
        "data-active" => active?,
        "data-invalid" => errors != []
      },
      label_attrs: %{"for" => input_id},
      help_attrs: %{"id" => help_id},
      error_attrs: %{"id" => error_id, "role" => "alert"},
      input_attrs: %{
        "id" => input_id,
        "type" => "text",
        "name" => Cinder.Filter.field_name(name),
        "value" => value,
        "required" => filter.required?,
        "form" => config.form_id,
        "phx-debounce" => "300",
        "aria-describedby" => described_by,
        "aria-invalid" => errors != []
      },
      form_field: form_field(ctx, name, input_id, value),
      clear_attrs: %{
        "type" => "button",
        "aria-label" => dgettext("cinder", "Clear filter"),
        "hidden" => not active?,
        "phx-click" => event.("clear_filter"),
        "phx-value-field" => name,
        "phx-target" => target
      }
    }
    |> then(
      &if(module && function_exported?(module, :view, 2), do: module.view(&1, ctx), else: &1)
    )
  end

  defp control(module) do
    if module && function_exported?(module, :control, 1), do: &module.control/1
  end

  # Any of the field's params arrived without LiveView's `_unused_` marker, which it
  # sends for inputs nobody has interacted with yet
  defp used_input?(raw, name) do
    Enum.any?(raw, fn {param, _value} ->
      State.param_field?(param, name) and not Map.has_key?(raw, "_unused_" <> param)
    end)
  end

  @doc """
  What a single input shows: the raw form input while there is any, else the
  filter's value as text. A value with parts (a range's, a list) has no text; its
  type sets its own.
  """
  def text_value(ctx) do
    case {ctx.raw[ctx.name], filter_value(ctx)} do
      {raw, _value} when is_binary(raw) -> raw
      {_raw, value} when is_map(value) or is_list(value) -> ""
      {_raw, value} -> to_string(value || "")
    end
  end

  @doc "The processed filter's `value`, or nil."
  def filter_value(ctx), do: get_in(ctx.filter_value, [:value])

  @doc "The raw param `<field>_<suffix>`, like a range's `price_min`."
  def raw(ctx, suffix), do: ctx.raw["#{ctx.name}_#{suffix}"]

  @doc """
  The filter as a `Phoenix.HTML.FormField` for one param, which component libraries'
  inputs take (`<.input field={f.form_field} />`). It gets a form whose params mark
  it used or not, so a component's own `used_input?/1` agrees with ours.
  """
  def form_field(ctx, param, id, value) do
    params = if ctx.used?, do: %{param => value}, else: %{}

    %Phoenix.HTML.FormField{
      id: id,
      name: Cinder.Filter.field_name(param),
      field: param,
      value: value,
      # Already interpolated, in the `{message, opts}` shape components translate
      errors: Enum.map(ctx.errors, &{&1, []}),
      form: Phoenix.Component.to_form(params, as: "filters", id: ctx.form_id)
    }
  end

  @doc """
  Each `{label, value}` choice as an `<option>` (`attrs`) and as a radio or checkbox
  that joins the form (`input_attrs`), selected when `selected?` says so.
  Checkboxes post a list.
  """
  def choices(ctx, choices, input_type, selected?) do
    name = Cinder.Filter.field_name(ctx.name) <> if(input_type == "checkbox", do: "[]", else: "")

    for {{label, option_value}, index} <- Enum.with_index(choices) do
      option_value = to_string(option_value)
      selected? = selected?.(option_value)

      %{
        label: label,
        value: option_value,
        selected?: selected?,
        attrs: %{"value" => option_value, "selected" => selected?},
        input_attrs: %{
          "type" => input_type,
          "id" => "#{ctx.input_id}-#{index}",
          "name" => name,
          "value" => option_value,
          "checked" => selected?,
          "form" => ctx.form_id,
          "aria-label" => label
        }
      }
    end
  end

  @doc """
  The view-model for a list of checkboxes (`options`) posting a list: the value is
  the list chosen, and there's no single input.
  """
  def checkboxes(filter, ctx) do
    values =
      case ctx.raw[ctx.name] do
        values when is_list(values) -> values
        _none -> Enum.map(filter_value(ctx) || [], &to_string/1)
      end

    %{
      filter
      | value: values,
        options: choices(ctx, declared_options(ctx), "checkbox", &(&1 in values)),
        input_attrs: nil,
        form_field: form_field(ctx, ctx.name, ctx.input_id, values)
    }
  end

  @doc "The declared `options:` choices."
  def declared_options(ctx), do: Keyword.get(ctx.options, :options, [])
end
