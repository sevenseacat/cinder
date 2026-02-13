if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.Cinder.Upgrade do
    @moduledoc false

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
          "0.10.0" => [&rename_boolean_theme_keys/2]
        }

      Igniter.Upgrades.run(igniter, positional.from, positional.to, upgrades,
        custom_opts: options
      )
    end

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
        # Re-find the node from the current accumulator zipper
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
