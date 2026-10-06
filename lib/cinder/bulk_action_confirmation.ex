defmodule Cinder.BulkActionConfirmation do
  @moduledoc false

  @type context :: %{
          selected_ids: MapSet.t(),
          selected_count: non_neg_integer(),
          action: any()
        }

  @spec prepare(nil | (context() -> any()), context()) :: {:ok, any()} | {:error, any()}
  def prepare(nil, _context), do: {:ok, nil}

  def prepare(callback, context) when is_function(callback, 1) do
    try do
      callback.(context)
      |> normalize_result()
    rescue
      error -> {:error, Exception.message(error)}
    end
  end

  def prepare(_callback, _context) do
    {:error, "Invalid prepare_confirmation callback - must be a function/1"}
  end

  @spec normalize_result(any()) :: {:ok, any()} | {:error, any()}
  def normalize_result({:ok, _data} = success), do: success
  def normalize_result({:error, _reason} = error), do: error
  def normalize_result(:ok), do: {:ok, nil}
  def normalize_result(data), do: {:ok, data}
end
