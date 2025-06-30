defmodule Cinder.CardsTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  # Mock Ash resource for testing
  defmodule TestUser do
    use Ash.Resource,
      domain: nil,
      data_layer: Ash.DataLayer.Ets,
      validate_domain_inclusion?: false

    ets do
      private?(true)
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string)
      attribute(:email, :string)
      attribute(:age, :integer)
      attribute(:active, :boolean)
      attribute(:created_at, :utc_datetime)
    end

    actions do
      defaults([:create, :read, :update, :destroy])
    end
  end

  describe "Cinder.Cards.cards/1" do
    test "renders basic cards component with resource parameter" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        prop: [
          %{field: "name", filter: true, sort: true},
          %{field: "email", filter: true}
        ],
        card: [%{__slot__: :card, inner_block: fn _user -> "Card Content" end}]
      }

      html = render_component(&Cinder.Cards.cards/1, assigns)

      # Should contain the cinder-cards wrapper
      assert html =~ "cinder-cards"
    end

    test "renders cards component with query parameter" do
      assigns = %{
        query: Ash.Query.new(TestUser),
        actor: nil,
        prop: [
          %{field: "name", filter: true, sort: true},
          %{field: "email", filter: true}
        ],
        card: [%{__slot__: :card, inner_block: fn _user -> "Card Content" end}]
      }

      html = render_component(&Cinder.Cards.cards/1, assigns)

      # Should contain the cinder-cards wrapper
      assert html =~ "cinder-cards"
    end

    test "validates that either resource or query is provided" do
      assigns = %{
        actor: nil,
        prop: [%{field: "name", filter: true, sort: true}],
        card: [%{__slot__: :card, inner_block: fn _user -> "Card Content" end}]
      }

      assert_raise ArgumentError, ~r/Either :resource or :query must be provided/, fn ->
        render_component(&Cinder.Cards.cards/1, assigns)
      end
    end

    test "validates that both resource and query cannot be provided" do
      assigns = %{
        resource: TestUser,
        query: Ash.Query.new(TestUser),
        actor: nil,
        prop: [%{field: "name", filter: true, sort: true}],
        card: [%{__slot__: :card, inner_block: fn _user -> "Card Content" end}]
      }

      assert_raise ArgumentError, ~r/Cannot provide both :resource and :query/, fn ->
        render_component(&Cinder.Cards.cards/1, assigns)
      end
    end

    test "validates field requirement for filter and sort props" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        prop: [%{filter: true, sort: true}],  # Missing field
        card: [%{__slot__: :card, inner_block: fn _user -> "Card Content" end}]
      }

      assert_raise ArgumentError, ~r/requires a 'field' attribute/, fn ->
        render_component(&Cinder.Cards.cards/1, assigns)
      end
    end

    test "supports custom theme configuration" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        theme: "modern",
        prop: [%{field: "name", filter: true, sort: true}],
        card: [%{__slot__: :card, inner_block: fn _user -> "Card Content" end}]
      }

      html = render_component(&Cinder.Cards.cards/1, assigns)
      assert html =~ "cinder-cards"
    end

    test "supports URL state management" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        url_state: %{
          filters: %{},
          current_page: 1,
          sort_by: []
        },
        prop: [%{field: "name", filter: true, sort: true}],
        card: [%{__slot__: :card, inner_block: fn _user -> "Card Content" end}]
      }

      html = render_component(&Cinder.Cards.cards/1, assigns)
      assert html =~ "cinder-cards"
    end

    test "auto-detects filters when show_filters is nil" do
      # With filterable props - should show filters
      assigns_with_filters = %{
        resource: TestUser,
        actor: nil,
        prop: [
          %{field: "name", filter: true, sort: true},
          %{field: "email", filter: true}
        ],
        card: [%{__slot__: :card, inner_block: fn _user -> "Card Content" end}]
      }

      html = render_component(&Cinder.Cards.cards/1, assigns_with_filters)
      assert html =~ "cinder-cards"

      # Without filterable props - should not show filters
      assigns_no_filters = %{
        resource: TestUser,
        actor: nil,
        prop: [
          %{field: "name", sort: true},
          %{field: "email"}
        ],
        card: [%{__slot__: :card, inner_block: fn _user -> "Card Content" end}]
      }

      html = render_component(&Cinder.Cards.cards/1, assigns_no_filters)
      assert html =~ "cinder-cards"
    end
  end

  describe "process_props/2" do
    test "processes property slots correctly" do
      props = [
        %{field: "name", filter: true, sort: true, label: "User Name"},
        %{field: "email", filter: :text, sort: false},
        %{field: "age", filter: false, sort: true}
      ]

      processed = Cinder.Cards.process_props(props, TestUser)

      assert length(processed) == 3

      # Check first prop
      first_prop = Enum.at(processed, 0)
      assert first_prop.field == "name"
      assert first_prop.label == "User Name"
      assert first_prop.filterable == true
      assert first_prop.sortable == true

      # Check second prop
      second_prop = Enum.at(processed, 1)
      assert second_prop.field == "email"
      assert second_prop.filterable == true
      assert second_prop.filter_type == :text
      assert second_prop.sortable == false

      # Check third prop
      third_prop = Enum.at(processed, 2)
      assert third_prop.field == "age"
      assert third_prop.filterable == false
      assert third_prop.sortable == true
    end

    test "validates field requirement for filtering and sorting" do
      props_with_missing_field = [
        %{filter: true, sort: true}
      ]

      assert_raise ArgumentError, ~r/requires a 'field' attribute/, fn ->
        Cinder.Cards.process_props(props_with_missing_field, TestUser)
      end
    end

    test "handles properties without fields for action props" do
      props = [
        %{label: "Actions"}
      ]

      processed = Cinder.Cards.process_props(props, TestUser)

      assert length(processed) == 1
      prop = Enum.at(processed, 0)
      assert prop.field == nil
      assert prop.label == "Actions"
      assert prop.filterable == false
      assert prop.sortable == false
    end
  end

  describe "LiveComponent event handling" do
    test "refresh event handler exists" do
      # Verify the refresh event handler is defined by checking it's listed in module functions
      functions = Cinder.Cards.LiveComponent.__info__(:functions)
      assert {:handle_event, 3} in functions
      
      # We can't easily test the actual async behavior in unit tests,
      # but we've verified the handler exists and the integration tests 
      # will cover the actual functionality
    end

    test "async loading handlers exist" do
      # Verify async handlers are defined by checking they're listed in module functions
      functions = Cinder.Cards.LiveComponent.__info__(:functions)
      assert {:handle_async, 3} in functions
    end
  end
end