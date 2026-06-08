defmodule Cinder.EmbeddedFieldSimpleTest do
  use ExUnit.Case, async: true

  describe "embedded field filtering integration" do
    @tag capture_log: true
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

    test "parse_field_notation/1 accepts double-underscore (canonical) notation" do
      assert Cinder.Filter.Helpers.parse_field_notation("profile__first_name") ==
               {:embedded, "profile", "first_name"}

      assert Cinder.Filter.Helpers.parse_field_notation("settings__address__street") ==
               {:nested_embedded, "settings", ["address", "street"]}

      assert Cinder.Filter.Helpers.parse_field_notation("user.profile__first_name") ==
               {:relationship_embedded, ["user"], "profile", "first_name"}
    end

    @tag capture_log: true
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

    @tag capture_log: true
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

    @tag capture_log: true
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
      # Verify embedded field configs (double-underscore notation) parse to a usable shape
      # in filter context, without building Ash queries (which require real resources).
      test_fields = [
        "profile__first_name",
        "settings__theme",
        "settings__address__street",
        "user.profile__first_name",
        "company.settings__address__city"
      ]

      for field <- test_fields do
        parsed = Cinder.Filter.Helpers.parse_field_notation(field)
        assert parsed != {:invalid, field}, "Failed to parse: #{field}"
      end
    end
  end
end

# Mock module for testing
defmodule MockQuery do
  defstruct []
end
