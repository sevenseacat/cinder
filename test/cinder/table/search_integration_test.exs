defmodule Cinder.Table.SearchIntegrationTest do
  use ExUnit.Case, async: true

  alias Cinder.Support.SearchTestResource

  describe "complete search attribute integration" do
    test "keeps supplied and toggleable filters once across search branches" do
      require Ash.Query

      [title_match, description_match, archived_match | _] =
        for {title, description, category, status} <- [
              {"Widget", "Title match", "allowed", "active"},
              {"Other", "Widget", "allowed", "active"},
              {"Widget", "Archived match", "allowed", "archived"},
              {"Widget", "Wrong category", "other", "active"},
              {"Other", "No match", "allowed", "active"},
              {"Other", nil, "allowed", "active"}
            ] do
          Ash.create!(SearchTestResource, %{
            title: title,
            description: description,
            category: category,
            status: status
          })
        end

      base_query =
        SearchTestResource
        |> Ash.Query.for_read(:read)
        |> Ash.Query.filter(category == "allowed")
        |> Ash.Query.set_context(%{caller: :search_regression})

      columns = [
        %{field: "title", searchable: true},
        %{field: "description", searchable: true},
        %{field: "status", searchable: false, filter_fn: nil}
      ]

      assert {:ok, filtered_query} =
               Cinder.QueryBuilder.build_query(base_query,
                 columns: columns,
                 search_term: "widget",
                 filters: %{"status" => %{type: :select, value: "active", operator: :equals}}
               )

      assert MapSet.new(Ash.read!(filtered_query), & &1.id) ==
               MapSet.new([title_match.id, description_match.id])

      assert filtered_query.context == base_query.context
      predicates = Ash.Filter.list_predicates(filtered_query.filter)
      assert Enum.count(predicates, &match?(%{right: "allowed"}, &1)) == 1
      assert Enum.count(predicates, &match?(%{right: "active"}, &1)) == 1

      assert {:ok, unfiltered_query} =
               Cinder.QueryBuilder.build_query(base_query,
                 columns: columns,
                 search_term: "widget",
                 filters: %{}
               )

      assert MapSet.new(Ash.read!(unfiltered_query), & &1.id) ==
               MapSet.new([title_match.id, description_match.id, archived_match.id])
    end

    test "a searchable column with an invalid field doesn't disable search on a filtered query" do
      require Ash.Query

      widget = Ash.create!(SearchTestResource, %{title: "Widget", category: "allowed"})
      Ash.create!(SearchTestResource, %{title: "Other", category: "allowed"})

      base_query =
        SearchTestResource
        |> Ash.Query.for_read(:read)
        |> Ash.Query.filter(category == "allowed")

      columns = [
        %{field: "title", searchable: true},
        %{field: "invalid field", searchable: true}
      ]

      assert {:ok, query} =
               Cinder.QueryBuilder.build_query(base_query,
                 columns: columns,
                 search_term: "widget",
                 filters: %{}
               )

      assert Enum.map(Ash.read!(query), & &1.id) == [widget.id]
    end

    test "search works with mixed search and filter attributes" do
      col_slots = [
        %{field: "title", search: true, filter: true, label: "Title"},
        %{field: "description", search: true, filter: false, label: "Description"},
        %{field: "status", search: false, filter: true, label: "Status"},
        %{field: "id", label: "ID"}
      ]

      processed_columns = Cinder.Collection.process_columns(col_slots, SearchTestResource)

      # Find specific columns
      title_col = Enum.find(processed_columns, &(&1.field == "title"))
      desc_col = Enum.find(processed_columns, &(&1.field == "description"))
      status_col = Enum.find(processed_columns, &(&1.field == "status"))
      id_col = Enum.find(processed_columns, &(&1.field == "id"))

      # Verify search and filter combinations work correctly
      assert title_col.searchable == true
      assert title_col.filterable == true

      assert desc_col.searchable == true
      assert desc_col.filterable == false

      assert status_col.searchable == false
      assert status_col.filterable == true

      assert id_col.searchable == false
      assert id_col.filterable == false
    end

    test "no search attribute means no search functionality" do
      # Columns without search attributes
      col_slots = [
        %{field: "title", label: "Title"},
        %{field: "description", filter: true, label: "Description"},
        %{field: "status", sort: true, label: "Status"}
      ]

      processed_columns = Cinder.Collection.process_columns(col_slots, SearchTestResource)

      # No columns should be searchable
      assert Enum.all?(processed_columns, &(&1.searchable == false))

      # Search should not modify query when no searchable columns
      query = Ash.Query.for_read(SearchTestResource, :read)
      search_result = Cinder.QueryBuilder.apply_search(query, "test", processed_columns, nil)
      assert search_result == query
    end

    @tag :capture_log
    test "search attribute on fields the resource doesn't have (embedded notation) is skipped, not an error" do
      # Test search on embedded fields (URL-safe notation)
      col_slots = [
        %{field: "profile__first_name", search: true, label: "First Name"},
        %{field: "profile__last_name", search: true, label: "Last Name"},
        %{field: "settings__theme", search: false, label: "Theme"}
      ]

      processed_columns = Cinder.Collection.process_columns(col_slots, SearchTestResource)

      first_name_col = Enum.find(processed_columns, &(&1.field == "profile__first_name"))
      last_name_col = Enum.find(processed_columns, &(&1.field == "profile__last_name"))
      theme_col = Enum.find(processed_columns, &(&1.field == "settings__theme"))

      assert first_name_col.searchable == true
      assert last_name_col.searchable == true
      assert theme_col.searchable == false

      query = Ash.Query.for_read(SearchTestResource, :read)
      assert Cinder.QueryBuilder.apply_search(query, "test", processed_columns, nil) == query
    end
  end

  describe "build_query_columns capability matrix" do
    # This test suite verifies the column inclusion logic in build_query_columns
    # to prevent regressions like the searchable columns being excluded bug.
    #
    # Matrix:
    # | Capability           | In query_columns? | In display_columns? |
    # |----------------------|-------------------|---------------------|
    # | searchable only      | ✅                | ✅                  |
    # | filterable only      | ✅                | ✅                  |
    # | sortable only        | ❌                | ✅                  |
    # | searchable+filterable| ✅                | ✅                  |
    # | filter-only slot     | ✅                | ❌                  |

    test "searchable-only columns are included in query_columns" do
      col_slots = [
        %{field: "name", search: true, filter: false, sort: false, label: "Name"}
      ]

      processed = Cinder.Collection.process_columns(col_slots, SearchTestResource)
      query_cols = Cinder.Collection.build_query_columns(processed, [])

      assert length(query_cols) == 1
      assert hd(query_cols).field == "name"
      assert hd(query_cols).searchable == true
      assert hd(query_cols).filterable == false
    end

    test "filterable-only columns are included in query_columns" do
      col_slots = [
        %{field: "status", search: false, filter: true, sort: false, label: "Status"}
      ]

      processed = Cinder.Collection.process_columns(col_slots, SearchTestResource)
      query_cols = Cinder.Collection.build_query_columns(processed, [])

      assert length(query_cols) == 1
      assert hd(query_cols).field == "status"
      assert hd(query_cols).filterable == true
      assert hd(query_cols).searchable == false
    end

    test "sortable-only columns are NOT included in query_columns" do
      col_slots = [
        %{field: "status", search: false, filter: false, sort: true, label: "Status"}
      ]

      processed = Cinder.Collection.process_columns(col_slots, SearchTestResource)
      query_cols = Cinder.Collection.build_query_columns(processed, [])

      # Sortable-only should NOT be in query_columns (sorting uses display columns)
      assert Enum.empty?(query_cols)

      # But it should still be in processed columns (display columns)
      assert length(processed) == 1
      assert hd(processed).field == "status"
    end

    test "columns with multiple capabilities are included once" do
      col_slots = [
        %{field: "title", search: true, filter: true, sort: true, label: "Title"}
      ]

      processed = Cinder.Collection.process_columns(col_slots, SearchTestResource)
      query_cols = Cinder.Collection.build_query_columns(processed, [])

      assert length(query_cols) == 1
      col = hd(query_cols)
      assert col.searchable == true
      assert col.filterable == true
      assert col.sortable == true
    end

    test "filter-only slots are included in query_columns but not display columns" do
      col_slots = [
        %{field: "title", search: true, filter: false, label: "Title"}
      ]

      filter_slots = [
        %{field: "category", type: :select, label: "Category", options: [{"A", "a"}]}
      ]

      processed_cols = Cinder.Collection.process_columns(col_slots, SearchTestResource)

      processed_filters =
        Cinder.Collection.process_filter_slots(filter_slots, SearchTestResource)

      query_cols = Cinder.Collection.build_query_columns(processed_cols, processed_filters)

      # query_columns should have both
      query_fields = Enum.map(query_cols, & &1.field)
      assert "title" in query_fields
      assert "category" in query_fields

      # display columns (processed_cols) should only have title
      display_fields = Enum.map(processed_cols, & &1.field)
      assert "title" in display_fields
      refute "category" in display_fields
    end

    test "mixed capability columns are correctly partitioned" do
      col_slots = [
        %{field: "title", search: true, filter: false, label: "Title"},
        %{field: "status", search: false, filter: true, label: "Status"},
        %{
          field: "category",
          search: false,
          filter: false,
          sort: true,
          label: "Category Sort Only"
        },
        %{field: "description", search: false, filter: false, sort: false, label: "Display Only"}
      ]

      filter_slots = [
        %{field: "notes", type: :text, label: "Filter Only"}
      ]

      processed_cols = Cinder.Collection.process_columns(col_slots, SearchTestResource)

      processed_filters =
        Cinder.Collection.process_filter_slots(filter_slots, SearchTestResource)

      query_cols = Cinder.Collection.build_query_columns(processed_cols, processed_filters)

      query_fields = Enum.map(query_cols, & &1.field)

      # Searchable and filterable columns should be in query_columns
      assert "title" in query_fields
      assert "status" in query_fields
      assert "notes" in query_fields

      # Sortable-only and display-only should NOT be in query_columns
      refute "category" in query_fields
      refute "description" in query_fields

      # All columns should be in display columns
      display_fields = Enum.map(processed_cols, & &1.field)
      assert length(display_fields) == 4
    end
  end
end
