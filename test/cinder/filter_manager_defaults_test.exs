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
  end
end
