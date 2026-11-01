defmodule Cinder.Integration.FilterUrlValuesTest do
  @moduledoc """
  Filter values through the URL: a custom filter's value round-trips through it, values the
  client can send that a filter can't use never reach the query, and a filter that fails to
  build fails closed (an error, never unfiltered data).

  The test data layer (ETS) accepts values a real one rejects (`added_at <= "froo"`
  is fine in ETS and an error on Postgres), so these assert that a bad value never
  gets as far as `build_query/3`, rather than waiting for the data layer to complain.
  """
  use Cinder.ConnCase, async: false

  import Phoenix.ConnTest, only: [get: 2]

  import Phoenix.LiveViewTest,
    only: [live: 2, render: 1, render_async: 1, element: 2, render_change: 2, assert_patch: 1]

  alias Cinder.Filters.{Autocomplete, Date, DateRange, NumberRange, RadioGroup, Select}

  describe "process/2 drops values a filter can't use" do
    test "dates and date ranges must be dates, or dates and times" do
      assert Date.process("froo", %{}) == nil
      assert %{value: "2026-10-25"} = Date.process("2026-10-25", %{})

      # An unusable bound is dropped and the range stays open on that side
      assert %{value: %{from: "2026-10-21", to: ""}} = DateRange.process("2026-10-21,froo", %{})
      assert DateRange.process("froo,nope", %{}) == nil

      assert %{value: %{from: "", to: "2026-10-25"}} =
               DateRange.process(%{from: "x", to: "2026-10-25"}, %{})

      # A datetime-local input sends no seconds
      assert %{value: %{from: "2026-10-25T14:30"}} =
               DateRange.process("2026-10-25T14:30,", %{})
    end

    test "number ranges must be numbers" do
      assert %{value: %{min: "5", max: ""}} = NumberRange.process("5,lots", %{})
      assert NumberRange.process("one,two", %{}) == nil

      assert %{value: %{min: "1.5", max: "10"}} =
               NumberRange.process(%{min: "1.5", max: "10"}, %{})
    end

    test "single choices must be among the options, when there are any" do
      column = %{filter_options: [options: [{"Rock", :rock}, {"Jazz", "jazz"}]]}

      for module <- [Select, RadioGroup, Autocomplete] do
        assert module.process("bogus", column) == nil, inspect(module)
        assert %{value: "rock"} = module.process("rock", column)
        assert %{value: "anything"} = module.process("anything", %{filter_options: []})
      end
    end
  end

  test "an invalid URL value is left out of the decoded filters" do
    columns = [
      %{field: "added_at", filterable: true, filter_type: :date_range, filter_options: []},
      %{field: "price", filterable: true, filter_type: :number_range, filter_options: []}
    ]

    assert %{"added_at" => %{value: %{from: "2026-10-21", to: ""}}} =
             filters =
             Cinder.UrlManager.decode_filters(
               %{"added_at" => "2026-10-21,froo", "price" => "a,b"},
               columns
             )

    refute Map.has_key?(filters, "price")
  end

  describe "from the URL, end to end" do
    setup do
      artist = generate(artist(name: "Range Artist"))

      for {title, price, added} <- [
            {"Cheap", "5", ~U[2026-01-10 10:00:00Z]},
            {"Pricey", "50", ~U[2026-06-10 10:00:00Z]}
          ] do
        generate(
          album(title: title, price: Decimal.new(price), added_at: added, artist_id: artist.id)
        )
      end

      on_exit(fn ->
        Ash.bulk_destroy!(Music.Album, :destroy, %{})
        Ash.bulk_destroy!(Music.Artist, :destroy, %{})
      end)

      path =
        Cinder.TestLive.Fixture.register(fn assigns ->
          ~H"""
          <Cinder.collection resource={Music.Album} url_state={@url_state}>
            <:col :let={album} field="title">{album.title}</:col>
            <:filter field="added_at" type={:date_range} />
            <:filter field="price" type={:number_range} />
          </Cinder.collection>
          """
        end)

      %{path: path}
    end

    test "valid ranges filter", %{conn: conn, path: path} do
      conn
      |> visit(path <> "?price=10%2C100")
      |> assert_has("td", text: "Pricey")
      |> refute_has("td", text: "Cheap")

      conn
      |> visit(path <> "?added_at=2026-01-01%2C2026-02-01")
      |> assert_has("td", text: "Cheap")
      |> refute_has("td", text: "Pricey")
    end

    test "an unusable bound is ignored, and the rest of the range still applies", %{
      conn: conn,
      path: path
    } do
      conn
      |> visit(path <> "?added_at=2026-03-01%2Cfroo")
      |> assert_has("td", text: "Pricey")
      |> refute_has("td", text: "Cheap")

      conn
      |> visit(path <> "?price=froo%2Cnope")
      |> assert_has("td", text: "Cheap")
      |> assert_has("td", text: "Pricey")
    end
  end

  # The range pattern from the custom filters guide
  defmodule TrackRange do
    @moduledoc false
    use Cinder.Filter

    @impl true
    def render(column, _current_value, _theme, _assigns) do
      assigns = %{column: column}

      ~H"""
      <input name={field_name(@column.field, "min")} />
      <input name={field_name(@column.field, "max")} />
      """
    end

    @impl true
    def process(raw_value, _column) when is_binary(raw_value) do
      with [min, max] <- String.split(raw_value, ","),
           {min_val, ""} <- Integer.parse(min),
           {max_val, ""} <- Integer.parse(max),
           true <- min_val <= max_val do
        %{type: :track_range, value: [min_val, max_val], operator: :between}
      else
        _ -> nil
      end
    end

    def process(_raw_value, _column), do: nil

    @impl true
    def validate(_value), do: true
    @impl true
    def default_options, do: []
    @impl true
    def empty?(value), do: is_nil(value)

    @impl true
    def build_query(query, field, %{value: [min, max]}) do
      field = String.to_existing_atom(field)
      Ash.Query.filter(query, ^ref(field) >= ^min and ^ref(field) <= ^max)
    end
  end

  test "a custom filter's value is kept in the URL, and applied again from it", %{conn: conn} do
    Cinder.TestHelpers.put_app_env(:filters, track_range: TrackRange)

    artist = generate(artist(name: "Track Artist"))
    generate(album(title: "Short", track_count: 5, artist_id: artist.id))
    generate(album(title: "Long", track_count: 20, artist_id: artist.id))

    on_exit(fn ->
      Ash.bulk_destroy!(Music.Album, :destroy, %{})
      Ash.bulk_destroy!(Music.Artist, :destroy, %{})
    end)

    path =
      Cinder.TestLive.Fixture.register(fn assigns ->
        ~H"""
        <Cinder.collection resource={Music.Album} url_state={@url_state}>
          <:col :let={album} field="title">{album.title}</:col>
          <:filter field="track_count" type={:track_range} />
        </Cinder.collection>
        """
      end)

    {:ok, view, _html} = live(conn, path)

    view
    |> element("form[phx-change=filter_change]")
    |> render_change(%{"filters" => %{"track_count_min" => "1", "track_count_max" => "10"}})

    # With URL sync, the filter applies when the URL comes back
    url = assert_patch(view)
    assert URI.decode_query(URI.parse(url).query) == %{"track_count" => "1,10"}
    assert_only_short(view)

    {:ok, view, _html} = live(conn, url)
    assert_only_short(view)
  end

  defp assert_only_short(view) do
    html = render(view)
    assert html =~ "Short"
    refute html =~ "Long"
  end

  # Regression: a filter that raised while building the query was dropped, so the
  # collection showed unfiltered data
  defmodule RaisingFilter do
    @moduledoc false
    use Cinder.Filter

    @impl true
    def render(_column, _value, _theme, _assigns), do: raise("not rendered in this test")
    @impl true
    def process(value, _column) when is_binary(value) and value != "",
      do: %{type: :raising, value: value, operator: :equals}

    def process(_value, _column), do: nil
    @impl true
    def validate(_value), do: true
    @impl true
    def default_options, do: []
    @impl true
    def empty?(value), do: is_nil(value)
    @impl true
    def build_query(_query, _field, _value), do: raise("this filter can't be built")
  end

  @tag :capture_log
  test "a filter that fails to build shows the error state, not unfiltered data", %{conn: conn} do
    previous = Application.get_env(:cinder, :filters)
    Application.put_env(:cinder, :filters, raising: RaisingFilter)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:cinder, :filters, previous),
        else: Application.delete_env(:cinder, :filters)
    end)

    artist = generate(artist(name: "Raising Artist"))
    generate(album(title: "Secret", artist_id: artist.id))

    # The test data is shared, so a record left behind shows up in other tests
    on_exit(fn ->
      Ash.bulk_destroy!(Music.Album, :destroy, %{})
      Ash.bulk_destroy!(Music.Artist, :destroy, %{})
    end)

    path =
      Cinder.TestLive.Fixture.register(fn assigns ->
        ~H"""
        <Cinder.collection resource={Music.Album} url_state={@url_state}>
          <:col :let={album} field="title">{album.title}</:col>
          <:filter field="title" type={:raising} />
        </Cinder.collection>
        """
      end)

    {:ok, view, _html} = live(conn, path <> "?title=anything")
    html = render_async(view)

    refute html =~ "Secret"
    assert html =~ "An error occurred"
  end
end
