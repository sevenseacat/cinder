defmodule Cinder.Next.ComponentTest do
  @moduledoc "Clicking through a mounted `Cinder.Next.collection`."
  use Cinder.ConnCase, async: false

  import Phoenix.ConnTest, only: [get: 2]

  import Phoenix.LiveViewTest,
    only: [
      live: 2,
      render_async: 1,
      render_change: 2,
      render_click: 1,
      render_click: 3,
      render_hook: 3,
      with_target: 2,
      element: 2
    ]

  setup do
    artist = generate(artist(name: "Next Artist"))

    for {title, genre} <- [
          {"Alpha", :rock},
          {"Bravo", :jazz},
          {"Charlie", :rock},
          {"Delta", :jazz},
          {"Echo", :pop}
        ] do
      generate(album(title: title, genre: genre, artist_id: artist.id))
    end

    on_exit(fn ->
      Ash.bulk_destroy!(Music.Album, :destroy, %{})
      Ash.bulk_destroy!(Music.Artist, :destroy, %{})
    end)

    path =
      Cinder.TestLive.Fixture.register(fn assigns ->
        ~H"""
        <Cinder.Next.collection id="albums" resource={Music.Album} page_size={2}>
          <:col :let={album} field="title" filter search sort>{album.title}</:col>
          <:col field="genre" filter />
        </Cinder.Next.collection>
        """
      end)

    %{path: path}
  end

  defp titles(html), do: Regex.scan(~r/Alpha|Bravo|Charlie|Delta|Echo/, html) |> List.flatten()

  defp click(view, selector) do
    view |> element(selector) |> render_click()
    render_async(view)
  end

  test "sorting cycles through ascending and descending", %{conn: conn, path: path} do
    {:ok, view, _html} = live(conn, path)
    render_async(view)

    assert titles(click(view, ~s(.cinder-sort[phx-value-field="title"]))) == [
             "Alpha",
             "Bravo"
           ]

    assert titles(click(view, ~s(.cinder-sort[phx-value-field="title"]))) == [
             "Echo",
             "Delta"
           ]
  end

  test "the default components mark what they render with cinder-* classes", %{
    conn: conn,
    path: path
  } do
    {:ok, view, _html} = live(conn, path)
    html = render_async(view)

    for part <- ~w(table row cell pagination toolbar) do
      assert html =~ ~r/class="cinder-#{part}[" ]/, "no cinder-#{part}"
    end
  end

  # Regression: raw filter params are stored and rendered back, so a map or list
  # where a string belongs crashed the render, as did a non-string page or field
  test "odd client params are ignored rather than crashing the view", %{conn: conn, path: path} do
    {:ok, view, _html} = live(conn, path)
    render_async(view)
    target = with_target(view, "#albums")

    render_click(target, "filter", %{
      "filters" => %{"title" => %{"nested" => "map"}, "genre" => [1, 2], "nope" => "x"},
      "search" => %{"not" => "a string"}
    })

    render_click(target, "go_to_page", %{"page" => 3})
    render_click(target, "clear_filter", %{"field" => %{"x" => 1}})

    assert length(titles(render_async(view))) == 2
  end

  test "paging moves through the sorted records", %{conn: conn, path: path} do
    {:ok, view, _html} = live(conn, path)
    render_async(view)
    click(view, ~s(.cinder-sort[phx-value-field="title"]))

    assert titles(click(view, ~s(.cinder-page[data-kind="page"][phx-value-page="2"]))) ==
             ["Charlie", "Delta"]

    assert titles(click(view, ~s(.cinder-page[data-kind="next"]))) == ["Echo"]

    html = click(view, ~s(.cinder-page[data-kind="prev"]))
    assert titles(html) == ["Charlie", "Delta"]
    assert html =~ "showing 3-4 of 5"
  end

  test "sorting goes back to the first page", %{conn: conn, path: path} do
    {:ok, view, _html} = live(conn, path)
    render_async(view)
    click(view, ~s(.cinder-sort[phx-value-field="title"]))
    click(view, ~s(.cinder-page[data-kind="next"]))

    html = click(view, ~s(.cinder-sort[phx-value-field="title"]))

    assert titles(html) == ["Echo", "Delta"]
    assert html =~ "showing 1-2 of 5"
  end

  defp change(view, params) do
    view |> element("#albums-filters") |> render_change(params)
    render_async(view)
  end

  test "a text filter narrows the records", %{conn: conn, path: path} do
    {:ok, view, _html} = live(conn, path)
    render_async(view)

    html = change(view, %{"filters" => %{"title" => "ha", "genre" => ""}})

    assert Enum.sort(titles(html)) == ["Alpha", "Charlie"]
    assert html =~ ~s(data-active)
  end

  test "the select filter lists the enum's values and marks the chosen one", %{
    conn: conn,
    path: path
  } do
    {:ok, view, _html} = live(conn, path)
    render_async(view)

    html = change(view, %{"filters" => %{"title" => "", "genre" => "jazz"}})

    assert Enum.sort(titles(html)) == ["Bravo", "Delta"]
    assert html =~ ~r/<option(?=[^>]*value="jazz")[^>]*selected/
    assert html =~ ~r/<option[^>]*value="rock"/
  end

  test "search narrows the records", %{conn: conn, path: path} do
    {:ok, view, _html} = live(conn, path)
    render_async(view)

    assert titles(change(view, %{"search" => "echo"})) == ["Echo"]

    html = click(view, ~s(.cinder-search-clear))
    assert html =~ "showing 1-2 of 5"
    assert html =~ ~r/<button[^>]*class="cinder-search-clear"[^>]*hidden/
  end

  test "clear all resets filters and search together", %{conn: conn, path: path} do
    {:ok, view, _html} = live(conn, path)
    render_async(view)
    html = change(view, %{"filters" => %{"title" => "a", "genre" => "rock"}, "search" => "alpha"})
    assert titles(html) == ["Alpha"]

    # Clear all isn't in the default layout, so send its event as a custom layout's button would
    view |> with_target("#albums") |> render_hook("clear_all", %{})
    html = render_async(view)

    assert html =~ "showing 1-2 of 5"
    refute html =~ ~s(value="alpha")
  end

  test "clearing a filter brings the records back", %{conn: conn, path: path} do
    {:ok, view, _html} = live(conn, path)
    render_async(view)
    change(view, %{"filters" => %{"title" => "", "genre" => "pop"}})

    html = click(view, ~s(.cinder-filter-clear[phx-value-field="genre"]))

    assert length(titles(html)) == 2
    assert html =~ "showing 1-2 of 5"
  end

  test "a custom pagination slot replaces the default and works through the attribute maps",
       %{conn: conn} do
    path =
      Cinder.TestLive.Fixture.register(fn assigns ->
        ~H"""
        <Cinder.Next.collection id="albums" resource={Music.Album} page_size={2}>
          <:col :let={album} field="title" sort>{album.title}</:col>
          <:pagination :let={c}>
            <ol id="custom-pagination">
              <li :for={page <- c.pagination.pages}>
                <a :if={page.kind == :page} {page.attrs}>Page {page.label}</a>
              </li>
            </ol>
          </:pagination>
        </Cinder.Next.collection>
        """
      end)

    {:ok, view, _html} = live(conn, path)
    html = render_async(view)

    assert html =~ ~s(id="custom-pagination")
    refute html =~ ~s(class="cinder-summary")

    click(view, ~s(.cinder-sort[phx-value-field="title"]))
    html = click(view, ~s(#custom-pagination [phx-value-page="3"]))

    assert titles(html) == ["Echo"]
  end

  # For components like Petal's table, which take a command per column, not attrs
  test "sort_command/2 sorts like a sortable header", %{conn: conn} do
    path =
      Cinder.TestLive.Fixture.register(fn assigns ->
        ~H"""
        <Cinder.Next.collection id="albums" resource={Music.Album} page_size={2}>
          <:sort field="title" />
          <:page :let={c}>
            <button id="by-title" phx-click={Cinder.Next.sort_command(c, "title")}>Title</button>
            <p :for={row <- c.rows}>{row.record.title}</p>
          </:page>
        </Cinder.Next.collection>
        """
      end)

    {:ok, view, _html} = live(conn, path)
    render_async(view)

    assert titles(click(view, "#by-title")) == ["Alpha", "Bravo"]
    assert titles(click(view, "#by-title")) == ["Echo", "Delta"]
  end

  test "a filter can be placed by field, with the markup from its <:filter>", %{conn: conn} do
    path =
      Cinder.TestLive.Fixture.register(fn assigns ->
        ~H"""
        <Cinder.Next.collection id="albums" resource={Music.Album}>
          <:filter :let={f} field="genre">
            <select id="custom-genre" {f.input_attrs}>
              <option :for={option <- f.options} {option.attrs}>{option.label}</option>
            </select>
          </:filter>
          <:filter field="title" />
          <:page :let={c}>
            <form {c.form_attrs}>
              <div id="top"><Cinder.Next.filter collection={c} field="genre" /></div>
              <div id="bottom"><Cinder.Next.filter collection={c} field="title" /></div>
            </form>
            <p :for={row <- c.rows}>{row.record.title}</p>
          </:page>
        </Cinder.Next.collection>
        """
      end)

    {:ok, view, _html} = live(conn, path)
    html = render_async(view)

    assert html =~ ~r/id="top">\s*<select id="custom-genre"/
    assert html =~ ~r/id="bottom">.*name="filters\[title\]"/s

    view |> element("#albums-filters") |> render_change(%{"filters" => %{"genre" => "pop"}})
    assert titles(render_async(view)) == ["Echo"]
  end

  test "placing a filter for a field that wasn't declared is an error" do
    collection = %{filters: Cinder.Next.Filters.new([])}

    assert_raise ArgumentError, ~r/no filter is declared for "genre"/, fn ->
      Phoenix.LiveViewTest.render_component(&Cinder.Next.filter/1,
        collection: collection,
        field: "genre"
      )
    end
  end

  test "a <:filter> with content replaces that filter's markup, and keeps its wiring",
       %{conn: conn} do
    path =
      Cinder.TestLive.Fixture.register(fn assigns ->
        ~H"""
        <Cinder.Next.collection id="albums" resource={Music.Album} page_size={5}>
          <:col :let={album} field="title">{album.title}</:col>
          <:filter :let={f} field="genre" help="One genre at a time">
            <fieldset id="custom-genre">
              <legend>{f.label} <abbr title={f.help}>(?)</abbr></legend>
              <select {f.input_attrs}>
                <option :for={option <- f.options} {option.attrs}>{option.label}</option>
              </select>
            </fieldset>
          </:filter>
        </Cinder.Next.collection>
        """
      end)

    {:ok, view, _html} = live(conn, path)
    html = render_async(view)

    assert html =~ ~s(id="custom-genre")
    assert html =~ ~s(title="One genre at a time")
    refute html =~ ~s(class="cinder-filter-help")

    view |> element("#albums-filters") |> render_change(%{"filters" => %{"genre" => "pop"}})

    assert titles(render_async(view)) == ["Echo"]
  end

  describe "grid layout" do
    setup do
      path =
        Cinder.TestLive.Fixture.register(fn assigns ->
          ~H"""
          <Cinder.Next.collection id="albums" resource={Music.Album} layout="grid" page_size={5}>
            <:filter field="genre" />
            <:sort field="title" />
            <:item :let={album}><h3>{album.title}</h3></:item>
          </Cinder.Next.collection>
          """
        end)

      %{grid_path: path}
    end

    test "renders cards from <:item>, with no columns declared", %{conn: conn, grid_path: path} do
      {:ok, view, _html} = live(conn, path)
      html = render_async(view)

      assert length(Regex.scan(~r/class="cinder-item"/, html)) == 5
      refute html =~ "<table"
    end

    test "sorts through the dropdown, alongside filtering", %{conn: conn, grid_path: path} do
      {:ok, view, _html} = live(conn, path)
      render_async(view)

      html = change(view, %{"filters" => %{"genre" => ""}, "sort_by" => "-title"})
      assert titles(html) == ["Echo", "Delta", "Charlie", "Bravo", "Alpha"]
      assert html =~ ~r/<option(?=[^>]*value="-title")[^>]*selected/

      html = change(view, %{"filters" => %{"genre" => "rock"}, "sort_by" => "title"})
      assert titles(html) == ["Alpha", "Charlie"]
    end

    test "ignores a sort that wasn't declared", %{conn: conn, grid_path: path} do
      {:ok, view, _html} = live(conn, path)
      render_async(view)

      html = change(view, %{"filters" => %{"genre" => ""}, "sort_by" => "-price"})
      refute html =~ ~r/<option[^>]*selected[^>]*value="-price"/
    end
  end
end
