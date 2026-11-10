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

  # An `<:argument>` slot entry
  defp argument(name, attrs \\ []),
    do: Map.merge(%{__slot__: :argument, name: name}, Map.new(attrs))

  # A `<:bulk_action>` slot entry
  defp bulk_action(attrs), do: Map.merge(%{__slot__: :bulk_action}, Map.new(attrs))

  defp build(
         fields,
         options \\ [id: "albums", resource: Music.Album],
         arguments \\ [],
         bulk_actions \\ []
       ) do
    Config.build(options, fields, arguments, bulk_actions)
  end

  test "each column has a label, the humanised field unless one's given" do
    config =
      build([
        field("title"),
        field("artist.name"),
        field("details__recorded_on"),
        field("price", label: "Cost")
      ])

    assert Enum.map(config.columns, & &1.label) ==
             ["Title", "Artist > Name", "Details > Recorded On", "Cost"]
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

    # The engine sets `page` from `pagination`, and there's no `page` attribute
    assert_raise ArgumentError,
                 ~r/^<Cinder\.Next\.collection id="albums">: unknown options \[:page\], valid options are: \[/,
                 fn -> query_opts.(page: [limit: 5]) end

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

    test "the sort mode is additive unless given" do
      assert build([field("title")]).sort.mode == :additive
      options = [id: "albums", resource: Music.Album, sort: [mode: :exclusive]]
      assert build([field("title")], options).sort.mode == :exclusive
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

    test "a sort mode that isn't one, or is a string, is an error naming the collection" do
      for mode <- [:sideways, "exclusive"] do
        options = [id: "albums", resource: Music.Album, sort: [mode: mode]]

        assert_raise ArgumentError,
                     ~s(<Cinder.Next.collection id="albums">: invalid value for :mode option: ) <>
                       "expected one of [:additive, :exclusive], " <>
                       "got: #{inspect(mode)} (in options [:sort])",
                     fn -> build([field("title")], options) end
      end
    end

    test "a column that's always sorted, and already sorted by the query, keeps the query's" do
      query = Ash.Query.sort(Music.Album, title: :desc)
      config = build([field("title", sort: [cycle: [:asc, :desc]])], id: "albums", query: query)
      assert config.sort.default == [{"title", :desc}]
    end
  end

  describe "filtering" do
    test "a column with `filter` is filtered by the type its attribute infers" do
      config =
        build([
          field("title", filter: true),
          field("release_date", filter: true),
          field("genre", filter: true),
          field("price")
        ])

      assert Enum.map(config.fields, &{&1.name, &1.filter}) == [
               {"title",
                %{
                  type: :text,
                  module: Cinder.Filters.Text,
                  options: [operator: :contains, case_sensitive: false, placeholder: nil]
                }},
               {"release_date",
                %{
                  type: :date_range,
                  module: Cinder.Filters.DateRange,
                  options: [include_time: false]
                }},
               {"genre",
                %{
                  type: :select,
                  module: Cinder.Filters.Select,
                  options: [
                    prompt: nil,
                    options: [
                      {"Rock", :rock},
                      {"Pop", :pop},
                      {"Jazz", :jazz},
                      {"Classical", :classical}
                    ]
                  ]
                }},
               {"price", nil}
             ]
    end

    test "`filter={false}` is the same as no `filter`" do
      assert [%{filter: nil}] = build([field("title", filter: false)]).fields
    end

    test "a filter's type and options are merged over the type's defaults and enum values" do
      config =
        build([
          field("genre", filter: [type: :select, prompt: "Any"]),
          field("title", filter: [placeholder: "Search"])
        ])

      assert Enum.map(config.fields, & &1.filter) == [
               %{
                 type: :select,
                 module: Cinder.Filters.Select,
                 options: [
                   options: [
                     {"Rock", :rock},
                     {"Pop", :pop},
                     {"Jazz", :jazz},
                     {"Classical", :classical}
                   ],
                   prompt: "Any"
                 ]
               },
               %{
                 type: :text,
                 module: Cinder.Filters.Text,
                 options: [operator: :contains, case_sensitive: false, placeholder: "Search"]
               }
             ]
    end

    test "a filter's label is the control's, and the column keeps its own" do
      config = build([field("genre", label: "Genre", filter: [label: "Style"])])
      assert [%{label: "Genre"}] = config.columns
      assert [%{column: %{label: "Style"}}] = config.filters
    end

    test "a filter type that doesn't exist is an error naming the field" do
      assert_raise ArgumentError,
                   ~s("title" can't be filtered: :nope is not a filter type (known: :autocomplete, ) <>
                     ":boolean, :checkbox, :date, :date_range, :multi_checkboxes, :multi_select, " <>
                     ":number_range, :radio_group, :select, :text)",
                   fn -> build([field("title", filter: [type: :nope])]) end
    end

    test "a filter type given as a string is an error naming the column" do
      assert_raise ArgumentError,
                   ~s(<:field name="title">: invalid value for :type option: ) <>
                     ~s|expected atom, got: "select" (in options [:filter])|,
                   fn -> build([field("title", filter: [type: "select"])]) end
    end

    test "a filter that isn't `true` or a keyword list is an error naming the column" do
      assert_raise ArgumentError,
                   ~s(<:field name="title">: invalid value for :filter option: ) <>
                     ~s(expected keyword list, got: "select"),
                   fn -> build([field("title", filter: "select")]) end
    end
  end

  describe "searching" do
    test "a field with `search` is searched, whether it's a column or not" do
      config =
        build([
          field("title", search: true),
          field("artist.name", search: true, column: false, inner_block: nil),
          field("price", search: false),
          field("genre")
        ])

      assert Enum.map(config.fields, &{&1.name, &1.searchable?}) == [
               {"title", true},
               {"artist.name", true},
               {"price", false},
               {"genre", false}
             ]

      assert config.search == %{label: nil, placeholder: nil, fn: nil}
    end

    # Not an error: fields can become searchable after mount
    test "without a searchable field, there's no search, even with search options" do
      assert build([field("title")]).search == nil

      config =
        build([field("title")], id: "albums", resource: Music.Album, search: [label: "Find"])

      assert config.search == nil
    end

    test "the search's label, placeholder and function" do
      search_fn = fn query, _fields, _text -> query end

      config =
        build([field("title", search: true)],
          id: "albums",
          resource: Music.Album,
          search: [label: "Find", placeholder: "Title...", fn: search_fn]
        )

      assert config.search == %{label: "Find", placeholder: "Title...", fn: search_fn}
    end

    test "search options that aren't a keyword list, or aren't search options, are errors" do
      assert_raise ArgumentError,
                   ~s(<Cinder.Next.collection id="albums">: invalid value for :search option: ) <>
                     "expected keyword list, got: false",
                   fn ->
                     build([field("title", search: true)],
                       id: "albums",
                       resource: Music.Album,
                       search: false
                     )
                   end

      assert_raise ArgumentError,
                   ~s(<Cinder.Next.collection id="albums">: unknown options [:nope], ) <>
                     "valid options are: [:label, :placeholder, :fn] (in options [:search])",
                   fn ->
                     build([field("title", search: true)],
                       id: "albums",
                       resource: Music.Album,
                       search: [nope: true]
                     )
                   end
    end

    test "searching a field that can't be searched is an error naming the field" do
      assert_raise ArgumentError,
                   ~s("artist" can't be searched: it is a relationship, not a field),
                   fn ->
                     build([field("artist", search: true)])
                   end
    end
  end

  test "a field with `column={false}` is a field, but not a column, and needs no content" do
    config =
      build([
        field("title"),
        field("genre", column: false, filter: true, inner_block: nil)
      ])

    assert Enum.map(config.columns, & &1.field) == ["title"]

    assert [%{name: "title", column?: true}, %{name: "genre", column?: false, load: nil}] =
             config.fields

    assert [%{column: %{field: "genre", label: "Genre"}, module: Cinder.Filters.Select}] =
             config.filters
  end

  test "a field that isn't a column isn't in the starting sort, as nothing would show it" do
    config =
      build([
        field("title", sort: [cycle: [:asc, :desc]]),
        field("price", sort: [cycle: [:desc, :asc]], column: false)
      ])

    assert config.sort.default == [{"title", :asc}]
  end

  test "a second <:field> for a name is an error" do
    assert_raise ArgumentError,
                 ~s(<:field name="title"> is declared twice: each field is declared once),
                 fn -> build([field("title"), field("title", sort: true)]) end
  end

  test "a field the resource doesn't have is an error" do
    assert_raise ArgumentError, ~s("nope" is not a field of Music.Album), fn ->
      build([field("nope")])
    end
  end

  describe "pagination" do
    defp pagination(source, pagination) do
      build([field("title")], id: "albums", query: source, pagination: pagination).pagination
    end

    test "by offset, 25 records a page, counted, unless the size is given" do
      assert build([field("title")]).pagination == %{mode: :offset, size: 25, count?: true}

      assert pagination(Ash.Query.new(Music.Album), size: 10) ==
               %{mode: :offset, size: 10, count?: true}
    end

    test "an action that can't count pages without a count" do
      query = Ash.Query.for_read(Music.Album, :uncountable)
      assert pagination(query, []) == %{mode: :offset, size: 25, count?: false}
    end

    test "by keyset when asked, or when the action only pages that way, without a count" do
      assert pagination(Ash.Query.new(Music.Album), mode: :keyset) ==
               %{mode: :keyset, size: 25, count?: false}

      assert pagination(Ash.Query.for_read(Music.Album, :keyset_only), []) ==
               %{mode: :keyset, size: 25, count?: false}
    end

    test "a mode the action can't page by is an error" do
      assert_raise ArgumentError,
                   ~s(<Cinder.Next.collection id="albums">: `pagination` can't be used: ) <>
                     "Music.Album's :keyset_only action doesn't paginate by offset",
                   fn ->
                     pagination(Ash.Query.for_read(Music.Album, :keyset_only), mode: :offset)
                   end

      assert_raise ArgumentError,
                   ~s(<Cinder.Next.collection id="albums">: `pagination` can't be used: ) <>
                     "Music.Album's :uncountable action doesn't paginate by keyset",
                   fn ->
                     pagination(Ash.Query.for_read(Music.Album, :uncountable), mode: :keyset)
                   end
    end

    test "a mode that isn't one is an error" do
      assert_raise ArgumentError,
                   ~s(<Cinder.Next.collection id="albums">: invalid value for :mode option: ) <>
                     "expected one of [:offset, :keyset], got: :cursor (in options [:pagination])",
                   fn -> pagination(Ash.Query.new(Music.Album), mode: :cursor) end
    end

    test "an action that doesn't paginate isn't paged, and asking it to is an error" do
      query = Ash.Query.for_read(Music.Album, :by_context)
      assert pagination(query, []) == nil

      assert_raise ArgumentError,
                   ~s(<Cinder.Next.collection id="albums">: `pagination` can't be used: ) <>
                     "Music.Album's :by_context action doesn't paginate",
                   fn -> pagination(query, size: 10) end
    end

    test "a size that isn't a positive integer is an error" do
      assert_raise ArgumentError,
                   ~s(<Cinder.Next.collection id="albums">: invalid value for :size option: ) <>
                     "expected positive integer, got: 0 (in options [:pagination])",
                   fn -> pagination(Ash.Query.new(Music.Album), size: 0) end
    end
  end

  describe "the read action" do
    @albums ~s(<Cinder.Next.collection id="albums">)

    test "the `action` given, the query's, or the primary read" do
      assert build([field("title")]).action == :read

      assert build([field("title")], id: "albums", resource: Music.Album, action: "by_genre").action ==
               :by_genre

      query = Ash.Query.for_read(Music.Album, :paginated)
      assert build([field("title")], id: "albums", query: query).action == :paginated
    end

    test "pagination is the `action`'s" do
      config = build([field("title")], id: "albums", resource: Music.Album, action: :keyset_only)
      assert config.pagination == %{mode: :keyset, size: 25, count?: false}
    end

    test "an action that isn't one of the resource's reads is an error" do
      assert_raise ArgumentError,
                   "#{@albums}: Music.Artist has no read action :nope (its read actions: :read)",
                   fn ->
                     build([field("name")], id: "albums", resource: Music.Artist, action: :nope)
                   end
    end

    # The old shell only warned, and read with the query's
    test "a query already reading with a different action is an error" do
      query = Ash.Query.for_read(Music.Album, :paginated)

      assert_raise ArgumentError,
                   "#{@albums}: the query already reads with :paginated, so it can't read with :by_genre",
                   fn ->
                     build([field("title")], id: "albums", query: query, action: :by_genre)
                   end
    end
  end

  describe "selection" do
    defp selection(options) do
      config = build([field("title")], [id: "albums", resource: Music.Album] ++ options)
      Map.take(config, [:selectable, :primary_key, :on_selection_change])
    end

    test "nothing is selectable unless asked" do
      assert selection([]) == %{selectable: false, primary_key: nil, on_selection_change: nil}
    end

    test "every record, or those a function picks, by their primary key" do
      assert selection(selectable: true, on_selection_change: :picked) ==
               %{selectable: true, primary_key: :id, on_selection_change: :picked}

      picks = &(&1.title == "Blue")
      assert %{selectable: ^picks, primary_key: :id} = selection(selectable: picks)
    end

    # No one field identifies a record, so the selection couldn't say which
    test "a resource whose primary key isn't one attribute can't be selectable" do
      options = [id: "codes", resource: TestCompositeKey]
      assert build([field("code")], options).selectable == false

      assert_raise ArgumentError,
                   ~s(<Cinder.Next.collection id="codes">: `selectable` can't be used: ) <>
                     "TestCompositeKey's primary key isn't a single attribute: [:album_id, :position]",
                   fn -> build([field("code")], [selectable: true] ++ options) end
    end
  end

  describe "bulk actions" do
    @selectable [id: "albums", resource: Music.Album, selectable: true]

    defp bulk_actions(slots), do: build([field("title")], @selectable, [], slots).bulk_actions

    test "none unless declared" do
      assert build([field("title")]).bulk_actions == []
    end

    test "each <:bulk_action> is an action, named and labelled by it unless given" do
      export = fn query, _opts -> {:ok, query} end

      assert bulk_actions([
               bulk_action(action: :remaster),
               bulk_action(action: "destroy", label: "Delete", confirm: "Delete {count} albums?"),
               bulk_action(action: export, name: "export_csv")
             ]) == [
               %{
                 name: "remaster",
                 label: "Remaster",
                 confirm: nil,
                 action: %Cinder.Engine.BulkAction{action: :remaster, type: :update}
               },
               %{
                 name: "destroy",
                 label: "Delete",
                 confirm: "Delete {count} albums?",
                 action: %Cinder.Engine.BulkAction{action: :destroy, type: :destroy}
               },
               %{
                 name: "export_csv",
                 label: "Export Csv",
                 confirm: nil,
                 action: %Cinder.Engine.BulkAction{action: export, type: nil}
               }
             ]
    end

    # On Artist, whose only update or destroy is `:destroy`, so the list doesn't change
    test "an action that isn't an update or destroy is an error" do
      options = [id: "artists", resource: Music.Artist, selectable: true]

      assert_raise ArgumentError,
                   ~s(<:bulk_action name="read">: Music.Artist has no update or destroy action ) <>
                     "\"read\" (its update and destroy actions: :destroy)",
                   fn -> build([field("name")], options, [], [bulk_action(action: "read")]) end
    end

    # The name says which action an event is for, and a function has none
    test "a function needs a name" do
      assert_raise ArgumentError,
                   "<:bulk_action> runs a function, so needs a `name` to go by",
                   fn -> bulk_actions([bulk_action(action: fn query, _opts -> query end)]) end
    end

    # It'd be ignored, and as a new closure on every render, would rebuild the config
    test "content is an error, as its button's text is its `label`" do
      assert_raise ArgumentError,
                   ~s(<:bulk_action name="destroy"> takes no content: ) <>
                     ~s(give its button's text as `label`, as in <:bulk_action label="Delete" />),
                   fn ->
                     bulk_actions([
                       bulk_action(action: :destroy, inner_block: fn _changed, _arg -> "" end)
                     ])
                   end
    end

    test "a name declared twice is an error" do
      assert_raise ArgumentError,
                   ~s(<:bulk_action name="destroy"> is declared twice: ) <>
                     "give each bulk action its own `name`",
                   fn ->
                     bulk_actions([bulk_action(action: :destroy), bulk_action(action: :destroy)])
                   end
    end

    test "they run on selected records, so need records to be selectable" do
      assert_raise ArgumentError,
                   ~s(<Cinder.Next.collection id="albums">: bulk actions run on the selected ) <>
                     "records, so need `selectable`",
                   fn ->
                     build([field("title")], [id: "albums", resource: Music.Album], [], [
                       bulk_action(action: :destroy)
                     ])
                   end
    end

    test "an option of the wrong type is an error naming it" do
      assert_raise ArgumentError,
                   ~s(<:bulk_action name="destroy">: invalid value for :confirm option: ) <>
                     "expected string, got: true",
                   fn -> bulk_actions([bulk_action(action: :destroy, confirm: true)]) end
    end
  end

  describe "arguments" do
    @by_genre [id: "albums", resource: Music.Album, action: :by_genre]
    @by_inputs [id: "albums", resource: Music.Album, action: :by_inputs]

    test "each <:argument> is an argument of the action, with its input" do
      config = build([field("title")], @by_genre, [argument("genre")])

      assert [%Cinder.Engine.Argument{name: "genre", required?: true, input: %{type: :select}}] =
               config.arguments

      assert [%{column: %{field: "genre", label: "Genre", filter_type: :select}, module: module}] =
               config.argument_inputs

      assert module == Cinder.Filters.Select
    end

    test "an input's label, type and options, as a filter's" do
      config =
        build([field("title")], @by_genre, [
          argument("genre",
            input: [type: :radio_group, label: "Style", options: [{"Rock", :rock}]]
          )
        ])

      assert [%{column: column, module: Cinder.Filters.RadioGroup}] = config.argument_inputs
      assert %{label: "Style", filter_type: :radio_group} = column
      assert column.filter_options[:options] == [{"Rock", :rock}]
    end

    test "an argument the action doesn't have is an error" do
      assert_raise ArgumentError,
                   ~s("nope" is not an argument of Music.Album's :by_genre action),
                   fn -> build([field("title")], @by_genre, [argument("nope")]) end
    end

    test "an argument declared twice is an error" do
      assert_raise ArgumentError,
                   ~s(<:argument name="genre"> is declared twice: each argument is declared once),
                   fn ->
                     build([field("title")], @by_genre, [argument("genre"), argument("genre")])
                   end
    end

    # They'd share a name in the form and the URL
    test "an argument named as a <:field>, one of the collection's URL params, or another argument's `param`, is an error" do
      assert_raise ArgumentError,
                   ~s(<:argument name="title"> clashes with <:field name="title"> in the form and the URL: ) <>
                     ~s(give it another name there with `param`),
                   fn -> build([field("title")], @by_inputs, [argument("title")]) end

      assert_raise ArgumentError,
                   ~s(<:argument name="page"> clashes with the collection's own URL param "page": ) <>
                     ~s(give it another name there with `param`),
                   fn -> build([field("title")], @by_inputs, [argument("page")]) end

      assert_raise ArgumentError,
                   ~s(<:argument name="size"> clashes with <:argument name="title"> in the form and the URL: ) <>
                     ~s(give it another name there with `param`),
                   fn ->
                     build([field("price")], @by_inputs, [
                       argument("title"),
                       argument("size", param: "title")
                     ])
                   end
    end

    test "a `param` is what an argument goes by in the form and the URL" do
      config =
        build([field("title")], @by_inputs, [
          argument("title", param: "named"),
          argument("page", param: "p")
        ])

      assert [%{name: "title", param: "named"}, %{name: "page", param: "p"}] = config.arguments

      assert [%{column: %{field: "named", label: "Title"}}, %{column: %{field: "p"}}] =
               config.argument_inputs
    end

    test "a query already prepared for its action can't take arguments" do
      query = Ash.Query.for_read(Music.Album, :by_genre, %{genre: :rock})

      assert_raise ArgumentError,
                   ~s("genre" can't be given: the query is already prepared for :by_genre, ) <>
                     "so the action has run without it. Give the action as `action` instead",
                   fn ->
                     build([field("title")], [id: "albums", query: query], [argument("genre")])
                   end
    end

    test "an unknown option is an error" do
      assert_raise ArgumentError,
                   ~s(<:argument name="genre">: unknown options [:nope], valid options are: [:name, :param, :input]),
                   fn -> build([field("title")], @by_genre, [argument("genre", nope: true)]) end
    end
  end
end
