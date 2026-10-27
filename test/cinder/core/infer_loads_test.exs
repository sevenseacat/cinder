defmodule Cinder.QueryBuilder.InferLoadsTest do
  use ExUnit.Case, async: true

  alias Cinder.QueryBuilder

  test "attributes, embedded fields and nothing need no load" do
    assert QueryBuilder.infer_loads(Music.Album, ["title", "genre", "details__label"]) == []
    assert QueryBuilder.infer_loads(Music.Album, []) == []
  end

  test "calculations and aggregates on the resource" do
    assert QueryBuilder.infer_loads(Music.Album, ["title", "title_lower"]) == [:title_lower]
    assert QueryBuilder.infer_loads(Music.Artist, ["album_count"]) == [:album_count]
  end

  test "relationships load, with their calculations and aggregates merged in" do
    assert QueryBuilder.infer_loads(Music.Album, ["artist.name"]) == [artist: []]

    fields = ["artist.name_lower", "title_lower", "artist.album_count", "artist.name"]

    assert QueryBuilder.infer_loads(Music.Album, fields) ==
             [{:artist, [:name_lower, :album_count]}, :title_lower]
  end

  test "nested relationships nest, and a relationship before an embedded field loads" do
    assert QueryBuilder.infer_loads(Music.Album, ["artist.albums.title_lower"]) ==
             [artist: [albums: [:title_lower]]]

    assert QueryBuilder.infer_loads(Music.Artist, ["albums.details__label"]) == [albums: []]
  end

  test "fields Cinder can't resolve, or can't load without arguments, are skipped" do
    fields = [nil, "nope", "artist.nope", "nope.name", "title_with", "title_lower", "title_lower"]
    assert QueryBuilder.infer_loads(Music.Album, fields) == [:title_lower]
  end
end
