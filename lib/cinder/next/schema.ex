# SPDX-FileCopyrightText: 2026 Cinder contributors <https://github.com/sevenseacat/cinder/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Cinder.Next.Schema do
  @moduledoc false
  # What each of a collection's options is: its type, whether it's required, and its
  # docs, as `Spark.Options` schemas. Only each option on its own: rules about
  # several options together are `Cinder.Next.Config`'s. Errors name the declaration
  # they're about.

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
      type: {:keyword_list, Cinder.Engine.read_opts()},
      doc: "More options for the read, as `Ash.read/2` takes them."
    ],
    sort: [
      type:
        {:keyword_list,
         [
           mode: [
             type: {:in, [:additive, :exclusive]},
             default: :additive,
             doc: "Whether a column clicked adds to the sort (`:additive`) or replaces it."
           ]
         ]},
      default: [],
      doc: "How the collection sorts."
    ],
    search: [
      type:
        {:keyword_list,
         [
           label: [type: :string, doc: "The search box's label. Defaults to \"Search\"."],
           placeholder: [
             type: :string,
             doc: "The search box's placeholder. Defaults to \"Search...\"."
           ],
           fn: [
             type: {:fun, 3},
             doc:
               "Searches instead of a case-insensitive `contains` on each searchable field: " <>
                 "called with the `Ash.Query`, the searchable fields " <>
                 "(`%{name: \"artist.name\", expr: <Ash expression>}`), and the text. " <>
                 "Returns the query."
           ]
         ]},
      default: [],
      doc: "How the collection searches. It has a search box if any field is searchable."
    ],
    pagination: [
      type:
        {:keyword_list,
         [
           mode: [
             type: {:in, [:offset, :keyset]},
             doc: "`:offset` or `:keyset`. By default, offset if the read action can, or keyset."
           ],
           size: [type: :pos_integer, default: 25, doc: "How many records a page shows."]
         ]},
      default: [],
      doc:
        "How the collection pages, if the read action can. " <>
          "Giving this for an action that can't page that way is an error."
    ],
    url_state: [
      type: {:or, [nil, :map]},
      doc:
        "The LiveView's `@url_state`, from `use Cinder.UrlSync`, " <>
          "to keep the sort, filters, search and page in the URL."
    ]
  ]

  @directions [:asc, :desc, :asc_nils_first, :asc_nils_last, :desc_nils_first, :desc_nils_last]

  # Cinder's own keys in a `<:field>`'s `filter`. Any others are the filter type's
  # options, split off before Spark sees them.
  @filter [
    type: [type: :atom, doc: "The filter type. Inferred from the field if not given."],
    label: [type: :string, doc: "The control's label. Defaults to the column's."]
  ]

  @field [
    name: [type: :string, required: true, doc: "The field's name, or path (`artist.name`)."],
    label: [type: :string, doc: "The column's heading. Defaults to the humanised name."],
    column: [
      type: :boolean,
      default: true,
      doc: "Whether it's a column. If not, it has no heading or cells, and needs no content."
    ],
    search: [type: :boolean, default: false, doc: "Search the field from the search box."],
    # `sort` and `filter` alone (`true`) mean `[]`, and `false` is left out, before this
    sort: [
      type:
        {:keyword_list,
         [
           cycle: [
             type: {:list, {:in, [nil | @directions]}},
             default: [nil, :asc, :desc],
             doc:
               "The directions clicking the heading steps through. Without `nil`, it's always sorted."
           ]
         ]},
      doc: "Sort by the field, by clicking its heading: `sort`, or `sort={[cycle: [...]]}`."
    ],
    filter: [
      type: {:keyword_list, @filter},
      doc:
        "Filter by the field: `filter`, or `filter={[type: ..., label: ..., ...]}` " <>
          "with the type's own options."
    ]
  ]

  def collection, do: @collection
  def field, do: @field

  @doc "The collection's options, checked."
  def validate_collection!(options) do
    declaration = ~s(<Cinder.Next.collection id="#{options[:id]}">)
    check_query_opts!(options[:query_opts] || [], declaration)

    # Checking `query_opts` against the read options' schema fills in Ash's
    # defaults, which are Ash's to apply: only the options given are kept
    options
    |> validate!(@collection, declaration)
    |> Keyword.replace(:query_opts, options[:query_opts])
  end

  # Before the schema, which would only call these unknown: `select`, and the
  # collection's own attributes (such as `actor` and `tenant`)
  defp check_query_opts!(query_opts, declaration) do
    explained = [:select | Keyword.keys(@collection) -- Keyword.keys(Cinder.Engine.read_opts())]

    if Keyword.keyword?(query_opts) do
      case Enum.find(Keyword.keys(query_opts), &(&1 in explained)) do
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

  @doc """
  A `<:field>` slot entry's attributes, checked. A filter's type options come back
  under its `options` key, unchecked: they're the type's to check.
  """
  def validate_field!(slot) do
    attributes =
      slot
      |> Map.drop([:__slot__, :inner_block])
      |> Enum.flat_map(&shorthand/1)

    {attributes, filter_options} = split_filter_options(attributes)

    attributes
    |> validate!(@field, ~s(<:field name="#{slot[:name]}">))
    |> Keyword.replace_lazy(:filter, &Keyword.put(&1, :options, filter_options))
  end

  # Spark rejects keys its schema doesn't have, and a type's options can be anything
  defp split_filter_options(attributes) do
    with filter when is_list(filter) <- attributes[:filter],
         true <- Keyword.keyword?(filter) do
      {own, options} = Keyword.split(filter, Keyword.keys(@filter))
      {Keyword.put(attributes, :filter, own), options}
    else
      _not_a_keyword_list -> {attributes, []}
    end
  end

  # One shape for each option, so an error is about that shape alone
  defp shorthand({key, true}) when key in [:sort, :filter], do: [{key, []}]
  defp shorthand({key, false}) when key in [:sort, :filter], do: []
  defp shorthand(attribute), do: [attribute]

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
