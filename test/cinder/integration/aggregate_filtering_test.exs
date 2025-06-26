defmodule Cinder.AggregateFilteringTest do
  use ExUnit.Case, async: true

  # Test resource with track_count as an actual aggregate
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
      attribute(:title, :string)
      attribute(:album_id, :uuid)
    end

    relationships do
      belongs_to(:album, TestAlbum, destination_attribute: :id, source_attribute: :album_id)
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
      has_many(:tracks, TestTrack, destination_attribute: :album_id, source_attribute: :id)
    end

    aggregates do
      count(:track_count, :tracks)
    end

    actions do
      defaults([:create, :read, :update, :destroy])
    end
  end

  describe "aggregate column type detection" do
    test "aggregate fields should be detected correctly" do
      # Test that Column module can properly detect aggregate field types
      aggregate_column = %{
        field: "track_count",
        filterable: true
      }

      parsed_column = Cinder.Column.parse_column(aggregate_column, TestAlbum)

      # Aggregate count fields should be detected as numeric, not text
      assert parsed_column.filter_type in [:number_range, :integer],
             "Expected numeric filter type for aggregate count field, got #{parsed_column.filter_type}"
    end

    test "text field detection works correctly" do
      # Verify that text fields are still detected correctly
      text_column = %{
        field: "title",
        filterable: true
      }

      parsed_column = Cinder.Column.parse_column(text_column, TestAlbum)

      assert parsed_column.filter_type == :text,
             "Expected text filter type for string field, got #{parsed_column.filter_type}"
    end
  end

  describe "aggregate field inference" do
    test "aggregate field type detection from Ash resource" do
      # Check if FilterManager can properly infer filter config for aggregates
      filter_config =
        Cinder.FilterManager.infer_filter_config("track_count", TestAlbum, %{filterable: true})

      # Aggregate count fields should be inferred as numeric
      assert filter_config.filter_type in [:number_range, :integer],
             "Expected numeric filter type for aggregate, got #{filter_config.filter_type}"
    end
  end

  describe "manual filter testing" do
    test "demonstrates the issue with manual filter configuration" do
      # This test shows what happens when we manually create filters
      # for an integer field but use text filter type (current bug scenario)

      columns = [
        %{
          field: "track_count",
          filterable: true,
          # This is the bug - should be :number_range
          filter_type: :text,
          sortable: true
        }
      ]

      # Test the filter processing without actual data
      processed_filters = Cinder.FilterManager.params_to_filters(%{"track_count" => "3"}, columns)

      # The issue is likely here - text filters on integer fields don't work properly
      assert is_map(processed_filters), "Should process filters without error"
    end
  end
end
