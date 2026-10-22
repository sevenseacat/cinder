defmodule CinderDevWeb.NextThemesLive do
  @moduledoc """
  The shell-rewrite spike's CSS themes (7CC-108): the same collection, with
  Cinder's default components, in the "default" theme and in `modern` ported to
  CSS, by hand and by `mix cinder.next.convert_theme`. The ports are scoped with
  `data-cinder-theme` so all three fit on one page, which also means they're
  layered over the default theme rather than replacing it (a real theme would be
  imported on its own).
  """
  use CinderDevWeb, :live_view

  @impl true
  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      theme={@theme}
      current_path={@current_path}
      query_params={@query_params}
    >
      <div class="grid gap-10 xl:grid-cols-2">
        <section>
          <h2 class="mb-4 text-lg font-semibold">"default"</h2>
          <.albums id="default-theme" />
        </section>
        <section data-cinder-theme="modern">
          <h2 class="mb-4 text-lg font-semibold">modern</h2>
          <.albums id="modern-theme" />
        </section>
        <section data-cinder-theme="modern-converted">
          <h2 class="mb-4 text-lg font-semibold">modern, converted by the mix task</h2>
          <.albums id="modern-converted-theme" />
        </section>
        <section data-cinder-theme="daisy_ui">
          <h2 class="mb-4 text-lg font-semibold">daisy_ui (daisyUI classes through @apply)</h2>
          <.albums id="daisy-theme" />
        </section>
      </div>
    </Layouts.app>
    """
  end

  attr :id, :string, required: true

  defp albums(assigns) do
    ~H"""
    <Cinder.Next.collection
      id={@id}
      resource={Music.Album}
      query_opts={[load: [:artist]]}
      page_size={6}
      selectable
      grid_columns={[xs: 1, md: 2]}
    >
      <:col :let={album} field="title" sort search>{album.title}</:col>
      <:col :let={album} field="artist.name" label="Artist">{album.artist.name}</:col>
      <:col field="genre" />
      <:col :let={album} field="price" sort>${Decimal.to_string(album.price)}</:col>
      <:filter field="genre" type="select" prompt="Any genre" />
      <:item :let={album}>
        <strong>{album.title}</strong>
        <p>{album.artist.name}</p>
      </:item>
      <:bulk_action name="remaster" action={:remaster} />
    </Cinder.Next.collection>
    """
  end
end
