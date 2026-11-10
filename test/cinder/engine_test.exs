defmodule Cinder.EngineTest do
  use ExUnit.Case, async: true

  alias Cinder.Engine
  alias Cinder.Engine.{Argument, BulkAction, Field}

  describe "field/2" do
    defp filter(name, declared \\ %{}) do
      {:ok, field} = Engine.field(Music.Album, %Field{name: name, filter: declared})
      field.filter
    end

    defp error(name, declared) do
      {:error, message} =
        Engine.field(Music.Album, struct!(Field, Map.put(declared, :name, name)))

      message
    end

    test "infers a filter type from the field's Ash type" do
      assert filter("title").type == :text
      assert filter("genre").type == :select
      assert filter("tags").type == :multi_select
      assert filter("release_date").type == :date_range
      assert filter("added_at").type == :date_range
      assert filter("is_remastered").type == :boolean
      assert filter("price").type == :number_range
      assert filter("track_count").type == :number_range
      assert filter("artist.name").type == :text
      assert filter("artist.album_count").type == :number_range
      assert filter("details__recorded_on").type == :date_range
    end

    test "infers a text filter for types with no better one" do
      assert filter("artist_id").type == :text
    end

    test "the filter has its type's module, for the shell to render and check options with" do
      assert filter("genre").module == Cinder.Filters.Select
      assert filter("genre", %{type: :radio_group}).module == Cinder.Filters.RadioGroup
    end

    test "a declared type wins over the inferred one" do
      assert filter("genre", %{type: :radio_group}).type == :radio_group
      assert filter("title", %{type: :select}).type == :select
    end

    test "options are the type's defaults, then the field's enum values, then the declared ones" do
      options = filter("genre").options

      assert options[:options] == [
               {"Rock", :rock},
               {"Pop", :pop},
               {"Jazz", :jazz},
               {"Classical", :classical}
             ]

      assert Keyword.has_key?(options, :prompt)

      assert filter("genre", %{options: [prompt: "Any"]}).options[:prompt] == "Any"

      assert filter("genre", %{options: [options: [{"Rock", :rock}]]}).options[:options] ==
               [{"Rock", :rock}]

      assert filter("title").options[:operator] == :contains
      assert filter("title", %{options: [operator: :equals]}).options[:operator] == :equals
    end

    test "enum values only go to types that take options" do
      assert length(filter("genre", %{type: :radio_group}).options[:options]) == 4
      refute Keyword.has_key?(filter("genre", %{type: :text}).options, :options)
    end

    test "no filter, sort or search unless declared" do
      assert {:ok, field} = Engine.field(Music.Album, %Field{name: "title"})

      assert %Field{name: "title", filter: nil, sortable?: false, searchable?: false} =
               field
    end

    test "sort and search as declared" do
      assert {:ok, %{sortable?: true, searchable?: true}} =
               Engine.field(Music.Album, %Field{name: "title", sortable?: true, searchable?: true})
    end

    test "what showing a column's field needs loaded" do
      assert {:ok, %{load: nil}} = Engine.field(Music.Album, %Field{name: "title", column?: true})

      assert {:ok, %{load: :title_lower}} =
               Engine.field(Music.Album, %Field{name: "title_lower", column?: true})

      assert {:ok, %{load: {:artist, [:album_count]}}} =
               Engine.field(Music.Album, %Field{name: "artist.album_count", column?: true})
    end

    test "a field that isn't a column is never shown, so it needs nothing loaded" do
      assert {:ok, %{load: nil}} =
               Engine.field(Music.Album, %Field{name: "artist.album_count", filter: %{}})
    end

    test "an unknown field is an error" do
      assert error("nope", %{}) =~ ~s("nope")
      assert error("artist.nope", %{}) =~ "is not a field of Music.Album"
    end

    test "filtering, sorting or searching a field that can't be queried is an error" do
      assert error("artist", %{filter: %{}}) =~ "is a relationship"
      assert error("title_with", %{sortable?: true}) =~ "can't be sorted: it is a calculation"
      assert error("artist", %{searchable?: true}) =~ "can't be searched: it is a relationship"

      assert error("artist", %{filter: %{}, sortable?: true}) =~
               ~s("artist" can't be filtered or sorted: it is a relationship)
    end

    test "the field's path: its relationships, then its name, then any names inside it" do
      path = fn name ->
        {:ok, field} = Engine.field(Music.Album, %Field{name: name})
        field.path
      end

      assert path.("title") == ["title"]
      assert path.("artist.name") == ["artist", "name"]
      assert path.("details__recorded_on") == ["details", "recorded_on"]
    end

    test "a query is checked against its resource" do
      query = Ash.Query.for_read(Music.Album, :keyset_only)

      assert {:ok, %{filter: %{type: :select}}} =
               Engine.field(query, %Field{name: "genre", filter: %{}})

      assert {:error, ~s("nope" is not a field of Music.Album)} =
               Engine.field(query, %Field{name: "nope"})
    end

    test "showing a field that can't be queried is fine" do
      assert {:ok, %{filter: nil}} = Engine.field(Music.Album, %Field{name: "artist"})
    end

    test "an unknown filter type is an error naming the known ones" do
      message = error("title", %{filter: %{type: :radio}})
      assert message =~ ~s("title")
      assert message =~ ":radio is not a filter type"
      assert message =~ ":radio_group"
    end
  end

  describe "read_opts/0" do
    test "Ash's read options, without the ones the engine sets" do
      keys = Keyword.keys(Engine.read_opts())

      assert :timeout in keys
      assert :load in keys

      for set <- [:action, :actor, :tenant, :scope, :page, :return_query?] do
        refute set in keys
      end
    end
  end

  describe "query_sorts/2" do
    # `title`, `title_lower` and `artist.name` are sortable; `price` is only shown
    defp fields do
      for {name, sortable?} <- [
            {"title", true},
            {"title_lower", true},
            {"artist.name", true},
            {"price", false}
          ] do
        {:ok, field} = Engine.field(Music.Album, %Field{name: name, sortable?: sortable?})
        field
      end
    end

    defp query_sorts(sort), do: Engine.query_sorts(Ash.Query.sort(Music.Album, sort), fields())

    test "a resource has no sort" do
      assert Engine.query_sorts(Music.Album, fields()) == []
    end

    test "sorts on sortable fields, in order, in any direction" do
      assert query_sorts(title: :desc_nils_last, title_lower: :asc_nils_first) ==
               [{"title", :desc_nils_last}, {"title_lower", :asc_nils_first}]

      assert query_sorts([:title]) == [{"title", :asc}]
    end

    test "sorts through relationships, by their field name" do
      assert query_sorts("-artist.name") == [{"artist.name", :desc}]
    end

    test "sorts on fields that aren't sortable are left out" do
      assert query_sorts(price: :asc, title: :desc) == [{"title", :desc}]
      assert query_sorts(track_count: :asc) == []
    end
  end

  describe "pagination/3" do
    test "an action that pages by offset, counted if it can be" do
      assert Engine.pagination(Music.Album, :read, :offset) == {:ok, %{count?: true}}

      assert Engine.pagination(Music.Album, :uncountable, :offset) ==
               {:ok, %{count?: false}}
    end

    test "an action that pages by keyset" do
      assert Engine.pagination(Music.Album, :keyset_only, :keyset) ==
               {:ok, %{count?: true}}
    end

    test "an action can't be paged in a way it doesn't page" do
      assert Engine.pagination(Music.Album, :keyset_only, :offset) ==
               {:error, "Music.Album's :keyset_only action doesn't paginate by offset"}

      assert Engine.pagination(Music.Album, :uncountable, :keyset) ==
               {:error, "Music.Album's :uncountable action doesn't paginate by keyset"}
    end

    test "an action that doesn't paginate can't be paged" do
      for mode <- [:offset, :keyset] do
        assert Engine.pagination(Music.Album, :by_context, mode) ==
                 {:error, "Music.Album's :by_context action doesn't paginate"}
      end
    end
  end

  describe "primary_key/1" do
    test "the field that identifies each record" do
      assert Engine.primary_key(Music.Album) == {:ok, :id}
      assert Engine.primary_key(Ash.Query.new(Music.Album)) == {:ok, :id}
    end

    # No one field identifies a record
    test "a primary key of several attributes is an error" do
      assert Engine.primary_key(TestCompositeKey) ==
               {:error,
                "TestCompositeKey's primary key isn't a single attribute: [:album_id, :position]"}
    end
  end

  describe "bulk_action/2" do
    test "an update or destroy action, by its name or as a string" do
      assert Engine.bulk_action(Music.Album, :remaster) ==
               {:ok, %BulkAction{action: :remaster, type: :update}}

      assert Engine.bulk_action(Ash.Query.new(Music.Album), "destroy") ==
               {:ok, %BulkAction{action: :destroy, type: :destroy}}
    end

    test "a function is the developer's to run, so isn't checked" do
      fun = fn query, _opts -> {:ok, query} end
      assert Engine.bulk_action(Music.Album, fun) == {:ok, %BulkAction{action: fun, type: nil}}
    end

    # On Artist, whose only update or destroy is `:destroy`, so the list doesn't change
    test "an action that isn't one of the resource's updates or destroys is an error naming them" do
      for action <- [:nope, "nope", :read] do
        assert Engine.bulk_action(Music.Artist, action) ==
                 {:error,
                  "Music.Artist has no update or destroy action #{inspect(action)} " <>
                    "(its update and destroy actions: :destroy)"}
      end
    end
  end

  describe "read_action/2" do
    test "the query's action, or the primary read" do
      assert Engine.read_action(Ash.Query.new(Music.Album), nil) == {:ok, :read}
      assert Engine.read_action(Music.Album, nil) == {:ok, :read}

      assert Engine.read_action(Ash.Query.for_read(Music.Album, :paginated), nil) ==
               {:ok, :paginated}
    end

    test "the given action, by its name or as a string" do
      assert Engine.read_action(Music.Album, :by_genre) == {:ok, :by_genre}
      assert Engine.read_action(Music.Album, "by_genre") == {:ok, :by_genre}
    end

    # On Artist, whose only read is `:read`, so the list doesn't change as Album's grows
    test "an action that isn't one of the resource's reads is an error naming them" do
      for action <- [:nope, "nope", :destroy] do
        assert Engine.read_action(Music.Artist, action) ==
                 {:error,
                  "Music.Artist has no read action #{inspect(action)} (its read actions: :read)"}
      end
    end

    test "a query that reads with a different action is an error" do
      query = Ash.Query.for_read(Music.Album, :paginated)
      assert Engine.read_action(query, :paginated) == {:ok, :paginated}

      assert Engine.read_action(query, :by_genre) ==
               {:error,
                "the query already reads with :paginated, so it can't read with :by_genre"}
    end
  end

  describe "argument/3" do
    defp input(name, input \\ %{}) do
      {:ok, argument} =
        Engine.argument(Music.Album, :by_inputs, %Argument{name: name, input: input})

      argument.input
    end

    test "infers an input type from the argument's Ash type" do
      assert input("remastered").type == :boolean
      assert input("title").type == :text
      assert input("labels").type == :multi_select
      assert input("released_on").type == :date
      assert input("size").type == :select
    end

    test "an enum or `one_of` argument's values are its options" do
      assert input("size").options[:options] == [{"Single", :single}, {"Double", :double}]

      {:ok, argument} =
        Engine.argument(Music.Album, :by_genre, %Argument{name: "genre", input: %{}})

      assert argument.input.module == Cinder.Filters.Select
      assert length(argument.input.options[:options]) == 4
    end

    test "a declared type and options win, as with a filter" do
      assert %{type: :radio_group, module: Cinder.Filters.RadioGroup} =
               input =
               input("size", %{type: :radio_group, options: [options: [{"One", :single}]]})

      assert input.options[:options] == [{"One", :single}]
    end

    test "an argument goes by its name in the form and the URL, unless it has a `param`" do
      {:ok, genre} = Engine.argument(Music.Album, :by_genre, %Argument{name: "genre", input: %{}})
      assert genre.param == "genre"

      {:ok, genre} =
        Engine.argument(Music.Album, :by_genre, %Argument{
          name: "genre",
          param: "style",
          input: %{}
        })

      assert genre.param == "style"
    end

    test "an argument is required if it can't be nil and has no default" do
      {:ok, genre} = Engine.argument(Music.Album, :by_genre, %Argument{name: "genre", input: %{}})
      assert genre.required?

      {:ok, title} =
        Engine.argument(Music.Album, :by_inputs, %Argument{name: "title", input: %{}})

      refute title.required?
    end

    test "an argument the action doesn't have is an error" do
      assert Engine.argument(Music.Album, :read, %Argument{name: "genre", input: %{}}) ==
               {:error, ~s("genre" is not an argument of Music.Album's :read action)}
    end

    test "an unknown input type is an error naming the known ones" do
      {:error, message} =
        Engine.argument(Music.Album, :by_genre, %Argument{name: "genre", input: %{type: :nope}})

      assert message =~
               ~r/^"genre" can't be an input: :nope is not a filter type \(known: :autocomplete/
    end

    # The action's preparations have already run without the argument
    test "a query already prepared for its action can't take arguments" do
      query = Ash.Query.for_read(Music.Album, :by_genre, %{genre: :rock})

      assert Engine.argument(query, :by_genre, %Argument{name: "genre", input: %{}}) ==
               {:error,
                ~s("genre" can't be given: the query is already prepared for :by_genre, ) <>
                  "so the action has run without it. Give the action as `action` instead"}
    end
  end
end
