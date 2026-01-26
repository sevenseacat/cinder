defmodule Cinder.Theme.Docs do
  @moduledoc """
  Auto-generates theme documentation from `Cinder.Theme.complete_default/0`.
  """

  @theming_file "docs/theming.md"
  @docs_start_comment "<!-- theme-properties-begin -->"
  @docs_end_comment "<!-- theme-properties-end -->"

  @doc """
  Updates the theming guide with auto-generated property reference documentation.
  """
  def write_docs! do
    [prelude, _ | rest] =
      @theming_file
      |> File.read!()
      |> String.split([@docs_start_comment, @docs_end_comment])

    [prelude, @docs_start_comment, "\n\n", property_docs(), "\n\n", @docs_end_comment]
    |> Enum.concat(rest)
    |> Enum.join()
    |> then(&File.write!(@theming_file, &1))
  end

  defp property_docs do
    defaults = Cinder.Theme.complete_default()

    properties =
      defaults
      |> Map.keys()
      |> Enum.sort()
      |> Enum.map_join("\n", fn prop ->
        value = Map.get(defaults, prop, "")
        formatted = if is_binary(value), do: "\"#{value}\"", else: inspect(value)
        "set :#{prop}, #{formatted}"
      end)

    """
    ### All Theme Properties

    ```elixir
    #{properties}
    ```
    """
  end
end
