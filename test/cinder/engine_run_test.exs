defmodule Cinder.EngineRunTest do
  # The Music records are shared ETS data
  use Cinder.ConnCase, async: false

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

  test "offset and unpaginated pages have no cursors" do
    assert %Page{first_cursor: nil, last_cursor: nil} = run(%{}, action: :paginated)
    assert %Page{first_cursor: nil, last_cursor: nil} = run(%{})
  end

  test "passes arguments to the read action" do
    generate(album(title: "Jazzy", genre: :jazz))
    page = run(%{arguments: %{"genre" => "jazz"}}, action: :by_genre)
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
    test "a missing or invalid argument is an error on that input, to translate" do
      opts = [action: :by_genre, arguments: ["genre"]]

      assert error(%{}, opts) ==
               %Engine.Error{inputs: %{"genre" => [{"is required", []}]}, reason: nil}

      assert error(%{"genre" => "polka"}, opts) ==
               %Engine.Error{inputs: %{"genre" => [{"is invalid", []}]}, reason: nil}
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
end
