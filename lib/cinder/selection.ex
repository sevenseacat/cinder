defmodule Cinder.Selection do
  @moduledoc """
  Predicates that decide selection behaviour for a collection.

  Selection has two distinct concerns:

    * whether selection is enabled for the collection at all (`enabled?/1`),
      which governs the checkbox column, the "select all" control and the
      bulk-action bar; and
    * whether an individual item may be selected (`item_selectable?/2`), which
      governs the per-item checkbox and click-to-toggle.

  These functions are shared by the renderers and `Cinder.LiveComponent`. They
  treat the `selectable` value uniformly as `true | false | (item -> boolean)`.
  """

  @doc """
  Returns whether selection is enabled for the collection.

  `false` and `nil` disable selection entirely; any other value (`true` or a
  predicate function) enables it.
  """
  def enabled?(false), do: false
  def enabled?(nil), do: false
  def enabled?(_), do: true

  @doc """
  Returns whether the given `item` may be selected.

  A predicate function is called with the item and its result is coerced to a
  boolean.
  """
  def item_selectable?(false, _item), do: false
  def item_selectable?(true, _item), do: true
  def item_selectable?(fun, item) when is_function(fun, 1), do: !!fun.(item)
  def item_selectable?(_, _item), do: false

  @doc """
  Returns whether the given `item` is currently selected.
  """
  def item_selected?(selected_ids, item, id_field) do
    MapSet.member?(selected_ids, to_string(Map.get(item, id_field)))
  end

  @doc """
  Returns whether the given `item`'s checkbox should be interactive.

  An item is toggleable when it is selectable, or when it is already selected so
  that an item that became non-selectable can still be removed.
  """
  def item_toggleable?(selectable, selected_ids, item, id_field) do
    item_selectable?(selectable, item) or item_selected?(selected_ids, item, id_field)
  end
end
