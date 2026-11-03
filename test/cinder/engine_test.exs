defmodule Cinder.EngineTest do
  use ExUnit.Case, async: true

  alias Cinder.Engine
  alias Cinder.Engine.Field

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
end
