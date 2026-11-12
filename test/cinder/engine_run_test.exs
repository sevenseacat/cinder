defmodule Cinder.EngineRunTest do
  # The Music records are shared ETS data
  use Cinder.ConnCase, async: false

  require Ash.Query

  alias Cinder.Engine
  alias Cinder.Engine.{Field, Page, Query}

  setup do
    artist = generate(artist(name: "Run Artist"))

    for {title, price} <- [{"Blue", "12.00"}, {"Abbey", "9.00"}, {"Cold", "15.00"}] do
      generate(album(title: title, price: Decimal.new(price), artist_id: artist.id))
    end

    on_exit(fn ->
      Ash.bulk_destroy!(Music.Album, :destroy, %{})
      Ash.bulk_destroy!(Music.Artist, :destroy, %{})
    end)
  end

  defp fields(declared \\ %{"title" => %{sortable?: true, searchable?: true}}) do
    for {name, declared} <- declared do
      {:ok, field} = Engine.field(Music.Album, struct!(Field, Map.put(declared, :name, name)))
      field
    end
  end

  defp run(query, opts \\ [], fields \\ fields()) do
    {:ok, page} = Engine.run(Music.Album, fields, struct(Query, query), opts)
    page
  end

  defp titles(%Page{records: records}), do: Enum.map(records, & &1.title)

  test "reads a page of records" do
    page = run(%{sort: [{"title", :asc}]})
    assert titles(page) == ["Abbey", "Blue", "Cold"]
    assert %Page{page: 1, page_size: 25, more?: false, previous?: false} = page
  end

  test "an empty sort leaves the source query's own sort alone" do
    source = Ash.Query.sort(Music.Album, price: :desc)
    {:ok, page} = Engine.run(source, fields(), %Query{}, [])
    assert titles(page) == ["Cold", "Blue", "Abbey"]
  end

  test "a sort replaces the source query's own" do
    source = Ash.Query.sort(Music.Album, price: :desc)
    {:ok, page} = Engine.run(source, fields(), %Query{sort: [{"title", :desc}]}, [])
    assert titles(page) == ["Cold", "Blue", "Abbey"]

    {:ok, page} = Engine.run(source, fields(), %Query{sort: [{"title", :asc}]}, [])
    assert titles(page) == ["Abbey", "Blue", "Cold"]
  end

  test "offset pages, with a count" do
    opts = [action: :paginated]
    first = run(%{sort: [{"title", :asc}], page_size: 2}, opts)
    assert titles(first) == ["Abbey", "Blue"]
    assert %Page{page: 1, page_size: 2, count: 3, more?: true, previous?: false} = first

    second = run(%{sort: [{"title", :asc}], page_size: 2, page: 2}, opts)
    assert titles(second) == ["Cold"]
    assert %Page{page: 2, more?: false, previous?: true} = second
  end

  test "no count unless asked" do
    assert %Page{count: nil} = run(%{page_size: 2}, action: :paginated, count?: false)
  end

  test "keyset pages, from a record's cursor" do
    opts = [action: :paginated, pagination: :keyset]
    first = run(%{sort: [{"title", :asc}], page_size: 2}, opts)
    assert titles(first) == ["Abbey", "Blue"]
    assert %Page{page: nil, more?: true, previous?: false} = first

    second =
      run(%{sort: [{"title", :asc}], page_size: 2, cursor: {:after, first.last_cursor}}, opts)

    assert titles(second) == ["Cold"]
    assert %Page{more?: false, previous?: true} = second

    back =
      run(%{sort: [{"title", :asc}], page_size: 2, cursor: {:before, second.first_cursor}}, opts)

    assert titles(back) == ["Abbey", "Blue"]
    assert %Page{more?: true, previous?: false} = back
  end

  test "with no page size, an action that doesn't page reads every record, and one that does uses the default" do
    assert %Page{page_size: nil} = page = run(%{page_size: nil}, action: :by_context)
    assert length(page.records) == 3
    assert %Page{page_size: 25} = run(%{page_size: nil}, action: :paginated)
  end

  test "offset and unpaginated pages have no cursors" do
    assert %Page{first_cursor: nil, last_cursor: nil} = run(%{}, action: :paginated)
    assert %Page{first_cursor: nil, last_cursor: nil} = run(%{})
  end

  defp genre(param) do
    argument = %Engine.Argument{name: "genre", param: param, input: %{}}
    {:ok, argument} = Engine.argument(Music.Album, :by_genre, argument)
    argument
  end

  # Arguments are their inputs' values, as filters are, under their `param`s
  test "passes each argument's value to the read action" do
    generate(album(title: "Jazzy", genre: :jazz))
    genre = %{type: :select, value: "jazz", operator: :equals}
    page = run(%{arguments: %{"style" => genre}}, action: :by_genre, arguments: [genre("style")])
    assert "Jazzy" in titles(page)
    assert Enum.all?(page.records, &(&1.genre == :jazz))
  end

  test "filters by each field's filter value" do
    fields = fields(%{"title" => %{filter: %{}}, "price" => %{filter: %{}}})
    # "b" matches Abbey and Blue, and Abbey is under 10
    filters = Cinder.Params.filters_from_params(%{"title" => "b", "price_min" => "10"}, fields)
    assert titles(run(%{filters: filters}, [], fields)) == ["Blue"]
  end

  describe "errors" do
    defp error(arguments, opts) do
      {:error, error} = Engine.run(Music.Album, fields(), %Query{arguments: arguments}, opts)
      error
    end

    # `QueryBuilder` logs every failed read, even one the user just needs to finish
    @tag :capture_log
    # Under the input's `param`, which is what the shell knows it by
    test "a missing or invalid argument is an error on that input, to translate" do
      opts = [action: :by_genre, arguments: [genre("style")]]

      assert error(%{}, opts) ==
               %Engine.Error{inputs: %{"style" => [{"is required", []}]}, reason: nil}

      assert error(%{"style" => %{type: :text, value: "polka", operator: :contains}}, opts) ==
               %Engine.Error{inputs: %{"style" => [{"is invalid", []}]}, reason: nil}
    end

    @tag :capture_log
    test "an argument with no input can't be fixed by the user, so the read failed" do
      assert %Engine.Error{
               inputs: inputs,
               reason: %Ash.Error.Invalid{errors: [%Ash.Error.Query.Required{field: :genre}]}
             } = error(%{}, action: :by_genre)

      assert inputs == %{}
    end

    @tag :capture_log
    test "anything else is a failure, with the original error as the reason" do
      assert %Engine.Error{inputs: inputs, reason: %Ash.Error.Unknown{errors: [unknown]}} =
               error(%{}, action: :failing)

      assert inputs == %{}
      assert %Ash.Error.Unknown.UnknownError{error: "Simulated failure"} = unknown
    end
  end

  describe "authorisation and read options" do
    defp viewers(opts) do
      {:ok, field} = Engine.field(Music.Album, %Field{name: "viewer", column?: true})
      {:ok, page} = Engine.run(Music.Album, [field], %Query{}, opts)
      page.records |> Enum.map(& &1.viewer) |> Enum.uniq()
    end

    test "the actor and the scope reach the read, with Ash's precedence between them" do
      assert viewers(actor: %{name: "Actor"}) == ["Actor"]
      assert viewers(scope: %{actor: %{name: "Scope"}}) == ["Scope"]
      assert viewers(actor: %{name: "Actor"}, scope: %{actor: %{name: "Scope"}}) == ["Actor"]
    end

    test "read options that preparations depend on reach them" do
      opts = [action: :by_context, query_opts: [context: %{only_title: "Blue"}]]
      assert titles(run(%{}, opts)) == ["Blue"]
    end
  end

  test "searches the searchable fields" do
    assert titles(run(%{search: "bl"})) == ["Blue"]
  end

  test "a custom search gets each searchable field's name and expression, and the text" do
    test = self()

    search_fn = fn query, fields, text ->
      send(test, {:searched, Enum.map(fields, & &1.name), text})
      %{expr: title} = Enum.find(fields, &(&1.name == "title"))
      Ash.Query.filter(query, ^title == ^text)
    end

    fields =
      fields(%{
        "title" => %{searchable?: true},
        "artist.name" => %{searchable?: true},
        "price" => %{column?: true}
      })

    assert titles(run(%{search: "Blue"}, [search_fn: search_fn], fields)) == ["Blue"]
    assert_received {:searched, ["artist.name", "title"], "Blue"}
  end

  test "loads what the columns need, and only the columns" do
    fields =
      fields(%{
        "title" => %{column?: true},
        "title_lower" => %{column?: true},
        "artist.name" => %{filter: %{}}
      })

    [album | _] = run(%{}, [], fields).records
    assert album.title_lower == String.downcase(album.title)
    assert %Ash.NotLoaded{} = album.artist
  end

  test "a column's loads go with the query_opts ones" do
    fields = fields(%{"title_lower" => %{column?: true}})
    [album | _] = run(%{}, [query_opts: [load: [:artist]]], fields).records
    assert album.title_lower == String.downcase(album.title)
    assert album.artist.name == "Run Artist"
  end

  describe "run_bulk_action/6" do
    defp ids(titles) do
      for album <- Ash.read!(Music.Album), album.title in titles, do: to_string(album.id)
    end

    defp remastered do
      Music.Album
      |> Ash.read!()
      |> Enum.filter(& &1.is_remastered)
      |> Enum.map(& &1.title)
      |> Enum.sort()
    end

    defp titles_left, do: Music.Album |> Ash.read!() |> Enum.map(& &1.title) |> Enum.sort()

    defp bulk(action, selection, opts \\ []) do
      {source, opts} = Keyword.pop(opts, :source, Music.Album)
      {fields, opts} = Keyword.pop(opts, :fields, fields())
      {query, opts} = Keyword.pop(opts, :query, %Query{})
      {:ok, bulk_action} = Engine.bulk_action(source, action)
      Engine.run_bulk_action(source, fields, query, bulk_action, selection, opts)
    end

    test "an update or a destroy runs on the selected records" do
      assert {:ok, %Ash.BulkResult{status: :success}} = bulk(:remaster, {:ids, ids(["Blue"])})
      assert remastered() == ["Blue"]

      assert {:ok, %Ash.BulkResult{status: :success}} =
               bulk(:destroy, {:ids, ids(["Abbey", "Cold"])})

      assert titles_left() == ["Blue"]
    end

    # Selected ids are acted on wherever the user's filters and search have left them
    test "selected records are acted on even when the filters and search hide them" do
      bulk(:remaster, {:ids, ids(["Blue", "Cold"])}, query: %Query{search: "Abbey"})
      assert remastered() == ["Blue", "Cold"]
    end

    # Each part matters: the filter keeps Abbey, the search Cold, the source query
    # Bluebird, and the exception Bonus
    test "all matching acts on the records the filters and search match, within the source query, except those excepted" do
      generate(album(title: "Bonus", price: Decimal.new("20.00")))
      generate(album(title: "Bluebird", price: Decimal.new("20.00")))

      fields = fields(%{"title" => %{searchable?: true}, "price" => %{filter: %{}}})
      filters = Cinder.Params.filters_from_params(%{"price_min" => "10"}, fields)

      opts = [
        fields: fields,
        query: %Query{filters: filters, search: "b"},
        source: Ash.Query.filter(Music.Album, title != "Bluebird")
      ]

      assert {:ok, %Ash.BulkResult{status: :success}} =
               bulk(:destroy, {:all_except, ids(["Bonus"])}, opts)

      assert titles_left() == ["Abbey", "Bluebird", "Bonus", "Cold"]
    end

    test "all matching, with nothing excepted, acts on every matching record" do
      bulk(:remaster, {:all_except, []}, query: %Query{search: "b"})
      assert remastered() == ["Abbey", "Blue"]
    end

    # As the records are read: a selected record the source query or the read action
    # (with its arguments) can't read isn't acted on
    test "only selected records the collection's read can reach" do
      generate(album(title: "Jazzy", genre: :jazz))
      generate(album(title: "Rocky", genre: :rock))
      genre = %{type: :select, value: "jazz", operator: :equals}

      opts = [
        action: :by_genre,
        arguments: [genre("style")],
        query: %Query{arguments: %{"style" => genre}},
        source: Ash.Query.filter(Music.Album, title != "Blue")
      ]

      bulk(:destroy, {:ids, ids(["Blue", "Jazzy", "Rocky"])}, opts)
      assert titles_left() == ["Abbey", "Blue", "Cold", "Rocky"]

      # The other albums' genres are random, so the search narrows it to these two
      generate(album(title: "Jazzier", genre: :jazz))
      generate(album(title: "Jazz Rock", genre: :rock))
      query = %Query{arguments: %{"style" => genre}, search: "Jazz"}
      bulk(:destroy, {:all_except, []}, Keyword.put(opts, :query, query))
      assert titles_left() == ["Abbey", "Blue", "Cold", "Jazz Rock", "Rocky"]
    end

    # A code interface takes a query in place of a record, and its options
    test "a function gets a query for the selected records, and the options" do
      opts = [actor: %{name: "Actor"}, action_opts: [return_errors?: false]]

      action = fn query, opts ->
        send(self(), {:ran, query |> Ash.read!() |> Enum.map(& &1.title), opts})
        :done
      end

      assert bulk(action, {:ids, ids(["Blue"])}, opts) == {:ok, :done}

      assert_received {:ran, ["Blue"],
                       [bulk_options: [return_errors?: false], actor: %{name: "Actor"}]}
    end

    test "a failed action is an error" do
      assert bulk(fn _query, _opts -> raise "Nope" end, {:ids, ids(["Blue"])}) == {:error, "Nope"}

      assert bulk(fn _query, _opts -> {:error, :nope} end, {:ids, ids(["Blue"])}) ==
               {:error, :nope}
    end
  end
end
