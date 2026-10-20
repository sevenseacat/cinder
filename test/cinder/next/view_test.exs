defmodule Cinder.Next.ViewTest do
  use ExUnit.Case, async: true

  alias Cinder.Next.{State, View}

  @myself %Phoenix.LiveComponent.CID{cid: 1}

  defp column(field, sortable),
    do: %{field: field, label: field, slot: %{}, sortable: sortable, sort_cycle: nil}

  defp offset_page(page_number, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    count = Keyword.get(opts, :count, 100)
    offset = (page_number - 1) * limit

    %Ash.Page.Offset{
      results: Enum.map(1..min(limit, max(count - offset, 0))//1, &%{id: &1}),
      limit: limit,
      offset: offset,
      count: count,
      more?: offset + limit < count
    }
  end

  defp build(opts) do
    state = Keyword.get(opts, :state, State.new(page_size: 10))

    View.build(%{
      config: %{columns: Keyword.get(opts, :columns, [column("title", true)])},
      state: state,
      page: Keyword.get(opts, :page, offset_page(state.page)),
      status: :idle,
      myself: @myself
    })
  end

  describe "columns" do
    test "sortable columns get sort wiring that targets the component" do
      [title] = build([]).columns

      assert title.sort_attrs["phx-click"] == "sort"
      assert title.sort_attrs["phx-value-field"] == "title"
      assert title.sort_attrs["phx-target"] == @myself
    end

    test "state is expressed through attributes" do
      state = State.new() |> State.toggle_sort("title")

      [title, genre] =
        build(state: state, columns: [column("title", true), column("genre", false)]).columns

      assert title.attrs["aria-sort"] == "ascending"
      assert title.attrs["data-sortable"] == true
      assert title.indicator_attrs["data-direction"] == :asc

      # Unsortable columns don't claim a sort state at all
      refute genre.attrs["aria-sort"]
      refute genre.attrs["data-sortable"]
    end
  end

  describe "pagination" do
    defp labels(pagination), do: Enum.map(pagination.pages, & &1.label)

    test "shows a window around the current page, plus the first and last, with gaps" do
      state = State.new(page_size: 10) |> State.go_to_page(5)

      assert labels(build(state: state).pagination) == [
               "1",
               "…",
               "3",
               "4",
               "5",
               "6",
               "7",
               "…",
               "10"
             ]
    end

    test "has no gaps when the window reaches the ends" do
      assert labels(build([]).pagination) == ["1", "2", "3", "…", "10"]
    end

    test "marks the current page and disables previous on the first page" do
      pagination = build([]).pagination
      [first | _] = pagination.pages

      assert first.attrs["aria-current"] == "page"
      assert first.attrs["data-active"] == true
      assert pagination.prev.attrs["disabled"] == true
      refute pagination.next.attrs["disabled"]
      assert pagination.next.attrs["phx-value-page"] == 2
    end

    test "disables next on the last page" do
      state = State.new(page_size: 10) |> State.go_to_page(10)

      assert build(state: state).pagination.next.attrs["disabled"] == true
    end

    test "without a count, offers only previous and next" do
      page = %{offset_page(1) | count: nil}
      pagination = build(page: page).pagination

      assert pagination.pages == []
      assert pagination.summary == nil
      refute pagination.next.attrs["disabled"]
    end
  end
end
