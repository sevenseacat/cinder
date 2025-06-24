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
  Builds a relationship-aware Ash query filter with embedded field support.

  Handles direct fields, relationship fields using dot notation, and embedded fields using bracket notation.

  ## Examples

      build_ash_filter(query, "name", "John", :equals)
      build_ash_filter(query, "user.name", "John", :equals)
      build_ash_filter(query, "profile[:first_name]", "John", :equals)
      build_ash_filter(query, "settings[:address][:street]", "Main St", :contains)

  """
  def build_ash_filter(query, field, value, operator) when is_binary(field) do
    require Ash.Query
    import Ash.Expr

    case parse_field_notation(field) do
      {:direct, field_name} ->
        field_atom = String.to_atom(field_name)
        apply_operator_to_field(query, field_atom, value, operator)

      {:relationship, rel_path, field_name} ->
        rel_path_atoms = Enum.map(rel_path, &String.to_atom/1)
        field_atom = String.to_atom(field_name)
        apply_operator_to_relationship(query, rel_path_atoms, field_atom, value, operator)

      {:embedded, embed_field, field_name} ->
        embed_atom = String.to_atom(embed_field)
        field_atom = String.to_atom(field_name)
        apply_operator_to_embedded(query, embed_atom, field_atom, value, operator)

      {:nested_embedded, embed_field, field_path} ->
        embed_atom = String.to_atom(embed_field)
        apply_operator_to_nested_embedded(query, embed_atom, field_path, value, operator)

      {:relationship_embedded, rel_path, embed_field, field_name} ->
        rel_path_atoms = Enum.map(rel_path, &String.to_atom/1)
        embed_atom = String.to_atom(embed_field)
        field_atom = String.to_atom(field_name)

        apply_operator_to_relationship_embedded(
          query,
          rel_path_atoms,
          embed_atom,
          field_atom,
          value,
          operator
        )

      {:relationship_nested_embedded, rel_path, embed_field, field_path} ->
        rel_path_atoms = Enum.map(rel_path, &String.to_atom/1)
        embed_atom = String.to_atom(embed_field)

        apply_operator_to_relationship_nested_embedded(
          query,
          rel_path_atoms,
          embed_atom,
          field_path,
          value,
          operator
        )

      {:invalid, _} ->
        # Return query unchanged for invalid field notation
        query
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

  @doc """
  Parses field notation to determine field type and structure.

  ## Examples

      iex> parse_field_notation("username")
      {:direct, "username"}

      iex> parse_field_notation("user.name")
      {:relationship, ["user"], "name"}

      iex> parse_field_notation("profile[:first_name]")
      {:embedded, "profile", "first_name"}

      iex> parse_field_notation("settings[:address][:street]")
      {:nested_embedded, "settings", ["address", "street"]}

  """
  def parse_field_notation(field) when is_binary(field) do
    trimmed = String.trim(field)

    cond do
      trimmed == "" ->
        {:invalid, field}

      # Check for invalid bracket notation (missing colon)
      String.contains?(trimmed, "[") and not String.contains?(trimmed, "[:") ->
        {:invalid, field}

      # Check for whitespace in field names
      String.contains?(trimmed, " ") ->
        {:invalid, field}

      # Check for unclosed brackets
      String.contains?(trimmed, "[:") and not String.ends_with?(trimmed, "]") ->
        {:invalid, field}

      String.contains?(trimmed, "[:") ->
        parse_embedded_field_notation(trimmed)

      String.contains?(trimmed, ".") ->
        parse_relationship_field_notation(trimmed)

      true ->
        {:direct, trimmed}
    end
  end

  # Parses embedded field notation like "profile[:first_name]" or "settings[:address][:street]"
  defp parse_embedded_field_notation(field) do
    cond do
      # Check for mixed relationship + embedded: "user.profile[:first_name]"
      String.contains?(field, ".") and String.contains?(field, "[:") ->
        parse_mixed_relationship_embedded(field)

      # Pure embedded field notation
      true ->
        parse_pure_embedded_field(field)
    end
  end

  # Parses mixed relationship and embedded notation like "user.profile[:first_name]"
  defp parse_mixed_relationship_embedded(field) do
    case String.split(field, "[:") do
      [relationship_part | embed_parts] ->
        # Split relationship part by dots
        rel_parts = String.split(relationship_part, ".")

        case rel_parts do
          rel_path when length(rel_path) >= 2 ->
            # Extract the embedded field name (last part before [:)
            {rel_path_init, [embed_field]} = Enum.split(rel_parts, -1)

            case parse_embedded_field_from_parts(embed_parts) do
              {field_name} when is_binary(field_name) ->
                {:relationship_embedded, rel_path_init, embed_field, field_name}

              {field_path} when is_list(field_path) ->
                {:relationship_nested_embedded, rel_path_init, embed_field, field_path}

              :invalid ->
                {:invalid, field}
            end

          _ ->
            {:invalid, field}
        end

      _ ->
        {:invalid, field}
    end
  end

  # Parses pure embedded field notation like "profile[:first_name]" or "settings[:address][:street]"
  defp parse_pure_embedded_field(field) do
    case String.split(field, "[:") do
      [embed_field | field_parts] ->
        case parse_embedded_field_from_parts(field_parts) do
          {field_name} when is_binary(field_name) ->
            {:embedded, embed_field, field_name}

          {field_path} when is_list(field_path) ->
            {:nested_embedded, embed_field, field_path}

          :invalid ->
            {:invalid, field}
        end

      _ ->
        {:invalid, field}
    end
  end

  # Helper to parse the embedded field parts from bracket notation
  defp parse_embedded_field_from_parts(parts) do
    field_names =
      parts
      |> Enum.map(&String.replace(&1, "]", ""))
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(&String.trim/1)

    # Validate all field names
    if Enum.all?(field_names, &valid_field_name?/1) do
      case field_names do
        [single_field] -> {single_field}
        multiple_fields when length(multiple_fields) > 1 -> {multiple_fields}
        _ -> :invalid
      end
    else
      :invalid
    end
  end

  # Parses relationship field notation like "user.name" or "user.company.name"
  defp parse_relationship_field_notation(field) do
    parts = String.split(field, ".")

    case parts do
      # No dots after split means it's direct
      [_single] ->
        {:direct, field}

      parts when length(parts) > 1 ->
        {rel_path, [field_name]} = Enum.split(parts, -1)
        {:relationship, rel_path, field_name}

      _ ->
        {:invalid, field}
    end
  end

  # Validates field names according to Elixir atom naming rules
  defp valid_field_name?(name) do
    String.match?(name, ~r/^[a-z][a-zA-Z0-9_]*$/)
  end

  # Apply operators to embedded fields
  defp apply_operator_to_embedded(query, embed_atom, field_atom, value, operator) do
    require Ash.Query
    import Ash.Expr

    case operator do
      :equals ->
        Ash.Query.filter(query, get_path(^ref(embed_atom), [^field_atom]) == ^value)

      :contains ->
        Ash.Query.filter(query, contains(get_path(^ref(embed_atom), [^field_atom]), ^value))

      :starts_with ->
        Ash.Query.filter(query, contains(get_path(^ref(embed_atom), [^field_atom]), ^value))

      :ends_with ->
        Ash.Query.filter(query, contains(get_path(^ref(embed_atom), [^field_atom]), ^value))

      :greater_than ->
        Ash.Query.filter(query, get_path(^ref(embed_atom), [^field_atom]) > ^value)

      :greater_than_or_equal ->
        Ash.Query.filter(query, get_path(^ref(embed_atom), [^field_atom]) >= ^value)

      :less_than ->
        Ash.Query.filter(query, get_path(^ref(embed_atom), [^field_atom]) < ^value)

      :less_than_or_equal ->
        Ash.Query.filter(query, get_path(^ref(embed_atom), [^field_atom]) <= ^value)

      :in when is_list(value) ->
        Ash.Query.filter(query, get_path(^ref(embed_atom), [^field_atom]) in ^value)

      _ ->
        query
    end
  end

  # Apply operators to nested embedded fields
  defp apply_operator_to_nested_embedded(query, embed_atom, field_path, value, operator) do
    require Ash.Query
    import Ash.Expr

    # Convert field path to atoms for get_path
    field_atoms = Enum.map(field_path, &String.to_atom/1)

    case operator do
      :equals ->
        Ash.Query.filter(query, get_path(^ref(embed_atom), ^field_atoms) == ^value)

      :contains ->
        Ash.Query.filter(query, contains(get_path(^ref(embed_atom), ^field_atoms), ^value))

      :starts_with ->
        Ash.Query.filter(query, contains(get_path(^ref(embed_atom), ^field_atoms), ^value))

      :ends_with ->
        Ash.Query.filter(query, contains(get_path(^ref(embed_atom), ^field_atoms), ^value))

      :greater_than ->
        Ash.Query.filter(query, get_path(^ref(embed_atom), ^field_atoms) > ^value)

      :greater_than_or_equal ->
        Ash.Query.filter(query, get_path(^ref(embed_atom), ^field_atoms) >= ^value)

      :less_than ->
        Ash.Query.filter(query, get_path(^ref(embed_atom), ^field_atoms) < ^value)

      :less_than_or_equal ->
        Ash.Query.filter(query, get_path(^ref(embed_atom), ^field_atoms) <= ^value)

      :in when is_list(value) ->
        Ash.Query.filter(query, get_path(^ref(embed_atom), ^field_atoms) in ^value)

      _ ->
        query
    end
  end

  # Apply operators to relationship + embedded fields
  defp apply_operator_to_relationship_embedded(
         query,
         rel_path,
         embed_atom,
         field_atom,
         value,
         operator
       ) do
    require Ash.Query
    import Ash.Expr

    case operator do
      :equals ->
        Ash.Query.filter(
          query,
          exists(^rel_path, get_path(^ref(embed_atom), [^field_atom]) == ^value)
        )

      :contains ->
        Ash.Query.filter(
          query,
          exists(^rel_path, contains(get_path(^ref(embed_atom), [^field_atom]), ^value))
        )

      :starts_with ->
        Ash.Query.filter(
          query,
          exists(^rel_path, contains(get_path(^ref(embed_atom), [^field_atom]), ^value))
        )

      :ends_with ->
        Ash.Query.filter(
          query,
          exists(^rel_path, contains(get_path(^ref(embed_atom), [^field_atom]), ^value))
        )

      :greater_than ->
        Ash.Query.filter(
          query,
          exists(^rel_path, get_path(^ref(embed_atom), [^field_atom]) > ^value)
        )

      :greater_than_or_equal ->
        Ash.Query.filter(
          query,
          exists(^rel_path, get_path(^ref(embed_atom), [^field_atom]) >= ^value)
        )

      :less_than ->
        Ash.Query.filter(
          query,
          exists(^rel_path, get_path(^ref(embed_atom), [^field_atom]) < ^value)
        )

      :less_than_or_equal ->
        Ash.Query.filter(
          query,
          exists(^rel_path, get_path(^ref(embed_atom), [^field_atom]) <= ^value)
        )

      :in when is_list(value) ->
        Ash.Query.filter(
          query,
          exists(^rel_path, get_path(^ref(embed_atom), [^field_atom]) in ^value)
        )

      _ ->
        query
    end
  end

  # Apply operators to relationship + nested embedded fields
  defp apply_operator_to_relationship_nested_embedded(
         query,
         rel_path,
         embed_atom,
         field_path,
         value,
         operator
       ) do
    require Ash.Query
    import Ash.Expr

    # Convert field path to atoms for get_path
    field_atoms = Enum.map(field_path, &String.to_atom/1)

    case operator do
      :equals ->
        Ash.Query.filter(
          query,
          exists(^rel_path, get_path(^ref(embed_atom), ^field_atoms) == ^value)
        )

      :contains ->
        Ash.Query.filter(
          query,
          exists(^rel_path, contains(get_path(^ref(embed_atom), ^field_atoms), ^value))
        )

      :starts_with ->
        Ash.Query.filter(
          query,
          exists(^rel_path, contains(get_path(^ref(embed_atom), ^field_atoms), ^value))
        )

      :ends_with ->
        Ash.Query.filter(
          query,
          exists(^rel_path, contains(get_path(^ref(embed_atom), ^field_atoms), ^value))
        )

      :greater_than ->
        Ash.Query.filter(
          query,
          exists(^rel_path, get_path(^ref(embed_atom), ^field_atoms) > ^value)
        )

      :greater_than_or_equal ->
        Ash.Query.filter(
          query,
          exists(^rel_path, get_path(^ref(embed_atom), ^field_atoms) >= ^value)
        )

      :less_than ->
        Ash.Query.filter(
          query,
          exists(^rel_path, get_path(^ref(embed_atom), ^field_atoms) < ^value)
        )

      :less_than_or_equal ->
        Ash.Query.filter(
          query,
          exists(^rel_path, get_path(^ref(embed_atom), ^field_atoms) <= ^value)
        )

      :in when is_list(value) ->
        Ash.Query.filter(
          query,
          exists(^rel_path, get_path(^ref(embed_atom), ^field_atoms) in ^value)
        )

      _ ->
        query
    end
  end

  @doc """
  Converts embedded field notation to URL-safe format.

  ## Examples

      iex> url_safe_field_notation("profile[:first_name]")
      "profile__first_name"

      iex> url_safe_field_notation("settings[:address][:street]")
      "settings__address__street"

  """
  def url_safe_field_notation(field) when is_binary(field) do
    # Only convert embedded field parts, leave relationship dots unchanged
    field
    |> String.replace(~r/\[:([a-zA-Z0-9_]+)\]/, "__\\1")
  end

  @doc """
  Converts URL-safe format back to embedded field notation.

  ## Examples

      iex> field_notation_from_url_safe("profile__first_name")
      "profile[:first_name]"

      iex> field_notation_from_url_safe("settings__address__street")
      "settings[:address][:street]"

  """
  def field_notation_from_url_safe(field) when is_binary(field) do
    # Convert double underscores back to bracket notation
    # Handle mixed relationship.embedded__field patterns
    if String.contains?(field, "__") do
      # Split on dots first to handle relationship.embedded__field patterns
      parts = String.split(field, ".")

      converted_parts =
        Enum.map(parts, fn part ->
          if String.contains?(part, "__") do
            # This part contains embedded field notation
            [base | field_parts] = String.split(part, "__")
            embedded_parts = Enum.map(field_parts, fn fp -> "[:#{fp}]" end)
            base <> Enum.join(embedded_parts)
          else
            part
          end
        end)

      Enum.join(converted_parts, ".")
    else
      field
    end
  end

  @doc """
  Converts field notation to human-readable labels.

  ## Examples

      iex> humanize_embedded_field("profile[:first_name]")
      "Profile > First Name"

      iex> humanize_embedded_field("user.profile[:first_name]")
      "User > Profile > First Name"

  """
  def humanize_embedded_field(field) when is_binary(field) do
    case parse_field_notation(field) do
      {:direct, field_name} ->
        Cinder.Filter.humanize_key(field_name)

      {:relationship, rel_path, field_name} ->
        rel_labels = Enum.map(rel_path, &Cinder.Filter.humanize_key/1)
        field_label = Cinder.Filter.humanize_key(field_name)
        Enum.join(rel_labels ++ [field_label], " > ")

      {:embedded, embed_field, field_name} ->
        embed_label = Cinder.Filter.humanize_key(embed_field)
        field_label = Cinder.Filter.humanize_key(field_name)
        "#{embed_label} > #{field_label}"

      {:nested_embedded, embed_field, field_path} ->
        embed_label = Cinder.Filter.humanize_key(embed_field)
        field_labels = Enum.map(field_path, &Cinder.Filter.humanize_key/1)
        Enum.join([embed_label | field_labels], " > ")

      {:relationship_embedded, rel_path, embed_field, field_name} ->
        rel_labels = Enum.map(rel_path, &Cinder.Filter.humanize_key/1)
        embed_label = Cinder.Filter.humanize_key(embed_field)
        field_label = Cinder.Filter.humanize_key(field_name)
        Enum.join(rel_labels ++ [embed_label, field_label], " > ")

      {:relationship_nested_embedded, rel_path, embed_field, field_path} ->
        rel_labels = Enum.map(rel_path, &Cinder.Filter.humanize_key/1)
        embed_label = Cinder.Filter.humanize_key(embed_field)
        field_labels = Enum.map(field_path, &Cinder.Filter.humanize_key/1)
        Enum.join(rel_labels ++ [embed_label | field_labels], " > ")

      {:invalid, _} ->
        Cinder.Filter.humanize_key(field)
    end
  end

  @doc """
  Validates embedded field syntax.

  ## Examples

      iex> validate_embedded_field_syntax("profile[:first_name]")
      :ok

      iex> validate_embedded_field_syntax("profile[invalid]")
      {:error, "Invalid embedded field syntax: missing colon"}

  """
  def validate_embedded_field_syntax(field) when is_binary(field) do
    case parse_field_notation(field) do
      {:invalid, _} ->
        cond do
          String.contains?(field, "[") and not String.contains?(field, "[:") ->
            {:error, "Invalid embedded field syntax: missing colon"}

          String.contains?(field, "[:") and not String.contains?(field, "]") ->
            {:error, "Invalid embedded field syntax: unclosed bracket"}

          String.contains?(field, "[:]") ->
            {:error, "Invalid embedded field syntax: empty field name"}

          String.contains?(field, "[:") and String.contains?(field, "-") ->
            {:error, "Invalid embedded field syntax: invalid field name characters"}

          true ->
            {:error, "Invalid field syntax"}
        end

      _ ->
        :ok
    end
  end
end
