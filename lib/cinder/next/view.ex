defmodule Cinder.Next.View do
  @moduledoc """
  Spike: view-models for the new shell's markup. Built from the component's
  assigns and the config's field registry, with no markup of its own. Each part
  comes with ready-to-spread attribute maps that carry its wiring (`phx-click`,
  `phx-value-*`, `phx-target`, ARIA, state), so default and custom markup behave
  the same.
  """
  use Cinder.Messages

  alias Cinder.QueryBuilder

  @window 2

  @doc "The whole collection's view-model, from the component's assigns."
  def build(%{config: config, state: state, page: page, status: status, myself: myself}) do
    filters = for name <- config.filter_order, f = filter(config, name, state, myself), do: f

    %{
      status: status,
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
      filters: filters,
      filters_by_field: Map.new(filters, &{&1.field, &1}),
      active_filter_count: Enum.count(filters, & &1.attrs["data-active"]),
      clear_all_attrs: %{
        "type" => "button",
        "data-part" => "clear-all",
        "phx-click" => "clear_all",
        "phx-target" => myself
      },
      sorts: for(name <- config.sort_order, do: sort(config.fields[name], state, myself)),
      sort_select: sort_select(config, state),
      layout: config.layout,
      grid_attrs: grid_attrs(config.grid_columns),
      # So `grid/1` can render cards given only the collection
      item_slot: config.item_slot,
      columns: Enum.map(config.columns, &column(&1, config.fields[&1.field], state, myself)),
      rows: rows(page, config.layout),
      pagination: pagination(page, state, myself)
    }
  end

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

  # Text and select only, for the spike
  defp filter(config, name, state, myself) do
    %{label: label, filter: filter} = config.fields[name]

    if filter.type in [:text, :select] do
      input_id = Cinder.Filter.filter_id(config.form_id, name)
      help_id = "#{input_id}-help"
      value = get_in(state.filters, [name, :value])
      value = if value, do: to_string(value), else: ""

      %{
        field: name,
        label: label,
        type: filter.type,
        value: value,
        help: filter.help,
        render: filter.render,
        options: filter_options(filter, label, value, name, input_id, config.form_id),
        attrs: %{
          "data-part" => "filter",
          "data-field" => name,
          "data-filter-type" => filter.type,
          "data-active" => value != ""
        },
        label_attrs: %{"for" => input_id},
        help_attrs: %{"id" => help_id, "data-part" => "filter-help"},
        input_attrs:
          filter.type
          |> filter_input_attrs(name, label, filter, input_id, value, config.form_id)
          |> Map.put("aria-describedby", filter.help && help_id),
        clear_attrs: %{
          "type" => "button",
          "data-part" => "filter-clear",
          "aria-label" => dgettext("cinder", "Clear filter"),
          "hidden" => value == "",
          "phx-click" => "clear_filter",
          "phx-value-field" => name,
          "phx-target" => myself
        }
      }
    end
  end

  defp filter_input_attrs(:text, name, label, filter, input_id, value, form_id) do
    %{
      "id" => input_id,
      "type" => "text",
      "name" => Cinder.Filter.field_name(name),
      "value" => value,
      "placeholder" =>
        filter.options[:placeholder] || dgettext("cinder", "Filter %{label}...", label: label),
      "form" => form_id,
      "phx-debounce" => "300"
    }
  end

  defp filter_input_attrs(:select, name, _label, _filter, input_id, _value, form_id) do
    %{"id" => input_id, "name" => Cinder.Filter.field_name(name), "form" => form_id}
  end

  # A select's options, starting with the prompt that clears it. `attrs` are for an
  # `<option>`; `input_attrs` render the same option as a radio button that joins the
  # form, for a button group or radio list instead of a dropdown.
  defp filter_options(%{type: :select, options: options}, label, value, name, input_id, form_id) do
    prompt = options[:prompt] || dgettext("cinder", "All %{label}", label: label)

    for {{option_label, option_value}, index} <-
          Enum.with_index([{prompt, ""} | Keyword.get(options, :options, [])]) do
      option_value = to_string(option_value)
      selected? = option_value == value

      %{
        label: option_label,
        value: option_value,
        selected?: selected?,
        attrs: %{"value" => option_value, "selected" => selected?},
        input_attrs: %{
          "type" => "radio",
          "id" => "#{input_id}-#{index}",
          "name" => Cinder.Filter.field_name(name),
          "value" => option_value,
          "checked" => selected?,
          "form" => form_id,
          "aria-label" => option_label
        }
      }
    end
  end

  defp filter_options(_filter, _label, _value, _name, _input_id, _form_id), do: []

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

  defp rows(nil, _layout), do: []

  defp rows(%{results: results}, layout) do
    part = if layout == :grid, do: "item", else: "row"

    for record <- results do
      %{
        record: record,
        attrs: %{"data-part" => part, "data-row-id" => to_string(Map.get(record, :id))}
      }
    end
  end

  # Offset pages only, for the spike. A page without a count (`count: false`)
  # gets previous/next but no numbers or total.
  defp pagination(%Ash.Page.Offset{} = page, state, myself) do
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

  defp pagination(_page, _state, _myself), do: nil

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
