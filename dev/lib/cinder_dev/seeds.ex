defmodule CinderDev.Seeds do
  @moduledoc """
  Seeds the ETS-backed music resources at boot. The data resets on every restart.
  """

  import Ash.Generator, only: [generate: 1]

  @artist_count 12
  @album_count 300

  def run do
    # A fixed seed gives the same data on every boot, so pages look the same
    # between restarts.
    :rand.seed(:default, 42)

    artists = for _ <- 1..@artist_count, do: generate(Cinder.Generator.artist())

    for _ <- 1..@album_count do
      generate(
        Cinder.Generator.album(
          artist_id: Enum.random(artists).id,
          genre: Enum.random([:rock, :pop, :jazz, :classical]),
          price: Decimal.new(Enum.random(499..2999)) |> Decimal.div(100),
          release_date: Date.add(~D[1960-01-01], Enum.random(0..23_000)),
          is_remastered: Enum.random([true, false])
        )
      )
    end

    :ok
  end
end
