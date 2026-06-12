defmodule Cinder.FilterManager.DefaultsTest do
  use ExUnit.Case, async: true

  alias Cinder.FilterManager

  defp date_column(opts) do
    %{
      field: "delivered_on",
      filterable: true,
      filter_type: :date,
      filter_options: opts
    }
  end

  describe "apply_defaults/2" do
    test "seeds a default for a column that has none set" do
      columns = [date_column(default: ~D[2026-06-12])]

      assert FilterManager.apply_defaults(%{}, columns) ==
               %{"delivered_on" => %{type: :date, value: "2026-06-12", operator: :equals}}
    end

    test "never overwrites an existing filter value" do
      columns = [date_column(default: ~D[2026-06-12])]
      existing = %{"delivered_on" => %{type: :date, value: "2026-06-01", operator: :equals}}

      assert FilterManager.apply_defaults(existing, columns) == existing
    end

    test "ignores columns without a default option" do
      columns = [date_column([])]

      assert FilterManager.apply_defaults(%{}, columns) == %{}
    end

    test "ignores non-filterable columns" do
      columns = [%{date_column(default: ~D[2026-06-12]) | filterable: false}]

      assert FilterManager.apply_defaults(%{}, columns) == %{}
    end

    test "processes a raw string default through the column's filter" do
      columns = [date_column(default: "2026-06-12")]

      assert FilterManager.apply_defaults(%{}, columns) ==
               %{"delivered_on" => %{type: :date, value: "2026-06-12", operator: :equals}}
    end

    test "treats nil and empty-string defaults as no default" do
      assert FilterManager.apply_defaults(%{}, [date_column(default: nil)]) == %{}
      assert FilterManager.apply_defaults(%{}, [date_column(default: "")]) == %{}
    end

    test "skips defaults that the filter processes into nil" do
      # The date filter trims blank strings to nil, so a whitespace-only
      # default seeds nothing rather than an empty filter.
      columns = [date_column(default: "   ")]

      assert FilterManager.apply_defaults(%{}, columns) == %{}
    end

    test "skips defaults that process into an invalid filter" do
      # "not-a-date" processes into a structurally-complete but invalid filter;
      # validate/1 rejects it, so it must not be seeded.
      columns = [date_column(default: "not-a-date")]

      assert FilterManager.apply_defaults(%{}, columns) == %{}
    end

    test "tolerates a column with no :filter_options key" do
      columns = [%{field: "delivered_on", filterable: true, filter_type: :date}]

      assert FilterManager.apply_defaults(%{}, columns) == %{}
    end

    test "seeds defaults for several columns while preserving existing ones" do
      columns = [
        date_column(default: ~D[2026-06-12]),
        %{
          field: "shipped_on",
          filterable: true,
          filter_type: :date,
          filter_options: [default: ~D[2026-01-01]]
        }
      ]

      existing = %{"delivered_on" => %{type: :date, value: "2026-06-01", operator: :equals}}

      assert FilterManager.apply_defaults(existing, columns) == %{
               "delivered_on" => %{type: :date, value: "2026-06-01", operator: :equals},
               "shipped_on" => %{type: :date, value: "2026-01-01", operator: :equals}
             }
    end
  end
end
