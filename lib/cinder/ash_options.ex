defmodule Cinder.AshOptions do
  @moduledoc """
  Resolves actor, tenant, and scope into options for Ash calls.

  Cinder accepts `:actor`, `:tenant`, and `:scope` from host LiveViews. The
  scope is an Ash 3 idiom: a struct implementing `Ash.Scope.ToOpts` that
  carries actor, tenant, tracer, and context together. This module unifies
  how both the read and bulk-action pipelines resolve those inputs so scope
  is always honoured, with explicit actor/tenant overriding the scope's.
  """

  @doc """
  Resolves actor, tenant, and scope into `{actor, tenant, scope_opts}`.

  `scope_opts` contains any non-actor/tenant options the scope exposes
  (tracer, context, authorize?), suitable for merging into the final Ash
  options. An invalid scope is tolerated and treated as an empty list.
  """
  @spec resolve(any(), any(), any()) :: {any(), any(), keyword()}
  def resolve(actor, tenant, scope) do
    scope_opts = extract_scope_options(scope)
    resolved_actor = actor || scope_opts[:actor]
    resolved_tenant = tenant || scope_opts[:tenant]
    {resolved_actor, resolved_tenant, scope_opts}
  end

  defp extract_scope_options(nil), do: []

  defp extract_scope_options(scope) do
    try do
      Ash.Scope.to_opts(scope)
    rescue
      _ -> []
    end
  end
end
