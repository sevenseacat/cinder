defmodule Cinder.Renderers.SortIcon do
  @moduledoc """
  Shared sort indicator used by every renderer (table, list, grid).

  Renders a Heroicon reflecting the current sort direction so that all layouts
  show identical indicators. Handles the ascending, descending, and unsorted
  states (including `*_nils_first`/`*_nils_last` variants) and applies the
  loading pulse while data is refreshing.
  """

  use Phoenix.Component

  attr :sort_direction, :atom, default: nil
  attr :theme, :map, required: true
  attr :loading, :boolean, default: false

  def sort_icon(assigns) do
    ~H"""
    <span class={Map.get(@theme, :sort_arrow_wrapper_class, "inline-block ml-1")}>
      <%= case @sort_direction do %>
        <% direction when direction in [:asc, :asc_nils_first, :asc_nils_last] -> %>
          <.icon
            name={Map.get(@theme, :sort_asc_icon_name, "hero-chevron-up")}
            class={[Map.get(@theme, :sort_asc_icon_class, "w-3 h-3 inline"), (@loading && "animate-pulse" || "")]}
          />
        <% direction when direction in [:desc, :desc_nils_first, :desc_nils_last] -> %>
          <.icon
            name={Map.get(@theme, :sort_desc_icon_name, "hero-chevron-down")}
            class={[Map.get(@theme, :sort_desc_icon_class, "w-3 h-3 inline"), (@loading && "animate-pulse" || "")]}
          />
        <% _ -> %>
          <.icon
            name={Map.get(@theme, :sort_none_icon_name, "hero-chevron-up-down")}
            class={Map.get(@theme, :sort_none_icon_class, "w-3 h-3 inline opacity-30")}
          />
      <% end %>
    </span>
    """
  end

  defp icon(%{name: _, class: _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end
end
