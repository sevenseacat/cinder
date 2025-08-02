defmodule Cinder.Messages do
  @moduledoc """
  Wrappers for `Gettext` translation functions.
  """

  @doc """
  Gets the default `Gettext` backend or a user configured one.
  """
  def gettext_backend, do: Application.get_env(:cinder, :gettext_backend, Cinder.Gettext)

  def dgettext(domain, msgid, bindings \\ %{}) do
    gettext_backend()
    |> Gettext.dgettext(domain, msgid, bindings)
  end

  def dngettext(domain, msgid, msgid_plural, n, bindings \\ %{}) do
    gettext_backend()
    |> Gettext.dngettext(domain, msgid, msgid_plural, n, bindings)
  end
end
