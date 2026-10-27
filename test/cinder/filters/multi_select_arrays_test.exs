defmodule Cinder.Filters.MultiSelectArraysTest do
  @moduledoc """
  Multi-select filters on array-valued fields match records whose array holds the selected
  values: a `list` aggregate, an array calculation, and an array attribute through a
  relationship (where `:all` means the related records hold every value between them).
  """
  use Cinder.ConnCase, async: false

  alias Cinder.Filters.MultiSelect

  setup do
    for {name, albums} <- [
          {"Alice Cooper", [{:rock, ["live", "remaster"]}, {:jazz, ["live"]}]},
          {"Miles Davis", [{:jazz, ["studio"]}]},
          {"Pop Star", [{:pop, ["remaster"]}, {:rock, ["studio"]}]}
        ] do
      artist = generate(artist(name: name))

      for {genre, tags} <- albums do
        generate(album(genre: genre, tags: tags, artist_id: artist.id))
      end
    end

    on_exit(fn ->
      Ash.bulk_destroy!(Music.Album, :destroy, %{})
      Ash.bulk_destroy!(Music.Artist, :destroy, %{})
    end)
  end

  defp artists(field, values, match_mode \\ :any) do
    filter = %{type: :multi_select, value: values, operator: :in, match_mode: match_mode}

    Music.Artist
    |> Ash.Query.new()
    |> MultiSelect.build_query(field, filter)
    |> Ash.read!()
    |> Enum.map(& &1.name)
    |> Enum.sort()
  end

  test "a list aggregate (genres)" do
    assert artists("genres", ["jazz"]) == ["Alice Cooper", "Miles Davis"]
    assert artists("genres", ["jazz", "pop"]) == ["Alice Cooper", "Miles Davis", "Pop Star"]
    assert artists("genres", ["rock", "jazz"], :all) == ["Alice Cooper"]
  end

  test "an array calculation (name_words)" do
    assert artists("name_words", ["Davis"]) == ["Miles Davis"]
    assert artists("name_words", ["Davis", "Pop"]) == ["Miles Davis", "Pop Star"]
    assert artists("name_words", ["Alice", "Cooper"], :all) == ["Alice Cooper"]
  end

  test "an array attribute through a relationship (albums.tags)" do
    assert artists("albums.tags", ["studio"]) == ["Miles Davis", "Pop Star"]

    assert artists("albums.tags", ["live", "studio"]) == [
             "Alice Cooper",
             "Miles Davis",
             "Pop Star"
           ]

    # Between their albums, not on one album
    assert artists("albums.tags", ["remaster", "studio"], :all) == ["Pop Star"]
    assert artists("albums.tags", ["live", "remaster"], :all) == ["Alice Cooper"]
  end
end
