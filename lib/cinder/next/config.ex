# SPDX-FileCopyrightText: 2026 Cinder contributors <https://github.com/sevenseacat/cinder/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Cinder.Next.Config do
  @moduledoc false
  # What a collection's template declares, built into what it runs from: where its
  # records come from, its columns, and its fields for the engine. Each option is
  # checked by `Cinder.Next.Schema` first; this checks the rules about several
  # together. Any mistake is the developer's, so it raises.

  alias Cinder.Engine
  alias Cinder.Next.Schema
  alias Cinder.Params

  # The actor, tenant and scope are kept as given: Ash applies its own precedence.
  # `sort` is the mode, and the default: the sort the collection starts with.
  # `filters` are the filter controls: the column map their type renders from (with
  # the column's label), and the type's module.
  # `search` is the search box's options, or `nil` when no field is searchable.
  # `pagination` is the mode, the page size and whether to count, or `nil` when the
  # action doesn't page.
  # `action` is the read action's name, and `arguments` the ones the user gives
  # values for. `argument_inputs` are their controls, as `filters` are.
  # `selectable` is as given (`false`, `true` or a function), and `primary_key` the
  # attribute selected records are told apart by, when they can be.
  # `bulk_actions` are what can run on the selected records, each with its name (in
  # events), label and confirmation, and the engine's `Cinder.Engine.BulkAction`.
  defstruct [
    :source,
    :action,
    :actor,
    :tenant,
    :scope,
    :primary_key,
    :on_selection_change,
    :on_bulk_action_result,
    selectable: false,
    columns: [],
    fields: [],
    filters: [],
    arguments: [],
    argument_inputs: [],
    bulk_actions: [],
    query_opts: [],
    search: nil,
    pagination: nil,
    sort: %{mode: :additive, default: []}
  ]

  @doc """
  The parts of the declarations that decide the config. A `<:field>`'s inner block
  closes over the parent's assigns, so it's new on every render, and is left out,
  as is `url_state`, which is the user's state rather than the config.
  """
  def declarations(options, field_slots, argument_slots, bulk_action_slots) do
    {Keyword.delete(options, :url_state), Enum.map(field_slots, &Map.drop(&1, [:inner_block])),
     argument_slots, bulk_action_slots}
  end

  def build(options, field_slots, argument_slots, bulk_action_slots) do
    # The schema fills in the page size, so whether `pagination` was given is asked first
    paginate? = options[:pagination] not in [nil, []]
    options = Schema.validate_collection!(options)
    source = source!(options[:resource], options[:query])
    action = action!(source, options)
    declared = field_slots |> Enum.map(&declare!/1) |> once_each!()
    fields = Enum.map(declared, &field!(source, &1))
    declared = Enum.zip_with(declared, fields, &labelled/2)
    columns = Enum.filter(declared, & &1.column?)
    arguments = arguments!(source, action, argument_slots, declared)

    %__MODULE__{
      source: source,
      action: action,
      arguments: Enum.map(arguments, &elem(&1, 0)),
      argument_inputs: Enum.map(arguments, &argument_input/1),
      columns: columns,
      fields: fields,
      filters: filters(fields, declared),
      search: search(options[:search], declared),
      pagination: pagination!(source, action, options, paginate?),
      actor: options[:actor],
      tenant: options[:tenant],
      scope: options[:scope],
      query_opts: options[:query_opts] || [],
      selectable: options[:selectable],
      primary_key: primary_key!(source, options),
      on_selection_change: options[:on_selection_change],
      on_bulk_action_result: options[:on_bulk_action_result],
      bulk_actions: bulk_actions!(source, bulk_action_slots, options),
      sort: %{
        mode: options[:sort][:mode] || :additive,
        default: default_sort(source, fields, columns)
      }
    }
  end

  # A `<:field>` declares its field, so a second one for a name would contradict it
  defp once_each!(declared) do
    names = Enum.map(declared, & &1.field)

    case names -- Enum.uniq(names) do
      [] ->
        declared

      [name | _] ->
        raise ArgumentError,
              ~s(<:field name="#{name}"> is declared twice: each field is declared once)
    end
  end

  # Only needed when records can be selected: a resource that can't be selected
  # needn't have a primary key of one attribute
  defp primary_key!(source, options) do
    case {options[:selectable], Engine.primary_key(source)} do
      {false, _primary_key} ->
        nil

      {_selectable, {:ok, key}} ->
        key

      {_selectable, {:error, message}} ->
        raise ArgumentError,
              ~s(<Cinder.Next.collection id="#{options[:id]}">: `selectable` can't be used: ) <>
                message
    end
  end

  # Events name the action, rather than giving its place, so one behind an `:if`
  # can't change which runs
  defp bulk_actions!(source, slots, options) do
    bulk_actions = Enum.map(slots, &bulk_action!(source, &1))

    if bulk_actions != [] and options[:selectable] == false do
      raise ArgumentError,
            ~s(<Cinder.Next.collection id="#{options[:id]}">: bulk actions run on the ) <>
              "selected records, so need `selectable`"
    end

    names = Enum.map(bulk_actions, & &1.name)

    case names -- Enum.uniq(names) do
      [] ->
        bulk_actions

      [name | _] ->
        raise ArgumentError,
              ~s(<:bulk_action name="#{name}"> is declared twice: ) <>
                "give each bulk action its own `name`"
    end
  end

  defp bulk_action!(source, slot) do
    attributes = Schema.validate_bulk_action!(slot)
    action = attributes[:action]
    declaration = Schema.bulk_action_declaration(slot)

    if slot[:inner_block] do
      raise ArgumentError,
            "#{declaration} takes no content: give its button's text as `label`, " <>
              ~s(as in <:bulk_action label="Delete" />)
    end

    name =
      cond do
        attributes[:name] ->
          attributes[:name]

        is_function(action) ->
          raise ArgumentError, "#{declaration} runs a function, so needs a `name` to go by"

        true ->
          to_string(action)
      end

    case Engine.bulk_action(source, action) do
      {:ok, bulk_action} ->
        action_opts = attributes[:action_opts] || []
        check_action_opts!(action_opts, Engine.bulk_action_opts(bulk_action), declaration)

        %{
          name: name,
          label: attributes[:label] || humanize(name),
          confirm: attributes[:confirm],
          action: bulk_action,
          action_opts: action_opts
        }

      {:error, message} ->
        raise ArgumentError, "#{declaration}: #{message}"
    end
  end

  # Checking fills in Ash's defaults, which are Ash's to apply, so the options are
  # only checked, and kept as given
  defp check_action_opts!(_action_opts, nil, _declaration), do: :ok

  defp check_action_opts!(action_opts, schema, declaration) do
    # The schema would only call these unknown
    case Enum.find(Keyword.keys(action_opts), &(&1 in [:actor, :tenant, :scope])) do
      nil ->
        :ok

      key ->
        raise ArgumentError,
              "#{declaration}: give `#{key}` as the collection's own attribute, not in `action_opts`"
    end

    case Spark.Options.validate(action_opts, schema) do
      {:ok, _validated} -> :ok
      {:error, error} -> raise ArgumentError, "#{declaration}: #{Exception.message(error)}"
    end
  end

  defp action!(source, options) do
    case Engine.read_action(source, options[:action]) do
      {:ok, action} ->
        action

      {:error, message} ->
        raise ArgumentError, ~s(<Cinder.Next.collection id="#{options[:id]}">: ) <> message
    end
  end

  # Each argument with its input's label
  defp arguments!(source, action, argument_slots, declared) do
    Enum.each(argument_slots, &argument_without_content!/1)

    argument_slots
    |> Enum.map(&Schema.validate_argument!/1)
    |> tap(&arguments_once!/1)
    |> tap(&params_unclashed!(&1, declared))
    |> Enum.map(fn attributes ->
      input = attributes[:input]

      declared = %Engine.Argument{
        name: attributes[:name],
        param: attributes[:param],
        input: Map.new(Keyword.take(input, [:type, :options]))
      }

      {argument!(source, action, declared), input[:label] || humanize(attributes[:name])}
    end)
  end

  # An argument's input shares the form and the URL with the fields' filters, the
  # collection's own params and the other arguments, so its param can't be one of
  # theirs. An argument's name can't be changed, so its param can be.
  defp params_unclashed!(arguments, declared) do
    shared = " in the form and the URL"

    taken =
      Map.new(Params.own_keys(), &{&1, ~s(the collection's own URL param "#{&1}")})
      |> Map.merge(Map.new(declared, &{&1.field, ~s(<:field name="#{&1.field}">) <> shared}))

    Enum.reduce(arguments, taken, fn attributes, taken ->
      name = attributes[:name]
      param = attributes[:param] || name

      if clash = taken[param] do
        raise ArgumentError,
              ~s(<:argument name="#{name}"> clashes with #{clash}: ) <>
                "give it another name there with `param`"
      end

      Map.put(taken, param, ~s(<:argument name="#{name}">) <> shared)
    end)
  end

  # Content would be ignored, and as a new closure on every render, would rebuild
  # the config
  defp argument_without_content!(slot) do
    if slot[:inner_block] do
      raise ArgumentError,
            ~s(<:argument name="#{slot[:name]}"> takes no content: give its input with ) <>
              ~s(`input`, as in <:argument name="#{slot[:name]}" ) <>
              ~s(input={[label: "#{humanize(slot[:name])}"]} />)
    end
  end

  defp arguments_once!(arguments) do
    names = Enum.map(arguments, & &1[:name])

    case names -- Enum.uniq(names) do
      [] ->
        :ok

      [name | _] ->
        raise ArgumentError,
              ~s(<:argument name="#{name}"> is declared twice: each argument is declared once)
    end
  end

  defp argument!(source, action, argument) do
    case Engine.argument(source, action, argument) do
      {:ok, argument} -> argument
      {:error, message} -> raise ArgumentError, message
    end
  end

  defp argument_input({argument, label}) do
    column = %{Engine.Argument.to_column_map(argument) | label: label}
    %{column: column, module: argument.input.module}
  end

  # A label or placeholder not given stays `nil`: its default is translated when
  # rendered, in the user's locale
  defp search(options, declared) do
    if Enum.any?(declared, & &1.search?) do
      %{label: options[:label], placeholder: options[:placeholder], fn: options[:fn]}
    end
  end

  # Paged if the action can be, by offset if it can. Asking for pagination it can't
  # do is a mistake, as it is in Ash; by default, it just reads every record.
  # Keyset pages have no number to show a total against, so aren't counted (yet).
  defp pagination!(source, action, options, paginate?) do
    modes = if mode = options[:pagination][:mode], do: [mode], else: [:offset, :keyset]

    case first_mode(source, action, modes) do
      {:ok, mode, %{count?: count?}} ->
        %{mode: mode, size: options[:pagination][:size], count?: mode == :offset and count?}

      {:error, message} when paginate? ->
        raise ArgumentError,
              ~s(<Cinder.Next.collection id="#{options[:id]}">: `pagination` can't be used: ) <>
                message

      {:error, _message} ->
        nil
    end
  end

  # The first mode the action can page by, or the last one's error
  defp first_mode(source, action, [mode | rest]) do
    case {Engine.pagination(source, action, mode), rest} do
      {{:ok, can}, _rest} -> {:ok, mode, can}
      {error, []} -> error
      {_error, rest} -> first_mode(source, action, rest)
    end
  end

  # The fields are built from the declared ones one for one, so they pair up in order
  defp filters(fields, declared) do
    for {%Engine.Field{filter: %{module: module}} = field, %{filter: filter}} <-
          Enum.zip(fields, declared) do
      %{column: %{Engine.Field.to_column_map(field) | label: filter.label}, module: module}
    end
  end

  # The source query's sorts the collection can show, then each column that's always
  # sorted (its cycle has no `nil`) and isn't yet, in its first direction. Only
  # columns: a field that isn't one has no heading to show its sort.
  defp default_sort(source, fields, columns) do
    from_query = Engine.query_sorts(source, fields)

    always_sorted =
      for %{sort: %{cycle: cycle}, field: field} <- columns,
          nil not in cycle,
          !List.keymember?(from_query, field, 0),
          do: {field, hd(cycle)}

    Enum.uniq_by(from_query ++ always_sorted, &elem(&1, 0))
  end

  defp source!(nil, nil), do: raise(ArgumentError, "a collection needs a `resource` or a `query`")
  defp source!(resource, nil), do: resource
  defp source!(nil, query), do: query

  defp source!(_resource, _query) do
    raise ArgumentError, "give a collection a `resource` or a `query`, not both"
  end

  # A field that isn't a column has no cells, so its inner block is never used
  defp declare!(slot) do
    attributes = Schema.validate_field!(slot)
    name = attributes[:name]

    if attributes[:column] and !slot[:inner_block] do
      raise ArgumentError,
            ~s(<:field name="#{name}"> needs content, such as ) <>
              ~s(<:field :let={record} name="#{name}">{record.#{name}}</:field>)
    end

    %{
      field: name,
      label: attributes[:label],
      column?: attributes[:column],
      sort: declared_sort(attributes[:sort]),
      search?: attributes[:search],
      filter: declared_filter(attributes[:filter])
    }
  end

  defp declared_sort(nil), do: nil
  defp declared_sort(sort), do: %{cycle: sort[:cycle]}

  # The type is left out when it isn't given, for `Engine.field/2` to infer
  defp declared_filter(nil), do: nil

  defp declared_filter(filter) do
    filter
    |> Keyword.take([:type, :options])
    |> Map.new()
    |> Map.put(:label, filter[:label])
  end

  # A label not given is the field's path, humanised ("Artist > Name"), and a
  # filter's is its field's
  defp labelled(declared, %Engine.Field{path: path}) do
    label = declared.label || Enum.map_join(path, " > ", &humanize/1)
    filter = declared.filter && Map.update!(declared.filter, :label, &(&1 || label))
    %{declared | label: label, filter: filter}
  end

  defp humanize(name) do
    name |> String.split("_") |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp field!(source, declared) do
    field = %Engine.Field{
      name: declared.field,
      column?: declared.column?,
      sortable?: declared.sort != nil,
      searchable?: declared.search?,
      filter: declared.filter && Map.delete(declared.filter, :label)
    }

    case Engine.field(source, field) do
      {:ok, field} -> field
      {:error, message} -> raise ArgumentError, message
    end
  end
end
