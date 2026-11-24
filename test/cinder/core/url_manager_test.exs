defmodule Cinder.UrlManagerTest do
  use ExUnit.Case, async: true

  alias Cinder.UrlManager

  doctest Cinder.UrlManager

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

    @tag :pending
    test "encodes page_size when different from default" do
      state = %{
        filters: %{},
        current_page: 1,
        sort_by: [],
        page_size: 50,
        default_page_size: 25
      }

      result = UrlManager.encode_state(state)

      assert result[:page_size] == "50"
    end

    @tag :pending
    test "omits page_size when equal to default" do
      state = %{
        filters: %{},
        current_page: 1,
        sort_by: [],
        page_size: 25,
        default_page_size: 25
      }

      result = UrlManager.encode_state(state)

      refute Map.has_key?(result, :page_size)
    end

    @tag :pending
    test "omits page_size when no default specified" do
      state = %{
        filters: %{},
        current_page: 1,
        sort_by: []
      }

      result = UrlManager.encode_state(state)

      refute Map.has_key?(result, :page_size)
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

    test "joins a custom filter's list value with commas" do
      filters = %{"tags" => %{type: :my_tags, value: ["a", "b"], operator: :in}}

      assert UrlManager.encode_filters(filters) == %{tags: "a,b"}
    end

    test "leaves out a custom filter's value it can't encode, logging the filter and type" do
      filters = %{
        "name" => %{type: :text, value: "x", operator: :contains},
        "price" => %{type: :my_range, value: %{min: 1, max: 10}, operator: :between}
      }

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          assert UrlManager.encode_filters(filters) == %{name: "x"}
        end)

      assert log =~ ~s("price")
      assert log =~ ":my_range"
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

  describe "parse_sort/1" do
    test "decodes single ascending sort" do
      result = UrlManager.parse_sort("title")

      assert result == [{"title", :asc}]
    end

    test "decodes single descending sort" do
      result = UrlManager.parse_sort("-title")

      assert result == [{"title", :desc}]
    end

    test "decodes multiple sorts" do
      result = UrlManager.parse_sort("-title,created_at,-price")

      assert result == [{"title", :desc}, {"created_at", :asc}, {"price", :desc}]
    end

    test "filters out empty sort fields" do
      result = UrlManager.parse_sort("title,,created_at")

      assert result == [{"title", :asc}, {"created_at", :asc}]
    end

    test "handles nil input" do
      result = UrlManager.parse_sort(nil)

      assert result == []
    end

    test "handles empty string" do
      result = UrlManager.parse_sort("")

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

    # Regression: any page number became the query's offset, so a huge one could
    # overflow the data layer's integers (and a long digit string cost CPU to parse)
    test "caps the page, and ignores absurdly long numbers" do
      assert UrlManager.decode_page("1000000") == 1_000_000
      assert UrlManager.decode_page("1000001") == 1_000_000
      assert UrlManager.decode_page("99999999999999999999") == 1_000_000
      assert UrlManager.decode_page(String.duplicate("9", 5000)) == 1
    end

    test "handles non-string input" do
      assert UrlManager.decode_page(123) == 1
      assert UrlManager.decode_page([]) == 1
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

  # Deprecated (unused by Cinder, removed in 1.0), but it still works until then
  describe "validate_url_params/1" do
    # Called through apply/3, so the deprecation doesn't warn when the tests compile
    defp validate_url_params(params), do: apply(UrlManager, :validate_url_params, [params])

    test "validates normal parameters" do
      params = %{"title" => "test", "page" => "2"}

      assert validate_url_params(params) == {:ok, params}
    end

    test "rejects too many parameters" do
      params =
        1..100
        |> Enum.map(fn i -> {"key#{i}", "value#{i}"} end)
        |> Enum.into(%{})

      assert validate_url_params(params) == {:error, "Too many URL parameters"}
    end

    test "rejects parameters that are too long" do
      long_value = String.duplicate("a", 1001)
      params = %{"title" => long_value}

      assert validate_url_params(params) == {:error, "URL parameter too long"}
    end

    test "rejects non-map input" do
      assert validate_url_params("not a map") ==
               {:error, "Invalid URL parameters format"}

      assert validate_url_params(nil) == {:error, "Invalid URL parameters format"}
    end
  end

  describe "search parameter encoding" do
    test "encode_state includes search term when present" do
      state = %{
        filters: %{},
        current_page: 1,
        sort_by: [],
        search_term: "widget"
      }

      result = UrlManager.encode_state(state)

      assert result[:search] == "widget"
    end

    test "encode_state omits search parameter when empty" do
      state = %{
        filters: %{},
        current_page: 1,
        sort_by: [],
        search_term: ""
      }

      result = UrlManager.encode_state(state)

      refute Map.has_key?(result, :search)
    end

    test "encode_state omits search parameter when nil" do
      state = %{
        filters: %{},
        current_page: 1,
        sort_by: [],
        search_term: nil
      }

      result = UrlManager.encode_state(state)

      refute Map.has_key?(result, :search)
    end

    test "search integrates with other parameters" do
      state = %{
        filters: %{"title" => %{type: :text, value: "book", operator: :contains}},
        current_page: 2,
        sort_by: [{"title", :asc}],
        search_term: "widget"
      }

      encoded = UrlManager.encode_state(state)

      assert encoded[:title] == "book"
      assert encoded[:page] == "2"
      assert encoded[:sort] == "title"
      assert encoded[:search] == "widget"
    end
  end
end
