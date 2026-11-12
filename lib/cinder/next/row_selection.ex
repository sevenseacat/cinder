# SPDX-FileCopyrightText: 2026 Cinder contributors <https://github.com/sevenseacat/cinder/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Cinder.Next.RowSelection do
  @moduledoc false
  # Which of a collection's records are selected, and every rule about it, as pure
  # functions. `mode` says what `ids` are: those picked (`:ids`), or those left out
  # of every record matching the query (`:all_except`). Ids are the strings the
  # boxes carry.
  #
  # With them are what the rules need to know: which records can be selected
  # (`selectable`, as the collection gives it: `true` or a function) and how they're
  # told apart (`primary_key`), and of the page shown, the ids its boxes can change
  # (`page_ids`) and how many records match (`total`, `nil` if not counted).

  alias Cinder.Engine.{Page, Query}

  defstruct mode: :ids,
            ids: MapSet.new(),
            selectable: true,
            primary_key: nil,
            page_ids: MapSet.new(),
            total: nil

  @type t :: %__MODULE__{
          mode: :ids | :all_except,
          ids: MapSet.t(String.t()),
          selectable: boolean() | (term() -> boolean()),
          primary_key: atom() | nil,
          page_ids: MapSet.t(String.t()),
          total: non_neg_integer() | nil
        }

  @doc "Nothing picked, before a page is shown."
  def new(selectable, primary_key) do
    %__MODULE__{selectable: selectable, primary_key: primary_key}
  end

  @doc """
  The selection when the collection is rebuilt, reading the same records. What's
  picked stays, but a `selectable` function can't be asked of records not read, so
  it ends all matching.
  """
  def for_selectable(selection, selectable, primary_key) do
    selection = %{selection | selectable: selectable, primary_key: primary_key}
    if selection.mode == :all_except and selectable != true, do: clear(selection), else: selection
  end

  @doc "The selection with `page` shown."
  def for_page(selection, %Page{records: records, count: count}) do
    page_ids =
      for record <- records, selectable?(selection.selectable, record), into: MapSet.new() do
        id(selection, record)
      end

    %{selection | page_ids: page_ids, total: count}
  end

  defp selectable?(selectable, record) when is_function(selectable, 1), do: selectable.(record)
  defp selectable?(selectable, _record), do: selectable

  @doc "The id of `record`, as its box carries it."
  def id(selection, record), do: to_string(Map.fetch!(record, selection.primary_key))

  @doc "Whether the record with `id` is selected."
  def selected?(%__MODULE__{mode: :ids, ids: ids}, id), do: id in ids
  def selected?(%__MODULE__{mode: :all_except, ids: ids}, id), do: id not in ids

  @doc """
  How many records are selected. All matching without a count (a failed read), or
  with fewer matching than are left out (records since gone), is none: nothing to
  act on, rather than a guess.
  """
  def count(%__MODULE__{mode: :ids, ids: ids}), do: MapSet.size(ids)
  def count(%__MODULE__{mode: :all_except, total: nil}), do: 0

  def count(%__MODULE__{mode: :all_except, ids: ids, total: total}) do
    max(total - MapSet.size(ids), 0)
  end

  @doc "Whether every record matching is selected, none left out."
  def everything?(%__MODULE__{mode: mode, ids: ids}) do
    mode == :all_except and MapSet.size(ids) == 0
  end

  @doc """
  The selection after a record's box is clicked: selected, or not if it was. Only
  an id the page's boxes can change can be, so any other, from a forged event,
  changes nothing.
  """
  def toggle(%__MODULE__{ids: ids} = selection, id) do
    cond do
      id not in selection.page_ids -> selection
      id in ids -> %{selection | ids: MapSet.delete(ids, id)}
      true -> %{selection | ids: MapSet.put(ids, id)}
    end
  end

  @doc """
  The selection after the page's box is clicked. It's checked when all of the page
  is selected, so it clears the page, and otherwise selects it, keeping what's
  selected on other pages.
  """
  def toggle_page(%__MODULE__{mode: mode, ids: ids, page_ids: page_ids} = selection) do
    # Picked, selecting the page adds its ids; all matching, it stops leaving them out
    ids =
      case {mode, page_selected?(selection)} do
        {:ids, false} -> MapSet.union(ids, page_ids)
        {:ids, true} -> MapSet.difference(ids, page_ids)
        {:all_except, false} -> MapSet.difference(ids, page_ids)
        {:all_except, true} -> MapSet.union(ids, page_ids)
      end

    %{selection | ids: ids}
  end

  @doc "Whether all of the page is selected. A page with nothing to select isn't."
  def page_selected?(%__MODULE__{page_ids: page_ids} = selection) do
    MapSet.size(page_ids) > 0 and Enum.all?(page_ids, &selected?(selection, &1))
  end

  @doc """
  How many records "all matching" would select, when it's offered: once all of the
  page is picked, and more records match. It's only offered with a count, to say how
  many, and when every record can be selected, as a `selectable` function can't be
  asked of records not read. `nil` when it isn't offered.
  """
  def all_matching_offer(%__MODULE__{mode: :ids, selectable: true, total: total} = selection)
      when is_integer(total) do
    if total > MapSet.size(selection.page_ids) and page_selected?(selection), do: total
  end

  def all_matching_offer(_selection), do: nil

  @doc """
  Every record matching, replacing what was picked (a record picked and since
  filtered out isn't added). When it isn't offered, from a forged event, it changes
  nothing.
  """
  def select_all_matching(selection) do
    if all_matching_offer(selection) do
      %{selection | mode: :all_except, ids: MapSet.new()}
    else
      selection
    end
  end

  @doc "Nothing picked."
  def clear(selection), do: %{selection | mode: :ids, ids: MapSet.new()}

  @doc """
  The selection after the query changes from `old` to `new`. Arguments decide what
  the read action reads, so new values clear it, as a new action would: a bulk
  action then only reaches records selected under the arguments it runs with. The
  filters and search decide what all matching is, so new ones end that; ids picked
  stay, as a filter hides a record without unselecting it.
  """
  def for_query(selection, %Query{} = old, %Query{} = new) do
    cond do
      old.arguments != new.arguments -> clear(selection)
      selection.mode == :ids -> selection
      {old.filters, old.search} != {new.filters, new.search} -> clear(selection)
      true -> selection
    end
  end

  @doc "Whether what's selected differs, ignoring the page shown."
  def changed?(old, new), do: {old.mode, old.ids} != {new.mode, new.ids}

  @doc "What the parent hears of the selection."
  def payload(%__MODULE__{mode: mode, ids: ids} = selection) do
    all_matching? = mode == :all_except

    %{
      selected_ids: if(all_matching?, do: MapSet.new(), else: ids),
      selected_count: count(selection),
      all_matching?: all_matching?,
      excluded_ids: if(all_matching?, do: ids, else: MapSet.new())
    }
  end

  @doc "The selection as `Cinder.Engine.run_bulk_action/6` takes it."
  def to_engine(%__MODULE__{mode: mode, ids: ids}), do: {mode, MapSet.to_list(ids)}
end
