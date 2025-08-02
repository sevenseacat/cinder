defmodule Cinder.Gettext do
  @moduledoc """
  Default `Gettext` backend.
  """

  use Gettext.Backend, otp_app: :cinder, priv: "i18n/gettext"
end
