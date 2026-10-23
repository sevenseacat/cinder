defmodule CinderDevWeb.NextFiltersLive do
  @moduledoc """
  The shell-rewrite spike's filter types, each rendered by the default markup from
  its view-model (`Cinder.Next.FilterView`): the built-ins, and two custom filters
  registered in `config/config.exs`.
  """
  use CinderDevWeb, :live_view
  use Cinder.UrlSync

  @impl true
  def mount(_params, _session, socket) do
    artists = Music.Artist |> Ash.read!() |> Enum.map(& &1.name) |> Enum.sort() |> Enum.take(4)
    {:ok, assign(socket, :artists, Enum.map(artists, &{&1, &1}))}
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
      <Cinder.Next.collection
        id="filters"
        resource={Music.Album}
        url_state={@url_state}
        query_opts={[load: [:artist]]}
        page_size={10}
      >
        <:col :let={album} field="title" search sort>{album.title}</:col>
        <:col field="genre" />
        <:col field="release_date" label="Released" sort />
        <:col :let={album} field="added_at" label="Added">
          {Calendar.strftime(album.added_at, "%Y-%m-%d %H:%M")}
        </:col>
        <:col field="is_remastered" label="Remastered" />
        <:col :let={album} field="price">${Decimal.to_string(album.price)}</:col>
        <:filter field="title" type="text" />
        <:filter field="genre" type="select" prompt="Any genre" />
        <:filter
          field="tags"
          type="multi_select"
          options={Enum.map(CinderDev.Seeds.tags(), &{&1, &1})}
        />
        <:filter field="price" type="number_range" />
        <:filter field="release_date" type="date_range" label="Released" />
        <:filter field="added_at" type="date" label="Added on" />
        <:filter
          field="is_remastered"
          type="boolean"
          label="Remastered"
          opts={[labels: %{true: "Yes", false: "No"}]}
        />
        <:filter
          field="artist.name"
          type="radio_group"
          label="Artist"
          options={@artists}
        />
        <:filter field="track_count" type="checkbox" label="Twelve tracks" opts={[value: 12]} />
      </Cinder.Next.collection>

      <h2 class="mt-12 text-lg font-semibold">Custom filters</h2>
      <p class="text-sm opacity-70">
        A hand-written slider (`CinderDev.Filters.Slider`), and a select from
        `mix cinder.gen.filter CinderDev.Filters.CustomSelect custom_select --template=select`
        (not URL-synced)
      </p>
      <Cinder.Next.collection id="custom-filters" resource={Music.Album} page_size={5}>
        <:col :let={album} field="title">{album.title}</:col>
        <:col field="genre" />
        <:col field="track_count" label="Tracks" />
        <:filter field="track_count" type="slider" label="Tracks, at most" opts={[min: 5, max: 20]} />
        <:filter field="genre" type="custom_select" label="Genre (generated filter)" />
      </Cinder.Next.collection>
    </Layouts.app>
    """
  end
end
