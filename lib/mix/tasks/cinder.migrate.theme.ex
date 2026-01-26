if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.Cinder.Migrate.Theme do
    @example "mix cinder.migrate.theme MyApp.CustomTheme"

    @moduledoc """
    Migrate a Cinder theme module from the deprecated `component/2` syntax to flat `set` calls.

    ## Example

    ```bash
    #{@example}
    ```

    ## Arguments

    * `module` - The theme module to migrate (e.g., MyApp.CustomTheme)

    ## What it does

    Transforms theme files from:

        defmodule MyApp.CustomTheme do
          use Cinder.Theme

          component Cinder.Components.Table do
            set :container_class, "..."
            set :row_class, "..."
          end

          component Cinder.Components.Filters do
            set :filter_container_class, "..."
          end
        end

    To:

        defmodule MyApp.CustomTheme do
          use Cinder.Theme

          # Table
          set :container_class, "..."
          set :row_class, "..."

          # Filters
          set :filter_container_class, "..."
        end
    """

    @shortdoc "Migrate a theme module from component/2 syntax to flat set calls"
    use Igniter.Mix.Task

    @impl Igniter.Mix.Task
    def info(_argv, _parent) do
      %Igniter.Mix.Task.Info{
        example: @example,
        positional: [:module],
        schema: []
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      module = Igniter.Project.Module.parse(igniter.args.positional.module)

      Mix.shell().info("Migrating theme: #{inspect(module)}")

      case Igniter.Project.Module.find_module(igniter, module) do
        {:ok, {igniter, source, _zipper}} ->
          # Get the file path from the source
          path = Rewrite.Source.get(source, :path)

          # Update the file with text-based patching
          Igniter.update_file(igniter, path, fn source ->
            transform_theme_source(source)
          end)

        {:error, igniter} ->
          Igniter.add_issue(igniter, "Could not find module #{inspect(module)}")
      end
    end

    defp transform_theme_source(source) do
      original_string = Rewrite.Source.get(source, :content)

      # Parse and transform
      new_string = transform_component_blocks(original_string)

      if new_string == original_string do
        source
      else
        Rewrite.Source.update(source, :content, new_string)
      end
    end

    @doc false
    def transform_component_blocks(source_string) do
      # Parse the source with range information
      case Sourceror.parse_string(source_string) do
        {:ok, ast} ->
          # Collect all patches
          patches = collect_component_patches(ast)

          if patches == [] do
            source_string
          else
            source_string
            |> Sourceror.patch_string(patches)
            |> Code.format_string!(locals_without_parens: [set: 2, extends: 1])
            |> IO.iodata_to_binary()
          end

        {:error, _} ->
          source_string
      end
    end

    defp collect_component_patches(ast) do
      {_ast, patches} =
        Macro.prewalk(ast, [], fn
          # Pattern for Sourceror AST: do block is stored as {{:__block__, _, [:do]}, body}
          {:component, _meta, [module_ast, [{{:__block__, _, [:do]}, body}]]} = node, acc ->
            extract_and_patch_component(node, module_ast, body, acc)

          # Pattern for standard AST: do block is stored as {:do, body}
          {:component, _meta, [module_ast, [do: body]]} = node, acc ->
            extract_and_patch_component(node, module_ast, body, acc)

          node, acc ->
            {node, acc}
        end)

      Enum.reverse(patches)
    end

    defp extract_and_patch_component(node, module_ast, body, acc) do
      # Extract the short name for the comment
      comment = module_to_comment(module_ast)

      # Extract the set calls from the body
      set_calls =
        case body do
          {:__block__, _, calls} -> calls
          single_call -> [single_call]
        end

      # Build replacement text
      replacement_text = build_replacement_text(comment, set_calls)

      # Create patch using the node's range
      range = Sourceror.get_range(node)

      if range do
        patch = %{range: range, change: replacement_text}
        {node, [patch | acc]}
      else
        {node, acc}
      end
    end

    @doc false
    def module_to_comment(module_ast) do
      case module_ast do
        {:__aliases__, _, parts} ->
          # Get last part, e.g., [:Cinder, :Components, :Table] -> "Table"
          parts |> List.last() |> to_string()

        atom when is_atom(atom) ->
          atom |> Module.split() |> List.last()

        _ ->
          "Component"
      end
    end

    defp build_replacement_text(comment, set_calls) do
      # Convert each set call back to source code
      set_call_strings =
        Enum.map(set_calls, fn call ->
          Sourceror.to_string(call)
        end)

      # Build the replacement with comment
      # Note: Sourceror preserves the original indentation from the file,
      # so we don't need to add our own indentation
      case set_call_strings do
        [] ->
          "# #{comment}"

        calls ->
          "# #{comment}\n" <> Enum.join(calls, "\n")
      end
    end
  end
else
  defmodule Mix.Tasks.Cinder.Migrate.Theme do
    @moduledoc """
    Migrate a Cinder theme module from the deprecated `component/2` syntax to flat `set` calls.

    This task requires Igniter to be installed.
    """

    @shortdoc "Migrate a theme module from component/2 syntax to flat set calls"
    use Mix.Task

    def run(_argv) do
      Mix.shell().error("""
      The task 'cinder.migrate.theme' requires Igniter to be available.

      Please install igniter and try again:

          mix deps.get

      For more information, see: https://hexdocs.pm/igniter
      """)

      exit({:shutdown, 1})
    end
  end
end
