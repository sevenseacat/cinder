defmodule Cinder.Next.SchemaTest do
  use ExUnit.Case, async: true

  alias Cinder.Next.Schema

  # Phoenix's `attr` and `slot` need literal names, so they're written by hand, and
  # this keeps them in step with the schemas, both ways. `__components__/0` is
  # LiveView's own, undocumented record of a module's declarations (it uses it for
  # compile-time checks): if a release changes its shape, this test fails, and
  # nothing users see does.
  test "the component's attrs and each slot's attrs are the schemas' options" do
    component = Cinder.Next.__components__()[:collection]

    attrs = component.attrs |> Enum.map(& &1.name) |> Enum.sort()
    assert attrs == Schema.collection() |> Keyword.keys() |> Enum.sort()

    field = Enum.find(component.slots, &(&1.name == :field))
    field_attrs = field.attrs |> Enum.map(& &1.name) |> Enum.sort()
    assert field_attrs == Schema.field() |> Keyword.keys() |> Enum.sort()

    argument = Enum.find(component.slots, &(&1.name == :argument))
    argument_attrs = argument.attrs |> Enum.map(& &1.name) |> Enum.sort()
    assert argument_attrs == Schema.argument() |> Keyword.keys() |> Enum.sort()

    bulk_action = Enum.find(component.slots, &(&1.name == :bulk_action))
    bulk_action_attrs = bulk_action.attrs |> Enum.map(& &1.name) |> Enum.sort()
    assert bulk_action_attrs == Schema.bulk_action() |> Keyword.keys() |> Enum.sort()
  end
end
