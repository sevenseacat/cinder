defmodule Cinder.BulkActionConfirmationTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog
  import Phoenix.LiveViewTest

  alias Cinder.BulkActionConfirmation
  alias Cinder.LiveComponent
  alias Cinder.Support.SearchTestResource

  setup {Cinder.TestHelpers, :disable_async_loading}

  @context %{
    selected_ids: MapSet.new(["one", "two"]),
    selected_count: 2,
    action: :destroy
  }

  describe "prepare/2" do
    test "returns nil data when no callback is configured" do
      assert {:ok, nil} = BulkActionConfirmation.prepare(nil, @context)
    end

    test "passes the confirmation context to the callback" do
      assert {:ok, selected_ids} =
               BulkActionConfirmation.prepare(
                 fn context -> {:ok, MapSet.to_list(context.selected_ids)} end,
                 @context
               )

      assert MapSet.new(selected_ids) == @context.selected_ids
    end

    test "normalizes plain callback values" do
      assert {:ok, :prepared} =
               BulkActionConfirmation.prepare(fn _context -> :prepared end, @context)
    end

    test "normalizes :ok as nil data" do
      assert {:ok, nil} = BulkActionConfirmation.prepare(fn _context -> :ok end, @context)
    end

    test "preserves callback errors" do
      assert {:error, :unavailable} =
               BulkActionConfirmation.prepare(
                 fn _context -> {:error, :unavailable} end,
                 @context
               )
    end

    test "normalizes raised exceptions as errors" do
      assert {:error, "preparation failed"} =
               BulkActionConfirmation.prepare(
                 fn _context -> raise "preparation failed" end,
                 @context
               )
    end
  end

  describe "LiveComponent confirmation lifecycle" do
    test "prepares confirmation data and clears it on cancel" do
      socket =
        socket(%{
          bulk_action_slots: [
            %{
              action: :destroy,
              confirmation: :slot,
              prepare_confirmation: fn context ->
                {:ok, MapSet.to_list(context.selected_ids)}
              end
            }
          ]
        })

      assert {:noreply, socket} =
               LiveComponent.handle_event("bulk_action_prepare", %{"index" => 0}, socket)

      assert socket.assigns.bulk_action_confirmation.index == 0
      assert socket.assigns.bulk_action_confirmation.selected_ids == @context.selected_ids
      attempt = socket.assigns.bulk_action_confirmation.attempt
      refute Map.has_key?(socket.assigns.bulk_action_confirmation, :data)
      refute Map.has_key?(socket.assigns.bulk_action_confirmation, :error)

      assert {:noreply, socket} =
               LiveComponent.handle_async(
                 {:bulk_action_confirmation, 0, attempt},
                 {:ok, {:ok, ["one", "two"]}},
                 socket
               )

      assert MapSet.new(socket.assigns.bulk_action_confirmation.data) ==
               @context.selected_ids

      assert {:noreply, socket} =
               LiveComponent.handle_event("bulk_action_cancel", %{}, socket)

      assert socket.assigns.bulk_action_confirmation == nil
    end

    test "keeps confirmation open and exposes preparation errors" do
      socket =
        socket(%{
          bulk_action_slots: [
            %{
              action: :destroy,
              confirmation: :slot,
              prepare_confirmation: fn _context -> {:error, :unavailable} end
            }
          ]
        })

      assert {:noreply, socket} =
               LiveComponent.handle_event("bulk_action_prepare", %{"index" => 0}, socket)

      attempt = socket.assigns.bulk_action_confirmation.attempt

      assert {:noreply, socket} =
               LiveComponent.handle_async(
                 {:bulk_action_confirmation, 0, attempt},
                 {:ok, {:error, :unavailable}},
                 socket
               )

      assert socket.assigns.bulk_action_confirmation.index == 0
      assert socket.assigns.bulk_action_confirmation.error == :unavailable
      refute Map.has_key?(socket.assigns.bulk_action_confirmation, :data)
    end

    test "ignores stale preparation results" do
      socket = socket(%{bulk_action_confirmation: confirmation(:current, nil, make_ref())})

      assert {:noreply, unchanged} =
               LiveComponent.handle_async(
                 {:bulk_action_confirmation, 1, make_ref()},
                 {:ok, {:ok, :stale}},
                 socket
               )

      assert unchanged.assigns.bulk_action_confirmation ==
               socket.assigns.bulk_action_confirmation
    end

    test "ignores preparation results after cancellation" do
      attempt = make_ref()
      socket = socket(%{bulk_action_confirmation: confirmation(:current, nil, attempt)})

      assert {:noreply, socket} =
               LiveComponent.handle_event("bulk_action_cancel", %{}, socket)

      assert {:noreply, socket} =
               LiveComponent.handle_async(
                 {:bulk_action_confirmation, 0, attempt},
                 {:ok, {:ok, :late}},
                 socket
               )

      assert socket.assigns.bulk_action_confirmation == nil
    end

    test "does not start preparation twice while an attempt is running" do
      socket =
        socket(%{
          bulk_action_slots: [
            %{
              action: :destroy,
              confirmation: :slot,
              prepare_confirmation: fn _context -> :prepared end
            }
          ]
        })

      assert {:noreply, socket} =
               LiveComponent.handle_event("bulk_action_prepare", %{"index" => 0}, socket)

      assert {:noreply, unchanged} =
               LiveComponent.handle_event("bulk_action_prepare", %{"index" => 0}, socket)

      assert unchanged.assigns.bulk_action_confirmation ==
               socket.assigns.bulk_action_confirmation
    end

    test "ignores a late result from an earlier attempt for the same action" do
      socket =
        socket(%{
          bulk_action_slots: [
            %{
              action: :destroy,
              confirmation: :slot,
              prepare_confirmation: fn _context -> :fresh end
            }
          ]
        })

      assert {:noreply, first_attempt_socket} =
               LiveComponent.handle_event("bulk_action_prepare", %{"index" => 0}, socket)

      first_attempt = first_attempt_socket.assigns.bulk_action_confirmation.attempt

      assert {:noreply, cancelled_socket} =
               LiveComponent.handle_event("bulk_action_cancel", %{}, first_attempt_socket)

      assert {:noreply, second_attempt_socket} =
               LiveComponent.handle_event(
                 "bulk_action_prepare",
                 %{"index" => 0},
                 cancelled_socket
               )

      second_attempt = second_attempt_socket.assigns.bulk_action_confirmation.attempt
      refute first_attempt == second_attempt

      assert {:noreply, unchanged} =
               LiveComponent.handle_async(
                 {:bulk_action_confirmation, 0, first_attempt},
                 {:ok, {:ok, :stale}},
                 second_attempt_socket
               )

      refute Map.has_key?(unchanged.assigns.bulk_action_confirmation, :data)
    end

    test "ignores direct execution for actions that require slot confirmation" do
      action = fn _query, _opts -> send(self(), :executed) end

      socket =
        socket(%{
          query: SearchTestResource,
          bulk_action_slots: [%{action: action, confirmation: :slot}]
        })

      assert {:noreply, unchanged} =
               LiveComponent.handle_event("bulk_action_execute", %{"index" => 0}, socket)

      assert unchanged.assigns.selected_ids == @context.selected_ids
      refute_received :executed
    end

    test "ignores confirmation before preparation succeeds" do
      action = fn _query, _opts -> send(self(), :executed) end

      socket =
        socket(%{
          query: SearchTestResource,
          bulk_action_confirmation: %{
            index: 0,
            selected_ids: @context.selected_ids
          },
          bulk_action_slots: [%{action: action, confirmation: :slot}]
        })

      assert {:noreply, unchanged} =
               LiveComponent.handle_event("bulk_action_confirm", %{}, socket)

      assert unchanged.assigns.bulk_action_confirmation ==
               socket.assigns.bulk_action_confirmation

      refute_received :executed
    end

    test "keeps confirmation open and exposes execution errors" do
      action = fn _query, _opts -> {:error, :not_allowed} end

      socket =
        socket(%{
          query: SearchTestResource,
          bulk_action_confirmation: confirmation(:prepared),
          bulk_action_slots: [
            %{action: action, confirmation: :slot, on_error: :bulk_action_failed}
          ]
        })

      assert {:noreply, socket} =
               LiveComponent.handle_event("bulk_action_confirm", %{}, socket)

      assert socket.assigns.bulk_action_confirmation.index == 0
      assert socket.assigns.bulk_action_confirmation.data == :prepared
      assert socket.assigns.bulk_action_confirmation.error == :not_allowed

      assert_received {:bulk_action_failed,
                       %{
                         component_id: "test-collection",
                         action: ^action,
                         reason: :not_allowed
                       }}
    end

    test "closes confirmation state after successful execution" do
      action = fn _query, _opts -> {:ok, :done} end

      socket =
        socket(%{
          query: SearchTestResource,
          bulk_action_confirmation: confirmation(:prepared, :previous_error),
          bulk_action_slots: [
            %{action: action, confirmation: :slot, on_success: :bulk_action_succeeded}
          ]
        })

      assert {:noreply, socket} =
               LiveComponent.handle_event("bulk_action_confirm", %{}, socket)

      assert socket.assigns.bulk_action_confirmation == nil
      assert socket.assigns.selected_ids == MapSet.new()

      assert_received {:bulk_action_succeeded,
                       %{
                         component_id: "test-collection",
                         action: ^action,
                         count: 2,
                         result: :done
                       }}
    end
  end

  describe "configuration warnings" do
    test "warns when slot confirmation content is missing" do
      log =
        capture_log(fn ->
          render_collection([
            %{action: :destroy, label: "Delete", confirmation: :slot}
          ])
        end)

      assert log =~ "require a <:bulk_action_confirmation> slot"
    end

    test "warns when browser and slot confirmations are both configured" do
      log =
        capture_log(fn ->
          render_collection(
            [
              %{
                action: :destroy,
                label: "Delete",
                confirm: "Delete records?",
                confirmation: :slot
              }
            ],
            confirmation_slot()
          )
        end)

      assert log =~ "cannot use both"
    end

    test "warns when custom confirmation content is unused" do
      log = capture_log(fn -> render_collection([], confirmation_slot()) end)

      assert log =~ "is unused"
    end
  end

  defp socket(assigns) do
    defaults = %{
      __changed__: %{},
      id: "test-collection",
      selected_ids: @context.selected_ids,
      id_field: :id,
      actor: nil,
      tenant: nil,
      scope: nil,
      bulk_action_confirmation: nil,
      query_opts: [],
      page_size: 25,
      current_page: 1,
      sort_by: [],
      filters: %{},
      columns: [],
      search_term: "",
      search_fn: nil,
      pagination_mode: :offset,
      after_keyset: nil,
      before_keyset: nil,
      page_size_config: Cinder.PageSize.parse(nil),
      on_query_change: nil,
      loading: false,
      error: false,
      data: []
    }

    %Phoenix.LiveView.Socket{
      assigns: Map.merge(defaults, assigns),
      root_pid: self()
    }
  end

  defp render_collection(bulk_actions, confirmation_slot \\ []) do
    render_component(&Cinder.collection/1, %{
      resource: SearchTestResource,
      actor: nil,
      selectable: true,
      col: [],
      bulk_action: bulk_actions,
      bulk_action_confirmation: confirmation_slot
    })
  end

  defp confirmation_slot do
    [%{inner_block: fn _assigns, _context -> "Confirmation" end}]
  end

  defp confirmation(data, error \\ nil, attempt \\ make_ref()) do
    confirmation = %{
      index: 0,
      attempt: attempt,
      selected_ids: @context.selected_ids,
      data: data
    }

    if error, do: Map.put(confirmation, :error, error), else: confirmation
  end
end
