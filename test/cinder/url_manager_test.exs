defmodule Cinder.UrlManagerTest do
  use ExUnit.Case, async: true

  alias Cinder.UrlManager

  describe "encode_state/1" do
    test "encodes complete state with filters, pagination, and sorting" do
      state = %{
        filters: %{
          "title" => %{type: :text, value: "test", operator: :contains},
          "status" => %{type: :select, value: "active", operator: :equals}
        },
        current_page: 2,
        sort_by: [{"title", :desc}, {"created_at", :asc}]
      }

      result = UrlManager.encode_state(state)

      assert result[:title] == "test"
      assert result[:status] == "active"
      assert result[:page] == "2"
      assert result[:sort] == "-title,created_at"
    end

    test "omits page parameter when current_page is 1" do
      state = %{
        filters: %{"title" => %{type: :text, value: "test", operator: :contains}},
        current_page: 1,
        sort_by: []
      }

      result = UrlManager.encode_state(state)

      assert result[:title] == "test"
      refute Map.has_key?(result, :page)
    end

    test "omits sort parameter when sort_by is empty" do
      state = %{
        filters: %{"title" => %{type: :text, value: "test", operator: :contains}},
        current_page: 1,
        sort_by: []
      }

      result = UrlManager.encode_state(state)

      assert result[:title] == "test"
      refute Map.has_key?(result, :sort)
    end

    test "handles empty state" do
      state = %{
        filters: %{},
        current_page: 1,
        sort_by: []
      }

      result = UrlManager.encode_state(state)

      assert result == %{}
    end
  end

  describe "decode_state/2" do
    setup do
      columns = [
        %{field: "title", filterable: true, filter_type: :text},
        %{field: "status", filterable: true, filter_type: :select},
        %{field: "tags", filterable: true, filter_type: :multi_select},
        %{field: "created_at", filterable: true, filter_type: :date_range},
        %{field: "price", filterable: true, filter_type: :number_range},
        %{field: "active", filterable: true, filter_type: :boolean}
      ]

      {:ok, columns: columns}
    end

    test "decodes complete state", %{columns: columns} do
      url_params = %{
        "title" => "test",
        "status" => "active",
        "page" => "3",
        "sort" => "-title,created_at"
      }

      result = UrlManager.decode_state(url_params, columns)

      assert result.filters["title"] == %{
               type: :text,
               value: "test",
               operator: :contains,
               case_sensitive: false
             }

      assert result.filters["status"] == %{type: :select, value: "active", operator: :equals}
      assert result.current_page == 3
      assert result.sort_by == [{"title", :desc}, {"created_at", :asc}]
    end

    test "handles missing parameters", %{columns: columns} do
      url_params = %{"title" => "test"}

      result = UrlManager.decode_state(url_params, columns)

      assert result.filters["title"] == %{
               type: :text,
               value: "test",
               operator: :contains,
               case_sensitive: false
             }

      assert result.current_page == 1
      assert result.sort_by == []
    end

    test "ignores non-filterable columns", %{columns: columns} do
      url_params = %{"unknown_field" => "value"}

      result = UrlManager.decode_state(url_params, columns)

      assert result.filters == %{}
    end
  end

  describe "encode_filters/1" do
    test "encodes text filters" do
      filters = %{
        "title" => %{type: :text, value: "hello world", operator: :contains}
      }

      result = UrlManager.encode_filters(filters)

      assert result == %{title: "hello world"}
    end

    test "encodes multi-select filters" do
      filters = %{
        "tags" => %{type: :multi_select, value: ["tag1", "tag2", "tag3"], operator: :in}
      }

      result = UrlManager.encode_filters(filters)

      assert result == %{tags: "tag1,tag2,tag3"}
    end

    test "encodes date range filters" do
      filters = %{
        "created_at" => %{
          type: :date_range,
          value: %{from: "2023-01-01", to: "2023-12-31"},
          operator: :between
        }
      }

      result = UrlManager.encode_filters(filters)

      assert result == %{created_at: "2023-01-01,2023-12-31"}
    end

    test "encodes number range filters" do
      filters = %{
        "price" => %{
          type: :number_range,
          value: %{min: "10", max: "100"},
          operator: :between
        }
      }

      result = UrlManager.encode_filters(filters)

      assert result == %{price: "10,100"}
    end

    test "encodes boolean filters" do
      filters = %{
        "active" => %{type: :boolean, value: "true", operator: :equals}
      }

      result = UrlManager.encode_filters(filters)

      assert result == %{active: "true"}
    end

    test "handles empty filters" do
      result = UrlManager.encode_filters(%{})

      assert result == %{}
    end
  end

  describe "decode_filters/2" do
    setup do
      columns = [
        %{field: "title", filterable: true, filter_type: :text},
        %{field: "status", filterable: true, filter_type: :select},
        %{field: "tags", filterable: true, filter_type: :multi_select},
        %{field: "created_at", filterable: true, filter_type: :date_range},
        %{field: "price", filterable: true, filter_type: :number_range},
        %{field: "active", filterable: true, filter_type: :boolean}
      ]

      {:ok, columns: columns}
    end

    test "decodes text filters", %{columns: columns} do
      url_params = %{"title" => "hello world"}

      result = UrlManager.decode_filters(url_params, columns)

      assert result["title"] == %{
               type: :text,
               value: "hello world",
               operator: :contains,
               case_sensitive: false
             }
    end

    test "decodes select filters", %{columns: columns} do
      url_params = %{"status" => "active"}

      result = UrlManager.decode_filters(url_params, columns)

      assert result["status"] == %{type: :select, value: "active", operator: :equals}
    end

    test "decodes multi-select filters", %{columns: columns} do
      url_params = %{"tags" => "tag1,tag2,tag3"}

      result = UrlManager.decode_filters(url_params, columns)

      assert result["tags"] == %{
               type: :multi_select,
               value: ["tag1", "tag2", "tag3"],
               operator: :in
             }
    end

    test "decodes date range filters", %{columns: columns} do
      url_params = %{"created_at" => "2023-01-01,2023-12-31"}

      result = UrlManager.decode_filters(url_params, columns)

      assert result["created_at"] == %{
               type: :date_range,
               value: %{from: "2023-01-01", to: "2023-12-31"},
               operator: :between
             }
    end

    test "decodes partial date range filters", %{columns: columns} do
      url_params = %{"created_at" => "2023-01-01"}

      result = UrlManager.decode_filters(url_params, columns)

      assert result["created_at"] == %{
               type: :date_range,
               value: %{from: "2023-01-01", to: ""},
               operator: :between
             }
    end

    test "decodes number range filters", %{columns: columns} do
      url_params = %{"price" => "10,100"}

      result = UrlManager.decode_filters(url_params, columns)

      assert result["price"] == %{
               type: :number_range,
               value: %{min: "10", max: "100"},
               operator: :between
             }
    end

    test "decodes boolean filters", %{columns: columns} do
      url_params = %{"active" => "true"}

      result = UrlManager.decode_filters(url_params, columns)

      assert result["active"] == %{type: :boolean, value: true, operator: :equals}
    end

    test "ignores empty filter values", %{columns: columns} do
      url_params = %{"title" => ""}

      result = UrlManager.decode_filters(url_params, columns)

      assert result == %{}
    end

    test "ignores non-filterable columns", %{columns: columns} do
      url_params = %{"unknown" => "value"}

      result = UrlManager.decode_filters(url_params, columns)

      assert result == %{}
    end

    test "handles atom keys in url_params", %{columns: columns} do
      url_params = %{title: "test"}

      result = UrlManager.decode_filters(url_params, columns)

      assert result["title"] == %{
               type: :text,
               value: "test",
               operator: :contains,
               case_sensitive: false
             }
    end
  end

  describe "encode_sort/1" do
    test "encodes ascending sort" do
      sort_by = [{"title", :asc}]

      result = UrlManager.encode_sort(sort_by)

      assert result == "title"
    end

    test "encodes descending sort" do
      sort_by = [{"title", :desc}]

      result = UrlManager.encode_sort(sort_by)

      assert result == "-title"
    end

    test "encodes multiple sorts" do
      sort_by = [{"title", :desc}, {"created_at", :asc}, {"price", :desc}]

      result = UrlManager.encode_sort(sort_by)

      assert result == "-title,created_at,-price"
    end

    test "handles empty sort" do
      result = UrlManager.encode_sort([])

      assert result == ""
    end

    test "handles invalid sort input gracefully" do
      import ExUnit.CaptureLog

      # Test with invalid tuple format (missing direction)
      invalid_sort_by = [{"field"}]
      {result, _logs} = with_log(fn -> UrlManager.encode_sort(invalid_sort_by) end)
      assert result == ""

      # Test with non-tuple elements
      invalid_sort_by2 = ["not_a_tuple"]
      {result2, _logs} = with_log(fn -> UrlManager.encode_sort(invalid_sort_by2) end)
      assert result2 == ""

      # Test with invalid direction
      invalid_sort_by3 = [{"field", :invalid}]
      {result3, _logs} = with_log(fn -> UrlManager.encode_sort(invalid_sort_by3) end)
      assert result3 == ""
    end
  end

  describe "decode_sort/1" do
    test "decodes single ascending sort" do
      result = UrlManager.decode_sort("title")

      assert result == [{"title", :asc}]
    end

    test "decodes single descending sort" do
      result = UrlManager.decode_sort("-title")

      assert result == [{"title", :desc}]
    end

    test "decodes multiple sorts" do
      result = UrlManager.decode_sort("-title,created_at,-price")

      assert result == [{"title", :desc}, {"created_at", :asc}, {"price", :desc}]
    end

    test "filters out empty sort fields" do
      result = UrlManager.decode_sort("title,,created_at")

      assert result == [{"title", :asc}, {"created_at", :asc}]
    end

    test "handles nil input" do
      result = UrlManager.decode_sort(nil)

      assert result == []
    end

    test "handles empty string" do
      result = UrlManager.decode_sort("")

      assert result == []
    end
  end

  describe "decode_page/1" do
    test "decodes valid page number" do
      assert UrlManager.decode_page("5") == 5
      assert UrlManager.decode_page("1") == 1
      assert UrlManager.decode_page("999") == 999
    end

    test "returns 1 for invalid page numbers" do
      assert UrlManager.decode_page("0") == 1
      assert UrlManager.decode_page("-1") == 1
      assert UrlManager.decode_page("invalid") == 1
      assert UrlManager.decode_page("1.5") == 1
      assert UrlManager.decode_page("") == 1
    end

    test "handles nil input" do
      assert UrlManager.decode_page(nil) == 1
    end

    test "handles non-string input" do
      assert UrlManager.decode_page(123) == 1
      assert UrlManager.decode_page([]) == 1
    end
  end

  describe "notify_state_change/2" do
    test "sends notification when on_state_change is present" do
      socket = %{
        assigns: %{
          on_state_change: :table_changed,
          id: "test-table"
        }
      }

      state = %{
        filters: %{"title" => %{type: :text, value: "test", operator: :contains}},
        current_page: 2,
        sort_by: [{"title", :desc}]
      }

      result = UrlManager.notify_state_change(socket, state)

      # Should return the socket unchanged
      assert result == socket

      # Should have sent a message
      assert_received {:table_changed, "test-table", %{title: "test", page: "2", sort: "-title"}}
    end

    test "does nothing when on_state_change is not present" do
      socket = %{assigns: %{id: "test-table"}}

      state = %{
        filters: %{},
        current_page: 1,
        sort_by: []
      }

      result = UrlManager.notify_state_change(socket, state)

      assert result == socket
      refute_received _
    end
  end

  describe "ensure_multiselect_fields/2" do
    test "adds missing multi-select fields as empty arrays" do
      filter_params = %{"title" => ["value1"]}

      columns = [
        %{field: "title", filterable: true, filter_type: :multi_select},
        %{field: "tags", filterable: true, filter_type: :multi_select},
        %{field: "status", filterable: true, filter_type: :select}
      ]

      result = UrlManager.ensure_multiselect_fields(filter_params, columns)

      assert result["title"] == ["value1"]
      assert result["tags"] == []
      refute Map.has_key?(result, "status")
    end

    test "preserves existing multi-select fields" do
      filter_params = %{"tags" => ["tag1", "tag2"]}

      columns = [
        %{field: "tags", filterable: true, filter_type: :multi_select}
      ]

      result = UrlManager.ensure_multiselect_fields(filter_params, columns)

      assert result["tags"] == ["tag1", "tag2"]
    end

    test "ignores non-filterable multi-select columns" do
      filter_params = %{}

      columns = [
        %{field: "tags", filterable: false, filter_type: :multi_select}
      ]

      result = UrlManager.ensure_multiselect_fields(filter_params, columns)

      assert result == %{}
    end
  end

  describe "validate_url_params/1" do
    test "validates normal parameters" do
      params = %{"title" => "test", "page" => "2"}

      assert UrlManager.validate_url_params(params) == {:ok, params}
    end

    test "rejects too many parameters" do
      params =
        1..100
        |> Enum.map(fn i -> {"key#{i}", "value#{i}"} end)
        |> Enum.into(%{})

      assert UrlManager.validate_url_params(params) == {:error, "Too many URL parameters"}
    end

    test "rejects parameters that are too long" do
      long_value = String.duplicate("a", 1001)
      params = %{"title" => long_value}

      assert UrlManager.validate_url_params(params) == {:error, "URL parameter too long"}
    end

    test "rejects non-map input" do
      assert UrlManager.validate_url_params("not a map") ==
               {:error, "Invalid URL parameters format"}

      assert UrlManager.validate_url_params(nil) == {:error, "Invalid URL parameters format"}
    end
  end

  describe "integration scenarios" do
    test "round-trip encoding and decoding preserves state" do
      columns = [
        %{field: "title", filterable: true, filter_type: :text},
        %{field: "tags", filterable: true, filter_type: :multi_select},
        %{field: "created_at", filterable: true, filter_type: :date_range}
      ]

      original_state = %{
        filters: %{
          "title" => %{type: :text, value: "test", operator: :contains, case_sensitive: false},
          "tags" => %{type: :multi_select, value: ["tag1", "tag2"], operator: :in},
          "created_at" => %{
            type: :date_range,
            value: %{from: "2023-01-01", to: "2023-12-31"},
            operator: :between
          }
        },
        current_page: 3,
        sort_by: [{"title", :desc}, {"created_at", :asc}]
      }

      # Encode to URL
      encoded = UrlManager.encode_state(original_state)

      # Convert to string keys (simulating URL parameters)
      url_params = Enum.into(encoded, %{}, fn {k, v} -> {to_string(k), v} end)

      # Decode back
      decoded_state = UrlManager.decode_state(url_params, columns)

      # Should match original
      assert decoded_state.filters == original_state.filters
      assert decoded_state.current_page == original_state.current_page
      assert decoded_state.sort_by == original_state.sort_by
    end

    test "handles complex real-world scenario" do
      columns = [
        %{field: "name", filterable: true, filter_type: :text},
        %{field: "status", filterable: true, filter_type: :select},
        %{field: "categories", filterable: true, filter_type: :multi_select},
        %{field: "price", filterable: true, filter_type: :number_range},
        %{field: "created_at", filterable: true, filter_type: :date_range},
        %{field: "active", filterable: true, filter_type: :boolean}
      ]

      # Simulate URL parameters from a real request
      url_params = %{
        "name" => "product",
        "status" => "published",
        "categories" => "electronics,gadgets",
        "price" => "100,500",
        "created_at" => "2023-01-01,2023-06-30",
        "active" => "true",
        "page" => "2",
        "sort" => "-created_at,name"
      }

      decoded = UrlManager.decode_state(url_params, columns)

      assert decoded.filters["name"].value == "product"
      assert decoded.filters["status"].value == "published"
      assert decoded.filters["categories"].value == ["electronics", "gadgets"]
      assert decoded.filters["price"].value == %{min: "100", max: "500"}

      assert decoded.filters["created_at"].value == %{
               from: "2023-01-01",
               to: "2023-06-30"
             }

      assert decoded.filters["active"].value == true
      assert decoded.current_page == 2
      assert decoded.sort_by == [{"created_at", :desc}, {"name", :asc}]
    end
  end
end
