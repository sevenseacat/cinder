# SPDX-FileCopyrightText: 2026 Cinder contributors <https://github.com/sevenseacat/cinder/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Cinder.Field do
  @moduledoc false
  # A column's `field` resolved against its Ash resource, once, so the questions asked of it
  # (can it be loaded? sorted? filtered?) all agree.
  #
  # Field notation: `.` walks relationships (`artist.name`), `__` reaches into an embedded or
  # map attribute (`details__label`, `meta__any__key`). Names are matched against what the
  # resource declares, never converted to atoms, since sort keys can come from the client.

  @typedoc """
  - `relationships` - the relationship path to the field, outermost first
  - `resource` - the resource the field is on, at the end of that path
  - `name` - the field on that resource (for an embedded field, the attribute holding it)
  - `calculation` - the calculation, when `kind` is `:calculation`
  """
  @type t :: %{
          relationships: [atom()],
          resource: module(),
          name: atom(),
          kind: :attribute | :embedded | :relationship | :aggregate | :calculation,
          calculation: struct() | nil
        }

  # Any key can be under these, so nested names can't be checked
  @open_types [Ash.Type.Map, Ash.Type.Keyword, Ash.Type.Struct]

  @doc "Resolves a field in column notation, or `:error` if the resource has no such field."
  @spec resolve(module(), String.t()) :: {:ok, t()} | :error
  def resolve(resource, field) when is_atom(resource) and is_binary(field) do
    if resource && Ash.Resource.Info.resource?(resource) do
      resolve_path(resource, String.split(field, "."), [])
    else
      :error
    end
  end

  def resolve(_resource, _field), do: :error

  @doc """
  Why a field can't be sorted or filtered by, or `nil` if it can. The data layer has to
  compute it, and field notation can't pass a calculation's arguments.
  """
  @spec query_error(t()) :: String.t() | nil
  def query_error(%{kind: :relationship}), do: "is a relationship, not a field"

  def query_error(%{kind: :calculation, calculation: calculation}) do
    case required_arguments(calculation) do
      [] ->
        unless expression?(calculation) do
          {module, _opts} = calculation.calculation

          "is an in-memory calculation (#{inspect(module)} is missing expression/2)"
        end

      arguments ->
        "is a calculation that needs arguments (#{Enum.join(arguments, ", ")})"
    end
  end

  def query_error(_field), do: nil

  @doc """
  What showing a field needs loaded, for `Ash.Query.load/2`: its calculation or aggregate and
  the relationships in its path. `nil` when nothing does, or when it can't be loaded (a
  calculation that needs arguments).
  """
  @spec load(t()) :: atom() | {atom(), list()} | nil
  def load(%{kind: :calculation, calculation: calculation} = field) do
    if required_arguments(calculation) == [] do
      wrap(field.relationships, calculation.name)
    end
  end

  def load(%{kind: :aggregate} = field), do: wrap(field.relationships, field.name)
  def load(%{kind: :relationship} = field), do: wrap(field.relationships, {field.name, []})
  def load(field), do: wrap(field.relationships, nil)

  @doc "The field's Ash type, or `nil` for a relationship or a field inside an embedded one."
  @spec type(t()) :: Ash.Type.t() | nil
  def type(%{kind: :attribute, resource: resource, name: name}) do
    Ash.Resource.Info.attribute(resource, name).type
  end

  def type(%{kind: :calculation, calculation: calculation}), do: calculation.type

  def type(%{kind: :aggregate, resource: resource, name: name}) do
    case Ash.Resource.Info.aggregate_type(resource, name) do
      {:ok, type} -> type
      _error -> nil
    end
  end

  def type(_field), do: nil

  @doc "Whether the field is marked `sensitive?`, so its values are redacted where Ash's would be."
  @spec sensitive?(t()) :: boolean()
  def sensitive?(%{kind: kind, resource: resource, name: name})
      when kind in [:attribute, :embedded] do
    Ash.Resource.Info.attribute(resource, name).sensitive?
  end

  def sensitive?(%{kind: :aggregate, resource: resource, name: name}) do
    Ash.Resource.Info.aggregate(resource, name).sensitive?
  end

  def sensitive?(%{kind: :calculation, calculation: calculation}), do: calculation.sensitive?
  def sensitive?(_field), do: false

  defp resolve_path(resource, [field], relationships) do
    case String.split(field, "__") do
      [name] -> resolve_direct(resource, name, relationships)
      [name | nested] -> resolve_embedded(resource, name, nested, relationships)
    end
  end

  defp resolve_path(resource, [relationship | rest], relationships) do
    case Ash.Resource.Info.relationship(resource, relationship) do
      %{name: name, destination: destination} ->
        resolve_path(destination, rest, relationships ++ [name])

      nil ->
        :error
    end
  end

  defp resolve_direct(resource, name, relationships) do
    found =
      Enum.find_value(
        [
          attribute: &Ash.Resource.Info.attribute/2,
          relationship: &Ash.Resource.Info.relationship/2,
          aggregate: &Ash.Resource.Info.aggregate/2,
          calculation: &Ash.Resource.Info.calculation/2
        ],
        fn {kind, lookup} ->
          if definition = lookup.(resource, name), do: {kind, definition}
        end
      )

    case found do
      {kind, definition} ->
        {:ok, field(resource, relationships, definition.name, kind, definition)}

      nil ->
        :error
    end
  end

  defp resolve_embedded(resource, name, nested, relationships) do
    with %{name: attribute, type: type} <- Ash.Resource.Info.attribute(resource, name),
         true <- nested_exists?(type, nested) do
      {:ok, field(resource, relationships, attribute, :embedded, nil)}
    else
      _ -> :error
    end
  end

  defp nested_exists?({:array, type}, nested), do: nested_exists?(type, nested)
  defp nested_exists?(type, nested) when type in @open_types, do: "" not in nested

  defp nested_exists?(type, [name | rest]) do
    with true <- Ash.Resource.Info.resource?(type),
         %{type: nested_type} <- Ash.Resource.Info.attribute(type, name) do
      rest == [] or nested_exists?(nested_type, rest)
    else
      _ -> false
    end
  end

  defp field(resource, relationships, name, kind, definition) do
    %{
      relationships: relationships,
      resource: resource,
      name: name,
      kind: kind,
      calculation: if(kind == :calculation, do: definition)
    }
  end

  defp required_arguments(calculation) do
    for %{allow_nil?: false, default: nil, name: name} <- calculation.arguments, do: name
  end

  # Expression calculations, and modules defining `expression/2`, run in the data layer
  @doc false
  def expression?(%{calculation: {Ash.Resource.Calculation.Expression, _opts}}), do: true

  def expression?(%{calculation: {module, _opts}}) do
    Code.ensure_loaded?(module) and function_exported?(module, :expression, 2)
  end

  defp wrap([], leaf), do: leaf
  defp wrap([relationship | rest], leaf), do: {relationship, List.wrap(wrap(rest, leaf))}
end
