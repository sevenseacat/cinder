defmodule Cinder.Renderers.Helpers do
  @moduledoc false

  alias Cinder.Selection

  @doc """
  Builds the CSS classes for a selectable row/item.

  Merges the user-supplied `item_class` onto the theme's base class, adds the
  clickable cursor when a click handler is present or the row is toggleable,
  and appends `selected_class` when the row is currently selected.
  """
  def selection_classes(
        base,
        item_class,
        click,
        selectable,
        selected_ids,
        item,
        id_field,
        selected_class
      ) do
    selected? = Selection.item_selected?(selected_ids, item, id_field)

    clickable =
      click != nil or Selection.item_toggleable?(selectable, selected_ids, item, id_field)

    classes = [base, resolve_item_class(item_class, item)]
    classes = if clickable, do: classes ++ ["cursor-pointer"], else: classes

    if selected?, do: classes ++ [selected_class], else: classes
  end

  @doc """
  Builds the `phx-click` action for a selectable row/item.

  Returns the caller's click handler when one is given; otherwise pushes a
  `toggle_select` event when the row is toggleable.
  """
  def selection_click_action(click, _selectable, _selected_ids, item, _id_field, _myself)
      when click != nil do
    click.(item)
  end

  def selection_click_action(nil, selectable, selected_ids, item, id_field, myself) do
    if Selection.item_toggleable?(selectable, selected_ids, item, id_field) do
      Phoenix.LiveView.JS.push("toggle_select",
        value: %{id: to_string(Map.get(item, id_field))},
        target: myself
      )
    end
  end

  @doc false
  def item_number(index, :infinite, _current_page, _page), do: index + 1

  def item_number(index, _mode, _current_page, %Ash.Page.Offset{offset: offset}) do
    offset + index + 1
  end

  def item_number(index, :keyset, current_page, %{limit: limit}) do
    (current_page - 1) * limit + index + 1
  end

  def item_number(index, _mode, _current_page, _page), do: index + 1

  @doc false
  def assign_infinite_defaults(assigns) do
    stream_items = assigns |> Map.get(:streams, %{}) |> Map.get(:items, [])

    assigns
    |> Phoenix.Component.assign(:stream_items, stream_items)
    |> Phoenix.Component.assign_new(:infinite_loaded_count, fn -> 0 end)
    |> Phoenix.Component.assign_new(:infinite_range_start, fn -> 0 end)
    |> Phoenix.Component.assign_new(:infinite_range_end, fn -> 0 end)
    |> Phoenix.Component.assign_new(:infinite_has_previous, fn -> false end)
    |> Phoenix.Component.assign_new(:infinite_has_next, fn -> false end)
    |> Phoenix.Component.assign_new(:infinite_selectable_ids, fn -> MapSet.new() end)
    |> Phoenix.Component.assign_new(:total_count, fn -> nil end)
    |> Phoenix.Component.assign_new(:count_mode, fn -> :sync end)
  end

  @doc """
  Checks whether a slot assign contains any provided slot content.
  """
  def has_slot?(assigns, key) do
    case Map.get(assigns, key) do
      slots when is_list(slots) and slots != [] -> true
      _ -> false
    end
  end

  @doc """
  Resolves a user-supplied row/item class for the given item.

  A `fn item -> class end` function is called with the item; any other value
  (string, list, or nil) is returned unchanged, to be merged with the theme's
  base row/item class.
  """
  def resolve_item_class(fun, item) when is_function(fun, 1), do: fun.(item)
  def resolve_item_class(class, _item), do: class

  @doc """
  Builds context map passed to the empty slot via `:let`.

  The `filtered?` field is true when any filter has a meaningful value
  (using `Cinder.Filter.has_filter_value?/1`) or a search term is active.
  """
  def empty_context(assigns) do
    filters = Map.get(assigns, :filters, %{})
    search_term = Map.get(assigns, :search_term, "")

    has_active_filters =
      Enum.any?(filters, fn {_key, filter} ->
        Cinder.Filter.has_filter_value?(filter.value)
      end)

    %{
      filtered?: has_active_filters or search_term != "",
      filters: filters,
      search_term: search_term
    }
  end
end
