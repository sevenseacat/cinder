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
    attribute(:release_date, :date)
    attribute(:is_remastered, :boolean)
    attribute(:artist_id, :uuid)
  end

  relationships do
    belongs_to(:artist, Music.Artist)
  end

  actions do
    defaults([:read, :destroy])
  end
end
