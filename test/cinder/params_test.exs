defmodule Cinder.ParamsTest do
  use ExUnit.Case, async: true

  alias Cinder.{Engine, Params}
  alias Cinder.Engine.{Argument, Field, Query}

  defp fields do
    for {name, declared} <- [
          {"title", %{filter: %{}, sortable?: true}},
          {"genre", %{filter: %{}}},
          {"price", %{filter: %{}}},
          {"tags", %{filter: %{options: [options: [{"A", "a"}, {"B", "b"}]]}}},
          {"track_count", %{sortable?: true}}
        ] do
      {:ok, field} = Engine.field(Music.Album, struct!(Field, Map.put(declared, :name, name)))
      field
    end
  end

  defp arguments do
    for {name, input} <- [
          {"size", %{}},
          {"labels", %{options: [options: [{"A", "a"}, {"B", "b"}]]}}
        ] do
      {:ok, argument} =
        Engine.argument(Music.Album, :by_inputs, %Argument{name: name, input: input})

      argument
    end
  end

  describe "filters_from_params/2" do
    test "each filtered field's input becomes its type's filter value" do
      filters =
        Params.filters_from_params(
          %{"title" => "road", "genre" => "rock", "tags" => ["a", "b"]},
          fields()
        )

      assert %{type: :text, value: "road", operator: :contains} = filters["title"]
      assert %{type: :select, value: "rock", operator: :equals} = filters["genre"]
      assert %{type: :multi_select, value: ["a", "b"]} = filters["tags"]
    end

    test "a range's halves become one filter" do
      filters = Params.filters_from_params(%{"price_min" => "10", "price_max" => ""}, fields())
      assert %{type: :number_range, value: %{min: "10", max: ""}} = filters["price"]
    end

    test "empty input, unknown keys and fields without a filter are left out" do
      params = %{"title" => "", "nope" => "x", "track_count" => "3"}
      assert Params.filters_from_params(params, fields()) == %{}
    end

    test "input a filter can't use is left out, not an error" do
      params = %{"genre" => "polka", "tags" => ["z"], "price_min" => "lots"}
      assert Params.filters_from_params(params, fields()) == %{}
    end
  end

  describe "filter_values/2" do
    test "each filtered field's value as its control shows it, empty if it isn't filtered" do
      filters = Params.filters_from_params(%{"title" => "road", "price_min" => "10"}, fields())

      assert Params.filter_values(filters, fields()) == %{
               "title" => "road",
               "genre" => "",
               "price" => %{min: "10", max: ""},
               "tags" => []
             }
    end
  end

  describe "to_url/4 and from_url/4" do
    @defaults %Query{sort: [{"title", :asc}], page_size: 25}
    @opts [page_sizes: [25, 50]]

    defp to_url(query),
      do: Params.to_url(query, fields(), @defaults, [arguments: arguments()] ++ @opts)

    defp from_url(params),
      do: Params.from_url(params, fields(), @defaults, [arguments: arguments()] ++ @opts)

    test "a query round-trips through the URL" do
      filters =
        Params.filters_from_params(
          %{"title" => "road", "genre" => "rock", "tags" => ["a", "b"], "price_min" => "10"},
          fields()
        )

      query = %Query{
        filters: filters,
        arguments:
          Params.filters_from_params(%{"size" => "single", "labels" => ["a", "b"]}, arguments()),
        search: "blue",
        sort: [{"track_count", :desc_nils_last}, {"title", :asc}],
        page: 3,
        page_size: 50
      }

      params = to_url(query)

      assert params == %{
               "title" => "road",
               "genre" => "rock",
               "tags" => "a,b",
               "price" => "10,",
               "size" => "single",
               "labels" => "a,b",
               "search" => "blue",
               "sort" => "--track_count,title",
               "page" => "3",
               "page_size" => "50"
             }

      assert from_url(params) == query
    end

    test "an argument goes in the URL under its `param`" do
      argument = %Argument{name: "size", param: "format", input: %{}}
      {:ok, argument} = Engine.argument(Music.Album, :by_inputs, argument)
      opts = [arguments: [argument]]

      query = %Query{
        @defaults
        | arguments: Params.filters_from_params(%{"format" => "single"}, [argument])
      }

      assert Params.to_url(query, [], @defaults, opts) == %{"format" => "single"}
      assert Params.from_url(%{"format" => "single"}, [], @defaults, opts) == query
      assert Params.url_keys([], opts) == Params.own_keys() ++ ["format"]
    end

    test "a keyset cursor round-trips through the URL" do
      for cursor <- [{:after, "g2wAAA"}, {:before, "g2wAAA"}] do
        query = %Query{@defaults | cursor: cursor}
        assert from_url(to_url(query)) == query
      end
    end

    # Without a `sort` param, a URL has the default sort
    test "an unsorted query round-trips through the URL as an empty `sort`" do
      query = %Query{@defaults | sort: []}

      assert to_url(query) == %{"sort" => ""}
      assert from_url(to_url(query)) == query
    end

    test "the defaults are left out of the URL, and fill in what isn't there" do
      assert to_url(@defaults) == %{}
      assert from_url(%{}) == @defaults
    end

    test "params that aren't the collection's are ignored" do
      assert from_url(%{"tab" => "info", "track_count" => "3"}) == @defaults
    end

    test "input that can't be used falls back to the default" do
      query =
        from_url(%{
          "sort" => "-price,nope,-track_count",
          "page" => "lots",
          "page_size" => "10000000",
          "genre" => "polka"
        })

      # Only sortable fields sort, and only allowed page sizes are used
      assert query == %Query{@defaults | sort: [{"track_count", :desc}]}
    end

    test "exclusive, only the first sort the collection can use is kept" do
      params = %{"sort" => "price,-track_count,title"}
      from_url = &Params.from_url(params, fields(), @defaults, &1)

      assert from_url.(sort_mode: :exclusive).sort == [{"track_count", :desc}]
      assert from_url.(sort_mode: :additive).sort == [{"track_count", :desc}, {"title", :asc}]
      assert from_url.([]).sort == [{"track_count", :desc}, {"title", :asc}]
    end

    test "with no page sizes given, only the default is allowed" do
      query = Params.from_url(%{"page_size" => "50"}, fields(), @defaults, [])
      assert query.page_size == 25
    end

    test "without search, a search in the URL is ignored" do
      query = Params.from_url(%{"search" => "blue"}, fields(), @defaults, search?: false)
      assert query == @defaults
    end

    test "each paging mode ignores the other's params, and an unpaged collection both" do
      params = %{"page" => "3", "after" => "g2wAAA"}
      from_url = &Params.from_url(params, fields(), @defaults, pagination: &1)

      assert from_url.(:offset) == %Query{@defaults | page: 3}
      assert from_url.(:keyset) == %Query{@defaults | cursor: {:after, "g2wAAA"}}
      assert from_url.(nil) == @defaults
    end
  end

  describe "url_keys/2" do
    test "every key the collection may write: its own, each filterable field's, and the arguments'" do
      assert Params.url_keys(fields(), arguments: arguments()) ==
               ~w(search sort page after before page_size title genre price tags size labels)
    end
  end
end
