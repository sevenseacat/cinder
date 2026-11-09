defmodule TestCompositeKey do
  @moduledoc false
  # A resource whose primary key is two attributes, so no one field identifies a record
  use Ash.Resource, domain: nil

  attributes do
    attribute(:album_id, :uuid, primary_key?: true, allow_nil?: false)
    attribute(:position, :integer, primary_key?: true, allow_nil?: false)
    attribute(:code, :string)
  end

  actions do
    defaults([:read])
  end
end
