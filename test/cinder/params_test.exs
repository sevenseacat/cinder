defmodule Cinder.ParamsTest do
  use ExUnit.Case, async: true

  alias Cinder.{Engine, Params}
  alias Cinder.Engine.{Field, Query}

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

  describe "to_url/4 and from_url/4" do
    @defaults %Query{sort: [{"title", :asc}], page_size: 25}
    @opts [arguments: ["year"], page_sizes: [25, 50]]

    defp to_url(query), do: Params.to_url(query, fields(), @defaults, @opts)
    defp from_url(params), do: Params.from_url(params, fields(), @defaults, @opts)

    test "a query round-trips through the URL" do
      filters =
        Params.filters_from_params(
          %{"title" => "road", "genre" => "rock", "tags" => ["a", "b"], "price_min" => "10"},
          fields()
        )

      query = %Query{
        filters: filters,
        arguments: %{"year" => "1987"},
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
               "year" => "1987",
               "search" => "blue",
               "sort" => "--track_count,title",
               "page" => "3",
               "page_size" => "50"
             }

      assert from_url(params) == query
    end

    test "a keyset cursor round-trips through the URL" do
      for cursor <- [{:after, "g2wAAA"}, {:before, "g2wAAA"}] do
        query = %Query{@defaults | cursor: cursor}
        assert from_url(to_url(query)) == query
      end
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

    test "with no page sizes given, only the default is allowed" do
      query = Params.from_url(%{"page_size" => "50"}, fields(), @defaults, [])
      assert query.page_size == 25
    end
  end
end
