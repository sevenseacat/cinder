defmodule Cinder.Filter.FieldParsingTest do
  use ExUnit.Case, async: true

  describe "parse_field_notation/1" do
    test "parses direct field references" do
      assert Cinder.Filter.Helpers.parse_field_notation("username") ==
               {:direct, "username"}

      assert Cinder.Filter.Helpers.parse_field_notation("email") ==
               {:direct, "email"}

      assert Cinder.Filter.Helpers.parse_field_notation("created_at") ==
               {:direct, "created_at"}
    end

    test "parses relationship field references with dot notation" do
      assert Cinder.Filter.Helpers.parse_field_notation("user.name") ==
               {:relationship, ["user"], "name"}

      assert Cinder.Filter.Helpers.parse_field_notation("user.profile.email") ==
               {:relationship, ["user", "profile"], "email"}

      assert Cinder.Filter.Helpers.parse_field_notation("company.address.city") ==
               {:relationship, ["company", "address"], "city"}
    end

    test "parses basic embedded field references with bracket notation" do
      assert Cinder.Filter.Helpers.parse_field_notation("profile[:first_name]") ==
               {:embedded, "profile", "first_name"}

      assert Cinder.Filter.Helpers.parse_field_notation("settings[:theme]") ==
               {:embedded, "settings", "theme"}

      assert Cinder.Filter.Helpers.parse_field_notation("metadata[:version]") ==
               {:embedded, "metadata", "version"}
    end

    test "parses nested embedded field references" do
      assert Cinder.Filter.Helpers.parse_field_notation("settings[:address][:street]") ==
               {:nested_embedded, "settings", ["address", "street"]}

      assert Cinder.Filter.Helpers.parse_field_notation("config[:ui][:theme][:colors]") ==
               {:nested_embedded, "config", ["ui", "theme", "colors"]}

      assert Cinder.Filter.Helpers.parse_field_notation("data[:meta][:info]") ==
               {:nested_embedded, "data", ["meta", "info"]}
    end

    test "parses mixed relationship and embedded field references" do
      assert Cinder.Filter.Helpers.parse_field_notation("user.profile[:first_name]") ==
               {:relationship_embedded, ["user"], "profile", "first_name"}

      assert Cinder.Filter.Helpers.parse_field_notation("company.metadata[:founded_year]") ==
               {:relationship_embedded, ["company"], "metadata", "founded_year"}

      assert Cinder.Filter.Helpers.parse_field_notation("order.customer.address[:street]") ==
               {:relationship_embedded, ["order", "customer"], "address", "street"}
    end

    test "handles edge cases and invalid syntax" do
      # Empty field
      assert Cinder.Filter.Helpers.parse_field_notation("") ==
               {:invalid, ""}

      # Malformed bracket notation (missing colon)
      assert Cinder.Filter.Helpers.parse_field_notation("profile[first_name]") ==
               {:invalid, "profile[first_name]"}

      # Unclosed brackets
      assert Cinder.Filter.Helpers.parse_field_notation("profile[:first_name") ==
               {:invalid, "profile[:first_name"}

      # Empty brackets
      assert Cinder.Filter.Helpers.parse_field_notation("profile[:]") ==
               {:invalid, "profile[:]"}

      # Missing field name in brackets
      assert Cinder.Filter.Helpers.parse_field_notation("profile[]") ==
               {:invalid, "profile[]"}

      # Invalid characters
      assert Cinder.Filter.Helpers.parse_field_notation("profile[:first-name]") ==
               {:invalid, "profile[:first-name]"}
    end

    test "handles complex nested scenarios" do
      # Deep relationship with embedded field
      assert Cinder.Filter.Helpers.parse_field_notation("user.company.settings[:address][:city]") ==
               {:relationship_nested_embedded, ["user", "company"], "settings",
                ["address", "city"]}

      # Multiple levels of nesting
      assert Cinder.Filter.Helpers.parse_field_notation("org.dept.user.profile[:contact][:phone]") ==
               {:relationship_nested_embedded, ["org", "dept", "user"], "profile",
                ["contact", "phone"]}
    end

    test "validates field name patterns" do
      # Valid field names with underscores
      assert Cinder.Filter.Helpers.parse_field_notation("profile[:first_name]") ==
               {:embedded, "profile", "first_name"}

      assert Cinder.Filter.Helpers.parse_field_notation("settings[:notification_enabled]") ==
               {:embedded, "settings", "notification_enabled"}

      # Valid field names with numbers
      assert Cinder.Filter.Helpers.parse_field_notation("data[:field_1]") ==
               {:embedded, "data", "field_1"}

      # Field names starting with numbers should be invalid
      assert Cinder.Filter.Helpers.parse_field_notation("data[:1_field]") ==
               {:invalid, "data[:1_field]"}
    end

    test "handles whitespace and formatting" do
      # Should trim whitespace
      assert Cinder.Filter.Helpers.parse_field_notation(" profile[:first_name] ") ==
               {:embedded, "profile", "first_name"}

      # Should not accept spaces within field references
      assert Cinder.Filter.Helpers.parse_field_notation("profile[:first name]") ==
               {:invalid, "profile[:first name]"}

      # Should not accept spaces in relationship notation
      assert Cinder.Filter.Helpers.parse_field_notation("user .name") ==
               {:invalid, "user .name"}
    end
  end

  describe "url_safe_field_notation/1" do
    test "converts embedded field notation to URL-safe format" do
      assert Cinder.Filter.Helpers.url_safe_field_notation("profile[:first_name]") ==
               "profile__first_name"

      assert Cinder.Filter.Helpers.url_safe_field_notation("settings[:theme]") ==
               "settings__theme"
    end

    test "converts nested embedded field notation to URL-safe format" do
      assert Cinder.Filter.Helpers.url_safe_field_notation("settings[:address][:street]") ==
               "settings__address__street"

      assert Cinder.Filter.Helpers.url_safe_field_notation("config[:ui][:theme][:colors]") ==
               "config__ui__theme__colors"
    end

    test "leaves relationship notation unchanged for URL safety" do
      assert Cinder.Filter.Helpers.url_safe_field_notation("user.profile.name") ==
               "user.profile.name"

      assert Cinder.Filter.Helpers.url_safe_field_notation("company.address.city") ==
               "company.address.city"
    end

    test "leaves direct fields unchanged" do
      assert Cinder.Filter.Helpers.url_safe_field_notation("username") ==
               "username"

      assert Cinder.Filter.Helpers.url_safe_field_notation("email") ==
               "email"
    end
  end

  describe "field_notation_from_url_safe/1" do
    test "converts URL-safe format back to embedded field notation" do
      assert Cinder.Filter.Helpers.field_notation_from_url_safe("profile__first_name") ==
               "profile[:first_name]"

      assert Cinder.Filter.Helpers.field_notation_from_url_safe("settings__theme") ==
               "settings[:theme]"
    end

    test "converts nested URL-safe format back to embedded field notation" do
      assert Cinder.Filter.Helpers.field_notation_from_url_safe("settings__address__street") ==
               "settings[:address][:street]"

      assert Cinder.Filter.Helpers.field_notation_from_url_safe("config__ui__theme__colors") ==
               "config[:ui][:theme][:colors]"
    end

    test "leaves relationship and direct field notation unchanged" do
      assert Cinder.Filter.Helpers.field_notation_from_url_safe("user.profile.name") ==
               "user.profile.name"

      assert Cinder.Filter.Helpers.field_notation_from_url_safe("username") ==
               "username"
    end
  end

  describe "humanize_embedded_field/1" do
    test "converts embedded field notation to human-readable labels" do
      assert Cinder.Filter.Helpers.humanize_embedded_field("profile[:first_name]") ==
               "Profile > First Name"

      assert Cinder.Filter.Helpers.humanize_embedded_field("settings[:notifications_enabled]") ==
               "Settings > Notifications Enabled"
    end

    test "converts nested embedded field notation to human-readable labels" do
      assert Cinder.Filter.Helpers.humanize_embedded_field("settings[:address][:street]") ==
               "Settings > Address > Street"

      assert Cinder.Filter.Helpers.humanize_embedded_field("config[:ui][:theme][:colors]") ==
               "Config > Ui > Theme > Colors"
    end

    test "handles mixed relationship and embedded field notation" do
      assert Cinder.Filter.Helpers.humanize_embedded_field("user.profile[:first_name]") ==
               "User > Profile > First Name"

      assert Cinder.Filter.Helpers.humanize_embedded_field("company.settings[:address][:city]") ==
               "Company > Settings > Address > City"
    end

    test "handles regular relationship fields for consistency" do
      assert Cinder.Filter.Helpers.humanize_embedded_field("user.profile.name") ==
               "User > Profile > Name"

      assert Cinder.Filter.Helpers.humanize_embedded_field("company.address.city") ==
               "Company > Address > City"
    end

    test "handles direct fields" do
      assert Cinder.Filter.Helpers.humanize_embedded_field("username") ==
               "Username"

      assert Cinder.Filter.Helpers.humanize_embedded_field("created_at") ==
               "Created At"
    end
  end

  describe "validate_embedded_field_syntax/1" do
    test "validates correct embedded field syntax" do
      assert Cinder.Filter.Helpers.validate_embedded_field_syntax("profile[:first_name]") == :ok
      assert Cinder.Filter.Helpers.validate_embedded_field_syntax("settings[:theme]") == :ok
      assert Cinder.Filter.Helpers.validate_embedded_field_syntax("data[:version]") == :ok
    end

    test "validates correct nested embedded field syntax" do
      assert Cinder.Filter.Helpers.validate_embedded_field_syntax("settings[:address][:street]") ==
               :ok

      assert Cinder.Filter.Helpers.validate_embedded_field_syntax("config[:ui][:theme]") == :ok
    end

    test "validates mixed relationship and embedded syntax" do
      assert Cinder.Filter.Helpers.validate_embedded_field_syntax("user.profile[:first_name]") ==
               :ok

      assert Cinder.Filter.Helpers.validate_embedded_field_syntax("company.metadata[:version]") ==
               :ok
    end

    test "validates regular field syntax" do
      assert Cinder.Filter.Helpers.validate_embedded_field_syntax("username") == :ok
      assert Cinder.Filter.Helpers.validate_embedded_field_syntax("user.name") == :ok
    end

    test "rejects invalid embedded field syntax" do
      assert Cinder.Filter.Helpers.validate_embedded_field_syntax("profile[first_name]") ==
               {:error, "Invalid embedded field syntax: missing colon"}

      assert Cinder.Filter.Helpers.validate_embedded_field_syntax("profile[:first_name") ==
               {:error, "Invalid embedded field syntax: unclosed bracket"}

      assert Cinder.Filter.Helpers.validate_embedded_field_syntax("profile[:]") ==
               {:error, "Invalid embedded field syntax: empty field name"}

      assert Cinder.Filter.Helpers.validate_embedded_field_syntax("profile[:first-name]") ==
               {:error, "Invalid embedded field syntax: invalid field name characters"}
    end
  end
end
