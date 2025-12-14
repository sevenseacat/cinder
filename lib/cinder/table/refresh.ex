defmodule Cinder.Table.Refresh do
  @moduledoc """
  Helper functions for refreshing Cinder collection data.

  **DEPRECATED**: This module has been moved to `Cinder.Refresh`.
  Please update your code to use `Cinder.Refresh` instead.

  ## Migration

      # OLD
      import Cinder.Table.Refresh
      refresh_table(socket, "my-table")

      # NEW
      import Cinder.Refresh
      refresh_table(socket, "my-table")

      # Or use top-level delegates
      Cinder.refresh_table(socket, "my-table")

  This module will be removed in version 1.0.
  """

  @deprecated "Use Cinder.Refresh.refresh_table/2 instead"
  defdelegate refresh_table(socket, table_id), to: Cinder.Refresh

  @deprecated "Use Cinder.Refresh.refresh_tables/2 instead"
  defdelegate refresh_tables(socket, table_ids), to: Cinder.Refresh
end
