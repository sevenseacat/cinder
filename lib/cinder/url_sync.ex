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
          <Cinder.collection
            resource={MyApp.User}
            actor={@current_user}
            url_state={@url_state}
          >
            <:col :let={user} field="name" filter sort>{user.name}</:col>
            <:col :let={user} field="email" filter>{user.email}</:col>
          </Cinder.collection>
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

  # Carrying on to a LiveView without its own `handle_params/3` crashes on patch
  defp params_hook(params, uri, socket) do
    socket = handle_params(params, uri, socket)

    if function_exported?(socket.view, :handle_params, 3),
      do: {:cont, socket},
      else: {:halt, socket}
  end

  defp info_hook({:table_state_change, _table_id, encoded_state}, socket) do
    current_uri = get_in(socket.assigns, [:url_state, :uri])
    {:halt, update_url(socket, encoded_state, current_uri)}
  end

  defp info_hook(_message, socket), do: {:cont, socket}

  @doc """
  Updates the LiveView socket with new URL parameters.

  This function preserves the current path and updates only the query parameters
  with the new collection state.

  ## Parameters

  - `socket` - The LiveView socket
  - `encoded_state` - Map of URL parameters from collection state
  - `current_uri` - Optional current URI string to use for path resolution

  ## Returns

  Updated socket with URL changed via `push_patch/2`
  """
  def update_url(socket, encoded_state, current_uri \\ nil) do
    new_url = build_url(encoded_state, current_uri, socket)
    Phoenix.LiveView.push_patch(socket, to: new_url)
  end

  @doc """
  Builds a new URL by merging collection state with existing query parameters.

  This function is extracted for testing purposes. It builds the URL that
  would be pushed by `update_url/3`.

  ## Parameters

  - `encoded_state` - Map of URL parameters from collection state
  - `current_uri` - Optional current URI string to use for path resolution
  - `socket` - Optional socket for fallback path resolution

  ## Returns

  A string representing the new URL with merged query parameters
  """
  def build_url(encoded_state, current_uri \\ nil, socket \\ nil) do
    # Convert encoded state to string keys and remove empty params
    new_params =
      encoded_state
      |> Enum.map(fn {k, v} -> {to_string(k), v} end)
      |> Enum.into(%{})
      |> remove_empty_params()

    # Get the current path from the URI if provided, otherwise use relative path
    if current_uri do
      uri = URI.parse(current_uri)
      current_path = uri.path || "/"

      # Parse existing query parameters
      existing_params = URI.decode_query(uri.query || "")

      # The collection manages these specific parameter keys
      # Including after/before for keyset pagination
      known_collection_keys = ["page", "sort", "page_size", "search", "after", "before"]

      # Extract filter field names from encoded state (if provided)
      # This tells us exactly which parameters are collection-managed filter fields
      filter_field_names =
        case Map.get(new_params, "_filter_fields") do
          nil -> []
          fields_str -> String.split(fields_str, ",")
        end

      # Remove the metadata key from new_params
      new_params = Map.delete(new_params, "_filter_fields")

      # Build set of all collection-managed parameter keys
      collection_managed_keys =
        MapSet.new(known_collection_keys ++ filter_field_names ++ Map.keys(new_params))

      # Preserve only custom params (those NOT in collection_managed_keys)
      custom_params =
        existing_params
        |> Enum.reject(fn {key, _value} ->
          MapSet.member?(collection_managed_keys, key)
        end)
        |> Enum.into(%{})

      # Merge custom params with new collection state
      merged_params = Map.merge(custom_params, new_params)

      if map_size(merged_params) > 0 do
        query_string = URI.encode_query(merged_params)
        "#{current_path}?#{query_string}"
      else
        current_path
      end
    else
      # Fallback: Extract path from socket's url_state or use root
      fallback_uri =
        if socket do
          get_in(socket.assigns, [:url_state, :uri]) || "/"
        else
          "/"
        end

      current_path =
        if is_binary(fallback_uri) do
          URI.parse(fallback_uri).path || "/"
        else
          "/"
        end

      if map_size(new_params) > 0 do
        query_string = URI.encode_query(new_params)
        "#{current_path}?#{query_string}"
      else
        # No parameters - clear query string but keep current path
        current_path
      end
    end
  end

  @doc """
  Decodes URL parameters into a collection's state: its `:filters`, `:current_page`,
  `:sort_by`, `:page_size`, `:search_term`, and keyset `:after` and `:before`.

  Without the collection's columns, filters are only partly decoded and the sort isn't
  checked. This isn't what `url_state` takes: `use Cinder.UrlSync` builds that for you.
  """
  def extract_url_state(params) when is_map(params) do
    # Handle case where sort_by might be an empty list (causing UrlManager error)
    safe_params =
      Map.update(params, "sort", nil, fn
        [] -> nil
        # Convert lists to nil
        sort when is_list(sort) -> nil
        sort -> sort
      end)

    # There are no columns here yet, so the sort is only parsed, not checked. The
    # component checks it against its columns before applying it.
    decode_unchecked(safe_params)
  end

  @doc """
  The same as `extract_url_state/1`.
  """
  def extract_collection_state(params) when is_map(params) do
    # Handle case where sort_by might be an empty list (causing UrlManager error)
    safe_params =
      Map.update(params, "sort", nil, fn
        [] -> nil
        # Convert lists to nil
        sort when is_list(sort) -> nil
        sort -> sort
      end)

    # There are no columns here yet: filter details may be lost (which is why the raw
    # params are kept in url_state too), and the sort is only parsed, not checked. The
    # component checks it against its columns before applying it.
    decode_unchecked(safe_params)
  end

  defp decode_unchecked(params) do
    params
    |> Cinder.UrlManager.decode_state([])
    |> Map.put(:sort_by, Cinder.UrlManager.parse_sort(params["sort"]))
  end

  @doc false
  @deprecated "Use extract_collection_state/1 instead"
  def extract_table_state(params), do: extract_collection_state(params)

  # Private helper functions

  defp remove_empty_params(params) do
    params
    |> Enum.reject(fn {k, v} ->
      is_nil(v) or v == "" or (v == "1" and String.contains?(to_string(k), "page"))
    end)
    |> Enum.into(%{})
  end

  @doc """
  Assigns `@url_state` from the URL parameters. `use Cinder.UrlSync` calls it for you, before
  your own `handle_params/3`, so you don't need to.

  ## Parameters

  - `params` - URL parameters from `handle_params/3`
  - `uri` - Current URI from `handle_params/3` (optional but recommended)
  - `socket` - The LiveView socket

  ## Returns

  Updated socket with `:url_state` assign containing:
  - `filters` - Raw URL parameters for proper filter decoding
  - `current_page` - Current page number
  - `sort_by` - Sort configuration
  - `uri` - Current URI for URL generation

  """
  def handle_params(params, uri \\ nil, socket) do
    collection_state = extract_collection_state(params)

    url_state = %{
      # Raw params for proper filter decoding
      filters: params,
      current_page: collection_state.current_page,
      sort_by: collection_state.sort_by,
      uri: uri
    }

    assign(socket, :url_state, url_state)
  end

  @doc """
  Returns `@url_state` from a socket's assigns, or `nil`:

      Cinder.UrlSync.get_url_state(socket.assigns)

  It contains:
  - filters: Raw URL parameters for proper filter decoding
  - current_page: Current page number
  - sort_by: Sort configuration
  - uri: Current URI
  """
  def get_url_state(socket_assigns) do
    Map.get(socket_assigns, :url_state, nil)
  end
end
