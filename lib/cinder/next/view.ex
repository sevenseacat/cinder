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
      columns: Enum.map(config.columns, &column(&1, state, myself)),
      rows: rows(page),
      pagination: pagination(page, state, myself)
    }
  end

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
