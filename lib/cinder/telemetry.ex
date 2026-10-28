# SPDX-FileCopyrightText: 2026 Cinder contributors <https://github.com/sevenseacat/cinder/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Cinder.Telemetry do
  @moduledoc false
  # Telemetry and `Ash.Tracer` spans around a collection's reads, saying which collection
  # loaded and with what state. Ash's own spans run inside them, so a tracer nests them.
  # Documented in the advanced guide.

  require Ash.Tracer

  @redacted "**redacted**"

  @doc "Runs `fun` (returning `{:ok, _}` or `{:error, _}`) inside a `[:cinder, event]` span."
  def span(event, %Ash.Query{} = query, options, fun) do
    metadata = metadata(event, query, options)
    name = ["cinder", metadata.id, event] |> Enum.reject(&is_nil/1) |> Enum.join(":")
    tracers = tracers(options)

    Ash.Tracer.span :custom, name, tracers do
      Ash.Tracer.set_metadata(tracers, :custom, metadata)

      :telemetry.span([:cinder, event], metadata, fn ->
        result = fun.()
        {result, Map.put(metadata, :result, elem(result, 0))}
      end)
    end
  end

  defp metadata(event, query, options) do
    columns = Keyword.get(options, :columns, [])
    filters = Keyword.get(options, :filters, %{})

    %{
      id: Keyword.get(options, :id),
      resource: query.resource,
      action: query.action && query.action.name,
      filters: redact_filters(filters, query.resource),
      search_term: redact_search(Keyword.get(options, :search_term), columns, query.resource)
    }
    |> Map.merge(page_metadata(event, options))
  end

  defp page_metadata(:query, options) do
    Map.new([:sort_by, :page_size, :current_page, :pagination_mode], fn key ->
      {key, Keyword.get(options, key)}
    end)
  end

  defp page_metadata(:count, _options), do: %{}

  # The tracers Ash itself uses for the read: the configured ones and any passed in
  defp tracers(options) do
    query_opts = Keyword.get(options, :query_opts, [])

    Enum.uniq(List.wrap(Application.get_env(:ash, :tracer)) ++ List.wrap(query_opts[:tracer]))
  end

  # As Ash does for `sensitive?` fields, unless `config :ash, :show_sensitive?` is on
  defp redact_filters(filters, resource) do
    if show_sensitive?() do
      filters
    else
      Map.new(filters, fn {field, filter} ->
        if sensitive?(resource, field), do: {field, redact(filter)}, else: {field, filter}
      end)
    end
  end

  # The term is matched against every searchable column, so any sensitive one hides it
  defp redact_search(term, _columns, _resource) when term in [nil, ""], do: term

  defp redact_search(term, columns, resource) do
    if not show_sensitive?() and
         Enum.any?(columns, &(&1[:searchable] && sensitive?(resource, &1.field))) do
      @redacted
    else
      term
    end
  end

  defp redact(%{value: _} = filter), do: %{filter | value: @redacted}
  defp redact(_filter), do: @redacted

  defp sensitive?(resource, field) when is_binary(field) do
    case Cinder.Field.resolve(resource, field) do
      {:ok, resolved} -> Cinder.Field.sensitive?(resolved)
      :error -> false
    end
  end

  defp sensitive?(_resource, _field), do: false

  defp show_sensitive?, do: Application.get_env(:ash, :show_sensitive?, false)
end
