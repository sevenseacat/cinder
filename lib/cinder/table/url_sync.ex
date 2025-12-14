defmodule Cinder.Table.UrlSync do
  @moduledoc """
  URL synchronization helper for collection components.

  **DEPRECATED**: This module has been moved to `Cinder.UrlSync`.
  Please update your code to use `Cinder.UrlSync` instead.

  ## Migration

      # OLD
      use Cinder.Table.UrlSync
      Cinder.Table.UrlSync.handle_params(params, uri, socket)

      # NEW
      use Cinder.UrlSync
      Cinder.UrlSync.handle_params(params, uri, socket)

  This module will be removed in version 1.0.
  """

  require Logger

  @deprecated "Use Cinder.UrlSync instead"
  defmacro __using__(_opts) do
    quote do
      require Logger

      Logger.warning(
        "Cinder.Table.UrlSync is deprecated. Use `use Cinder.UrlSync` instead. " <>
          "This will be removed in Cinder 1.0."
      )

      def handle_info({:table_state_change, _table_id, encoded_state}, socket) do
        current_uri = get_in(socket.assigns, [:url_state, :uri])
        {:noreply, Cinder.UrlSync.update_url(socket, encoded_state, current_uri)}
      end
    end
  end

  @deprecated "Use Cinder.UrlSync.update_url/3 instead"
  defdelegate update_url(socket, encoded_state, current_uri \\ nil), to: Cinder.UrlSync

  @deprecated "Use Cinder.UrlSync.build_url/3 instead"
  defdelegate build_url(encoded_state, current_uri \\ nil, socket \\ nil), to: Cinder.UrlSync

  @deprecated "Use Cinder.UrlSync.extract_url_state/1 instead"
  defdelegate extract_url_state(params), to: Cinder.UrlSync

  @deprecated "Use Cinder.UrlSync.extract_collection_state/1 instead"
  defdelegate extract_table_state(params), to: Cinder.UrlSync, as: :extract_collection_state

  @deprecated "Use Cinder.UrlSync.handle_params/3 instead"
  defdelegate handle_params(params, uri \\ nil, socket), to: Cinder.UrlSync

  @deprecated "Use Cinder.UrlSync.get_url_state/1 instead"
  defdelegate get_url_state(socket_assigns), to: Cinder.UrlSync
end
