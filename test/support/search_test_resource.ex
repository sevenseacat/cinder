defmodule Cinder.Support.SearchTestResource do
  @moduledoc """
  Shared test resource for search functionality testing.
  Eliminates duplication across search test files.
  """

  use Ash.Resource,
    domain: Cinder.Support.SearchTestDomain,
    data_layer: Ash.DataLayer.Ets,
    validate_domain_inclusion?: false

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:title, :string, public?: true)
    attribute(:description, :string, public?: true)
    attribute(:status, :string, public?: true)
    attribute(:category, :string, public?: true)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)
      accept([:title, :description, :status, :category])
    end

    update :archive do
      change(set_attribute(:status, "archived"))
    end
  end
end

defmodule Cinder.Support.SearchTestDomain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(Cinder.Support.SearchTestResource)
  end
end
