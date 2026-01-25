defmodule Cinder.CustomFilterOptionsTest do
  use ExUnit.Case, async: true

  defmodule TestWeapon do
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
      attribute(:damage, :integer)

      attribute(:type, :atom,
        constraints: [
          one_of: [:short_blade, :long_blade, :blunt_1_hand, :blunt_2_hand, :bow, :crossbow]
        ]
      )
    end

    actions do
      defaults([:create, :read, :update, :destroy])
    end
  end

  describe "custom filter_options in slot" do
    test "slot with custom filter_options merges with inferred options" do
      # Create a slot configuration with custom multiselect options
      slot_config = %{
        field: "type",
        filterable: true,
        filter_type: :multi_select,
        filter_options: [
          options: [
            {"Blade", "short_blade"},
            {"Blunt", "blunt_1_hand"}
          ]
        ]
      }

      parsed_column = Cinder.Column.parse_column(slot_config, TestWeapon)

      # Should merge custom options with inferred defaults
      assert parsed_column.filter_type == :multi_select

      # Should have custom options plus inferred defaults
      assert Keyword.get(parsed_column.filter_options, :options) == [
               {"Blade", "short_blade"},
               {"Blunt", "blunt_1_hand"}
             ]

      # Should also have inferred defaults
      assert Keyword.get(parsed_column.filter_options, :prompt) == "All Type"
      assert Keyword.get(parsed_column.filter_options, :match_mode) == :any
    end

    test "slot without custom filter_options uses inferred enum options" do
      # Create a slot configuration without custom options
      slot_config = %{
        field: "type",
        filterable: true,
        filter_type: :multi_select
      }

      parsed_column = Cinder.Column.parse_column(slot_config, TestWeapon)

      # Should use inferred options from the enum
      assert parsed_column.filter_type == :multi_select

      # Should have auto-generated options from the enum constraint
      options = Keyword.get(parsed_column.filter_options, :options, [])

      # Should have all enum values from the constraint
      assert length(options) == 6

      # Check that it includes expected enum values with proper labels
      option_values = Enum.map(options, fn {_label, value} -> value end)
      assert :short_blade in option_values
      assert :long_blade in option_values
      assert :blunt_1_hand in option_values
      assert :blunt_2_hand in option_values
      assert :bow in option_values
      assert :crossbow in option_values

      # Check that labels are properly humanized
      option_labels = Enum.map(options, fn {label, _value} -> label end)
      assert "Short Blade" in option_labels
      assert "Long Blade" in option_labels
      assert "Blunt 1 Hand" in option_labels
    end

    test "select filter with custom options" do
      slot_config = %{
        field: "type",
        filterable: true,
        filter_type: :select,
        filter_options: [
          options: [
            {"Melee", "melee"},
            {"Ranged", "ranged"}
          ],
          prompt: "Choose weapon category"
        ]
      }

      parsed_column = Cinder.Column.parse_column(slot_config, TestWeapon)

      assert parsed_column.filter_type == :select

      assert parsed_column.filter_options[:options] == [
               {"Melee", "melee"},
               {"Ranged", "ranged"}
             ]

      assert parsed_column.filter_options[:prompt] == "Choose weapon category"
    end

    test "multi_select uses column label for default prompt" do
      slot_config = %{
        field: "type",
        label: "Weapon Type",
        filterable: true,
        filter_type: :multi_select
      }

      parsed_column = Cinder.Column.parse_column(slot_config, TestWeapon)

      # Should use the column label for the default prompt
      assert parsed_column.filter_options[:prompt] == "All Weapon Type"
    end

    test "select uses column label for default prompt" do
      slot_config = %{
        field: "type",
        label: "Category",
        filterable: true,
        filter_type: :select
      }

      parsed_column = Cinder.Column.parse_column(slot_config, TestWeapon)

      # Should use the column label for the default prompt
      assert parsed_column.filter_options[:prompt] == "All Category"
    end

    test "falls back to humanized field name when no label provided" do
      slot_config = %{
        field: "type",
        filterable: true,
        filter_type: :multi_select
      }

      parsed_column = Cinder.Column.parse_column(slot_config, TestWeapon)

      # Should fall back to humanized field name
      assert parsed_column.filter_options[:prompt] == "All Type"
    end

    test "Collection.process_columns passes label through for filter prompt" do
      # This tests the real flow through Collection.process_columns
      # which is what Cinder.Table uses
      slots = [
        %{
          field: "type",
          label: "Weapon Category",
          filter: [type: :multi_select]
        }
      ]

      [processed] = Cinder.Collection.process_columns(slots, TestWeapon)

      # The label should be used for the filter prompt
      assert processed.label == "Weapon Category"
      assert processed.filter_options[:prompt] == "All Weapon Category"
    end

    test "Collection.process_columns falls back to humanized field when no label" do
      slots = [
        %{
          field: "type",
          filter: [type: :multi_select]
        }
      ]

      [processed] = Cinder.Collection.process_columns(slots, TestWeapon)

      # Should fall back to humanized field name for both label and prompt
      assert processed.label == "Type"
      assert processed.filter_options[:prompt] == "All Type"
    end

    test "text filter with custom options" do
      slot_config = %{
        field: "name",
        filterable: true,
        filter_type: :text,
        filter_options: [
          placeholder: "Search weapon names...",
          case_sensitive: true,
          operator: :starts_with
        ]
      }

      parsed_column = Cinder.Column.parse_column(slot_config, TestWeapon)

      assert parsed_column.filter_type == :text
      assert parsed_column.filter_options[:placeholder] == "Search weapon names..."
      assert parsed_column.filter_options[:case_sensitive] == true
      assert parsed_column.filter_options[:operator] == :starts_with
    end

    test "number_range filter with custom options" do
      # Add a numeric field for testing
      slot_config = %{
        field: "damage",
        filterable: true,
        filter_type: :number_range,
        filter_options: [
          min: 1,
          max: 100,
          step: 5
        ]
      }

      parsed_column = Cinder.Column.parse_column(slot_config, TestWeapon)

      assert parsed_column.filter_type == :number_range
      assert parsed_column.filter_options[:min] == 1
      assert parsed_column.filter_options[:max] == 100
      assert parsed_column.filter_options[:step] == 5
    end
  end

  describe "FilterManager with custom options" do
    test "processes custom multiselect options correctly" do
      columns = [
        %{
          field: "type",
          filterable: true,
          filter_type: :multi_select,
          filter_options: [
            options: [
              {"Blade", "short_blade"},
              {"Blunt", "blunt_1_hand"}
            ]
          ]
        }
      ]

      # Test that filter processing works with custom options
      filter_params = %{"type" => ["short_blade", "blunt_1_hand"]}
      processed_filters = Cinder.FilterManager.params_to_filters(filter_params, columns)

      assert %{
               "type" => %{
                 type: :multi_select,
                 value: ["short_blade", "blunt_1_hand"],
                 operator: :in
               }
             } = processed_filters
    end

    test "builds filter values with custom options" do
      columns = [
        %{
          field: "type",
          filterable: true,
          filter_type: :multi_select,
          filter_options: [
            options: [
              {"Blade", "short_blade"},
              {"Blunt", "blunt_1_hand"}
            ]
          ]
        }
      ]

      filters = %{
        "type" => %{
          type: :multi_select,
          value: ["short_blade"],
          operator: :in
        }
      }

      filter_values = Cinder.FilterManager.build_filter_values(columns, filters)

      assert filter_values["type"] == ["short_blade"]
    end
  end
end
