defmodule Cinder.DeprecationsTest do
  @moduledoc """
  Everything removed in 1.0 that has a replacement today warns when an app compiles a call
  to it, HEEx component calls included.
  """
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @deprecated_calls [
    "Cinder.Table.table/1",
    "Cinder.Table.process_columns/2",
    "Cinder.Table.process_filter_slots/2",
    "Cinder.Table.build_query_columns/2",
    "Cinder.Table.merge_filter_configurations/2",
    "Cinder.Table.process_search_config/2",
    "Cinder.Table.Refresh.refresh_table/2",
    "Cinder.Table.Refresh.refresh_tables/2",
    "Cinder.Table.UrlSync.handle_params/3",
    "Cinder.Collection.merge_filter_configurations/2",
    "Cinder.setup/0",
    "Cinder.Filters.Registry.register_filter/2",
    "Cinder.UrlManager.decode_sort/1",
    "Cinder.UrlManager.validate_url_params/1",
    "Cinder.UrlSync.extract_table_state/1",
    "Cinder.Theme.validate/1",
    "Cinder.Theme.valid_property?/1",
    "Cinder.Messages.gettext_backend/0",
    "Cinder.QueryBuilder.validate_field_existence/2"
  ]

  test "compiling a call to anything deprecated warns" do
    warnings =
      capture_io(:stderr, fn ->
        Code.compile_string("""
        defmodule Cinder.DeprecationsTest.App do
          use Phoenix.Component

          def render(assigns) do
            ~H\"\"\"
            <Cinder.Table.table resource={Music.Album}><:col field="title" /></Cinder.Table.table>
            \"\"\"
          end

          def calls(socket) do
            Cinder.Table.process_columns([], Music.Album)
            Cinder.Table.process_filter_slots([], Music.Album)
            Cinder.Table.build_query_columns([], [])
            Cinder.Table.merge_filter_configurations([], [])
            Cinder.Table.process_search_config(nil, [])
            Cinder.Table.Refresh.refresh_table(socket, "id")
            Cinder.Table.Refresh.refresh_tables(socket, ["id"])
            Cinder.Table.UrlSync.handle_params(%{}, nil, socket)
            Cinder.Collection.merge_filter_configurations([], [])
            Cinder.setup()
            Cinder.Filters.Registry.register_filter(:x, String)
            Cinder.UrlManager.decode_sort("title")
            Cinder.UrlManager.validate_url_params(%{})
            Cinder.UrlSync.extract_table_state(%{})
            Cinder.Theme.validate("modern")
            Cinder.Theme.valid_property?(:container_class)
            Cinder.Messages.gettext_backend()
            Cinder.QueryBuilder.validate_field_existence(Music.Album, "title")
          end
        end
        """)
      end)

    missing = Enum.reject(@deprecated_calls, &(warnings =~ "#{&1} is deprecated"))
    assert missing == []
  end
end
