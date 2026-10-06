defmodule Cinder.Renderers.BulkActionsTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  alias Cinder.Renderers.BulkActions

  @theme %{
    bulk_actions_container_class: "flex gap-2",
    button_class: "btn",
    button_primary_class: "btn-primary",
    button_secondary_class: "btn-outline",
    button_danger_class: "btn-danger",
    button_disabled_class: "btn-disabled"
  }

  describe "declarative API with label attribute" do
    test "renders themed button when label is provided" do
      assigns = %{
        selectable: true,
        selected_ids: MapSet.new(["1", "2"]),
        bulk_action_slots: [
          %{action: :test_action, label: "Test Action ({count})", variant: :primary}
        ],
        theme: @theme,
        myself: %Phoenix.LiveComponent.CID{cid: 1}
      }

      html = render_component(&BulkActions.render/1, assigns)

      assert html =~ "Test Action (2)"
      assert html =~ "btn btn-primary"
      refute html =~ "btn-disabled"
    end

    test "renders primary variant by default" do
      assigns = %{
        selectable: true,
        selected_ids: MapSet.new(["1"]),
        bulk_action_slots: [
          %{action: :test_action, label: "Action"}
        ],
        theme: @theme,
        myself: %Phoenix.LiveComponent.CID{cid: 1}
      }

      html = render_component(&BulkActions.render/1, assigns)

      assert html =~ "btn-primary"
    end

    test "renders secondary variant" do
      assigns = %{
        selectable: true,
        selected_ids: MapSet.new(["1"]),
        bulk_action_slots: [
          %{action: :test_action, label: "Action", variant: :secondary}
        ],
        theme: @theme,
        myself: %Phoenix.LiveComponent.CID{cid: 1}
      }

      html = render_component(&BulkActions.render/1, assigns)

      assert html =~ "btn-outline"
    end

    test "renders danger variant" do
      assigns = %{
        selectable: true,
        selected_ids: MapSet.new(["1"]),
        bulk_action_slots: [
          %{action: :test_action, label: "Delete", variant: :danger}
        ],
        theme: @theme,
        myself: %Phoenix.LiveComponent.CID{cid: 1}
      }

      html = render_component(&BulkActions.render/1, assigns)

      assert html =~ "btn-danger"
    end

    test "adds disabled class when no items selected" do
      assigns = %{
        selectable: true,
        selected_ids: MapSet.new(),
        bulk_action_slots: [
          %{action: :test_action, label: "Action", variant: :primary}
        ],
        theme: @theme,
        myself: %Phoenix.LiveComponent.CID{cid: 1}
      }

      html = render_component(&BulkActions.render/1, assigns)

      assert html =~ "btn-disabled"
      assert html =~ "disabled"
    end

    test "interpolates {count} in label" do
      assigns = %{
        selectable: true,
        selected_ids: MapSet.new(["a", "b", "c"]),
        bulk_action_slots: [
          %{action: :test_action, label: "Process {count} items"}
        ],
        theme: @theme,
        myself: %Phoenix.LiveComponent.CID{cid: 1}
      }

      html = render_component(&BulkActions.render/1, assigns)

      assert html =~ "Process 3 items"
    end
  end

  describe "custom content fallback" do
    test "renders slot content when no label provided" do
      assigns = %{
        selectable: true,
        selected_ids: MapSet.new(["1"]),
        bulk_action_slots: [
          %{
            action: :test_action,
            inner_block: fn _assigns, _arg -> "Custom Button Content" end
          }
        ],
        theme: @theme,
        myself: %Phoenix.LiveComponent.CID{cid: 1}
      }

      html = render_component(&BulkActions.render/1, assigns)

      # Should not render themed button classes
      refute html =~ "btn-primary"
    end

    test "lets custom slot confirmation content own the preparation click" do
      assigns = %{
        selectable: true,
        selected_ids: MapSet.new(["1"]),
        bulk_action_slots: [
          %{
            action: :delete,
            confirmation: :slot,
            inner_block: fn _assigns, context ->
              "prepare=#{not is_nil(context.prepare)}"
            end
          }
        ],
        theme: @theme,
        myself: %Phoenix.LiveComponent.CID{cid: 1}
      }

      html = render_component(&BulkActions.render/1, assigns)

      assert html =~ "prepare=true"
      refute html =~ "phx-click="
      refute html =~ "data-confirm="
    end
  end

  describe "render conditions" do
    test "returns empty when selectable is false" do
      assigns = %{
        selectable: false,
        selected_ids: MapSet.new(["1"]),
        bulk_action_slots: [%{action: :test, label: "Test"}],
        theme: @theme,
        myself: %Phoenix.LiveComponent.CID{cid: 1}
      }

      html = render_component(&BulkActions.render/1, assigns)

      assert html == ""
    end

    test "returns empty when no bulk action slots" do
      assigns = %{
        selectable: true,
        selected_ids: MapSet.new(["1"]),
        bulk_action_slots: [],
        theme: @theme,
        myself: %Phoenix.LiveComponent.CID{cid: 1}
      }

      html = render_component(&BulkActions.render/1, assigns)

      assert html == ""
    end
  end

  describe "confirm message" do
    test "interpolates {count} in confirm message" do
      assigns = %{
        selectable: true,
        selected_ids: MapSet.new(["1", "2"]),
        bulk_action_slots: [
          %{action: :delete, label: "Delete", confirm: "Delete {count} items?"}
        ],
        theme: @theme,
        myself: %Phoenix.LiveComponent.CID{cid: 1}
      }

      html = render_component(&BulkActions.render/1, assigns)

      assert html =~ ~s(data-confirm="Delete 2 items?")
    end

    test "prepares a custom confirmation instead of using data-confirm" do
      assigns = %{
        selectable: true,
        selected_ids: MapSet.new(["1", "2"]),
        bulk_action_slots: [
          %{action: :delete, label: "Delete", confirmation: :slot}
        ],
        bulk_action_confirmation_slot: [],
        pending_bulk_action: nil,
        theme: @theme,
        myself: %Phoenix.LiveComponent.CID{cid: 1}
      }

      html = render_component(&BulkActions.render/1, assigns)

      assert html =~ "bulk_action_prepare"
      refute html =~ "data-confirm="
      refute html =~ "bulk_action_execute"
    end

    test "renders the custom confirmation slot with action context" do
      assigns = %{
        selectable: true,
        selected_ids: MapSet.new(["1", "2"]),
        bulk_action_slots: [
          %{action: :delete, label: "Delete", confirmation: :slot}
        ],
        bulk_action_confirmation_slot: [
          %{
            inner_block: fn _assigns, context ->
              "Confirm #{context.selected_count} for #{context.action}: #{context.data} / #{context.error}; active=#{context.active?} ready=#{context.ready?} confirm=#{not is_nil(context.confirm)} cancel=#{not is_nil(context.cancel)}"
            end
          }
        ],
        bulk_action_confirmation: %{
          index: 0,
          selected_ids: MapSet.new(["1", "2"]),
          data: "prepared",
          error: "failed"
        },
        theme: @theme,
        myself: %Phoenix.LiveComponent.CID{cid: 1}
      }

      html = render_component(&BulkActions.render/1, assigns)

      assert html =~
               "Confirm 2 for delete: prepared / failed; active=true ready=true confirm=true cancel=true"
    end

    test "renders the custom confirmation slot while inactive" do
      assigns = %{
        selectable: true,
        selected_ids: MapSet.new(["1"]),
        bulk_action_slots: [
          %{action: :delete, label: "Delete", confirmation: :slot}
        ],
        bulk_action_confirmation_slot: [
          %{
            inner_block: fn _assigns, context ->
              "active=#{context.active?} ready=#{context.ready?} data=#{inspect(context.data)} error=#{inspect(context.error)} confirm=#{not is_nil(context.confirm)} cancel=#{not is_nil(context.cancel)}"
            end
          }
        ],
        bulk_action_confirmation: nil,
        theme: @theme,
        myself: %Phoenix.LiveComponent.CID{cid: 1}
      }

      html = render_component(&BulkActions.render/1, assigns)

      assert html =~
               "active=false ready=false data=nil error=nil confirm=true cancel=true"
    end
  end
end
