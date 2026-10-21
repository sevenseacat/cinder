defmodule Cinder.Next.Filters do
  @moduledoc """
  Spike: a collection's filter view-models, in declaration order for loops
  (`:for={f <- c.filters}`) and by field for placing one (`c.filters["price"]`).
  """
  defstruct list: [], by_field: %{}

  def new(filters), do: %__MODULE__{list: filters, by_field: Map.new(filters, &{&1.field, &1})}

  @behaviour Access

  @impl Access
  def fetch(%__MODULE__{by_field: by_field}, field), do: Map.fetch(by_field, field)

  # View-models are built, not edited, so there's nothing to update
  @impl Access
  def get_and_update(_filters, _field, _fun), do: raise(ArgumentError, "filters are read-only")

  @impl Access
  def pop(_filters, _field), do: raise(ArgumentError, "filters are read-only")

  defimpl Enumerable do
    def count(filters), do: {:ok, length(filters.list)}
    def member?(filters, filter), do: {:ok, filter in filters.list}
    def slice(filters), do: Enumerable.slice(filters.list)
    def reduce(filters, acc, fun), do: Enumerable.reduce(filters.list, acc, fun)
  end
end
