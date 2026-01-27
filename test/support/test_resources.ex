defmodule TestProfile do
  @moduledoc false
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute(:first_name, :string)
    attribute(:last_name, :string)
    attribute(:phone, :string)
    attribute(:country, :string)
    attribute(:bio, :string)
  end
end

defmodule TestAddress do
  @moduledoc false
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute(:street, :string)
    attribute(:city, :string)
    attribute(:postal_code, :string)
    attribute(:country, :string)
  end
end

defmodule TestSettings do
  @moduledoc false
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute(:theme, :string)
    attribute(:language, :string)
    attribute(:notifications_enabled, :boolean)
    attribute(:address, TestAddress)
  end
end

defmodule TestResourceForInference do
  @moduledoc false
  use Ash.Resource, domain: nil

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string)
    attribute(:active, :boolean)
    attribute(:count, :integer, constraints: [min: 0])
    attribute(:price, :decimal)
    attribute(:created_at, :date)
    attribute(:status_enum, TestStatusEnum)
    attribute(:tags, {:array, TestTagEnum})
    attribute(:description, :string)
    attribute(:weapon_type, TestWeaponTypeEnum)
    attribute(:profile, TestProfile)
    attribute(:settings, TestSettings)
    attribute(:metadata, :map)
  end
end

defmodule NotAnAshResource do
  @moduledoc false
  def some_function, do: :ok
end

defmodule TestUuidResource do
  @moduledoc false
  use Ash.Resource, domain: nil

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string)
    attribute(:user_id, :uuid)
    attribute(:organization_id, :uuid)
    attribute(:status, :string)
    attribute(:count, :integer)
  end

  relationships do
    belongs_to(:user, TestUserResource, destination_attribute: :id, source_attribute: :user_id)
  end
end

defmodule TestUserResource do
  @moduledoc false
  use Ash.Resource, domain: nil

  attributes do
    uuid_primary_key(:id)
    attribute(:email, :string)
    attribute(:profile_id, :uuid)
    attribute(:profile, TestProfile)
    attribute(:settings, TestSettings)
  end
end

# Resources for testing relationship filtering
defmodule TestGenreEnum do
  @moduledoc false
  use Ash.Type.Enum,
    values: [
      rock: [label: "Rock"],
      pop: [label: "Pop"],
      jazz: [label: "Jazz"],
      classical: [label: "Classical"]
    ]
end

defmodule TestRelationshipDomain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(TestArtist)
    resource(TestAlbum)
  end
end

defmodule TestArtist do
  @moduledoc false
  use Ash.Resource,
    domain: TestRelationshipDomain,
    data_layer: Ash.DataLayer.Ets,
    validate_domain_inclusion?: false

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string)
    attribute(:country, :string)
    attribute(:founded_year, :integer)
    attribute(:active, :boolean)
  end

  relationships do
    has_many(:albums, TestAlbum, destination_attribute: :artist_id)
  end

  actions do
    defaults([:create, :read, :update, :destroy])
  end
end

defmodule TestAlbum do
  @moduledoc false
  use Ash.Resource,
    domain: TestRelationshipDomain,
    data_layer: Ash.DataLayer.Ets,
    validate_domain_inclusion?: false

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:title, :string)
    attribute(:release_date, :date)
    attribute(:price, :decimal)
    attribute(:is_remastered, :boolean)
    attribute(:genre, TestGenreEnum)
    attribute(:artist_id, :uuid)
  end

  relationships do
    belongs_to(:artist, TestArtist, attribute_writable?: true)
  end

  actions do
    defaults([:create, :read, :update, :destroy])
  end
end
