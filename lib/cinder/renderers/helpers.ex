defmodule Cinder.Renderers.Helpers do
  @moduledoc false

  use Phoenix.Component

  @doc """
  Renders the "columns" glyph used by the column-preferences trigger.

  `fill="currentColor"` so it inherits the surrounding text/button color.
  """
  attr :class, :string, default: "w-4 h-4"

  def columns_icon(assigns) do
    ~H"""
    <svg viewBox="0 0 8 7" fill="none" xmlns="http://www.w3.org/2000/svg" class={@class} aria-hidden="true">
      <path d="M0.75 6V2H3.625V6.25H1C0.8625 6.25 0.75 6.1375 0.75 6ZM4.375 6.25V2H7.25V6C7.25 6.1375 7.1375 6.25 7 6.25H4.375ZM1 0C0.448438 0 0 0.448437 0 1V6C0 6.55156 0.448438 7 1 7H7C7.55156 7 8 6.55156 8 6V1C8 0.448437 7.55156 0 7 0H1Z" fill="currentColor" />
    </svg>
    """
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
