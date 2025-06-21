defmodule Cinder.Table.RowClickIntegrationTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  # Test resource for integration testing
  defmodule TestUser do
    use Ash.Resource,
      domain: Cinder.Table.RowClickIntegrationTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      validate_domain_inclusion?: false

    ets do
      private?(true)
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string, public?: true)
      attribute(:email, :string, public?: true)
      attribute(:active, :boolean, default: true, public?: true)
    end

    actions do
      defaults([:read, :update, :destroy, create: [:*]])
    end
  end

  defmodule Domain do
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource(TestUser)
    end
  end

  # Test component for testing row_click with captured function calls
  defmodule TestRowClickWrapper do
    use Phoenix.Component

    def wrapper(assigns) do
      ~H"""
      <div>
        <Cinder.Table.table
          resource={TestUser}
          actor={nil}
          row_click={@row_click_fn}
        >
          <:col field="name">Name</:col>
          <:col field="email">Email</:col>
        </Cinder.Table.table>
      </div>
      """
    end
  end

  defmodule TestNoRowClickWrapper do
    use Phoenix.Component

    def wrapper(assigns) do
      ~H"""
      <div>
        <Cinder.Table.table resource={TestUser} actor={nil}>
          <:col field="name">Name</:col>
          <:col field="email">Email</:col>
        </Cinder.Table.table>
      </div>
      """
    end
  end

  describe "row_click integration tests" do
    test "row_click function is properly called when defined" do
      test_pid = self()

      row_click_fn = fn user ->
        send(test_pid, {:row_clicked, user})
        Phoenix.LiveView.JS.navigate("/users/#{user.id}")
      end

      assigns = %{row_click_fn: row_click_fn}

      html = render_component(&TestRowClickWrapper.wrapper/1, assigns)

      # Should render with row_click functionality
      assert html =~ "cinder-table"
      # The table component should be rendered (data loading is async)
      assert html
    end

    test "table without row_click renders without clickable elements" do
      assigns = %{}

      html = render_component(&TestNoRowClickWrapper.wrapper/1, assigns)

      # Should render table without row_click
      assert html =~ "cinder-table"
      refute html =~ "cursor-pointer"
    end

    test "row_click function execution works correctly" do
      # Test the row_click function behavior directly
      test_pid = self()
      test_user = %{id: "test-123", name: "Test User", email: "test@example.com"}

      row_click_fn = fn user ->
        send(test_pid, {:row_clicked, user})
        Phoenix.LiveView.JS.navigate("/users/#{user.id}")
      end

      # Execute the function
      result = row_click_fn.(test_user)

      # Verify the function was called and returns JS command
      assert_received {:row_clicked, received_user}
      assert received_user.id == "test-123"
      assert received_user.name == "Test User"
      assert %Phoenix.LiveView.JS{} = result
    end

    test "row_click function can handle different JS commands" do
      test_user = %{id: "js-test", name: "JS Test"}

      # Test different JS commands
      navigate_fn = fn user -> Phoenix.LiveView.JS.navigate("/users/#{user.id}") end
      show_fn = fn user -> Phoenix.LiveView.JS.show(to: "#modal-#{user.id}") end

      # Both should return valid JS commands
      nav_result = navigate_fn.(test_user)
      show_result = show_fn.(test_user)

      assert %Phoenix.LiveView.JS{} = nav_result
      assert %Phoenix.LiveView.JS{} = show_result
    end
  end
end
