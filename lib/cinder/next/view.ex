defmodule Cinder.Next.View do
  @moduledoc """
  Spike: view-models for the new shell's markup. Built from the component's
  assigns and the config's field registry, with no markup of its own. Each part
  comes with ready-to-spread attribute maps that carry its wiring (`phx-click`,
  `phx-value-*`, `phx-target`, ARIA, state), so default and custom markup behave
  the same.
  """
  use Cinder.Messages

  alias Cinder.Next.{FilterView, Ordered}
  alias Cinder.QueryBuilder

  @window 2

  @doc "The whole collection's view-model, from the component's assigns."
  def build(%{config: config, state: state, page: page, status: status, myself: myself} = assigns) do
    layout = state.layout || config.default_layout
    rows = rows(page, config.selectable, state, myself)

    sorts =
      Ordered.new(for name <- config.sort_order, do: sort(config.fields[name], state, myself))

    filters =
      for name <- config.filter_order,
          do: FilterView.build(config, name, state, &event(myself, &1), target(myself))

    %{
      status: status,
      # For components that take an event and target rather than attribute maps
      target: target(myself),
      # Prepended to event names when the collection lives in a LiveView
      event_prefix: event(myself, ""),
      form_id: config.form_id,
      # `data-state` drives the structural CSS's loading dim, wherever these attrs go
      attrs: %{"data-cinder" => "collection", "data-state" => to_string(status)},
      # The default toolbar renders inside this form, so it works with any test
      # tooling. Filter inputs also name it in their `form` attribute, so custom
      # layouts can put them anywhere and they still arrive in one `phx-change`.
      form_attrs: %{
        "id" => config.form_id,
        "phx-change" => event(myself, "filter"),
        "phx-submit" => event(myself, "filter"),
        "phx-target" => target(myself)
      },
      search: search(config, state, myself),
      filters: Ordered.new(filters),
      active_filter_count: Enum.count(filters, & &1.active?),
      clear_all_attrs: %{
        "type" => "button",
        "phx-click" => event(myself, "clear_all"),
        "phx-target" => target(myself)
      },
      sorts: sorts,
      sort_select: sort_select(config, state),
      # Tables that only show one sorted column want just the first
      primary_sort: primary_sort(state.sort),
      # The layout showing now
      layout: layout,
      layouts: layouts(config.layouts, layout, myself),
      grid_attrs: grid_attrs(config.grid_columns),
      # So `grid/1` can render cards given only the collection
      item_slot: config.item_slot,
      # The `<:row_action>`s, for the table's last cell (or wherever custom markup puts them)
      row_action_slot: config.row_action_slot,
      columns: Enum.map(config.columns, &column(&1, sorts[&1.field])),
      reorderable?: config.reorderable,
      # The user's column choices; the table arranges its columns by them
      column_prefs: state.columns,
      rows: rows,
      # `nil` unless grouped: then the page's rows by group (see `groups/2`)
      groups: groups(config, rows),
      selection: selection(config.selectable, rows, state, myself),
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
          "data-layout" => layout,
          "data-active" => layout == current,
          "aria-pressed" => to_string(layout == current),
          "phx-click" => event(myself, "set_layout"),
          "phx-value-layout" => layout,
          "phx-target" => target(myself)
        }
      }
    end
  end

  defp layout_label(:table), do: dgettext("cinder", "Table")
  defp layout_label(:grid), do: dgettext("cinder", "Grid")

  # Events go to the LiveComponent (`myself`), or, for a collection kept in a
  # LiveView's assigns (`{:live_view, name}`), to the LiveView, named
  # `cinder:<name>:<event>` so its hook can tell which collection they're for, with
  # no target (`nil` attributes aren't rendered)
  defp event({:live_view, name}, event), do: "cinder:#{name}:" <> event
  defp event(_myself, event), do: event

  defp target({:live_view, _name}), do: nil
  defp target(myself), do: myself

  # Column counts go in as CSS variables, which the base CSS reads (with media
  # queries for breakpoints), so no Tailwind classes need generating
  defp grid_attrs(nil), do: %{}

  defp grid_attrs(count) when is_integer(count) do
    %{"data-columns" => true, "style" => "--cinder-grid-columns: #{count}"}
  end

  defp grid_attrs(breakpoints) do
    style =
      Enum.map_join(breakpoints, "; ", fn {bp, count} ->
        "--cinder-grid-columns-#{bp}: #{count}"
      end)

    %{"data-columns" => true, "style" => style}
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
        "data-active" => direction != nil,
        "phx-click" => event(myself, "sort"),
        "phx-value-field" => field.name,
        "phx-target" => target(myself)
      },
      indicator_attrs: %{
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
      attrs: %{},
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
      attrs: %{"data-active" => state.search != ""},
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
        "aria-label" => dgettext("cinder", "Clear search"),
        "hidden" => state.search == "",
        "phx-click" => event(myself, "clear_filter"),
        "phx-value-field" => "search",
        "phx-target" => target(myself)
      }
    }
  end

  @doc """
  Columns in the user's order (`column_prefs`), each with `visible?`: what the
  user chose, or else whether it's declared `hidden`. Columns the order doesn't
  name (added since it was saved) keep their place after the ones it does.
  """
  def arrange_columns(columns, prefs) do
    order = Map.new(Enum.with_index(prefs.order || []))

    columns
    |> Enum.with_index()
    |> Enum.sort_by(fn {column, index} ->
      case order[column.field] do
        nil -> {1, index}
        position -> {0, position}
      end
    end)
    |> Enum.map(fn {column, _index} ->
      Map.put(column, :visible?, Map.get(prefs.visible, column.field, not column.hidden))
    end)
  end

  @doc """
  The columns control's view-model, from the collection and its arranged columns:
  a popover (`trigger_attrs`, `panel_attrs`, like a multi-select's) of `items`, each
  with a checkbox (`toggle_attrs`) and buttons to move it (`up_attrs`,
  `down_attrs`). The last visible column can't be hidden.
  """
  def columns_control(collection, columns) do
    id = collection.form_id <> "-columns"
    anchor = "--" <> id
    fields = Enum.map(columns, & &1.field)
    visible_count = Enum.count(columns, & &1.visible?)
    last = length(columns) - 1

    %{
      label: dgettext("cinder", "Columns"),
      trigger_attrs: %{
        "type" => "button",
        "id" => id,
        "popovertarget" => id <> "-panel",
        "aria-haspopup" => "true",
        "style" => "anchor-name: #{anchor}"
      },
      panel_attrs: %{
        "id" => id <> "-panel",
        "popover" => "auto",
        "aria-labelledby" => id,
        "phx-hook" => "Cinder.Filters.MultiSelect.Dropdown",
        "style" => "position-anchor: #{anchor}"
      },
      items:
        for {column, index} <- Enum.with_index(columns) do
          %{
            field: column.field,
            label: column.label,
            visible?: column.visible?,
            toggle_attrs: %{
              "type" => "checkbox",
              "id" => "#{id}-#{index}",
              "checked" => column.visible?,
              "disabled" => column.visible? and visible_count == 1,
              "phx-click" => collection.event_prefix <> "set_column",
              "phx-value-field" => column.field,
              "phx-value-visible" => to_string(not column.visible?),
              "phx-target" => collection.target
            },
            up_attrs:
              move_attrs(collection, fields, index, index - 1, index == 0, column.label, :up),
            down_attrs:
              move_attrs(collection, fields, index, index + 1, index == last, column.label, :down)
          }
        end
    }
  end

  # A button sending the whole new order, so the server needn't know the table's
  # columns (in a LiveView, only the template does)
  defp move_attrs(collection, fields, from, to, disabled?, label, direction) do
    order =
      if disabled?,
        do: fields,
        else:
          fields
          |> List.replace_at(from, Enum.at(fields, to))
          |> List.replace_at(to, Enum.at(fields, from))

    %{
      "type" => "button",
      "disabled" => disabled?,
      "aria-label" =>
        if(direction == :up,
          do: dgettext("cinder", "Move %{label} up", label: label),
          else: dgettext("cinder", "Move %{label} down", label: label)
        ),
      "phx-click" => collection.event_prefix <> "set_column_order",
      "phx-value-order" => Enum.join(order, ","),
      "phx-target" => collection.target
    }
  end

  @doc """
  A column's view-model, from a config column or a table's own `:col` slot (`field`,
  `label`, `slot`, `header`). A sortable one shares its field's sort view-model, so
  the header's button is the same as a sort chip's.
  """
  def column(column, sort) do
    %{
      field: column.field,
      label: column.label,
      slot: column.slot,
      # The `<:header>` slot entry, rendered with this map, or nil for the label
      header: Map.get(column, :header),
      # Declared hidden: available from the columns control, not shown at first
      hidden: Map.get(column, :hidden, false),
      sort: sort,
      attrs: %{
        "data-field" => column.field,
        "data-sortable" => sort != nil,
        "aria-sort" => sort && aria_sort(sort.direction)
      }
    }
  end

  defp aria_sort(:asc), do: "ascending"
  defp aria_sort(:desc), do: "descending"
  defp aria_sort(_), do: "none"

  # The page's rows by the group field's value, in order of first appearance (the
  # group sort keeps each group together, and grouping by key rather than by runs
  # means an out-of-place row can't split a group). Collapsing is in the browser:
  # each group's ids come from the collection and the value, not its position, so a
  # collapsed group stays collapsed across page and filter changes, and LiveView
  # keeps what its JS commands did through patches.
  defp groups(%{group: nil}, _rows), do: nil

  defp groups(%{group: group, id: id}, rows) do
    value = &field_value(&1.record, group.field)
    by_value = Enum.group_by(rows, value)

    rows
    |> Enum.map(value)
    |> Enum.uniq()
    |> Enum.map(fn value ->
      items = Map.fetch!(by_value, value)
      group_id = "#{id}-group-#{:erlang.phash2(value)}"
      items_id = group_id <> "-items"
      label_id = group_id <> "-label"

      %{
        value: value,
        items: items,
        id: group_id,
        attrs: %{"id" => group_id, "data-value" => to_string(value)},
        toggle_attrs: %{
          "type" => "button",
          "aria-expanded" => "true",
          "aria-controls" => items_id,
          # Named by the group's label, so it needs no words of its own
          "aria-labelledby" => label_id,
          # `hidden`, not `JS.toggle`: showing again restores the element's own
          # display (a `<tbody>`, a grid), where `JS.toggle` would set `block`
          "phx-click" =>
            Phoenix.LiveView.JS.toggle_attribute({"aria-expanded", "true", "false"})
            |> Phoenix.LiveView.JS.toggle_attribute({"hidden", ""}, to: "#" <> items_id)
        },
        items_attrs: %{"id" => items_id},
        label_id: label_id,
        # The group's header content, if declared, rendered with `value` and `items`
        slot: group.slot
      }
    end)
  end

  defp rows(nil, _selectable, _state, _myself), do: []

  defp rows(%{results: results}, selectable, state, myself) do
    for record <- results do
      id = to_string(Map.get(record, :id))
      selected? = MapSet.member?(state.selected, id)
      selectable? = Cinder.Selection.item_selectable?(selectable, record)

      %{
        record: record,
        id: id,
        selected?: selected?,
        selectable?: selectable?,
        attrs: %{"data-row-id" => id, "data-selected" => selected?},
        # A checkbox, though not a form input: it toggles by click
        select_attrs:
          selectable != false &&
            %{
              "type" => "checkbox",
              "checked" => selected?,
              "disabled" => not selectable?,
              "aria-label" => dgettext("cinder", "Select"),
              "phx-click" => event(myself, "toggle_select"),
              "phx-value-id" => id,
              "phx-target" => target(myself)
            }
      }
    end
  end

  # The page checkbox reads all, some or none of the page's selectable rows
  defp selection(false, _rows, _state, _myself), do: nil

  defp selection(_selectable, rows, state, myself) do
    page_ids = for %{selectable?: true, id: id} <- rows, do: id

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
        "data-state" => page_state,
        "checked" => page_state == :all,
        "disabled" => page_ids == [],
        "aria-label" => dgettext("cinder", "Select page"),
        "phx-click" => event(myself, "toggle_select_page"),
        "phx-target" => target(myself)
      },
      clear_attrs: %{
        "type" => "button",
        "hidden" => count == 0,
        "phx-click" => event(myself, "clear_selection"),
        "phx-target" => target(myself)
      }
    }
  end

  defp bulk_action(action, state, myself) do
    %{
      name: action.name,
      label: action.label,
      attrs: %{
        "type" => "button",
        "data-action" => action.name,
        "disabled" => MapSet.size(state.selected) == 0,
        "phx-click" => event(myself, "bulk_action"),
        "phx-value-name" => action.name,
        "phx-target" => target(myself)
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
      attrs: %{"role" => "alertdialog"},
      confirm_attrs: %{
        "type" => "button",
        "phx-click" => event(myself, "confirm_action"),
        "phx-target" => target(myself)
      },
      cancel_attrs: %{
        "type" => "button",
        "phx-click" => event(myself, "cancel_action"),
        "phx-target" => target(myself)
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
      attrs: %{},
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
      attrs: %{},
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
        "data-kind" => kind,
        "aria-label" => page_aria_label(kind, nil),
        "disabled" => disabled?,
        "phx-click" => event(myself, "go_to_cursor"),
        "phx-value-#{direction}" => cursor,
        "phx-target" => target(myself)
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
        "data-kind" => kind,
        "data-active" => current?,
        "aria-current" => current? && "page",
        "aria-label" => page_aria_label(kind, number),
        "disabled" => disabled?,
        "phx-click" => event(myself, "go_to_page"),
        "phx-value-page" => number,
        "phx-target" => target(myself)
      }
    }
  end

  defp gap do
    %{kind: :gap, label: "…", attrs: %{"data-kind" => "gap"}}
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
