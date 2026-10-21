defmodule Cinder.Next.LiveView do
  @moduledoc """
  Spike: collections kept in a LiveView's own assigns, rendered by any markup.

      use Cinder.Next.LiveView

      def mount(_params, _session, socket) do
        {:ok,
         Cinder.Next.LiveView.assign_collection(socket, :albums, Music.Album,
           url: true,
           filters: [genre: :select, price: :number_range],
           sorts: [:title, release_date: [label: "Released"]]
         )}
      end

  `@albums` is then the collection's view-model, the same one a `<:page>` gets, for
  `Cinder.Next`'s components or your own. Its events are named
  `cinder:albums:<event>`, and the `on_mount` hook this attaches handles them, the
  URL (for `url: true`) and the loads, so the LiveView's own callbacks only see
  their own events.
  """
  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [attach_hook: 4, start_async: 3]

  alias Cinder.Next.{Collection, Config}

  defmacro __using__(_opts) do
    quote do
      on_mount Cinder.Next.LiveView
    end
  end

  @doc false
  def on_mount(:default, _params, _session, socket) do
    socket =
      socket
      |> assign(:__cinder__, %{})
      |> attach_hook(:cinder_events, :handle_event, &handle_event/3)
      |> attach_hook(:cinder_params, :handle_params, &handle_params/3)
      |> attach_hook(:cinder_async, :handle_async, &handle_async/3)

    {:cont, socket}
  end

  @doc """
  Declares a collection and assigns its view-model as `name`. `query` is a resource
  or an `Ash.Query`.

  The options are the collection's attrs, with the slots as keyword lists:

    * `filters:` `[field: type]`, or `[field: [type: ..., options: ..., label: ...]]`
    * `sorts:` `[field]` or `[field: [label: ..., cycle: ...]]`
    * `bulk_actions:` `[name: action]` or `[name: [action: ..., confirm: ...]]`
    * `search:` the fields to search
    * `group:` a field, or `[field: ..., sort: :desc]`, to group each page's rows by
    * `load:` passed on as `query_opts: [load: ...]`
    * `url:` `true` to keep the collection's state in the URL (one per LiveView,
      for the spike)

  plus `layout`, `layouts`, `selectable`, `page_size`, `pagination_mode`,
  `grid_columns`, `action`, `scope`, `actor` and `tenant`, as on
  `Cinder.Next.collection/1`.
  """
  def assign_collection(socket, name, query, opts \\ []) do
    {url?, opts} = Keyword.pop(opts, :url, false)
    config = Config.build(to_assigns(name, query, opts))

    # A URL-synced collection waits for the URL, which `handle_params` brings next
    {collection, effects} = Collection.new(to_string(name), config, url? && %{})
    effects = if url?, do: [], else: effects

    socket
    |> put_entry(name, %{collection: collection, url?: url?, loaded?: false})
    |> run(name, effects)
  end

  # The slots `Cinder.Next.collection/1` would get, from keyword lists
  defp to_assigns(name, query, opts) do
    {query_key, query} = if is_atom(query), do: {:resource, query}, else: {:query, query}
    {load, opts} = Keyword.pop(opts, :load)
    query_opts = Keyword.get(opts, :query_opts, []) ++ if(load, do: [load: load], else: [])

    opts
    |> Keyword.drop([:filters, :sorts, :bulk_actions, :search, :query_opts, :group])
    |> Map.new()
    |> Map.merge(%{
      query_key => query,
      :id => to_string(name),
      :query_opts => query_opts,
      :search => search(opts[:search]),
      :group => group(opts[:group]),
      :filter => Enum.map(opts[:filters] || [], &slot(:filter, :field, &1, :type)),
      :sort => Enum.map(opts[:sorts] || [], &slot(:sort, :field, &1, nil)),
      :bulk_action => Enum.map(opts[:bulk_actions] || [], &slot(:bulk_action, :name, &1, :action))
    })
  end

  # `group: :genre` or `group: [field: :genre, sort: :desc]`
  defp group(nil), do: []
  defp group(field) when is_atom(field), do: group(field: field)

  defp group(opts) do
    {field, opts} = Keyword.pop!(opts, :field)
    [Map.merge(%{__slot__: :group, inner_block: nil, field: to_string(field)}, Map.new(opts))]
  end

  defp search(nil), do: nil
  defp search(fields) when is_list(fields), do: [fields: Enum.map(fields, &to_string/1)]

  # `title`, `{:genre, :select}` or `{:price, [type: :number_range, label: ...]}`
  defp slot(slot, key, entry, shorthand) do
    {name, attrs} =
      case entry do
        {name, attrs} when is_list(attrs) -> {name, attrs}
        {name, value} -> {name, [{shorthand, value}]}
        name -> {name, []}
      end

    Map.merge(%{__slot__: slot, inner_block: nil}, Map.new([{key, to_string(name)} | attrs]))
  end

  defp handle_event("cinder:" <> rest, params, socket) do
    with [name, event] <- String.split(rest, ":", parts: 2),
         %{collection: collection} <- socket.assigns.__cinder__[name] do
      {collection, effects} = Collection.handle_event(collection, event, params)
      {:halt, socket |> update_collection(name, collection) |> run(name, effects)}
    else
      _unknown -> {:halt, socket}
    end
  end

  defp handle_event(_event, _params, socket), do: {:cont, socket}

  defp handle_params(params, uri, socket) do
    socket =
      Enum.reduce(socket.assigns.__cinder__, assign(socket, :__cinder_uri__, uri), fn
        {name, %{url?: true} = entry}, socket ->
          {collection, effects} = Collection.apply_url(entry.collection, params)
          # The first visit always loads, even when the URL holds nothing new
          effects = if entry.loaded?, do: effects, else: Enum.uniq([:load | effects])
          socket |> update_collection(name, collection) |> run(name, effects)

        _not_synced, socket ->
          socket
      end)

    {:cont, socket}
  end

  defp handle_async({:cinder, name}, result, socket) do
    case socket.assigns.__cinder__[name] do
      nil ->
        {:halt, socket}

      entry ->
        {:halt,
         update_collection(socket, name, Collection.loaded(entry.collection, unwrap(result)))}
    end
  end

  defp handle_async(_name, _result, socket), do: {:cont, socket}

  defp unwrap({:ok, result}), do: result
  defp unwrap({:exit, reason}), do: {:exit, reason}

  defp run(socket, name, effects) do
    name = to_string(name)

    Enum.reduce(effects, socket, fn
      :load, socket ->
        load(socket, name)

      {:url, params}, socket ->
        Cinder.UrlSync.update_url(socket, params, socket.assigns[:__cinder_uri__])
    end)
  end

  defp load(socket, name) do
    collection = Collection.loading(socket.assigns.__cinder__[name].collection)
    run = Collection.load_fun(collection)
    socket = socket |> update_collection(name, collection) |> mark_loaded(name)

    # Ash's test helpers set this to make reads synchronous, as the current shell honours
    if Application.get_env(:ash, :disable_async?) do
      update_collection(socket, name, Collection.loaded(collection, run.()))
    else
      start_async(socket, {:cinder, name}, run)
    end
  end

  defp put_entry(socket, name, entry) do
    name = to_string(name)

    socket
    |> assign(
      :__cinder__,
      Map.put(socket.assigns.__cinder__, name, Map.put(entry, :assign, assign_name(name)))
    )
    |> update_collection(name, entry.collection)
  end

  # The view-model is what the template sees, under the name it was declared with
  defp update_collection(socket, name, collection) do
    entry = Map.put(socket.assigns.__cinder__[name], :collection, collection)

    socket
    |> assign(:__cinder__, Map.put(socket.assigns.__cinder__, name, entry))
    |> assign(entry.assign, Collection.view(collection, {:live_view, name}))
  end

  defp mark_loaded(socket, name),
    do: assign(socket, :__cinder__, put_in(socket.assigns.__cinder__, [name, :loaded?], true))

  # The declared name comes back as an atom: it was one when declared
  defp assign_name(name), do: String.to_existing_atom(name)
end
