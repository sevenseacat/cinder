defmodule Cinder.Filters.DateRangeFieldConversionTest.Domain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(Cinder.Filters.DateRangeFieldConversionTest.Event)
    resource(Cinder.Filters.DateRangeFieldConversionTest.Venue)
  end
end

defmodule Cinder.Filters.DateRangeFieldConversionTest.Venue do
  @moduledoc false
  use Ash.Resource,
    domain: Cinder.Filters.DateRangeFieldConversionTest.Domain,
    data_layer: Ash.DataLayer.Ets,
    validate_domain_inclusion?: false

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:opened_at, :naive_datetime, public?: true)
  end

  actions do
    defaults([:read, create: [:opened_at]])
  end

  relationships do
    has_many(:events, Cinder.Filters.DateRangeFieldConversionTest.Event)
  end
end

defmodule Cinder.Filters.DateRangeFieldConversionTest.Meta do
  @moduledoc false
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute(:recorded_on, :date, public?: true)
    attribute(:recorded_at, :naive_datetime, public?: true)
  end
end

defmodule Cinder.Filters.DateRangeFieldConversionTest.Event do
  @moduledoc false
  use Ash.Resource,
    domain: Cinder.Filters.DateRangeFieldConversionTest.Domain,
    data_layer: Ash.DataLayer.Ets,
    validate_domain_inclusion?: false

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:on_date, :date, public?: true)
    attribute(:at_naive, :naive_datetime, public?: true)
    attribute(:at_utc, :utc_datetime, public?: true)
    attribute(:at_usec, :utc_datetime_usec, public?: true)
    attribute(:meta, Cinder.Filters.DateRangeFieldConversionTest.Meta, public?: true)
  end

  actions do
    defaults([:read, create: [:on_date, :at_naive, :at_utc, :at_usec, :meta, :venue_id]])
  end

  relationships do
    belongs_to :venue, Cinder.Filters.DateRangeFieldConversionTest.Venue do
      public?(true)
      attribute_writable?(true)
    end
  end
end

defmodule Cinder.Filters.DateRangeFieldConversionTest do
  use ExUnit.Case, async: true

  alias Cinder.Filters.DateRange
  alias Cinder.Filters.DateRangeFieldConversionTest.{Event, Venue}

  defp matching_ids(resource \\ Event, field, from, to) do
    resource
    |> filtered(field, from, to)
    |> Ash.read!()
    |> MapSet.new(& &1.id)
  end

  defp filtered(resource, field, from, to) do
    filter_value = %{type: :date_range, value: %{from: from, to: to}, operator: :between}
    DateRange.build_query(Ash.Query.new(resource), field, filter_value)
  end

  describe "build_query/3, by the records it returns" do
    test "covers the whole first and last days on date and datetime fields" do
      for {field, day_before, first, last, day_after} <- [
            {:on_date, ~D[2026-06-09], ~D[2026-06-10], ~D[2026-06-12], ~D[2026-06-13]},
            {:at_naive, ~N[2026-06-09 23:59:59], ~N[2026-06-10 00:00:00], ~N[2026-06-12 23:59:59],
             ~N[2026-06-13 00:00:00]},
            {:at_utc, ~U[2026-06-09 23:59:59Z], ~U[2026-06-10 00:00:00Z],
             ~U[2026-06-12 23:59:59Z], ~U[2026-06-13 00:00:00Z]}
          ] do
        hits = for value <- [first, last], do: Ash.create!(Event, %{field => value}).id
        for value <- [day_before, day_after], do: Ash.create!(Event, %{field => value})

        assert matching_ids("#{field}", "2026-06-10", "2026-06-12") == MapSet.new(hits),
               "for #{field}"
      end
    end

    test "leaves a range open on a side with no bound" do
      early = Ash.create!(Event, %{at_naive: ~N[2026-06-01 12:00:00]})
      late = Ash.create!(Event, %{at_naive: ~N[2026-06-20 12:00:00]})

      assert matching_ids("at_naive", "2026-06-10", "") == MapSet.new([late.id])
      assert matching_ids("at_naive", "", "2026-06-10") == MapSet.new([early.id])
      assert matching_ids("at_naive", "", "") == MapSet.new([early.id, late.id])
      assert matching_ids("at_naive", nil, nil) == MapSet.new([early.id, late.id])
    end

    test "mixes a date bound with a bound that has a time" do
      hit = Ash.create!(Event, %{at_usec: ~U[2026-06-12 12:00:00.000000Z]})
      _late = Ash.create!(Event, %{at_usec: ~U[2026-06-12 18:00:00.000000Z]})
      _early = Ash.create!(Event, %{at_usec: ~U[2026-06-09 12:00:00.000000Z]})

      assert matching_ids("at_usec", "2026-06-10", "2026-06-12T17:00") == MapSet.new([hit.id])
    end

    test "through a to-many relationship, needs one related record inside the range" do
      inside = Ash.create!(Venue, %{})
      Ash.create!(Event, %{venue_id: inside.id, at_naive: ~N[2026-06-11 12:00:00]})

      # One event before the range and one after: each passes one bound, neither is in it
      outside = Ash.create!(Venue, %{})
      Ash.create!(Event, %{venue_id: outside.id, at_naive: ~N[2026-06-01 12:00:00]})
      Ash.create!(Event, %{venue_id: outside.id, at_naive: ~N[2026-06-20 12:00:00]})

      assert matching_ids(Venue, "events.at_naive", "2026-06-10", "2026-06-12") ==
               MapSet.new([inside.id])
    end

    # Casting the column (`at_naive::date` in Postgres) would stop a plain index on it being
    # used, and ETS can't show that
    test "compares a date bound against the field itself, not the field cast to a date" do
      filter = inspect(filtered(Event, "at_naive", "2026-06-10", "2026-06-12").filter)

      refute filter =~ "type("
      assert filter =~ "at_naive >= ~N[2026-06-10 00:00:00]"
      assert filter =~ "at_naive < ~N[2026-06-13 00:00:00]"
    end

    test "includes the whole end date of a naive datetime field through a relationship" do
      hit =
        Ash.create!(Event, %{
          venue_id: Ash.create!(Venue, %{opened_at: ~N[2026-06-12 18:00:00]}).id
        })

      _miss =
        Ash.create!(Event, %{
          venue_id: Ash.create!(Venue, %{opened_at: ~N[2026-06-13 00:00:00]}).id
        })

      assert matching_ids("venue.opened_at", "2026-06-10", "2026-06-12") == MapSet.new([hit.id])
    end

    test "matches a date field in an embedded resource" do
      hit = Ash.create!(Event, %{meta: %{recorded_on: ~D[2026-06-12]}})
      _miss = Ash.create!(Event, %{meta: %{recorded_on: ~D[2026-06-13]}})

      assert matching_ids("meta__recorded_on", "2026-06-10", "2026-06-12") == MapSet.new([hit.id])
    end

    test "includes the whole end date of a naive datetime field in an embedded resource" do
      hit = Ash.create!(Event, %{meta: %{recorded_at: ~N[2026-06-12 18:00:00]}})
      _miss = Ash.create!(Event, %{meta: %{recorded_at: ~N[2026-06-13 00:00:00]}})

      assert matching_ids("meta__recorded_at", "2026-06-10", "2026-06-12") == MapSet.new([hit.id])
    end

    test "includes the last second of the end date" do
      hit = Ash.create!(Event, %{at_usec: ~U[2026-06-12 23:59:59.500000Z]})
      _miss = Ash.create!(Event, %{at_usec: ~U[2026-06-13 00:00:00.000000Z]})

      assert matching_ids("at_usec", "2026-06-10", "2026-06-12") == MapSet.new([hit.id])
    end

    test "compares times when the bounds include them" do
      hit = Ash.create!(Event, %{at_usec: ~U[2026-06-12 12:00:00.000000Z]})
      _early = Ash.create!(Event, %{at_usec: ~U[2026-06-12 08:00:00.000000Z]})
      _late = Ash.create!(Event, %{at_usec: ~U[2026-06-12 18:00:00.000000Z]})

      assert matching_ids("at_usec", "2026-06-12T09:00", "2026-06-12T17:00") ==
               MapSet.new([hit.id])
    end
  end

  describe "value conversion helpers" do
    test "format_value_for_input/2 handles include_time properly" do
      # Test datetime-local formatting (include_time: true)
      assert DateRange.__info__(:functions) |> Keyword.has_key?(:render)

      # Test basic date to datetime conversion
      column = %{
        field: "created_at",
        filter_type: :date_range,
        filter_options: [include_time: true]
      }

      current_value = %{from: "2024-01-01", to: "2024-12-31"}
      theme = Cinder.Theme.default()

      rendered = DateRange.render(column, current_value, theme, %{})
      html = Phoenix.HTML.Safe.to_iodata(rendered) |> IO.iodata_to_binary()

      # Should format as datetime-local
      assert String.contains?(html, "2024-01-01T00:00")
      assert String.contains?(html, "2024-12-31T00:00")
    end

    test "format_value_for_input/2 extracts date from datetime when include_time is false" do
      column = %{
        field: "created_at",
        filter_type: :date_range,
        filter_options: [include_time: false]
      }

      current_value = %{from: "2024-01-01T10:30:00", to: "2024-12-31T15:45:00"}
      theme = Cinder.Theme.default()

      rendered = DateRange.render(column, current_value, theme, %{})
      html = Phoenix.HTML.Safe.to_iodata(rendered) |> IO.iodata_to_binary()

      # Should extract only date part
      assert String.contains?(html, ~s(value="2024-01-01"))
      assert String.contains?(html, ~s(value="2024-12-31"))
      # Should not contain time parts
      refute String.contains?(html, "T10:30")
      refute String.contains?(html, "T15:45")
    end
  end

  describe "validation with datetime support" do
    test "validates both date and datetime formats" do
      # Valid date format
      date_filter = %{
        type: :date_range,
        value: %{from: "2024-01-01", to: "2024-12-31"},
        operator: :between
      }

      assert DateRange.validate(date_filter) == true

      # Valid datetime format
      datetime_filter = %{
        type: :date_range,
        value: %{from: "2024-01-01T10:30:00", to: "2024-12-31T15:45:00"},
        operator: :between
      }

      assert DateRange.validate(datetime_filter) == true

      # Valid ISO datetime with timezone
      iso_filter = %{
        type: :date_range,
        value: %{from: "2024-01-01T10:30:00Z", to: "2024-12-31T15:45:00+05:00"},
        operator: :between
      }

      assert DateRange.validate(iso_filter) == true

      # Invalid datetime format
      invalid_filter = %{
        type: :date_range,
        value: %{from: "2024-01-01T25:00:00", to: "2024-12-31"},
        operator: :between
      }

      assert DateRange.validate(invalid_filter) == false

      # Mixed valid formats
      mixed_filter = %{
        type: :date_range,
        value: %{from: "2024-01-01", to: "2024-12-31T15:45:00"},
        operator: :between
      }

      assert DateRange.validate(mixed_filter) == true
    end

    test "handles empty values in validation" do
      # Empty strings should be valid
      empty_filter = %{
        type: :date_range,
        value: %{from: "", to: ""},
        operator: :between
      }

      assert DateRange.validate(empty_filter) == true

      # Nil values should be valid
      nil_filter = %{
        type: :date_range,
        value: %{from: nil, to: nil},
        operator: :between
      }

      assert DateRange.validate(nil_filter) == true

      # Mixed empty and valid
      mixed_empty_filter = %{
        type: :date_range,
        value: %{from: "2024-01-01", to: ""},
        operator: :between
      }

      assert DateRange.validate(mixed_empty_filter) == true
    end
  end
end
