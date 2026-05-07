defmodule Cinder.ColumnPreferencesLiveComponentTest do
  @moduledoc """
  Integration tests for column-preferences events on the LiveComponent.
  """

  use ExUnit.Case, async: true

  alias Cinder.{ColumnPreferences, LiveComponent}

  defp col(field, opts \\ []) do
    %{
      field: field,
      label: field,
      hideable: Keyword.get(opts, :hideable, true),
      reorderable: Keyword.get(opts, :reorderable, true),
      default_visible: Keyword.get(opts, :default_visible, true),
      filterable: false,
      sortable: false,
      class: ""
    }
  end

  defp make_socket(opts) do
    declared = Keyword.fetch!(opts, :columns)

    assigns =
      %{
        __changed__: %{},
        id: Keyword.get(opts, :id, "test-table"),
        col: declared,
        declared_columns: declared,
        columns: declared,
        column_preferences?: Keyword.get(opts, :column_preferences?, true),
        column_preferences:
          Keyword.get(opts, :column_preferences, ColumnPreferences.from_columns(declared)),
        on_columns_change: Keyword.get(opts, :on_columns_change, nil),
        column_prefs_drawer_open?: false,
        column_prefs_hydrated?: Keyword.get(opts, :column_prefs_hydrated?, false),
        query_columns: declared,
        filter_field_names: []
      }

    %Phoenix.LiveView.Socket{assigns: assigns, root_pid: self()}
  end

  describe "toggle_column_visibility" do
    test "hides a previously visible hideable column" do
      cols = [col("a"), col("b"), col("c")]
      socket = make_socket(columns: cols)

      {:noreply, socket} =
        LiveComponent.handle_event("toggle_column_visibility", %{"field" => "b"}, socket)

      assert MapSet.member?(socket.assigns.column_preferences.hidden, "b")
      assert Enum.map(socket.assigns.columns, & &1.field) == ["a", "c"]
    end

    test "refuses to hide a non-hideable column" do
      cols = [col("a", hideable: false), col("b")]
      socket = make_socket(columns: cols)

      {:noreply, socket} =
        LiveComponent.handle_event("toggle_column_visibility", %{"field" => "a"}, socket)

      assert socket.assigns.column_preferences.hidden == MapSet.new()
      assert Enum.map(socket.assigns.columns, & &1.field) == ["a", "b"]
    end
  end

  describe "reorder_columns" do
    test "applies new order to reorderable columns" do
      cols = [col("a"), col("b"), col("c")]
      socket = make_socket(columns: cols)

      {:noreply, socket} =
        LiveComponent.handle_event("reorder_columns", %{"order" => ["c", "a", "b"]}, socket)

      assert socket.assigns.column_preferences.order == ["c", "a", "b"]
      assert Enum.map(socket.assigns.columns, & &1.field) == ["c", "a", "b"]
    end

    test "preserves pinned column positions" do
      cols = [col("a"), col("b", reorderable: false), col("c"), col("d")]
      socket = make_socket(columns: cols)

      {:noreply, socket} =
        LiveComponent.handle_event("reorder_columns", %{"order" => ["d", "c", "a"]}, socket)

      assert Enum.map(socket.assigns.columns, & &1.field) == ["d", "b", "c", "a"]
    end

    test "drawer column list mirrors the user's order, with hidden cols at end" do
      cols = [col("a"), col("b"), col("c"), col("d")]

      socket =
        make_socket(
          columns: cols,
          column_preferences: %{order: nil, hidden: MapSet.new(["c"])}
        )

      {:noreply, socket} =
        LiveComponent.handle_event("reorder_columns", %{"order" => ["d", "a", "b"]}, socket)

      drawer_fields = Enum.map(socket.assigns.prefs_drawer_columns, & &1.field)
      assert drawer_fields == ["d", "a", "b", "c"]
    end
  end

  describe "reset_column_preferences" do
    test "restores defaults" do
      cols = [col("a"), col("b"), col("c", default_visible: false)]

      socket =
        make_socket(
          columns: cols,
          column_preferences: %{order: ["b", "a"], hidden: MapSet.new(["a"])}
        )

      {:noreply, socket} =
        LiveComponent.handle_event("reset_column_preferences", %{}, socket)

      assert socket.assigns.column_preferences == %{order: nil, hidden: MapSet.new(["c"])}
      assert Enum.map(socket.assigns.columns, & &1.field) == ["a", "b"]
    end
  end

  describe "apply_column_preferences (client hydration)" do
    test "applies payload from localStorage without firing on_columns_change" do
      cols = [col("a"), col("b"), col("c")]
      socket = make_socket(columns: cols, on_columns_change: :columns_changed)

      payload = %{"order" => ["c", "b", "a"], "hidden" => ["b"]}

      {:noreply, socket} =
        LiveComponent.handle_event("apply_column_preferences", payload, socket)

      assert socket.assigns.column_preferences.order == ["c", "b", "a"]
      assert socket.assigns.column_preferences.hidden == MapSet.new(["b"])
      assert Enum.map(socket.assigns.columns, & &1.field) == ["c", "a"]

      refute_received {:columns_changed, _}
    end

    test "marks the table as hydrated even when the payload is empty" do
      cols = [col("a"), col("b")]
      socket = make_socket(columns: cols)
      refute socket.assigns.column_prefs_hydrated?

      {:noreply, socket} =
        LiveComponent.handle_event("apply_column_preferences", %{}, socket)

      assert socket.assigns.column_prefs_hydrated?
    end

    test "is idempotent — replaying the same push leaves state coherent" do
      cols = [col("a"), col("b"), col("c")]
      socket = make_socket(columns: cols)
      payload = %{"order" => ["b", "a", "c"], "hidden" => ["c"]}

      {:noreply, socket} =
        LiveComponent.handle_event("apply_column_preferences", payload, socket)

      first_visible = Enum.map(socket.assigns.columns, & &1.field)
      first_drawer = Enum.map(socket.assigns.prefs_drawer_columns, & &1.field)

      {:noreply, socket} =
        LiveComponent.handle_event("apply_column_preferences", payload, socket)

      assert Enum.map(socket.assigns.columns, & &1.field) == first_visible
      assert Enum.map(socket.assigns.prefs_drawer_columns, & &1.field) == first_drawer
      assert socket.assigns.column_prefs_hydrated?
    end
  end

  describe "force-hydrate fallback" do
    test "force-hydrate update flips hydrated when prefs hadn't been applied yet" do
      cols = [col("a"), col("b")]
      socket = make_socket(columns: cols)
      refute socket.assigns.column_prefs_hydrated?

      {:ok, socket} = LiveComponent.update(%{__force_hydrate__: true}, socket)

      assert socket.assigns.column_prefs_hydrated?
      assert Enum.map(socket.assigns.columns, & &1.field) == ["a", "b"]
    end

    test "force-hydrate update is a no-op when already hydrated" do
      cols = [col("a"), col("b")]
      socket = make_socket(columns: cols, column_prefs_hydrated?: true)

      {:ok, socket} = LiveComponent.update(%{__force_hydrate__: true}, socket)

      assert socket.assigns.column_prefs_hydrated?
    end

    test "force-hydrate update is a no-op when prefs feature is disabled" do
      cols = [col("a"), col("b")]
      socket = make_socket(columns: cols, column_preferences?: false)

      {:ok, socket} = LiveComponent.update(%{__force_hydrate__: true}, socket)

      refute socket.assigns.column_prefs_hydrated?
    end
  end

  describe "on_columns_change callback" do
    test "fires after a user edit with payload shape {prefs, id}" do
      cols = [col("a"), col("b")]
      socket = make_socket(columns: cols, on_columns_change: :columns_changed)

      {:noreply, _socket} =
        LiveComponent.handle_event("toggle_column_visibility", %{"field" => "a"}, socket)

      assert_received {:columns_changed, %{prefs: prefs, id: "test-table"}}
      assert prefs.hidden == ["a"]
      assert prefs.order == nil
    end

    test "does not fire when on_columns_change is nil" do
      cols = [col("a"), col("b")]
      socket = make_socket(columns: cols, on_columns_change: nil)

      {:noreply, _socket} =
        LiveComponent.handle_event("reorder_columns", %{"order" => ["b", "a"]}, socket)

      refute_received {_, _}
    end
  end

  describe "toggle_column_prefs_drawer" do
    test "flips the drawer open/closed flag" do
      cols = [col("a")]
      socket = make_socket(columns: cols)

      {:noreply, socket} =
        LiveComponent.handle_event("toggle_column_prefs_drawer", %{}, socket)

      assert socket.assigns.column_prefs_drawer_open? == true

      {:noreply, socket} =
        LiveComponent.handle_event("toggle_column_prefs_drawer", %{}, socket)

      assert socket.assigns.column_prefs_drawer_open? == false
    end
  end
end
