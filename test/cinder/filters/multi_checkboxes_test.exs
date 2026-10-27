defmodule Cinder.Filters.MultiCheckboxesTest do
  @moduledoc """
  `Cinder.Filters.MultiCheckboxes` is `Cinder.Filters.MultiSelect` with checkboxes for a
  renderer (see `Cinder.Filters.MultiSelectTest` for the shared behaviour). These cover
  what's its own: its type tag, and its options.
  """
  use Cinder.ConnCase, async: false

  alias Cinder.Filters.MultiCheckboxes

  test "process/2 and validate/1 use its own type tag, which picks it to build the query" do
    assert %{type: :multi_checkboxes, value: ["a"], operator: :in, match_mode: :any} =
             filter = MultiCheckboxes.process(["a", "a"], %{filter_options: []})

    assert MultiCheckboxes.validate(filter)
    refute MultiCheckboxes.validate(%{filter | type: :multi_select})
    assert MultiCheckboxes.process([], %{filter_options: []}) == nil
  end

  test "default_options/0 has no prompt (there's no dropdown)" do
    assert MultiCheckboxes.default_options() == [options: [], match_mode: :any]
  end

  test "build_query/3 matches like MultiSelect" do
    artist = generate(artist(name: "Pop Star"))
    generate(album(title: "P1", tags: ["remaster"], artist_id: artist.id))
    generate(album(title: "P2", tags: ["studio"], artist_id: artist.id))

    on_exit(fn ->
      Ash.bulk_destroy!(Music.Album, :destroy, %{})
      Ash.bulk_destroy!(Music.Artist, :destroy, %{})
    end)

    filter = %{type: :multi_checkboxes, value: ["remaster", "studio"], match_mode: :all}

    assert [%{name: "Pop Star"}] =
             Music.Artist
             |> Ash.Query.new()
             |> MultiCheckboxes.build_query("albums.tags", filter)
             |> Ash.read!()
  end
end
