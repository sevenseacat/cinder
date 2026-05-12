if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.Cinder.Install do
    @example "mix cinder.install"

    @moduledoc """
    Installs Cinder and configures Tailwind CSS to include Cinder's styles.

    This installer ensures that all Tailwind CSS classes used by Cinder are
    included in your application's generated stylesheets by updating your
    Tailwind configuration.

    The installer also adds a Cinder configuration to your `config/config.exs`
    with a `:default_theme`.

    ## Recommended Installation

    For new installations, use Igniter:

    ```bash
    mix igniter.install cinder
    ```

    This will automatically add Cinder to your dependencies and run this installer.

    ## Manual Installation

    If you've already added Cinder to your dependencies manually:

    ```bash
    #{@example}
    ```

    ## What it does

    1. Adds Cinder's files to your Tailwind configuration content paths
    2. Provides setup instructions for using Cinder in your application
    3. Shows example usage to get you started quickly

    ## Tailwind Configuration

    The installer will attempt to automatically update your Tailwind configuration:

    - **Tailwind v3 and below**: Updates `tailwind.config.js` content array
    - **Tailwind v4**: Adds `@import` directives to your CSS file

    If automatic configuration fails, manual setup instructions will be provided.

    ## Next Steps

    After installation:

    1. Add Cinder.setup() to your Application.start/2 function (if using custom filters)
    2. Start using Cinder tables in your LiveView templates
    3. Explore the documentation for advanced features
    """

    @shortdoc "Install Cinder and configure Tailwind CSS"
    use Igniter.Mix.Task

    @impl Igniter.Mix.Task
    def info(_argv, _parent) do
      %Igniter.Mix.Task.Info{
        positional: [],
        example: @example,
        schema: []
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      igniter
      |> Igniter.Project.Formatter.import_dep(:cinder)
      |> configure_tailwind()
      |> configure_default_theme()
    end

    @tailwind_v3_prefix """
    module.exports = {
      content: [
    """

    @tailwind_v4_import "@import \"tailwindcss\""

    @default_theme "daisy_ui"

    defp configure_tailwind(igniter) do
      cond do
        Igniter.exists?(igniter, "assets/tailwind.config.js") ->
          configure_tailwind_v3(igniter)

        Igniter.exists?(igniter, "assets/css/app.css") ->
          configure_tailwind_v4(igniter)

        true ->
          explain_tailwind_setup(igniter)
      end
    end

    defp configure_tailwind_v3(igniter) do
      igniter = Igniter.include_glob(igniter, "assets/tailwind.config.js")
      source = Rewrite.source!(igniter.rewrite, "assets/tailwind.config.js")
      content = Rewrite.Source.get(source, :content)

      if String.contains?(content, "../deps/cinder/") do
        igniter
      else
        do_tailwind_v3_changes(igniter, content, source)
      end
    end

    defp do_tailwind_v3_changes(igniter, content, source) do
      case String.split(content, @tailwind_v3_prefix, parts: 2) do
        [prefix, suffix] ->
          source =
            Rewrite.Source.update(
              source,
              :content,
              prefix <>
                @tailwind_v3_prefix <>
                Cinder.Tailwind.v3_content_lines(@default_theme) <> suffix
            )

          %{igniter | rewrite: Rewrite.update!(igniter.rewrite, source)}

        _ ->
          explain_tailwind_setup(igniter)
      end
    end

    defp configure_tailwind_v4(igniter) do
      igniter = Igniter.include_glob(igniter, "assets/css/app.css")
      source = Rewrite.source!(igniter.rewrite, "assets/css/app.css")
      content = Rewrite.Source.get(source, :content)

      # Skip if any cinder source is already wired in (old @source or new @import).
      # Old format gets upgraded via `mix cinder.upgrade`.
      if String.contains?(content, "deps/cinder") do
        igniter
      else
        igniter
        |> do_tailwind_v4_changes(content, source)
        |> add_themes_notice()
      end
    end

    defp do_tailwind_v4_changes(igniter, content, source) do
      with true <- String.contains?(content, @tailwind_v4_import),
           [head, after_import] <- String.split(content, @tailwind_v4_import, parts: 2),
           [import_stuff, after_import] <- String.split(after_import, "\n", parts: 2) do
        updated_content =
          head <>
            @tailwind_v4_import <>
            import_stuff <>
            "\n" <>
            "@import \"../../deps/cinder/priv/cinder.css\";\n" <>
            "@import \"../../deps/cinder/priv/themes/#{@default_theme}.css\";\n" <>
            after_import

        source = Rewrite.Source.update(source, :content, updated_content)
        %{igniter | rewrite: Rewrite.update!(igniter.rewrite, source)}
      else
        _ ->
          explain_tailwind_setup(igniter)
      end
    end

    defp add_themes_notice(igniter) do
      others = Enum.join(Cinder.Theme.built_in_theme_names() -- [@default_theme], ", ")

      Igniter.add_notice(igniter, """
      Cinder Tailwind setup complete with the "#{@default_theme}" theme.

      To use additional built-in themes on specific tables, @import their CSS:
        @import "../../deps/cinder/priv/themes/<name>.css";

      Other built-in themes: #{others}.
      """)
    end

    defp explain_tailwind_setup(igniter) do
      Igniter.add_notice(igniter, """
      Cinder Installation:

      Cinder requires Tailwind CSS classes to be included in your build.
      Please update your Tailwind configuration manually:

      ## If using Tailwind v3 or below (tailwind.config.js):

      Add Cinder's files to your content configuration:

      ```javascript
      module.exports = {
        content: [
          "./js/**/*.js",
          "../lib/*_web.ex",
          "../lib/*_web/**/*.*ex",
          "../deps/cinder/lib/**/*.*ex", // <-- Add this line
        ],
        // ... rest of your config
      }
      ```

      ## If using Tailwind v4 (CSS configuration):

      Add these lines to your app.css file after the @import statement:

      ```css
      @import "tailwindcss";
      @import "../../deps/cinder/priv/cinder.css"; /* <-- Add this */
      @import "../../deps/cinder/priv/themes/#{@default_theme}.css"; /* <-- And this, for the theme you use */
      ```

      ## Troubleshooting:

      If you're still missing styles after configuration:

      1. Restart your development server
      2. Clear any CSS build cache
      3. Check that your Tailwind build process is running
      4. Verify the path to Cinder's files is correct for your setup
      """)
    end

    defp configure_default_theme(igniter) do
      if Igniter.Project.Config.configures_key?(igniter, "config.exs", :cinder, :default_theme) do
        igniter
      else
        igniter
        |> Igniter.Project.Config.configure(
          "config.exs",
          :cinder,
          [:default_theme],
          @default_theme
        )
      end
    end
  end
else
  defmodule Mix.Tasks.Cinder.Install do
    @moduledoc """
    Install Cinder and configure Tailwind CSS.

    This task requires Igniter to be available for automatic configuration management.
    """

    @shortdoc "Install Cinder and configure Tailwind CSS"
    use Mix.Task

    def run(_argv) do
      Mix.shell().error("""
      The task 'cinder.install' requires Igniter to be available for automatic configuration.

      ## Recommended Installation

      For the best experience, use Igniter to install Cinder:

          mix igniter.install cinder

      This will automatically add Cinder to your dependencies and configure Tailwind.

      ## Alternative Setup

      If you prefer to set up manually:

      1. Ensure Igniter is available:

          mix deps.get

      2. Then run this installer again:

          mix cinder.install

      For more information, see: https://hexdocs.pm/igniter

      ## Manual Tailwind Setup

      If you prefer to configure Tailwind manually:

      1. Add Cinder's files to your Tailwind configuration:

      **For Tailwind v3 and below (tailwind.config.js):**
      ```javascript
      module.exports = {
        content: [
          // ... your existing content
          "../deps/cinder/lib/**/*.*ex",
        ],
        // ... rest of config
      }
      ```

      **For Tailwind v4 (CSS configuration):**
      ```css
      @import "tailwindcss";
      @import "../../deps/cinder/priv/cinder.css";
      @import "../../deps/cinder/priv/themes/modern.css";
      ```

      2. Restart your development server

      3. Start using Cinder in your templates:
      ```elixir
      <Cinder.Table.table resource={MyApp.User} actor={@current_user}>
        <:col :let={user} field="name" filter sort>{user.name}</:col>
      </Cinder.Table.table>
      ```
      """)

      exit({:shutdown, 1})
    end
  end
end
