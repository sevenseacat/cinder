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

  # The actor, tenant and scope are kept as given: Ash applies its own precedence
  defstruct [:source, :actor, :tenant, :scope, columns: [], fields: [], query_opts: []]

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

    fields =
      Enum.map(columns, fn column ->
        field!(resource, %Engine.Field{name: column.field, column?: true})
      end)

    %__MODULE__{
      source: source,
      columns: columns,
      fields: fields,
      actor: options[:actor],
      tenant: options[:tenant],
      scope: options[:scope],
      query_opts: options[:query_opts] || []
    }
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
      label: attributes[:label] || Cinder.Filter.Helpers.humanize_embedded_field(field)
    }
  end

  defp field!(resource, field) do
    case Engine.field(resource, field) do
      {:ok, field} -> field
      {:error, message} -> raise ArgumentError, message
    end
  end
end
