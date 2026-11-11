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
    action: [
      type: {:or, [:atom, :string]},
      doc:
        "The read action, if not the query's or the primary read. " <>
          "Give it here, not in the query, for its arguments to be given."
    ],
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
    ],
    selectable: [
      type: {:or, [:boolean, {:fun, 1}]},
      default: false,
      doc:
        "Whether records can be selected, with a box each: `true`, or a function " <>
          "given each record, for only some. Records are told apart by their primary key."
    ],
    on_selection_change: [
      type: :atom,
      doc:
        "A message to send the LiveView when the selection changes: " <>
          "`{name, %{selected_ids:, selected_count:, component_id:}}`."
    ],
    on_bulk_action_result: [
      type: :atom,
      doc:
        "A message to send the LiveView when a bulk action has run: " <>
          "`{name, %{bulk_action:, status:, selected_count:, result:, errors:, component_id:}}`. " <>
          "`status` is `:success`, `:partial_success` (some records failed, and the rest " <>
          "changed) or `:error`. `selected_count` is how many records were selected: one the " <>
          "read no longer reaches is skipped, so for how many changed, give the action " <>
          "`action_opts={[return_records?: true]}` and count `result.records`."
    ]
  ]

  @directions [:asc, :desc, :asc_nils_first, :asc_nils_last, :desc_nils_first, :desc_nils_last]

  # Cinder's own keys in a `<:field>`'s `filter`. Any others are the filter type's
  # options, split off before Spark sees them.
  @filter [
    type: [type: :atom, doc: "The filter type. Inferred from the field if not given."],
    label: [type: :string, doc: "The control's label. Defaults to the column's."]
  ]

  # The same for an `<:argument>`'s `input`
  @input [
    type: [type: :atom, doc: "The input type. Inferred from the argument if not given."],
    label: [type: :string, doc: "The input's label. Defaults to the humanised name."]
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

  @argument [
    name: [type: :string, required: true, doc: "The read action argument's name."],
    param: [
      type: :string,
      doc:
        "What it goes by in the form and the URL, if not its name: " <>
          "for a name that's a field's, or one of the collection's own URL params."
    ],
    input: [
      type: {:keyword_list, @input},
      default: [],
      doc:
        "Its input, as a filter's: `input={[type: ..., label: ..., ...]}` " <>
          "with the type's own options."
    ]
  ]

  @bulk_action [
    action: [
      type: {:or, [:atom, :string, {:fun, 2}]},
      required: true,
      doc:
        "What runs on the selected records: an update or destroy action, or a function " <>
          "given a query for them and the options to run it with (`actor`, `tenant`, `scope`)."
    ],
    name: [
      type: :string,
      doc: "What it goes by in events, unique to the collection. Defaults to the action's name."
    ],
    label: [type: :string, doc: "Its button's text. Defaults to the humanised name."],
    confirm: [
      type: :string,
      doc: "A question to confirm before it runs. `{count}` is how many records are selected."
    ],
    action_opts: [
      type: :keyword_list,
      doc:
        "More options to run it with: `Ash.bulk_update/4`'s or `Ash.bulk_destroy/4`'s for " <>
          "an update or destroy action, and a function gets them as `bulk_options`, as a " <>
          "code interface takes them."
    ]
  ]

  def collection, do: @collection
  def field, do: @field
  def argument, do: @argument
  def bulk_action, do: @bulk_action

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

    {attributes, filter_options} = split_type_options(attributes, :filter, @filter)

    attributes
    |> validate!(@field, ~s(<:field name="#{slot[:name]}">))
    |> Keyword.replace_lazy(:filter, &Keyword.put(&1, :options, filter_options))
  end

  @doc """
  An `<:argument>` slot entry's attributes, checked. Its input's type options come
  back under its `options` key, unchecked, as a filter's do.
  """
  def validate_argument!(slot) do
    {attributes, input_options} =
      slot
      |> Map.drop([:__slot__, :inner_block])
      |> Enum.to_list()
      |> split_type_options(:input, @input)

    attributes
    |> validate!(@argument, ~s(<:argument name="#{slot[:name]}">))
    |> Keyword.update!(:input, &Keyword.put(&1, :options, input_options))
  end

  @doc "A `<:bulk_action>` slot entry's attributes, checked."
  def validate_bulk_action!(slot) do
    slot
    |> Map.drop([:__slot__, :inner_block])
    |> validate!(@bulk_action, bulk_action_declaration(slot))
  end

  @doc "How errors name a `<:bulk_action>`: by its name, or its action's."
  def bulk_action_declaration(slot) do
    case slot[:name] || slot[:action] do
      unnamed when is_function(unnamed) or is_nil(unnamed) -> "<:bulk_action>"
      name -> ~s(<:bulk_action name="#{name}">)
    end
  end

  # Spark rejects keys its schema doesn't have, and a type's options can be anything
  defp split_type_options(attributes, key, schema) do
    with given when is_list(given) <- attributes[key],
         true <- Keyword.keyword?(given) do
      {own, options} = Keyword.split(given, Keyword.keys(schema))
      {Keyword.put(attributes, key, own), options}
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
