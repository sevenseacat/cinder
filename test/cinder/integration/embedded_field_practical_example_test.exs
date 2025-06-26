defmodule Cinder.EmbeddedFieldPracticalExampleTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Practical examples demonstrating embedded field filtering functionality.

  This test demonstrates the key features without requiring full Ash resource setup.
  """

  describe "embedded field filtering practical examples" do
    test "demonstrates field notation parsing for common use cases" do
      # User profile embedded fields
      assert Cinder.Filter.Helpers.parse_field_notation("profile[:first_name]") ==
               {:embedded, "profile", "first_name"}

      assert Cinder.Filter.Helpers.parse_field_notation("profile[:last_name]") ==
               {:embedded, "profile", "last_name"}

      assert Cinder.Filter.Helpers.parse_field_notation("profile[:age]") ==
               {:embedded, "profile", "age"}

      # User settings with nested address
      assert Cinder.Filter.Helpers.parse_field_notation("settings[:theme]") ==
               {:embedded, "settings", "theme"}

      assert Cinder.Filter.Helpers.parse_field_notation("settings[:address][:street]") ==
               {:nested_embedded, "settings", ["address", "street"]}

      assert Cinder.Filter.Helpers.parse_field_notation("settings[:address][:city]") ==
               {:nested_embedded, "settings", ["address", "city"]}

      # Company metadata examples
      assert Cinder.Filter.Helpers.parse_field_notation("metadata[:industry]") ==
               {:embedded, "metadata", "industry"}

      assert Cinder.Filter.Helpers.parse_field_notation("metadata[:founded_year]") ==
               {:embedded, "metadata", "founded_year"}

      # Mixed relationship and embedded (user belongs to company with embedded metadata)
      assert Cinder.Filter.Helpers.parse_field_notation("company.metadata[:industry]") ==
               {:relationship_embedded, ["company"], "metadata", "industry"}

      assert Cinder.Filter.Helpers.parse_field_notation("user.profile[:first_name]") ==
               {:relationship_embedded, ["user"], "profile", "first_name"}
    end

    test "demonstrates URL-safe conversion for form handling" do
      # Basic embedded fields
      assert Cinder.Filter.Helpers.url_safe_field_notation("profile[:first_name]") ==
               "profile__first_name"

      assert Cinder.Filter.Helpers.url_safe_field_notation("settings[:theme]") ==
               "settings__theme"

      # Nested embedded fields
      assert Cinder.Filter.Helpers.url_safe_field_notation("settings[:address][:street]") ==
               "settings__address__street"

      assert Cinder.Filter.Helpers.url_safe_field_notation("metadata[:config][:api_key]") ==
               "metadata__config__api_key"

      # Mixed relationship and embedded (relationship dots preserved)
      assert Cinder.Filter.Helpers.url_safe_field_notation("company.metadata[:industry]") ==
               "company.metadata__industry"

      assert Cinder.Filter.Helpers.url_safe_field_notation("user.settings[:address][:city]") ==
               "user.settings__address__city"

      # Regular fields remain unchanged
      assert Cinder.Filter.Helpers.url_safe_field_notation("username") == "username"
      assert Cinder.Filter.Helpers.url_safe_field_notation("user.name") == "user.name"
    end

    test "demonstrates round-trip URL conversion for form processing" do
      test_cases = [
        # Basic embedded fields
        "profile[:first_name]",
        "profile[:last_name]",
        "profile[:age]",
        "settings[:theme]",
        "metadata[:version]",

        # Nested embedded fields
        "settings[:address][:street]",
        "settings[:address][:city]",
        "settings[:address][:zip_code]",
        "config[:ui][:theme][:primary_color]",

        # Mixed relationship and embedded
        "user.profile[:first_name]",
        "company.metadata[:industry]",
        "order.customer.address[:street]",

        # Regular fields (should pass through unchanged)
        "username",
        "email",
        "user.name",
        "company.name",
        "order.customer.email"
      ]

      for field <- test_cases do
        # Convert to URL-safe format
        url_safe = Cinder.Filter.Helpers.url_safe_field_notation(field)

        # Convert back to original format
        converted_back = Cinder.Filter.Helpers.field_notation_from_url_safe(url_safe)

        # Should be identical to original
        assert converted_back == field,
               "Round-trip conversion failed for '#{field}': '#{url_safe}' -> '#{converted_back}'"
      end
    end

    test "demonstrates human-readable labels for UI display" do
      # Basic embedded fields
      assert Cinder.Filter.Helpers.humanize_embedded_field("profile[:first_name]") ==
               "Profile > First Name"

      assert Cinder.Filter.Helpers.humanize_embedded_field("settings[:notifications_enabled]") ==
               "Settings > Notifications Enabled"

      # Nested embedded fields
      assert Cinder.Filter.Helpers.humanize_embedded_field("settings[:address][:street]") ==
               "Settings > Address > Street"

      assert Cinder.Filter.Helpers.humanize_embedded_field("config[:ui][:theme][:primary_color]") ==
               "Config > Ui > Theme > Primary Color"

      # Mixed relationship and embedded
      assert Cinder.Filter.Helpers.humanize_embedded_field("user.profile[:first_name]") ==
               "User > Profile > First Name"

      assert Cinder.Filter.Helpers.humanize_embedded_field("company.metadata[:founded_year]") ==
               "Company > Metadata > Founded Year"

      # Regular fields
      assert Cinder.Filter.Helpers.humanize_embedded_field("username") == "Username"
      assert Cinder.Filter.Helpers.humanize_embedded_field("user.email") == "User > Email"
    end

    test "demonstrates comprehensive syntax validation" do
      # Valid embedded field syntax
      valid_fields = [
        "profile[:first_name]",
        "settings[:theme]",
        "settings[:address][:street]",
        "config[:ui][:theme][:colors]",
        "user.profile[:first_name]",
        "company.settings[:address][:city]"
      ]

      for field <- valid_fields do
        assert Cinder.Filter.Helpers.validate_embedded_field_syntax(field) == :ok,
               "Expected '#{field}' to be valid"
      end

      # Invalid embedded field syntax with specific error messages
      invalid_cases = [
        {"profile[first_name]", "Invalid embedded field syntax: missing colon"},
        {"profile[:first_name", "Invalid embedded field syntax: unclosed bracket"},
        {"profile[:]", "Invalid embedded field syntax: empty field name"},
        {"profile[:first-name]", "Invalid embedded field syntax: invalid field name characters"}
      ]

      for {field, expected_error} <- invalid_cases do
        assert Cinder.Filter.Helpers.validate_embedded_field_syntax(field) ==
                 {:error, expected_error},
               "Expected '#{field}' to return error: #{expected_error}"
      end

      # Regular fields should always be valid
      regular_fields = ["username", "email", "user.name", "company.address.city"]

      for field <- regular_fields do
        assert Cinder.Filter.Helpers.validate_embedded_field_syntax(field) == :ok,
               "Expected regular field '#{field}' to be valid"
      end
    end

    test "demonstrates filter processing compatibility" do
      # Simulate filter parameter processing for different filter types

      # Text filter with embedded field
      text_params = %{"profile[:first_name]" => "Alice"}

      text_columns = [
        %{
          field: "profile[:first_name]",
          filterable: true,
          filter_type: :text,
          filter_options: []
        }
      ]

      text_filters = Cinder.FilterManager.params_to_filters(text_params, text_columns)
      assert Map.has_key?(text_filters, "profile[:first_name]")
      text_filter = text_filters["profile[:first_name]"]
      assert text_filter.type == :text
      assert text_filter.value == "Alice"
      assert text_filter.operator == :contains

      # Select filter with nested embedded field
      select_params = %{"settings[:address][:state]" => "CA"}

      select_columns = [
        %{
          field: "settings[:address][:state]",
          filterable: true,
          filter_type: :select,
          filter_options: [options: [{"CA", "CA"}, {"NY", "NY"}]]
        }
      ]

      select_filters = Cinder.FilterManager.params_to_filters(select_params, select_columns)
      assert Map.has_key?(select_filters, "settings[:address][:state]")
      select_filter = select_filters["settings[:address][:state]"]
      assert select_filter.type == :select
      assert select_filter.value == "CA"
      assert select_filter.operator == :equals

      # Number range filter with embedded field
      range_params = %{
        "profile[:age]_from" => "25",
        "profile[:age]_to" => "65"
      }

      range_columns = [
        %{
          field: "profile[:age]",
          filterable: true,
          filter_type: :number_range,
          filter_options: []
        }
      ]

      range_filters = Cinder.FilterManager.params_to_filters(range_params, range_columns)
      assert Map.has_key?(range_filters, "profile[:age]")
      range_filter = range_filters["profile[:age]"]
      assert range_filter.type == :number_range
      assert range_filter.value == %{min: "25", max: "65"}
      assert range_filter.operator == :between
    end

    test "demonstrates form field name generation for embedded fields" do
      # Test that form field names are generated correctly for embedded fields

      # Basic embedded field
      assert Cinder.Filter.field_name("profile[:first_name]") == "filters[profile[:first_name]]"

      # Nested embedded field
      assert Cinder.Filter.field_name("settings[:address][:street]") ==
               "filters[settings[:address][:street]]"

      # Range filter suffixes
      assert Cinder.Filter.field_name("profile[:age]", "from") == "filters[profile[:age]_from]"
      assert Cinder.Filter.field_name("profile[:age]", "to") == "filters[profile[:age]_to]"

      # Mixed relationship and embedded
      assert Cinder.Filter.field_name("user.profile[:first_name]") ==
               "filters[user.profile[:first_name]]"
    end

    test "demonstrates error handling for malformed embedded field syntax" do
      malformed_fields = [
        # Missing colon
        "profile[invalid]",
        # Unclosed bracket
        "profile[:unclosed",
        # Empty field name
        "profile[:]",
        # Field name starting with number
        "profile[:123invalid]",
        # Invalid characters (hyphen)
        "profile[:first-name]",
        # Spaces in field name
        "profile[:first name]",
        # Empty string
        "",
        # Incomplete bracket
        "profile[",
        # Invalid structure
        "]invalid[:"
      ]

      for field <- malformed_fields do
        # Should be parsed as invalid
        parsed = Cinder.Filter.Helpers.parse_field_notation(field)

        assert match?({:invalid, _}, parsed),
               "Expected '#{field}' to be parsed as invalid, got: #{inspect(parsed)}"

        # Should fail validation with error message
        validation = Cinder.Filter.Helpers.validate_embedded_field_syntax(field)

        assert match?({:error, _}, validation),
               "Expected '#{field}' to fail validation, got: #{inspect(validation)}"
      end
    end

    test "demonstrates practical usage patterns for common scenarios" do
      # E-commerce user profile filtering
      user_profile_fields = [
        # User's first name
        "profile[:first_name]",
        # User's last name
        "profile[:last_name]",
        # User's age
        "profile[:age]",
        # Profile email (might differ from login email)
        "profile[:email]",
        # Newsletter subscription preference
        "settings[:newsletter]",
        # UI theme preference
        "settings[:theme]",
        # Language preference
        "settings[:language]"
      ]

      # Multi-level configuration filtering
      config_fields = [
        # API timeout setting
        "config[:api][:timeout]",
        # Theme color configuration
        "config[:ui][:theme][:colors]",
        # Cache time-to-live
        "config[:cache][:ttl]",
        # SMTP server configuration
        "config[:email][:smtp][:host]"
      ]

      # Mixed relationship and embedded filtering (company employees)
      mixed_fields = [
        # Employee department
        "user.profile[:department]",
        # Work schedule preference
        "user.settings[:work_schedule]",
        # Company industry
        "company.metadata[:industry]",
        # Company office city
        "company.settings[:address][:city]"
      ]

      all_test_fields = user_profile_fields ++ config_fields ++ mixed_fields

      for field <- all_test_fields do
        # Should parse successfully
        parsed = Cinder.Filter.Helpers.parse_field_notation(field)
        refute match?({:invalid, _}, parsed), "Failed to parse: #{field}"

        # Should validate successfully
        assert Cinder.Filter.Helpers.validate_embedded_field_syntax(field) == :ok,
               "Failed to validate: #{field}"

        # Should have readable label
        label = Cinder.Filter.Helpers.humanize_embedded_field(field)

        assert is_binary(label) and String.length(label) > 0,
               "Failed to generate label for: #{field}"

        # Should convert to URL-safe format and back
        url_safe = Cinder.Filter.Helpers.url_safe_field_notation(field)
        converted_back = Cinder.Filter.Helpers.field_notation_from_url_safe(url_safe)

        assert converted_back == field,
               "Round-trip failed for: #{field}"
      end
    end
  end
end
