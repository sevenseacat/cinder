# SPDX-FileCopyrightText: 2026 Cinder contributors <https://github.com/sevenseacat/cinder/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Cinder.Params do
  @moduledoc """
  Strings to and from values: a filter form's params, and a collection's URL
  params.

  The shell hands it what was typed or what's in the URL, and gets back the
  values to query with, or the other way round. It doesn't touch Ash: what a
  field is comes from `Cinder.Engine`.

  Input comes from users, so input that can't be used is left out, never an error.
  """

  alias Cinder.Engine.Field
  alias Cinder.FilterManager

  @doc """
  The filters in a filter form's params (`%{"genre" => "rock", "price_min" =>
  "10"}`), as `Cinder.Engine.Query`'s `filters`: each filterable field's input
  as its filter type's value. Input a field's filter can't use is left out.
  """
  @spec filters_from_params(%{String.t() => term()}, [Field.t()]) :: %{String.t() => map()}
  def filters_from_params(params, fields) do
    FilterManager.params_to_filters(params, Enum.map(fields, &Field.to_column_map/1))
  end
end
