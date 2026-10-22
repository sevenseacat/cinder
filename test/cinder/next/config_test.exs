defmodule Cinder.Next.ConfigTest do
  use ExUnit.Case, async: true

  alias Cinder.Next.Config
  alias Cinder.Next.Config.{Filter, Sort}

  # Slot entries as HEEx hands them to the component
  defp col(field, attrs \\ []), do: slot(:col, field, attrs)
  defp filter(field, attrs \\ []), do: slot(:filter, field, attrs)
  defp sort(field, attrs \\ []), do: slot(:sort, field, attrs)

  defp slot(name, field, attrs),
    do: Map.merge(%{__slot__: name, field: field, inner_block: nil}, Map.new(attrs))

  defp build(slots) do
    Config.build(Map.merge(%{resource: Music.Album, query: nil}, Map.new(slots)))
  end

  describe "shorthands on <:col>" do
    test "declare the field's filter, sort and search with defaults" do
      config = build(col: [col("title", filter: true, sort: true, search: true)])
      title = config.fields["title"]

      assert %Filter{type: :text} = title.filter
      assert %Sort{cycle: [nil, :asc, :desc]} = title.sort
      assert title.search?
      assert config.search.enabled?
    end

    test "a column without them declares nothing" do
      genre = build(col: [col("genre")]).fields["genre"]

      refute genre.filter
      refute genre.sort
      refute genre.search?
    end
  end

  describe "explicit slots" do
    test "atom-valued attrs also take their string form" do
      genre =
        build(filter: [filter("genre", type: "multi_select", match_mode: "all")]).fields["genre"]

      assert genre.filter.type == :multi_select
      assert genre.filter.options[:match_mode] == :all
    end

    test "an unknown string type is an error that lists the known ones" do
      assert_raise ArgumentError, ~r/unknown filter type "selectt".*:select/, fn ->
        build(filter: [filter("genre", type: "selectt")])
      end
    end

    test "a <:filter> infers its type and options from the attribute" do
      genre = build(filter: [filter("genre", type: :select, prompt: "Any genre")]).fields["genre"]

      assert genre.filter.type == :select
      assert genre.filter.options[:prompt] == "Any genre"
      assert {"Jazz", :jazz} in genre.filter.options[:options]
    end

    test "a <:filter> overrides the shorthand for the same field" do
      config = build(col: [col("genre", filter: true)], filter: [filter("genre", type: :select)])

      assert config.fields["genre"].filter.type == :select
      assert config.filter_order == ["genre"]
    end

    test "a <:sort> doesn't need a filter, or a column" do
      config = build(sort: [sort("price", cycle: [:desc, :asc])])

      assert %Sort{cycle: [:desc, :asc]} = config.fields["price"].sort
      refute config.fields["price"].filter
      assert config.columns == []
    end

    test "a <:filter> keeps its help text, and its inner block for rendering" do
      price = filter("price", type: :number_range, help: "In AUD", inner_block: :rendered)

      assert %Filter{help: "In AUD", render: ^price} =
               build(filter: [price]).fields["price"].filter
    end

    test "declaring the same capability twice for a field is an error" do
      assert_raise ArgumentError, ~r/<:filter> is declared 2 times for the field "genre"/, fn ->
        build(filter: [filter("genre"), filter("genre", type: :select)])
      end
    end
  end

  describe "labels" do
    test "the slot's own label wins" do
      config = build(col: [col("price", label: "Cost")], sort: [sort("price", label: "Price")])

      assert config.fields["price"].label == "Cost"
    end

    test "a declaration without a label borrows one from another declaration of the field" do
      config = build(filter: [filter("price", label: "Price (AUD)")], sort: [sort("price")])

      assert config.fields["price"].label == "Price (AUD)"
    end

    test "falls back to the humanised field name" do
      assert build(sort: [sort("release_date")]).fields["release_date"].label == "Release Date"
    end
  end

  describe "order" do
    test "shorthands come first in column order, then explicit slots in their own order" do
      config =
        build(
          col: [col("title", filter: true), col("genre", filter: true), col("price")],
          filter: [filter("price", type: :number_range), filter("genre", type: :select)]
        )

      assert config.filter_order == ["title", "price", "genre"]
    end
  end

  describe "search" do
    test "is off without any search fields" do
      refute build(col: [col("title")], search: [label: "Find"]).search.enabled?
    end

    test "takes fields from the search attr as well as columns" do
      config = build(col: [col("title", search: true)], search: [fields: ["artist.name"]])

      assert config.fields["artist.name"].search?
      assert config.fields["title"].search?
    end

    test "can be turned off" do
      refute build(col: [col("title", search: true)], search: false).search.enabled?
    end
  end

  test "engine_columns gives the column maps the existing engine expects" do
    config = build(col: [col("title", filter: true, sort: true)], filter: [filter("genre")])

    assert %{
             field: "title",
             filterable: true,
             filter_type: :text,
             sortable: true,
             searchable: false
           } = Enum.find(Config.engine_columns(config), &(&1.field == "title"))
  end

  describe "arguments" do
    defp argument(name, attrs \\ []), do: Map.merge(%{name: name}, Map.new(attrs))

    defp with_arguments(arguments, extra \\ []) do
      build([action: :with_min_tracks, argument: arguments] ++ extra)
    end

    test "infer their input and whether they're required from the action" do
      config = with_arguments([argument("min_tracks")])
      field = config.fields["min_tracks"]

      assert %{source: :argument, required?: true, type: :text} = field.filter
      assert field.filter.options[:input_type] == "number"
      assert field.label == "Min Tracks"
    end

    test "come before filters, and the engine never filters on them" do
      config =
        with_arguments([argument("min_tracks", label: "At least")], filter: [filter("genre")])

      assert config.filter_order == ["min_tracks", "genre"]
      assert config.argument_fields == ["min_tracks"]
      refute Enum.find(config.engine_columns, &(&1.field == "min_tracks")).filterable
    end

    test "must be declared on the action" do
      assert_raise ArgumentError, ~r/:with_min_tracks action has no argument "max_tracks"/, fn ->
        with_arguments([argument("max_tracks")])
      end
    end

    test "can't share a name with a field" do
      assert_raise ArgumentError, ~r/both an <:argument> and a field/, fn ->
        with_arguments([argument("min_tracks")], col: [col("min_tracks")])
      end
    end
  end

  describe "layout" do
    test "defaults to a table, and takes the string form" do
      assert build([]).default_layout == :table
      assert build(layout: "grid").default_layout == :grid
    end

    test "an unknown layout is an error" do
      assert_raise ArgumentError,
                   ~r/:layout option: expected one of \[:table, :grid, :list\].*"cards"/,
                   fn ->
                     build(layout: "cards")
                   end
    end

    test "a list is a one-column grid, and nothing past the config sees :list" do
      assert %{default_layout: :grid, grid_columns: 1} = build(layout: :list)
      assert %{default_layout: :grid, grid_columns: 1} = build(layout: "list")
    end

    test "a list with grid_columns contradicts itself" do
      assert_raise ArgumentError, ~r/a list is one column/, fn ->
        build(layout: :list, grid_columns: 3)
      end
    end

    test "grid_columns takes a number or breakpoints, and only for grids" do
      assert build(layout: :grid, grid_columns: 3).grid_columns == 3
      assert build(layout: :grid, grid_columns: [xs: 1, md: 3]).grid_columns == [xs: 1, md: 3]

      assert_raise ArgumentError, ~r/only applies to grids/, fn ->
        build(grid_columns: 3)
      end

      assert_raise ArgumentError,
                   ~r/:grid_columns option: expected a positive count, or breakpoints/,
                   fn ->
                     build(layout: :grid, grid_columns: [huge: 4])
                   end
    end

    test "the layouts to switch between come from what's declared" do
      item = [%{__slot__: :item, inner_block: nil}]

      assert build(col: [col("title")]).layouts == [:table]
      assert build(layout: :grid, item: item).layouts == [:grid]

      # Columns and an item: either, starting on the declared one, which takes grid_columns
      config = build(layout: :table, col: [col("title")], item: item, grid_columns: 3)
      assert %{layouts: [:table, :grid], default_layout: :table, grid_columns: 3} = config
    end

    test "your own page markup is a LiveView-kept collection, not a layout" do
      assert_raise ArgumentError, ~r/no custom layout.*Cinder.Next.LiveView/, fn ->
        build(layout: "custom")
      end
    end
  end

  describe "headers" do
    defp header(field), do: %{__slot__: :header, field: field, inner_block: :rendered}

    test "belong to the column of their field" do
      config = build(col: [col("title"), col("genre")], header: [header("genre")])

      assert [%{field: "title", header: nil}, %{field: "genre", header: %{field: "genre"}}] =
               config.columns
    end

    test "for a field with no column, or twice for one, are errors" do
      assert_raise ArgumentError, ~r/<:header> for "price" has no <:col>/, fn ->
        build(col: [col("title")], header: [header("price")])
      end

      assert_raise ArgumentError, ~r/<:header> is declared 2 times for the field "title"/, fn ->
        build(col: [col("title")], header: [header("title"), header("title")])
      end
    end
  end

  describe "validation" do
    # A socket isn't needed: the options are checked before it's touched
    defp assign_collection(opts),
      do:
        Cinder.Next.LiveView.assign_collection(
          %Phoenix.LiveView.Socket{},
          :albums,
          Music.Album,
          opts
        )

    test "an unknown option is an error, rather than ignored" do
      assert_raise ArgumentError, ~r/assign_collection: unknown options \[:sortz\]/, fn ->
        assign_collection(sortz: [:title])
      end
    end

    test "a value of the wrong type names the declaration it's in" do
      assert_raise ArgumentError, ~r/<:col> for "title": invalid value for :sort option/, fn ->
        build(col: [col("title", sort: "yes")])
      end

      assert_raise ArgumentError,
                   ~r/<Cinder.Next.collection>: invalid value for :page_size/,
                   fn ->
                     build(page_size: 0)
                   end
    end

    test "string forms come out as atoms" do
      config =
        build(
          pagination_mode: "keyset",
          filter: [filter("genre", type: "multi_select", match_mode: "all")],
          group: [%{__slot__: :group, field: "genre", sort: "desc", inner_block: nil}]
        )

      assert config.pagination == :keyset
      assert config.fields["genre"].filter.options[:match_mode] == :all
      assert config.group.direction == :desc
    end

    test "slots and keyword lists give the same error for the same mistake" do
      message =
        ~r/<:filter> for "genre": invalid value for :type option: unknown filter type "selectt"/

      assert_raise ArgumentError, message, fn ->
        build(filter: [filter("genre", type: "selectt")])
      end

      assert_raise ArgumentError, message, fn ->
        assign_collection(filters: [genre: "selectt"])
      end
    end
  end

  describe "scope" do
    test "is passed through as it is" do
      scope = %{actor: :someone, tenant: "acme", shared: %{tz: "UTC"}}

      assert build(scope: scope).scope == scope
    end

    test "is made from an actor and/or tenant, with only the keys given" do
      assert build(actor: :someone).scope == %{actor: :someone}
      assert build(actor: :someone, tenant: "acme").scope == %{actor: :someone, tenant: "acme"}
      assert build([]).scope == nil
    end

    test "can't be given alongside an actor or tenant" do
      assert_raise ArgumentError, ~r/either a scope, or an actor and\/or tenant/, fn ->
        build(scope: %{actor: :someone}, tenant: "acme")
      end
    end
  end
end
