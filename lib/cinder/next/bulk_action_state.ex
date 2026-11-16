# SPDX-FileCopyrightText: 2026 Cinder contributors <https://github.com/sevenseacat/cinder/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Cinder.Next.BulkActionState do
  @moduledoc false
  # Where a collection's bulk actions are, and every rule about moving between
  # states, as pure functions: `:idle`, `{:confirming, bulk_action, asked_at}` (in
  # milliseconds) or `{:running, bulk_action, selected_count}`. One at a time. The
  # time is given, so the rules don't read a clock; running the action is
  # `Cinder.Next.Collection`'s.

  @doc """
  When the user clicks an action (`nil` if it isn't declared): one with a confirm
  asks first, and one without runs. With nothing selected, or while one waits or
  runs, it's ignored: the buttons are disabled then, so it's from tampering.
  """
  def ask(:idle, %{} = bulk_action, selected_count, now) when selected_count > 0 do
    if bulk_action.confirm do
      {:confirming, {:confirming, bulk_action, now}}
    else
      {:run, bulk_action}
    end
  end

  def ask(_state, _bulk_action, _selected_count, _now), do: :ignore

  @doc """
  When the user confirms the action named. Within `delay` of asking, it's a slow
  double click on the action, not an answer, so it's ignored and the question
  stays. With nothing waiting, another action waiting, or nothing selected, it's
  ignored too.
  """
  def answer({:confirming, %{name: name} = bulk_action, asked_at}, name, count, now, delay)
      when now - asked_at >= delay and count > 0 do
    {:run, bulk_action}
  end

  def answer(_state, _name, _selected_count, _now, _delay), do: :ignore

  @doc "Only a confirm can be cancelled: a running action isn't stopped."
  def cancel({:confirming, _bulk_action, _asked_at}), do: :idle
  def cancel(state), do: state

  @doc "An action running on `selected_count` records."
  def running(bulk_action, selected_count), do: {:running, bulk_action, selected_count}

  @doc """
  When the collection is rebuilt with `bulk_actions`: a waiting confirm asks about
  its action as now declared, and goes if the action has. A running action is left
  to finish.
  """
  def carry_over({:confirming, %{name: name}, asked_at}, bulk_actions) do
    case Enum.find(bulk_actions, &(&1.name == name)) do
      nil -> :idle
      bulk_action -> {:confirming, bulk_action, asked_at}
    end
  end

  def carry_over(state, _bulk_actions), do: state

  @doc "With nothing selected, a waiting confirm has nothing left to act on."
  def for_selection({:confirming, _bulk_action, _asked_at}, 0), do: :idle
  def for_selection(state, _selected_count), do: state
end
