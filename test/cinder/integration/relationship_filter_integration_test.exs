defmodule Cinder.RelationshipFilterIntegrationTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  alias Cinder.FilterManager

  # Test enums and resources for integration testing
  defmodule UserRole do
    use Ash.Type.Enum, values: [:admin, :manager, :employee, :contractor]
  end

  defmodule CompanyType do
    use Ash.Type.Enum, values: [:startup, :enterprise, :nonprofit, :government]
  end

  defmodule Company do
    use Ash.Resource, domain: nil

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string)
      attribute(:company_type, CompanyType)
      attribute(:founded_date, :date)
      attribute(:active, :boolean, default: true)
      attribute(:employee_count, :integer)
      attribute(:annual_revenue, :decimal)
    end
  end

  defmodule User do
    use Ash.Resource, domain: nil

    attributes do
      uuid_primary_key(:id)
      attribute(:email, :string)
      attribute(:full_name, :string)
      attribute(:role, UserRole)
      attribute(:created_at, :utc_datetime)
      attribute(:active, :boolean, default: true)
      attribute(:salary, :decimal)
      attribute(:company_id, :uuid)
    end

    relationships do
      belongs_to(:company, Company, destination_attribute: :id, source_attribute: :company_id)
    end
  end

  defmodule ProjectAssignment do
    use Ash.Resource, domain: nil

    attributes do
      uuid_primary_key(:id)
      attribute(:project_name, :string)
      attribute(:assigned_date, :date)
      attribute(:completed, :boolean, default: false)
      attribute(:user_id, :uuid)
    end

    relationships do
      belongs_to(:user, User, destination_attribute: :id, source_attribute: :user_id)
    end
  end

  describe "relationship filter integration" do
    test "table with relationship filters renders correct filter types" do
      # Simulate table component assigns with relationship fields
      assigns = %{
        resource: ProjectAssignment,
        actor: nil,
        columns: [
          %{
            field: "user.role",
            label: "User Role",
            filterable: true,
            filter_type: nil,
            filter_options: []
          },
          %{
            field: "user.created_at",
            label: "User Join Date",
            filterable: true,
            filter_type: nil,
            filter_options: []
          },
          %{
            field: "user.active",
            label: "User Active",
            filterable: true,
            filter_type: nil,
            filter_options: []
          },
          %{
            field: "user.salary",
            label: "User Salary",
            filterable: true,
            filter_type: nil,
            filter_options: []
          },
          %{
            field: "user.company.name",
            label: "Company Name",
            filterable: true,
            filter_type: nil,
            filter_options: []
          },
          %{
            field: "user.company.company_type",
            label: "Company Type",
            filterable: true,
            filter_type: nil,
            filter_options: []
          },
          %{
            field: "user.company.founded_date",
            label: "Company Founded",
            filterable: true,
            filter_type: nil,
            filter_options: []
          },
          %{
            field: "user.company.employee_count",
            label: "Company Size",
            filterable: true,
            filter_type: nil,
            filter_options: []
          }
        ]
      }

      # Test each relationship field gets the correct filter type inferred
      expected_filter_types = %{
        # enum -> select
        "user.role" => :select,
        # datetime -> date_range
        "user.created_at" => :date_range,
        # boolean -> boolean
        "user.active" => :boolean,
        # decimal -> number_range
        "user.salary" => :number_range,
        # string -> text
        "user.company.name" => :text,
        # enum -> select
        "user.company.company_type" => :select,
        # date -> date_range
        "user.company.founded_date" => :date_range,
        # integer -> number_range
        "user.company.employee_count" => :number_range
      }

      # Test filter type inference for each column
      for column <- assigns.columns do
        slot = %{
          filterable: column.filterable,
          filter_type: column.filter_type,
          filter_options: column.filter_options
        }

        config = FilterManager.infer_filter_config(column.field, assigns.resource, slot)
        expected_type = expected_filter_types[column.field]

        assert config.filter_type == expected_type,
               "Expected #{expected_type} for field #{column.field}, got #{inspect(config.filter_type)}"
      end
    end

    test "filter controls render with correct filter types for relationship fields" do
      theme = Cinder.Theme.default()

      # Test that relationship fields get their proper filter types
      test_cases = [
        {"user.role", :select, "test-table-filter-user_role", "filters[user.role]"},
        {"user.created_at", :date_range, "type=\"date\"", "filters[user.created_at_from]"},
        {"user.active", :boolean, "type=\"radio\"", "filters[user.active]"},
        {"user.salary", :number_range, "type=\"number\"", "filters[user.salary_min]"}
      ]

      for {field, filter_type, expected_html_marker, expected_field_name} <- test_cases do
        column = %{
          field: field,
          label: String.replace(field, ".", " "),
          filter_type: filter_type,
          filter_options: []
        }

        assigns = %{
          column: column,
          current_value: nil,
          theme: theme,
          target: nil,
          filter_values: %{},
          table_id: "test-table"
        }

        html = render_component(&FilterManager.filter_input/1, assigns)

        assert html =~ expected_html_marker,
               "Expected #{field} with #{filter_type} to render #{expected_html_marker}"

        # Check for appropriate field naming
        assert html =~ expected_field_name,
               "Expected #{field} to have field name #{expected_field_name}"
      end
    end

    test "filter processing works for relationship fields with correct types" do
      # Test enum field processing - most important is that it's using select type
      enum_column = %{
        field: "user.role",
        filter_type: :select,
        filter_options: []
      }

      result = FilterManager.process_filter_value("admin", enum_column)

      assert result.type == :select
      assert result.value == "admin"
      assert result.operator == :equals

      # Test boolean field processing - verify boolean type is used
      boolean_column = %{
        field: "user.active",
        filter_type: :boolean,
        filter_options: []
      }

      result = FilterManager.process_filter_value("true", boolean_column)

      assert result.type == :boolean
      assert result.value == true
      assert result.operator == :equals

      # Test text field processing for comparison
      text_column = %{
        field: "user.email",
        filter_type: :text,
        filter_options: []
      }

      result = FilterManager.process_filter_value("test@example.com", text_column)

      assert result.type == :text
      assert result.value == "test@example.com"
      assert result.operator == :contains
    end

    test "explicit filter type overrides work for relationship fields" do
      slot = %{
        filterable: true,
        # Force text filter for an enum field
        filter_type: :text,
        filter_options: []
      }

      # Even though user.role is an enum, explicit override should be respected
      config = FilterManager.infer_filter_config("user.role", ProjectAssignment, slot)

      assert config.filter_type == :text,
             "Explicit filter type override should be respected for relationship fields"
    end

    test "fallback behavior for invalid relationship fields" do
      slot = %{
        filterable: true,
        filter_options: []
      }

      # Non-existent relationship should fall back to text
      config = FilterManager.infer_filter_config("invalid_rel.field", ProjectAssignment, slot)

      assert config.filter_type == :text,
             "Should fall back to text filter for invalid relationships"

      # Non-existent field on valid relationship should fall back to text
      config = FilterManager.infer_filter_config("user.invalid_field", ProjectAssignment, slot)

      assert config.filter_type == :text,
             "Should fall back to text filter for invalid fields on valid relationships"
    end
  end
end
