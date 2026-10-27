# SPDX-FileCopyrightText: 2025 Cinder contributors <https://github.com/sevenseacat/cinder/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Cinder.Messages do
  @moduledoc """
  Provides Gettext macros with configurable backend support.

  This module allows using Gettext macros while supporting a configurable
  backend through the `:gettext_backend` application config.
  """

  # Get the backend at compile time
  @backend Application.compile_env(:cinder, :gettext_backend, Cinder.Gettext)

  @doc """
  Injects Gettext macros into the using module.

  This allows automatic extraction of translation strings while
  maintaining support for configurable Gettext backends.

  ## Usage

      defmodule MyModule do
        use Cinder.Messages
        
        def my_function do
          dgettext("cinder", "Hello world")
        end
      end
  """
  defmacro __using__(_opts) do
    backend = @backend

    quote do
      use Gettext, backend: unquote(backend)
    end
  end

  @doc false
  @deprecated "Unused by Cinder, and removed in 1.0"
  def gettext_backend do
    Application.get_env(:cinder, :gettext_backend, Cinder.Gettext)
  end
end
