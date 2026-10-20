defmodule Cinder.Next.View do
  @moduledoc """
  Spike: view-models for the new shell's markup. Built from the component's
  assigns, with no markup of its own. Each part comes with ready-to-spread
  attribute maps that carry its wiring (`phx-click`, `phx-value-*`,
  `phx-target`, ARIA, state), so default and custom markup behave the same.
  """
  use Cinder.Messages

  alias Cinder.QueryBuilder

  @window 2

  @doc "The whole collection's view-model, from the component's assigns."
  def build(%{config: config, state: state, page: page, status: status, myself: myself}) do
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
      filters:
        for(column <- config.columns, filter = filter(column, config, state, myself), do: filter),
      columns: Enum.map(config.columns, &column(&1, state, myself)),
      rows: rows(page),
      pagination: pagination(page, state, myself)
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
  defp filter(%{filterable: true, filter_type: type} = column, config, state, myself)
       when type in [:text, :select] do
    input_id = Cinder.Filter.filter_id(config.form_id, column.field)
    value = get_in(state.filters, [column.field, :value])
    value = if value, do: to_string(value), else: ""

    %{
      field: column.field,
      label: column.label,
      type: type,
      value: value,
      options: filter_options(column, value),
      attrs: %{
        "data-part" => "filter",
        "data-field" => column.field,
        "data-filter-type" => type,
        "data-active" => value != ""
      },
      label_attrs: %{"for" => input_id},
      input_attrs: filter_input_attrs(type, column, input_id, value, config.form_id),
      clear_attrs: %{
        "type" => "button",
        "data-part" => "filter-clear",
        "aria-label" => dgettext("cinder", "Clear filter"),
        "hidden" => value == "",
        "phx-click" => "clear_filter",
        "phx-value-field" => column.field,
        "phx-target" => myself
      }
    }
  end

  defp filter(_column, _config, _state, _myself), do: nil

  defp filter_input_attrs(:text, column, input_id, value, form_id) do
    %{
      "id" => input_id,
      "type" => "text",
      "name" => Cinder.Filter.field_name(column.field),
      "value" => value,
      "placeholder" =>
        Keyword.get(
          column.filter_options,
          :placeholder,
          dgettext("cinder", "Filter %{label}...", label: column.label)
        ),
      "form" => form_id,
      "phx-debounce" => "300"
    }
  end

  defp filter_input_attrs(:select, column, input_id, _value, form_id) do
    %{"id" => input_id, "name" => Cinder.Filter.field_name(column.field), "form" => form_id}
  end

  # A select's options, starting with the prompt that clears it
  defp filter_options(%{filter_type: :select} = column, value) do
    prompt =
      Keyword.get(
        column.filter_options,
        :prompt,
        dgettext("cinder", "All %{label}", label: column.label)
      )

    options = Keyword.get(column.filter_options, :options, [])

    for {label, option_value} <- [{prompt, ""} | options] do
      option_value = to_string(option_value)
      %{label: label, attrs: %{"value" => option_value, "selected" => option_value == value}}
    end
  end

  defp filter_options(_column, _value), do: []

  defp column(column, state, myself) do
    direction = column.sortable && QueryBuilder.get_sort_direction(state.sort, column.field)

    %{
      field: column.field,
      label: column.label,
      slot: column.slot,
      sortable?: column.sortable,
      direction: direction,
      attrs: %{
        "data-part" => "header-cell",
        "data-field" => column.field,
        "data-sortable" => column.sortable,
        "aria-sort" => column.sortable && aria_sort(direction)
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

  defp rows(nil), do: []

  defp rows(%{results: results}) do
    for record <- results do
      %{
        record: record,
        attrs: %{"data-part" => "row", "data-row-id" => to_string(Map.get(record, :id))}
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
