defmodule TestResourceForInference do
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
  end
end

defmodule NotAnAshResource do
  def some_function, do: :ok
end

defmodule TestUuidResource do
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
  use Ash.Resource, domain: nil

  attributes do
    uuid_primary_key(:id)
    attribute(:email, :string)
    attribute(:profile_id, :uuid)
  end
end
