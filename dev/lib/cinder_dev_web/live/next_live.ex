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
      <Cinder.Next.collection
        id="albums"
        resource={Music.Album}
        pagination={[mode: :keyset, size: 10]}
      >
        <:field :let={album} name="title" sort filter search>{album.title}</:field>
        <:field :let={album} name="artist.name" sort search>{album.artist.name}</:field>
        <:field
          :let={album}
          name="release_date"
          label="Released"
          sort={[cycle: [:desc, :asc, nil]]}
          filter
        >
          {Calendar.strftime(album.release_date, "%d/%m/%Y")}
        </:field>
        <:field name="genre" filter={[type: :radio_group, prompt: "Any"]} column={false} />
      </Cinder.Next.collection>
    </Layouts.app>
    """
  end
end
