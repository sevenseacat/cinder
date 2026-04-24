defmodule Cinder.AshOptionsTest do
  use ExUnit.Case, async: true

  alias Cinder.AshOptions

  defmodule TestScope do
    defstruct [:current_user, :current_tenant, :tz]

    defimpl Ash.Scope.ToOpts do
      def get_actor(%{current_user: current_user}), do: {:ok, current_user}
      def get_tenant(%{current_tenant: current_tenant}), do: {:ok, current_tenant}
      def get_context(%{tz: tz}) when not is_nil(tz), do: {:ok, %{shared: %{tz: tz}}}
      def get_context(_), do: :error
      def get_tracer(_), do: :error
      def get_authorize?(_), do: :error
    end
  end

  describe "resolve/3" do
    test "returns explicit actor/tenant untouched when no scope is given" do
      assert {:alice, "t1", []} = AshOptions.resolve(:alice, "t1", nil)
    end

    test "extracts actor and tenant from scope when not passed explicitly" do
      scope = %TestScope{current_user: :alice, current_tenant: "t1"}
      assert {:alice, "t1", scope_opts} = AshOptions.resolve(nil, nil, scope)
      assert scope_opts[:actor] == :alice
      assert scope_opts[:tenant] == "t1"
    end

    test "explicit actor and tenant override scope values" do
      scope = %TestScope{current_user: :from_scope, current_tenant: "from_scope"}

      assert {:explicit, "explicit", _} =
               AshOptions.resolve(:explicit, "explicit", scope)
    end

    test "falls back to scope when only one of actor/tenant is explicit" do
      scope = %TestScope{current_user: :from_scope, current_tenant: "from_scope"}

      assert {:explicit_actor, "from_scope", _} =
               AshOptions.resolve(:explicit_actor, nil, scope)

      assert {:from_scope, "explicit_tenant", _} =
               AshOptions.resolve(nil, "explicit_tenant", scope)
    end

    test "preserves non-actor/tenant scope options like context" do
      scope = %TestScope{current_user: :alice, current_tenant: "t1", tz: "America/New_York"}
      assert {_, _, scope_opts} = AshOptions.resolve(nil, nil, scope)
      assert scope_opts[:context] == %{shared: %{tz: "America/New_York"}}
    end

    test "tolerates an invalid scope by returning empty scope_opts" do
      assert {nil, nil, []} = AshOptions.resolve(nil, nil, %{not: "a scope"})
    end

    test "nil scope returns empty scope_opts" do
      assert {nil, nil, []} = AshOptions.resolve(nil, nil, nil)
    end
  end
end
