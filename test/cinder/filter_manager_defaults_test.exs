defmodule Cinder.FilterManager.DefaultsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

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

    test "keeps a select's prompt value that was chosen over its default" do
      columns = [
        %{
          field: "status",
          filterable: true,
          filter_type: :select,
          filter_options: [
            options: [{"Active", "active"}],
            prompt_value: "all",
            default: "active"
          ]
        }
      ]

      filters =
        %{"status" => "all"}
        |> FilterManager.params_to_filters(columns)
        |> FilterManager.apply_defaults(columns)

      assert filters == %{"status" => %{type: :select, value: "all", operator: :any}}
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

  describe "at_default?/2" do
    defp select_filter(value), do: %{type: :select, value: value, operator: :equals}

    defp select_column(opts) do
      %{
        field: "status",
        filterable: true,
        filter_type: :select,
        filter_options: [options: [{"Active", "active"}, {"Done", "done"}]] ++ opts
      }
    end

    test "is true while the filter holds the value its default seeds" do
      assert FilterManager.at_default?(select_column(default: "active"), select_filter("active"))
    end

    test "is false once the filter holds another value" do
      refute FilterManager.at_default?(select_column(default: "active"), select_filter("done"))
    end

    test "is false for a column without a default" do
      refute FilterManager.at_default?(select_column([]), select_filter("active"))
    end

    test "is false for a filter that is not set" do
      refute FilterManager.at_default?(select_column(default: "active"), nil)
    end

    test "compares a date default by the value it processes into" do
      filter = %{type: :date, value: "2026-06-12", operator: :equals}

      assert FilterManager.at_default?(date_column(default: ~D[2026-06-12]), filter)
    end

    test "is false for a field no column declares" do
      refute FilterManager.at_default?(nil, select_filter("active"))
    end
  end

  describe "the clear button of a filter" do
    test "stays hidden while the filter holds its default" do
      assert clear_button(at_default?: true) =~ "invisible"
    end

    test "shows once the filter holds another value" do
      refute clear_button(at_default?: false) =~ "invisible"
    end

    defp clear_button(at_default?: at_default?) do
      filter = %{
        field: "status",
        label: "Status",
        type: :select,
        value: "active",
        at_default?: at_default?,
        options: [options: [{"Active", "active"}, {"Done", "done"}]],
        name: "filters[status]",
        id: "table-filter-status"
      }

      assigns = %{
        filter: filter,
        theme: Cinder.Theme.default(),
        target: nil,
        filter_values: %{},
        raw_filter_params: %{}
      }

      html = render_component(&Cinder.Controls.render_filter/1, assigns)

      ~r{<button[^>]*data-cinder-clear[^>]*>}s |> Regex.run(html) |> hd()
    end
  end

  describe "count_active_filters/2" do
    test "leaves out a filter still at its column's default" do
      columns = [date_column(default: ~D[2026-06-12])]
      at_default = %{"delivered_on" => %{type: :date, value: "2026-06-12", operator: :equals}}
      changed = %{"delivered_on" => %{type: :date, value: "2026-06-01", operator: :equals}}

      assert FilterManager.count_active_filters(at_default, columns) == 0
      assert FilterManager.count_active_filters(changed, columns) == 1
    end
  end
end
