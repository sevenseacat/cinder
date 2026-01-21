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
end
