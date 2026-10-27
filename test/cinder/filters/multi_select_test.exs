defmodule Cinder.Filters.MultiSelectTest do
  @moduledoc """
  Everything `Cinder.Filters.MultiSelect` does, apart from rendering. Its query results
  are checked by running the query, on every kind of field it can target. (On a to-many
  relationship, `:all` means the related records hold every value between them.)
  """
  use Cinder.ConnCase, async: false

  alias Cinder.Filters.MultiSelect

  describe "process/2" do
    test "takes a list of values, or a single one" do
      expected = %{type: :multi_select, value: ["a", "b"], operator: :in, match_mode: :any}

      assert MultiSelect.process(["a", "b"], %{filter_options: []}) == expected
      assert %{value: ["a"]} = MultiSelect.process("a", %{filter_options: []})
      assert MultiSelect.process([], %{filter_options: []}) == nil
      assert MultiSelect.process([""], %{filter_options: []}) == nil
      assert MultiSelect.process(nil, %{filter_options: []}) == nil
    end

    test "carries the match_mode option, :any by default" do
      assert %{match_mode: :any} = MultiSelect.process(["a"], %{filter_options: []})

      assert %{match_mode: :all} =
               MultiSelect.process(["a"], %{filter_options: [match_mode: :all]})
    end

    # Values come from the client (URLs and form events), and each one becomes part of
    # the query, so they're trimmed to what the filter could have offered
    test "keeps unique values among the options, when there are options" do
      column = %{filter_options: [options: [{"Rock", :rock}, {"Jazz", "jazz"}, "pop"]]}

      assert %{value: ["rock", "jazz", "pop"]} =
               MultiSelect.process(["rock", "zzz", "rock", "jazz", "pop", ""], column)

      assert MultiSelect.process(["zzz", "nope"], column) == nil
    end

    test "keeps a capped number of unique strings, when there are no options" do
      values = Enum.map(1..500, &"v#{&1}")

      assert %{value: kept} = MultiSelect.process(values ++ values, %{filter_options: []})
      assert kept == Enum.take(values, 100)
    end

    test "drops anything that isn't a string" do
      assert %{value: ["a"]} =
               MultiSelect.process(["a", %{"x" => "y"}, ["b"], 1], %{filter_options: []})
    end
  end

  test "validate/1" do
    valid = %{type: :multi_select, value: ["a"], operator: :in}

    assert MultiSelect.validate(Map.put(valid, :match_mode, :any))
    assert MultiSelect.validate(Map.put(valid, :match_mode, :all))
    # Values from before match_mode existed
    assert MultiSelect.validate(valid)

    refute MultiSelect.validate(Map.put(valid, :match_mode, :invalid))
    refute MultiSelect.validate(%{valid | value: []})
    refute MultiSelect.validate(%{valid | type: :multi_checkboxes})
  end

  test "empty?/1" do
    for value <- [nil, [], %{value: []}, %{value: nil}], do: assert(MultiSelect.empty?(value))
    for value <- [["a"], %{value: ["a"]}], do: refute(MultiSelect.empty?(value))
  end

  test "default_options/0" do
    assert MultiSelect.default_options() == [options: [], match_mode: :any, prompt: nil]
  end

  describe "build_query/3" do
    # Artist => [{album title, genre, tags}]
    @data [
      {"Alice Cooper", [{"A1", :rock, ["live", "remaster"]}, {"A2", :jazz, ["live"]}]},
      {"Miles Davis", [{"M1", :jazz, ["studio"]}]},
      {"Pop Star", [{"P1", :pop, ["remaster"]}, {"P2", :rock, ["studio"]}]}
    ]

    setup do
      for {name, albums} <- @data do
        artist = generate(artist(name: name))

        for {title, genre, tags} <- albums do
          generate(album(title: title, genre: genre, tags: tags, artist_id: artist.id))
        end
      end

      on_exit(fn ->
        Ash.bulk_destroy!(Music.Album, :destroy, %{})
        Ash.bulk_destroy!(Music.Artist, :destroy, %{})
      end)
    end

    test "an array attribute (tags)" do
      assert albums("tags", ["studio"]) == ["M1", "P2"]
      assert albums("tags", ["studio"], :all) == ["M1", "P2"]
      assert albums("tags", ["live", "remaster"], :any) == ["A1", "A2", "P1"]
      assert albums("tags", ["live", "remaster"]) == ["A1", "A2", "P1"]
      assert albums("tags", ["live", "remaster"], :all) == ["A1"]
      assert length(albums("tags", ["live", "remaster", "studio"], :any)) == 5
    end

    test "a plain attribute (genre)" do
      assert albums("genre", ["jazz"]) == ["A2", "M1"]
      assert albums("genre", ["jazz", "pop"], :any) == ["A2", "M1", "P1"]
    end

    test "a list aggregate (genres)" do
      assert artists("genres", ["jazz"]) == ["Alice Cooper", "Miles Davis"]

      assert artists("genres", ["jazz", "pop"], :any) == [
               "Alice Cooper",
               "Miles Davis",
               "Pop Star"
             ]

      assert artists("genres", ["rock", "jazz"], :all) == ["Alice Cooper"]
    end

    test "an array calculation (name_words)" do
      assert artists("name_words", ["Davis"]) == ["Miles Davis"]
      assert artists("name_words", ["Davis", "Pop"], :any) == ["Miles Davis", "Pop Star"]
      assert artists("name_words", ["Alice", "Cooper"], :all) == ["Alice Cooper"]
    end

    test "a plain field through a relationship (albums.title)" do
      assert artists("albums.title", ["A1"]) == ["Alice Cooper"]
      assert artists("albums.title", ["A1"], :all) == ["Alice Cooper"]
      assert artists("albums.title", ["M1", "P1"], :any) == ["Miles Davis", "Pop Star"]
      assert artists("albums.title", ["M1", "P1"]) == ["Miles Davis", "Pop Star"]
      assert artists("albums.title", ["A1", "A2"], :all) == ["Alice Cooper"]
      assert artists("albums.title", ["A1", "M1"], :all) == []
    end

    test "an array through a relationship (albums.tags)" do
      assert artists("albums.tags", ["studio"]) == ["Miles Davis", "Pop Star"]

      assert artists("albums.tags", ["live", "studio"], :any) ==
               ["Alice Cooper", "Miles Davis", "Pop Star"]

      # Between their albums, not on one album
      assert artists("albums.tags", ["remaster", "studio"], :all) == ["Pop Star"]
      assert artists("albums.tags", ["live", "remaster"], :all) == ["Alice Cooper"]
    end

    test "no values filter nothing" do
      assert length(albums("tags", [], :any)) == 5
      assert length(artists("albums.tags", [], :all)) == 3
    end
  end

  defp albums(field, values, match_mode \\ nil) do
    matching(Music.Album, field, values, match_mode, & &1.title)
  end

  defp artists(field, values, match_mode \\ nil) do
    matching(Music.Artist, field, values, match_mode, & &1.name)
  end

  # A `nil` match_mode leaves it out, so the filter's default applies
  defp matching(resource, field, values, match_mode, name) do
    filter = %{type: :multi_select, value: values, operator: :in}
    filter = if match_mode, do: Map.put(filter, :match_mode, match_mode), else: filter

    resource
    |> Ash.Query.new()
    |> MultiSelect.build_query(field, filter)
    |> Ash.read!()
    |> Enum.map(name)
    |> Enum.sort()
  end
end
