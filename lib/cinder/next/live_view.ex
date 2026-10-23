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

  `@albums` is then the collection's view-model, for `Cinder.Next`'s components or your
  own. Its events are named
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
  Declares a collection and assigns its view-model as `name`. `query` is a resource,
  an `Ash.Query`, or a module declaring the collection with `Cinder.Next.Dsl` (the
  options here then add to and override its declarations).

  The options are the collection's attrs, with the slots as keyword lists, checked
  against the same schemas (`Cinder.Next.Schema`). Generated from them:

  #{Cinder.Next.Schema.live_view_docs()}
  """
  def assign_collection(socket, name, query, opts \\ []) do
    {query, opts} = declared(query, opts)
    {url?, opts} = Keyword.pop(opts, :url, false)
    config = config!(name, query, opts)

    # A URL-synced collection waits for the URL, which `handle_params` brings next
    {collection, effects} = Collection.new(to_string(name), config, if(url?, do: %{}))
    effects = if url?, do: [], else: effects

    socket
    |> put_entry(name, %{collection: collection, url?: url?, loaded?: false})
    |> run(name, effects)
  end

  @doc false
  # The config from a resource or query and keyword lists, checked; also how a
  # `Cinder.Next.Dsl` module is checked when it compiles
  def config!(name, query, opts),
    do: Config.build(to_assigns(name, query, Cinder.Next.Schema.validate_live_view!(opts)))

  # A `Cinder.Next.Dsl` module's declarations, under what only the page knows
  # (`url`, the actor, a prepared `query` instead of the declared resource)
  defp declared(query, opts) do
    if Cinder.Next.Dsl.collection?(query) do
      {resource, declared} = Keyword.pop(Cinder.Next.Dsl.options(query), :resource)
      {opts[:query] || resource, Keyword.merge(declared, Keyword.delete(opts, :query))}
    else
      {query, opts}
    end
  end

  # The slots `Cinder.Next.collection/1` would get, from keyword lists
  defp to_assigns(name, query, opts) do
    {query_key, query} = if is_atom(query), do: {:resource, query}, else: {:query, query}
    {load, opts} = Keyword.pop(opts, :load)
    query_opts = Keyword.get(opts, :query_opts, []) ++ if(load, do: [load: load], else: [])

    opts
    |> Keyword.drop([:filters, :arguments, :sorts, :bulk_actions, :search, :query_opts, :group])
    |> Map.new()
    |> Map.merge(%{
      query_key => query,
      :id => to_string(name),
      :query_opts => query_opts,
      :search => opts[:search],
      :group => group(opts[:group]),
      :filter => Enum.map(opts[:filters] || [], &filter_slot/1),
      :argument => Enum.map(opts[:arguments] || [], &slot(:argument, :name, &1, :type)),
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

  # `[type: :slider, min: 0]` reads flat; the keys a `<:filter>` doesn't declare
  # are the type's own `opts`
  defp filter_slot(entry) do
    slot = slot(:filter, :field, entry, :type)
    {own, opts} = Map.split(slot, [:__slot__, :inner_block | Cinder.Next.Schema.filter_keys()])

    if opts == %{},
      do: own,
      else: Map.put(own, :opts, Keyword.merge(Map.to_list(opts), Map.get(own, :opts, [])))
  end

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
    with [event_name, event] <- String.split(rest, ":", parts: 2),
         {name, %{collection: collection}} <- entry(socket, event_name) do
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
         update_collection(socket, name, Collection.async_loaded(entry.collection, result))}
    end
  end

  defp handle_async(_name, _result, socket), do: {:cont, socket}

  # Collections are kept by their declared name (an atom); events name them as text
  defp entry(socket, event_name),
    do:
      Enum.find(socket.assigns.__cinder__, fn {name, _entry} ->
        Atom.to_string(name) == event_name
      end)

  defp run(socket, name, effects) do
    Enum.reduce(effects, socket, fn
      :load, socket ->
        load(socket, name)

      {:url, params}, socket ->
        Cinder.UrlSync.update_url(socket, params, socket.assigns[:__cinder_uri__])

      {:columns_changed, fun, prefs}, socket ->
        tap(socket, fn _ -> fun.(prefs) end)
    end)
  end

  defp load(socket, name) do
    socket = mark_loaded(socket, name)

    case Collection.start_load(socket.assigns.__cinder__[name].collection) do
      {:done, collection} ->
        update_collection(socket, name, collection)

      {:async, collection, run} ->
        socket |> update_collection(name, collection) |> start_async({:cinder, name}, run)
    end
  end

  defp put_entry(socket, name, entry) do
    socket
    |> assign(:__cinder__, Map.put(socket.assigns.__cinder__, name, entry))
    |> update_collection(name, entry.collection)
  end

  # The view-model is what the template sees, under the name it was declared with
  defp update_collection(socket, name, collection) do
    entry = Map.put(socket.assigns.__cinder__[name], :collection, collection)

    socket
    |> assign(:__cinder__, Map.put(socket.assigns.__cinder__, name, entry))
    |> assign(name, Collection.view(collection, {:live_view, name}))
  end

  defp mark_loaded(socket, name),
    do: assign(socket, :__cinder__, put_in(socket.assigns.__cinder__, [name, :loaded?], true))
end
