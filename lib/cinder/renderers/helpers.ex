defmodule Cinder.Renderers.Helpers do
  @moduledoc false

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
