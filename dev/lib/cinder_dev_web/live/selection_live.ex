defmodule CinderDevWeb.SelectionLive do
  @moduledoc """
  Row selection and bulk actions. Deleted albums come back on restart, because
  the data is re-seeded at boot.
  """
  use CinderDevWeb, :live_view
  use Cinder.UrlSync

  @impl true
  def handle_params(params, uri, socket) do
    {:noreply, Cinder.UrlSync.handle_params(params, uri, socket)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      theme={@theme}
      current_path={@current_path}
      query_params={@query_params}
    >
      <Cinder.collection
        id="albums-selection"
        resource={Music.Album}
        theme={@theme}
        url_state={@url_state}
        selectable
      >
        <:col :let={album} field="title" filter sort>{album.title}</:col>
        <:col :let={album} field="is_remastered" label="Remastered" filter>
          {album.is_remastered}
        </:col>

        <:bulk_action action={:remaster} label="Remaster ({count})" variant={:primary} />
        <:bulk_action
          action={:destroy}
          label="Delete"
          variant={:danger}
          confirm="Delete {count} albums?"
        />
      </Cinder.collection>
    </Layouts.app>
    """
  end
end
