defmodule Mix.Tasks.Cinder.Next.ConvertTheme do
  @shortdoc "Spike: converts an Elixir theme into a CSS theme for Cinder.Next"

  @moduledoc """
  Spike: converts an Elixir theme into a CSS theme for `Cinder.Next`, using
  `@apply` (see `Cinder.Next.ThemeCss`).

      mix cinder.next.convert_theme MyAppWeb.CinderTheme assets/css/cinder_theme.css
      mix cinder.next.convert_theme modern priv/next_themes/modern_converted.css --scope modern-converted

  `--scope` wraps it in `[data-cinder-theme="<scope>"]`.
  """
  use Mix.Task

  @impl true
  def run(args) do
    {opts, [theme, path], _} = OptionParser.parse(args, strict: [scope: :string])
    Mix.Task.run("compile")

    theme = if theme =~ ~r/^[A-Z]/, do: Module.concat([theme]), else: theme
    css = Cinder.Next.ThemeCss.convert(theme, scope: opts[:scope])

    File.write!(path, css)
    Mix.shell().info("Wrote #{path}")
  end
end
