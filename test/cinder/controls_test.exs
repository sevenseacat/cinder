defmodule Cinder.ControlsTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  alias Cinder.Controls
  alias Cinder.FilterManager

  defmodule TestUser do
    use Ash.Resource,
      domain: nil,
      data_layer: Ash.DataLayer.Ets,
      validate_domain_inclusion?: false

    ets do
      private?(true)
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string)
      attribute(:email, :string)
      attribute(:status, :string)
      attribute(:age, :integer)
    end

    actions do
      defaults([:create, :read, :update, :destroy])
    end
  end

  defmodule TestDomain do
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource(TestUser)
    end
  end

  defp base_theme do
    Cinder.Theme.default()
  end

  defp build_columns(opts \\ []) do
    resource = Keyword.get(opts, :resource, TestUser)

    columns =
      Keyword.get(opts, :columns, [
        %{field: "name", filter: true, __slot__: :col},
        %{
          field: "status",
          filter: [type: :select, options: [{"Active", "active"}, {"Inactive", "inactive"}]],
          __slot__: :col
        },
        %{field: "email", __slot__: :col}
      ])

    Cinder.Collection.process_columns(columns, resource)
  end

  defp build_query_columns(columns) do
    Enum.filter(columns, fn col -> col.filterable or Map.get(col, :searchable, false) end)
  end

  defp base_assigns(overrides \\ %{}) do
    columns = build_columns()
    query_columns = build_query_columns(columns)

    Map.merge(
      %{
        columns: query_columns,
        filters: %{},
        theme: base_theme(),
        target: nil,
        table_id: "test-table",
        filters_label: "Filters",
        filter_mode: true,
        raw_filter_params: %{},
        show_search: false,
        search_term: "",
        search_label: "Search",
        search_placeholder: "Search..."
      },
      overrides
    )
  end

  # ============================================================================
  # build_controls_data/1
  # ============================================================================

  describe "build_controls_data/1" do
    test "builds keyword list of lean filter maps with shared context at top level" do
      assigns = base_assigns(%{target: :some_target, raw_filter_params: %{"name" => "test"}})
      result = Controls.build_controls_data(assigns)

      # Top-level structure
      assert length(result.filters) == 2
      assert result.active_filter_count == 0
      assert is_nil(result.search)
      assert result.table_id == "test-table"
      assert result.filters_label == "Filters"
      assert result.filter_mode == true

      # Shared context at top level only
      assert result.target == :some_target
      assert result.theme == assigns.theme
      assert result.filter_values == %{"name" => "", "status" => ""}
      assert result.raw_filter_params == %{"name" => "test"}

      # Filters is a keyword list keyed by field atom
      assert [{:name, name_filter}, {:status, status_filter}] = result.filters

      assert name_filter.field == "name"
      assert name_filter.label == "Name"
      assert name_filter.type == :text
      assert name_filter.name == "filters[name]"
      assert name_filter.id == "test-table-filter-name"

      assert status_filter.field == "status"
      assert status_filter.type == :select

      # Keyed access works
      assert result.filters[:name].field == "name"
      assert result.filters[:status].type == :select
      assert is_nil(result.filters[:unknown])

      # Shared context NOT duplicated per-filter
      for {_key, filter} <- result.filters do
        refute Map.has_key?(filter, :table_id)
        refute Map.has_key?(filter, :column)
        refute Map.has_key?(filter, :theme)
        refute Map.has_key?(filter, :target)
        refute Map.has_key?(filter, :filter_values)
        refute Map.has_key?(filter, :raw_filter_params)
      end
    end

    test "returns empty filters when no filterable columns" do
      columns = build_columns(columns: [%{field: "name", __slot__: :col}])
      query_columns = build_query_columns(columns)
      assigns = base_assigns(%{columns: query_columns})
      result = Controls.build_controls_data(assigns)

      assert result.filters == []
    end

    test "populates filter values from active filters" do
      assigns =
        base_assigns(%{
          filters: %{"name" => %{type: :text, value: "john", operator: :contains}}
        })

      result = Controls.build_controls_data(assigns)

      assert result.filters[:name].value == "john"
      assert result.active_filter_count == 1
    end

    test "builds search data when search enabled" do
      assigns =
        base_assigns(%{
          show_search: true,
          search_term: "hello",
          search_label: "Find",
          search_placeholder: "Find something..."
        })

      result = Controls.build_controls_data(assigns)

      assert result.search.value == "hello"
      assert result.search.name == "search"
      assert result.search.label == "Find"
      assert result.search.placeholder == "Find something..."
      assert result.search.id == "test-table-filter-search"

      # Search map should also be lean
      refute Map.has_key?(result.search, :target)
      refute Map.has_key?(result.search, :theme)
    end
  end

  # ============================================================================
  # render_filter/1
  # ============================================================================

  describe "render_filter/1" do
    test "renders nothing when filter is nil" do
      html = render_component(&Controls.render_filter/1, %{filter: nil})
      assert html == ""
    end

    test "renders filter with label and input for different types" do
      controls = Controls.build_controls_data(base_assigns())

      for {field, label} <- [{:name, "Name"}, {:status, "Status"}] do
        html =
          render_component(&Controls.render_filter/1, %{
            filter: controls.filters[field],
            theme: base_theme()
          })

        assert html =~ label
        assert html =~ "filters[#{field}]"
        assert html =~ "filter_input_wrapper_class"
      end
    end

    test "applies custom theme" do
      controls = Controls.build_controls_data(base_assigns())
      custom_theme = Map.put(base_theme(), :filter_input_wrapper_class, "custom-wrapper")

      html =
        render_component(&Controls.render_filter/1, %{
          filter: controls.filters[:name],
          theme: custom_theme
        })

      assert html =~ "custom-wrapper"
    end
  end

  # ============================================================================
  # render_search/1
  # ============================================================================

  describe "render_search/1" do
    test "renders nothing when search is nil" do
      html = render_component(&Controls.render_search/1, %{search: nil, theme: base_theme()})
      assert html == ""
    end

    test "renders search input with clear button visibility" do
      # With value: clear button visible
      controls =
        Controls.build_controls_data(base_assigns(%{show_search: true, search_term: "hello"}))

      html =
        render_component(&Controls.render_search/1, %{
          search: controls.search,
          theme: base_theme()
        })

      assert html =~ "name=\"search\""
      assert html =~ "value=\"hello\""
      assert html =~ "Search..."
      assert html =~ "phx-debounce"
      assert html =~ "clear_filter"
      assert html =~ "phx-value-key=\"search\""
      refute html =~ "invisible"

      # Without value: clear button invisible
      controls =
        Controls.build_controls_data(base_assigns(%{show_search: true, search_term: ""}))

      html =
        render_component(&Controls.render_search/1, %{
          search: controls.search,
          theme: base_theme()
        })

      assert html =~ "invisible"
    end
  end

  # ============================================================================
  # render_header/1
  # ============================================================================

  describe "render_header/1" do
    defp render_header(overrides) do
      attrs =
        Map.merge(
          %{
            table_id: "test-table",
            filters_label: "Filters",
            active_filter_count: 0,
            filter_mode: true,
            target: nil,
            theme: base_theme(),
            has_filters: true
          },
          overrides
        )

      render_component(&Controls.render_header/1, attrs)
    end

    test "renders clear all button based on active filter count" do
      # Active filters: clear all visible
      html = render_header(%{active_filter_count: 2})

      assert html =~ "Filters"
      assert html =~ "(2"
      assert html =~ "active"
      assert html =~ "clear_all_filters"
      assert html =~ "Clear all"
      refute html =~ "invisible"

      # No active filters: clear all invisible
      html = render_header(%{active_filter_count: 0})

      assert html =~ "clear_all_filters"
      assert html =~ "invisible"
    end

    test "renders toggle controls only in toggle mode" do
      html = render_header(%{filter_mode: :toggle})

      assert html =~ "filter-toggle-expanded"
      assert html =~ "filter-toggle-collapsed"
      assert html =~ "hero-chevron-down"
      assert html =~ "hero-chevron-right"

      # Default mode: no toggle
      html = render_header(%{filter_mode: true})

      refute html =~ "filter-toggle-expanded"
    end

    test "omits clear all button when has_filters is false" do
      html = render_header(%{has_filters: false})

      refute html =~ "clear_all_filters"
    end
  end

  # ============================================================================
  # Integration: controls slot with FilterManager
  # ============================================================================

  describe "FilterManager.render_filter_controls with controls_slot" do
    test "renders default UI when no controls_slot provided" do
      html = render_component(&FilterManager.render_filter_controls/1, base_assigns())

      assert html =~ "filter_header_class"
      assert html =~ "filter_inputs_class"
      assert html =~ "Filters"
    end

    test "renders slot content in form wrapper, replacing default UI" do
      controls_slot = [
        %{
          __slot__: :controls,
          inner_block: fn _assigns, controls_data ->
            "CUSTOM_CONTROLS:filters=#{length(controls_data.filters)}"
          end
        }
      ]

      assigns = Map.put(base_assigns(), :controls_slot, controls_slot)
      html = render_component(&FilterManager.render_filter_controls/1, assigns)

      assert html =~ "CUSTOM_CONTROLS:filters=2"
      assert html =~ "phx-change=\"filter_change\""
      assert html =~ "phx-submit=\"filter_change\""
      refute html =~ "filter_header_class"
      refute html =~ "filter_inputs_class"
    end

    test "passes filter values and search data to slot" do
      assigns =
        base_assigns(%{
          filters: %{"name" => %{type: :text, value: "john", operator: :contains}},
          show_search: true,
          search_term: "test query"
        })

      controls_slot = [
        %{
          __slot__: :controls,
          inner_block: fn _assigns, controls_data ->
            "VALUE:#{controls_data.filters[:name].value}|COUNT:#{controls_data.active_filter_count}|SEARCH:#{controls_data.search.value}"
          end
        }
      ]

      assigns = Map.put(assigns, :controls_slot, controls_slot)
      html = render_component(&FilterManager.render_filter_controls/1, assigns)

      assert html =~ "VALUE:john"
      assert html =~ "COUNT:1"
      assert html =~ "SEARCH:test query"
    end

    test "does not render when no filterable columns and no search" do
      columns = build_columns(columns: [%{field: "name", __slot__: :col}])
      query_columns = build_query_columns(columns)
      assigns = base_assigns(%{columns: query_columns, show_search: false})

      controls_slot = [
        %{
          __slot__: :controls,
          inner_block: fn _assigns, _controls_data -> "SHOULD_NOT_RENDER" end
        }
      ]

      assigns = Map.put(assigns, :controls_slot, controls_slot)
      html = render_component(&FilterManager.render_filter_controls/1, assigns)

      refute html =~ "SHOULD_NOT_RENDER"
    end
  end

  # ============================================================================
  # Integration: collection with :controls slot
  # ============================================================================

  describe "collection with :controls slot" do
    test "controls slot replaces default filter UI" do
      controls_slot = [
        %{
          __slot__: :controls,
          inner_block: fn _assigns, controls_data ->
            "CONTROLS_SLOT:#{length(controls_data.filters)}"
          end
        }
      ]

      # Without slot: default UI
      assigns = %{
        resource: TestUser,
        actor: nil,
        col: [
          %{field: "name", filter: true, __slot__: :col},
          %{field: "email", __slot__: :col}
        ]
      }

      html = render_component(&Cinder.collection/1, assigns)
      assert html =~ "filter_header_class"

      # With slot: custom content, no default UI
      html = render_component(&Cinder.collection/1, Map.put(assigns, :controls, controls_slot))
      assert html =~ "CONTROLS_SLOT:1"
      refute html =~ "filter_header_class"
    end

    test "controls slot receives search and filter-only slot data" do
      controls_slot = [
        %{
          __slot__: :controls,
          inner_block: fn _assigns, controls_data ->
            search_status = if controls_data.search, do: "HAS_SEARCH", else: "NO_SEARCH"

            fields =
              Enum.map_join(controls_data.filters, ",", fn {_key, filter} -> filter.field end)

            "#{search_status}|FIELDS:#{fields}"
          end
        }
      ]

      assigns = %{
        resource: TestUser,
        actor: nil,
        col: [%{field: "name", filter: true, search: true, __slot__: :col}],
        filter: [
          %{field: "status", type: :select, options: [{"Active", "active"}], __slot__: :filter}
        ],
        controls: controls_slot
      }

      html = render_component(&Cinder.collection/1, assigns)

      assert html =~ "HAS_SEARCH"
      assert html =~ "FIELDS:name,status"
    end
  end
end
