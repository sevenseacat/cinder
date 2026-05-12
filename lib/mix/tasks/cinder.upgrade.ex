if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.Cinder.Upgrade do
    @moduledoc """
    Tasks for automatic migration of your code between various versions of Cinder.
    """

    use Igniter.Mix.Task

    @theme_key_renames %{
      filter_boolean_container_class: :filter_radio_group_container_class,
      filter_boolean_option_class: :filter_radio_group_option_class,
      filter_boolean_radio_class: :filter_radio_group_radio_class,
      filter_boolean_label_class: :filter_radio_group_label_class
    }

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :cinder,
        adds_deps: [],
        installs: [],
        positional: [:from, :to],
        composes: [],
        schema: [],
        defaults: [],
        aliases: [],
        required: []
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      positional = igniter.args.positional
      options = igniter.args.options

      upgrades =
        %{
          "0.9.0" => [&flatten_theme_component_blocks/2],
          "0.10.0" => [&rename_boolean_theme_keys/2],
          "0.14.0" => [&migrate_tailwind_sources/2]
        }

      Igniter.Upgrades.run(igniter, positional.from, positional.to, upgrades,
        custom_opts: options
      )
    end

    # --- 0.9.0: Flatten component/2 blocks to flat set calls ---

    @doc false
    def flatten_theme_component_blocks(igniter, _opts) do
      Igniter.update_all_elixir_files(igniter, fn zipper ->
        with {:ok, _zipper} <- Igniter.Code.Module.move_to_module_using(zipper, [Cinder.Theme]) do
          # Work on the source text directly since this is a structural transform
          source_string = zipper |> Sourceror.Zipper.topmost_root() |> Sourceror.to_string()
          new_string = transform_component_blocks(source_string)

          if new_string == source_string do
            {:ok, zipper}
          else
            case Sourceror.parse_string(new_string) do
              {:ok, new_ast} ->
                new_zipper = Sourceror.Zipper.zip(new_ast)
                {:ok, new_zipper}

              {:error, _} ->
                {:ok, zipper}
            end
          end
        else
          _ -> {:ok, zipper}
        end
      end)
    end

    @doc false
    def transform_component_blocks(source_string) do
      case Sourceror.parse_string(source_string) do
        {:ok, ast} ->
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
      comment = module_to_comment(module_ast)

      set_calls =
        case body do
          {:__block__, _, calls} -> calls
          single_call -> [single_call]
        end

      replacement_text = build_replacement_text(comment, set_calls)
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
          parts |> List.last() |> to_string()

        atom when is_atom(atom) ->
          atom |> Module.split() |> List.last()

        _ ->
          "Component"
      end
    end

    defp build_replacement_text(comment, set_calls) do
      set_call_strings =
        Enum.map(set_calls, fn call ->
          Sourceror.to_string(call)
        end)

      case set_call_strings do
        [] ->
          "# #{comment}"

        calls ->
          "# #{comment}\n" <> Enum.join(calls, "\n")
      end
    end

    # --- 0.10.0: Rename filter_boolean_* theme keys to filter_radio_group_* ---

    @doc false
    def rename_boolean_theme_keys(igniter, _opts) do
      Igniter.update_all_elixir_files(igniter, fn zipper ->
        with {:ok, zipper} <- Igniter.Code.Module.move_to_module_using(zipper, [Cinder.Theme]) do
          zipper = Sourceror.Zipper.top(zipper)

          zipper =
            Enum.reduce(@theme_key_renames, zipper, fn {old_key, new_key}, zipper ->
              rename_set_calls(zipper, old_key, new_key)
            end)

          {:ok, zipper}
        else
          _ -> {:ok, zipper}
        end
      end)
    end

    defp rename_set_calls(zipper, old_key, new_key) do
      zipper
      |> Igniter.Code.Common.find_all(fn z ->
        match?(
          {:set, _, [{:__block__, _, [^old_key]}, _]},
          Sourceror.Zipper.node(z)
        )
      end)
      |> Enum.reduce(zipper, fn _found_zipper, acc_zipper ->
        case Igniter.Code.Common.move_to(acc_zipper, fn z ->
               match?(
                 {:set, _, [{:__block__, _, [^old_key]}, _]},
                 Sourceror.Zipper.node(z)
               )
             end) do
          {:ok, found} ->
            {:set, meta, [{:__block__, key_meta, [^old_key]}, value]} =
              Sourceror.Zipper.node(found)

            new_node = {:set, meta, [{:__block__, key_meta, [new_key]}, value]}
            Sourceror.Zipper.replace(found, new_node) |> Sourceror.Zipper.top()

          _ ->
            acc_zipper
        end
      end)
    end

    # --- 0.14.0: Migrate Tailwind sources to new per-theme @import format ---

    @app_css_path "assets/css/app.css"
    @tailwind_v3_path "assets/tailwind.config.js"
    @v4_old_source "@source \"../../deps/cinder\";"
    @v4_new_import "@import \"../../deps/cinder/priv/cinder.css\";"
    @v3_old_entry "\"../deps/cinder/lib/**/*.*ex\","
    @v3_new_marker "\"../deps/cinder/lib/cinder.ex\""

    @doc false
    def migrate_tailwind_sources(igniter, _opts) do
      theme_name = resolved_theme_name()

      igniter = Igniter.include_existing_file(igniter, @app_css_path)
      igniter = Igniter.include_existing_file(igniter, @tailwind_v3_path)

      {igniter, v4?} =
        migrate_file(igniter, @app_css_path, @v4_new_import, @v4_old_source, fn ->
          v4_replacement(theme_name)
        end)

      {igniter, v3?} =
        migrate_file(igniter, @tailwind_v3_path, @v3_new_marker, @v3_old_entry, fn ->
          v3_replacement(theme_name)
        end)

      if v4? or v3?, do: add_upgrade_notice(igniter, theme_name), else: igniter
    end

    # Skips if `already_migrated_marker` is present; otherwise swaps `old_marker`
    # for `build_replacement.()` and reports whether the file changed.
    defp migrate_file(igniter, path, already_migrated_marker, old_marker, build_replacement) do
      with {:ok, source} <- Rewrite.source(igniter.rewrite, path),
           content = Rewrite.Source.get(source, :content),
           false <- String.contains?(content, already_migrated_marker),
           true <- String.contains?(content, old_marker) do
        new_content = String.replace(content, old_marker, build_replacement.(), global: false)
        source = Rewrite.Source.update(source, :content, new_content)
        {%{igniter | rewrite: Rewrite.update!(igniter.rewrite, source)}, true}
      else
        _ -> {igniter, false}
      end
    end

    defp v4_replacement(nil), do: @v4_new_import

    defp v4_replacement(name),
      do: @v4_new_import <> "\n@import \"../../deps/cinder/priv/themes/#{name}.css\";"

    defp v3_replacement(theme_name) do
      Cinder.Tailwind.v3_content_lines(theme_name)
      |> String.trim_trailing("\n")
      |> String.trim_leading()
    end

    # Resolves the configured default_theme into a built-in theme name string,
    # or `nil` if there's no default or it points at a custom module.
    defp resolved_theme_name do
      case Application.get_env(:cinder, :default_theme) do
        name when is_binary(name) ->
          if name in Cinder.Theme.built_in_theme_names(), do: name

        module when is_atom(module) and not is_nil(module) ->
          with "Elixir.Cinder.Themes." <> suffix <- Atom.to_string(module),
               name = Macro.underscore(suffix),
               true <- name in Cinder.Theme.built_in_theme_names() do
            name
          else
            _ -> nil
          end

        _ ->
          nil
      end
    end

    defp add_upgrade_notice(igniter, theme_name) do
      themes = Enum.join(Cinder.Theme.built_in_theme_names(), ", ")

      detail =
        if theme_name,
          do: "Your configured `default_theme` (#{theme_name}) was imported automatically.",
          else: "No matching built-in `default_theme` found, so no theme @import was added."

      Igniter.add_notice(igniter, """
      Migrated Cinder Tailwind config to the new @import format.
      #{detail}

      To use additional built-in themes on specific tables, @import their CSS:
        @import "../../deps/cinder/priv/themes/<name>.css";

      Available built-in themes: #{themes}.
      """)
    end
  end
else
  defmodule Mix.Tasks.Cinder.Upgrade do
    @moduledoc false

    use Mix.Task

    @impl Mix.Task
    def run(_argv) do
      Mix.shell().error("""
      The task 'cinder.upgrade' requires igniter. Please install igniter and try again.

      For more information, see: https://hexdocs.pm/igniter/readme.html#installation
      """)

      exit({:shutdown, 1})
    end
  end
end
