defmodule Cinder.EngineCustomFilterTest do
  # Custom filter types come from app config
  use ExUnit.Case, async: false

  import Cinder.TestHelpers, only: [put_app_env: 2]

  alias Cinder.Engine
  alias Cinder.Engine.Field

  defmodule Slider do
    use Cinder.Filter

    @impl true
    def render(_column, _value, _theme, _assigns), do: nil

    @impl true
    def process(value, _column), do: %{type: :slider, value: value, operator: :equals}

    @impl true
    def validate(_value), do: true

    @impl true
    def default_options, do: [options: [], step: 1]

    @impl true
    def empty?(value), do: value in [nil, ""]

    @impl true
    def build_query(query, _field, _filter_value), do: query
  end

  test "a custom filter type is a filter type, and takes enum values if it has options" do
    put_app_env(:filters, slider: Slider)

    assert {:ok, %{filter: filter}} =
             Engine.field(Music.Album, %Field{name: "genre", filter: %{type: :slider}})

    assert filter.type == :slider
    assert filter.options[:step] == 1
    assert length(filter.options[:options]) == 4
  end

  test "a custom filter type whose module can't be loaded is an error" do
    put_app_env(:filters, gone: Cinder.EngineCustomFilterTest.Gone)

    assert {:error, message} =
             Engine.field(Music.Album, %Field{name: "title", filter: %{type: :gone}})

    assert message =~ "Cinder.EngineCustomFilterTest.Gone"
  end
end
