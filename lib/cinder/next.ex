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

  attr :action, :any,
    default: nil,
    doc: "The read action, if not the query's or the primary read (atom or string)"

  attr :actor, :any, default: nil, doc: "The actor to read as"
  attr :tenant, :any, default: nil, doc: "The tenant to read in"
  attr :scope, :any, default: nil, doc: "An Ash scope"

  attr :query_opts, :list,
    default: [],
    doc: "More options for the read, as `Ash.read/2` takes them"

  attr :sort, :list,
    default: [],
    doc: "How the collection sorts: `[mode: :additive | :exclusive]`"

  attr :search, :list,
    default: [],
    doc: "How the collection searches: `[label: ..., placeholder: ..., fn: ...]`"

  attr :pagination, :list, default: [], doc: "How the collection pages: `[mode: ..., size: ...]`"

  attr :url_state, :map,
    default: nil,
    doc: "The LiveView's `@url_state` (`use Cinder.UrlSync`), to keep its state in the URL"

  attr :selectable, :any,
    default: false,
    doc: "Whether records can be selected: `true`, or a function given each record"

  attr :on_selection_change, :atom,
    default: nil,
    doc: "A message to send the LiveView when the selection changes"

  attr :on_bulk_action_result, :atom,
    default: nil,
    doc: "A message to send the LiveView when a bulk action has run"

  slot :field,
    required: true,
    doc: "A field, shown as a column with its content for each record" do
    attr :name, :string, required: true
    attr :label, :string

    attr :column, :boolean,
      doc: "Whether it's a column (default `true`). One that isn't can still be filtered."

    attr :sort, :any, doc: "Sort by the field: `true`, or `[cycle: [...]]`"

    attr :filter, :any,
      doc:
        "Filter by the field: `true`, or `[type: ..., label: ..., ...]` with the type's options"

    attr :search, :boolean, doc: "Search the field from the search box"
  end

  slot :argument,
    doc:
      "A read action argument, with an input for its value. Unlike a filter's, a new " <>
        "value clears the selection, as it changes what the action reads." do
    attr :name, :string, required: true
    attr :param, :string, doc: "What it goes by in the form and the URL, if not its name"

    attr :input, :list,
      doc: "Its input, as a filter's: `[type: ..., label: ..., ...]` with the type's options"
  end

  slot :bulk_action, doc: "An action to run on the selected records, with a button" do
    attr :action, :any,
      required: true,
      doc: "An update or destroy action, or a function given a query for the selected records"

    attr :name, :string, doc: "What it goes by in events. Defaults to the action's name."
    attr :label, :string, doc: "Its button's text. Defaults to the humanised name."
    attr :confirm, :string, doc: "A question to confirm before it runs, with `{count}`"

    attr :action_opts, :list,
      doc: "More options for the action: Ash's bulk update or destroy options, or the function's"
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
      options={assigns_to_attributes(assigns, [:field, :argument, :bulk_action])}
      fields={@field}
      arguments={@argument}
      bulk_actions={@bulk_action}
    />
    """
  end
end
