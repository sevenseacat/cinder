defmodule Cinder.Filters.RelationshipMatchModeTest do
  @moduledoc """
  Tests for match_mode support on relationship fields (e.g., albums.title via has_many).

  Uses TestArtist/TestAlbum from test/support/test_resources.ex which have
  a properly configured has_many relationship.
  """
  use ExUnit.Case, async: true

  alias Cinder.Filter.Helpers

  describe "relationship field match_mode in filter helpers" do
    setup do
      # TestArtist has_many :albums, so we query artists and filter on albums.title
      query = Ash.Query.new(TestArtist)
      %{query: query}
    end

    test "ANY mode generates single exists with IN for multiple values", %{query: query} do
      result =
        Helpers.build_ash_filter(query, "albums.title", ["Abbey Road", "Let It Be"], :in,
          match_mode: :any
        )

      filter_str = inspect(result.filter)

      # Should have exists with IN operator (OR semantics)
      assert String.contains?(filter_str, "exists")
      assert String.contains?(filter_str, "Abbey Road")
      assert String.contains?(filter_str, "Let It Be")
      # IN operator implies OR - any match works
      refute String.contains?(filter_str, " and ")
    end

    test "ALL mode generates multiple exists clauses combined with AND", %{query: query} do
      result =
        Helpers.build_ash_filter(query, "albums.title", ["Abbey Road", "Let It Be"], :in,
          match_mode: :all
        )

      filter_str = inspect(result.filter)

      # Should have multiple exists combined with AND
      assert String.contains?(filter_str, "exists")
      assert String.contains?(filter_str, "Abbey Road")
      assert String.contains?(filter_str, "Let It Be")
      assert String.contains?(filter_str, " and ")
    end

    test "single value works identically in both modes", %{query: query} do
      result_any =
        Helpers.build_ash_filter(query, "albums.title", ["Abbey Road"], :in, match_mode: :any)

      result_all =
        Helpers.build_ash_filter(query, "albums.title", ["Abbey Road"], :in, match_mode: :all)

      # Both should produce equivalent filters for single value
      assert inspect(result_any.filter) == inspect(result_all.filter)
    end

    test "defaults to ANY mode when match_mode not specified", %{query: query} do
      result_default =
        Helpers.build_ash_filter(query, "albums.title", ["Abbey Road", "Let It Be"], :in)

      result_explicit_any =
        Helpers.build_ash_filter(query, "albums.title", ["Abbey Road", "Let It Be"], :in,
          match_mode: :any
        )

      assert inspect(result_default.filter) == inspect(result_explicit_any.filter)
    end

    test "empty value list returns unchanged query", %{query: query} do
      result = Helpers.build_ash_filter(query, "albums.title", [], :in, match_mode: :all)

      # Should return query unchanged (no filter applied)
      assert result.filter == nil
    end
  end

  describe "multi_select filter with relationship field" do
    alias Cinder.Filters.MultiSelect

    setup do
      query = Ash.Query.new(TestArtist)
      %{query: query}
    end

    test "builds query with ANY match_mode for relationship field", %{query: query} do
      filter_value = %{
        type: :multi_select,
        value: ["Abbey Road", "Let It Be"],
        operator: :in,
        match_mode: :any
      }

      result = MultiSelect.build_query(query, "albums.title", filter_value)

      filter_str = inspect(result.filter)
      assert String.contains?(filter_str, "exists")
      assert String.contains?(filter_str, "Abbey Road")
      assert String.contains?(filter_str, "Let It Be")
    end

    test "builds query with ALL match_mode for relationship field", %{query: query} do
      filter_value = %{
        type: :multi_select,
        value: ["Abbey Road", "Let It Be"],
        operator: :in,
        match_mode: :all
      }

      result = MultiSelect.build_query(query, "albums.title", filter_value)

      filter_str = inspect(result.filter)
      assert String.contains?(filter_str, "exists")
      assert String.contains?(filter_str, "Abbey Road")
      assert String.contains?(filter_str, "Let It Be")
      # ALL mode should have AND between exists clauses
      assert String.contains?(filter_str, " and ")
    end
  end
end
