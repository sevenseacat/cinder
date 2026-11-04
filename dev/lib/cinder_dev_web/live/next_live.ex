defmodule CinderDevWeb.NextLive do
  @moduledoc """
  The new shell (`Cinder.Next`), as it's rebuilt slice by slice.
  """
  use CinderDevWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      theme={@theme}
      current_path={@current_path}
      query_params={@query_params}
    >
      <Cinder.Next.collection id="albums" resource={Music.Album} sort={[mode: :exclusive]}>
        <:col :let={album} field="title" sort>{album.title}</:col>
        <:col :let={album} field="artist.name" sort>{album.artist.name}</:col>
        <:col :let={album} field="release_date" label="Released" sort={[cycle: [:desc, :asc, nil]]}>
          {Calendar.strftime(album.release_date, "%d/%m/%Y")}
        </:col>
      </Cinder.Next.collection>
    </Layouts.app>
    """
  end
end
