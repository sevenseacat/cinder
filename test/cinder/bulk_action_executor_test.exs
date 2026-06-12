defmodule Cinder.BulkActionExecutorTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Cinder.BulkActionExecutor
  alias Cinder.Support.SearchTestResource

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

  setup do
    # Create some test records
    {:ok, record1} = Ash.create(SearchTestResource, %{title: "Record 1", status: "active"})
    {:ok, record2} = Ash.create(SearchTestResource, %{title: "Record 2", status: "active"})
    {:ok, record3} = Ash.create(SearchTestResource, %{title: "Record 3", status: "active"})

    %{
      record1: record1,
      record2: record2,
      record3: record3,
      ids: [record1.id, record2.id]
    }
  end

  describe "build_query/3" do
    test "builds a query filtered by id", %{ids: ids} do
      query = BulkActionExecutor.build_query(SearchTestResource, ids)

      assert %Ash.Query{} = query
      assert query.resource == SearchTestResource
    end

    test "supports custom id_field", %{ids: ids} do
      query = BulkActionExecutor.build_query(SearchTestResource, ids, :id)

      assert %Ash.Query{} = query
    end
  end

  describe "execute/2 with atom action" do
    test "executes bulk update action", %{ids: ids, record3: record3} do
      result =
        BulkActionExecutor.execute(:archive,
          resource: SearchTestResource,
          ids: ids
        )

      assert {:ok, %Ash.BulkResult{status: :success}} = result

      # Verify the records were updated
      {:ok, records} = Ash.read(SearchTestResource)
      archived = Enum.filter(records, &(&1.status == "archived"))
      assert length(archived) == 2

      # Record 3 should not be affected
      {:ok, unchanged} = Ash.get(SearchTestResource, record3.id)
      assert unchanged.status == "active"
    end

    test "executes destroy action", %{ids: ids, record3: record3} do
      result =
        BulkActionExecutor.execute(:destroy,
          resource: SearchTestResource,
          ids: ids
        )

      assert {:ok, %Ash.BulkResult{status: :success}} = result

      # Verify the records were destroyed
      {:ok, records} = Ash.read(SearchTestResource)
      assert length(records) == 1
      assert hd(records).id == record3.id
    end
  end

  describe "execute/2 with function action" do
    test "passes query and opts to function", %{ids: ids} do
      test_pid = self()

      action = fn query, opts ->
        send(test_pid, {:called, query, opts})
        {:ok, :done}
      end

      result =
        BulkActionExecutor.execute(action,
          resource: SearchTestResource,
          ids: ids,
          actor: :test_actor,
          tenant: :test_tenant
        )

      assert {:ok, :done} = result

      assert_receive {:called, query, opts}
      assert %Ash.Query{} = query
      assert query.resource == SearchTestResource
      assert opts[:actor] == :test_actor
      assert opts[:tenant] == :test_tenant
    end

    test "handles function that returns bulk result", %{ids: ids} do
      action = fn query, opts ->
        Ash.bulk_update(query, :archive, %{}, opts)
      end

      result =
        BulkActionExecutor.execute(action,
          resource: SearchTestResource,
          ids: ids
        )

      assert {:ok, %Ash.BulkResult{status: :success}} = result

      # Verify records were updated
      {:ok, records} = Ash.read(SearchTestResource)
      archived = Enum.filter(records, &(&1.status == "archived"))
      assert length(archived) == 2
    end

    test "handles function that raises", %{ids: ids} do
      action = fn _query, _opts ->
        raise "Something went wrong"
      end

      result =
        BulkActionExecutor.execute(action,
          resource: SearchTestResource,
          ids: ids
        )

      assert {:error, "Something went wrong"} = result
    end
  end

  describe "action_opts" do
    test "atom actions merge action_opts directly into Ash options", %{ids: ids} do
      # Use return_records? to verify opts are passed through
      result =
        BulkActionExecutor.execute(:archive,
          resource: SearchTestResource,
          ids: ids,
          action_opts: [return_records?: true]
        )

      assert {:ok, %Ash.BulkResult{status: :success, records: records}} = result
      assert length(records) == 2
      assert Enum.all?(records, &(&1.status == "archived"))
    end

    test "function actions wrap action_opts in bulk_options for code interface compatibility", %{
      ids: ids
    } do
      test_pid = self()

      action = fn _query, opts ->
        send(test_pid, {:called_with_opts, opts})
        {:ok, :done}
      end

      result =
        BulkActionExecutor.execute(action,
          resource: SearchTestResource,
          ids: ids,
          action_opts: [return_records?: true, notify?: true]
        )

      assert {:ok, :done} = result

      assert_receive {:called_with_opts, opts}
      assert opts[:bulk_options] == [return_records?: true, notify?: true]
      # nil actor/tenant/scope are filtered out, not passed as explicit nils
      refute Keyword.has_key?(opts, :actor)
      refute Keyword.has_key?(opts, :tenant)
      refute Keyword.has_key?(opts, :scope)
    end

    test "function actions without action_opts don't include bulk_options key", %{ids: ids} do
      test_pid = self()

      action = fn _query, opts ->
        send(test_pid, {:called_with_opts, opts})
        {:ok, :done}
      end

      result =
        BulkActionExecutor.execute(action,
          resource: SearchTestResource,
          ids: ids
        )

      assert {:ok, :done} = result

      assert_receive {:called_with_opts, opts}
      refute Keyword.has_key?(opts, :bulk_options)
    end
  end

  describe "scope, actor, tenant — function action" do
    # Function actions are documented as receiving (query, opts) matching code
    # interface signatures. After the scope refactor, opts contain `:scope`,
    # `:actor`, `:tenant` raw — Cinder no longer pre-resolves scope. The
    # function is expected to forward opts to Ash, which handles precedence.

    setup do
      test_pid = self()

      action = fn _query, opts ->
        send(test_pid, {:called_with_opts, opts})
        {:ok, :done}
      end

      %{action: action}
    end

    test "explicit actor reaches opts unchanged", %{ids: ids, action: action} do
      BulkActionExecutor.execute(action,
        resource: SearchTestResource,
        ids: ids,
        actor: :alice
      )

      assert_receive {:called_with_opts, opts}
      assert Keyword.get(opts, :actor) == :alice
      refute Keyword.has_key?(opts, :scope)
    end

    test "scope is passed raw, not pre-resolved to actor/tenant", %{ids: ids, action: action} do
      scope = %TestScope{current_user: :scope_actor, current_tenant: "scope_tenant", tz: nil}

      BulkActionExecutor.execute(action,
        resource: SearchTestResource,
        ids: ids,
        scope: scope
      )

      assert_receive {:called_with_opts, opts}
      # Scope is passed through untouched — function/Ash resolves
      assert Keyword.get(opts, :scope) == scope
      # Cinder does NOT pre-extract actor/tenant from scope
      refute Keyword.has_key?(opts, :actor)
      refute Keyword.has_key?(opts, :tenant)
    end

    test "explicit + scope both reach opts; Ash resolves precedence", %{ids: ids, action: action} do
      scope = %TestScope{current_user: :scope_actor, current_tenant: "scope_tenant", tz: nil}

      BulkActionExecutor.execute(action,
        resource: SearchTestResource,
        ids: ids,
        scope: scope,
        actor: :explicit_actor,
        tenant: "explicit_tenant"
      )

      assert_receive {:called_with_opts, opts}
      # All three keys present; downstream Ash applies its documented
      # precedence (explicit wins over scope).
      assert Keyword.get(opts, :scope) == scope
      assert Keyword.get(opts, :actor) == :explicit_actor
      assert Keyword.get(opts, :tenant) == "explicit_tenant"
    end

    test "explicit actor: nil is filtered, scope is preserved", %{ids: ids, action: action} do
      scope = %TestScope{current_user: :scope_actor, current_tenant: nil, tz: nil}

      BulkActionExecutor.execute(action,
        resource: SearchTestResource,
        ids: ids,
        scope: scope,
        actor: nil
      )

      assert_receive {:called_with_opts, opts}
      # Nil filtered so scope's actor still wins via Ash resolution
      refute Keyword.has_key?(opts, :actor)
      assert Keyword.get(opts, :scope) == scope
    end

    test "nil scope and no actor/tenant produces no auth keys", %{ids: ids, action: action} do
      BulkActionExecutor.execute(action,
        resource: SearchTestResource,
        ids: ids,
        scope: nil
      )

      assert_receive {:called_with_opts, opts}
      refute Keyword.has_key?(opts, :actor)
      refute Keyword.has_key?(opts, :tenant)
      refute Keyword.has_key?(opts, :scope)
    end

    test "function still works end-to-end with scope (Ash resolves at consumption)",
         %{ids: ids} do
      scope = %TestScope{current_user: nil, current_tenant: nil, tz: nil}

      action = fn query, opts ->
        Ash.bulk_update(query, :archive, %{}, opts)
      end

      result =
        BulkActionExecutor.execute(action,
          resource: SearchTestResource,
          ids: ids,
          scope: scope
        )

      assert {:ok, %Ash.BulkResult{status: :success}} = result
    end
  end

  describe "scope, actor, tenant — atom action" do
    # Atom actions go through Ash.bulk_update / Ash.bulk_destroy. We mock those
    # to capture the opts and verify the same scope/actor/tenant contract as
    # function actions.

    setup do
      test_pid = self()

      Ash
      |> expect(:bulk_update, fn _query, action, params, opts ->
        send(test_pid, {:bulk_update_called, action, params, opts})
        %Ash.BulkResult{status: :success}
      end)

      :ok
    end

    test "explicit actor flows through to Ash.bulk_update opts", %{ids: ids} do
      BulkActionExecutor.execute(:archive,
        resource: SearchTestResource,
        ids: ids,
        actor: :alice
      )

      assert_receive {:bulk_update_called, :archive, _params, opts}
      assert Keyword.get(opts, :actor) == :alice
      refute Keyword.has_key?(opts, :scope)
    end

    test "scope flows through raw to Ash.bulk_update opts", %{ids: ids} do
      scope = %TestScope{current_user: :scope_actor, current_tenant: "t1", tz: nil}

      BulkActionExecutor.execute(:archive,
        resource: SearchTestResource,
        ids: ids,
        scope: scope
      )

      assert_receive {:bulk_update_called, :archive, _params, opts}
      assert Keyword.get(opts, :scope) == scope
      refute Keyword.has_key?(opts, :actor)
      refute Keyword.has_key?(opts, :tenant)
    end

    test "explicit + scope both reach Ash.bulk_update opts", %{ids: ids} do
      scope = %TestScope{current_user: :scope_actor, current_tenant: "scope_t", tz: nil}

      BulkActionExecutor.execute(:archive,
        resource: SearchTestResource,
        ids: ids,
        scope: scope,
        actor: :explicit_actor,
        tenant: "explicit_t"
      )

      assert_receive {:bulk_update_called, :archive, _params, opts}
      assert Keyword.get(opts, :scope) == scope
      assert Keyword.get(opts, :actor) == :explicit_actor
      assert Keyword.get(opts, :tenant) == "explicit_t"
    end

    test "nil actor/tenant/scope are filtered", %{ids: ids} do
      BulkActionExecutor.execute(:archive,
        resource: SearchTestResource,
        ids: ids,
        scope: nil,
        actor: nil,
        tenant: nil
      )

      assert_receive {:bulk_update_called, :archive, _params, opts}
      refute Keyword.has_key?(opts, :scope)
      refute Keyword.has_key?(opts, :actor)
      refute Keyword.has_key?(opts, :tenant)
    end

    test "action_opts are still merged alongside auth opts", %{ids: ids} do
      BulkActionExecutor.execute(:archive,
        resource: SearchTestResource,
        ids: ids,
        actor: :alice,
        action_opts: [return_records?: true, notify?: true]
      )

      assert_receive {:bulk_update_called, :archive, _params, opts}
      assert Keyword.get(opts, :actor) == :alice
      assert Keyword.get(opts, :return_records?) == true
      assert Keyword.get(opts, :notify?) == true
    end

    test "action_opts override top-level auth opts (slot config wins)", %{ids: ids} do
      # The atom path does `Keyword.merge(base_opts, action_opts)`, so a slot
      # config that explicitly sets `action_opts: [actor: ...]` overrides the
      # collection's `actor=`. This is intentional — the slot author asked for
      # it — but lock the contract in so a refactor doesn't quietly reverse it.
      BulkActionExecutor.execute(:archive,
        resource: SearchTestResource,
        ids: ids,
        actor: :alice,
        action_opts: [actor: :impersonated]
      )

      assert_receive {:bulk_update_called, :archive, _params, opts}
      assert Keyword.get(opts, :actor) == :impersonated
    end
  end

  describe "scope, actor, tenant — atom destroy action" do
    # Destroy actions go through `Ash.bulk_destroy`. Smoke test that they
    # receive the same auth opts shape as update actions.

    test "scope flows through raw to Ash.bulk_destroy opts", %{ids: ids} do
      test_pid = self()
      scope = %TestScope{current_user: :alice, current_tenant: "t1", tz: nil}

      Ash
      |> expect(:bulk_destroy, fn _query, action, _params, opts ->
        send(test_pid, {:bulk_destroy_called, action, opts})
        %Ash.BulkResult{status: :success}
      end)

      BulkActionExecutor.execute(:destroy,
        resource: SearchTestResource,
        ids: ids,
        scope: scope
      )

      assert_receive {:bulk_destroy_called, :destroy, opts}
      assert Keyword.get(opts, :scope) == scope
      refute Keyword.has_key?(opts, :actor)
      refute Keyword.has_key?(opts, :tenant)
    end
  end

  describe "atom and function action — auth opts parity" do
    # Both paths should produce identical auth opts (modulo function-specific
    # wrappers like :bulk_options). Regression guard against the kind of
    # divergence that's caused bulk-action scope bugs in the past.

    test "scope-only: same auth keys in both paths", %{ids: ids} do
      scope = %TestScope{current_user: :alice, current_tenant: "t1", tz: "UTC"}
      test_pid = self()

      # Function path
      fn_action = fn _query, opts ->
        send(test_pid, {:fn_opts, opts})
        {:ok, :done}
      end

      BulkActionExecutor.execute(fn_action,
        resource: SearchTestResource,
        ids: ids,
        scope: scope
      )

      # Atom path
      Ash
      |> expect(:bulk_update, fn _query, _action, _params, opts ->
        send(test_pid, {:atom_opts, opts})
        %Ash.BulkResult{status: :success}
      end)

      BulkActionExecutor.execute(:archive,
        resource: SearchTestResource,
        ids: ids,
        scope: scope
      )

      assert_receive {:fn_opts, fn_opts}
      assert_receive {:atom_opts, atom_opts}

      # Auth subset should be identical (drop function-only / atom-only keys)
      auth_keys = [:scope, :actor, :tenant]
      assert Keyword.take(fn_opts, auth_keys) == Keyword.take(atom_opts, auth_keys)
    end

    test "explicit-only: same auth keys in both paths", %{ids: ids} do
      test_pid = self()

      fn_action = fn _query, opts ->
        send(test_pid, {:fn_opts, opts})
        {:ok, :done}
      end

      BulkActionExecutor.execute(fn_action,
        resource: SearchTestResource,
        ids: ids,
        actor: :bob,
        tenant: "t2"
      )

      Ash
      |> expect(:bulk_update, fn _query, _action, _params, opts ->
        send(test_pid, {:atom_opts, opts})
        %Ash.BulkResult{status: :success}
      end)

      BulkActionExecutor.execute(:archive,
        resource: SearchTestResource,
        ids: ids,
        actor: :bob,
        tenant: "t2"
      )

      assert_receive {:fn_opts, fn_opts}
      assert_receive {:atom_opts, atom_opts}

      auth_keys = [:scope, :actor, :tenant]
      assert Keyword.take(fn_opts, auth_keys) == Keyword.take(atom_opts, auth_keys)
    end
  end

  describe "normalize_result/1" do
    test "passes through {:ok, _} tuples" do
      assert {:ok, :value} = BulkActionExecutor.normalize_result({:ok, :value})
    end

    test "passes through {:error, _} tuples" do
      assert {:error, :reason} = BulkActionExecutor.normalize_result({:error, :reason})
    end

    test "converts :ok to {:ok, :ok}" do
      assert {:ok, :ok} = BulkActionExecutor.normalize_result(:ok)
    end

    test "converts successful BulkResult" do
      bulk = %Ash.BulkResult{status: :success}
      assert {:ok, ^bulk} = BulkActionExecutor.normalize_result(bulk)
    end

    test "converts error BulkResult" do
      errors = ["error1", "error2"]
      bulk = %Ash.BulkResult{status: :error, errors: errors}
      assert {:error, ^errors} = BulkActionExecutor.normalize_result(bulk)
    end

    test "wraps other values as {:ok, value}" do
      assert {:ok, [1, 2, 3]} = BulkActionExecutor.normalize_result([1, 2, 3])
      assert {:ok, "string"} = BulkActionExecutor.normalize_result("string")
    end
  end
end
