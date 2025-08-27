defmodule Cinder.FilterManagerRelationshipTest do
  use ExUnit.Case, async: true

  alias Cinder.FilterManager

  # Test enums - must be defined before resources that use them
  defmodule TestUserTypeEnum do
    use Ash.Type.Enum, values: [:admin, :member, :guest]
  end

  # Test resources for relationship filtering
  defmodule TestCompany do
    use Ash.Resource, domain: nil

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string)
      attribute(:founded_date, :date)
      attribute(:active, :boolean)
      attribute(:employee_count, :integer)
    end
  end

  defmodule TestUser do
    use Ash.Resource, domain: nil

    attributes do
      uuid_primary_key(:id)
      attribute(:email, :string)
      attribute(:user_type, TestUserTypeEnum)
      attribute(:created_at, :utc_datetime)
      attribute(:active, :boolean)
      attribute(:company_id, :uuid)
    end

    relationships do
      belongs_to(:company, TestCompany, destination_attribute: :id, source_attribute: :company_id)
    end
  end

  defmodule TestOrganizationMembership do
    use Ash.Resource, domain: nil

    attributes do
      uuid_primary_key(:id)
      attribute(:role, :string)
      attribute(:joined_at, :date)
      attribute(:user_id, :uuid)
    end

    relationships do
      belongs_to(:user, TestUser, destination_attribute: :id, source_attribute: :user_id)
    end
  end

  describe "infer_filter_config/3 with relationship fields" do
    test "infers correct filter type for enum field on related resource" do
      slot = %{
        filterable: true,
        filter_options: []
      }

      # This should infer :select filter type for the enum field on the related user resource
      config =
        FilterManager.infer_filter_config("user.user_type", TestOrganizationMembership, slot)

      assert config.filter_type == :select,
             "Expected :select filter for enum field user.user_type, got #{inspect(config.filter_type)}"

      assert is_list(config.filter_options)
    end

    test "infers correct filter type for date field on related resource" do
      slot = %{
        filterable: true,
        filter_options: []
      }

      # This should infer :date_range filter type for the date field on the related user resource
      config =
        FilterManager.infer_filter_config("user.created_at", TestOrganizationMembership, slot)

      assert config.filter_type == :date_range,
             "Expected :date_range filter for date field user.created_at, got #{inspect(config.filter_type)}"

      assert is_list(config.filter_options)
    end

    test "infers correct filter type for boolean field on related resource" do
      slot = %{
        filterable: true,
        filter_options: []
      }

      # This should infer :boolean filter type for the boolean field on the related user resource
      config = FilterManager.infer_filter_config("user.active", TestOrganizationMembership, slot)

      assert config.filter_type == :boolean,
             "Expected :boolean filter for boolean field user.active, got #{inspect(config.filter_type)}"

      assert is_list(config.filter_options)
    end

    test "infers correct filter type for string field on related resource" do
      slot = %{
        filterable: true,
        filter_options: []
      }

      # This should infer :text filter type for the string field on the related user resource
      config = FilterManager.infer_filter_config("user.email", TestOrganizationMembership, slot)

      assert config.filter_type == :text,
             "Expected :text filter for string field user.email, got #{inspect(config.filter_type)}"

      assert is_list(config.filter_options)
    end

    test "infers correct filter type for nested relationship fields" do
      slot = %{
        filterable: true,
        filter_options: []
      }

      # This should infer :text filter type for the string field on the nested related resource
      config =
        FilterManager.infer_filter_config("user.company.name", TestOrganizationMembership, slot)

      assert config.filter_type == :text,
             "Expected :text filter for nested relationship field user.company.name, got #{inspect(config.filter_type)}"

      assert is_list(config.filter_options)
    end

    test "infers correct filter type for date field on nested relationship" do
      slot = %{
        filterable: true,
        filter_options: []
      }

      # This should infer :date_range filter type for the date field on the nested related resource
      config =
        FilterManager.infer_filter_config(
          "user.company.founded_date",
          TestOrganizationMembership,
          slot
        )

      assert config.filter_type == :date_range,
             "Expected :date_range filter for nested date field user.company.founded_date, got #{inspect(config.filter_type)}"

      assert is_list(config.filter_options)
    end

    test "infers correct filter type for integer field on nested relationship" do
      slot = %{
        filterable: true,
        filter_options: []
      }

      # This should infer :number_range filter type for the integer field on the nested related resource
      config =
        FilterManager.infer_filter_config(
          "user.company.employee_count",
          TestOrganizationMembership,
          slot
        )

      assert config.filter_type == :number_range,
             "Expected :number_range filter for integer field user.company.employee_count, got #{inspect(config.filter_type)}"

      assert is_list(config.filter_options)
    end

    test "falls back to text filter for non-existent relationship field" do
      slot = %{
        filterable: true,
        filter_options: []
      }

      # This should fall back to :text filter since the field doesn't exist
      config =
        FilterManager.infer_filter_config(
          "user.non_existent_field",
          TestOrganizationMembership,
          slot
        )

      assert config.filter_type == :text,
             "Expected :text filter fallback for non-existent field, got #{inspect(config.filter_type)}"

      assert is_list(config.filter_options)
    end

    test "falls back to text filter for non-existent relationship" do
      slot = %{
        filterable: true,
        filter_options: []
      }

      # This should fall back to :text filter since the relationship doesn't exist
      config =
        FilterManager.infer_filter_config(
          "non_existent_relation.field",
          TestOrganizationMembership,
          slot
        )

      assert config.filter_type == :text,
             "Expected :text filter fallback for non-existent relationship, got #{inspect(config.filter_type)}"

      assert is_list(config.filter_options)
    end

    test "respects explicit filter type override for relationship fields" do
      slot = %{
        filterable: true,
        # Explicit override
        filter_type: :number_range,
        filter_options: []
      }

      # Even though user.user_type is an enum, explicit override should be respected
      config =
        FilterManager.infer_filter_config("user.user_type", TestOrganizationMembership, slot)

      assert config.filter_type == :number_range,
             "Expected explicit filter type override to be respected"

      assert is_list(config.filter_options)
    end
  end

  describe "get_ash_attribute/2 with relationship fields" do
    test "returns correct attribute for single relationship field" do
      # This is testing the internal get_ash_attribute function indirectly
      # by checking that the inferred filter config is correct
      slot = %{
        filterable: true,
        filter_options: []
      }

      config =
        FilterManager.infer_filter_config("user.user_type", TestOrganizationMembership, slot)

      # If get_ash_attribute worked correctly, we should get the enum filter type
      assert config.filter_type == :select,
             "get_ash_attribute should return the enum attribute from related resource"
    end

    test "returns correct attribute for nested relationship field" do
      slot = %{
        filterable: true,
        filter_options: []
      }

      config =
        FilterManager.infer_filter_config("user.company.name", TestOrganizationMembership, slot)

      # If get_ash_attribute worked correctly, we should get the string filter type
      assert config.filter_type == :text,
             "get_ash_attribute should return the string attribute from nested related resource"
    end
  end

  describe "field parsing integration" do
    test "correctly identifies relationship field notation" do
      # This tests that the field parsing correctly identifies relationship fields
      # and that the filter manager handles them properly

      slot = %{
        filterable: true,
        filter_options: []
      }

      # Test various valid relationship field formats
      test_cases = [
        {"user.email", :text},
        {"user.user_type", :select},
        {"user.created_at", :date_range},
        {"user.active", :boolean},
        {"user.company.name", :text},
        {"user.company.founded_date", :date_range},
        {"user.company.employee_count", :number_range},
        {"user.company.active", :boolean}
      ]

      for {field, expected_type} <- test_cases do
        config = FilterManager.infer_filter_config(field, TestOrganizationMembership, slot)

        assert config.filter_type == expected_type,
               "Expected #{expected_type} for field #{field}, got #{inspect(config.filter_type)}"
      end
    end
  end
end
