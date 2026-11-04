defmodule Cinder.Next.ConfigTest do
  use ExUnit.Case, async: true

  alias Cinder.Next.Config

  # A `<:col>` slot entry, as Phoenix gives it
  defp col(field, attrs \\ []) do
    Map.merge(
      %{__slot__: :col, field: field, inner_block: fn _changed, _record -> "" end},
      Map.new(attrs)
    )
  end

  defp build(columns, options \\ [id: "albums", resource: Music.Album]) do
    Config.build(options, columns)
  end

  test "each column has a label, the humanised field unless one's given" do
    config = build([col("title"), col("artist.name"), col("price", label: "Cost")])
    assert Enum.map(config.columns, & &1.label) == ["Title", "Artist > Name", "Cost"]
  end

  test "each column is a field, to load what it shows" do
    config = build([col("title"), col("artist.name")])

    assert [%{name: "title", load: nil}, %{name: "artist.name", load: {:artist, []}}] =
             config.fields
  end

  test "the source is the resource, or the query" do
    query = Ash.Query.sort(Music.Album, title: :asc)
    assert build([col("title")]).source == Music.Album
    assert build([col("title")], id: "albums", query: query).source == query
  end

  test "a resource and a query together, or neither, is an error" do
    query = Ash.Query.new(Music.Album)

    assert_raise ArgumentError, "give a collection a `resource` or a `query`, not both", fn ->
      build([col("title")], id: "albums", resource: Music.Album, query: query)
    end

    assert_raise ArgumentError, "a collection needs a `resource` or a `query`", fn ->
      build([col("title")], id: "albums")
    end
  end

  test "an option of the wrong type is an error naming the collection" do
    assert_raise ArgumentError,
                 ~s(<Cinder.Next.collection id="albums">: expected module in :resource option, got: "Music.Album"),
                 fn ->
                   build([col("title")], id: "albums", resource: "Music.Album")
                 end
  end

  test "a column with no content is an error" do
    assert_raise ArgumentError,
                 ~s(<:col field="title"> needs content, such as <:col :let={record} field="title">{record.title}</:col>),
                 fn ->
                   build([col("title", inner_block: nil)])
                 end
  end

  test "a column attribute of the wrong type is an error naming the column" do
    assert_raise ArgumentError,
                 ~s(<:col field="title">: invalid value for :label option: expected string, got: 123),
                 fn ->
                   build([col("title", label: 123)])
                 end
  end

  test "the actor, tenant and scope are kept as given, for Ash to apply" do
    scope = %{actor: %{name: "Scope"}}

    options = [
      id: "albums",
      resource: Music.Album,
      actor: %{name: "A"},
      tenant: "t",
      scope: scope
    ]

    config = build([col("title")], options)
    assert {config.actor, config.tenant, config.scope} == {%{name: "A"}, "t", scope}
  end

  test "a scope that Ash can't read is an error" do
    assert_raise ArgumentError,
                 ~s(<Cinder.Next.collection id="albums">: invalid value for :scope option: ) <>
                   "expected a value which implements the `Ash.Scope.ToOpts` protocol",
                 fn ->
                   build([col("title")], id: "albums", resource: Music.Album, scope: 123)
                 end
  end

  test "query_opts are Ash's read options" do
    options = [
      id: "albums",
      resource: Music.Album,
      query_opts: [timeout: 5_000, context: %{a: 1}]
    ]

    assert build([col("title")], options).query_opts == [timeout: 5_000, context: %{a: 1}]
  end

  test "query_opts that aren't read options, or that the collection sets, are errors" do
    query_opts = fn opts ->
      build([col("title")], id: "albums", resource: Music.Album, query_opts: opts)
    end

    # The message ends with Ash's list of read options, which grows with Ash
    assert_raise ArgumentError,
                 ~r/^<Cinder\.Next\.collection id="albums">: unknown options \[:nope\], valid options are: \[/,
                 fn ->
                   query_opts.(nope: 1)
                 end

    assert_raise ArgumentError,
                 ~s(<Cinder.Next.collection id="albums">: give `tenant` as the collection's own attribute, not in `query_opts`),
                 fn -> query_opts.(tenant: "t") end

    assert_raise ArgumentError,
                 ~s(<Cinder.Next.collection id="albums">: `select` isn't a read option: ) <>
                   "select on the query instead, as in query={Ash.Query.select(Resource, [...])}",
                 fn -> query_opts.(select: [:title]) end
  end

  test "a field the resource doesn't have is an error" do
    assert_raise ArgumentError, ~s("nope" is not a field of Music.Album), fn ->
      build([col("nope")])
    end
  end
end
