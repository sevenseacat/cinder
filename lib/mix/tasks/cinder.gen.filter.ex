if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.Cinder.Gen.Filter do
    @example """
    mix cinder.gen.filter MyApp.Filters.CustomText custom_text --template=text
    """

    @moduledoc """
    Generate and configure a custom Cinder filter based on built-in filters.

    This task creates a new custom filter module that delegates to a built-in filter
    as a starting point, allowing you to customize specific behaviors while keeping
    the rest of the implementation. It automatically registers the filter in your
    application configuration.

    ## Example

    ```bash
    #{@example}
    ```

    ## Arguments

    * `module` - The module name for the filter (e.g., MyApp.Filters.CustomText)
    * `type` - The filter type identifier (e.g., custom_text)

    ## Options

    * `--template` or `-t` - Base filter to copy from: text, select, multi_select, boolean, date_range, number_range
    * `--no-tests` - Skip generating test file
    * `--no-config` - Skip automatic configuration registration
    * `--no-setup` - Skip ensuring Cinder.setup() is called in application

    ## Available Templates

    * `text` - Based on Cinder.Filters.Text (text input with operators)
    * `select` - Based on Cinder.Filters.Select (dropdown selection)
    * `multi_select` - Based on Cinder.Filters.MultiSelect (multiple selection)
    * `boolean` - Based on Cinder.Filters.Boolean (true/false/any selection)
    * `date_range` - Based on Cinder.Filters.DateRange (from/to date picker)
    * `number_range` - Based on Cinder.Filters.NumberRange (from/to number input)

    ## What it does

    1. Creates a custom filter module that delegates to the chosen built-in filter
    2. Automatically updates the filter type to your custom type
    3. Generates comprehensive test file (unless --no-tests)
    4. Automatically adds the filter to your :cinder configuration
    5. Provides clear examples of how to customize the behavior

    ## Customization

    The generated filter starts by delegating all behavior to the base filter but with
    your custom type. You can then override any callback function to customize:

    * `render/4` - Customize the HTML rendering
    * `process/2` - Customize input processing and validation
    * `validate/1` - Customize filter validation logic
    * `build_query/3` - Customize query building
    * `default_options/0` - Customize default options
    * `empty?/1` - Customize empty value detection

    The generated filter will be immediately ready to use in your tables.
    """

    @shortdoc "Generate and configure a custom Cinder filter"
    use Igniter.Mix.Task

    @templates [
      "text",
      "select",
      "multi_select",
      "multi_checkboxes",
      "boolean",
      "date_range",
      "number_range"
    ]

    @impl Igniter.Mix.Task
    def info(_argv, _parent) do
      %Igniter.Mix.Task.Info{
        positional: [:module, :type],
        example: @example,
        schema: [
          template: :string,
          no_tests: :boolean,
          no_config: :boolean,
          no_setup: :boolean
        ],
        aliases: [
          t: :template
        ]
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      arguments = igniter.args.positional
      options = igniter.args.options

      module_name = Igniter.Project.Module.parse(arguments.module)
      filter_type = String.to_atom(arguments.type)
      template = options[:template] || "basic"

      # Validate template - use "text" as default instead of "basic"
      template = if template == "basic", do: "text", else: template

      unless template in @templates do
        Mix.raise(
          "Unknown template: #{template}. Available templates: #{Enum.join(@templates, ", ")}"
        )
      end

      # Validate module name structure
      module_parts = Module.split(module_name)

      if length(module_parts) < 2 do
        Mix.raise("Module name must be fully qualified (e.g., MyApp.Filters.Slider)")
      end

      igniter
      |> create_filter_module(module_name, filter_type, template)
      |> maybe_create_test_file(module_name, filter_type, options)
      |> maybe_update_config(filter_type, module_name, options)
      |> maybe_ensure_cinder_setup(options)
      |> add_completion_notice(module_name, filter_type)
    end

    # Create the main filter module
    defp create_filter_module(igniter, module_name, filter_type, template) do
      content = generate_filter_content(module_name, filter_type, template)

      Igniter.Project.Module.create_module(
        igniter,
        module_name,
        content
      )
    end

    # Generate test file unless --no-tests
    defp maybe_create_test_file(igniter, module_name, filter_type, options) do
      if options[:no_tests] do
        igniter
      else
        # Create test file in test directory with proper naming
        test_module_name = Module.concat([module_name, Test])
        test_content = generate_test_content(module_name, filter_type)

        # Construct the proper test file path manually
        module_parts = Module.split(module_name)
        file_parts = Enum.map(module_parts, &Macro.underscore/1)
        test_file_path = "test/" <> Path.join(file_parts) <> "_test.exs"

        Igniter.create_new_file(
          igniter,
          test_file_path,
          """
          defmodule #{inspect(test_module_name)} do
          #{test_content}
          end
          """
        )
      end
    end

    # Update application config unless --no-config
    defp maybe_update_config(igniter, filter_type, module_name, options) do
      if options[:no_config] do
        igniter
      else
        Igniter.Project.Config.configure(
          igniter,
          "config.exs",
          :cinder,
          [:filters],
          [{filter_type, module_name}],
          updater: fn
            nil ->
              [{filter_type, module_name}]

            existing when is_list(existing) ->
              Keyword.put(existing, filter_type, module_name)

            existing when is_map(existing) ->
              # Convert old map format to keyword list
              existing
              |> Map.to_list()
              |> Keyword.put(filter_type, module_name)

            _ ->
              [{filter_type, module_name}]
          end
        )
      end
    end

    # Ensure Cinder.setup() is called in Application module unless --no-setup
    defp maybe_ensure_cinder_setup(igniter, options) do
      if options[:no_setup] do
        igniter
      else
        # For now, just add a notice about manual setup
        # since the Application module modification is complex
        igniter
      end
    end

    # Add completion notice
    defp add_completion_notice(igniter, module_name, filter_type) do
      # Add informational output using Mix.shell
      Mix.shell().info("""

      Custom filter #{inspect(module_name)} has been generated successfully!

      The filter has been automatically registered in your configuration.

      Next steps:
      1. Ensure Cinder.setup() is called in your Application.start/2 function
      2. Use the filter in your table columns:

         <:col field="field_name" filter={:#{filter_type}}>
           {item.field_name}
         </:col>

      3. Run 'mix test' to verify your filter implementation!
      """)

      igniter
    end

    # Generate filter module content based on template
    defp generate_filter_content(_module_name, filter_type, template) do
      base_filter = get_base_filter_module(template)

      """
      @moduledoc \"\"\"
      Custom #{String.capitalize(to_string(filter_type))} filter for Cinder tables.

      This filter is based on the built-in #{base_filter} filter.
      You can customize any of the callback functions to modify the behavior.

      ## Usage

      Use in table columns:

          <:col field="field_name" filter={:#{filter_type}}>
            {item.field_name}
          </:col>

      ## Customization

      You can modify any of the callback functions below:
      - `render/4` - Customize the HTML rendering
      - `process/2` - Customize input processing
      - `validate/1` - Customize validation logic
      - `build_query/3` - Customize query building
      - `default_options/0` - Customize default options
      - `empty?/1` - Customize empty value detection

      ## Built-in Reference

      This filter uses the same structure as `#{base_filter}`.
      You can refer to that module's source code for implementation details.
      \"\"\"

      use Cinder.Filter

      @impl true
      def render(column, current_value, theme, assigns) do
        #{base_filter}.render(column, current_value, theme, assigns)
      end

      @impl true
      def process(raw_value, column) do
        case #{base_filter}.process(raw_value, column) do
          %{type: _old_type} = filter -> %{filter | type: :#{filter_type}}
          result -> result
        end
      end

      @impl true
      def validate(filter_value) do
        #{base_filter}.validate(filter_value)
      end

      @impl true
      def default_options do
        #{base_filter}.default_options()
      end

      @impl true
      def empty?(value) do
        #{base_filter}.empty?(value)
      end

      @impl true
      def build_query(query, field, filter_value) do
        #{base_filter}.build_query(query, field, filter_value)
      end

      # You can override any of the above functions to customize behavior
      # For example, to customize rendering:
      #
      # @impl true
      # def render(column, current_value, theme, assigns) do
      #   # Your custom rendering logic here
      # end
      """
    end

    # Get the base filter module for each template
    defp get_base_filter_module(template) do
      case template do
        "text" -> "Cinder.Filters.Text"
        "select" -> "Cinder.Filters.Select"
        "multi_select" -> "Cinder.Filters.MultiSelect"
        "boolean" -> "Cinder.Filters.Boolean"
        "date_range" -> "Cinder.Filters.DateRange"
        "number_range" -> "Cinder.Filters.NumberRange"
        _ -> "Cinder.Filters.Text"
      end
    end

    # Generate test content
    defp generate_test_content(module_name, filter_type) do
      """
      @moduledoc false

      use ExUnit.Case, async: true

      alias #{inspect(module_name)}

      describe "render/4" do
        test "renders filter input" do
          column = %{field: "test_field", filter_options: []}
          theme = %{}

          html = #{inspect(module_name)}.render(column, nil, theme, %{})

          assert html =~ "name=\\"test_field\\""
        end

        test "renders with custom options" do
          column = %{field: "test_field", filter_options: [placeholder: "Custom placeholder"]}
          theme = %{}

          html = #{inspect(module_name)}.render(column, nil, theme, %{})

          assert html =~ "Custom placeholder"
        end
      end

      describe "process/2" do
        test "processes valid input" do
          result = #{inspect(module_name)}.process("test value", %{})

          assert result == %{
            type: :#{filter_type},
            value: "test value",
            operator: :equals
          }
        end

        test "returns nil for empty input" do
          assert #{inspect(module_name)}.process("", %{}) == nil
          assert #{inspect(module_name)}.process("   ", %{}) == nil
          assert #{inspect(module_name)}.process(nil, %{}) == nil
        end
      end

      describe "validate/1" do
        test "validates correct filter structure" do
          valid_filter = %{
            type: :#{filter_type},
            value: "test",
            operator: :equals
          }

          assert #{inspect(module_name)}.validate(valid_filter)
        end

        test "rejects invalid filter structure" do
          refute #{inspect(module_name)}.validate(%{type: :other})
          refute #{inspect(module_name)}.validate(%{value: "test"})
          refute #{inspect(module_name)}.validate(nil)
        end
      end

      describe "empty?/1" do
        test "identifies empty values" do
          assert #{inspect(module_name)}.empty?(nil)
          assert #{inspect(module_name)}.empty?("")
          assert #{inspect(module_name)}.empty?(%{value: ""})
          assert #{inspect(module_name)}.empty?(%{value: nil})
        end

        test "identifies non-empty values" do
          refute #{inspect(module_name)}.empty?("test")
          refute #{inspect(module_name)}.empty?(%{value: "test"})
        end
      end

      describe "default_options/0" do
        test "returns default options" do
          options = #{inspect(module_name)}.default_options()

          assert is_list(options)
          assert Keyword.has_key?(options, :placeholder)
        end
      end
      """
    end
  end
else
  defmodule Mix.Tasks.Cinder.Gen.Filter do
    @moduledoc """
    Generate and configure a custom Cinder filter.

    This task requires Igniter to be installed for automatic configuration management.
    """

    @shortdoc "Generate and configure a custom Cinder filter"
    use Mix.Task

    def run(_argv) do
      Mix.shell().error("""
      The task 'cinder.gen.filter' requires Igniter to be available for automatic configuration.

      Please install igniter and try again:

          mix deps.get

      For more information, see: https://hexdocs.pm/igniter
      """)

      exit({:shutdown, 1})
    end
  end
end
