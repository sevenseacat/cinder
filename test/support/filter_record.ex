defmodule Cinder.Test.FilterRecord do
  @moduledoc """
  Records to run filters' queries against, so their tests can check what comes back. The
  ETS table is private to each test process, so tests seed their own records.
  """
  use Ash.Resource,
    domain: Cinder.Test.FilterRecordDomain,
    data_layer: Ash.DataLayer.Ets,
    validate_domain_inclusion?: false

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string, public?: true)
    attribute(:active, :boolean, public?: true)
    attribute(:tags, {:array, :string}, public?: true, default: [])
    attribute(:flags, {:array, :boolean}, public?: true, default: [])
  end

  actions do
    defaults([:read])
  end

  @doc "Seeds a record with the given attributes."
  def seed(attrs), do: Ash.Seed.seed!(__MODULE__, Map.new(attrs))

  @doc "The ids of the records a filter type's `build_query/3` matches."
  def matching_ids(filter_module, field, filter_value) do
    __MODULE__
    |> Ash.Query.new()
    |> filter_module.build_query(field, filter_value)
    |> Ash.read!()
    |> MapSet.new(& &1.id)
  end
end

defmodule Cinder.Test.FilterRecordDomain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(Cinder.Test.FilterRecord)
  end
end
