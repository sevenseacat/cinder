defmodule Cinder.Integration.SortModeTest do
  use Cinder.ConnCase, async: false

  import ExUnit.CaptureIO
  import Phoenix.ConnTest, only: [get: 2]
  import Phoenix.LiveViewTest, only: [live: 2, element: 2, render_click: 1, assert_patch: 1]

  defp sorted_after_clicking_title_then_price(conn, sort_mode) do
    path =
      Cinder.TestLive.Fixture.register(fn assigns ->
        assigns = assign(assigns, :sort_mode, sort_mode)

        ~H"""
        <Cinder.collection resource={Music.Album} url_state={@url_state} sort_mode={@sort_mode}>
          <:col :let={album} field="title" sort>{album.title}</:col>
          <:col :let={album} field="price" sort>{album.price}</:col>
        </Cinder.collection>
        """
      end)

    {:ok, view, _html} = live(conn, path)

    url =
      for field <- ["title", "price"], reduce: nil do
        _ ->
          view |> element("[phx-click=toggle_sort][phx-value-key=#{field}]") |> render_click()
          assert_patch(view)
      end

    url |> URI.parse() |> Map.get(:query) |> URI.decode_query()
  end

  test "exclusive sorting replaces the existing sort, as a string or an atom", %{conn: conn} do
    for sort_mode <- ["exclusive", :exclusive] do
      assert %{"sort" => "price"} = sorted_after_clicking_title_then_price(conn, sort_mode)
    end
  end

  test "sorting adds to the existing sort by default", %{conn: conn} do
    %{"sort" => sort} = sorted_after_clicking_title_then_price(conn, nil)
    assert sort |> String.split(",") |> Enum.sort() == ["price", "title"]
  end

  test "sort_mode is a declared attribute, so calling the component directly doesn't warn" do
    warnings =
      capture_io(:stderr, fn ->
        Code.compile_string("""
        defmodule Cinder.Integration.SortModeTest.DirectCall do
          use Phoenix.Component

          def render(assigns) do
            ~H\"\"\"
            <Cinder.Collection.collection resource={Music.Album} sort_mode="exclusive">
              <:col field="title" sort />
            </Cinder.Collection.collection>
            \"\"\"
          end
        end
        """)
      end)

    assert warnings == ""
  end
end
