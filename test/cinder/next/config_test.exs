defmodule Cinder.Next.ConfigTest do
  use ExUnit.Case, async: true

  alias Cinder.Next.Config

  # A `<:field>` slot entry, as Phoenix gives it
  defp field(name, attrs \\ []) do
    Map.merge(
      %{__slot__: :field, name: name, inner_block: fn _changed, _record -> "" end},
      Map.new(attrs)
    )
  end

  defp build(fields, options \\ [id: "albums", resource: Music.Album]) do
    Config.build(options, fields)
  end

  test "each column has a label, the humanised field unless one's given" do
    config = build([field("title"), field("artist.name"), field("price", label: "Cost")])
    assert Enum.map(config.columns, & &1.label) == ["Title", "Artist > Name", "Cost"]
  end

  test "each column is a field, to load what it shows" do
    config = build([field("title"), field("artist.name")])

    assert [%{name: "title", load: nil}, %{name: "artist.name", load: {:artist, []}}] =
             config.fields
  end

  test "the source is the resource, or the query" do
    query = Ash.Query.sort(Music.Album, title: :asc)
    assert build([field("title")]).source == Music.Album
    assert build([field("title")], id: "albums", query: query).source == query
  end

  test "a resource and a query together, or neither, is an error" do
    query = Ash.Query.new(Music.Album)

    assert_raise ArgumentError, "give a collection a `resource` or a `query`, not both", fn ->
      build([field("title")], id: "albums", resource: Music.Album, query: query)
    end

    assert_raise ArgumentError, "a collection needs a `resource` or a `query`", fn ->
      build([field("title")], id: "albums")
    end
  end

  test "an option of the wrong type is an error naming the collection" do
    assert_raise ArgumentError,
                 ~s(<Cinder.Next.collection id="albums">: expected module in :resource option, got: "Music.Album"),
                 fn ->
                   build([field("title")], id: "albums", resource: "Music.Album")
                 end
  end

  test "a column with no content is an error" do
    assert_raise ArgumentError,
                 ~s(<:field name="title"> needs content, such as <:field :let={record} name="title">{record.title}</:field>),
                 fn ->
                   build([field("title", inner_block: nil)])
                 end
  end

  test "a column attribute of the wrong type is an error naming the column" do
    assert_raise ArgumentError,
                 ~s(<:field name="title">: invalid value for :label option: expected string, got: 123),
                 fn ->
                   build([field("title", label: 123)])
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

    config = build([field("title")], options)
    assert {config.actor, config.tenant, config.scope} == {%{name: "A"}, "t", scope}
  end

  test "a scope that Ash can't read is an error" do
    assert_raise ArgumentError,
                 ~s(<Cinder.Next.collection id="albums">: invalid value for :scope option: ) <>
                   "expected a value which implements the `Ash.Scope.ToOpts` protocol",
                 fn ->
                   build([field("title")], id: "albums", resource: Music.Album, scope: 123)
                 end
  end

  test "query_opts are Ash's read options" do
    options = [
      id: "albums",
      resource: Music.Album,
      query_opts: [timeout: 5_000, context: %{a: 1}]
    ]

    assert build([field("title")], options).query_opts == [timeout: 5_000, context: %{a: 1}]
  end

  test "query_opts that aren't read options, or that the collection sets, are errors" do
    query_opts = fn opts ->
      build([field("title")], id: "albums", resource: Music.Album, query_opts: opts)
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

  describe "sorting" do
    test "a column with `sort` cycles unsorted, ascending, descending, or its own cycle" do
      config =
        build([
          field("title", sort: true),
          field("added_at", sort: [cycle: [:desc, :asc, nil]]),
          field("price")
        ])

      assert Enum.map(config.columns, & &1.sort) == [
               %{cycle: [nil, :asc, :desc]},
               %{cycle: [:desc, :asc, nil]},
               nil
             ]

      assert Enum.map(config.fields, &{&1.name, &1.sortable?}) ==
               [{"title", true}, {"added_at", true}, {"price", false}]
    end

    test "two columns for one field are one field, sortable if either is" do
      config = build([field("title"), field("title", sort: true)])
      assert [%{name: "title", sortable?: true}] = config.fields
      assert length(config.columns) == 2
    end

    test "the sort mode is additive unless given, as an atom or a string" do
      assert build([field("title")]).sort.mode == :additive

      for mode <- [:exclusive, "exclusive"] do
        options = [id: "albums", resource: Music.Album, sort: [mode: mode]]
        assert build([field("title")], options).sort.mode == :exclusive
      end
    end

    test "the starting sort: the query's on sortable fields, then always-sorted columns" do
      query = Ash.Query.sort(Music.Album, price: :desc, track_count: :asc)

      config =
        build(
          [
            field("price", sort: true),
            field("track_count"),
            field("title", sort: [cycle: [:asc, :desc]]),
            field("release_date", sort: [cycle: [:desc, :asc]])
          ],
          id: "albums",
          query: query
        )

      assert config.sort.default ==
               [{"price", :desc}, {"title", :asc}, {"release_date", :desc}]
    end

    test "`sort={false}` is the same as no `sort`" do
      assert [%{sort: nil}] = build([field("title", sort: false)]).columns
    end

    test "a cycle with something that isn't a direction is an error naming the column" do
      assert_raise ArgumentError,
                   ~s(<:field name="title">: invalid list in :cycle option: invalid value for list ) <>
                     "element at position 0: expected one of [nil, :asc, :desc, :asc_nils_first, " <>
                     ":asc_nils_last, :desc_nils_first, :desc_nils_last], got: :up (in options [:sort])",
                   fn -> build([field("title", sort: [cycle: [:up, :down]])]) end
    end

    test "a sort mode that isn't one is an error naming the collection" do
      options = [id: "albums", resource: Music.Album, sort: [mode: :sideways]]

      assert_raise ArgumentError,
                   ~s(<Cinder.Next.collection id="albums">: invalid value for :mode option: ) <>
                     ~s(expected one of [:additive, :exclusive, "additive", "exclusive"], ) <>
                     "got: :sideways (in options [:sort])",
                   fn -> build([field("title")], options) end
    end

    test "a column that's always sorted, and already sorted by the query, keeps the query's" do
      query = Ash.Query.sort(Music.Album, title: :desc)
      config = build([field("title", sort: [cycle: [:asc, :desc]])], id: "albums", query: query)
      assert config.sort.default == [{"title", :desc}]
    end
  end

  test "a field the resource doesn't have is an error" do
    assert_raise ArgumentError, ~s("nope" is not a field of Music.Album), fn ->
      build([field("nope")])
    end
  end
end
