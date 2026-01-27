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
          tenant: any(),
          action_opts: keyword()
        ]

  @doc """
  Executes a bulk action on the given IDs.

  ## Options

  - `:resource` - The Ash resource (required)
  - `:ids` - List of record IDs to act on (required)
  - `:id_field` - The field to filter on (default: `:id`)
  - `:actor` - Actor for authorization
  - `:tenant` - Tenant for multi-tenancy
  - `:action_opts` - Additional options for the action (e.g., `[return_records?: true]`)

  ## Action Types

  - **Atom**: Calls `Ash.bulk_update/4` (or `Ash.bulk_destroy/4` for `:destroy`).
    Action opts are merged directly into the Ash options.
  - **Function/2**: Calls the function with `(query, opts)` where query is
    filtered to the selected IDs. Action opts are wrapped in `bulk_options: [...]`
    for code interface compatibility.

  ## Examples

      # Atom action - uses Ash.bulk_update
      execute(:archive, resource: MyApp.User, ids: ["1", "2"], actor: current_user)

      # With action options
      execute(:archive, resource: MyApp.User, ids: ["1", "2"], action_opts: [return_records?: true])

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
    action_opts = Keyword.get(opts, :action_opts, [])

    query = build_query(resource, ids, id_field)
    base_opts = build_base_opts(actor, tenant)

    run_action(action, query, base_opts, action_opts)
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

  defp build_base_opts(actor, tenant) do
    [actor: actor, tenant: tenant]
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
  end

  # Atom actions: merge action_opts directly (for Ash.bulk_update/bulk_destroy)
  defp run_action(action, query, base_opts, action_opts) when is_atom(action) do
    opts = Keyword.merge(base_opts, action_opts)

    result =
      case action do
        :destroy ->
          Ash.bulk_destroy(query, :destroy, %{}, opts)

        _ ->
          Ash.bulk_update(query, action, %{}, opts)
      end

    normalize_result(result)
  end

  # Function actions: wrap action_opts in bulk_options (for code interface)
  defp run_action(action, query, base_opts, action_opts) when is_function(action, 2) do
    opts =
      if action_opts == [] do
        base_opts
      else
        Keyword.put(base_opts, :bulk_options, action_opts)
      end

    try do
      result = action.(query, opts)
      normalize_result(result)
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  defp run_action(_action, _query, _base_opts, _action_opts) do
    {:error, "Invalid action - must be an atom or function/2"}
  end
end
