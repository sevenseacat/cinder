defmodule Cinder.FieldTest do
  use ExUnit.Case, async: true

  alias Cinder.Field

  # One of each kind of field a column can name

  defmodule Inner do
    @moduledoc false
    use Ash.Resource, data_layer: :embedded

    attributes do
      attribute(:street, :string)
    end
  end

  defmodule Details do
    @moduledoc false
    use Ash.Resource, data_layer: :embedded

    attributes do
      attribute(:label, :string)
      attribute(:size, :atom, constraints: [one_of: [:small, :large]])
      attribute(:inner, Inner)
      attribute(:extra, :map)
    end
  end

  defmodule InMemoryCalc do
    @moduledoc false
    use Ash.Resource.Calculation

    @impl true
    def calculate(records, _opts, _context), do: Enum.map(records, & &1.title)
  end

  defmodule ExpressionCalc do
    @moduledoc false
    use Ash.Resource.Calculation

    @impl true
    def expression(_opts, _context), do: Ash.Expr.expr(title)
  end

  # Aggregates need a data layer that supports them
  defmodule Owner do
    @moduledoc false
    use Ash.Resource, domain: nil, data_layer: Ash.DataLayer.Ets

    # Each test process has its own records
    ets do
      private?(true)
    end

    actions do
      defaults([:read])
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string)
    end

    relationships do
      has_many(:items, Cinder.FieldTest.Item, destination_attribute: :owner_id)
    end

    calculations do
      calculate(:name_lower, :string, expr(string_downcase(name)))
    end

    aggregates do
      count(:item_count, :items)
    end
  end

  defmodule Item do
    @moduledoc false
    use Ash.Resource, domain: nil, data_layer: Ash.DataLayer.Ets

    # Each test process has its own records
    ets do
      private?(true)
    end

    actions do
      defaults([:read])
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:title, :string)
      attribute(:details, Details)
      attribute(:details_list, {:array, Details})
      attribute(:meta, :map)
      attribute(:meta_list, {:array, :map})
      attribute(:tags, {:array, :string})
    end

    relationships do
      belongs_to(:owner, Cinder.FieldTest.Owner)
    end

    calculations do
      calculate(:title_lower, :string, expr(string_downcase(title)))
      calculate(:in_memory, :string, Cinder.FieldTest.InMemoryCalc)
      calculate(:module_expression, :string, Cinder.FieldTest.ExpressionCalc)

      calculate :needs_arg, :string, expr(title <> ^arg(:suffix)) do
        argument(:suffix, :string, allow_nil?: false)
      end

      calculate :optional_arg, :string, expr(title <> ^arg(:suffix)) do
        argument(:suffix, :string, default: "!")
      end
    end
  end

  # To read them by, for `expr/1`
  defmodule Domain do
    @moduledoc false
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource(Cinder.FieldTest.Owner)
      resource(Cinder.FieldTest.Item)
    end
  end

  defp kind(resource, field) do
    case Field.resolve(resource, field) do
      {:ok, resolved} -> resolved.kind
      :error -> :error
    end
  end

  describe "resolve/2" do
    test "fields directly on the resource" do
      assert {:ok, %{kind: :attribute, resource: Item, name: :title, relationships: []}} =
               Field.resolve(Item, "title")

      assert kind(Item, "owner") == :relationship
      assert kind(Owner, "item_count") == :aggregate
      assert kind(Item, "title_lower") == :calculation
      assert kind(Item, "nope") == :error
    end

    test "relationship paths resolve on the related resource" do
      assert {:ok, %{kind: :attribute, resource: Owner, name: :name, relationships: [:owner]}} =
               Field.resolve(Item, "owner.name")

      assert {:ok, %{kind: :aggregate, relationships: [:owner]}} =
               Field.resolve(Item, "owner.item_count")

      assert {:ok, %{kind: :calculation, relationships: [:owner, :items]}} =
               Field.resolve(Item, "owner.items.title_lower")

      assert kind(Item, "nope.name") == :error
      assert kind(Item, "owner.nope") == :error
    end

    test "embedded fields, nested, in arrays, and through relationships" do
      assert {:ok, %{kind: :embedded, resource: Item, name: :details}} =
               Field.resolve(Item, "details__label")

      assert kind(Item, "details__inner__street") == :embedded
      assert kind(Item, "details_list__label") == :embedded
      assert kind(Item, "owner.items.details__label") == :embedded

      assert kind(Item, "details__nope") == :error
      assert kind(Item, "details__inner__nope") == :error
      assert kind(Item, "nope__label") == :error
    end

    test "map attributes accept any nested name, other types none" do
      assert kind(Item, "meta__anything") == :embedded
      assert kind(Item, "meta__deeply__nested") == :embedded
      assert kind(Item, "meta_list__anything") == :embedded
      assert kind(Item, "details__extra__anything") == :embedded

      assert kind(Item, "title__anything") == :error
      assert kind(Item, "tags__anything") == :error
    end

    test "malformed and missing fields don't resolve" do
      for field <- [
            nil,
            "",
            "owner.",
            ".name",
            "owner..name",
            "details__",
            "__label",
            "details__label.title",
            :title
          ] do
        assert Field.resolve(Item, field) == :error, inspect(field)
      end

      assert Field.resolve(NotAnAshResource, "name") == :error
      assert Field.resolve(nil, "name") == :error
    end

    test "unknown names create no atoms" do
      name = "cinder_field_test_#{System.unique_integer([:positive])}"

      for field <- [name, "#{name}.name", "owner.#{name}", "#{name}__label", "details__#{name}"] do
        assert Field.resolve(Item, field) == :error
      end

      assert_raise ArgumentError, fn -> String.to_existing_atom(name) end
    end
  end

  describe "query_error/1" do
    defp query_error(field) do
      {:ok, resolved} = Field.resolve(Item, field)
      Field.query_error(resolved)
    end

    test "attributes, embedded fields, aggregates and expression calculations can be queried" do
      for field <- ["title", "details__label", "owner.item_count", "title_lower", "optional_arg"] do
        assert query_error(field) == nil, field
      end

      # A module calculation with an expression/2 runs in the data layer
      assert query_error("module_expression") == nil
    end

    test "in-memory calculations, calculations needing arguments and relationships can't" do
      assert query_error("in_memory") =~ "in-memory calculation"
      assert query_error("in_memory") =~ "InMemoryCalc"
      assert query_error("needs_arg") =~ "suffix"
      assert query_error("owner") =~ "relationship"
    end
  end

  describe "type/1" do
    defp type(field) do
      {:ok, resolved} = Field.resolve(Item, field)
      Field.type(resolved)
    end

    test "the Ash type of attributes, calculations and aggregates, through relationships" do
      assert type("tags") == {:array, Ash.Type.String}
      assert type("title_lower") == Ash.Type.String
      assert type("owner.item_count") == Ash.Type.Integer
      assert type("owner.items.tags") == {:array, Ash.Type.String}
      assert type("owner") == nil
    end

    test "the type of the field at the end of an embedded path, unknown under a map" do
      assert type("details__label") == Ash.Type.String
      assert type("details__inner__street") == Ash.Type.String
      assert type("details_list__label") == Ash.Type.String
      assert type("details__extra__anything") == nil
      assert type("meta__anything") == nil
    end
  end

  describe "constraints/1" do
    defp constraints(field) do
      {:ok, resolved} = Field.resolve(Item, field)
      Field.constraints(resolved)
    end

    test "the constraints of attributes, embedded fields and calculations" do
      assert constraints("tags")[:items] != nil
      assert constraints("details__size")[:one_of] == [:small, :large]
      assert constraints("title_lower")[:trim?] == true
      assert constraints("owner.item_count") == []
      assert constraints("meta__anything") == []
      assert constraints("owner") == []
    end
  end

  describe "load/1" do
    defp load(field) do
      {:ok, resolved} = Field.resolve(Item, field)
      Field.load(resolved)
    end

    test "what showing a field needs loaded" do
      assert load("title") == nil
      assert load("details__label") == nil
      assert load("title_lower") == :title_lower
      assert load("in_memory") == :in_memory
      assert load("optional_arg") == :optional_arg
      assert load("needs_arg") == nil
      assert load("owner") == {:owner, []}
      assert load("owner.name") == {:owner, []}
      assert load("owner.name_lower") == {:owner, [:name_lower]}
      assert load("owner.items.title_lower") == {:owner, [{:items, [:title_lower]}]}
      assert load("owner.items.details__label") == {:owner, [{:items, []}]}
    end
  end

  describe "expr/1" do
    # The records whose field contains `text`, filtering by the field's expression
    defp matching(resource, field, text) do
      require Ash.Query

      {:ok, resolved} = Field.resolve(resource, field)
      expr = Field.expr(resolved)

      resource
      |> Ash.Query.filter(contains(type(^expr, :string), ^text))
      |> Ash.read!(domain: Domain)
      |> Enum.map(&(Map.get(&1, :title) || &1.name))
      |> Enum.sort()
    end

    test "an expression of each kind of field, to query by" do
      ann = Ash.Seed.seed!(Owner, %{name: "Ann"})
      bob = Ash.Seed.seed!(Owner, %{name: "Bob"})

      Ash.Seed.seed!(Item, %{
        title: "Kettle",
        owner_id: ann.id,
        details: %Details{label: "Steel", inner: %Inner{street: "High St"}},
        meta: %{colour: "red"}
      })

      Ash.Seed.seed!(Item, %{title: "Lamp", owner_id: ann.id, details: %Details{label: "Brass"}})
      Ash.Seed.seed!(Item, %{title: "Mug", owner_id: bob.id, details: %Details{label: "Clay"}})

      assert matching(Item, "title", "Kett") == ["Kettle"]
      assert matching(Item, "title_lower", "kett") == ["Kettle"]
      assert matching(Item, "owner.name", "Bob") == ["Mug"]
      assert matching(Item, "owner.name_lower", "bob") == ["Mug"]
      assert matching(Item, "details__label", "Brass") == ["Lamp"]
      assert matching(Item, "details__inner__street", "High") == ["Kettle"]
      assert matching(Item, "meta__colour", "red") == ["Kettle"]
      assert matching(Owner, "item_count", "2") == ["Ann"]

      # Through a to-many relationship, a record matches if any related one does
      assert matching(Owner, "items.title", "Mug") == ["Bob"]
      assert matching(Owner, "items.details__label", "Steel") == ["Ann"]
    end
  end
end
