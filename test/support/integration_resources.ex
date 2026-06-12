# Resources for LiveView integration tests.
#
# These use `private?(false)` so data is visible across processes (test process,
# LiveView process, and async task processes). This is required because ETS
# `private?(true)` creates per-process tables that can't be read cross-process.
#
# Do NOT use these in unit tests — use the per-process-isolated resources in
# test_resources.ex instead.

defmodule Cinder.Integration.Domain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(Cinder.Integration.Artist)
    resource(Cinder.Integration.Album)
  end
end

defmodule Cinder.Integration.Artist do
  @moduledoc false
  use Ash.Resource,
    domain: Cinder.Integration.Domain,
    data_layer: Ash.DataLayer.Ets

  ets do
    private?(false)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string)
  end

  relationships do
    has_many(:albums, Cinder.Integration.Album)
  end

  actions do
    defaults([:read, :destroy])
  end
end

defmodule Cinder.Integration.Album do
  @moduledoc false
  use Ash.Resource,
    domain: Cinder.Integration.Domain,
    data_layer: Ash.DataLayer.Ets

  ets do
    private?(false)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:title, :string)
    attribute(:genre, TestGenreEnum)
    attribute(:price, :decimal)
    attribute(:release_date, :date)
    attribute(:is_remastered, :boolean)
    attribute(:artist_id, :uuid)
  end

  relationships do
    belongs_to(:artist, Cinder.Integration.Artist)
  end

  actions do
    defaults([:read, :destroy])
  end
end
