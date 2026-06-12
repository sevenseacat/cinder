defmodule Cinder.Filters.DateTest do
  use ExUnit.Case, async: true

  alias Cinder.Filters.Date, as: DateFilter

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

    test "shows the current value, accepting a string or a Date" do
      column = %{field: "delivered_on", filter_options: []}

      assert render_html(column, "2026-06-12") =~ ~s(value="2026-06-12")
      assert render_html(column, ~D[2026-06-12]) =~ ~s(value="2026-06-12")
    end
  end

  describe "process/2" do
    test "builds an :equals filter from an ISO date string" do
      assert DateFilter.process("2026-06-12", %{}) ==
               %{type: :date, value: "2026-06-12", operator: :equals}
    end

    test "accepts a %Date{} (so a default flows through unchanged)" do
      assert DateFilter.process(~D[2026-06-12], %{}) ==
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
end
