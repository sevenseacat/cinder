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

  # Its form posts halves, folded as a built-in range's are, and the URL keeps the value
  test "a custom range type's value round-trips through the URL, from the form's halves" do
    put_app_env(:filters, track_range: Cinder.Test.TrackRange)

    {:ok, field} =
      Engine.field(Music.Album, %Field{name: "track_count", filter: %{type: :track_range}})

    form = %{"track_count_min" => "1", "track_count_max" => "10"}
    defaults = %Cinder.Engine.Query{}
    query = %{defaults | filters: Cinder.Params.filters_from_form(form, [field])}

    assert query.filters == %{
             "track_count" => %{type: :track_range, value: [1, 10], operator: :between}
           }

    params = Cinder.Params.to_url(query, [field], defaults, [])
    assert params == %{"track_count" => "1,10"}
    assert Cinder.Params.from_url(params, [field], defaults, []) == query
  end
end
