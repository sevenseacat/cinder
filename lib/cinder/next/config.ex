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
  defstruct [
    :source,
    :actor,
    :tenant,
    :scope,
    columns: [],
    fields: [],
    query_opts: [],
    sort: %{mode: :additive, default: []}
  ]

  @doc """
  The parts of the declarations that decide the config. A column's inner block
  closes over the parent's assigns, so it's new on every render, and is left out.
  """
  def declarations(options, columns) do
    {options, Enum.map(columns, &Map.drop(&1, [:inner_block]))}
  end

  def build(options, columns) do
    options = Schema.validate_collection!(options)
    source = source!(options[:resource], options[:query])
    resource = Ash.Query.new(source).resource
    columns = Enum.map(columns, &column!/1)
    fields = fields!(resource, columns)

    %__MODULE__{
      source: source,
      columns: columns,
      fields: fields,
      actor: options[:actor],
      tenant: options[:tenant],
      scope: options[:scope],
      query_opts: options[:query_opts] || [],
      sort: %{
        mode: sort_mode(options[:sort][:mode]),
        default: default_sort(source, fields, columns)
      }
    }
  end

  # One field per name: two columns can show the same field, which is sortable if
  # either column is
  defp fields!(resource, columns) do
    for name <- columns |> Enum.map(& &1.field) |> Enum.uniq() do
      sortable? = Enum.any?(columns, &(&1.field == name and &1.sort != nil))
      field!(resource, %Engine.Field{name: name, column?: true, sortable?: sortable?})
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
    attributes = Schema.validate_col!(slot)
    field = attributes[:field]

    if !slot[:inner_block] do
      raise ArgumentError,
            ~s(<:col field="#{field}"> needs content, such as ) <>
              ~s(<:col :let={record} field="#{field}">{record.#{field}}</:col>)
    end

    %{
      field: field,
      label: attributes[:label] || Cinder.Filter.Helpers.humanize_embedded_field(field),
      sort: column_sort(attributes[:sort])
    }
  end

  # The schema has already checked it's one of these
  defp sort_mode(mode) when mode in [:exclusive, "exclusive"], do: :exclusive
  defp sort_mode(_additive), do: :additive

  defp column_sort(nil), do: nil
  defp column_sort(sort), do: %{cycle: sort[:cycle]}

  defp field!(resource, field) do
    case Engine.field(resource, field) do
      {:ok, field} -> field
      {:error, message} -> raise ArgumentError, message
    end
  end
end
