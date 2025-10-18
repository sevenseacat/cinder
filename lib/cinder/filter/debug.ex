defmodule Cinder.Filter.Debug do
  @moduledoc """
  Debugging tools for custom filter development.

  This module provides utilities to help developers debug and test their custom filters
  during development.

  ## Usage

  Enable debug mode in your configuration:

      config :cinder, debug_filters: true

  Then use the debugging functions in your filter:

      defmodule MyApp.Filters.CustomFilter do
        use Cinder.Filter
        import Cinder.Filter.Debug

        @impl true
        def process(raw_value, column) do
          debug_step("Processing input", %{raw_value: raw_value, column: column})

          result = # ... your processing logic

          debug_step("Process result", %{result: result})
          result
        end
      end

  """

  require Logger

  @doc """
  Logs a debug step with context information.

  Only logs when debug_filters is enabled in configuration.

  ## Examples

      debug_step("Validating input", %{input: "test", step: 1})

  """
  def debug_step(message, context \\ %{}) do
    if debug_enabled?() do
      Logger.debug("""
      [Cinder.Filter.Debug] #{message}
      Context: #{inspect(context, pretty: true, limit: :infinity)}
      """)
    end
  end

  @doc """
  Logs filter callback execution with timing.

  ## Examples

      debug_callback("process/2", fn ->
        # Your callback logic here
        process_implementation(raw_value, column)
      end)

  """
  def debug_callback(callback_name, fun) when is_function(fun, 0) do
    if debug_enabled?() do
      start_time = System.monotonic_time(:microsecond)

      result = fun.()

      end_time = System.monotonic_time(:microsecond)
      duration = end_time - start_time

      Logger.debug("""
      [Cinder.Filter.Debug] #{callback_name} completed
      Duration: #{duration}μs (#{Float.round(duration / 1000, 2)}ms)
      Result: #{inspect(result, pretty: true, limit: 50)}
      """)

      result
    else
      fun.()
    end
  end

  @doc """
  Validates and logs filter processing pipeline.

  Useful for debugging the complete flow from raw input to final filter.

  ## Examples

      debug_pipeline("MyFilter", raw_value, column, fn ->
        MyFilter.process(raw_value, column)
      end)

  """
  def debug_pipeline(filter_name, raw_value, column, process_fun) do
    if debug_enabled?() do
      Logger.debug("""
      [Cinder.Filter.Debug] #{filter_name} pipeline starting
      Raw input: #{inspect(raw_value)}
      Column config: #{inspect(column, limit: 10)}
      """)

      result = debug_callback("#{filter_name}.process/2", process_fun)

      Logger.debug("""
      [Cinder.Filter.Debug] #{filter_name} pipeline completed
      Final result: #{inspect(result, pretty: true)}
      """)

      result
    else
      process_fun.()
    end
  end

  @doc """
  Validates a filter's callbacks and logs any issues.

  Useful during development to ensure all callbacks are properly implemented.

  ## Examples

      debug_validate_filter(MyApp.Filters.CustomFilter)

  """
  def debug_validate_filter(module) when is_atom(module) do
    if debug_enabled?() do
      Logger.debug("[Cinder.Filter.Debug] Validating filter: #{module}")

      case Cinder.Filter.Helpers.validate_filter_implementation(module) do
        {:ok, message} ->
          Logger.debug("[Cinder.Filter.Debug] ✓ #{message}")
          :ok

        {:error, errors} ->
          Logger.error("""
          [Cinder.Filter.Debug] ✗ Filter validation failed: #{module}
          Errors:
          #{Enum.map_join(errors, "\n", &"  - #{&1}")}
          """)

          {:error, errors}
      end
    else
      :ok
    end
  end

  @doc """
  Tests filter processing with sample inputs and logs results.

  Useful for quick testing during development.

  ## Examples

      debug_test_inputs(MyApp.Filters.Slider, [
        {"50", %{filter_options: [min: 0, max: 100]}},
        {"invalid", %{filter_options: []}},
        {"", %{filter_options: []}}
      ])

  """
  def debug_test_inputs(module, test_cases) when is_atom(module) and is_list(test_cases) do
    if debug_enabled?() do
      Logger.debug(
        "[Cinder.Filter.Debug] Testing #{module} with #{length(test_cases)} test cases"
      )

      Enum.with_index(test_cases, 1)
      |> Enum.each(fn {{input, column}, index} ->
        Logger.debug("[Cinder.Filter.Debug] Test case #{index}: #{inspect(input)}")

        try do
          result = module.process(input, column)

          validation_result =
            if result do
              module.validate(result)
            else
              "N/A (nil result)"
            end

          Logger.debug("""
          [Cinder.Filter.Debug] Test case #{index} results:
            Input: #{inspect(input)}
            Column: #{inspect(column, limit: 5)}
            Process result: #{inspect(result)}
            Validation: #{validation_result}
            Empty?: #{if result, do: module.empty?(result), else: "N/A"}
          """)
        rescue
          error ->
            Logger.error("""
            [Cinder.Filter.Debug] Test case #{index} failed with error:
            #{inspect(error)}
            """)
        end
      end)
    end
  end

  @doc """
  Analyzes query building performance and logs the results.

  ## Examples

      debug_query_building(MyApp.Filters.Slider, "price", %{
        type: :slider,
        value: 100,
        operator: :less_than_or_equal
      })

  """
  def debug_query_building(module, field, filter_value) when is_atom(module) do
    if debug_enabled?() do
      Logger.debug("""
      [Cinder.Filter.Debug] Testing query building for #{module}
      Field: #{field}
      Filter value: #{inspect(filter_value)}
      """)

      # Create a dummy query for testing
      dummy_query = Ash.Query.new(DummyResource)

      start_time = System.monotonic_time(:microsecond)

      try do
        result_query = module.build_query(dummy_query, field, filter_value)

        end_time = System.monotonic_time(:microsecond)
        duration = end_time - start_time

        Logger.debug("""
        [Cinder.Filter.Debug] Query building completed
        Duration: #{duration}μs
        Query modified: #{result_query != dummy_query}
        """)

        result_query
      rescue
        error ->
          Logger.error("""
          [Cinder.Filter.Debug] Query building failed:
          #{inspect(error)}
          """)

          dummy_query
      end
    else
      # In non-debug mode, just return a dummy query
      Ash.Query.new(DummyResource)
    end
  end

  @doc """
  Logs render performance and output size.

  ## Examples

      debug_render_performance(MyApp.Filters.Slider, column, current_value, theme, assigns)

  """
  def debug_render_performance(module, column, current_value, theme, assigns) do
    if debug_enabled?() do
      start_time = System.monotonic_time(:microsecond)

      result = module.render(column, current_value, theme, assigns)

      end_time = System.monotonic_time(:microsecond)
      duration = end_time - start_time

      # Estimate rendered size (approximate)
      rendered_size = result |> Phoenix.HTML.Safe.to_iodata() |> IO.iodata_length()

      Logger.debug("""
      [Cinder.Filter.Debug] Render performance for #{module}
      Duration: #{duration}μs
      Rendered size: #{rendered_size} bytes
      Field: #{column.field}
      Current value: #{inspect(current_value)}
      """)

      result
    else
      module.render(column, current_value, theme, assigns)
    end
  end

  @doc """
  Checks if debug mode is enabled.
  """
  def debug_enabled? do
    Application.get_env(:cinder, :debug_filters, false)
  end

  @doc """
  Enables debug mode for the current session.

  Useful in IEx for temporary debugging.

  ## Examples

      iex> Cinder.Filter.Debug.enable_debug()
      :ok

  """
  def enable_debug do
    Application.put_env(:cinder, :debug_filters, true)
    Logger.info("[Cinder.Filter.Debug] Debug mode enabled")
  end

  @doc """
  Disables debug mode for the current session.

  ## Examples

      iex> Cinder.Filter.Debug.disable_debug()
      :ok

  """
  def disable_debug do
    Application.put_env(:cinder, :debug_filters, false)
    Logger.info("[Cinder.Filter.Debug] Debug mode disabled")
  end

  @doc """
  Runs a comprehensive filter test suite.

  Tests all callbacks with various inputs and logs results.

  ## Examples

      debug_comprehensive_test(MyApp.Filters.Slider)

  """
  def debug_comprehensive_test(module) when is_atom(module) do
    if debug_enabled?() do
      Logger.info("[Cinder.Filter.Debug] Running comprehensive test for #{module}")

      # Test validation
      debug_validate_filter(module)

      # Test default options
      try do
        options = module.default_options()
        Logger.debug("[Cinder.Filter.Debug] Default options: #{inspect(options)}")
      rescue
        error ->
          Logger.error("[Cinder.Filter.Debug] default_options/0 failed: #{inspect(error)}")
      end

      # Test common process inputs
      test_inputs = [
        "",
        nil,
        "valid_input",
        "123",
        "invalid",
        []
      ]

      column = %{filter_options: []}

      Enum.each(test_inputs, fn input ->
        try do
          result = module.process(input, column)

          if result do
            validation = module.validate(result)
            empty_check = module.empty?(result)

            Logger.debug("""
            [Cinder.Filter.Debug] Process test:
              Input: #{inspect(input)}
              Result: #{inspect(result)}
              Valid: #{validation}
              Empty: #{empty_check}
            """)
          else
            Logger.debug("[Cinder.Filter.Debug] Process test: #{inspect(input)} -> nil")
          end
        rescue
          error ->
            Logger.error(
              "[Cinder.Filter.Debug] Process failed for #{inspect(input)}: #{inspect(error)}"
            )
        end
      end)

      Logger.info("[Cinder.Filter.Debug] Comprehensive test completed for #{module}")
    end
  end

  # Dummy resource for query testing
  defmodule DummyResource do
    @moduledoc false
    use Ash.Resource, data_layer: Ash.DataLayer.Ets, domain: nil

    attributes do
      integer_primary_key(:id)
      attribute(:name, :string)
      attribute(:value, :integer)
      attribute(:active, :boolean)
    end
  end
end
