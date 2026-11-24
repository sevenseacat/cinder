defmodule Cinder.DeprecationsTest do
  @moduledoc """
  Everything removed in 1.0 that has a replacement today warns when an app compiles a call
  to it.
  """
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO
  import Cinder.TestHelpers, only: [compile_and_unload: 1]

  @deprecated_calls [
    "Cinder.Filters.Registry.register_filter/2",
    "Cinder.UrlManager.decode_sort/1",
    "Cinder.UrlManager.validate_url_params/1",
    "Cinder.Theme.validate/1",
    "Cinder.Theme.valid_property?/1",
    "Cinder.Messages.gettext_backend/0",
    "Cinder.QueryBuilder.validate_field_existence/2"
  ]

  test "compiling a call to anything deprecated warns" do
    warnings =
      capture_io(:stderr, fn ->
        compile_and_unload("""
        defmodule Cinder.DeprecationsTest.App do
          def calls do
            Cinder.Filters.Registry.register_filter(:x, String)
            Cinder.UrlManager.decode_sort("title")
            Cinder.UrlManager.validate_url_params(%{})
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

  test "a theme's component/2 block warns" do
    warnings =
      capture_io(:stderr, fn ->
        compile_and_unload("""
        defmodule Cinder.DeprecationsTest.Theme do
          use Cinder.Theme

          component Cinder.Components.Table do
            set :container_class, "my-table"
          end
        end
        """)
      end)

    assert warnings =~ "component/2 is deprecated in Cinder themes and will be removed in 1.0"
  end
end
