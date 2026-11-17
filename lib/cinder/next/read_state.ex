# SPDX-FileCopyrightText: 2026 Cinder contributors <https://github.com/sevenseacat/cinder/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Cinder.Next.ReadState do
  @moduledoc false
  # Where a collection's read of its records is, and every rule about it, as pure
  # functions: `:unread` (before the first), `:loading`, `:loaded`, or
  # `{:invalid, errors}` (argument values the action can't use, as messages by
  # input, or required arguments missing, with nothing to say yet). The records
  # shown are `Cinder.Next.Collection`'s, as the old ones stay while loading.

  alias Cinder.Engine.{Error, Page}

  @doc """
  Whether a read is done before the page renders: always when Ash's
  `disable_async?` is set (as apps do in their tests), and the first with
  `initial_load: :sync`.
  """
  def read_first?(state, initial_load, disable_async?) do
    disable_async? or (initial_load == :sync and state == :unread)
  end

  @doc """
  A read's result (from `Cinder.Engine.run/4`) as the state and the records to
  show. Only errors the user can fix are taken; other failures are the caller's.
  """
  def done({:ok, %Page{} = page}), do: {:loaded, page}

  def done({:error, %Error{reason: nil, inputs: inputs}}) do
    errors = Map.new(inputs, fn {name, errors} -> {name, Enum.map(errors, &message/1)} end)
    {{:invalid, errors}, %Page{}}
  end

  @doc "Whether a read is under way."
  def loading?(state), do: state == :loading

  @doc "Each input's messages, when the action can't use its value."
  def errors({:invalid, errors}), do: errors
  def errors(_state), do: %{}

  # Ash's messages, filled in but not translated, until they can be
  defp message({message, vars}) do
    Enum.reduce(vars, message, fn {key, value}, message ->
      String.replace(message, "%{#{key}}", var(value))
    end)
  end

  # Lists are chardata to `to_string/1`, so a list of values (`one_of`'s) is joined
  defp var(value) when is_list(value), do: Enum.map_join(value, ", ", &var/1)

  defp var(value) do
    if String.Chars.impl_for(value), do: to_string(value), else: inspect(value)
  end
end
