defmodule Cinder.Renderers.InfiniteStream do
  @moduledoc false

  use Phoenix.Component
  use Cinder.Messages

  attr :id, :string, required: true
  attr :myself, :any, required: true
  attr :theme, :map, required: true
  attr :show, :boolean, default: false

  def top_sentinel(assigns) do
    ~H"""
    <div
      :if={@show}
      id={"#{@id}-infinite-top-sentinel"}
      data-pagination-state="ready-previous"
      phx-viewport-top="load_previous"
      phx-target={@myself}
    >
      <button
        type="button"
        class={@theme.pagination_button_class}
        phx-click="load_previous"
        phx-target={@myself}
      >
        {dgettext("cinder", "Load previous")}
      </button>
    </div>
    """
  end

  def encode_selected_ids(selected_ids, visible_ids \\ nil) do
    selected_ids =
      case visible_ids do
        %MapSet{} -> MapSet.intersection(selected_ids, visible_ids)
        _ -> selected_ids
      end

    Jason.encode!(selected_ids |> MapSet.to_list() |> Enum.sort())
  end

  def encode_selected_classes(selected_classes), do: Jason.encode!(selected_classes)

  def selected_classes(class) when is_binary(class), do: String.split(class)

  def selected_classes(classes) when is_list(classes) do
    classes
    |> List.flatten()
    |> Enum.flat_map(&selected_classes/1)
  end

  def selected_classes(_), do: []
end
