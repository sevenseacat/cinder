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
end
