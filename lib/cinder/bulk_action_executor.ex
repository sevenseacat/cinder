defmodule Cinder.BulkActionExecutor do
  @moduledoc """
  Executes bulk actions on selected records.

  Handles both Ash action atoms (using bulk_update/bulk_destroy) and
  function captures (passing an Ash.Query filtered to the selected IDs).
  """

  @type action :: atom() | (Ash.Query.t(), keyword() -> any())
  @type opts :: [
          resource: Ash.Resource.t(),
          ids: [String.t()],
          id_field: atom(),
          actor: any(),
          tenant: any()
        ]

  @doc """
  Executes a bulk action on the given IDs.

  ## Options

  - `:resource` - The Ash resource (required)
  - `:ids` - List of record IDs to act on (required)
  - `:id_field` - The field to filter on (default: `:id`)
  - `:actor` - Actor for authorization
  - `:tenant` - Tenant for multi-tenancy

  ## Action Types

  - **Atom**: Calls `Ash.bulk_update/4` (or `Ash.bulk_destroy/4` for `:destroy`)
  - **Function/2**: Calls the function with `(query, opts)` where query is
    filtered to the selected IDs

  ## Examples

      # Atom action - uses Ash.bulk_update
      execute(:archive, resource: MyApp.User, ids: ["1", "2"], actor: current_user)

      # Function - receives filtered query
      execute(&MyApp.Users.archive/2, resource: MyApp.User, ids: ["1", "2"])

      # Destroy action
      execute(:destroy, resource: MyApp.User, ids: ["1", "2"])
  """
  @spec execute(action(), opts()) :: {:ok, any()} | {:error, any()}
  def execute(action, opts) do
    resource = Keyword.fetch!(opts, :resource)
    ids = Keyword.fetch!(opts, :ids)
    id_field = Keyword.get(opts, :id_field, :id)
    actor = Keyword.get(opts, :actor)
    tenant = Keyword.get(opts, :tenant)

    query = build_query(resource, ids, id_field)
    ash_opts = build_ash_opts(actor, tenant)

    run_action(action, query, ash_opts)
  end

  @doc """
  Builds an Ash.Query filtered to the given IDs.
  """
  @spec build_query(Ash.Resource.t(), [String.t()], atom()) :: Ash.Query.t()
  def build_query(resource, ids, id_field \\ :id) do
    filter = %{id_field => [in: ids]}

    resource
    |> Ash.Query.new()
    |> Ash.Query.filter_input(filter)
  end

  @doc """
  Normalizes a bulk action result to `{:ok, result}` or `{:error, reason}`.
  """
  @spec normalize_result(any()) :: {:ok, any()} | {:error, any()}
  def normalize_result(result) do
    case result do
      {:ok, _} = success -> success
      {:error, _} = error -> error
      :ok -> {:ok, :ok}
      %Ash.BulkResult{status: :success} = bulk -> {:ok, bulk}
      %Ash.BulkResult{status: :error, errors: errors} -> {:error, errors}
      other -> {:ok, other}
    end
  end

  # Private functions

  defp build_ash_opts(actor, tenant) do
    [actor: actor, tenant: tenant]
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
  end

  defp run_action(action, query, opts) when is_atom(action) do
    result =
      case action do
        :destroy ->
          Ash.bulk_destroy(query, :destroy, %{}, opts)

        _ ->
          Ash.bulk_update(query, action, %{}, opts)
      end

    normalize_result(result)
  end

  defp run_action(action, query, opts) when is_function(action, 2) do
    try do
      result = action.(query, opts)
      normalize_result(result)
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  defp run_action(_action, _query, _opts) do
    {:error, "Invalid action - must be an atom or function/2"}
  end
end
