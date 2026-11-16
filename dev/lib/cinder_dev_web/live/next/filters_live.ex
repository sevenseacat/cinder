defmodule CinderDevWeb.Next.FiltersLive do
  @moduledoc """
  The Filters page in the new shell (`Cinder.Next`), plus a read action's arguments,
  which only the new shell has.
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
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      theme={@theme}
      current_path={@current_path}
      query_params={@query_params}
    >
      <h2 class="text-lg font-semibold">One of each main type (URL-synced)</h2>
      <Layouts.parity not_yet={["Themes"]} />
      <Cinder.Next.collection
        id="filters-main"
        resource={Music.Album}
        url_state={@url_state}
        pagination={[size: 10]}
      >
        <:field :let={album} name="title" filter={[type: :text]} search sort>
          {album.title}
        </:field>
        <:field
          :let={album}
          name="artist.name"
          label="Artist"
          filter={[type: :autocomplete, options: @artists]}
        >
          {album.artist.name}
        </:field>
        <:field :let={album} name="genre" filter={[type: :select]}>{album.genre}</:field>
        <:field :let={album} name="tags" filter={[type: :multi_select, options: @tags]}>
          {Enum.join(album.tags, ", ")}
        </:field>
        <:field
          :let={album}
          name="details__label"
          label="Label"
          filter={[type: :multi_checkboxes, options: @labels]}
        >
          {album.details.label}
        </:field>
        <:field :let={album} name="price" filter={[type: :number_range]} sort>
          {Decimal.to_string(album.price)}
        </:field>
        <:field :let={album} name="track_count" label="Tracks" filter={[type: :number_range]}>
          {album.track_count}
        </:field>
        <:field :let={album} name="release_date" filter={[type: :date_range]} sort>
          {album.release_date}
        </:field>
        <:field :let={album} name="added_at" filter={[type: :date_range]}>
          {album.added_at}
        </:field>
        <:field
          :let={album}
          name="artist.debuted_at"
          label="Artist debuted"
          filter={[type: :date_range]}
        >
          {album.artist.debuted_at}
        </:field>
        <:field
          :let={album}
          name="details__recorded_on"
          label="Recorded"
          filter={[type: :date_range]}
        >
          {album.details.recorded_on}
        </:field>
        <:field :let={album} name="is_remastered" label="Remastered" filter={[type: :boolean]}>
          {album.is_remastered}
        </:field>
      </Cinder.Next.collection>

      <h2 class="mt-10 text-lg font-semibold">Alternative inputs (not URL-synced)</h2>
      <Layouts.parity
        not_yet={["Themes"]}
        changed={["A filter that isn't a column is a `<:field column={false}>`, not a `<:filter>`"]}
      />
      <Cinder.Next.collection id="filters-alt" resource={Music.Album} pagination={[size: 10]}>
        <:field :let={album} name="title">{album.title}</:field>
        <:field :let={album} name="genre" filter={[type: :radio_group]}>{album.genre}</:field>
        <:field
          :let={album}
          name="is_remastered"
          label="Remastered"
          filter={[type: :checkbox, label: "Remastered only"]}
        >
          {album.is_remastered}
        </:field>
        <:field :let={album} name="release_date" filter={[type: :date]}>
          {album.release_date}
        </:field>
        <:field :let={album} name="added_at" label="Added on" filter={[type: :date]}>
          {album.added_at}
        </:field>
        <:field
          :let={album}
          name="tags"
          filter={[type: :multi_select, options: @tags, match_mode: :all]}
        >
          {Enum.join(album.tags, ", ")}
        </:field>
        <:field
          name="details__catalog_number"
          column={false}
          filter={[type: :text, label: "Catalog number"]}
        />
      </Cinder.Next.collection>

      <h2 class="mt-10 text-lg font-semibold">A read action's arguments (new shell only)</h2>
      <Cinder.Next.collection id="albums-by-genre" resource={Music.Album} action={:by_genre}>
        <:field :let={album} name="title" sort>{album.title}</:field>
        <:field :let={album} name="artist.name">{album.artist.name}</:field>
        <:argument name="genre" input={[prompt: "Choose a genre"]} />
      </Cinder.Next.collection>
    </Layouts.app>
    """
  end
end
