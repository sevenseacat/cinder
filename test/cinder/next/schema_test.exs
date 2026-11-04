defmodule Cinder.Next.SchemaTest do
  use ExUnit.Case, async: true

  alias Cinder.Next.Schema

  # Phoenix's `attr` and `slot` need literal names, so they're written by hand, and
  # this keeps them in step with the schemas, both ways. `__components__/0` is
  # LiveView's own, undocumented record of a module's declarations (it uses it for
  # compile-time checks): if a release changes its shape, this test fails, and
  # nothing users see does.
  test "the component's attrs and slot attrs are the schemas' options" do
    component = Cinder.Next.__components__()[:collection]

    attrs = component.attrs |> Enum.map(& &1.name) |> Enum.sort()
    assert attrs == Schema.collection() |> Keyword.keys() |> Enum.sort()

    col = Enum.find(component.slots, &(&1.name == :col))
    col_attrs = col.attrs |> Enum.map(& &1.name) |> Enum.sort()
    assert col_attrs == Schema.col() |> Keyword.keys() |> Enum.sort()
  end
end
