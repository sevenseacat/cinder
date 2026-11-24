# SPDX-FileCopyrightText: 2025 Cinder contributors <https://github.com/sevenseacat/cinder/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Cinder.UrlSync do
  @moduledoc """
  Keeps a collection's filters, sorting, search and page in the URL.

  ## Usage

  1. Add `use Cinder.UrlSync` to your LiveView, after `use MyAppWeb, :live_view`
     (or `use Phoenix.LiveView`).
  2. Pass `url_state={@url_state}` to your collection.

  ## Example

      defmodule MyAppWeb.UsersLive do
        use MyAppWeb, :live_view
        use Cinder.UrlSync

        def mount(_params, _session, socket) do
          {:ok, assign(socket, :current_user, get_current_user())}
        end

        def render(assigns) do
          ~H\"\"\"
          <Cinder.Next.collection
            id="users"
            resource={MyApp.User}
            actor={@current_user}
            url_state={@url_state}
          >
            <:field :let={user} name="name" filter sort>{user.name}</:field>
            <:field :let={user} name="email" filter>{user.email}</:field>
          </Cinder.Next.collection>
          \"\"\"
        end
      end

  Your LiveView can still have its own `handle_params/3` and `handle_info/2`: they run as
  usual, and `@url_state` is already assigned when `handle_params/3` runs.

  ## Custom URL Parameters

  The URL sync helper automatically preserves custom (non-collection) query parameters
  while managing collection state. The collection component knows which parameters it manages
  (filters, page, sort, page_size, search) and will preserve any other parameters
  in the URL.

  For example:

      # URL with custom params and collection state
      /users?tab=overview&view=grid&name=john&page=2

      # When "name" filter is cleared, custom params are preserved
      /users?tab=overview&view=grid&page=2

      # When navigating to a different page, custom params remain
      /users?tab=overview&view=grid&page=3

  You can use any parameter names for custom state without worrying about conflicts
  with collection parameters. The collection automatically tracks which filter fields it manages
  and will only remove those when filters are cleared.
  """

  import Phoenix.Component, only: [assign: 3]

  @doc """
  Adds URL sync to a LiveView. It must come after `use Phoenix.LiveView` (or
  `use MyAppWeb, :live_view`).

  Adds `on_mount Cinder.UrlSync`, and a `handle_params/3` that does nothing, which your
  LiveView can replace with its own.
  """
  defmacro __using__(_opts) do
    # `on_mount` needs `use Phoenix.LiveView` to have run, and this order never used to
    # matter, so say how to fix it. (Checked as the module body runs: the earlier `use`
    # hasn't set `@behaviour` yet while this macro expands.)
    quote do
      unless Phoenix.LiveView in List.wrap(Module.get_attribute(__MODULE__, :behaviour)) do
        raise CompileError,
          file: unquote(__CALLER__.file),
          line: unquote(__CALLER__.line),
          description:
            "`use Cinder.UrlSync` must come after `use Phoenix.LiveView` (or `use MyAppWeb, :live_view`)"
      end

      require Phoenix.LiveView
      Phoenix.LiveView.on_mount(Cinder.UrlSync)

      # A patch calls the LiveView's `handle_params/3` without checking it exists, so
      # without one, some `handle_params` hook has to halt, and that skips the hooks
      # after it (often this one). Having one means no hook needs to halt. (No `@impl`:
      # with one, an override is treated as marked too and never gets the missing-`@impl` warning.)
      def handle_params(_params, _uri, socket), do: {:noreply, socket}
      defoverridable handle_params: 3
    end
  end

  @doc """
  Assigns `@url_state` from the URL, and updates the URL when a collection's state changes.
  `use Cinder.UrlSync` adds it. On its own (`on_mount Cinder.UrlSync`, or on a
  `live_session`), the LiveView needs a `handle_params/3` if any other hook halts without one.
  """
  def on_mount(:default, _params, _session, socket) do
    {:cont,
     socket
     |> Phoenix.LiveView.attach_hook(:cinder_url_sync_params, :handle_params, &params_hook/3)
     |> Phoenix.LiveView.attach_hook(:cinder_url_sync_info, :handle_info, &info_hook/2)}
  end

  # `@url_state` is what a collection reads: the URL's `params`, and the `uri` it patches.
  # Carrying on to a LiveView without its own `handle_params/3` crashes on patch.
  defp params_hook(params, uri, socket) do
    socket = assign(socket, :url_state, %{params: params, uri: uri})

    if function_exported?(socket.view, :handle_params, 3),
      do: {:cont, socket},
      else: {:halt, socket}
  end

  # `patch_later/2`'s message
  defp info_hook({:cinder_url_patch, params, owns}, socket) do
    uri = get_in(socket.assigns, [:url_state, :uri])
    {:halt, patch(socket, uri, params, owns: owns)}
  end

  defp info_hook(_message, socket), do: {:cont, socket}

  # How `Cinder.Next.collection` changes the URL. Its `params` replace every param it
  # `owns` (those it may write, so one it no longer writes goes), and the app's own
  # stay. LiveView calls the LiveView's `handle_params/3` as it patches, so the
  # collection hears of its new URL before the next event.

  @doc false
  # From the collection's socket, or the LiveView's, with the URL it's at (`uri`)
  def patch(socket, uri, params, owns: owns) do
    Phoenix.LiveView.push_patch(socket, to: patched_url(uri || "/", params, owns))
  end

  @doc false
  # For when the collection can't patch itself: while it's being updated, which
  # LiveView doesn't allow. It asks the LiveView to, after the current event, so an
  # event already waiting comes first.
  def patch_later(params, owns: owns), do: send(self(), {:cinder_url_patch, params, owns})

  @doc false
  # Empty params are kept: `params` leaves defaults out already, so an empty one
  # means something (`sort=` is unsorted, where no `sort` is the default sort).
  # The app's params are kept as pairs, in order, as a name can repeat
  def patched_url(uri, params, owns) do
    uri = URI.parse(uri)

    apps =
      for {key, _value} = pair <- URI.query_decoder(uri.query || ""), key not in owns do
        pair
      end

    pairs = apps ++ Enum.sort(params)
    path = uri.path || "/"

    if pairs == [], do: path, else: "#{path}?#{URI.encode_query(pairs)}"
  end
end
