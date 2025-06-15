defmodule Cinder.Filter.Helpers do
  @moduledoc """
  Helper functions for building and validating custom filters.

  This module provides common patterns and utilities that custom filter
  developers can use to simplify their implementations.

  ## Usage

      defmodule MyApp.Filters.CustomFilter do
        use Cinder.Filter
        import Cinder.Filter.Helpers

        @impl true
        def process(raw_value, column) do
          with {:ok, trimmed} <- validate_string_input(raw_value),
               {:ok, parsed} <- parse_custom_value(trimmed) do
            build_filter(:my_filter, parsed, :equals)
          else
            _ -> nil
          end
        end
      end

  """

  @doc """
  Validates and trims string input, returning error for empty strings.

  ## Examples

      iex> validate_string_input("  hello  ")
      {:ok, "hello"}

      iex> validate_string_input("")
      {:error, :empty}

      iex> validate_string_input(nil)
      {:error, :invalid}

  """
  def validate_string_input(value) when is_binary(value) do
    trimmed = String.trim(value)

    if trimmed == "" do
      {:error, :empty}
    else
      {:ok, trimmed}
    end
  end

  def validate_string_input(_), do: {:error, :invalid}

  @doc """
  Validates integer input with optional min/max bounds.

  ## Examples

      iex> validate_integer_input("42")
      {:ok, 42}

      iex> validate_integer_input("42", min: 0, max: 100)
      {:ok, 42}

      iex> validate_integer_input("150", max: 100)
      {:error, :out_of_bounds}

      iex> validate_integer_input("abc")
      {:error, :invalid}

  """
  def validate_integer_input(input, opts \\ [])

  def validate_integer_input(input, opts) when is_binary(input) do
    case Integer.parse(input) do
      {int_value, ""} ->
        min_value = Keyword.get(opts, :min)
        max_value = Keyword.get(opts, :max)

        cond do
          min_value && int_value < min_value -> {:error, :out_of_bounds}
          max_value && int_value > max_value -> {:error, :out_of_bounds}
          true -> {:ok, int_value}
        end

      _ ->
        {:error, :invalid}
    end
  end

  def validate_integer_input(_, _), do: {:error, :invalid}

  @doc """
  Validates float input with optional min/max bounds.

  ## Examples

      iex> validate_float_input("42.5")
      {:ok, 42.5}

      iex> validate_float_input("42.5", min: 0.0, max: 100.0)
      {:ok, 42.5}

      iex> validate_float_input("150.0", max: 100.0)
      {:error, :out_of_bounds}

      iex> validate_float_input("abc")
      {:error, :invalid}

  """
  def validate_float_input(input, opts \\ [])

  def validate_float_input(input, opts) when is_binary(input) do
    case Float.parse(input) do
      {float_value, ""} ->
        min_value = Keyword.get(opts, :min)
        max_value = Keyword.get(opts, :max)

        cond do
          min_value && float_value < min_value -> {:error, :out_of_bounds}
          max_value && float_value > max_value -> {:error, :out_of_bounds}
          true -> {:ok, float_value}
        end

      _ ->
        {:error, :invalid}
    end
  end

  def validate_float_input(_, _), do: {:error, :invalid}

  @doc """
  Validates date input in ISO 8601 format.

  ## Examples

      iex> validate_date_input("2023-12-25")
      {:ok, ~D[2023-12-25]}

      iex> validate_date_input("invalid-date")
      {:error, :invalid}

  """
  def validate_date_input(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> {:ok, date}
      _ -> {:error, :invalid}
    end
  end

  def validate_date_input(_), do: {:error, :invalid}

  @doc """
  Validates hex color input.

  ## Examples

      iex> validate_hex_color_input("#FF0000")
      {:ok, "#ff0000"}

      iex> validate_hex_color_input("#fff")
      {:error, :invalid}

      iex> validate_hex_color_input("red")
      {:error, :invalid}

  """
  def validate_hex_color_input(value) when is_binary(value) do
    trimmed = String.trim(value)

    if Regex.match?(~r/^#[0-9A-Fa-f]{6}$/, trimmed) do
      {:ok, String.downcase(trimmed)}
    else
      {:error, :invalid}
    end
  end

  def validate_hex_color_input(_), do: {:error, :invalid}

  @doc """
  Validates and parses comma-separated values.

  ## Examples

      iex> validate_csv_input("a,b,c")
      {:ok, ["a", "b", "c"]}

      iex> validate_csv_input("a, b , c ", trim: true)
      {:ok, ["a", "b", "c"]}

      iex> validate_csv_input("", min_length: 1)
      {:error, :empty}

  """
  def validate_csv_input(input, opts \\ [])

  def validate_csv_input(input, opts) when is_binary(input) do
    separator = Keyword.get(opts, :separator, ",")
    trim_values = Keyword.get(opts, :trim, true)
    min_length = Keyword.get(opts, :min_length, 0)
    max_length = Keyword.get(opts, :max_length, 1000)

    values =
      input
      |> String.split(separator)
      |> Enum.map(fn val -> if trim_values, do: String.trim(val), else: val end)
      |> Enum.reject(&(&1 == ""))

    cond do
      length(values) < min_length -> {:error, :empty}
      length(values) > max_length -> {:error, :too_many}
      true -> {:ok, values}
    end
  end

  def validate_csv_input(_, _), do: {:error, :invalid}

  @doc """
  Builds a standard filter map.

  ## Examples

      iex> build_filter(:my_filter, "value", :equals)
      %{type: :my_filter, value: "value", operator: :equals}

      iex> build_filter(:slider, 50, :less_than_or_equal, case_sensitive: false)
      %{type: :slider, value: 50, operator: :less_than_or_equal, case_sensitive: false}

  """
  def build_filter(type, value, operator, extra_fields \\ []) do
    base_filter = %{
      type: type,
      value: value,
      operator: operator
    }

    Enum.reduce(extra_fields, base_filter, fn {key, val}, acc ->
      Map.put(acc, key, val)
    end)
  end

  @doc """
  Validates a filter structure has required fields.

  ## Examples

      iex> validate_filter_structure(%{type: :text, value: "test", operator: :equals})
      {:ok, %{type: :text, value: "test", operator: :equals}}

      iex> validate_filter_structure(%{type: :text, value: "test"})
      {:error, :missing_operator}

  """
  def validate_filter_structure(filter) when is_map(filter) do
    required_fields = [:type, :value, :operator]

    missing_fields =
      required_fields
      |> Enum.reject(&Map.has_key?(filter, &1))

    if Enum.empty?(missing_fields) do
      {:ok, filter}
    else
      {:error, {:missing_fields, missing_fields}}
    end
  end

  def validate_filter_structure(_), do: {:error, :invalid_structure}

  @doc """
  Validates operator is in allowed list.

  ## Examples

      iex> validate_operator(:equals, [:equals, :contains])
      {:ok, :equals}

      iex> validate_operator(:invalid, [:equals, :contains])
      {:error, :invalid_operator}

  """
  def validate_operator(operator, allowed_operators) when is_atom(operator) do
    if operator in allowed_operators do
      {:ok, operator}
    else
      {:error, :invalid_operator}
    end
  end

  def validate_operator(_, _), do: {:error, :invalid_operator}

  @doc """
  Builds a relationship-aware Ash query filter.

  Handles both direct fields and relationship fields using dot notation.

  ## Examples

      build_ash_filter(query, "name", "John", :equals)
      build_ash_filter(query, "user.name", "John", :equals)

  """
  def build_ash_filter(query, field, value, operator) when is_binary(field) do
    require Ash.Query
    import Ash.Expr

    if String.contains?(field, ".") do
      # Handle relationship fields
      path_atoms = field |> String.split(".") |> Enum.map(&String.to_atom/1)
      {rel_path, [field_atom]} = Enum.split(path_atoms, -1)

      apply_operator_to_relationship(query, rel_path, field_atom, value, operator)
    else
      # Direct field
      field_atom = String.to_atom(field)
      apply_operator_to_field(query, field_atom, value, operator)
    end
  end

  defp apply_operator_to_relationship(query, rel_path, field_atom, value, operator) do
    require Ash.Query
    import Ash.Expr

    case operator do
      :equals ->
        Ash.Query.filter(query, exists(^rel_path, ^ref(field_atom) == ^value))

      :contains ->
        Ash.Query.filter(query, exists(^rel_path, contains(^ref(field_atom), ^value)))

      :starts_with ->
        Ash.Query.filter(query, exists(^rel_path, contains(^ref(field_atom), ^value)))

      :ends_with ->
        Ash.Query.filter(query, exists(^rel_path, contains(^ref(field_atom), ^value)))

      :greater_than ->
        Ash.Query.filter(query, exists(^rel_path, ^ref(field_atom) > ^value))

      :greater_than_or_equal ->
        Ash.Query.filter(query, exists(^rel_path, ^ref(field_atom) >= ^value))

      :less_than ->
        Ash.Query.filter(query, exists(^rel_path, ^ref(field_atom) < ^value))

      :less_than_or_equal ->
        Ash.Query.filter(query, exists(^rel_path, ^ref(field_atom) <= ^value))

      :in when is_list(value) ->
        Ash.Query.filter(query, exists(^rel_path, ^ref(field_atom) in ^value))

      _ ->
        query
    end
  end

  defp apply_operator_to_field(query, field_atom, value, operator) do
    require Ash.Query
    import Ash.Expr

    case operator do
      :equals ->
        Ash.Query.filter(query, ^ref(field_atom) == ^value)

      :contains ->
        Ash.Query.filter(query, contains(^ref(field_atom), ^value))

      :starts_with ->
        Ash.Query.filter(query, contains(^ref(field_atom), ^value))

      :ends_with ->
        Ash.Query.filter(query, contains(^ref(field_atom), ^value))

      :greater_than ->
        Ash.Query.filter(query, ^ref(field_atom) > ^value)

      :greater_than_or_equal ->
        Ash.Query.filter(query, ^ref(field_atom) >= ^value)

      :less_than ->
        Ash.Query.filter(query, ^ref(field_atom) < ^value)

      :less_than_or_equal ->
        Ash.Query.filter(query, ^ref(field_atom) <= ^value)

      :in when is_list(value) ->
        Ash.Query.filter(query, ^ref(field_atom) in ^value)

      _ ->
        query
    end
  end

  @doc """
  Common empty value check for most filter types.

  ## Examples

      iex> is_empty_value?(nil)
      true

      iex> is_empty_value?("")
      true

      iex> is_empty_value?([])
      true

      iex> is_empty_value?(%{value: nil})
      true

      iex> is_empty_value?("test")
      false

  """
  def is_empty_value?(value) do
    case value do
      nil -> true
      "" -> true
      [] -> true
      %{value: nil} -> true
      %{value: ""} -> true
      %{value: []} -> true
      _ -> false
    end
  end

  @doc """
  Extracts filter options with type safety.

  ## Examples

      iex> extract_option([min: 0, max: 100], :min, 50)
      0

      iex> extract_option([], :min, 50)
      50

      iex> extract_option(%{min: 0, max: 100}, :min, 50)
      0

  """
  def extract_option(options, key, default) when is_list(options) do
    Keyword.get(options, key, default)
  end

  def extract_option(options, key, default) when is_map(options) do
    Map.get(options, key, default)
  end

  def extract_option(_, _, default), do: default

  @doc """
  Debug helper for filter development.

  Logs filter processing information when debug is enabled.

  ## Examples

      debug_filter("MyFilter", "processing input", %{input: "test"})

  """
  def debug_filter(filter_name, message, data \\ %{}) do
    if Application.get_env(:cinder, :debug_filters, false) do
      require Logger

      Logger.debug("""
      [Cinder.Filter.Debug] #{filter_name}: #{message}
      Data: #{inspect(data, pretty: true)}
      """)
    end
  end

  @doc """
  Validates that a module properly implements the Cinder.Filter behaviour.

  ## Examples

      iex> validate_filter_implementation(MyApp.Filters.ValidFilter)
      {:ok, "Filter implementation is valid"}

      iex> validate_filter_implementation(InvalidModule)
      {:error, ["Missing callback: render/4", "Missing callback: process/2"]}

  """
  def validate_filter_implementation(module) when is_atom(module) do
    required_callbacks = [
      {:render, 4},
      {:process, 2},
      {:validate, 1},
      {:default_options, 0},
      {:empty?, 1},
      {:build_query, 3}
    ]

    missing_callbacks =
      required_callbacks
      |> Enum.reject(fn {function, arity} ->
        function_exported?(module, function, arity)
      end)
      |> Enum.map(fn {function, arity} -> "Missing callback: #{function}/#{arity}" end)

    if Enum.empty?(missing_callbacks) do
      {:ok, "Filter implementation is valid"}
    else
      {:error, missing_callbacks}
    end
  end

  def validate_filter_implementation(_), do: {:error, ["Invalid module"]}
end
