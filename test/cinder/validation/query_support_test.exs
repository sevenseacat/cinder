defmodule Cinder.QuerySupportTest do
  @moduledoc """
  Tests for query parameter support in Cinder tables.

  This module tests the ability to pass either a resource or a pre-configured
  Ash query to the table component, enabling advanced use cases like custom
  read actions, base filters, and authorization settings.
  """

  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  # Test resource definitions
  defmodule TestUser do
    @moduledoc false
    use Ash.Resource,
      domain: nil,
      validate_domain_inclusion?: false

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string, public?: true)
      attribute(:email, :string, public?: true)
      attribute(:age, :integer, public?: true)
      attribute(:active, :boolean, public?: true, default: true)
      attribute(:inserted_at, :utc_datetime_usec, public?: true)
      attribute(:updated_at, :utc_datetime_usec, public?: true)
    end

    actions do
      defaults([:read, :create, :update, :destroy])

      read :active_users do
        filter(expr(active == true))
      end

      read :admin_read do
        description("Special read action for admins")
      end
    end
  end

  defmodule TestAlbum do
    @moduledoc false
    use Ash.Resource,
      domain: nil,
      validate_domain_inclusion?: false

    attributes do
      uuid_primary_key(:id)
      attribute(:title, :string, public?: true)
      attribute(:release_date, :date, public?: true)
      attribute(:genre, :string, public?: true)
    end

    relationships do
      belongs_to(:artist, TestUser, public?: true)
    end

    actions do
      defaults([:read, :create, :update, :destroy])
    end
  end

  describe "query parameter validation" do
    test "accepts query parameter with resource module" do
      assigns = %{
        query: TestUser,
        actor: nil,
        col: [%{field: "name", __slot__: :col}]
      }

      html = render_component(&Cinder.collection/1, assigns)
      assert html =~ "cinder-table"
    end

    test "accepts query parameter with Ash.Query struct" do
      query = Ash.Query.new(TestUser)

      assigns = %{
        query: query,
        actor: nil,
        col: [%{field: "name", __slot__: :col}]
      }

      html = render_component(&Cinder.collection/1, assigns)
      assert html =~ "cinder-table"
    end

    test "raises error when neither resource nor query is provided" do
      assigns = %{
        actor: nil,
        col: [%{field: "name", __slot__: :col}]
      }

      assert_raise ArgumentError,
                   "Either :resource or :query must be provided",
                   fn -> render_component(&Cinder.collection/1, assigns) end
    end

    test "logs warning when both resource and query are provided" do
      import ExUnit.CaptureLog

      assigns = %{
        resource: TestUser,
        query: TestUser,
        actor: nil,
        col: [%{field: "name", __slot__: :col}]
      }

      # Collection now warns instead of raising, and uses the query
      log =
        capture_log(fn ->
          html = render_component(&Cinder.collection/1, assigns)
          assert html =~ "cinder-table"
        end)

      assert log =~ "Both :resource and :query provided"
    end

    test "raises error when resource is explicitly nil but query is not provided" do
      assigns = %{
        resource: nil,
        actor: nil,
        col: [%{field: "name", __slot__: :col}]
      }

      assert_raise ArgumentError,
                   "Either :resource or :query must be provided",
                   fn -> render_component(&Cinder.collection/1, assigns) end
    end
  end

  describe "column inference with queries" do
    test "infers column types from query resource" do
      query = Ash.Query.new(TestUser)

      assigns = %{
        query: query,
        actor: nil,
        col: [
          %{field: "name", filter: true, __slot__: :col},
          %{field: "age", filter: true, __slot__: :col},
          %{field: "active", filter: true, __slot__: :col}
        ]
      }

      html = render_component(&Cinder.collection/1, assigns)

      # Should have inferred filter types from the resource
      assert html =~ "cinder-table"
      assert html =~ "name=\"filters[name]\""
      assert html =~ "name=\"filters[age_min]\""
      assert html =~ "name=\"filters[active]\""
    end
  end

  describe "URL sync integration with queries" do
    test "works with URL sync when using query parameter" do
      query = Ash.Query.new(TestUser)

      assigns = %{
        query: query,
        actor: nil,
        url_state: %{
          filters: %{"name" => "john"},
          current_page: 1,
          sort_by: []
        },
        col: [
          %{field: "name", filter: true, __slot__: :col}
        ]
      }

      html = render_component(&Cinder.collection/1, assigns)
      assert html =~ "cinder-table"

      # Should integrate with URL sync
      assert html =~ "name=\"filters[name]\""
    end
  end
end
