defmodule Cinder.Filters.SelectTest do
  use ExUnit.Case, async: true

  alias Cinder.Filters.Select
  alias Cinder.Test.FilterRecord
  alias TestResourceForInference

  describe "Select filter build_query/3 for array fields" do
    setup do
      query = Ash.Query.new(TestResourceForInference)
      %{query: query}
    end

    test "matches records whose array contains the value" do
      hit = FilterRecord.seed(tags: ["tag1", "tag2"])
      _miss = FilterRecord.seed(tags: ["tag2"])
      filter_value = %{type: :select, value: "tag1", operator: :equals}

      assert FilterRecord.matching_ids(Select, "tags", filter_value) == MapSet.new([hit.id])
    end

    test "matches a plain field by equality" do
      hit = FilterRecord.seed(name: "tag1")
      _miss = FilterRecord.seed(name: "tag10")
      filter_value = %{type: :select, value: "tag1", operator: :equals}

      assert FilterRecord.matching_ids(Select, "name", filter_value) == MapSet.new([hit.id])
    end

    test "returns unchanged query for empty values on array fields", %{query: query} do
      filter_value = %{
        type: :select,
        value: "",
        operator: :equals
      }

      result_query = Select.build_query(query, "tags", filter_value)

      # Empty values should not modify the query, even for array fields
      assert result_query == query
    end
  end

  test "render/4 prompts with the column's label until a value is chosen" do
    button = fn column ->
      column
      |> Select.render(nil, Cinder.Theme.default(), %{table_id: "albums"})
      |> Phoenix.HTML.Safe.to_iodata()
      |> IO.iodata_to_binary()
      |> LazyHTML.from_fragment()
      |> LazyHTML.query("#albums-filter-genre-button")
      |> LazyHTML.text()
      |> String.trim()
    end

    column = %{field: "genre", label: "Genre", filter_options: [options: [{"Rock", :rock}]]}
    assert button.(column) == "All Genre"
    assert button.(%{column | filter_options: [prompt: "Any", options: []]}) == "Any"
  end

  test "process/2 takes only one of the options, when there are any" do
    column = %{filter_options: [options: [{"Rock", :rock}, {"Jazz", "jazz"}]]}
    assert Select.process("bogus", column) == nil
    assert %{value: "rock"} = Select.process("rock", column)
    assert %{value: "anything"} = Select.process("anything", %{filter_options: []})
  end

  test "matches a field through a relationship" do
    uk = Ash.Seed.seed!(TestArtist, %{name: "The Beatles", country: "UK"})
    sweden = Ash.Seed.seed!(TestArtist, %{name: "ABBA", country: "Sweden"})
    hit = Ash.Seed.seed!(TestAlbum, %{title: "Help!", artist_id: uk.id})
    _miss = Ash.Seed.seed!(TestAlbum, %{title: "Arrival", artist_id: sweden.id})
    filter_value = %{type: :select, value: "UK", operator: :equals}

    ids =
      TestAlbum
      |> Ash.Query.new()
      |> Select.build_query("artist.country", filter_value)
      |> Ash.read!()
      |> MapSet.new(& &1.id)

    assert ids == MapSet.new([hit.id])
  end
end
