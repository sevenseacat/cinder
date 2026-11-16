defmodule Cinder.Next.StateTest do
  use ExUnit.Case, async: true

  alias Cinder.Engine.Query
  alias Cinder.Next.{Config, State}

  @cycle [nil, :asc, :desc]

  describe "toggle_sort/4" do
    test "a column's clicks step through its cycle, back to unsorted" do
      assert State.toggle_sort([], "title", @cycle, :additive) == [{"title", :asc}]

      assert State.toggle_sort([{"title", :asc}], "title", @cycle, :additive) == [
               {"title", :desc}
             ]

      assert State.toggle_sort([{"title", :desc}], "title", @cycle, :additive) == []
    end

    test "additive: the column clicked becomes the main sort, the others break its ties" do
      assert State.toggle_sort([{"price", :asc}], "title", @cycle, :additive) ==
               [{"title", :asc}, {"price", :asc}]

      # Already in the sort, it changes direction and moves to the front
      assert State.toggle_sort([{"price", :asc}, {"title", :asc}], "title", @cycle, :additive) ==
               [{"title", :desc}, {"price", :asc}]

      assert State.toggle_sort([{"price", :asc}, {"title", :desc}], "title", @cycle, :additive) ==
               [{"price", :asc}]
    end

    test "exclusive: the column clicked is the only sort" do
      assert State.toggle_sort([{"price", :asc}], "title", @cycle, :exclusive) ==
               [{"title", :asc}]

      assert State.toggle_sort([{"price", :asc}, {"title", :desc}], "title", @cycle, :exclusive) ==
               []
    end

    test "a column's own cycle" do
      cycle = [:desc, :asc, nil]
      assert State.toggle_sort([], "added", cycle, :additive) == [{"added", :desc}]
      assert State.toggle_sort([{"added", :desc}], "added", cycle, :additive) == [{"added", :asc}]
      assert State.toggle_sort([{"added", :asc}], "added", cycle, :additive) == []
    end

    test "a cycle without nil never goes back to unsorted" do
      cycle = [:asc, :desc]
      assert State.toggle_sort([{"title", :desc}], "title", cycle, :additive) == [{"title", :asc}]
      # Unsorted (another column took over in exclusive mode): the cycle starts again
      assert State.toggle_sort([], "title", cycle, :exclusive) == [{"title", :asc}]
    end

    test "a direction that isn't in the cycle (from the query or the URL) starts the cycle" do
      for cycle <- [@cycle, [:asc, :desc], [:desc, :asc]] do
        first = Enum.find(cycle, & &1)

        assert State.toggle_sort([{"title", :desc_nils_last}], "title", cycle, :additive) ==
                 [{"title", first}]
      end
    end
  end

  describe "carry_over/4, when the declarations change" do
    defp field(name, attrs \\ []) do
      Map.merge(%{__slot__: :field, name: name, inner_block: fn _, _ -> "" end}, Map.new(attrs))
    end

    # Of the albums resource, unless a `query` is given
    defp config(fields, options \\ [], arguments \\ []) do
      source = if options[:query], do: [], else: [resource: Music.Album]
      options = [id: "albums"] ++ source ++ options

      arguments =
        for {name, param} <- arguments, do: %{__slot__: :argument, name: name, param: param}

      Config.build(options, fields, arguments, [])
    end

    defp fields,
      do: [field("title", sort: true, filter: true, search: true), field("genre", filter: true)]

    @ab %{type: :text, value: "ab", operator: :contains, case_sensitive: false}
    @rock %{type: :select, value: "rock", operator: :equals}

    # On page 3 of a sorted, filtered and searched query
    @query %Query{
      sort: [{"title", :desc}],
      filters: %{"title" => @ab, "genre" => @rock},
      search: "ab",
      page: 3,
      page_size: 25
    }

    test "the user's choices stay, and the page too while the records are the same" do
      old = config(fields())
      new = config(fields() ++ [field("price", sort: true)])
      assert State.carry_over(@query, old, new, true) == @query
    end

    test "back to the first page when the records aren't the same, or the page size changes" do
      old = config(fields())
      assert State.carry_over(@query, old, old, false) == %{@query | page: 1}

      assert State.carry_over(@query, old, config(fields(), pagination: [size: 10]), true) ==
               %{@query | page: 1, page_size: 10}
    end

    test "what's no longer sortable, filterable or searchable is dropped" do
      new = config([field("title"), field("genre", filter: true)])

      assert State.carry_over(@query, config(fields()), new, true) ==
               %{@query | sort: [], filters: %{"genre" => @rock}, search: "", page: 1}
    end

    test "a sort still at the old default becomes the new one" do
      old = config(fields(), query: Ash.Query.sort(Music.Album, title: :desc))
      new = config(fields(), query: Ash.Query.sort(Music.Album, title: :asc))
      assert State.carry_over(@query, old, new, true).sort == [{"title", :asc}]
    end

    test "the user's page size stays while it's offered, and the page with it" do
      sizes = [size: 25, size_options: [10, 25]]
      query = %{@query | page_size: 10}
      old = config(fields(), pagination: sizes)
      new = config(fields() ++ [field("price")], pagination: sizes)
      assert State.carry_over(query, old, new, true) == query
    end

    test "a page size still at the old default becomes the new one" do
      old = config(fields(), pagination: [size: 25, size_options: [25, 50]])
      new = config(fields(), pagination: [size: 50, size_options: [25, 50]])
      assert State.carry_over(@query, old, new, true) == %{@query | page_size: 50, page: 1}
    end

    test "a page size no longer offered becomes the default" do
      query = %{@query | page_size: 10}
      old = config(fields(), pagination: [size: 25, size_options: [10, 25]])
      new = config(fields(), pagination: [size: 25, size_options: [25, 50]])
      assert State.carry_over(query, old, new, true) == %{@query | page_size: 25, page: 1}
    end

    # Under its `param`, as the form and the URL give it
    test "an argument's value stays while it's declared" do
      query = %{@query | arguments: %{"style" => @rock}}
      old = config(fields(), [action: :by_genre], [{"genre", "style"}])
      assert State.carry_over(query, old, old, true).arguments == %{"style" => @rock}

      assert State.carry_over(query, old, config(fields(), action: :by_genre), false).arguments ==
               %{}
    end
  end

  # What each param means is `Cinder.Params`'; these check the collection's config
  # reaches it
  describe "from_url/2" do
    test "a search, only when the collection has a search box" do
      assert State.from_url(%{"search" => "ab"}, config(fields())).search == "ab"
      assert State.from_url(%{"search" => "ab"}, config([field("title")])).search == ""
    end

    test "a page number on offset pages, and a cursor on keyset pages" do
      params = %{"page" => "3", "after" => "abc"}
      offset = config(fields(), action: :paginated, pagination: [mode: :offset])
      keyset = config(fields(), action: :paginated, pagination: [mode: :keyset])

      assert {State.from_url(params, offset).page, State.from_url(params, offset).cursor} ==
               {3, nil}

      assert {State.from_url(params, keyset).page, State.from_url(params, keyset).cursor} ==
               {1, {:after, "abc"}}
    end

    test "a page size, only when it's offered" do
      config = config(fields(), pagination: [size: 25, size_options: [10, 25]])
      assert State.from_url(%{"page_size" => "10"}, config).page_size == 10
      assert State.from_url(%{"page_size" => "50"}, config).page_size == 25
    end
  end

  describe "change_page_size/3" do
    test "an offered size, on the first page" do
      config = config(fields(), pagination: [size: 25, size_options: [10, 25]])

      assert State.change_page_size(@query, "10", config) ==
               {:ok, %{@query | page_size: 10, page: 1}}

      keyset = %{@query | page: 1, cursor: {:after, "abc"}}

      assert State.change_page_size(keyset, "10", config) ==
               {:ok, %{keyset | page_size: 10, cursor: nil}}
    end

    # From a tampered event, or the same size again
    test "a size that isn't offered, or isn't new, changes nothing" do
      config = config(fields(), pagination: [size: 25, size_options: [10, 25]])

      for size <- ["50", "ten", "", "25"] do
        assert State.change_page_size(@query, size, config) == :ignore
      end
    end
  end
end
