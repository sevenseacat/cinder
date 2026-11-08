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

  # The actor, tenant and scope are kept as given: Ash applies its own precedence.
  # `sort` is the mode, and the default: the sort the collection starts with.
  # `filters` are the filter controls: the column map their type renders from (with
  # the column's label), and the type's module.
  # `search` is the search box's options, or `nil` when no field is searchable.
  # `pagination` is the mode, the page size and whether to count, or `nil` when the
  # action doesn't page.
  defstruct [
    :source,
    :actor,
    :tenant,
    :scope,
    columns: [],
    fields: [],
    filters: [],
    query_opts: [],
    search: nil,
    pagination: nil,
    sort: %{mode: :additive, default: []}
  ]

  @doc """
  The parts of the declarations that decide the config. A `<:field>`'s inner block
  closes over the parent's assigns, so it's new on every render, and is left out.
  """
  def declarations(options, field_slots) do
    {options, Enum.map(field_slots, &Map.drop(&1, [:inner_block]))}
  end

  def build(options, field_slots) do
    # The schema fills in the page size, so whether `pagination` was given is asked first
    paginate? = options[:pagination] not in [nil, []]
    options = Schema.validate_collection!(options)
    source = source!(options[:resource], options[:query])
    declared = field_slots |> Enum.map(&declare!/1) |> once_each!()
    columns = Enum.filter(declared, & &1.column?)
    fields = Enum.map(declared, &field!(source, &1))

    %__MODULE__{
      source: source,
      columns: columns,
      fields: fields,
      filters: filters(fields, declared),
      search: search(options[:search], declared),
      pagination: pagination!(source, options, paginate?),
      actor: options[:actor],
      tenant: options[:tenant],
      scope: options[:scope],
      query_opts: options[:query_opts] || [],
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
  defp pagination!(source, options, paginate?) do
    modes = if mode = options[:pagination][:mode], do: [mode], else: [:offset, :keyset]

    case first_mode(source, modes) do
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
  defp first_mode(source, [mode | rest]) do
    case {Engine.pagination(source, mode), rest} do
      {{:ok, can}, _rest} -> {:ok, mode, can}
      {error, []} -> error
      {_error, rest} -> first_mode(source, rest)
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

    label = attributes[:label] || Cinder.Filter.Helpers.humanize_embedded_field(name)

    %{
      field: name,
      label: label,
      column?: attributes[:column],
      sort: declared_sort(attributes[:sort]),
      search?: attributes[:search],
      filter: declared_filter(attributes[:filter], label)
    }
  end

  defp declared_sort(nil), do: nil
  defp declared_sort(sort), do: %{cycle: sort[:cycle]}

  # The type is left out when it isn't given, for `Engine.field/2` to infer
  defp declared_filter(nil, _label), do: nil

  defp declared_filter(filter, label) do
    filter
    |> Keyword.take([:type, :options])
    |> Map.new()
    |> Map.put(:label, filter[:label] || label)
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
