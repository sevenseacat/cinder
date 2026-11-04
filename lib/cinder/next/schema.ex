# SPDX-FileCopyrightText: 2026 Cinder contributors <https://github.com/sevenseacat/cinder/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Cinder.Next.Schema do
  @moduledoc false
  # What each of a collection's options is: its type, whether it's required, and its
  # docs, as `Spark.Options` schemas. Only each option on its own: rules about
  # several options together are `Cinder.Next.Config`'s. Errors name the declaration
  # they're about.

  # Read options the collection sets from its own attributes (or will: `action` and
  # `page`), so they can't also be given in `query_opts`
  @own_read_opts [:action, :actor, :tenant, :scope, :page, :return_query?]

  @collection [
    id: [type: :string, required: true, doc: "The collection's id, unique on the page."],
    resource: [type: {:spark, Ash.Resource}, doc: "The Ash resource to read (or give a `query`)."],
    query: [type: {:struct, Ash.Query}, doc: "The Ash query to read (or give a `resource`)."],
    actor: [type: :any, doc: "The actor to read as."],
    tenant: [type: :any, doc: "The tenant to read in."],
    scope: [
      type: {:protocol, Ash.Scope.ToOpts},
      doc: "An Ash scope. An `actor` or `tenant` given as well wins over the scope's, as in Ash."
    ],
    query_opts: [
      type: {:keyword_list, Keyword.drop(Ash.read_opts(), @own_read_opts)},
      doc: "More options for the read, as `Ash.read/2` takes them."
    ]
  ]

  @col [
    field: [type: :string, required: true, doc: "The field the column shows."],
    label: [type: :string, doc: "The column's heading. Defaults to the humanised field."]
  ]

  def collection, do: @collection
  def col, do: @col

  @doc "The collection's options, checked."
  def validate_collection!(options) do
    declaration = ~s(<Cinder.Next.collection id="#{options[:id]}">)
    check_query_opts!(options[:query_opts] || [], declaration)

    # Checking `query_opts` against Ash's schema fills in Ash's defaults, which are
    # Ash's to apply: only the options given are kept
    options
    |> validate!(@collection, declaration)
    |> Keyword.replace(:query_opts, options[:query_opts])
  end

  # Before the schema, which would only call these unknown
  defp check_query_opts!(query_opts, declaration) do
    if Keyword.keyword?(query_opts) do
      case Enum.find(Keyword.keys(query_opts), &(&1 in [:select | @own_read_opts])) do
        nil ->
          :ok

        :select ->
          raise ArgumentError,
                "#{declaration}: `select` isn't a read option: " <>
                  "select on the query instead, as in query={Ash.Query.select(Resource, [...])}"

        key ->
          raise ArgumentError,
                "#{declaration}: give `#{key}` as the collection's own attribute, not in `query_opts`"
      end
    end
  end

  @doc "A `<:col>` slot entry's attributes, checked."
  def validate_col!(slot) do
    attributes = slot |> Map.drop([:__slot__, :inner_block]) |> Enum.to_list()
    validate!(attributes, @col, ~s(<:col field="#{slot[:field]}">))
  end

  # Unset attrs arrive as `nil`, which means "not given"
  defp validate!(options, schema, declaration) do
    options = Enum.reject(options, fn {_key, value} -> is_nil(value) end)

    case Spark.Options.validate(options, schema) do
      {:ok, options} -> options
      {:error, error} -> raise ArgumentError, "#{declaration}: #{message(error)}"
    end
  end

  # Spark's message for a protocol type doesn't say which option it's about
  defp message(%{key: key} = error) when is_atom(key) do
    message = Exception.message(error)

    if String.contains?(message, inspect(key)) do
      message
    else
      "invalid value for #{inspect(key)} option: #{message}"
    end
  end

  defp message(error), do: Exception.message(error)
end
