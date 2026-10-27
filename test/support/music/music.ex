# Resources shared by the LiveView integration tests and the dev app in `dev/`,
# which compiles this directory too, so it must stay self-contained.
#
# These use `private?(false)` so data is visible across processes (test process,
# LiveView process, and async task processes). This is required because ETS
# `private?(true)` creates per-process tables that can't be read cross-process.
#
# Do NOT use these in unit tests — use the per-process-isolated resources in
# test_resources.ex instead.

defmodule Music.Genre do
  @moduledoc false
  use Ash.Type.Enum,
    values: [
      rock: [label: "Rock"],
      pop: [label: "Pop"],
      jazz: [label: "Jazz"],
      classical: [label: "Classical"]
    ]
end

defmodule Music.AlbumDetails do
  @moduledoc false
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute(:label, :string, public?: true)
    attribute(:catalog_number, :string, public?: true)
  end
end

defmodule Music do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(Music.Artist)
    resource(Music.Album)
  end
end

defmodule Music.Artist do
  @moduledoc false
  use Ash.Resource,
    domain: Music,
    data_layer: Ash.DataLayer.Ets

  ets do
    private?(false)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string)
  end

  relationships do
    has_many(:albums, Music.Album)
  end

  calculations do
    calculate(:name_lower, :string, expr(string_downcase(name)))

    calculate :name_with, :string, expr(name <> ^arg(:suffix)) do
      argument(:suffix, :string, allow_nil?: false)
    end

    calculate(:name_words, {:array, :string}, expr(string_split(name, " ")))
  end

  aggregates do
    count(:album_count, :albums)
    list(:genres, :albums, :genre, uniq?: true)
  end

  actions do
    defaults([:read, :destroy])
  end
end

defmodule Music.Album do
  @moduledoc false
  use Ash.Resource,
    domain: Music,
    data_layer: Ash.DataLayer.Ets

  ets do
    private?(false)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:title, :string)
    attribute(:genre, Music.Genre)
    attribute(:price, :decimal)
    attribute(:track_count, :integer)
    attribute(:release_date, :date)
    attribute(:added_at, :utc_datetime)
    attribute(:is_remastered, :boolean)
    attribute(:tags, {:array, :string})
    attribute(:details, Music.AlbumDetails)
    attribute(:artist_id, :uuid)
  end

  relationships do
    belongs_to(:artist, Music.Artist)
  end

  calculations do
    calculate(:title_lower, :string, expr(string_downcase(title)))

    calculate :title_with, :string, expr(title <> ^arg(:suffix)) do
      argument(:suffix, :string, allow_nil?: false)
    end
  end

  actions do
    defaults([:read, :destroy])

    read :paginated do
      pagination(offset?: true, keyset?: true, countable: true, required?: false)
    end

    # For showing the loading and error states in the dev app
    read :slow do
      prepare(fn query, _context ->
        Process.sleep(1500)
        query
      end)
    end

    read :failing do
      prepare(fn query, _context -> Ash.Query.add_error(query, "Simulated failure") end)
    end

    update :remaster do
      require_atomic?(false)
      change(set_attribute(:is_remastered, true))
    end
  end
end
