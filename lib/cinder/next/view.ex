defmodule Cinder.Next.View do
  @moduledoc """
  Spike: view-models for the new shell's markup. Built from the component's
  assigns, with no markup of its own. Each part comes with ready-to-spread
  attribute maps, so default and custom markup get the same wiring.
  """

  @doc "The whole collection's view-model, from the component's assigns."
  def build(%{config: config, page: page, status: status}) do
    %{
      status: status,
      attrs: %{"data-cinder" => "collection", "data-state" => to_string(status)},
      columns: Enum.map(config.columns, &column/1),
      rows: rows(page)
    }
  end

  defp column(column) do
    %{
      field: column.field,
      label: column.label,
      slot: column.slot,
      attrs: %{"data-part" => "header-cell", "data-field" => column.field}
    }
  end

  defp rows(nil), do: []

  defp rows(%{results: results}) do
    for record <- results do
      %{
        record: record,
        attrs: %{"data-part" => "row", "data-row-id" => to_string(Map.get(record, :id))}
      }
    end
  end

  @doc "A record's value for a column field, following `.` into relationships."
  def field_value(record, field) do
    field
    |> String.split(".")
    |> Enum.reduce(record, fn key, acc -> acc && Map.get(acc, String.to_existing_atom(key)) end)
  end
end
