defmodule CinderDevWeb.ControlsLive do
  @moduledoc """
  A custom filter/search layout through the `:controls` slot: search on the left,
  filters in a row beside it.
  """
  use CinderDevWeb, :live_view
  use Cinder.UrlSync

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
        id="albums-controls"
        resource={Music.Album}
        theme={@theme}
        url_state={@url_state}
      >
        <:col :let={album} field="title" search sort>{album.title}</:col>
        <:col :let={album} field="genre" filter>{album.genre}</:col>
        <:col :let={album} field="is_remastered" label="Remastered" filter>
          {album.is_remastered}
        </:col>

        <:controls :let={controls}>
          <Cinder.Controls.render_header {controls} />
          <div class="flex flex-wrap items-end gap-4">
            <Cinder.Controls.render_search
              search={controls.search}
              theme={controls.theme}
              target={controls.target}
            />
            <Cinder.Controls.render_filter
              :for={{_field, filter} <- controls.filters}
              filter={filter}
              theme={controls.theme}
              target={controls.target}
            />
          </div>
        </:controls>
      </Cinder.collection>
    </Layouts.app>
    """
  end
end
