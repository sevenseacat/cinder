defmodule Cinder.Integration.SelectionFilterClearTest do
  use ExUnit.Case, async: false
  alias Cinder.LiveComponent
  alias Cinder.Support.SearchTestResource

  setup {Cinder.TestHelpers, :disable_async_loading}

  for kind <- [:search, :filter, :all_filters] do
    test "clearing #{kind} drops query-wide selection before the scope expands" do
      assert_clear(unquote(kind))
    end
  end

  defp assert_clear(kind) do
    for title <- ["First", "Second"] do
      SearchTestResource
      |> Ash.Changeset.for_create(:create, %{title: title})
      |> Ash.create!(authorize?: false)
    end

    column = %{
      field: "title",
      searchable: true,
      filterable: true,
      filter_fn: fn q, config -> Ash.Query.filter_input(q, %{title: config.value}) end
    }

    {:ok, socket} =
      LiveComponent.update(
        %{
          id: "scope-clear",
          query: SearchTestResource,
          actor: nil,
          tenant: nil,
          query_opts: [authorize?: false],
          col: [],
          query_columns: [column],
          selectable: true,
          on_selection_change: :selection_changed,
          search_term: if(kind == :search, do: "First", else: ""),
          search_fn: fn q, _, term -> Ash.Query.filter_input(q, %{title: term}) end,
          filters: if(kind == :search, do: %{}, else: %{"title" => %{value: "First"}})
        },
        %Phoenix.LiveView.Socket{}
      )

    assert Enum.map(socket.assigns.data, & &1.title) == ["First"]
    {:noreply, socket} = LiveComponent.handle_event("toggle_select_all", %{}, socket)
    assert_receive {:selection_changed, %{selection_mode: :all_matching}}

    {event, params} =
      case kind do
        :search -> {"clear_filter", %{"key" => "search"}}
        :filter -> {"clear_filter", %{"key" => "title"}}
        :all_filters -> {"clear_all_filters", %{}}
      end

    {:noreply, socket} = LiveComponent.handle_event(event, params, socket)

    assert length(socket.assigns.data) == 2
    assert socket.assigns.selection_mode == :explicit
    assert socket.assigns.selected_ids == MapSet.new()
    assert_receive {:selection_changed, %{selected_count: 0, action: :clear}}
  end
end
