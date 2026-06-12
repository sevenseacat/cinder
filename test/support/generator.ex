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
      %Cinder.Integration.Artist{name: sequence(:artist_name, &"Artist #{&1}")},
      overrides: opts
    )
  end

  @doc """
  Generates an integration test album.

  ## Options

  - `:title` - Override the album title
  - `:genre` - Override the genre (:rock, :pop, :jazz, :classical)
  - `:price` - Override the price (Decimal)
  - `:release_date` - Override the release date
  - `:is_remastered` - Override remastered flag
  - `:artist_id` - Specify artist (generates one if not provided)
  """
  def album(opts \\ []) do
    artist_id =
      opts[:artist_id] ||
        once(:default_artist_id, fn ->
          generate(artist()).id
        end)

    seed_generator(
      %Cinder.Integration.Album{
        title: sequence(:album_title, &"Album #{&1}"),
        genre: StreamData.member_of([:rock, :pop, :jazz, :classical]),
        price: Decimal.new("9.99"),
        release_date: ~D[2000-01-01],
        is_remastered: false,
        artist_id: artist_id
      },
      overrides: opts
    )
  end
end
