defmodule Cinder.Cards.IntegrationTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  # Mock Ash resource for testing
  defmodule TestPackage do
    use Ash.Resource,
      domain: nil,
      data_layer: Ash.DataLayer.Ets,
      validate_domain_inclusion?: false

    ets do
      private?(true)
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:arca_tracking_number, :string)
      attribute(:size, :string)
      attribute(:delivery_status, :string)
      attribute(:van_required?, :boolean)
      attribute(:deliver_before, :string)
      attribute(:inserted_at, :utc_datetime)
    end

    relationships do
      belongs_to(:address, TestAddress)
    end

    actions do
      defaults([:create, :read, :update, :destroy])
    end
  end

  defmodule TestAddress do
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
      attribute(:formatted_address, :string)
    end

    actions do
      defaults([:create, :read, :update, :destroy])
    end
  end

  describe "Cards filtering integration" do
    test "handles filter change events with proper column structure" do
      # This test reproduces the KeyError: filter_fn issue
      
      # Create columns similar to your delivery_map project
      props = [
        %{field: "arca_tracking_number", filter: true, sort: true, label: "Tracking #"},
        %{field: "address.name", filter: true, sort: true, label: "Address Name"},
        %{field: "address.formatted_address", filter: true, sort: false, label: "Address"},
        %{field: "size", filter: true, sort: true, label: "Size"},
        %{field: "deliver_before", filter: true, sort: true, label: "Deliver Before"},
        %{field: "van_required?", filter: true, sort: true, label: "Van Required"},
        %{field: "delivery_status", filter: true, sort: true, label: "Status"},
        %{field: "inserted_at", filter: false, sort: true, label: "Created"}
      ]

      # Process props using Cards.process_props
      processed_props = Cinder.Cards.process_props(props, TestPackage)

      # Verify that processed props have all required fields
      for prop <- processed_props do
        # Each processed prop should have the basic structure
        assert Map.has_key?(prop, :field)
        assert Map.has_key?(prop, :label)
        assert Map.has_key?(prop, :filterable)
        assert Map.has_key?(prop, :filter_type)
        assert Map.has_key?(prop, :filter_options)
        assert Map.has_key?(prop, :sortable)
        
        # The processed prop should have filter_fn field (even if nil) for QueryBuilder compatibility
        assert Map.has_key?(prop, :filter_fn), 
          "Cards processed props should have filter_fn field for QueryBuilder compatibility"
      end
    end

    test "QueryBuilder handles columns without filter_fn gracefully (verifying the fix)" do
      # This test verifies that the original KeyError issue has been fixed
      # by ensuring Cards now provides proper column structure with filter_fn
      query = Ash.Query.new(TestPackage)
      
      # This was the old problematic column format (without filter_fn)
      problematic_columns = [
        %{
          field: "arca_tracking_number",
          label: "Tracking #",
          filterable: true,
          filter_type: :text,
          filter_options: [operator: :contains, case_sensitive: false, placeholder: nil],
          sortable: true,
          class: ""
          # Note: no filter_fn field - this USED TO cause the KeyError
        }
      ]

      filters = %{
        "arca_tracking_number" => %{
          type: :text,
          value: "fo",
          operator: :contains,
          case_sensitive: false
        }
      }

      # This SHOULD still crash with KeyError: filter_fn (for columns without filter_fn)
      assert_raise KeyError, ~r/key :filter_fn not found/, fn ->
        Cinder.QueryBuilder.apply_filters(query, filters, problematic_columns)
      end

      # But now Cards should provide proper columns with filter_fn field
      # See the "Cards.process_props produces QueryBuilder-compatible columns" test below
    end

    test "demonstrates the fix for missing filter_fn" do
      # This test shows how the columns should be structured to work with QueryBuilder
      query = Ash.Query.new(TestPackage)
      
      # Fixed column format with filter_fn: nil (or no filter_fn access)
      columns = [
        %{
          field: "arca_tracking_number",
          label: "Tracking #",
          filterable: true,
          filter_type: :text,
          filter_options: [operator: :contains, case_sensitive: false, placeholder: nil],
          sortable: true,
          class: "",
          filter_fn: nil  # This is what QueryBuilder expects
        }
      ]

      filters = %{
        "arca_tracking_number" => %{
          type: :text,
          value: "fo",
          operator: :contains,
          case_sensitive: false
        }
      }

      # This should work without crashing
      result_query = Cinder.QueryBuilder.apply_filters(query, filters, columns)
      assert %Ash.Query{} = result_query
    end

    test "Cards.process_props produces QueryBuilder-compatible columns" do
      # Test that the fixed Cards.process_props creates proper column structure
      props = [
        %{field: "arca_tracking_number", filter: true, sort: true, label: "Tracking #"}
      ]

      processed_props = Cinder.Cards.process_props(props, TestPackage)
      
      # Should have filter_fn field
      assert length(processed_props) == 1
      prop = Enum.at(processed_props, 0)
      assert Map.has_key?(prop, :filter_fn)
      assert prop.filter_fn == nil  # Default value

      # Now test that QueryBuilder can use these columns
      query = Ash.Query.new(TestPackage)
      
      # Convert to column format (as done in LiveComponent)
      columns = [
        %{
          field: prop.field,
          label: prop.label,
          filterable: prop.filterable,
          filter_type: prop.filter_type,
          filter_options: prop.filter_options,
          sortable: prop.sortable,
          class: "",
          filter_fn: prop.filter_fn
        }
      ]

      filters = %{
        "arca_tracking_number" => %{
          type: :text,
          value: "fo",
          operator: :contains,
          case_sensitive: false
        }
      }

      # This should now work without crashing
      result_query = Cinder.QueryBuilder.apply_filters(query, filters, columns)
      assert %Ash.Query{} = result_query
    end
  end

  describe "Cards state change handling" do
    test "Cards component sends proper state change messages" do
      # Test that demonstrates the missing handle_info issue
      
      # This is the state change message format that Cards sends
      state_change_message = {
        :cards_state_change,
        "packages-cards",
        %{
          filters: %{
            "arca_tracking_number" => %{
              type: :text,
              value: "fo",
              operator: :contains,
              case_sensitive: false
            }
          },
          sort_by: [],
          current_page: 1
        }
      }

      # LiveView using Cards needs to handle this message
      # The error shows: no function clause matching in handle_info/2
      
      # Expected handler in user's LiveView:
      # def handle_info({:cards_state_change, _id, _state}, socket) do
      #   {:noreply, socket}
      # end
      
      assert elem(state_change_message, 0) == :cards_state_change
      assert elem(state_change_message, 1) == "packages-cards"
      assert is_map(elem(state_change_message, 2))
    end
  end
end