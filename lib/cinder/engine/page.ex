# SPDX-FileCopyrightText: 2026 Cinder contributors <https://github.com/sevenseacat/cinder/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Cinder.Engine.Page do
  @moduledoc false
  # A page of records from `Cinder.Engine.run/4`, the same shape for offset,
  # keyset and unpaginated reads.
  #
  #   * `page` - the page number for offset pagination, `nil` otherwise
  #   * `page_size` - `nil` when the action isn't paginated
  #   * `count` - `nil` when the records weren't counted
  #   * `more?` and `previous?` - whether there's a next and a previous page
  #   * `first_cursor` and `last_cursor` - for keyset pagination, the first and
  #     last records' cursors: the next page is `{:after, last_cursor}`, and the
  #     previous one `{:before, first_cursor}`. `nil` otherwise, or when empty.

  @type t :: %__MODULE__{
          records: [Ash.Resource.Record.t()],
          page: pos_integer() | nil,
          page_size: pos_integer() | nil,
          count: non_neg_integer() | nil,
          more?: boolean(),
          previous?: boolean(),
          first_cursor: String.t() | nil,
          last_cursor: String.t() | nil
        }

  defstruct records: [],
            page: nil,
            page_size: nil,
            count: nil,
            more?: false,
            previous?: false,
            first_cursor: nil,
            last_cursor: nil
end
