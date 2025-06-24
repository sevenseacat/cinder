defmodule Cinder.EmbeddedFieldSimpleTest do
  use ExUnit.Case, async: true

  describe "embedded field filtering integration" do
    test "parse_field_notation/1 correctly identifies embedded fields" do
      # Test basic embedded field parsing
      assert Cinder.Filter.Helpers.parse_field_notation("profile[:first_name]") ==
               {:embedded, "profile", "first_name"}

      assert Cinder.Filter.Helpers.parse_field_notation("settings[:theme]") ==
               {:embedded, "settings", "theme"}

      # Test nested embedded fields
      assert Cinder.Filter.Helpers.parse_field_notation("settings[:address][:street]") ==
               {:nested_embedded, "settings", ["address", "street"]}

      # Test mixed relationship and embedded
      assert Cinder.Filter.Helpers.parse_field_notation("user.profile[:first_name]") ==
               {:relationship_embedded, ["user"], "profile", "first_name"}
    end

    test "url_safe_field_notation/1 converts embedded fields to URL-safe format" do
      assert Cinder.Filter.Helpers.url_safe_field_notation("profile[:first_name]") ==
               "profile__first_name"

      assert Cinder.Filter.Helpers.url_safe_field_notation("settings[:address][:street]") ==
               "settings__address__street"

      # Regular fields should remain unchanged
      assert Cinder.Filter.Helpers.url_safe_field_notation("username") == "username"
      assert Cinder.Filter.Helpers.url_safe_field_notation("user.name") == "user.name"
    end

    test "field_notation_from_url_safe/1 converts back from URL-safe format" do
      assert Cinder.Filter.Helpers.field_notation_from_url_safe("profile__first_name") ==
               "profile[:first_name]"

      assert Cinder.Filter.Helpers.field_notation_from_url_safe("settings__address__street") ==
               "settings[:address][:street]"

      # Regular fields should remain unchanged
      assert Cinder.Filter.Helpers.field_notation_from_url_safe("username") == "username"
      assert Cinder.Filter.Helpers.field_notation_from_url_safe("user.name") == "user.name"
    end

    test "humanize_embedded_field/1 creates readable labels" do
      assert Cinder.Filter.Helpers.humanize_embedded_field("profile[:first_name]") ==
               "Profile > First Name"

      assert Cinder.Filter.Helpers.humanize_embedded_field("settings[:address][:street]") ==
               "Settings > Address > Street"

      assert Cinder.Filter.Helpers.humanize_embedded_field("user.profile[:first_name]") ==
               "User > Profile > First Name"

      # Regular fields
      assert Cinder.Filter.Helpers.humanize_embedded_field("username") == "Username"
      assert Cinder.Filter.Helpers.humanize_embedded_field("user.name") == "User > Name"
    end

    test "validate_embedded_field_syntax/1 validates field syntax" do
      # Valid syntax
      assert Cinder.Filter.Helpers.validate_embedded_field_syntax("profile[:first_name]") == :ok

      assert Cinder.Filter.Helpers.validate_embedded_field_syntax("settings[:address][:street]") ==
               :ok

      assert Cinder.Filter.Helpers.validate_embedded_field_syntax("username") == :ok
      assert Cinder.Filter.Helpers.validate_embedded_field_syntax("user.name") == :ok

      # Invalid syntax
      assert Cinder.Filter.Helpers.validate_embedded_field_syntax("profile[first_name]") ==
               {:error, "Invalid embedded field syntax: missing colon"}

      assert Cinder.Filter.Helpers.validate_embedded_field_syntax("profile[:first_name") ==
               {:error, "Invalid embedded field syntax: unclosed bracket"}

      assert Cinder.Filter.Helpers.validate_embedded_field_syntax("profile[:]") ==
               {:error, "Invalid embedded field syntax: empty field name"}
    end

    test "field notation parsing handles all expected patterns" do
      # Test that field notation parsing works correctly for all types

      # Direct field
      assert Cinder.Filter.Helpers.parse_field_notation("username") == {:direct, "username"}

      # Relationship field
      assert Cinder.Filter.Helpers.parse_field_notation("user.name") ==
               {:relationship, ["user"], "name"}

      # Embedded field
      assert Cinder.Filter.Helpers.parse_field_notation("profile[:first_name]") ==
               {:embedded, "profile", "first_name"}

      # Nested embedded field
      assert Cinder.Filter.Helpers.parse_field_notation("settings[:address][:street]") ==
               {:nested_embedded, "settings", ["address", "street"]}

      # Mixed relationship and embedded
      assert Cinder.Filter.Helpers.parse_field_notation("user.profile[:first_name]") ==
               {:relationship_embedded, ["user"], "profile", "first_name"}

      # Invalid field syntax
      assert Cinder.Filter.Helpers.parse_field_notation("invalid[syntax") ==
               {:invalid, "invalid[syntax"}
    end

    test "filter modules parse embedded field notation correctly" do
      # Test that filter modules can process embedded field configurations
      # without actually building Ash queries (which require real resources)

      # Test that the field parsing logic works in filter context
      test_fields = [
        "profile[:first_name]",
        "settings[:theme]",
        "settings[:address][:street]",
        "user.profile[:first_name]",
        "company.settings[:address][:city]"
      ]

      for field <- test_fields do
        # Verify each field can be parsed
        parsed = Cinder.Filter.Helpers.parse_field_notation(field)
        assert parsed != {:invalid, field}, "Failed to parse: #{field}"

        # Verify field can be converted to URL-safe format
        url_safe = Cinder.Filter.Helpers.url_safe_field_notation(field)
        assert is_binary(url_safe)

        # Verify round-trip conversion works
        converted_back = Cinder.Filter.Helpers.field_notation_from_url_safe(url_safe)
        assert converted_back == field, "Round-trip failed for: #{field}"
      end
    end

    test "round-trip field notation conversion preserves original format" do
      embedded_fields = [
        "profile[:first_name]",
        "settings[:theme]",
        "settings[:address][:street]",
        "config[:ui][:theme][:colors]",
        "user.profile[:first_name]",
        "company.settings[:address][:city]"
      ]

      for field <- embedded_fields do
        url_safe = Cinder.Filter.Helpers.url_safe_field_notation(field)
        converted_back = Cinder.Filter.Helpers.field_notation_from_url_safe(url_safe)

        assert converted_back == field,
               "Round-trip failed for #{field}: #{url_safe} -> #{converted_back}"
      end

      # Regular fields should remain unchanged throughout the process
      regular_fields = ["username", "email", "user.name", "company.address.city"]

      for field <- regular_fields do
        url_safe = Cinder.Filter.Helpers.url_safe_field_notation(field)
        assert url_safe == field
        converted_back = Cinder.Filter.Helpers.field_notation_from_url_safe(url_safe)
        assert converted_back == field
      end
    end
  end
end

# Mock module for testing
defmodule MockQuery do
  defstruct []
end
