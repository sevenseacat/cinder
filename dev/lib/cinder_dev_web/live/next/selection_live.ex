defmodule CinderDevWeb.Next.SelectionLive do
  @moduledoc """
  The Selection page in the new shell (`Cinder.Next`), plus a `selectable` function on
  keyset pages, where selecting everything matching isn't offered. Deleted albums
  come back on restart, because the data is re-seeded at boot.
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
      <h2 class="text-lg font-semibold">Every album selectable (URL-synced)</h2>
      <Layouts.parity
        not_yet={["Button variants (`variant`)", "Themes"]}
        changed={["No `{count}` in a bulk action's label: the bar shows the count"]}
      />
      <Cinder.Next.collection
        id="albums-selection"
        resource={Music.Album}
        url_state={@url_state}
        selectable
        on_bulk_action_result={:bulk_action_done}
      >
        <:field :let={album} name="title" filter sort>{album.title}</:field>
        <:field :let={album} name="is_remastered" label="Remastered" filter>
          {album.is_remastered}
        </:field>
        <:bulk_action action={:remaster} />
        <:bulk_action action={:destroy} label="Delete" confirm="Delete {count} albums?" />
      </Cinder.Next.collection>

      <h2 class="mt-10 text-lg font-semibold">
        Classical albums can't be selected, on keyset pages (not URL-synced)
      </h2>
      <Cinder.Next.collection
        id="albums-selectable-fn"
        resource={Music.Album}
        pagination={[mode: :keyset, size: 10]}
        selectable={&(&1.genre != :classical)}
        on_bulk_action_result={:bulk_action_done}
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
        <:field :let={album} name="genre" filter={[type: :radio_group, prompt: "Any"]}>
          {album.genre}
        </:field>
        <:bulk_action action={:remaster} />
        <:bulk_action action={:destroy} label="Delete" confirm="Delete {count} albums?" />
      </Cinder.Next.collection>
    </Layouts.app>
    """
  end

  @impl true
  def handle_info({:bulk_action_done, result}, socket) do
    %{bulk_action: name, status: status, selected_count: count, errors: errors} = result

    {kind, message} =
      case status do
        :success -> {:info, "#{name}: ran on #{count} selected"}
        :partial_success -> {:error, "#{name}: some of #{count} failed: #{inspect(errors)}"}
        :error -> {:error, "#{name} failed: #{inspect(errors)}"}
      end

    {:noreply, put_flash(socket, kind, message)}
  end
end
