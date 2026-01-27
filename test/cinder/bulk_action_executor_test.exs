defmodule Cinder.BulkActionExecutorTest do
  use ExUnit.Case, async: true

  alias Cinder.BulkActionExecutor
  alias Cinder.Support.SearchTestResource

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

    test "function actions wrap action_opts in bulk_options for code interface compatibility", %{ids: ids} do
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
      assert opts[:actor] == nil
      assert opts[:tenant] == nil
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
