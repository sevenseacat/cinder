defmodule Cinder.Renderers.SelectAll do
  @moduledoc false

  use Phoenix.Component
  use Cinder.Messages

  alias Cinder.Selection

  attr :data, :any, required: true
  attr :id_field, :atom, required: true
  attr :loading, :boolean, required: true
  attr :label, :string, default: nil
  attr :mode, :atom, default: :query
  attr :myself, :any, required: true
  attr :pending, :boolean, default: false
  attr :scope_ids, :any, default: nil
  attr :selection_mode, :atom, default: :explicit
  attr :selectable, :any, required: true
  attr :selected_ids, :any, required: true
  attr :theme, :map, required: true
  attr :show_label, :boolean, default: true

  def render(assigns) do
    page_ids = Selection.page_ids(assigns.data, assigns.id_field, assigns.selectable)
    selection_ids = if assigns.mode == :query, do: assigns.scope_ids || page_ids, else: page_ids

    state = selection_state(assigns, selection_ids)

    assigns =
      assigns
      |> assign(
        :disabled,
        assigns.loading or (assigns.mode == :page and MapSet.size(selection_ids) == 0)
      )
      |> assign(
        :event,
        if(assigns.mode == :page, do: "toggle_select_all_page", else: "toggle_select_all")
      )
      |> assign(:label, assigns.label || default_label(assigns.mode))
      |> assign(:state, state)

    ~H"""
    <label class={@theme.select_all_container_class} data-key="select_all_container_class">
      <span class="relative inline-flex items-center justify-center">
        <input
          type="checkbox"
          aria-checked={if @state == :some, do: "mixed", else: to_string(@state == :all)}
          aria-label={@label}
          checked={@state == :all}
          class={@theme.selection_checkbox_class}
          data-indeterminate={@state == :some}
          data-key="selection_checkbox_class"
          data-selection-state={@state}
          disabled={@disabled}
          phx-click={@event}
          phx-disable-with=""
          phx-target={@myself}
        />
        <span
          :if={@state == :some}
          aria-hidden="true"
          class={@theme.selection_indeterminate_class}
          data-key="selection_indeterminate_class"
        >
        </span>
      </span>
      <span :if={@show_label}>{@label}</span>
    </label>
    """
  end

  defp default_label(:page), do: dgettext("cinder", "Select all visible items")
  defp default_label(_mode), do: dgettext("cinder", "Select all filtered items")

  defp selection_state(%{mode: :query, selection_mode: :all_matching} = assigns, _ids) do
    if MapSet.size(assigns.selected_ids) == 0, do: :all, else: :some
  end

  defp selection_state(%{pending: true}, _selection_ids), do: :all

  defp selection_state(assigns, selection_ids),
    do: explicit_selection_state(assigns.selected_ids, selection_ids)

  defp explicit_selection_state(selected_ids, selection_ids) do
    cond do
      MapSet.size(selection_ids) == 0 -> :none
      MapSet.subset?(selection_ids, selected_ids) -> :all
      MapSet.disjoint?(selection_ids, selected_ids) -> :none
      true -> :some
    end
  end
end
