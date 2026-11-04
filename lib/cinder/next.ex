# SPDX-FileCopyrightText: 2026 Cinder contributors <https://github.com/sevenseacat/cinder/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Cinder.Next do
  @moduledoc false
  # The new shell, built alongside the old one until it replaces `Cinder.collection`.

  use Phoenix.Component

  attr :id, :string, required: true, doc: "The collection's id, unique on the page"
  attr :resource, :atom, default: nil, doc: "The Ash resource to read (or give a `query`)"
  attr :query, :any, default: nil, doc: "The Ash query to read (or give a `resource`)"
  attr :actor, :any, default: nil, doc: "The actor to read as"
  attr :tenant, :any, default: nil, doc: "The tenant to read in"
  attr :scope, :any, default: nil, doc: "An Ash scope"

  attr :query_opts, :list,
    default: [],
    doc: "More options for the read, as `Ash.read/2` takes them"

  slot :col, required: true, doc: "A column, showing its content for each record" do
    attr :field, :string, required: true
    attr :label, :string
  end

  # Runs on every parent render, so it only hands everything on: the collection
  # works out what's changed. The id is checked here, as the LiveComponent can't
  # exist without one.
  def collection(assigns) do
    if !assigns[:id] do
      raise ArgumentError, "<Cinder.Next.collection> needs an `id`, unique on the page"
    end

    ~H"""
    <.live_component
      module={Cinder.Next.Collection}
      id={@id}
      options={assigns_to_attributes(assigns, [:col])}
      columns={@col}
    />
    """
  end
end
