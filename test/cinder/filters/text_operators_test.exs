defmodule Cinder.Filters.TextOperatorsTest do
  # Regression: :starts_with and :ends_with built the same query as :contains
  use Cinder.ConnCase, async: false

  alias Cinder.Filters.Text

  setup do
    for value <- ["Road Trip", "Abbey Road", "The Road Less"] do
      artist = generate(artist(name: value))
      generate(album(title: value, artist_id: artist.id, details: %{label: value}))
    end

    on_exit(fn ->
      Ash.bulk_destroy!(Music.Album, :destroy, %{})
      Ash.bulk_destroy!(Music.Artist, :destroy, %{})
    end)
  end

  defp matching(field, operator, value, case_sensitive \\ false) do
    filter = %{type: :text, value: value, operator: operator, case_sensitive: case_sensitive}

    Music.Album
    |> Ash.Query.new()
    |> Text.build_query(field, filter)
    |> Ash.read!()
    |> Enum.map(& &1.title)
    |> Enum.sort()
  end

  for field <- ["title", "artist.name", "details__label"] do
    test "operators match the right part of #{field}" do
      field = unquote(field)

      assert matching(field, :starts_with, "road") == ["Road Trip"]
      assert matching(field, :ends_with, "road") == ["Abbey Road"]
      assert matching(field, :contains, "road") == ["Abbey Road", "Road Trip", "The Road Less"]
      assert matching(field, :starts_with, "road", true) == []
    end
  end
end
