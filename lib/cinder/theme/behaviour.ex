defmodule Cinder.Theme.Behaviour do
  @moduledoc """
  Behaviour for Cinder theme modules.

  This behaviour defines the interface that all theme modules must implement,
  whether they use the DSL or are simple theme modules.
  """

  @doc """
  Resolves the theme configuration into a map of CSS classes.

  Returns a map where keys are theme property atoms and values are CSS class strings.
  """
  @callback resolve_theme() :: %{atom() => String.t()}
end
