defmodule Cinder.QueryBuilder.NumberRangeFilterTest.Domain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(Cinder.QueryBuilder.NumberRangeFilterTest.Shop)
    resource(Cinder.QueryBuilder.NumberRangeFilterTest.Item)
  end
end

defmodule Cinder.QueryBuilder.NumberRangeFilterTest.Shop do
  @moduledoc false
  use Ash.Resource,
    domain: Cinder.QueryBuilder.NumberRangeFilterTest.Domain,
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

  relationships do
    has_many(:items, Cinder.QueryBuilder.NumberRangeFilterTest.Item)
  end
end

defmodule Cinder.QueryBuilder.NumberRangeFilterTest.Meta do
  @moduledoc false
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute(:weight, :integer, public?: true)
  end
end

defmodule Cinder.QueryBuilder.NumberRangeFilterTest.Item do
  @moduledoc false
  use Ash.Resource,
    domain: Cinder.QueryBuilder.NumberRangeFilterTest.Domain,
    data_layer: Ash.DataLayer.Ets,
    validate_domain_inclusion?: false

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:count, :integer, public?: true)
    attribute(:price, :decimal, public?: true)
    attribute(:meta, Cinder.QueryBuilder.NumberRangeFilterTest.Meta, public?: true)
  end

  actions do
    defaults([:read, create: [:count, :price, :meta, :shop_id]])
  end

  relationships do
    belongs_to :shop, Cinder.QueryBuilder.NumberRangeFilterTest.Shop do
      public?(true)
      attribute_writable?(true)
    end
  end
end

defmodule Cinder.QueryBuilder.NumberRangeFilterTest do
  use ExUnit.Case, async: true

  alias Cinder.Filters.NumberRange
  alias Cinder.QueryBuilder.NumberRangeFilterTest.{Item, Shop}

  describe "min, max and step" do
    import Phoenix.LiveViewTest, only: [render_component: 2]

    test "go on both inputs, from a column or a filter slot" do
      for slots <- [
            [
              col: [
                %{
                  field: "price",
                  filter: [type: :number_range, min: 0, max: 1000, step: 10],
                  __slot__: :col
                }
              ]
            ],
            [
              col: [%{field: "title", __slot__: :col}],
              filter: [
                %{
                  field: "price",
                  type: :number_range,
                  min: 0,
                  max: 1000,
                  step: 10,
                  __slot__: :filter
                }
              ]
            ]
          ] do
        html =
          render_component(
            &Cinder.collection/1,
            Map.new([id: "albums", resource: Music.Album] ++ slots)
          )

        inputs = html |> LazyHTML.from_fragment() |> LazyHTML.query(~s(input[type="number"]))

        assert Enum.count(inputs) == 2

        for input <- inputs do
          assert LazyHTML.attribute(input, "min") == ["0"]
          assert LazyHTML.attribute(input, "max") == ["1000"]
          assert LazyHTML.attribute(input, "step") == ["10"]
        end
      end
    end
  end

  defp matching_ids(resource \\ Item, field, min, max) do
    filter_value = %{type: :number_range, value: %{min: min, max: max}, operator: :between}

    resource
    |> Ash.Query.new()
    |> NumberRange.build_query(field, filter_value)
    |> Ash.read!()
    |> MapSet.new(& &1.id)
  end

  describe "build_query/3, by the records it returns" do
    test "includes both bounds on an integer field" do
      hits = for count <- [10, 15, 20], do: Ash.create!(Item, %{count: count}).id
      for count <- [9, 21], do: Ash.create!(Item, %{count: count})

      assert matching_ids("count", "10", "20") == MapSet.new(hits)
    end

    test "compares a decimal field with fractional bounds" do
      hit = Ash.create!(Item, %{price: Decimal.new("15.50")})
      Ash.create!(Item, %{price: Decimal.new("10.49")})
      Ash.create!(Item, %{price: Decimal.new("20.01")})

      assert matching_ids("price", "10.5", "20") == MapSet.new([hit.id])
    end

    test "leaves a range open on a side with no bound" do
      low = Ash.create!(Item, %{count: 5})
      high = Ash.create!(Item, %{count: 25})

      assert matching_ids("count", "10", "") == MapSet.new([high.id])
      assert matching_ids("count", "", "10") == MapSet.new([low.id])
      assert matching_ids("count", "", "") == MapSet.new([low.id, high.id])
    end

    test "through a to-many relationship, needs one related record inside the range" do
      inside = Ash.create!(Shop, %{})
      Ash.create!(Item, %{shop_id: inside.id, count: 15})

      # One item below the range and one above: each passes one bound, neither is in it
      outside = Ash.create!(Shop, %{})
      Ash.create!(Item, %{shop_id: outside.id, count: 5})
      Ash.create!(Item, %{shop_id: outside.id, count: 25})

      assert matching_ids(Shop, "items.count", "10", "20") == MapSet.new([inside.id])
    end

    test "matches a field in an embedded resource" do
      hit = Ash.create!(Item, %{meta: %{weight: 15}})
      Ash.create!(Item, %{meta: %{weight: 5}})
      Ash.create!(Item, %{meta: %{weight: 25}})

      assert matching_ids("meta__weight", "10", "20") == MapSet.new([hit.id])
    end
  end
end
