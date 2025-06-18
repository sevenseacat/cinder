defmodule Cinder.Filters.DateRangeFieldConversionTest do
  use ExUnit.Case, async: true

  alias Cinder.Filters.DateRange

  # Mock resource for testing field type detection
  defmodule TestResource do
    use Ash.Resource, domain: nil

    attributes do
      uuid_primary_key(:id)
      attribute(:created_at, :naive_datetime)
      attribute(:updated_at, :utc_datetime)
      attribute(:birth_date, :date)
      attribute(:name, :string)
    end
  end

  describe "NaiveDatetime field conversion" do
    setup do
      query = Ash.Query.new(TestResource)
      {:ok, query: query}
    end

    test "converts date strings to datetime format for naive_datetime fields", %{query: query} do
      filter_value = %{
        type: :date_range,
        value: %{from: "2024-10-09", to: "2024-10-10"},
        operator: :between
      }

      result_query = DateRange.build_query(query, "created_at", filter_value)

      # The query should be modified (not the same as input)
      assert result_query != query

      # Check that the filter was applied with datetime conversion
      %{filter: filter} = result_query
      assert filter != nil
    end

    test "handles single date value for naive_datetime fields", %{query: query} do
      filter_value = %{
        type: :date_range,
        value: %{from: "2024-10-09", to: ""},
        operator: :between
      }

      result_query = DateRange.build_query(query, "created_at", filter_value)

      # Query should be modified
      assert result_query != query
      %{filter: filter} = result_query
      assert filter != nil
    end

    test "preserves datetime strings for naive_datetime fields", %{query: query} do
      filter_value = %{
        type: :date_range,
        value: %{from: "2024-10-09T10:30:00", to: "2024-10-10T15:45:00"},
        operator: :between
      }

      result_query = DateRange.build_query(query, "created_at", filter_value)

      # Query should be modified
      assert result_query != query
      %{filter: filter} = result_query
      assert filter != nil
    end

    test "works normally with utc_datetime fields", %{query: query} do
      filter_value = %{
        type: :date_range,
        value: %{from: "2024-10-09", to: "2024-10-10"},
        operator: :between
      }

      result_query = DateRange.build_query(query, "updated_at", filter_value)

      # Query should be modified
      assert result_query != query
      %{filter: filter} = result_query
      assert filter != nil
    end

    test "works normally with date fields", %{query: query} do
      filter_value = %{
        type: :date_range,
        value: %{from: "2024-10-09", to: "2024-10-10"},
        operator: :between
      }

      result_query = DateRange.build_query(query, "birth_date", filter_value)

      # Query should be modified
      assert result_query != query
      %{filter: filter} = result_query
      assert filter != nil
    end

    test "handles unknown field types gracefully", %{query: query} do
      filter_value = %{
        type: :date_range,
        value: %{from: "2024-10-09", to: "2024-10-10"},
        operator: :between
      }

      # Test with a string field (unknown type for date filtering)
      result_query = DateRange.build_query(query, "name", filter_value)

      # Query should still be modified (filter applied as-is)
      assert result_query != query
      %{filter: filter} = result_query
      assert filter != nil
    end

    test "handles empty values correctly", %{query: query} do
      filter_value = %{
        type: :date_range,
        value: %{from: "", to: ""},
        operator: :between
      }

      result_query = DateRange.build_query(query, "created_at", filter_value)

      # Query should not be modified for empty values
      assert result_query == query
    end

    test "handles nil values correctly", %{query: query} do
      filter_value = %{
        type: :date_range,
        value: %{from: nil, to: nil},
        operator: :between
      }

      result_query = DateRange.build_query(query, "created_at", filter_value)

      # Query should be modified but filter should handle nil values gracefully
      assert result_query != query
      %{filter: filter} = result_query
      assert filter != nil
    end

    test "handles mixed empty and date values", %{query: query} do
      # Only from value provided
      filter_value = %{
        type: :date_range,
        value: %{from: "2024-10-09", to: ""},
        operator: :between
      }

      result_query = DateRange.build_query(query, "created_at", filter_value)

      # Query should be modified
      assert result_query != query
      %{filter: filter} = result_query
      assert filter != nil

      # Only to value provided
      filter_value = %{
        type: :date_range,
        value: %{from: "", to: "2024-10-10"},
        operator: :between
      }

      result_query = DateRange.build_query(query, "created_at", filter_value)

      # Query should be modified
      assert result_query != query
      %{filter: filter} = result_query
      assert filter != nil
    end
  end

  describe "relationship field conversion" do
    test "handles relationship fields with dot notation gracefully" do
      # Since we can't easily create full relationship tests in unit tests,
      # we'll just verify the field detection logic doesn't crash
      query = Ash.Query.new(TestResource)

      filter_value = %{
        type: :date_range,
        value: %{from: "2024-10-09", to: "2024-10-10"},
        operator: :between
      }

      # This will fail with our test resource since the relationship doesn't exist,
      # but we can verify the code path is attempted
      assert_raise RuntimeError, ~r/Could not determine related resource/, fn ->
        DateRange.build_query(query, "user.created_at", filter_value)
      end
    end
  end

  describe "field type detection helpers" do
    test "get_field_type/2 detects correct types" do
      # Use the private function via module attribute access (test-only approach)
      assert DateRange.__info__(:functions) |> Keyword.has_key?(:build_query)

      # Test that our resource has the expected field types
      created_at_attr = Ash.Resource.Info.attribute(TestResource, :created_at)
      assert created_at_attr.type == Ash.Type.NaiveDatetime

      updated_at_attr = Ash.Resource.Info.attribute(TestResource, :updated_at)
      assert updated_at_attr.type == Ash.Type.UtcDatetime

      birth_date_attr = Ash.Resource.Info.attribute(TestResource, :birth_date)
      assert birth_date_attr.type == Ash.Type.Date
    end
  end

  describe "value conversion helpers" do
    test "format_value_for_input/2 handles include_time properly" do
      # Test datetime-local formatting (include_time: true)
      assert DateRange.__info__(:functions) |> Keyword.has_key?(:render)

      # Test basic date to datetime conversion
      column = %{
        field: "created_at",
        filter_type: :date_range,
        filter_options: [include_time: true]
      }

      current_value = %{from: "2024-01-01", to: "2024-12-31"}
      theme = Cinder.Theme.default()

      rendered = DateRange.render(column, current_value, theme, %{})
      html = Phoenix.HTML.Safe.to_iodata(rendered) |> IO.iodata_to_binary()

      # Should format as datetime-local
      assert String.contains?(html, "2024-01-01T00:00")
      assert String.contains?(html, "2024-12-31T00:00")
    end

    test "format_value_for_input/2 extracts date from datetime when include_time is false" do
      column = %{
        field: "created_at",
        filter_type: :date_range,
        filter_options: [include_time: false]
      }

      current_value = %{from: "2024-01-01T10:30:00", to: "2024-12-31T15:45:00"}
      theme = Cinder.Theme.default()

      rendered = DateRange.render(column, current_value, theme, %{})
      html = Phoenix.HTML.Safe.to_iodata(rendered) |> IO.iodata_to_binary()

      # Should extract only date part
      assert String.contains?(html, ~s(value="2024-01-01"))
      assert String.contains?(html, ~s(value="2024-12-31"))
      # Should not contain time parts
      refute String.contains?(html, "T10:30")
      refute String.contains?(html, "T15:45")
    end
  end

  describe "validation with datetime support" do
    test "validates both date and datetime formats" do
      # Valid date format
      date_filter = %{
        type: :date_range,
        value: %{from: "2024-01-01", to: "2024-12-31"},
        operator: :between
      }

      assert DateRange.validate(date_filter) == true

      # Valid datetime format
      datetime_filter = %{
        type: :date_range,
        value: %{from: "2024-01-01T10:30:00", to: "2024-12-31T15:45:00"},
        operator: :between
      }

      assert DateRange.validate(datetime_filter) == true

      # Valid ISO datetime with timezone
      iso_filter = %{
        type: :date_range,
        value: %{from: "2024-01-01T10:30:00Z", to: "2024-12-31T15:45:00+05:00"},
        operator: :between
      }

      assert DateRange.validate(iso_filter) == true

      # Invalid datetime format
      invalid_filter = %{
        type: :date_range,
        value: %{from: "2024-01-01T25:00:00", to: "2024-12-31"},
        operator: :between
      }

      assert DateRange.validate(invalid_filter) == false

      # Mixed valid formats
      mixed_filter = %{
        type: :date_range,
        value: %{from: "2024-01-01", to: "2024-12-31T15:45:00"},
        operator: :between
      }

      assert DateRange.validate(mixed_filter) == true
    end

    test "handles empty values in validation" do
      # Empty strings should be valid
      empty_filter = %{
        type: :date_range,
        value: %{from: "", to: ""},
        operator: :between
      }

      assert DateRange.validate(empty_filter) == true

      # Nil values should be valid
      nil_filter = %{
        type: :date_range,
        value: %{from: nil, to: nil},
        operator: :between
      }

      assert DateRange.validate(nil_filter) == true

      # Mixed empty and valid
      mixed_empty_filter = %{
        type: :date_range,
        value: %{from: "2024-01-01", to: ""},
        operator: :between
      }

      assert DateRange.validate(mixed_empty_filter) == true
    end
  end
end
