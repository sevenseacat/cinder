defmodule Cinder.UnqueryableColumnsTest do
  @moduledoc """
  A column asking for sorting or filtering by a field that can't support it gets neither,
  with a warning, rather than controls that fail when used. Search warns too, as the default
  search skips the column. Field notation can't pass a calculation's arguments, so
  calculations that need them can't be sorted, filtered or searched.
  """
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog
  import Phoenix.LiveViewTest, only: [render_component: 2]

  for field <- ["title_with", "artist.name_with"] do
    test "#{field}, a calculation that needs arguments, isn't sortable or filterable" do
      field = unquote(field)

      log =
        capture_log(fn ->
          [column] =
            Cinder.Collection.process_columns(
              [%{field: field, sort: true, filter: true, __slot__: :col}],
              Music.Album
            )

          refute column.sortable
          refute column.filterable
        end)

      assert log =~ "[warning]"
      assert log =~ "needs arguments (suffix)"
    end
  end

  test "sort validation rejects it before Ash does" do
    assert {:error, message} =
             Cinder.QueryBuilder.validate_sortable_fields([{"title_with", :asc}], Music.Album)

    assert message =~ "title_with (is a calculation that needs arguments (suffix))"
  end

  describe "searching" do
    defp render_search(field, search \\ nil) do
      capture_log(fn ->
        render_component(&Cinder.collection/1, %{
          id: "albums",
          resource: Music.Album,
          search: search,
          col: [%{field: field, search: true, __slot__: :col}]
        })
      end)
    end

    test "a field that doesn't exist warns" do
      log = render_search("titel")

      assert log =~ "[warning]"
      assert log =~ "Field 'titel' does not exist on Music.Album"
    end

    test "a field that can't be searched warns" do
      assert render_search("title_with") =~ "needs arguments (suffix), so it can't be searched"
    end

    test "a field that can be searched doesn't" do
      refute render_search("title") =~ "Field 'title'"
    end

    test "a custom search function can search any field" do
      refute render_search("titel", fn: fn query, _columns, _term -> query end) =~ "Field 'titel'"
    end
  end
end
