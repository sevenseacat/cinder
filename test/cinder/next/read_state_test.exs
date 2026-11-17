defmodule Cinder.Next.ReadStateTest do
  use ExUnit.Case, async: true

  alias Cinder.Engine.{Error, Page}
  alias Cinder.Next.ReadState

  describe "read_first?/3, whether a read is done before the page renders" do
    test "always when Ash's `disable_async?` is set, as apps do in their tests" do
      assert ReadState.read_first?(:loaded, :async, true)
    end

    test "the first read, with `initial_load: :sync`" do
      assert ReadState.read_first?(:unread, :sync, false)
      refute ReadState.read_first?(:loaded, :sync, false)
      refute ReadState.read_first?(:unread, :async, false)
    end
  end

  describe "done/1, a read's result" do
    test "records are loaded" do
      page = %Page{records: [%{title: "Blue"}]}
      assert ReadState.done({:ok, page}) == {:loaded, page}
    end

    # Ash's messages, as `{message, vars}`, until they're translated
    test "values the action can't use are invalid, each input's messages filled in, with no records" do
      inputs = %{
        "genre" => [{"is invalid", []}],
        "year" => [
          {"must be at least %{min}", min: 1900},
          {"must be one of %{values}", values: [:a, :b]}
        ]
      }

      assert ReadState.done({:error, %Error{inputs: inputs}}) ==
               {{:invalid,
                 %{
                   "genre" => ["is invalid"],
                   "year" => ["must be at least 1900", "must be one of a, b"]
                 }}, %Page{}}
    end

    # A var without `String.Chars` is inspected rather than crashing
    test "a var that can't be a string is inspected" do
      inputs = %{"range" => [{"got %{value}", value: %{min: 1}}]}

      assert ReadState.done({:error, %Error{inputs: inputs}}) ==
               {{:invalid, %{"range" => ["got %{min: 1}"]}}, %Page{}}
    end

    # As a form doesn't say a field is required before it's used
    test "missing required arguments are invalid with nothing to say yet" do
      assert ReadState.done({:error, %Error{}}) == {{:invalid, %{}}, %Page{}}
    end

    # Argument errors alongside another reason are dropped: the user can't fix the read
    test "any other error is a failure, with no records" do
      error = %Error{inputs: %{"genre" => [{"is invalid", []}]}, reason: :timeout}
      assert ReadState.done({:error, error}) == {{:failed, :timeout}, %Page{}}
    end

    test "a read that crashed is a failure, with no records" do
      assert ReadState.done({:exit, :killed}) == {{:failed, :killed}, %Page{}}
    end
  end

  # The markup's, and a retry's, so a forged one, or one sent twice, doesn't read again
  test "failed?/1" do
    assert ReadState.failed?({:failed, :timeout})
    refute ReadState.failed?(:loading)
    refute ReadState.failed?(:loaded)
    refute ReadState.failed?({:invalid, %{}})
  end

  test "loading?/1, loaded?/1 and errors/1, for the markup" do
    assert ReadState.loading?(:loading)
    refute ReadState.loading?(:loaded)

    assert ReadState.loaded?(:loaded)
    refute ReadState.loaded?(:loading)
    refute ReadState.loaded?({:invalid, %{}})

    assert ReadState.errors({:invalid, %{"genre" => ["is invalid"]}}) == %{
             "genre" => ["is invalid"]
           }

    assert ReadState.errors(:loaded) == %{}
  end
end
