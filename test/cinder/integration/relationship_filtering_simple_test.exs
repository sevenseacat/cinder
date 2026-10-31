defmodule Cinder.RelationshipFilteringSimpleTest do
  @moduledoc """
  Tests for relationship field filtering.

  Uses TestArtist/TestAlbum from test/support/test_resources.ex.
  """
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

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

      html = render_component(&Cinder.collection/1, assigns)

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

      html = render_component(&Cinder.collection/1, assigns)

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

      html = render_component(&Cinder.collection/1, assigns)

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
            filter: [
              type: :select,
              options: [{"Beatles", "beatles"}, {"Rolling Stones", "stones"}]
            ],
            __slot__: :col
          },
          %{field: "artist.active", filter: :boolean, __slot__: :col},
          %{field: "artist.founded_year", filter: :number_range, __slot__: :col},
          %{field: "release_date", filter: :date_range, __slot__: :col}
        ]
      }

      html = render_component(&Cinder.collection/1, assigns)

      # Should render all filter types without errors
      assert html =~ "cinder-table"
      assert html =~ "Artist &gt; Name"
      assert html =~ "Rolling Stones"
      assert html =~ "Artist &gt; Active"
      assert html =~ "Artist &gt; Founded Year"
      assert html =~ "Release Date"
    end
  end

  describe "QueryBuilder with relationship filters, by the records returned" do
    setup do
      beatles = Ash.Seed.seed!(TestArtist, %{name: "The Beatles", country: "UK"})
      stones = Ash.Seed.seed!(TestArtist, %{name: "The Rolling Stones", country: "UK"})
      abba = Ash.Seed.seed!(TestArtist, %{name: "ABBA", country: "Sweden"})

      for {artist, title} <- [
            {beatles, "Abbey Road"},
            {beatles, "Help!"},
            {stones, "Sticky Fingers"},
            {abba, "Arrival"}
          ] do
        Ash.Seed.seed!(TestAlbum, %{title: title, artist_id: artist.id})
      end

      :ok
    end

    test "a text filter on a related field" do
      filters = %{"artist.name" => text_filter("Beatles")}

      assert album_titles(filters, [column("artist.name", :text)]) == ["Abbey Road", "Help!"]
    end

    test "several filters on related fields all apply" do
      filters = %{
        "artist.name" => text_filter("The"),
        "artist.country" => %{type: :select, value: "UK", operator: :equals}
      }

      columns = [column("artist.name", :text), column("artist.country", :select)]

      assert album_titles(filters, columns) == ["Abbey Road", "Help!", "Sticky Fingers"]
    end

    test "a related field's filter combines with a field's own" do
      filters = %{"title" => text_filter("Abbey"), "artist.name" => text_filter("Beatles")}
      columns = [column("title", :text), column("artist.name", :text)]

      assert album_titles(filters, columns) == ["Abbey Road"]
    end
  end

  defp text_filter(value), do: %{type: :text, value: value, operator: :contains}

  defp column(field, type) do
    %{field: field, filterable: true, filter_type: type, filter_fn: nil, filter_options: []}
  end

  defp album_titles(filters, columns) do
    {:ok, page} =
      Cinder.QueryBuilder.build_and_execute(TestAlbum,
        filters: filters,
        sort_by: [],
        page_size: 25,
        current_page: 1,
        columns: columns,
        query_opts: []
      )

    page.results |> Enum.map(& &1.title) |> Enum.sort()
  end
end
