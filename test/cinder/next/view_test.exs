defmodule Cinder.Next.ViewTest do
  use ExUnit.Case, async: true

  alias Cinder.Next.{Config, State, View}

  @myself %Phoenix.LiveComponent.CID{cid: 1}

  # Slot entries as HEEx hands them to the collection
  defp col(field, attrs \\ []), do: Map.merge(%{field: field, inner_block: nil}, Map.new(attrs))

  defp filter(field, attrs \\ []),
    do: Map.merge(%{field: field, inner_block: nil}, Map.new(attrs))

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

    config =
      Config.build(%{
        id: "albums",
        resource: Music.Album,
        col: Keyword.get(opts, :col, [col("title", sort: true)]),
        filter: Keyword.get(opts, :filter, []),
        sort: Keyword.get(opts, :sort, [])
      })

    View.build(%{
      config: config,
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
        build(state: state, col: [col("title", sort: true), col("genre")]).columns

      assert title.attrs["aria-sort"] == "ascending"
      assert title.attrs["data-sortable"] == true
      assert title.indicator_attrs["data-direction"] == :asc

      # Unsortable columns don't claim a sort state at all
      refute genre.attrs["aria-sort"]
      refute genre.attrs["data-sortable"]
    end
  end

  describe "filters" do
    test "inputs join the collection's form, wherever they're rendered" do
      [filter] = build(filter: [filter("title", type: :text)]).filters

      assert filter.input_attrs["form"] == "albums-filters"
      assert filter.input_attrs["name"] == "filters[title]"
      assert filter.label_attrs["for"] == filter.input_attrs["id"]
      assert filter.clear_attrs["phx-target"] == @myself
      assert filter.clear_attrs["hidden"] == true
    end

    test "an active filter says so, and shows its clear button" do
      filters = %{"title" => %{type: :text, value: "alp", operator: :contains}}
      state = State.new(page_size: 10) |> State.set_filters(filters, "")

      [filter] = build(state: state, filter: [filter("title", type: :text)]).filters

      assert filter.attrs["data-active"] == true
      assert filter.input_attrs["value"] == "alp"
      refute filter.clear_attrs["hidden"]
    end

    test "help text is linked to the input for assistive tech" do
      [with_help, without] =
        build(filter: [filter("title", type: :text, help: "Exact words"), filter("genre")]).filters

      assert with_help.help == "Exact words"
      assert with_help.input_attrs["aria-describedby"] == with_help.help_attrs["id"]
      refute without.input_attrs["aria-describedby"]
    end

    test "follow the declared order, and can be looked up by field" do
      view = build(filter: [filter("genre", type: :select), filter("title", type: :text)])

      assert Enum.map(view.filters, & &1.field) == ["genre", "title"]
      assert view.filters_by_field["title"].type == :text
    end
  end

  describe "grid columns" do
    defp grid_attrs(columns) do
      %{
        config:
          Config.build(%{
            id: "albums",
            resource: Music.Album,
            layout: :grid,
            grid_columns: columns
          }),
        state: State.new(),
        page: nil,
        status: :idle,
        myself: @myself
      }
      |> View.build()
      |> Map.fetch!(:grid_attrs)
    end

    test "fit as many as there's room for by default, with no inline style" do
      assert grid_attrs(nil) == %{"data-part" => "grid"}
    end

    test "go in as CSS variables, so no utility classes need generating" do
      assert %{"data-columns" => true, "style" => "--cinder-grid-columns: 3"} = grid_attrs(3)

      assert grid_attrs(xs: 1, md: 3)["style"] ==
               "--cinder-grid-columns-xs: 1; --cinder-grid-columns-md: 3"
    end
  end

  describe "sorts" do
    defp sort(field), do: %{field: field, inner_block: nil}

    test "each declared sort gets the same wiring as a sortable header, for chips" do
      state = State.new() |> State.toggle_sort("title")
      view = build(state: state, col: [], sort: [sort("title"), sort("genre")])

      assert [%{field: "title", direction: :asc}, %{field: "genre", direction: nil}] = view.sorts
      assert hd(view.sorts).attrs["data-active"] == true
      assert hd(view.sorts).attrs["phx-target"] == @myself
    end

    test "the dropdown offers each field both ways, in the URL's encoding, and marks the current one" do
      state = State.new() |> State.set_sort([{"genre", :desc}])
      select = build(state: state, col: [], sort: [sort("title"), sort("genre")]).sort_select

      assert Enum.map(select.options, & &1.attrs["value"]) == [
               "",
               "title",
               "-title",
               "genre",
               "-genre"
             ]

      assert Enum.find(select.options, & &1.attrs["selected"]).attrs["value"] == "-genre"
      assert select.select_attrs["form"] == "albums-filters"
    end

    test "there's no dropdown without declared sorts" do
      refute build(col: []).sort_select
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
