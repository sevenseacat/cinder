defmodule Cinder.Next.StateTest do
  use ExUnit.Case, async: true

  alias Cinder.Next.State

  # Shaped as the text filter's process/2 produces it
  @title_filter %{
    "title" => %{type: :text, value: "alp", operator: :contains, case_sensitive: false}
  }
  @columns [%{field: "title", filterable: true, filter_type: :text, filter_options: []}]

  defp on_page(state, page), do: State.go_to_page(state, page)

  describe "new/1" do
    test "uses the page size and sort as both the current values and the defaults" do
      state = State.new(page_size: 10, sort: [{"title", :asc}])

      assert %{page: 1, page_size: 10, default_page_size: 10} = state
      assert state.sort == [{"title", :asc}]
      assert state.default_sort == [{"title", :asc}]
    end
  end

  describe "transitions that change the query go back to the first page" do
    test "setting filters" do
      state = State.new() |> on_page(3) |> State.set_filters(@title_filter, "")

      assert state.filters == @title_filter
      assert state.page == 1
    end

    test "setting search" do
      assert %{search: "x", page: 1} = State.new() |> on_page(3) |> State.set_filters(%{}, "x")
    end

    test "clearing a filter" do
      state =
        State.new()
        |> State.set_filters(@title_filter, "x")
        |> on_page(3)
        |> State.clear_filter("title")

      assert %{filters: %{}, search: "x", page: 1} = state
    end

    test "clearing search" do
      state = State.new() |> State.set_filters(@title_filter, "x") |> on_page(3)

      assert %{filters: @title_filter, search: "", page: 1} = State.clear_filter(state, "search")
    end

    test "clearing everything" do
      state = State.new() |> State.set_filters(@title_filter, "x") |> on_page(3)

      assert %{filters: %{}, search: "", page: 1} = State.clear_all(state)
    end

    test "toggling sort" do
      state = State.new() |> on_page(3) |> State.toggle_sort("title")

      assert %{sort: [{"title", :asc}], page: 1} = state
    end

    test "changing page size" do
      assert %{page_size: 50, page: 1} = State.new() |> on_page(3) |> State.set_page_size(50)
    end
  end

  describe "transitions that change nothing keep the page" do
    test "setting the same filters and search" do
      state = State.new() |> State.set_filters(@title_filter, "x") |> on_page(3)

      assert State.set_filters(state, @title_filter, "x").page == 3
    end

    test "setting the same page size" do
      state = State.new(page_size: 10) |> on_page(3)

      assert State.set_page_size(state, 10).page == 3
    end
  end

  describe "raw form input" do
    @price_columns [
      %{field: "price", filterable: true, filter_type: :number_range, filter_options: []}
    ]

    test "isn't part of the query, so changing it alone changes nothing that reloads" do
      state = State.new() |> on_page(3)
      new = State.set_filters(state, state.filters, state.search, %{"price_min" => "2"})

      refute State.query_changed?(state, new)
      assert new.raw == %{"price_min" => "2"}
      assert new.page == 3
    end

    test "clearing a filter drops its raw params, and only its" do
      raw = %{"price_min" => "2", "price_max" => "", "title" => "a"}
      state = State.new() |> State.set_filters(%{}, "", raw)

      assert State.clear_filter(state, "price").raw == %{"title" => "a"}
      assert State.clear_all(state).raw == %{}
    end

    test "from the URL, is kept while it still describes the filter, and dropped once it doesn't" do
      raw = %{"price_min" => "25", "price_max" => ""}
      filters = Cinder.FilterManager.params_to_filters(raw, @price_columns)
      state = State.new() |> State.set_filters(filters, "", raw)

      same_url =
        State.to_url_params(state, ["price"]) |> Map.new(fn {k, v} -> {to_string(k), v} end)

      assert State.from_url_params(state, same_url, @price_columns).raw == raw
      assert State.from_url_params(state, %{}, @price_columns).raw == %{}
    end
  end

  describe "set_sort/2" do
    test "replaces the whole sort and goes back to the first page" do
      state = State.new() |> State.toggle_sort("title") |> on_page(3)

      assert %{sort: [{"price", :desc}], page: 1} = State.set_sort(state, [{"price", :desc}])
    end
  end

  describe "go_to_page/2" do
    test "ignores pages that aren't positive integers" do
      state = State.new() |> on_page(2)

      assert State.go_to_page(state, 0).page == 2
      assert State.go_to_page(state, "3").page == 2
    end
  end

  describe "query_changed?/2" do
    test "is true when anything that affects the query differs" do
      state = State.new()

      refute State.query_changed?(state, state)
      assert State.query_changed?(state, on_page(state, 2))
      assert State.query_changed?(state, State.set_filters(state, %{}, "x"))
    end
  end

  describe "URL params" do
    # Params come back from the URL with string keys
    defp round_trip(state) do
      params =
        state |> State.to_url_params(["title"]) |> Map.new(fn {k, v} -> {to_string(k), v} end)

      State.from_url_params(State.new(page_size: 10), params, @columns)
    end

    test "round-trip filters, search, sort, page and page size" do
      state =
        State.new(page_size: 10)
        |> State.set_filters(@title_filter, "x")
        |> State.toggle_sort("title")
        |> State.set_page_size(50)
        |> on_page(2)

      assert round_trip(state) == state
    end

    test "leave out values that are the defaults" do
      params = State.new(page_size: 10) |> State.to_url_params(["title"])

      assert params == %{_filter_fields: "title"}
    end

    test "missing sort and page size go back to the defaults" do
      state =
        State.new(page_size: 10, sort: [{"title", :asc}])
        |> State.toggle_sort("title")
        |> State.set_page_size(50)

      restored = State.from_url_params(state, %{}, @columns)

      assert restored.sort == [{"title", :asc}]
      assert restored.page_size == 10
    end
  end
end
