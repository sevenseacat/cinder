defmodule TestStatusEnum do
  @moduledoc false
  use Ash.Type.Enum,
    values: [active: "Currently Active", inactive: "Not Active", pending: "Pending Activation"]
end

defmodule TestTagEnum do
  @moduledoc false
  use Ash.Type.Enum, values: [tag1: "First Tag", tag2: "Second Tag", tag3: "Third Tag"]
end

defmodule TestWeaponTypeEnum do
  @moduledoc false
  use Ash.Type.Enum,
    values: [
      sword: "Sword Weapon",
      bow: "Ranged Bow",
      staff: "Magic Staff",
      dagger: "Sharp Dagger"
    ]
end
