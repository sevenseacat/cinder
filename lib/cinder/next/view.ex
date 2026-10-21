defmodule Cinder.Next.View do
  @moduledoc """
  Spike: view-models for the new shell's markup. Built from the component's
  assigns and the config's field registry, with no markup of its own. Each part
  comes with ready-to-spread attribute maps that carry its wiring (`phx-click`,
  `phx-value-*`, `phx-target`, ARIA, state), so default and custom markup behave
  the same.
  """
  use Cinder.Messages

  alias Cinder.Next.{Filters, State}
  alias Cinder.QueryBuilder

  @window 2

  @doc "The whole collection's view-model, from the component's assigns."
  def build(%{config: config, state: state, page: page, status: status, myself: myself} = assigns) do
    layout = state.layout || config.default_layout
    filters = for name <- config.filter_order, f = filter(config, name, state, myself), do: f

    %{
      status: status,
      # For components that take an event and target rather than attribute maps
      target: myself,
      form_id: config.form_id,
      attrs: %{"data-cinder" => "collection", "data-state" => to_string(status)},
      # The default toolbar renders inside this form, so it works with any test
      # tooling. Filter inputs also name it in their `form` attribute, so custom
      # layouts can put them anywhere and they still arrive in one `phx-change`.
      form_attrs: %{
        "id" => config.form_id,
        "data-part" => "filter-form",
        "phx-change" => "filter",
        "phx-submit" => "filter",
        "phx-target" => myself
      },
      search: search(config, state, myself),
      filters: Filters.new(filters),
      active_filter_count: Enum.count(filters, & &1.attrs["data-active"]),
      clear_all_attrs: %{
        "type" => "button",
        "data-part" => "clear-all",
        "phx-click" => "clear_all",
        "phx-target" => myself
      },
      sorts: for(name <- config.sort_order, do: sort(config.fields[name], state, myself)),
      sort_select: sort_select(config, state),
      # Tables that only show one sorted column want just the first
      primary_sort: primary_sort(state.sort),
      # The layout showing now. A `<:page>` renders it itself.
      layout: layout,
      layouts: layouts(config.layouts, layout, myself),
      grid_attrs: grid_attrs(config.grid_columns),
      # So `grid/1` can render cards given only the collection
      item_slot: config.item_slot,
      columns: Enum.map(config.columns, &column(&1, config.fields[&1.field], state, myself)),
      rows: rows(page, layout, config.selectable, state, myself),
      selection: selection(config.selectable, page, state, myself),
      bulk_actions: Enum.map(config.bulk_actions, &bulk_action(&1, state, myself)),
      confirmation: confirmation(config.bulk_actions, state, myself),
      # What the last bulk action did: `%{status: :ok | :partial | :error, ...}`
      bulk_result: assigns[:bulk_result],
      pagination: pagination(page, state, myself, config.pagination)
    }
  end

  # A switcher's buttons, only when there's a choice
  defp layouts([_one], _layout, _myself), do: []

  defp layouts(layouts, current, myself) do
    for layout <- layouts do
      %{
        layout: layout,
        label: layout_label(layout),
        active?: layout == current,
        attrs: %{
          "type" => "button",
          "data-part" => "layout",
          "data-layout" => layout,
          "data-active" => layout == current,
          "aria-pressed" => to_string(layout == current),
          "phx-click" => "set_layout",
          "phx-value-layout" => layout,
          "phx-target" => myself
        }
      }
    end
  end

  defp layout_label(:table), do: dgettext("cinder", "Table")
  defp layout_label(:grid), do: dgettext("cinder", "Grid")

  # Column counts go in as CSS variables, which the base CSS reads (with media
  # queries for breakpoints), so no Tailwind classes need generating
  defp grid_attrs(nil), do: %{"data-part" => "grid"}

  defp grid_attrs(count) when is_integer(count) do
    %{"data-part" => "grid", "data-columns" => true, "style" => "--cinder-grid-columns: #{count}"}
  end

  defp grid_attrs(breakpoints) do
    style =
      Enum.map_join(breakpoints, "; ", fn {bp, count} ->
        "--cinder-grid-columns-#{bp}: #{count}"
      end)

    %{"data-part" => "grid", "data-columns" => true, "style" => style}
  end

  # Each declared sort, with the same wiring as a sortable column header, for
  # markup like chips or a segmented control
  defp sort(field, state, myself) do
    direction = QueryBuilder.get_sort_direction(state.sort, field.name)

    %{
      field: field.name,
      label: field.label,
      direction: direction,
      attrs: %{
        "type" => "button",
        "data-part" => "sort",
        "data-active" => direction != nil,
        "phx-click" => "sort",
        "phx-value-field" => field.name,
        "phx-target" => myself
      },
      indicator_attrs: %{
        "data-part" => "sort-indicator",
        "data-direction" => direction,
        "aria-hidden" => "true"
      }
    }
  end

  defp primary_sort([{field, direction} | _]), do: %{field: field, direction: direction}
  defp primary_sort([]), do: nil

  # An exclusive sort as one `<select>`, joined to the collection's form: each
  # field in both directions, with values in the URL's encoding (`price`, `-price`).
  # The arrows avoid new strings to translate, for the spike.
  defp sort_select(%{sort_order: []}, _state), do: nil

  defp sort_select(config, state) do
    current =
      case state.sort do
        [{field, :desc} | _] -> "-" <> field
        [{field, _asc} | _] -> field
        [] -> ""
      end

    options =
      [{"—", ""}] ++
        for name <- config.sort_order,
            label = config.fields[name].label,
            option <- [{"#{label} ↑", name}, {"#{label} ↓", "-" <> name}],
            do: option

    %{
      label: dgettext("cinder", "Sort by:"),
      attrs: %{"data-part" => "sort-select"},
      select_attrs: %{
        "id" => "#{config.form_id}-sort",
        "name" => "sort_by",
        "form" => config.form_id
      },
      options:
        for {label, value} <- options do
          %{label: label, attrs: %{"value" => value, "selected" => value == current}}
        end
    }
  end

  defp search(%{search: %{enabled?: false}}, _state, _myself), do: nil

  defp search(%{search: search, form_id: form_id}, state, myself) do
    %{
      label: search.label,
      value: state.search,
      attrs: %{"data-part" => "search", "data-active" => state.search != ""},
      input_attrs: %{
        "id" => "#{form_id}-search",
        "type" => "search",
        "name" => "search",
        "value" => state.search,
        "placeholder" => search.placeholder,
        "form" => form_id,
        "phx-debounce" => "300"
      },
      clear_attrs: %{
        "type" => "button",
        "data-part" => "search-clear",
        "aria-label" => dgettext("cinder", "Clear search"),
        "hidden" => state.search == "",
        "phx-click" => "clear_filter",
        "phx-value-field" => "search",
        "phx-target" => myself
      }
    }
  end

  @filter_types [:text, :select, :multi_select, :multi_checkboxes, :number_range, :autocomplete]
  @multi_types [:multi_select, :multi_checkboxes]

  # The types the spike renders; the rest are left out of the view-model
  defp filter(config, name, state, myself) do
    %{label: label, filter: filter} = config.fields[name]

    if filter.type in @filter_types do
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

      # What the details of each type's inputs need
      ctx = %{
        name: name,
        label: label,
        filter: filter,
        input_id: input_id,
        form_id: config.form_id,
        described_by: described_by,
        invalid?: errors != [],
        errors: errors,
        used?: used?,
        raw: state.raw
      }

      value =
        if argument?,
          do: state.raw[name] || state.arguments[name] || "",
          else: current_value(filter.type, name, state)

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
        options: options(filter.type, ctx, value),
        attrs: %{
          "data-part" => "filter",
          "data-field" => name,
          "data-filter-type" => filter.type,
          "data-active" => active?,
          "data-invalid" => errors != []
        },
        # Multi filters label a group of checkboxes, so there's no single input to point at
        label_attrs: %{
          "for" => if(filter.type not in @multi_types, do: label_target(filter.type, input_id))
        },
        help_attrs: %{"id" => help_id, "data-part" => "filter-help"},
        error_attrs: %{"id" => error_id, "data-part" => "filter-error", "role" => "alert"},
        input_attrs: input_attrs(filter.type, ctx, value),
        form_field: form_field(filter.type, ctx, value),
        clear_attrs: %{
          "type" => "button",
          "data-part" => "filter-clear",
          "aria-label" => dgettext("cinder", "Clear filter"),
          "hidden" => not active?,
          "phx-click" => "clear_filter",
          "phx-value-field" => name,
          "phx-target" => myself
        }
      }
    end
  end

  defp label_target(:number_range, input_id), do: input_id <> "-min"
  defp label_target(_type, input_id), do: input_id

  # Any of the field's params arrived without LiveView's `_unused_` marker, which it
  # sends for inputs nobody has interacted with yet
  defp used_input?(raw, name) do
    Enum.any?(raw, fn {param, _value} ->
      State.param_field?(param, name) and not Map.has_key?(raw, "_unused_" <> param)
    end)
  end

  # What the inputs show: the raw form input while there is any, else the filter's value
  defp current_value(:number_range, name, state) do
    value = get_in(state.filters, [name, :value]) || %{}

    %{
      min: state.raw[name <> "_min"] || to_string(value[:min] || ""),
      max: state.raw[name <> "_max"] || to_string(value[:max] || "")
    }
  end

  defp current_value(type, name, state) when type in @multi_types do
    case state.raw[name] do
      values when is_list(values) -> values
      _none -> Enum.map(get_in(state.filters, [name, :value]) || [], &to_string/1)
    end
  end

  defp current_value(_type, name, state) do
    case state.raw[name] do
      value when is_binary(value) -> value
      _none -> to_string(get_in(state.filters, [name, :value]) || "")
    end
  end

  defp input_attrs(:text, ctx, value) do
    %{
      "id" => ctx.input_id,
      "type" => ctx.filter.options[:input_type] || "text",
      "required" => ctx.filter.required?,
      "name" => Cinder.Filter.field_name(ctx.name),
      "value" => value,
      "placeholder" =>
        ctx.filter.options[:placeholder] ||
          dgettext("cinder", "Filter %{label}...", label: ctx.label),
      "form" => ctx.form_id,
      "phx-debounce" => "300",
      "aria-describedby" => ctx.described_by,
      "aria-invalid" => ctx.invalid?
    }
  end

  # `value` is ignored on a real `<select>` (its options' `selected` decides), but it
  # means these attrs keep the filter's state whatever control they're spread on
  defp input_attrs(:select, ctx, value) do
    %{
      "id" => ctx.input_id,
      "name" => Cinder.Filter.field_name(ctx.name),
      "value" => value,
      "form" => ctx.form_id,
      "required" => ctx.filter.required?,
      "aria-describedby" => ctx.described_by,
      "aria-invalid" => ctx.invalid?
    }
  end

  # The search box. What's typed is raw input, so it narrows the options without
  # a query; choosing an option (a radio, below) is what filters.
  defp input_attrs(:autocomplete, ctx, _value) do
    %{
      "id" => ctx.input_id,
      "type" => "search",
      "name" => Cinder.Filter.field_name(ctx.name, "autocomplete_search"),
      "value" => autocomplete_search(ctx),
      "placeholder" =>
        ctx.filter.options[:placeholder] ||
          dgettext("cinder", "Search %{label}...", label: ctx.label),
      "autocomplete" => "off",
      "form" => ctx.form_id,
      "phx-debounce" => "300",
      "aria-describedby" => ctx.described_by,
      "aria-invalid" => ctx.invalid?
    }
  end

  # Each checkbox is an option's `input_attrs`
  defp input_attrs(type, _ctx, _value) when type in @multi_types, do: nil

  # Two inputs, one filter
  defp input_attrs(:number_range, ctx, value) do
    for {bound, placeholder} <- [min: dgettext("cinder", "Min"), max: dgettext("cinder", "Max")],
        into: %{} do
      {bound,
       %{
         "id" => "#{ctx.input_id}-#{bound}",
         "type" => "number",
         "name" => Cinder.Filter.field_name(ctx.name, Atom.to_string(bound)),
         "value" => value[bound],
         "placeholder" => placeholder,
         "step" => ctx.filter.options[:step],
         "form" => ctx.form_id,
         "phx-debounce" => "300",
         "aria-describedby" => ctx.described_by
       }}
    end
  end

  # The filter as `Phoenix.HTML.FormField`s, which component libraries' inputs take
  # (`<.input field={f.form_field} form={c.form_id} />`). Each gets a form whose
  # params mark it used or not, so a component's own `used_input?/1` agrees with ours.
  # An autocomplete's input is its search box, not its value, so it has none.
  defp form_field(:autocomplete, _ctx, _value), do: nil

  defp form_field(:number_range, ctx, value) do
    for bound <- [:min, :max], into: %{} do
      {bound,
       build_form_field(ctx, "#{ctx.name}_#{bound}", "#{ctx.input_id}-#{bound}", value[bound])}
    end
  end

  defp form_field(_type, ctx, value), do: build_form_field(ctx, ctx.name, ctx.input_id, value)

  defp build_form_field(ctx, param, id, value) do
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

  # A select's options, starting with the prompt that clears it. `attrs` are for an
  # `<option>`; `input_attrs` render the same option as a radio button that joins the
  # form, for a button group or radio list instead of a dropdown.
  defp options(:select, ctx, value) do
    prompt = ctx.filter.options[:prompt] || dgettext("cinder", "All %{label}", label: ctx.label)
    choices = [{prompt, ""} | Keyword.get(ctx.filter.options, :options, [])]

    for {{label, option_value}, index} <- Enum.with_index(choices) do
      option_value = to_string(option_value)
      selected? = option_value == value

      %{
        label: label,
        value: option_value,
        selected?: selected?,
        attrs: %{"value" => option_value, "selected" => selected?},
        input_attrs: %{
          "type" => "radio",
          "id" => "#{ctx.input_id}-#{index}",
          "name" => Cinder.Filter.field_name(ctx.name),
          "value" => option_value,
          "checked" => selected?,
          "form" => ctx.form_id,
          "aria-label" => label
        }
      }
    end
  end

  # Checkboxes posting a list (`filters[tags][]`), so several can be chosen
  defp options(type, ctx, values) when type in @multi_types do
    for {{label, option_value}, index} <-
          Enum.with_index(Keyword.get(ctx.filter.options, :options, [])) do
      option_value = to_string(option_value)
      selected? = option_value in values

      %{
        label: label,
        value: option_value,
        selected?: selected?,
        attrs: %{"value" => option_value, "selected" => selected?},
        input_attrs: %{
          "type" => "checkbox",
          "id" => "#{ctx.input_id}-#{index}",
          "name" => Cinder.Filter.field_name(ctx.name) <> "[]",
          "value" => option_value,
          "checked" => selected?,
          "form" => ctx.form_id
        }
      }
    end
  end

  # The options matching what's been typed, up to `max_results`. The chosen one is
  # always included, even when the search no longer matches it: its radio is what
  # posts the filter's value, so dropping it would clear the filter on the next change.
  defp options(:autocomplete, ctx, value) do
    search = autocomplete_search(ctx) |> String.downcase()
    all = Keyword.get(ctx.filter.options, :options, [])

    matching =
      all
      |> Enum.filter(fn {label, _value} -> String.contains?(String.downcase(label), search) end)
      |> Enum.take(ctx.filter.options[:max_results] || 10)

    chosen = Enum.filter(all, fn {_label, option_value} -> to_string(option_value) == value end)

    for {{label, option_value}, index} <- Enum.with_index(Enum.uniq(chosen ++ matching)) do
      option_value = to_string(option_value)
      selected? = option_value == value

      %{
        label: label,
        value: option_value,
        selected?: selected?,
        attrs: %{"value" => option_value, "selected" => selected?},
        input_attrs: %{
          "type" => "radio",
          "id" => "#{ctx.input_id}-#{index}",
          "name" => Cinder.Filter.field_name(ctx.name),
          "value" => option_value,
          "checked" => selected?,
          "form" => ctx.form_id
        }
      }
    end
  end

  defp options(_type, _ctx, _value), do: []

  defp autocomplete_search(ctx), do: ctx.raw[ctx.name <> "_autocomplete_search"] || ""

  defp column(column, field, state, myself) do
    sortable? = field.sort != nil
    direction = sortable? && QueryBuilder.get_sort_direction(state.sort, column.field)

    %{
      field: column.field,
      label: column.label,
      slot: column.slot,
      sortable?: sortable?,
      direction: direction,
      attrs: %{
        "data-part" => "header-cell",
        "data-field" => column.field,
        "data-sortable" => sortable?,
        "aria-sort" => sortable? && aria_sort(direction)
      },
      sort_attrs: %{
        "type" => "button",
        "data-part" => "sort",
        "phx-click" => "sort",
        "phx-value-field" => column.field,
        "phx-target" => myself
      },
      indicator_attrs: %{
        "data-part" => "sort-indicator",
        "data-direction" => direction,
        "aria-hidden" => "true"
      }
    }
  end

  defp aria_sort(:asc), do: "ascending"
  defp aria_sort(:desc), do: "descending"
  defp aria_sort(_), do: "none"

  defp rows(nil, _layout, _selectable, _state, _myself), do: []

  defp rows(%{results: results}, layout, selectable, state, myself) do
    part = if layout == :grid, do: "item", else: "row"

    for record <- results do
      id = to_string(Map.get(record, :id))
      selected? = MapSet.member?(state.selected, id)

      %{
        record: record,
        selected?: selected?,
        attrs: %{"data-part" => part, "data-row-id" => id, "data-selected" => selected?},
        # A checkbox, though not a form input: it toggles by click
        select_attrs:
          selectable != false &&
            %{
              "type" => "checkbox",
              "data-part" => "select",
              "checked" => selected?,
              "disabled" => not selectable?(selectable, record),
              "aria-label" => dgettext("cinder", "Select"),
              "phx-click" => "toggle_select",
              "phx-value-id" => id,
              "phx-target" => myself
            }
      }
    end
  end

  @doc "Whether a record can be selected, given the collection's `selectable`."
  def selectable?(false, _record), do: false
  def selectable?(true, _record), do: true
  def selectable?(fun, record) when is_function(fun, 1), do: !!fun.(record)

  # The page checkbox reads all, some or none of the page's selectable rows
  defp selection(false, _page, _state, _myself), do: nil

  defp selection(selectable, page, state, myself) do
    page_ids =
      for record <- (page && page.results) || [],
          selectable?(selectable, record),
          do: to_string(record.id)

    on_page = Enum.count(page_ids, &MapSet.member?(state.selected, &1))

    page_state =
      cond do
        page_ids == [] or on_page == 0 -> :none
        on_page == length(page_ids) -> :all
        true -> :some
      end

    count = MapSet.size(state.selected)

    %{
      count: count,
      summary: dgettext("cinder", "%{count} selected", count: count),
      page_state: page_state,
      # `data-state="some"` is for styling the in-between state, which HTML can only
      # set from JS (`indeterminate`)
      page_attrs: %{
        "type" => "checkbox",
        "data-part" => "select-page",
        "data-state" => page_state,
        "checked" => page_state == :all,
        "disabled" => page_ids == [],
        "aria-label" => dgettext("cinder", "Select page"),
        "phx-click" => "toggle_select_page",
        "phx-target" => myself
      },
      clear_attrs: %{
        "type" => "button",
        "data-part" => "clear-selection",
        "hidden" => count == 0,
        "phx-click" => "clear_selection",
        "phx-target" => myself
      }
    }
  end

  defp bulk_action(action, state, myself) do
    %{
      name: action.name,
      label: action.label,
      attrs: %{
        "type" => "button",
        "data-part" => "bulk-action",
        "data-action" => action.name,
        "disabled" => MapSet.size(state.selected) == 0,
        "phx-click" => "bulk_action",
        "phx-value-name" => action.name,
        "phx-target" => myself
      }
    }
  end

  # A pending action's question, for the layout to show however it likes (a modal,
  # an inline bar). Confirming runs whatever the server has pending, not anything
  # the client names.
  defp confirmation(actions, %{pending_action: name} = state, myself) when name != nil do
    action = Enum.find(actions, &(&1.name == name))

    %{
      action: action.label,
      message: String.replace(action.confirm, "{count}", to_string(MapSet.size(state.selected))),
      attrs: %{"data-part" => "confirmation", "role" => "alertdialog"},
      confirm_attrs: %{
        "type" => "button",
        "data-part" => "confirm",
        "phx-click" => "confirm_action",
        "phx-target" => myself
      },
      cancel_attrs: %{
        "type" => "button",
        "data-part" => "cancel",
        "phx-click" => "cancel_action",
        "phx-target" => myself
      }
    }
  end

  defp confirmation(_actions, _state, _myself), do: nil

  # Offset pages only, for the spike. A page without a count (`count: false`)
  # gets previous/next but no numbers or total.
  defp pagination(%Ash.Page.Offset{} = page, state, myself, :offset) do
    current = state.page
    page_count = page.count && max(div(page.count + page.limit - 1, page.limit), 1)
    from = page.offset + 1
    to = page.offset + length(page.results)

    %{
      page: current,
      page_count: page_count,
      total: page.count,
      summary:
        page.count &&
          dgettext("cinder", "showing %{start}-%{end} of %{total}",
            start: from,
            end: to,
            total: page.count
          ),
      # No aria-label yet: it would be a new string to translate into every locale
      attrs: %{"data-part" => "pagination"},
      prev: page_link(:prev, current - 1, current <= 1, myself),
      next: page_link(:next, current + 1, not page.more?, myself),
      pages: numbered_pages(current, page_count, myself)
    }
  end

  # Keyset pages have no numbers: previous and next carry the first and last records'
  # cursors. Matched on the mode, not the page struct, because a keyset action's first
  # page can arrive as an `Ash.Page.Offset` (its records still carry keyset metadata).
  # `more?` says whether there are more records in the direction just paged.
  defp pagination(%{results: results, more?: more?}, state, myself, :keyset) do
    {prev?, next?} =
      case state.cursor do
        nil -> {false, more?}
        {:after, _} -> {true, more?}
        {:before, _} -> {more?, true}
      end

    %{
      page: nil,
      page_count: nil,
      total: nil,
      summary: nil,
      attrs: %{"data-part" => "pagination"},
      prev: cursor_link(:prev, :before, List.first(results), not prev?, myself),
      next: cursor_link(:next, :after, List.last(results), not next?, myself),
      pages: []
    }
  end

  defp pagination(_page, _state, _myself, _mode), do: nil

  defp cursor_link(kind, direction, record, disabled?, myself) do
    cursor = record && record.__metadata__[:keyset]
    disabled? = disabled? or is_nil(cursor)

    %{
      kind: kind,
      label: page_label(kind, nil),
      current?: false,
      disabled?: disabled?,
      attrs: %{
        "type" => "button",
        "data-part" => "page",
        "data-kind" => kind,
        "aria-label" => page_aria_label(kind, nil),
        "disabled" => disabled?,
        "phx-click" => "go_to_cursor",
        "phx-value-#{direction}" => cursor,
        "phx-target" => myself
      }
    }
  end

  defp numbered_pages(_current, nil, _myself), do: []

  defp numbered_pages(current, page_count, myself) do
    window = max(1, current - @window)..min(page_count, current + @window)//1

    [1 | Enum.to_list(window)]
    |> Kernel.++([page_count])
    |> Enum.uniq()
    |> Enum.chunk_every(2, 1)
    |> Enum.flat_map(fn
      [a, b] when b > a + 1 -> [page_link(:page, a, false, myself, current), gap()]
      [a | _] -> [page_link(:page, a, false, myself, current)]
    end)
  end

  defp page_link(kind, number, disabled?, myself, current \\ nil) do
    current? = kind == :page and number == current

    %{
      kind: kind,
      number: number,
      label: page_label(kind, number),
      current?: current?,
      disabled?: disabled?,
      attrs: %{
        "type" => "button",
        "data-part" => "page",
        "data-kind" => kind,
        "data-active" => current?,
        "aria-current" => current? && "page",
        "aria-label" => page_aria_label(kind, number),
        "disabled" => disabled?,
        "phx-click" => "go_to_page",
        "phx-value-page" => number,
        "phx-target" => myself
      }
    }
  end

  defp gap do
    %{kind: :gap, label: "…", attrs: %{"data-part" => "page", "data-kind" => "gap"}}
  end

  defp page_label(:prev, _), do: "‹"
  defp page_label(:next, _), do: "›"
  defp page_label(:page, number), do: to_string(number)

  defp page_aria_label(:prev, _), do: dgettext("cinder", "Previous page")
  defp page_aria_label(:next, _), do: dgettext("cinder", "Next page")
  defp page_aria_label(:page, number), do: dgettext("cinder", "Go to page %{page}", page: number)

  @doc "A record's value for a column field, following `.` into relationships."
  def field_value(record, field) do
    field
    |> String.split(".")
    |> Enum.reduce(record, fn key, acc -> acc && Map.get(acc, String.to_existing_atom(key)) end)
  end
end
