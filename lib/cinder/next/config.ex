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
  defstruct [
    :source,
    :actor,
    :tenant,
    :scope,
    columns: [],
    fields: [],
    filters: [],
    query_opts: [],
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
    options = Schema.validate_collection!(options)
    source = source!(options[:resource], options[:query])
    resource = Ash.Query.new(source).resource
    columns = field_slots |> Enum.map(&column!/1) |> once_each!()
    fields = Enum.map(columns, &field!(resource, &1))

    %__MODULE__{
      source: source,
      columns: columns,
      fields: fields,
      filters: filters(fields, columns),
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
  defp once_each!(columns) do
    names = Enum.map(columns, & &1.field)

    case names -- Enum.uniq(names) do
      [] ->
        columns

      [name | _] ->
        raise ArgumentError,
              ~s(<:field name="#{name}"> is declared twice: each field is declared once)
    end
  end

  # The fields are built from the columns one for one, so they pair up in order
  defp filters(fields, columns) do
    for {%Engine.Field{filter: %{module: module}} = field, column} <- Enum.zip(fields, columns) do
      %{column: %{Engine.Field.to_column_map(field) | label: column.filter.label}, module: module}
    end
  end

  # The source query's sorts the collection can show, then each column that's
  # always sorted (its cycle has no `nil`) and isn't yet, in its first direction
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

  defp column!(slot) do
    attributes = Schema.validate_field!(slot)
    name = attributes[:name]

    if !slot[:inner_block] do
      raise ArgumentError,
            ~s(<:field name="#{name}"> needs content, such as ) <>
              ~s(<:field :let={record} name="#{name}">{record.#{name}}</:field>)
    end

    label = attributes[:label] || Cinder.Filter.Helpers.humanize_embedded_field(name)

    %{
      field: name,
      label: label,
      sort: column_sort(attributes[:sort]),
      filter: column_filter(attributes[:filter], label)
    }
  end

  defp column_sort(nil), do: nil
  defp column_sort(sort), do: %{cycle: sort[:cycle]}

  # The type is left out when it isn't given, for `Engine.field/2` to infer
  defp column_filter(nil, _column_label), do: nil

  defp column_filter(filter, column_label) do
    filter
    |> Keyword.take([:type, :options])
    |> Map.new()
    |> Map.put(:label, filter[:label] || column_label)
  end

  defp field!(resource, column) do
    field = %Engine.Field{
      name: column.field,
      column?: true,
      sortable?: column.sort != nil,
      filter: column.filter && Map.delete(column.filter, :label)
    }

    case Engine.field(resource, field) do
      {:ok, field} -> field
      {:error, message} -> raise ArgumentError, message
    end
  end
end
