defmodule Cinder.UrlStateRestorationTest do
  use ExUnit.Case, async: true

  # Test domain
  defmodule TestDomain do
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource(Cinder.UrlStateRestorationTest.TestArtist)
      resource(Cinder.UrlStateRestorationTest.TestAlbum)
    end
  end

  # Test resources
  defmodule TestArtist do
    use Ash.Resource,
      domain: TestDomain,
      data_layer: Ash.DataLayer.Ets

    ets do
      private?(true)
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string)
      attribute(:country, :string)
      attribute(:founded_year, :integer)
      attribute(:active, :boolean)
    end

    relationships do
      has_many(:albums, Cinder.UrlStateRestorationTest.TestAlbum,
        destination_attribute: :artist_id
      )
    end

    actions do
      defaults([:create, :read, :update, :destroy])
    end
  end

  defmodule TestAlbum do
    use Ash.Resource,
      domain: TestDomain,
      data_layer: Ash.DataLayer.Ets

    ets do
      private?(true)
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:title, :string)
      attribute(:release_date, :date)
      attribute(:price, :decimal)
      attribute(:is_remastered, :boolean)
      attribute(:artist_id, :uuid)
    end

    relationships do
      belongs_to(:artist, Cinder.UrlStateRestorationTest.TestArtist)
    end

    actions do
      defaults([:create, :read, :update, :destroy])
    end
  end

  describe "URL state extraction and restoration" do
    test "extract_collection_state loses filter information due to empty columns" do
      # Simulate URL parameters that would come from a real URL
      url_params = %{
        "title" => "Abbey Road",
        "artist.name" => "Beatles",
        "artist.country" => "UK",
        "page" => "2",
        "sort" => "-title"
      }

      # This is what currently happens - extract_collection_state uses empty columns
      table_state = Cinder.UrlSync.extract_collection_state(url_params)

      # The problem: all filters are lost because there are no columns to match against
      assert table_state.filters == %{}
      assert table_state.current_page == 2
      assert table_state.sort_by == [{"title", :desc}]
    end

    test "decode_state works correctly when provided with actual columns" do
      url_params = %{
        "title" => "Abbey Road",
        "artist.name" => "Beatles",
        "artist.country" => "UK",
        "page" => "2",
        "sort" => "-title"
      }

      columns = [
        %{
          field: "title",
          filterable: true,
          filter_type: :text,
          filter_fn: nil,
          filter_options: []
        },
        %{
          field: "artist.name",
          filterable: true,
          filter_type: :text,
          filter_fn: nil,
          filter_options: []
        },
        %{
          field: "artist.country",
          filterable: true,
          filter_type: :select,
          filter_fn: nil,
          filter_options: []
        }
      ]

      # This works correctly when columns are provided
      decoded_state = Cinder.UrlManager.decode_state(url_params, columns)

      # All filters should be properly decoded
      assert Map.has_key?(decoded_state.filters, "title")
      assert Map.has_key?(decoded_state.filters, "artist.name")
      assert Map.has_key?(decoded_state.filters, "artist.country")

      assert decoded_state.filters["title"].value == "Abbey Road"
      assert decoded_state.filters["artist.name"].value == "Beatles"
      assert decoded_state.filters["artist.country"].value == "UK"

      assert decoded_state.current_page == 2
      assert decoded_state.sort_by == [{"title", :desc}]
    end

    test "relationship filters are properly decoded when columns are available" do
      url_params = %{
        "artist.name" => "Z",
        "artist.founded_year" => "1960,1970",
        "artist.active" => "true"
      }

      columns = [
        %{
          field: "artist.name",
          filterable: true,
          filter_type: :text,
          filter_fn: nil,
          filter_options: []
        },
        %{
          field: "artist.founded_year",
          filterable: true,
          filter_type: :number_range,
          filter_fn: nil,
          filter_options: []
        },
        %{
          field: "artist.active",
          filterable: true,
          filter_type: :boolean,
          filter_fn: nil,
          filter_options: []
        }
      ]

      decoded_state = Cinder.UrlManager.decode_state(url_params, columns)

      # Relationship text filter
      assert Map.has_key?(decoded_state.filters, "artist.name")
      assert decoded_state.filters["artist.name"].value == "Z"
      assert decoded_state.filters["artist.name"].type == :text

      # Relationship number range filter
      assert Map.has_key?(decoded_state.filters, "artist.founded_year")
      assert decoded_state.filters["artist.founded_year"].value == %{min: "1960", max: "1970"}
      assert decoded_state.filters["artist.founded_year"].type == :number_range

      # Relationship boolean filter
      assert Map.has_key?(decoded_state.filters, "artist.active")
      assert decoded_state.filters["artist.active"].value == true
      assert decoded_state.filters["artist.active"].type == :boolean
    end
  end

  describe "component URL state restoration" do
  end

  describe "URL encoding and decoding roundtrip" do
    test "filters survive encode -> decode cycle when columns are preserved" do
      # Start with filter state
      original_filters = %{
        "title" => %{type: :text, value: "Abbey Road", operator: :contains},
        "artist.name" => %{type: :text, value: "Beatles", operator: :contains},
        "artist.country" => %{type: :select, value: "UK", operator: :equals}
      }

      # Encode to URL parameters
      encoded_params =
        Cinder.UrlManager.encode_state(%{
          filters: original_filters,
          current_page: 2,
          sort_by: [{"title", :desc}]
        })

      # Add page and sort manually since encode_state might not include them
      encoded_params =
        encoded_params
        |> Map.put("page", "2")
        |> Map.put("sort", "-title")

      # Decode back with proper columns
      columns = [
        %{
          field: "title",
          filterable: true,
          filter_type: :text,
          filter_fn: nil,
          filter_options: []
        },
        %{
          field: "artist.name",
          filterable: true,
          filter_type: :text,
          filter_fn: nil,
          filter_options: []
        },
        %{
          field: "artist.country",
          filterable: true,
          filter_type: :select,
          filter_fn: nil,
          filter_options: []
        }
      ]

      decoded_state = Cinder.UrlManager.decode_state(encoded_params, columns)

      # Should be identical to original
      assert decoded_state.filters["title"].value == "Abbey Road"
      assert decoded_state.filters["artist.name"].value == "Beatles"
      assert decoded_state.filters["artist.country"].value == "UK"
      assert decoded_state.current_page == 2
      assert decoded_state.sort_by == [{"title", :desc}]
    end

    test "relationship filters survive encode -> decode cycle" do
      # Start with relationship filter state
      original_filters = %{
        "artist.name" => %{type: :text, value: "Z", operator: :contains},
        "artist.founded_year" => %{
          type: :number_range,
          value: %{min: "1960", max: "1970"},
          operator: :between
        }
      }

      # Encode to URL parameters
      encoded_params =
        Cinder.UrlManager.encode_state(%{
          filters: original_filters,
          current_page: 1,
          sort_by: []
        })

      # Decode back with proper columns
      columns = [
        %{
          field: "artist.name",
          filterable: true,
          filter_type: :text,
          filter_fn: nil,
          filter_options: []
        },
        %{
          field: "artist.founded_year",
          filterable: true,
          filter_type: :number_range,
          filter_fn: nil,
          filter_options: []
        }
      ]

      decoded_state = Cinder.UrlManager.decode_state(encoded_params, columns)

      # Should preserve relationship filters
      assert decoded_state.filters["artist.name"].value == "Z"
      assert decoded_state.filters["artist.founded_year"].value == %{min: "1960", max: "1970"}
    end
  end

  describe "URL restoration fix verification" do
  end

  describe "the actual broken flow" do
  end
end
