defmodule Cinder.UnqueryableColumnsTest do
  @moduledoc """
  A column asking for sorting or filtering by a field that can't support it gets neither,
  with a warning, rather than controls that fail when used. Field notation can't pass a
  calculation's arguments, so calculations that need them can't be sorted or filtered.
  """
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

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
end
