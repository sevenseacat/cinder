defmodule CinderDevWeb.FiltersLive do
  @moduledoc """
  Every built-in filter type. A column takes one filter, so the types that would
  reuse a field are in a second collection. Only the first is URL-synced, because
  two URL-synced collections on one page aren't supported yet.
  """
  use CinderDevWeb, :live_view
  use Cinder.UrlSync

  @impl true
  def mount(_params, _session, socket) do
    artists = Music.Artist |> Ash.read!() |> Enum.map(&{&1.name, &1.name}) |> Enum.sort()

    {:ok,
     assign(socket,
       artists: artists,
       tags: Enum.map(CinderDev.Seeds.tags(), &{&1, &1}),
       labels: Enum.map(CinderDev.Seeds.labels(), &{&1, &1})
     )}
  end

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
      <h2 class="text-lg font-semibold">One of each main type (URL-synced)</h2>
      <Cinder.collection
        id="filters-main"
        resource={Music.Album}
        theme={@theme}
        url_state={@url_state}
        query_opts={[load: [:artist]]}
        page_size={10}
      >
        <:col :let={album} field="title" filter={[type: :text]} search sort>
          {album.title}
        </:col>
        <:col
          :let={album}
          field="artist.name"
          label="Artist"
          filter={[type: :autocomplete, options: @artists]}
        >
          {album.artist.name}
        </:col>
        <:col :let={album} field="genre" filter={[type: :select]}>{album.genre}</:col>
        <:col :let={album} field="tags" filter={[type: :multi_select, options: @tags]}>
          {Enum.join(album.tags, ", ")}
        </:col>
        <:col
          :let={album}
          field="details__label"
          label="Label"
          filter={[type: :multi_checkboxes, options: @labels]}
        >
          {album.details.label}
        </:col>
        <:col :let={album} field="price" filter={[type: :number_range]} sort>
          {Decimal.to_string(album.price)}
        </:col>
        <:col :let={album} field="track_count" label="Tracks" filter={[type: :number_range]}>
          {album.track_count}
        </:col>
        <:col :let={album} field="release_date" filter={[type: :date_range]} sort>
          {album.release_date}
        </:col>
        <:col :let={album} field="added_at" filter={[type: :date_range]}>
          {album.added_at}
        </:col>
        <:col :let={album} field="is_remastered" label="Remastered" filter={[type: :boolean]}>
          {album.is_remastered}
        </:col>
      </Cinder.collection>

      <h2 class="mt-10 text-lg font-semibold">Alternative inputs (not URL-synced)</h2>
      <Cinder.collection
        id="filters-alt"
        resource={Music.Album}
        theme={@theme}
        page_size={10}
      >
        <:col :let={album} field="title">{album.title}</:col>
        <:col :let={album} field="genre" filter={[type: :radio_group]}>{album.genre}</:col>
        <:col
          :let={album}
          field="is_remastered"
          label="Remastered"
          filter={[type: :checkbox, label: "Remastered only"]}
        >
          {album.is_remastered}
        </:col>
        <:col :let={album} field="release_date" filter={[type: :date]}>
          {album.release_date}
        </:col>
        <:col
          :let={album}
          field="tags"
          filter={[type: :multi_select, options: @tags, match_mode: :all]}
        >
          {Enum.join(album.tags, ", ")}
        </:col>
        <:filter field="details__catalog_number" type={:text} label="Catalog number" />
      </Cinder.collection>
    </Layouts.app>
    """
  end
end
