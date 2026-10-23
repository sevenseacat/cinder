defmodule Cinder.Next.SchemaSyncTest do
  @moduledoc """
  `Cinder.Next.collection/1` declares its attrs and slots for HEEx (compile-time
  warnings, docs), and `Cinder.Next.Schema` checks them. Phoenix's `attr` takes
  literal names, so the declarations can't be generated from the schema; this
  keeps the two in step instead, in both directions.
  """
  use ExUnit.Case, async: true

  alias Cinder.Next.Schema

  @component Cinder.Next.__components__()[:collection]

  test "the component declares an attr for each option it takes, and no others" do
    assert Enum.sort(Enum.map(@component.attrs, & &1.name)) == Enum.sort(Schema.component_attrs())
  end

  test "each slot with a schema declares the same attrs" do
    for slot <- Schema.slots() do
      declared = Enum.find(@component.slots, &(&1.name == slot))
      assert declared, "<:#{slot}> has a schema but isn't declared"

      assert {slot, Enum.sort(Enum.map(declared.attrs, & &1.name))} ==
               {slot, Enum.sort(Schema.slot_attrs(slot))}
    end
  end

  test "the DSL has a section for each slot taken as a keyword list" do
    [collection] = Cinder.Next.Dsl.Extension.sections()

    assert Enum.sort(Enum.map(collection.sections, & &1.name)) ==
             Enum.sort(Schema.dsl_sections())
  end
end
