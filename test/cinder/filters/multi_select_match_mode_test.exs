defmodule Cinder.Filters.MultiSelectMatchModeTest do
  use ExUnit.Case, async: true

  alias Cinder.Filters.MultiSelect
  alias TestResourceForInference

  describe "match_mode option processing" do
    test "defaults to :any when match_mode not specified" do
      column = %{field: "tags", filter_options: [options: []]}
      result = MultiSelect.process(["tag1"], column)

      assert result.match_mode == :any
    end

    test "respects explicitly set match_mode" do
      column_any = %{field: "tags", filter_options: [match_mode: :any]}
      column_all = %{field: "tags", filter_options: [match_mode: :all]}

      result_any = MultiSelect.process(["tag1"], column_any)
      result_all = MultiSelect.process(["tag1"], column_all)

      assert result_any.match_mode == :any
      assert result_all.match_mode == :all
    end
  end

  describe "validation with match_mode" do
    test "validates match_mode values" do
      valid_any = %{type: :multi_select, value: ["tag1"], operator: :in, match_mode: :any}
      valid_all = %{type: :multi_select, value: ["tag1"], operator: :in, match_mode: :all}
      invalid = %{type: :multi_select, value: ["tag1"], operator: :in, match_mode: :invalid}

      assert MultiSelect.validate(valid_any) == true
      assert MultiSelect.validate(valid_all) == true
      assert MultiSelect.validate(invalid) == false
    end

    test "maintains backward compatibility for old format" do
      old_format = %{type: :multi_select, value: ["tag1"], operator: :in}
      assert MultiSelect.validate(old_format) == true
    end
  end

  describe "query building with match_mode" do
    setup do
      query = Ash.Query.new(TestResourceForInference)
      %{query: query}
    end

    test "ANY mode generates OR conditions for multiple values", %{query: query} do
      filter_value = %{
        type: :multi_select,
        value: ["tag1", "tag2"],
        operator: :in,
        match_mode: :any
      }

      result = MultiSelect.build_query(query, "tags", filter_value)

      filter_str = inspect(result.filter)
      assert String.contains?(filter_str, "tag1")
      assert String.contains?(filter_str, "tag2")
      assert String.contains?(filter_str, "or")
    end

    test "ALL mode generates AND conditions for multiple values", %{query: query} do
      filter_value = %{
        type: :multi_select,
        value: ["tag1", "tag2"],
        operator: :in,
        match_mode: :all
      }

      result = MultiSelect.build_query(query, "tags", filter_value)

      filter_str = inspect(result.filter)
      assert String.contains?(filter_str, "tag1")
      assert String.contains?(filter_str, "tag2")
      assert String.contains?(filter_str, "and")
    end

    test "single values work identically in both modes", %{query: query} do
      filter_any = %{type: :multi_select, value: ["tag1"], operator: :in, match_mode: :any}
      filter_all = %{type: :multi_select, value: ["tag1"], operator: :in, match_mode: :all}

      result_any = MultiSelect.build_query(query, "tags", filter_any)
      result_all = MultiSelect.build_query(query, "tags", filter_all)

      assert inspect(result_any.filter) == inspect(result_all.filter)
    end

    test "missing match_mode defaults to ANY behavior", %{query: query} do
      old_format = %{type: :multi_select, value: ["tag1", "tag2"], operator: :in}

      explicit_any = %{
        type: :multi_select,
        value: ["tag1", "tag2"],
        operator: :in,
        match_mode: :any
      }

      result_old = MultiSelect.build_query(query, "tags", old_format)
      result_any = MultiSelect.build_query(query, "tags", explicit_any)

      assert inspect(result_old.filter) == inspect(result_any.filter)
    end
  end

  test "default_options includes match_mode" do
    defaults = MultiSelect.default_options()
    assert Keyword.get(defaults, :match_mode) == :any
  end
end
