defmodule Cinder.Next.Parts do
  @moduledoc """
  Spike: the new shell's default markup. Each part renders a view-model from
  `Cinder.Next.View`, marks itself with `data-part` and expresses state through
  attributes rather than classes, so it's styled by CSS.
  """
  use Phoenix.Component
  use Cinder.Messages

  alias Cinder.Next.View

  attr :view, :map, required: true

  def table(assigns) do
    ~H"""
    <table data-part="grid">
      <thead>
        <tr>
          <th :for={column <- @view.columns} {column.attrs}>{column.label}</th>
        </tr>
      </thead>
      <tbody>
        <tr :for={row <- @view.rows} {row.attrs}>
          <td :for={column <- @view.columns} data-part="cell" data-field={column.field}>
            <%= if column.slot[:inner_block] do %>
              {render_slot(column.slot, row.record)}
            <% else %>
              {View.field_value(row.record, column.field)}
            <% end %>
          </td>
        </tr>
        <tr :if={@view.rows == [] and @view.status == :idle} data-part="empty">
          <td colspan={length(@view.columns)}>{dgettext("cinder", "No results found")}</td>
        </tr>
        <tr :if={@view.status == :error} data-part="error">
          <td colspan={length(@view.columns)}>
            {dgettext("cinder", "An error occurred while loading data")}
          </td>
        </tr>
      </tbody>
    </table>
    """
  end
end
