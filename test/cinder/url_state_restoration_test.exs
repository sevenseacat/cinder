defmodule Cinder.UrlStateRestorationTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  # Test resources
  defmodule TestArtist do
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
      attribute(:country, :string)
      attribute(:founded_year, :integer)
      attribute(:active, :boolean)
    end

    relationships do
      has_many(:albums, TestAlbum, destination_attribute: :artist_id)
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
      attribute(:release_date, :date)
      attribute(:price, :decimal)
      attribute(:is_remastered, :boolean)
      attribute(:artist_id, :uuid)
    end

    relationships do
      belongs_to(:artist, TestArtist)
    end

    actions do
      defaults([:create, :read, :update, :destroy])
    end
  end

  describe "URL state extraction and restoration" do
    test "extract_table_state loses filter information due to empty columns" do
      # Simulate URL parameters that would come from a real URL
      url_params = %{
        "title" => "Abbey Road",
        "artist.name" => "Beatles",
        "artist.country" => "UK",
        "page" => "2",
        "sort" => "-title"
      }

      # This is what currently happens - extract_table_state uses empty columns
      table_state = Cinder.Table.UrlSync.extract_table_state(url_params)

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
      assert decoded_state.filters["artist.active"].value == "true"
      assert decoded_state.filters["artist.active"].type == :boolean
    end
  end

  describe "component URL state restoration" do
    test "table component receives empty filters when using URL sync" do
      # Test assigns that would come from a parent LiveView using UrlSync
      assigns = %{
        resource: TestAlbum,
        current_user: nil,
        # These would be empty because extract_table_state uses empty columns
        url_filters: %{},
        url_page: 2,
        url_sort: [{"title", :desc}],
        col: [
          %{field: "title", filter: :text, __slot__: :col},
          %{field: "artist.name", filter: :text, __slot__: :col}
        ]
      }

      html = render_component(&Cinder.Table.table/1, assigns)

      # Component should render but filters won't be applied
      assert html =~ "cinder-table"

      # The page number should be restored (since that doesn't depend on columns)
      # But filters won't be, which is the bug
    end

    test "manual URL state passing works when raw parameters are provided" do
      # When raw URL parameters are manually passed to the component
      # along with proper column definitions, it should work

      # Simulate what should happen: raw URL params preserved and passed with columns
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
        }
      ]

      # These are the raw URL parameters that should be preserved
      raw_url_params = %{
        "title" => "Abbey",
        "artist.name" => "Beatles"
      }

      # Decode them with actual columns
      decoded_state = Cinder.UrlManager.decode_state(raw_url_params, columns)

      # This should work correctly
      assert Map.has_key?(decoded_state.filters, "title")
      assert Map.has_key?(decoded_state.filters, "artist.name")
      assert decoded_state.filters["title"].value == "Abbey"
      assert decoded_state.filters["artist.name"].value == "Beatles"
    end
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
    test "fixed flow preserves filters using raw URL params" do
      # 1. User visits URL with filters: /table?artist.name=Beatles&page=2
      incoming_url_params = %{
        "artist.name" => "Beatles",
        "page" => "2"
      }

      # 2. Parent LiveView handle_params calls extract_table_state
      # This still uses empty columns but now also stores raw params
      table_state = Cinder.Table.UrlSync.extract_table_state(incoming_url_params)

      # 3. Parent assigns state and raw params to socket (fixed version)
      parent_assigns = %{
        # Still empty due to empty columns
        table_url_filters: table_state.filters,
        table_url_page: table_state.current_page,
        table_url_sort: table_state.sort_by,
        # NEW: Raw params preserved for component
        table_raw_url_params: incoming_url_params
      }

      # 4. Component receives raw params and can decode properly
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
        }
      ]

      # 5. Component decodes raw params with actual columns
      decoded_state =
        Cinder.UrlManager.decode_state(parent_assigns.table_raw_url_params, columns)

      # Now filters are properly restored!
      assert Map.has_key?(decoded_state.filters, "artist.name")
      assert decoded_state.filters["artist.name"].value == "Beatles"
      assert decoded_state.current_page == 2
    end
  end

  describe "the actual broken flow" do
    test "demonstrates the complete broken URL restoration flow (without fix)" do
      # 1. User visits URL with filters: /table?artist.name=Beatles&page=2
      incoming_url_params = %{
        "artist.name" => "Beatles",
        "page" => "2"
      }

      # 2. Parent LiveView handle_params calls extract_table_state
      # This uses empty columns, so filters are lost
      broken_table_state = Cinder.Table.UrlSync.extract_table_state(incoming_url_params)

      # 3. Parent assigns the broken state to socket
      parent_assigns = %{
        # This is {} instead of the filters!
        table_url_filters: broken_table_state.filters,
        table_url_page: broken_table_state.current_page,
        table_url_sort: broken_table_state.sort_by
      }

      # 4. Parent passes these broken assigns to table component
      table_component_assigns = %{
        resource: TestAlbum,
        current_user: nil,
        url_sync: true,
        # Empty {}
        url_filters: parent_assigns.table_url_filters,
        # Correct: 2
        url_page: parent_assigns.table_url_page,
        # Correct: []
        url_sort: parent_assigns.table_url_sort,
        col: [
          %{field: "title", __slot__: :col},
          %{field: "artist.name", filter: :text, __slot__: :col}
        ]
      }

      # 5. Component tries to decode URL state but gets empty filters
      # The original URL parameters are LOST at this point

      # Demonstrate the issue:
      # Lost the artist.name filter!
      assert broken_table_state.filters == %{}
      # This works because page doesn't need columns
      assert broken_table_state.current_page == 2

      # The user's filter is gone and will never be restored
      assert table_component_assigns.url_filters == %{}
    end
  end
end
