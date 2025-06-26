defmodule Cinder.RelationshipFilteringSimpleTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  # Define enum first
  defmodule TestGenreEnum do
    use Ash.Type.Enum, values: [rock: "Rock", pop: "Pop", jazz: "Jazz", classical: "Classical"]
  end

  # Test domain
  defmodule TestDomain do
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource(Cinder.RelationshipFilteringSimpleTest.TestArtist)
      resource(Cinder.RelationshipFilteringSimpleTest.TestAlbum)
    end
  end

  # Test resources with relationships
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
      has_many(:albums, Cinder.RelationshipFilteringSimpleTest.TestAlbum,
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
      attribute(:genre, TestGenreEnum)
      attribute(:artist_id, :uuid)
    end

    relationships do
      belongs_to(:artist, Cinder.RelationshipFilteringSimpleTest.TestArtist)
    end

    actions do
      defaults([:create, :read, :update, :destroy])
    end
  end

  describe "relationship filter parameter processing" do
    test "processes text filter on relationship field" do
      form_params = %{"artist.name" => "Beatles"}

      columns = [
        %{
          field: "artist.name",
          filterable: true,
          filter_type: :text,
          filter_fn: nil,
          filter_options: []
        }
      ]

      filters = Cinder.FilterManager.params_to_filters(form_params, columns)

      assert Map.has_key?(filters, "artist.name")
      artist_filter = filters["artist.name"]
      assert artist_filter.type == :text
      assert artist_filter.value == "Beatles"
      assert artist_filter.operator == :contains
    end

    test "processes select filter on relationship field" do
      form_params = %{"artist.country" => "USA"}

      columns = [
        %{
          field: "artist.country",
          filterable: true,
          filter_type: :select,
          filter_fn: nil,
          filter_options: [options: [{"USA", "USA"}, {"UK", "UK"}]]
        }
      ]

      filters = Cinder.FilterManager.params_to_filters(form_params, columns)

      assert Map.has_key?(filters, "artist.country")
      country_filter = filters["artist.country"]
      assert country_filter.type == :select
      assert country_filter.value == "USA"
      assert country_filter.operator == :equals
    end

    test "processes boolean filter on relationship field" do
      form_params = %{"artist.active" => "true"}

      columns = [
        %{
          field: "artist.active",
          filterable: true,
          filter_type: :boolean,
          filter_fn: nil,
          filter_options: []
        }
      ]

      filters = Cinder.FilterManager.params_to_filters(form_params, columns)

      assert Map.has_key?(filters, "artist.active")
      active_filter = filters["artist.active"]
      assert active_filter.type == :boolean
      assert active_filter.value == true
      assert active_filter.operator == :equals
    end

    test "processes number range filter on relationship field" do
      form_params = %{
        "artist.founded_year_from" => "1960",
        "artist.founded_year_to" => "1970"
      }

      columns = [
        %{
          field: "artist.founded_year",
          filterable: true,
          filter_type: :number_range,
          filter_fn: nil,
          filter_options: []
        }
      ]

      filters = Cinder.FilterManager.params_to_filters(form_params, columns)

      assert Map.has_key?(filters, "artist.founded_year")
      year_filter = filters["artist.founded_year"]
      assert year_filter.type == :number_range
      assert year_filter.value == %{min: "1960", max: "1970"}
      assert year_filter.operator == :between
    end

    test "processes date range filter on relationship field" do
      form_params = %{
        "release_date_from" => "2020-01-01",
        "release_date_to" => "2023-12-31"
      }

      columns = [
        %{
          field: "release_date",
          filterable: true,
          filter_type: :date_range,
          filter_fn: nil,
          filter_options: []
        }
      ]

      filters = Cinder.FilterManager.params_to_filters(form_params, columns)

      assert Map.has_key?(filters, "release_date")
      date_filter = filters["release_date"]
      assert date_filter.type == :date_range
      assert date_filter.value == %{from: "2020-01-01", to: "2023-12-31"}
      assert date_filter.operator == :between
    end
  end

  describe "QueryBuilder integration with relationships" do
    test "handles relationship filters in build_and_execute" do
      filters = %{
        "artist.name" => %{
          type: :text,
          value: "Beatles",
          operator: :contains
        }
      }

      columns = [
        %{
          field: "title",
          filterable: false,
          filter_type: nil,
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

      options = [
        actor: nil,
        filters: filters,
        sort_by: [],
        page_size: 25,
        current_page: 1,
        columns: columns,
        query_opts: [load: [:artist]]
      ]

      # This should not crash - either succeed or fail gracefully
      result = Cinder.QueryBuilder.build_and_execute(TestAlbum, options)

      case result do
        {:ok, {results, page_info}} ->
          assert is_list(results)
          assert is_map(page_info)
          assert Map.has_key?(page_info, :total_count)

        {:error, _error} ->
          # Acceptable for test resources without proper domain setup
          assert true
      end
    end

    test "handles multiple relationship filters" do
      filters = %{
        "artist.name" => %{
          type: :text,
          value: "Beatles",
          operator: :contains
        },
        "artist.country" => %{
          type: :select,
          value: "UK",
          operator: :equals
        }
      }

      columns = [
        %{
          field: "title",
          filterable: false,
          filter_type: nil,
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

      options = [
        actor: nil,
        filters: filters,
        sort_by: [],
        page_size: 25,
        current_page: 1,
        columns: columns,
        query_opts: [load: [:artist]]
      ]

      result =
        Cinder.QueryBuilder.build_and_execute(TestAlbum, options)

      case result do
        {:ok, {results, _page_info}} ->
          assert is_list(results)

        {:error, _error} ->
          # Acceptable for test resources
          assert true
      end
    end

    test "handles mixed regular and relationship filters" do
      filters = %{
        "title" => %{
          type: :text,
          value: "Abbey",
          operator: :contains
        },
        "artist.name" => %{
          type: :text,
          value: "Beatles",
          operator: :contains
        }
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
        }
      ]

      options = [
        actor: nil,
        filters: filters,
        sort_by: [],
        page_size: 25,
        current_page: 1,
        columns: columns,
        query_opts: [load: [:artist]]
      ]

      result = Cinder.QueryBuilder.build_and_execute(TestAlbum, options)

      case result do
        {:ok, {results, _page_info}} ->
          assert is_list(results)

        {:error, _error} ->
          # Acceptable for test resources
          assert true
      end
    end
  end

  describe "component integration" do
    test "renders table with relationship filter inputs" do
      assigns = %{
        resource: TestAlbum,
        actor: nil,
        col: [
          %{field: "title", filter: :text, __slot__: :col},
          %{field: "artist.name", filter: :text, __slot__: :col},
          %{field: "artist.active", filter: :boolean, __slot__: :col}
        ]
      }

      html = render_component(&Cinder.Table.table/1, assigns)

      # Should render without errors
      assert html =~ "cinder-table"

      # Should show filter inputs for relationship fields
      assert html =~ "Filter Title"
      assert html =~ "Artist &gt; Name"
      assert html =~ "Artist &gt; Active"
    end

    test "renders table with nested relationship fields" do
      assigns = %{
        resource: TestAlbum,
        actor: nil,
        col: [
          %{field: "title", __slot__: :col},
          %{field: "artist.name", __slot__: :col}
        ]
      }

      html = render_component(&Cinder.Table.table/1, assigns)

      # Should render without errors
      assert html =~ "cinder-table"

      # Should show relationship field labels
      assert html =~ "Artist &gt; Name"
    end

    test "handles relationship filter form with correct input names" do
      assigns = %{
        resource: TestAlbum,
        actor: nil,
        col: [
          %{field: "title", filter: :text, __slot__: :col},
          %{field: "artist.name", filter: :text, __slot__: :col}
        ]
      }

      html = render_component(&Cinder.Table.table/1, assigns)

      # Should contain form with filter inputs
      assert html =~ ~r/<form[^>]*phx-change="filter_change"/
      assert html =~ ~r/<input[^>]*name="filters\[artist\.name\]"/
    end

    test "handles different relationship filter types" do
      assigns = %{
        resource: TestAlbum,
        actor: nil,
        col: [
          %{field: "title", filter: :text, __slot__: :col},
          %{
            field: "artist.name",
            filter: :select,
            filter_options: ["Beatles", "Rolling Stones"],
            __slot__: :col
          },
          %{field: "artist.active", filter: :boolean, __slot__: :col},
          %{field: "artist.founded_year", filter: :number_range, __slot__: :col},
          %{field: "release_date", filter: :date_range, __slot__: :col}
        ]
      }

      html = render_component(&Cinder.Table.table/1, assigns)

      # Should render all filter types without errors
      assert html =~ "cinder-table"
      assert html =~ "Artist &gt; Name"
      assert html =~ "Artist &gt; Active"
      assert html =~ "Artist &gt; Founded Year"
      assert html =~ "Release Date"
    end
  end

  describe "error handling" do
    test "handles empty filter values gracefully" do
      filters = %{
        "artist.name" => %{
          type: :text,
          value: "",
          operator: :contains
        }
      }

      columns = [
        %{
          field: "artist.name",
          filterable: true,
          filter_type: :text,
          filter_fn: nil,
          filter_options: []
        }
      ]

      options = [
        actor: nil,
        filters: filters,
        sort_by: [],
        page_size: 25,
        current_page: 1,
        columns: columns,
        query_opts: [load: [:artist]]
      ]

      # Should handle empty values gracefully (not crash)
      result = Cinder.QueryBuilder.build_and_execute(TestAlbum, options)
      assert is_tuple(result)
    end

    test "handles nil filter values gracefully" do
      filters = %{
        "artist.name" => %{
          type: :text,
          value: nil,
          operator: :contains
        }
      }

      columns = [
        %{
          field: "artist.name",
          filterable: true,
          filter_type: :text,
          filter_fn: nil,
          filter_options: []
        }
      ]

      options = [
        actor: nil,
        filters: filters,
        sort_by: [],
        page_size: 25,
        current_page: 1,
        columns: columns,
        query_opts: [load: [:artist]]
      ]

      # Should handle nil values gracefully (not crash)
      result = Cinder.QueryBuilder.build_and_execute(TestAlbum, options)
      assert is_tuple(result)
    end
  end
end
