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
