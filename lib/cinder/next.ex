defmodule Cinder.Next do
  @moduledoc """
  Spike: a new collection shell on Cinder's existing query engine (7CC-158).

  `collection/1` turns its slots into plain config here, in a function
  component, and mounts `Cinder.Next.Component` with that config. Raw slots are
  never passed to the LiveComponent as top-level assigns, which crashes after a
  `push_patch`.
  """
  use Phoenix.Component

  alias Cinder.Collection

  attr :id, :string, default: "cinder-collection"
  attr :resource, :atom, default: nil
  attr :query, :any, default: nil
  attr :action, :atom, default: nil
  attr :actor, :any, default: nil
  attr :tenant, :any, default: nil
  attr :scope, :any, default: nil
  attr :query_opts, :list, default: []
  attr :page_size, :integer, default: 25
  attr :url_state, :any, default: false

  slot :col do
    attr :field, :string
    attr :label, :string
    attr :filter, :any
    attr :sort, :any
    attr :search, :boolean
  end

  def collection(assigns) do
    query =
      assigns.query || assigns.resource ||
        raise ArgumentError, "a :resource or :query is required"

    resource = Ash.Query.new(query).resource

    assigns =
      assign(assigns, :config, %{
        query: query,
        resource: resource,
        columns: Collection.process_columns(assigns.col, resource),
        action: assigns.action,
        actor: assigns.actor,
        tenant: assigns.tenant,
        scope: assigns.scope,
        query_opts: assigns.query_opts,
        page_size: assigns.page_size
      })

    ~H"""
    <.live_component module={Cinder.Next.Component} id={@id} config={@config} />
    """
  end
end
