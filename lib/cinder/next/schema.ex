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
    query: [type: {:struct, Ash.Query}, doc: "The Ash query to read (or give a `resource`)."]
  ]

  @col [
    field: [type: :string, required: true, doc: "The field the column shows."],
    label: [type: :string, doc: "The column's heading. Defaults to the humanised field."]
  ]

  def collection, do: @collection
  def col, do: @col

  @doc "The collection's options, checked."
  def validate_collection!(options) do
    validate!(options, @collection, ~s(<Cinder.Next.collection id="#{options[:id]}">))
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
      {:error, error} -> raise ArgumentError, "#{declaration}: #{Exception.message(error)}"
    end
  end
end
