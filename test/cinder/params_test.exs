defmodule Cinder.ParamsTest do
  use ExUnit.Case, async: true

  alias Cinder.{Engine, Params}

  defp fields do
    for {name, declared} <- [
          {"title", %{filter: %{}}},
          {"genre", %{filter: %{}}},
          {"price", %{filter: %{}}},
          {"tags", %{filter: %{options: [options: [{"A", "a"}, {"B", "b"}]]}}},
          {"track_count", %{sortable?: true}}
        ] do
      {:ok, field} = Engine.field(Music.Album, name, declared)
      field
    end
  end

  describe "filters_from_params/2" do
    test "each filtered field's input becomes its type's filter value" do
      filters =
        Params.filters_from_params(
          %{"title" => "road", "genre" => "rock", "tags" => ["a", "b"]},
          fields()
        )

      assert %{type: :text, value: "road", operator: :contains} = filters["title"]
      assert %{type: :select, value: "rock", operator: :equals} = filters["genre"]
      assert %{type: :multi_select, value: ["a", "b"]} = filters["tags"]
    end

    test "a range's halves become one filter" do
      filters = Params.filters_from_params(%{"price_min" => "10", "price_max" => ""}, fields())
      assert %{type: :number_range, value: %{min: "10", max: ""}} = filters["price"]
    end

    test "empty input, unknown keys and fields without a filter are left out" do
      params = %{"title" => "", "nope" => "x", "track_count" => "3"}
      assert Params.filters_from_params(params, fields()) == %{}
    end

    test "input a filter can't use is left out, not an error" do
      params = %{"genre" => "polka", "tags" => ["z"], "price_min" => "lots"}
      assert Params.filters_from_params(params, fields()) == %{}
    end
  end
end
