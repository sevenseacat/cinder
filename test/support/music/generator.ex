defmodule Cinder.Generator do
  @moduledoc "Data generation for tests"

  use Ash.Generator

  @doc """
  Generates an integration test artist.

  ## Options

  - `:name` - Override the artist name
  """
  def artist(opts \\ []) do
    seed_generator(
      %Music.Artist{name: sequence(:artist_name, &"Artist #{&1}")},
      overrides: opts
    )
  end

  @doc """
  Generates an integration test album.

  ## Options

  - `:title` - Override the album title
  - `:genre` - Override the genre (:rock, :pop, :jazz, :classical)
  - `:price` - Override the price (Decimal)
  - `:track_count` - Override the number of tracks
  - `:release_date` - Override the release date
  - `:added_at` - Override when the album was added (DateTime)
  - `:is_remastered` - Override remastered flag
  - `:tags` - Override the tags (list of strings)
  - `:details` - Override the embedded details (`%Music.AlbumDetails{}`)
  - `:artist_id` - Specify artist (generates one if not provided)
  """
  def album(opts \\ []) do
    artist_id =
      opts[:artist_id] ||
        once(:default_artist_id, fn ->
          generate(artist()).id
        end)

    seed_generator(
      %Music.Album{
        title: sequence(:album_title, &"Album #{&1}"),
        genre: StreamData.member_of([:rock, :pop, :jazz, :classical]),
        price: Decimal.new("9.99"),
        track_count: 10,
        release_date: ~D[2000-01-01],
        added_at: ~U[2024-01-01 00:00:00Z],
        is_remastered: false,
        tags: [],
        details: %Music.AlbumDetails{label: "Label 1", catalog_number: "CAT-0001"},
        artist_id: artist_id
      },
      overrides: opts
    )
  end
end
