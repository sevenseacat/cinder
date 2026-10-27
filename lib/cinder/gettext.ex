# SPDX-FileCopyrightText: 2025 Cinder contributors <https://github.com/sevenseacat/cinder/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Cinder.Gettext do
  @moduledoc """
  Default `Gettext` backend.
  """

  use Gettext.Backend, otp_app: :cinder, priv: "i18n/gettext"
end
