defmodule Cinder.TableV2.UrlSync do
  @moduledoc """
  Simple URL synchronization helper for TableV2 components.

  This module provides an easy way to enable URL state synchronization
  for TableV2 components with minimal setup.

  ## Usage

  1. Add `use Cinder.TableV2.UrlSync` to your LiveView
  2. Add `url_sync` to your TableV2 component
  3. That's it! The helper handles all URL updates automatically.

  ## Example

      defmodule MyAppWeb.UsersLive do
        use MyAppWeb, :live_view
        use Cinder.TableV2.UrlSync

        def mount(_params, _session, socket) do
          {:ok, assign(socket, :current_user, get_current_user())}
        end

        def render(assigns) do
          ~H\"\"\"
          <Cinder.TableV2.table
            resource={MyApp.User}
            current_user={@current_user}
            url_sync
          >
            <:col field="name" filter sort>Name</:col>
            <:col field="email" filter>Email</:col>
          </Cinder.TableV2.table>
          \"\"\"
        end
      end

  The helper automatically:
  - Handles `:table_state_change` messages from TableV2 components
  - Updates the URL with new table state
  - Preserves other URL parameters
  - Works with any number of TableV2 components on the same page
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

      This function is automatically injected by `use Cinder.TableV2.UrlSync`.
      It handles `:table_state_change` messages from TableV2 components.
      """
      def handle_info({:table_state_change, _table_id, encoded_state}, socket) do
        current_uri = socket.assigns[:table_current_uri]
        {:noreply, Cinder.TableV2.UrlSync.update_url(socket, encoded_state, current_uri)}
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

      new_url =
        if map_size(new_params) > 0 do
          query_string = URI.encode_query(new_params)
          "#{current_path}?#{query_string}"
        else
          current_path
        end

      Phoenix.LiveView.push_patch(socket, to: new_url)
    else
      # Fallback to relative path update
      if map_size(new_params) > 0 do
        query_string = URI.encode_query(new_params)
        Phoenix.LiveView.push_patch(socket, to: "?#{query_string}")
      else
        # No parameters - clear query string but keep current path
        Phoenix.LiveView.push_patch(socket, to: ".")
      end
    end
  end

  @doc """
  Extracts table state from URL parameters.

  This function can be used in `handle_params/3` to initialize
  table state from URL parameters.

  ## Example

      def handle_params(params, _uri, socket) do
        table_state = Cinder.TableV2.UrlSync.extract_table_state(params)
        socket = assign(socket, :initial_table_state, table_state)
        {:noreply, socket}
      end

  """
  def extract_table_state(params) when is_map(params) do
    # Decode table state from URL parameters
    # We don't have columns context here, but UrlManager handles this
    columns = []

    # Handle case where sort_by might be an empty list (causing UrlManager error)
    safe_params =
      Map.update(params, "sort", nil, fn
        [] -> nil
        # Convert lists to nil
        sort when is_list(sort) -> nil
        sort -> sort
      end)

    Cinder.UrlManager.decode_state(safe_params, columns)
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

  This is a convenience function that can be called from handle_params
  to pass URL state to TableV2 components and store the current URI.

  ## Example

      def handle_params(params, uri, socket) do
        socket = Cinder.TableV2.UrlSync.handle_params(socket, params, uri)
        {:noreply, socket}
      end

  The table component will automatically pick up the state from socket assigns.
  """
  def handle_params(socket, params, uri \\ nil) do
    table_state = extract_table_state(params)

    socket
    |> assign(:table_url_filters, table_state.filters)
    |> assign(:table_url_page, table_state.current_page)
    |> assign(:table_url_sort, table_state.sort_by)
    |> assign(:table_current_uri, uri)
  end
end
