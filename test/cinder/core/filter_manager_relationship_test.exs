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
