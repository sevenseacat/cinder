defmodule Cinder.Table.FilterSlotsTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog

  # Test resources for filter-only slots
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
      attribute(:department, :string)
      attribute(:salary, :decimal)
      attribute(:tags, {:array, :string})
    end

    actions do
      defaults([:create, :read, :update, :destroy])
    end
  end

  # Test resource with aggregates for type inference testing
  defmodule TestTrack do
    use Ash.Resource,
      domain: nil,
      data_layer: Ash.DataLayer.Ets,
      validate_domain_inclusion?: false

    ets do
      private?(true)
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:duration_seconds, :integer)
      attribute(:test_album_id, :uuid)
    end

    relationships do
      belongs_to(:album, Cinder.Table.FilterSlotsTest.TestAlbum)
    end

    actions do
      defaults([:create, :read, :update, :destroy])
    end
  end

  defmodule TestAlbum do
    use Ash.Resource,
      domain: nil,
      data_layer: Ash.DataLayer.Ets,
      validate_domain_inclusion?: false

    ets do
      private?(true)
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:title, :string)
    end

    relationships do
      has_many(:tracks, Cinder.Table.FilterSlotsTest.TestTrack)
    end

    aggregates do
      sum(:duration_seconds, :tracks, :duration_seconds)
      count(:track_count, :tracks)
    end

    actions do
      defaults([:create, :read, :update, :destroy])
    end
  end

  defmodule TestDomain do
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource(TestUser)
      resource(TestTrack)
      resource(TestAlbum)
    end
  end

  describe "filter-only slot definition" do
    test "accepts basic filter slot with required attributes" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        col: [%{field: "name", __slot__: :col}],
        filter: [%{field: "created_at", type: :date_range, __slot__: :filter}]
      }

      html = render_component(&Cinder.Table.table/1, assigns)
      assert html =~ "cinder-table"
    end

    test "supports auto-detection when type is not provided" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        col: [%{field: "name", __slot__: :col}],
        filter: [
          # Should auto-detect as number_range
          %{field: "age", __slot__: :filter},
          # Should auto-detect as boolean
          %{field: "active", __slot__: :filter}
        ]
      }

      html = render_component(&Cinder.Table.table/1, assigns)
      assert html =~ "cinder-table"
    end

    test "supports custom labels for filter slots" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        col: [%{field: "name", __slot__: :col}],
        filter: [
          %{field: "created_at", type: :date_range, label: "Creation Date", __slot__: :filter}
        ]
      }

      html = render_component(&Cinder.Table.table/1, assigns)
      assert html =~ "Creation Date"
    end

    test "supports options for select filters" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        col: [%{field: "name", __slot__: :col}],
        filter: [
          %{
            field: "department",
            type: :select,
            options: [{"Sales", "sales"}, {"Marketing", "marketing"}],
            __slot__: :filter
          }
        ]
      }

      html = render_component(&Cinder.Table.table/1, assigns)
      assert html =~ "cinder-table"
    end
  end

  describe "field conflict detection" do
    test "raises error when same field is used in both column filter and filter slot" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        col: [%{field: "name", filter: true, __slot__: :col}],
        filter: [%{field: "name", type: :text, __slot__: :filter}]
      }

      assert_raise ArgumentError, ~r/Field conflict detected.*name/, fn ->
        render_component(&Cinder.Table.table/1, assigns)
      end
    end

    test "raises error with helpful message listing all conflicting fields" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        col: [
          %{field: "name", filter: true, __slot__: :col},
          %{field: "email", filter: true, __slot__: :col}
        ],
        filter: [
          %{field: "name", type: :text, __slot__: :filter},
          %{field: "email", type: :text, __slot__: :filter}
        ]
      }

      assert_raise ArgumentError, ~r/Field conflict detected.*email.*name/, fn ->
        render_component(&Cinder.Table.table/1, assigns)
      end
    end

    test "allows same field in column without filter and filter slot" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        # No filter enabled
        col: [%{field: "name", __slot__: :col}],
        filter: [%{field: "name", type: :text, __slot__: :filter}]
      }

      html = render_component(&Cinder.Table.table/1, assigns)
      assert html =~ "cinder-table"
    end

    test "allows different fields in columns and filter slots" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        col: [%{field: "name", filter: true, __slot__: :col}],
        filter: [%{field: "created_at", type: :date_range, __slot__: :filter}]
      }

      html = render_component(&Cinder.Table.table/1, assigns)
      assert html =~ "cinder-table"
    end
  end

  describe "resource field validation" do
    test "logs warning for invalid field names but continues rendering" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        col: [%{field: "name", __slot__: :col}],
        filter: [%{field: "nonexistent_field", type: :text, __slot__: :filter}]
      }

      logs = capture_log(fn ->
        html = render_component(&Cinder.Table.table/1, assigns)
        assert html =~ "cinder-table"
      end)

      assert logs =~ "Field 'nonexistent_field' does not exist"
    end

    test "logs warning for invalid relationship field paths" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        col: [%{field: "name", __slot__: :col}],
        filter: [%{field: "profile.invalid_field", type: :text, __slot__: :filter}]
      }

      logs = capture_log(fn ->
        html = render_component(&Cinder.Table.table/1, assigns)
        assert html =~ "cinder-table"
      end)

      assert logs =~ "Field 'profile.invalid_field' does not exist"
    end
  end

  describe "filter slot processing" do
    test "processes filter slots into correct internal format" do
      filter_slots = [
        %{field: "created_at", type: :date_range, label: "Creation Date", __slot__: :filter},
        %{field: "age", type: :number_range, __slot__: :filter}
      ]

      processed = Cinder.Table.process_filter_slots(filter_slots, TestUser)

      assert length(processed) == 2

      created_at_filter = Enum.find(processed, &(&1.field == "created_at"))
      assert created_at_filter.label == "Creation Date"
      assert created_at_filter.filterable == true
      assert created_at_filter.sortable == false
      assert created_at_filter.filter_type == :date_range
      assert created_at_filter.__slot__ == :filter

      age_filter = Enum.find(processed, &(&1.field == "age"))
      assert age_filter.filterable == true
      assert age_filter.filter_type == :number_range
    end

    test "auto-detects filter types when not specified" do
      filter_slots = [
        # Should be :number_range
        %{field: "age", __slot__: :filter},
        # Should be :boolean
        %{field: "active", __slot__: :filter},
        # Should be :text
        %{field: "name", __slot__: :filter}
      ]

      processed = Cinder.Table.process_filter_slots(filter_slots, TestUser)

      age_filter = Enum.find(processed, &(&1.field == "age"))
      assert age_filter.filter_type == :number_range

      active_filter = Enum.find(processed, &(&1.field == "active"))
      assert active_filter.filter_type == :boolean

      name_filter = Enum.find(processed, &(&1.field == "name"))
      assert name_filter.filter_type == :text
    end

    test "auto-detects filter types for aggregate fields" do
      filter_slots = [
        # Sum aggregate should be :number_range
        %{field: "duration_seconds", __slot__: :filter},
        # Count aggregate should be :number_range
        %{field: "track_count", __slot__: :filter}
      ]

      processed = Cinder.Table.process_filter_slots(filter_slots, TestAlbum)

      duration_filter = Enum.find(processed, &(&1.field == "duration_seconds"))
      assert duration_filter.filter_type == :number_range

      count_filter = Enum.find(processed, &(&1.field == "track_count"))
      assert count_filter.filter_type == :number_range
    end




    test "auto-generates labels from field names" do
      filter_slots = [
        %{field: "created_at", type: :date_range, __slot__: :filter},
        %{field: "department", type: :select, __slot__: :filter}
      ]

      processed = Cinder.Table.process_filter_slots(filter_slots, TestUser)

      created_at_filter = Enum.find(processed, &(&1.field == "created_at"))
      assert created_at_filter.label == "Created At"

      department_filter = Enum.find(processed, &(&1.field == "department"))
      assert department_filter.label == "Department"
    end

    test "raises error for missing field attribute" do
      filter_slots = [%{type: :text, __slot__: :filter}]

      assert_raise ArgumentError, ~r/Filter slot missing required :field attribute/, fn ->
        Cinder.Table.process_filter_slots(filter_slots, TestUser)
      end
    end
  end

  describe "configuration merging" do
    test "merges column filters and filter slots correctly" do
      processed_columns = [
        %{field: "name", filterable: true, filter_type: :text, __slot__: :col},
        %{field: "email", filterable: false, __slot__: :col}
      ]

      processed_filter_slots = [
        %{field: "created_at", filterable: true, filter_type: :date_range, __slot__: :filter},
        %{field: "department", filterable: true, filter_type: :select, __slot__: :filter}
      ]

      merged = Cinder.Table.merge_filter_configurations(processed_columns, processed_filter_slots)

      # Should include only filterable column + both filter slots
      assert length(merged) == 3

      fields = Enum.map(merged, & &1.field)
      assert "name" in fields
      assert "created_at" in fields
      assert "department" in fields
      # Not filterable
      assert "email" not in fields
    end

    test "detects conflicts between column filters and filter slots" do
      processed_columns = [
        %{field: "name", filterable: true, filter_type: :text, __slot__: :col}
      ]

      processed_filter_slots = [
        %{field: "name", filterable: true, filter_type: :text, __slot__: :filter}
      ]

      assert_raise ArgumentError, ~r/Field conflict detected.*name/, fn ->
        Cinder.Table.merge_filter_configurations(processed_columns, processed_filter_slots)
      end
    end

    test "allows same field in non-filterable column and filter slot" do
      processed_columns = [
        # Not filterable
        %{field: "name", filterable: false, __slot__: :col}
      ]

      processed_filter_slots = [
        %{field: "name", filterable: true, filter_type: :text, __slot__: :filter}
      ]

      merged = Cinder.Table.merge_filter_configurations(processed_columns, processed_filter_slots)
      assert length(merged) == 1
      assert hd(merged).field == "name"
      assert hd(merged).__slot__ == :filter
    end
  end

  describe "filter rendering integration" do
    test "renders filters from both columns and filter slots" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        col: [%{field: "name", filter: true, __slot__: :col}],
        filter: [
          %{field: "created_at", type: :date_range, label: "Creation Date", __slot__: :filter}
        ]
      }

      html = render_component(&Cinder.Table.table/1, assigns)

      # Should contain filter inputs for both name and created_at
      assert html =~ ~r/name.*filters/
      assert html =~ "Creation Date"
    end

    test "shows filters when only filter slots are present" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        # No filter
        col: [%{field: "name", __slot__: :col}],
        filter: [%{field: "created_at", type: :date_range, __slot__: :filter}]
      }

      html = render_component(&Cinder.Table.table/1, assigns)

      # Should show filter controls because filter slot is present
      assert html =~ "🔍 Filters"
    end

    test "handles mixed filter types correctly" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        col: [%{field: "name", filter: true, __slot__: :col}],
        filter: [
          %{field: "age", type: :number_range, __slot__: :filter},
          %{field: "active", type: :boolean, __slot__: :filter},
          %{field: "department", type: :select, options: [{"Sales", "sales"}], __slot__: :filter}
        ]
      }

      html = render_component(&Cinder.Table.table/1, assigns)
      assert html =~ "cinder-table"
      # More specific assertions would require testing the actual filter HTML structure
    end
  end

  describe "backward compatibility" do
    test "works without filter slots (existing behavior)" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        col: [
          %{field: "name", filter: true, __slot__: :col},
          %{field: "email", __slot__: :col}
        ]
      }

      html = render_component(&Cinder.Table.table/1, assigns)
      assert html =~ "cinder-table"
      # Should work exactly as before
    end

    test "handles empty filter slots gracefully" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        col: [%{field: "name", __slot__: :col}],
        filter: []
      }

      html = render_component(&Cinder.Table.table/1, assigns)
      assert html =~ "cinder-table"
    end

    test "works when filter key is missing from assigns" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        col: [%{field: "name", filter: true, __slot__: :col}]
        # No :filter key
      }

      html = render_component(&Cinder.Table.table/1, assigns)
      assert html =~ "cinder-table"
    end
  end

  describe "validation error messages" do
    test "provides helpful error for field conflicts" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        col: [%{field: "name", filter: true, __slot__: :col}],
        filter: [%{field: "name", type: :text, __slot__: :filter}]
      }

      error_message =
        assert_raise(ArgumentError, fn ->
          render_component(&Cinder.Table.table/1, assigns)
        end).message

      assert error_message =~ "Field conflict detected"
      assert error_message =~ "name"
      assert error_message =~ "cannot be defined in both"
      assert error_message =~ ":col"
      assert error_message =~ ":filter"
    end

    test "provides helpful error for missing required field" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        col: [%{field: "name", __slot__: :col}],
        filter: [%{type: :text, __slot__: :filter}]
      }

      error_message =
        assert_raise(ArgumentError, fn ->
          render_component(&Cinder.Table.table/1, assigns)
        end).message

      assert error_message =~ "Filter slot missing required :field attribute"
    end
  end

  describe "complex scenarios" do
    test "handles multiple filter slots with mixed configurations" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        col: [
          %{field: "name", filter: true, __slot__: :col},
          # Display only
          %{field: "email", __slot__: :col}
        ],
        filter: [
          %{field: "created_at", type: :date_range, label: "Created", __slot__: :filter},
          # Auto-detect type
          %{field: "age", __slot__: :filter},
          %{field: "department", type: :select, options: [{"Sales", "sales"}], __slot__: :filter},
          %{field: "active", type: :boolean, label: "Is Active", __slot__: :filter}
        ]
      }

      html = render_component(&Cinder.Table.table/1, assigns)
      assert html =~ "cinder-table"
      assert html =~ "Created"
      assert html =~ "Is Active"
    end

    test "handles relationship fields in filter slots" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        col: [%{field: "name", __slot__: :col}],
        filter: [%{field: "profile.first_name", type: :text, __slot__: :filter}]
      }

      # Should log warning but continue rendering
      logs = capture_log(fn ->
        html = render_component(&Cinder.Table.table/1, assigns)
        assert html =~ "cinder-table"
      end)

      assert logs =~ "Field 'profile.first_name' does not exist"
    end

    test "preserves column display while adding filter-only fields" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        col: [
          %{field: "name", label: "Full Name", __slot__: :col},
          %{field: "email", __slot__: :col}
        ],
        filter: [
          %{field: "created_at", type: :date_range, __slot__: :filter},
          %{field: "department", type: :select, options: [{"Sales", "sales"}], __slot__: :filter}
        ]
      }

      html = render_component(&Cinder.Table.table/1, assigns)

      # Should display table columns
      assert html =~ "Full Name"

      # Should not display filter-only fields as columns
      # Not in table header
      refute html =~ ">Created At<"
      # Not in table header
      refute html =~ ">Department<"

      # But should have filter controls (exact HTML would depend on filter rendering)
      assert html =~ "🔍 Filters"
    end
  end
end
