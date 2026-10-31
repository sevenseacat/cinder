defmodule CinderDev.Seeds do
  @moduledoc """
  Seeds the ETS-backed music resources at boot. The data resets on every restart.
  """

  import Ash.Generator, only: [generate: 1]

  @artist_count 12
  @album_count 300
  @tags ~w(live compilation debut soundtrack deluxe instrumental)
  @labels ["Blue Note", "Motown", "Sub Pop", "Rough Trade", "Deutsche Grammophon"]

  @doc "The tags seeded albums can have."
  def tags, do: @tags

  @doc "The record labels seeded albums can be on."
  def labels, do: @labels

  def run do
    # A fixed seed gives the same data on every boot, so pages look the same
    # between restarts.
    :rand.seed(:default, 42)

    artists =
      for _ <- 1..@artist_count do
        debuted_at = NaiveDateTime.add(~N[1955-01-01 00:00:00], Enum.random(0..1_500_000_000))
        generate(Cinder.Generator.artist(debuted_at: debuted_at))
      end

    for n <- 1..@album_count do
      generate(
        Cinder.Generator.album(
          artist_id: Enum.random(artists).id,
          genre: Enum.random([:rock, :pop, :jazz, :classical]),
          price: Decimal.new(Enum.random(499..2999)) |> Decimal.div(100),
          track_count: Enum.random(4..24),
          release_date: Date.add(~D[1960-01-01], Enum.random(0..23_000)),
          added_at: DateTime.add(~U[2020-01-01 00:00:00Z], Enum.random(0..180_000_000)),
          is_remastered: Enum.random([true, false]),
          tags: Enum.take_random(@tags, Enum.random(0..3)),
          details: %Music.AlbumDetails{
            label: Enum.random(@labels),
            catalog_number: "CAT-#{String.pad_leading("#{n}", 4, "0")}",
            recorded_on: Date.add(~D[1960-01-01], Enum.random(0..23_000))
          }
        )
      )
    end

    :ok
  end
end
