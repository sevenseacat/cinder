defmodule Cinder.Renderers.Helpers do
  @moduledoc false

  use Phoenix.Component
  use Cinder.Messages

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
  The `selectable` a row/item's own click and cursor should use: the collection's
  `selectable`, or `false` when `select_on_row_click` restricts selection to the
  checkbox.
  """
  def row_selection(selectable, true = _select_on_row_click), do: selectable
  def row_selection(_selectable, false = _select_on_row_click), do: false

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
  Renders the "filters" glyph used by the filter-preferences trigger.

  A funnel, `fill="currentColor"` so it inherits the surrounding button color —
  the counterpart to `columns_icon/1` on the filter row.
  """
  attr :class, :string, default: "w-4 h-4"

  def filters_icon(assigns) do
    ~H"""
    <svg viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg" class={@class} aria-hidden="true">
      <path d="M1.5 2.75C1.5 2.336 1.836 2 2.25 2h11.5a.75.75 0 0 1 .575 1.232L9.75 8.69v4.06a.75.75 0 0 1-1.2.6l-2-1.5a.75.75 0 0 1-.3-.6V8.69L1.675 3.232A.75.75 0 0 1 1.5 2.75Z" fill="currentColor" />
    </svg>
    """
  end

  @doc """
  `invisible` while a table's filter preferences are still in flight.

  The filter row is hidden for the same reason the table is: until the stored
  preferences arrive from the browser, the row we would paint is the wrong one.
  """
  def filter_prefs_hydration_class(%{filter_editable?: true, filter_prefs_hydrated?: false}),
    do: "invisible"

  def filter_prefs_hydration_class(_assigns), do: ""

  @doc """
  `invisible` while a table's remembered state is still in flight.

  The whole collection is held back, filter row included, for the reason the
  preference gates hold back theirs: until the browser says what it stored, the
  rows and the filter values on screen are the wrong ones, and watching them be
  replaced is worse than waiting a round trip for the right ones. The data is
  queried either way — this hides a paint, it does not hold a query — so a host
  that never registers the hook still gets its table, one second later, from the
  failsafe in `Cinder.LiveComponent`.
  """
  def state_hydration_class(%{persist_state?: true, table_state_hydrated?: false}),
    do: "invisible"

  def state_hydration_class(_assigns), do: ""

  @doc """
  The hidden element carrying the table-state hook.

  Mounted inside the LiveComponent so its push reaches the component rather than
  the host LiveView, and rendered only when the table remembers its state at all
  — otherwise nothing would ever release the hydration gate the hook opens.
  """
  attr :id, :string, required: true
  attr :myself, :any, required: true
  attr :enabled, :boolean, required: true

  def table_state_hook(assigns) do
    ~H"""
    <div
      :if={@enabled}
      id={"#{@id}-table-state-hook"}
      phx-hook="CinderTableState"
      phx-target={@myself}
      data-cinder-table-id={@id}
      class="hidden"
    />
    """
  end

  @doc """
  The empty state, which says *why* a list is empty when a filter is the reason.

  A list emptied by a filter the reader does not remember setting is the one
  failure mode remembered state introduces: the rows that are missing leave no
  trace, so an empty table that says only "No products found" reads as data loss
  rather than as a filter. When a filter or search is responsible the message
  names that, and the way out sits in the empty state itself rather than only in
  the row above — someone who does not realise a filter is set has no reason to
  look up there for the fix.

  `empty_filtered_message` lets a page name its own noun ("No products match the
  current filters"); without one the generic phrasing is used.
  """
  attr :empty_message, :string, required: true
  attr :empty_filtered_message, :string, default: nil
  attr :filtered?, :boolean, required: true
  attr :target, :any, default: nil
  attr :theme, :map, required: true

  def render_empty(assigns) do
    ~H"""
    <%= if @filtered? do %>
      <div class="flex flex-col items-center gap-3">
        <span>
          {@empty_filtered_message ||
            dgettext("cinder", "No results match the current filters.")}
        </span>

        <button
          type="button"
          phx-click="clear_all_filters"
          phx-target={@target}
          class={@theme.filter_clear_all_class}
          data-key="filter_clear_all_class"
        >
          {dgettext("cinder", "Reset filters")}
        </button>
      </div>
    <% else %>
      {@empty_message}
    <% end %>
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
  (using `Cinder.Filter.has_filter_value?/1`) other than its column's default,
  or a search term is active. A filter still at its default is not one the
  reader set, and resetting would only put it back.
  """
  def empty_context(assigns) do
    filters = Map.get(assigns, :filters, %{})
    search_term = Map.get(assigns, :search_term, "")

    has_active_filters =
      filters
      |> Cinder.FilterManager.reader_set_filters(Map.get(assigns, :query_columns, []))
      |> Enum.any?(fn {_key, filter} -> Cinder.Filter.has_filter_value?(filter.value) end)

    %{
      filtered?: has_active_filters or search_term != "",
      filters: filters,
      search_term: search_term
    }
  end
end
