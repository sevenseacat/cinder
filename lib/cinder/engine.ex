# SPDX-FileCopyrightText: 2026 Cinder contributors <https://github.com/sevenseacat/cinder/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Cinder.Engine do
  @moduledoc """
  The Ash layer: the only part of Cinder that touches Ash.

  The shell asks it what a resource's fields are and how they can be filtered,
  searched and sorted, what sort a given query already has, and for a page of
  records. It answers with Cinder's own data, never Ash structs or column maps,
  so what's behind it can change without the shell changing.

  Turning form and URL strings into values belongs to `Cinder.Params`, not here.
  """

  alias Cinder.Engine.Field
  alias Cinder.Filters.Registry

  @date_types [
    Ash.Type.Date,
    Ash.Type.DateTime,
    Ash.Type.UtcDatetime,
    Ash.Type.UtcDatetimeUsec,
    Ash.Type.NaiveDatetime
  ]

  @number_types [Ash.Type.Integer, Ash.Type.Decimal, Ash.Type.Float]

  @doc """
  Describes a field of `resource` for a collection, from what was declared for
  it:

    * `filter` - `nil` if it isn't filtered, or `%{type: type, options: options}`,
      where a `nil` (or missing) type is inferred from the field's Ash type
    * `sortable?` and `searchable?` - whether it can be sorted and searched

  A filter's options are its type's defaults, then the field's enum values (for
  types that take `options`), then the declared ones.

  Anything wrong is the developer's mistake, so it's an error naming the field:
  a field the resource doesn't have, filtering, sorting or searching a field that
  can't be queried, or a filter type that doesn't exist.
  """
  @spec field(module(), String.t(), map()) :: {:ok, Field.t()} | {:error, String.t()}
  def field(resource, name, declared) do
    declared_filter = Map.get(declared, :filter)
    sortable? = Map.get(declared, :sortable?, false)
    searchable? = Map.get(declared, :searchable?, false)
    uses = [filtered: declared_filter != nil, sorted: sortable?, searched: searchable?]

    with {:ok, resolved} <- resolve(resource, name),
         :ok <- queryable(resolved, uses),
         {:ok, filter} <- filter(resolved, declared_filter) do
      {:ok,
       %Field{
         name: name,
         filter: filter,
         sortable?: sortable?,
         searchable?: searchable?,
         load: Cinder.Field.load(resolved)
       }}
    else
      {:error, problem} -> {:error, "#{inspect(name)} #{problem}"}
    end
  end

  defp resolve(resource, name) do
    case Cinder.Field.resolve(resource, name) do
      {:ok, resolved} -> {:ok, resolved}
      :error -> {:error, "is not a field of #{inspect(resource)}"}
    end
  end

  # Only asked of a field that's queried: any field can be shown
  defp queryable(resolved, uses) do
    case {for({use, true} <- uses, do: use), Cinder.Field.query_error(resolved)} do
      {[_ | _] = used, problem} when is_binary(problem) ->
        {:error, "can't be #{Enum.join(used, " or ")}: it #{problem}"}

      _ ->
        :ok
    end
  end

  defp filter(_resolved, nil), do: {:ok, nil}

  defp filter(resolved, declared) do
    ash_type = Ash.Type.get_type(Cinder.Field.type(resolved))
    values = enum_values(ash_type, Cinder.Field.constraints(resolved))
    type = Map.get(declared, :type) || infer_type(ash_type, values)

    with {:ok, module} <- filter_module(type) do
      defaults = module.default_options()

      # Only types that take `options` get the field's values as options
      enum_options =
        if values != [] and Keyword.has_key?(defaults, :options), do: [options: values], else: []

      options =
        defaults
        |> Keyword.merge(enum_options)
        |> Keyword.merge(Map.get(declared, :options, []))

      {:ok, %{type: type, options: options}}
    end
  end

  defp filter_module(type) do
    known = Registry.all_filters_with_custom()

    case Map.fetch(known, type) do
      {:ok, module} ->
        if Code.ensure_loaded?(module) do
          {:ok, module}
        else
          {:error,
           "can't be filtered: #{inspect(type)}'s module #{inspect(module)} can't be loaded"}
        end

      :error ->
        names = known |> Map.keys() |> Enum.sort() |> Enum.map_join(", ", &inspect/1)
        {:error, "can't be filtered: #{inspect(type)} is not a filter type (known: #{names})"}
    end
  end

  # When nothing fits better, a text filter works on any field: it compares as strings
  defp infer_type(ash_type, values) do
    cond do
      match?({:array, _}, ash_type) -> :multi_select
      values != [] -> :select
      ash_type in @date_types -> :date_range
      ash_type == Ash.Type.Boolean -> :boolean
      ash_type in @number_types -> :number_range
      true -> :text
    end
  end

  # `{label, value}` pairs, from an enum type or a `one_of` constraint. An array's
  # values are its items', with the items' constraints under `:items`.
  defp enum_values({:array, item}, constraints) do
    enum_values(item, Keyword.get(constraints, :items, []))
  end

  defp enum_values(type, constraints) do
    cond do
      Keyword.has_key?(constraints, :one_of) ->
        Enum.map(constraints[:one_of], &{humanize(&1), &1})

      is_atom(type) and Spark.implements_behaviour?(type, Ash.Type.Enum) ->
        Enum.map(type.values(), &{type.label(&1) || humanize(&1), &1})

      true ->
        []
    end
  end

  defp humanize(value) when is_atom(value), do: Cinder.Filter.humanize_atom(value)
  defp humanize(value), do: to_string(value)
end
