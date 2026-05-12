defmodule Cinder.PageSizeTest do
  @moduledoc """
  Tests for global default page size configuration.
  """
  use ExUnit.Case, async: false

  alias Cinder.PageSize

  setup do
    on_exit(fn -> Application.delete_env(:cinder, :default_page_size) end)
  end

  describe "get_default_page_size/0" do
    test "returns 25 when no configuration is set" do
      Application.delete_env(:cinder, :default_page_size)
      assert PageSize.get_default_page_size() == 25
    end

    test "returns configured integer value" do
      Application.put_env(:cinder, :default_page_size, 50)
      assert PageSize.get_default_page_size() == 50
    end

    test "returns configured keyword list" do
      config = [default: 100, options: [25, 50, 100, 200]]
      Application.put_env(:cinder, :default_page_size, config)
      assert PageSize.get_default_page_size() == config
    end
  end

  describe "parse/1" do
    test "parses integer value" do
      assert PageSize.parse(50) == %{
               selected_page_size: 50,
               page_size_options: [],
               default_page_size: 50,
               configurable: false
             }
    end

    test "parses keyword list with options" do
      assert PageSize.parse(default: 100, options: [50, 100, 200]) == %{
               selected_page_size: 100,
               page_size_options: [50, 100, 200],
               default_page_size: 100,
               configurable: true
             }
    end

    test "parses nil using global config" do
      Application.put_env(:cinder, :default_page_size, 75)
      assert PageSize.parse(nil).selected_page_size == 75
    end

    test "handles invalid values gracefully" do
      assert PageSize.parse("invalid").selected_page_size == 25
      assert PageSize.parse(%{bad: :data}).selected_page_size == 25
    end

    test "single option is not configurable" do
      result = PageSize.parse(default: 50, options: [50])
      assert result.configurable == false
    end
  end

  describe "validate/2" do
    test "non-configurable table ignores any requested value" do
      config = PageSize.parse(100)

      assert PageSize.validate(500, config) == 100
      assert PageSize.validate(10, config) == 100
      assert PageSize.validate(nil, config) == 100
    end

    test "configurable table accepts values in the options allow-list" do
      config = PageSize.parse(default: 25, options: [10, 25, 50, 100])

      assert PageSize.validate(10, config) == 10
      assert PageSize.validate(25, config) == 25
      assert PageSize.validate(50, config) == 50
      assert PageSize.validate(100, config) == 100
    end

    test "configurable table rejects values not in the options and falls back to default" do
      config = PageSize.parse(default: 25, options: [10, 25, 50, 100])

      assert PageSize.validate(75, config) == 25
      assert PageSize.validate(500, config) == 25
      assert PageSize.validate(0, config) == 25
      assert PageSize.validate(nil, config) == 25
    end
  end

  describe "global page size integration" do
    defp make_socket(extra_assigns \\ %{}) do
      base_assigns = %{
        __changed__: %{},
        id: "test-table",
        query: nil,
        query_opts: [],
        actor: nil,
        tenant: nil,
        col: [],
        item_slot: [],
        filter: [],
        bulk_actions: [],
        id_field: :id,
        emit_visible_ids: false,
        scope: nil,
        search_fn: nil,
        row_click: nil
      }

      %Phoenix.LiveView.Socket{assigns: Map.merge(base_assigns, extra_assigns)}
    end

    test "LiveComponent uses configured default page size" do
      Application.put_env(:cinder, :default_page_size, 50)

      {:ok, updated_socket} = Cinder.LiveComponent.update(%{id: "test"}, make_socket())

      assert updated_socket.assigns.page_size_config.selected_page_size == 50
      assert updated_socket.assigns.page_size_config.default_page_size == 50
    end

    test "LiveComponent uses configured keyword list with options" do
      Application.put_env(:cinder, :default_page_size, default: 100, options: [50, 100, 200])

      {:ok, updated_socket} = Cinder.LiveComponent.update(%{id: "test"}, make_socket())

      assert updated_socket.assigns.page_size_config.selected_page_size == 100
      assert updated_socket.assigns.page_size_config.default_page_size == 100
      assert updated_socket.assigns.page_size_config.page_size_options == [50, 100, 200]
      assert updated_socket.assigns.page_size_config.configurable == true
    end

    test "explicit page_size attribute overrides global config" do
      Application.put_env(:cinder, :default_page_size, 50)

      {:ok, updated_socket} =
        Cinder.LiveComponent.update(%{id: "test", page_size: 10}, make_socket())

      assert updated_socket.assigns.page_size_config.selected_page_size == 10
      # default_page_size should still reflect the global config
      assert updated_socket.assigns.page_size_config.default_page_size == 50
    end
  end

  describe "change_page_size event validation" do
    defp make_event_socket(page_size_config) do
      %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          id: "t",
          pagination_mode: :offset,
          page_size: page_size_config.selected_page_size,
          page_size_config: page_size_config,
          current_page: 1,
          after_keyset: nil,
          before_keyset: nil,
          on_state_change: nil
        }
      }
    end

    test "non-configurable table ignores any requested page_size" do
      config = PageSize.parse(100)
      socket = make_event_socket(config)

      {:noreply, socket} =
        Cinder.LiveComponent.handle_event("change_page_size", %{"page_size" => "500"}, socket)

      assert socket.assigns.page_size == 100
      assert socket.assigns.page_size_config.selected_page_size == 100
    end

    test "configurable table ignores values not in the allow-list" do
      config = PageSize.parse(default: 25, options: [10, 25, 50, 100])
      socket = make_event_socket(config)

      {:noreply, socket} =
        Cinder.LiveComponent.handle_event("change_page_size", %{"page_size" => "500"}, socket)

      # unchanged
      assert socket.assigns.page_size == 25
      assert socket.assigns.page_size_config.selected_page_size == 25
    end

    test "change_page_size does not crash on non-numeric input" do
      config = PageSize.parse(default: 25, options: [10, 25, 50, 100])
      socket = make_event_socket(config)

      {:noreply, socket} =
        Cinder.LiveComponent.handle_event("change_page_size", %{"page_size" => "abc"}, socket)

      # unchanged
      assert socket.assigns.page_size == 25
    end
  end

  describe "goto_page event validation" do
    defp make_goto_socket do
      %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          id: "t",
          pagination_mode: :offset,
          current_page: 1,
          on_state_change: nil
        }
      }
    end

    test "goto_page does not crash on non-numeric input" do
      socket = make_goto_socket()

      {:noreply, socket} =
        Cinder.LiveComponent.handle_event("goto_page", %{"page" => "abc"}, socket)

      # unchanged
      assert socket.assigns.current_page == 1
    end

    test "goto_page ignores zero and negative pages" do
      socket = make_goto_socket()

      {:noreply, socket} =
        Cinder.LiveComponent.handle_event("goto_page", %{"page" => "0"}, socket)

      assert socket.assigns.current_page == 1

      {:noreply, socket} =
        Cinder.LiveComponent.handle_event("goto_page", %{"page" => "-5"}, socket)

      assert socket.assigns.current_page == 1
    end
  end
end
