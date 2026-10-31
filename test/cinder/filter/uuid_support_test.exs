defmodule Cinder.Filter.UuidSupportTest.Owner do
  @moduledoc false
  use Ash.Resource,
    domain: Cinder.Filter.UuidSupportTest.Domain,
    data_layer: Ash.DataLayer.Ets,
    validate_domain_inclusion?: false

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key(:id)
  end

  actions do
    defaults([:read, :create])
  end
end

defmodule Cinder.Filter.UuidSupportTest.Item do
  @moduledoc false
  use Ash.Resource,
    domain: Cinder.Filter.UuidSupportTest.Domain,
    data_layer: Ash.DataLayer.Ets,
    validate_domain_inclusion?: false

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key(:id)
  end

  actions do
    defaults([:read, create: [:owner_id]])
  end

  relationships do
    belongs_to :owner, Cinder.Filter.UuidSupportTest.Owner do
      public?(true)
      attribute_writable?(true)
    end
  end
end

defmodule Cinder.Filter.UuidSupportTest.Domain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(Cinder.Filter.UuidSupportTest.Owner)
    resource(Cinder.Filter.UuidSupportTest.Item)
  end
end

defmodule Cinder.Filter.UuidSupportTest do
  use ExUnit.Case, async: true

  alias Cinder.Filter.Helpers
  alias Cinder.Filter.UuidSupportTest.{Item, Owner}

  @text_operators [:contains, :starts_with, :ends_with]

  defp filter(field, value, operator) do
    Item
    |> Ash.Query.new()
    |> Helpers.build_ash_filter(field, value, operator)
    |> Map.fetch!(:filter)
    |> inspect()
  end

  defp matching_ids(field, value, operator) do
    Item
    |> Ash.Query.new()
    |> Helpers.build_ash_filter(field, value, operator)
    |> Ash.read!()
    |> MapSet.new(& &1.id)
  end

  # Postgres has no `ILIKE` for a uuid column, so text operators must cast the field to a
  # string; ETS compares without the cast, so only the query's shape can show it
  describe "the string cast text operators need" do
    test "is applied to a uuid field, directly and through a relationship" do
      for operator <- @text_operators do
        assert filter("owner_id", "123e", operator) =~ "type(owner_id, :string"
        assert filter("owner.id", "123e", operator) =~ "type(id, :string"
      end
    end

    test "isn't applied for :equals, which compares the field as its own type" do
      uuid = Ash.UUID.generate()

      refute filter("owner_id", uuid, :equals) =~ "type("
      refute filter("owner.id", uuid, :equals) =~ "type("
    end
  end

  describe "text operators on a uuid field, by the records they return" do
    setup do
      owner = Ash.create!(Owner, %{})
      hit = Ash.create!(Item, %{owner_id: owner.id})
      _miss = Ash.create!(Item, %{owner_id: Ash.create!(Owner, %{}).id})

      %{owner: owner, hit: hit}
    end

    test "match on part of the id", %{owner: owner, hit: hit} do
      first_part = owner.id |> String.split("-") |> hd()
      last_part = owner.id |> String.split("-") |> List.last()
      middle = String.slice(owner.id, 9, 9)

      assert matching_ids("owner_id", first_part, :starts_with) == MapSet.new([hit.id])
      assert matching_ids("owner_id", last_part, :ends_with) == MapSet.new([hit.id])
      assert matching_ids("owner_id", middle, :contains) == MapSet.new([hit.id])
    end

    test "match through a relationship", %{owner: owner, hit: hit} do
      first_part = owner.id |> String.split("-") |> hd()

      assert matching_ids("owner.id", first_part, :starts_with) == MapSet.new([hit.id])
    end

    test ":equals matches the whole id", %{owner: owner, hit: hit} do
      assert matching_ids("owner_id", owner.id, :equals) == MapSet.new([hit.id])
    end
  end
end
