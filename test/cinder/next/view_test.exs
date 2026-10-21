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
      filter = build(filter: [filter("title", type: :text)]).filters["title"]

      assert filter.input_attrs["form"] == "albums-filters"
      assert filter.input_attrs["name"] == "filters[title]"
      assert filter.name == "filters[title]"
      assert filter.label_attrs["for"] == filter.input_attrs["id"]
      assert filter.clear_attrs["phx-target"] == @myself
      assert filter.clear_attrs["hidden"] == true
    end

    test "an active filter says so, and shows its clear button" do
      filters = %{"title" => %{type: :text, value: "alp", operator: :contains}}
      state = State.new(page_size: 10) |> State.set_filters(filters, "")

      filter = build(state: state, filter: [filter("title", type: :text)]).filters["title"]

      assert filter.attrs["data-active"] == true
      assert filter.input_attrs["value"] == "alp"
      refute filter.clear_attrs["hidden"]
    end

    test "help text is linked to the input for assistive tech" do
      [with_help, without] =
        build(filter: [filter("title", type: :text, help: "Exact words"), filter("genre")]).filters
        |> Enum.to_list()

      assert with_help.help == "Exact words"
      assert with_help.input_attrs["aria-describedby"] == with_help.help_attrs["id"]
      refute without.input_attrs["aria-describedby"]
    end

    test "select options can also render as radio buttons that join the form" do
      filters = %{"genre" => %{type: :select, value: "jazz", operator: :equals}}
      state = State.new(page_size: 10) |> State.set_filters(filters, "")

      genre = build(state: state, filter: [filter("genre", type: :select)]).filters["genre"]
      jazz = Enum.find(genre.options, &(&1.value == "jazz"))

      assert %{
               "type" => "radio",
               "name" => "filters[genre]",
               "value" => "jazz",
               "checked" => true,
               "form" => "albums-filters"
             } = jazz.input_attrs

      assert jazz.selected?
      assert length(Enum.uniq_by(genre.options, & &1.input_attrs["id"])) == length(genre.options)
    end

    test "come as FormFields too, for component libraries' inputs" do
      filters = %{"title" => %{type: :text, value: "alp", operator: :contains}}
      state = State.new(page_size: 10) |> State.set_filters(filters, "")
      view = build(state: state, filter: [filter("title", type: :text), filter("genre")])
      {title, genre} = {view.filters["title"], view.filters["genre"]}

      assert %Phoenix.HTML.FormField{name: "filters[title]", value: "alp"} = title.form_field
      assert title.form_field.id == title.input_attrs["id"]
      assert view.form_id == title.input_attrs["form"]

      # Components gate errors with Phoenix's own check, which must agree with ours
      assert Phoenix.Component.used_input?(title.form_field)
      refute Phoenix.Component.used_input?(genre.form_field)
    end

    test "a FormField carries errors in the shape components translate, once used" do
      config =
        Config.build(%{
          id: "albums",
          resource: Music.Album,
          action: :with_min_tracks,
          argument: [%{name: "min_tracks"}]
        })

      view = fn raw ->
        state = %{State.new() | raw: raw, errors: %{"min_tracks" => ["is required"]}}

        %{config: config, state: state, page: nil, status: :invalid, myself: @myself}
        |> View.build()
        |> get_in([:filters, "min_tracks", :form_field])
      end

      assert view.(%{"min_tracks" => ""}).errors == [{"is required", []}]
      assert view.(%{"min_tracks" => "", "_unused_min_tracks" => ""}).errors == []
    end

    test "a range's FormFields are one per bound" do
      %{min: min, max: max} =
        build(filter: [filter("price", type: :number_range)]).filters["price"]
        |> Map.fetch!(:form_field)

      assert {min.name, max.name} == {"filters[price_min]", "filters[price_max]"}
    end

    test "the collection counts its active filters" do
      filters = %{"title" => %{type: :text, value: "alp", operator: :contains}}
      state = State.new(page_size: 10) |> State.set_filters(filters, "")
      view = build(state: state, filter: [filter("title", type: :text), filter("genre")])

      assert view.active_filter_count == 1
      assert view.clear_all_attrs["phx-click"] == "clear_all"
    end

    test "follow the declared order, and can be looked up by field" do
      view = build(filter: [filter("genre", type: :select), filter("title", type: :text)])

      assert Enum.map(view.filters, & &1.field) == ["genre", "title"]
      assert view.filters["title"].type == :text
    end
  end

  # Cinder's CSS styles `cinder-*` classes, which only its own components render.
  # Attribute maps carry no name or class for parts, so markup that
  # spreads them isn't styled by Cinder.
  test "attribute maps carry no part names or classes" do
    view = build(filter: [filter("title", type: :text)])

    maps =
      [view.attrs, view.form_attrs, view.clear_all_attrs, view.grid_attrs, view.pagination.attrs] ++
        Enum.flat_map(view.rows, &[&1.attrs]) ++
        Enum.flat_map(view.columns, &[&1.attrs, &1.sort_attrs]) ++
        Enum.flat_map(view.filters, &[&1.attrs, &1.input_attrs, &1.clear_attrs])

    assert Enum.all?(maps, &(not Map.has_key?(&1, "class") and not Map.has_key?(&1, "data-part")))
  end

  describe "groups" do
    defp groups(results, group \\ [%{__slot__: :group, field: "genre", inner_block: nil}]) do
      %{
        config: Config.build(%{id: "albums", resource: Music.Album, group: group}),
        state: State.new(),
        page: %Ash.Page.Offset{results: results, limit: 10, offset: 0, count: 3, more?: false},
        status: :idle,
        myself: @myself
      }
      |> View.build()
      |> Map.fetch!(:groups)
    end

    test "group by value in order of first appearance, so an out-of-place row can't split one" do
      results = [%{id: 1, genre: :rock}, %{id: 2, genre: :jazz}, %{id: 3, genre: :rock}]

      assert [%{value: :rock, items: [_, _]} = rock, %{value: :jazz, items: [_]}] =
               groups(results)

      # The toggle collapses the group's items, named by its label
      assert rock.toggle_attrs["aria-controls"] == rock.items_attrs["id"]
      assert rock.toggle_attrs["aria-labelledby"] == rock.label_id
    end

    test "are nil when the collection isn't grouped" do
      refute groups([%{id: 1, genre: :rock}], [])
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
      assert grid_attrs(nil) == %{}
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

    test "the primary sort is the first, for tables that only show one" do
      state = State.new() |> State.set_sort([{"genre", :desc}, {"title", :asc}])

      assert build(state: state).primary_sort == %{field: "genre", direction: :desc}
      refute build([]).primary_sort
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
