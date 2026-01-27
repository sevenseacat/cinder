defmodule Cinder.Renderers.BulkActions do
  @moduledoc """
  Shared bulk actions component used by Table, List, and Grid renderers.

  Renders bulk action buttons that execute Ash actions or custom functions
  on the selected records.
  """

  use Phoenix.Component
  alias Phoenix.LiveView.JS

  @doc """
  Renders bulk action buttons when selectable is enabled and slots are provided.

  ## Required assigns
  - `selectable` - Boolean indicating if selection is enabled
  - `selected_ids` - MapSet of selected record IDs
  - `bulk_action_slots` - List of bulk_action slot definitions
  - `theme` - Theme configuration map
  - `myself` - LiveComponent reference for event targeting
  """
  def render(assigns) do
    selectable = Map.get(assigns, :selectable, false)
    slots = Map.get(assigns, :bulk_action_slots, [])

    if selectable and slots != [] do
      render_bulk_actions(assigns)
    else
      ~H""
    end
  end

  defp render_bulk_actions(assigns) do
    selected_ids = Map.get(assigns, :selected_ids, MapSet.new())
    slots = Map.get(assigns, :bulk_action_slots, [])

    assigns =
      assigns
      |> assign(:selected_ids, selected_ids)
      |> assign(:selected_count, MapSet.size(selected_ids))
      |> assign(:slots, slots)

    ~H"""
    <div class={@theme.bulk_actions_container_class} {@theme.bulk_actions_container_data}>
      <span
        :for={{slot, index} <- Enum.with_index(@slots)}
        phx-click={JS.push("bulk_action_execute", value: %{index: index}, target: @myself)}
        data-confirm={slot[:confirm] && interpolate_confirm(slot[:confirm], @selected_count)}
        class="contents"
      >
        {render_slot([slot], %{selected_ids: @selected_ids, selected_count: @selected_count})}
      </span>
    </div>
    """
  end

  defp interpolate_confirm(message, count) do
    String.replace(message, "{count}", to_string(count))
  end
end
