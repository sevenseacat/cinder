defmodule Cinder.Table.UrlSync do
  @moduledoc """
  Simple URL synchronization helper for Table components.

  This module provides an easy way to enable URL state synchronization
  for Table components with minimal setup.

  ## Usage

  1. Add `use Cinder.Table.UrlSync` to your LiveView
  2. Call `Cinder.Table.UrlSync.handle_params/3` in your `handle_params/3` callback
  3. Pass `url_state={@url_state}` to your Table component
  4. That's it! The helper handles all URL updates automatically.

  ## Example

      defmodule MyAppWeb.UsersLive do
        use MyAppWeb, :live_view
        use Cinder.Table.UrlSync

        def mount(_params, _session, socket) do
          {:ok, assign(socket, :current_user, get_current_user())}
        end

        def handle_params(params, uri, socket) do
          socket = Cinder.Table.UrlSync.handle_params(params, uri, socket)
          {:noreply, socket}
        end

        def render(assigns) do
          ~H\"\"\"
          <Cinder.Table.table
            resource={MyApp.User}
            actor={@current_user}
            url_state={@url_state}
          >
            <:col :let={user} field="name" filter sort>{user.name}</:col>
            <:col :let={user} field="email" filter>{user.email}</:col>
          </Cinder.Table.table>
          \"\"\"
        end

        # Or with a pre-configured query:
        def render_with_query(assigns) do
          ~H\"\"\"
          <Cinder.Table.table
            query={MyApp.User |> Ash.Query.filter(active: true)}
            actor={@current_user}
            url_state={@url_state}
          >
            <:col :let={user} field="name" filter sort>{user.name}</:col>
            <:col :let={user} field="email" filter>{user.email}</:col>
          </Cinder.Table.table>
          \"\"\"
        end
      end

  The helper automatically:
  - Handles `:table_state_change` messages from Table components
  - Updates the URL with new table state
  - Preserves other URL parameters
  - Works with any number of Table components on the same page
  """

  import Phoenix.Component, only: [assign: 3]

  @doc """
  Adds URL sync support to a LiveView.

  This macro injects the necessary `handle_info/2` callback to handle
  table state changes and update the URL accordingly.
  """
  defmacro __using__(_opts) do
    quote do
      @doc """
      Handles table state changes and updates the URL.

      This function is automatically injected by `use Cinder.Table.UrlSync`.
      It handles `:table_state_change` messages from Table components.
      """
      def handle_info({:table_state_change, _table_id, encoded_state}, socket) do
        current_uri = get_in(socket.assigns, [:url_state, :uri])
        {:noreply, Cinder.Table.UrlSync.update_url(socket, encoded_state, current_uri)}
      end
    end
  end

  @doc """
  Updates the LiveView socket with new URL parameters.

  This function preserves the current path and updates only the query parameters
  with the new table state.

  ## Parameters

  - `socket` - The LiveView socket
  - `encoded_state` - Map of URL parameters from table state
  - `current_uri` - Optional current URI string to use for path resolution

  ## Returns

  Updated socket with URL changed via `push_patch/2`
  """
  def update_url(socket, encoded_state, current_uri \\ nil) do
    new_url = build_url(encoded_state, current_uri, socket)
    Phoenix.LiveView.push_patch(socket, to: new_url)
  end

  @doc """
  Builds a new URL by merging table state with existing query parameters.

  This function is extracted for testing purposes. It builds the URL that
  would be pushed by `update_url/3`.

  ## Parameters

  - `encoded_state` - Map of URL parameters from table state
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

      # Merge existing params with new params (new params take precedence)
      merged_params = Map.merge(existing_params, new_params)

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
  Extracts complete URL state from URL parameters for use with table components.

  This function can be used in `handle_params/3` to initialize
  URL state for table components.

  ## Example

      def handle_params(params, _uri, socket) do
        url_state = Cinder.Table.UrlSync.extract_url_state(params)
        socket = assign(socket, :url_state, url_state)
        {:noreply, socket}
      end

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

    # Use empty columns list since we don't have column context here
    Cinder.UrlManager.decode_state(safe_params, [])
  end

  @doc """
  Extracts table state from URL parameters using empty columns list.

  This function provides a simplified extraction that works without column
  metadata. It preserves page and sort information but may not fully decode
  filters (which is why we also preserve raw params in handle_params).

  ## Parameters

  - `params` - URL parameters map

  ## Returns

  Map with `:filters`, `:current_page`, and `:sort_by` keys
  """
  def extract_table_state(params) when is_map(params) do
    # Handle case where sort_by might be an empty list (causing UrlManager error)
    safe_params =
      Map.update(params, "sort", nil, fn
        [] -> nil
        # Convert lists to nil
        sort when is_list(sort) -> nil
        sort -> sort
      end)

    # Use empty columns list - this will preserve page/sort but may lose filter details
    # That's why we also preserve raw params in the url_state
    Cinder.UrlManager.decode_state(safe_params, [])
  end

  # Private helper functions

  defp remove_empty_params(params) do
    params
    |> Enum.reject(fn {k, v} ->
      is_nil(v) or v == "" or (v == "1" and String.contains?(to_string(k), "page"))
    end)
    |> Enum.into(%{})
  end

  @doc """
  Helper function to handle table state in LiveView handle_params.

  This function extracts URL parameters and creates a URL state object that
  can be passed to Table components. It should be called from your LiveView's
  `handle_params/3` callback.

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

  ## Example

      def handle_params(params, uri, socket) do
        socket = Cinder.Table.UrlSync.handle_params(params, uri, socket)
        {:noreply, socket}
      end

      def render(assigns) do
        ~H\"\"\"
        <Cinder.Table.table
          resource={MyApp.User}
          actor={@current_user}
          url_state={@url_state}
        >
          <:col :let={user} field="name" filter sort>{user.name}</:col>
        </Cinder.Table.table>
        \"\"\"
      end

  The `@url_state` assign will be available for use with the Table component.
  """
  def handle_params(params, uri \\ nil, socket) do
    table_state = extract_table_state(params)

    url_state = %{
      # Raw params for proper filter decoding
      filters: params,
      current_page: table_state.current_page,
      sort_by: table_state.sort_by,
      uri: uri
    }

    assign(socket, :url_state, url_state)
  end

  @doc """
  Helper to get the URL state for passing to table components.

  Use this to get the URL state object created by `handle_params/3`.

  ## Example

      def render(assigns) do
        ~H\"\"\"
        <Cinder.Table.table
          resource={Album}
          actor={@current_user}
          url_state={@url_state}
          theme="minimal"
        >
          <:col :let={album} field="name" filter="text">{album.name}</:col>
          <:col :let={album} field="artist.name" filter="text">{album.artist.name}</:col>
        </Cinder.Table.table>
        \"\"\"
      end

  The URL state object contains:
  - filters: Raw URL parameters for proper filter decoding
  - current_page: Current page number
  - sort_by: Sort configuration
  - uri: Current URI
  """
  def get_url_state(socket_assigns) do
    Map.get(socket_assigns, :url_state, nil)
  end
end
