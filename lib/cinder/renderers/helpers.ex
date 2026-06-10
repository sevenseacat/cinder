defmodule Cinder.Renderers.Helpers do
  @moduledoc false

  alias Cinder.Selection

  @doc """
  Builds the CSS classes for a selectable row/item.

  Adds the clickable cursor when a click handler is present or the row is
  toggleable, and appends `selected_class` when the row is currently selected.
  """
  def selection_classes(base, click, selectable, selected_ids, item, id_field, selected_class) do
    selected? = Selection.item_selected?(selected_ids, item, id_field)

    clickable =
      click != nil or Selection.item_toggleable?(selectable, selected_ids, item, id_field)

    classes = if clickable, do: [base, "cursor-pointer"], else: [base]

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
