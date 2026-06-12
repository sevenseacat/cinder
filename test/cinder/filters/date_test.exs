defmodule Cinder.Filters.DateTest.Domain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(Cinder.Filters.DateTest.Event)
  end
end

defmodule Cinder.Filters.DateTest.Event do
  @moduledoc false
  use Ash.Resource,
    domain: Cinder.Filters.DateTest.Domain,
    data_layer: Ash.DataLayer.Ets,
    validate_domain_inclusion?: false

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:on_date, :date, public?: true)
    attribute(:at_datetime, :utc_datetime_usec, public?: true)
  end

  actions do
    defaults([:read, create: [:on_date, :at_datetime]])
  end
end

defmodule Cinder.Filters.DateTest do
  use ExUnit.Case, async: true

  alias Cinder.Filters.Date, as: DateFilter
  alias Cinder.Filters.DateTest.Event

  defp render_html(column, value) do
    column
    |> DateFilter.render(value, Cinder.Theme.default(), %{table_id: "t"})
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end

  describe "render/4" do
    test "renders a single date input bound to the field" do
      html = render_html(%{field: "delivered_on", filter_options: []}, nil)

      assert html =~ ~s(type="date")
      assert html =~ ~s(name="filters[delivered_on]")
      assert html =~ "filter_date_input_class"
      assert html |> String.split(~s(type="date")) |> length() == 2
    end

    test "shows the current value" do
      column = %{field: "delivered_on", filter_options: []}

      assert render_html(column, "2026-06-12") =~ ~s(value="2026-06-12")
    end
  end

  describe "process/2" do
    test "builds an :equals filter from an ISO date string" do
      assert DateFilter.process("2026-06-12", %{}) ==
               %{type: :date, value: "2026-06-12", operator: :equals}
    end

    test "blank and non-date input is nil" do
      assert DateFilter.process("", %{}) == nil
      assert DateFilter.process("   ", %{}) == nil
      assert DateFilter.process(nil, %{}) == nil
    end
  end

  describe "validate/1" do
    test "true only for a valid :equals date filter" do
      assert DateFilter.validate(%{type: :date, value: "2026-06-12", operator: :equals})
      refute DateFilter.validate(%{type: :date, value: "nope", operator: :equals})
      refute DateFilter.validate(%{type: :date_range, value: %{from: "", to: ""}})
      refute DateFilter.validate(nil)
    end
  end

  describe "empty?/1" do
    test "blank values are empty" do
      assert DateFilter.empty?(nil)
      assert DateFilter.empty?(%{value: ""})
      assert DateFilter.empty?(%{value: nil})
      refute DateFilter.empty?(%{type: :date, value: "2026-06-12", operator: :equals})
    end
  end

  describe "registry" do
    test ":date resolves to this module" do
      assert Cinder.Filters.Registry.get_filter(:date) == Cinder.Filters.Date
    end
  end

  defp filter_value(value), do: %{type: :date, value: value, operator: :equals}

  defp matching_ids(field, value) do
    Event
    |> Ash.Query.new()
    |> DateFilter.build_query(field, filter_value(value))
    |> Ash.read!()
    |> MapSet.new(& &1.id)
  end

  describe "build_query/3" do
    test "matches an exact :date field" do
      hit = Ash.create!(Event, %{on_date: ~D[2026-06-12]})
      _miss = Ash.create!(Event, %{on_date: ~D[2026-06-13]})

      assert matching_ids("on_date", "2026-06-12") == MapSet.new([hit.id])
    end

    test "matches the whole calendar day for a datetime field" do
      midnight = Ash.create!(Event, %{at_datetime: ~U[2026-06-12 00:00:00.000000Z]})
      end_of_day = Ash.create!(Event, %{at_datetime: ~U[2026-06-12 23:59:59.999999Z]})
      _next_day = Ash.create!(Event, %{at_datetime: ~U[2026-06-13 00:00:00.000000Z]})

      assert matching_ids("at_datetime", "2026-06-12") ==
               MapSet.new([midnight.id, end_of_day.id])
    end

    test "leaves the query unchanged for a non-date value" do
      a = Ash.create!(Event, %{on_date: ~D[2026-06-12]})
      b = Ash.create!(Event, %{on_date: ~D[2026-06-13]})

      assert matching_ids("on_date", "nope") == MapSet.new([a.id, b.id])
    end
  end
end
