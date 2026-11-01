defmodule Cinder.Integration.RangeSuffixParamsTest.Shipment do
  @moduledoc false
  use Ash.Resource,
    domain: Cinder.Integration.RangeSuffixParamsTest.Domain,
    data_layer: Ash.DataLayer.Ets,
    validate_domain_inclusion?: false

  # Not private, so the LiveView's process sees the records the test seeds
  ets do
    private?(false)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string, public?: true)
    attribute(:ship_to, :string, public?: true)
    attribute(:tier_max, :string, public?: true)
    attribute(:valid_to, :date, public?: true)
    attribute(:price, :integer, public?: true)
  end

  actions do
    defaults([:read, :destroy])
  end
end

defmodule Cinder.Integration.RangeSuffixParamsTest.Domain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(Cinder.Integration.RangeSuffixParamsTest.Shipment)
  end
end

defmodule Cinder.Integration.RangeSuffixParamsTest do
  @moduledoc """
  Covers form filters on fields whose names end in a range input's suffix (`_from`,
  `_to`, `_min`, `_max`), which must not be mistaken for half of a range.
  """
  use Cinder.ConnCase, async: false
  import Phoenix.ConnTest, only: [get: 2]
  import Phoenix.LiveViewTest, only: [live: 2, element: 2, render_change: 2]

  alias Cinder.Integration.RangeSuffixParamsTest.Shipment

  defp collection(assigns) do
    ~H"""
    <Cinder.collection resource={Shipment}>
      <:col :let={s} field="name">{s.name}</:col>
      <:col :let={s} field="ship_to" filter>{s.ship_to}</:col>
      <:col :let={s} field="tier_max" filter>{s.tier_max}</:col>
      <:col :let={s} field="valid_to" filter={[type: :date_range]}>{s.valid_to}</:col>
      <:col :let={s} field="price" filter={[type: :number_range]}>{s.price}</:col>
    </Cinder.collection>
    """
  end

  setup do
    seed(
      name: "Early cheap",
      ship_to: "Perth",
      tier_max: "gold",
      valid_to: ~D[2020-01-01],
      price: 5
    )

    seed(
      name: "Late dear",
      ship_to: "Sydney",
      tier_max: "silver",
      valid_to: ~D[2024-01-01],
      price: 50
    )

    on_exit(fn -> Ash.bulk_destroy!(Shipment, :destroy, %{}) end)

    %{path: Cinder.TestLive.Fixture.register(&collection/1)}
  end

  for {name, params, shown, hidden} <- [
        {"a text filter on a `_to` field", %{"ship_to" => "Perth"}, "Early cheap", "Late dear"},
        {"a text filter on a `_max` field", %{"tier_max" => "silver"}, "Late dear",
         "Early cheap"},
        {"a date range on a `_to` field", %{"valid_to_from" => "2023-01-01", "valid_to_to" => ""},
         "Late dear", "Early cheap"},
        {"a number range with both halves", %{"price_min" => "1", "price_max" => "10"},
         "Early cheap", "Late dear"},
        {"a number range with only its upper half", %{"price_min" => "", "price_max" => "10"},
         "Early cheap", "Late dear"}
      ] do
    test "#{name} filters from the form", %{conn: conn, path: path} do
      {:ok, view, _html} = live(conn, path)

      html =
        view
        |> element("form[phx-change=filter_change]")
        |> render_change(%{"filters" => unquote(Macro.escape(params))})

      assert html =~ unquote(shown)
      refute html =~ unquote(hidden)
    end
  end

  defp seed(attrs), do: Ash.Seed.seed!(Shipment, Map.new(attrs))
end
