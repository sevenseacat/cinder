defmodule Cinder.Next.CollectionTest do
  @moduledoc "The collection core: events in, the new collection and its effects out."
  use ExUnit.Case, async: true

  alias Cinder.Next.{Collection, Config}

  defp new(url_params \\ nil) do
    config =
      Config.build(%{
        id: "albums",
        resource: Music.Album,
        query: nil,
        col: [%{field: "title", sort: true, inner_block: nil}],
        item: [%{__slot__: :item, inner_block: nil}]
      })

    Collection.new("albums", config, url_params)
  end

  test "a new collection loads" do
    assert {%Collection{status: :loading}, [:load]} = new()
  end

  test "without the URL, a query change loads straight away" do
    {collection, _} = new()

    assert {%{state: %{sort: [{"title", :asc}]}}, [:load]} =
             Collection.handle_event(collection, "sort", %{"field" => "title"})
  end

  test "with the URL, a change only patches it; the state follows when it comes back" do
    {collection, _} = new(%{})

    assert {unchanged, [{:url, %{sort: "title"} = params}]} =
             Collection.handle_event(collection, "sort", %{"field" => "title"})

    assert unchanged.state.sort == []

    url_params = Map.new(params, fn {key, value} -> {to_string(key), value} end)

    assert {%{state: %{sort: [{"title", :asc}]}}, [:load]} =
             Collection.apply_url(unchanged, url_params)
  end

  test "changes outside the query don't load: a layout switch only touches the URL" do
    {collection, _} = new()

    assert {%{state: %{layout: :grid}}, []} =
             Collection.handle_event(collection, "set_layout", %{"layout" => "grid"})

    {synced, _} = new(%{})

    assert {_, [{:url, %{layout: :grid}}]} =
             Collection.handle_event(synced, "set_layout", %{"layout" => "grid"})
  end

  # Regression: the engine also fails with plain strings ("Cannot sort by..."),
  # which crashed the error handling
  test "a load failing with a string reason is an error, not a crash" do
    {collection, _} = new()

    assert %{status: :error, page: nil} =
             Collection.loaded(collection, {:error, "Cannot sort by computed field"})
  end

  test "an event it doesn't know, or for a field that isn't sortable, does nothing" do
    {collection, _} = new()

    assert {^collection, []} = Collection.handle_event(collection, "drop_tables", %{})
    assert {^collection, []} = Collection.handle_event(collection, "sort", %{"field" => "genre"})
  end
end
