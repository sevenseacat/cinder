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
          <th :for={column <- @view.columns} {column.attrs}>
            <%= if column.sortable? do %>
              <button {column.sort_attrs}>
                {column.label}<span {column.indicator_attrs}></span>
              </button>
            <% else %>
              {column.label}
            <% end %>
          </th>
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

  attr :pagination, :map, required: true

  def pagination(assigns) do
    ~H"""
    <nav {@pagination.attrs}>
      <span :if={@pagination.summary} data-part="summary">{@pagination.summary}</span>
      <button {@pagination.prev.attrs}>{@pagination.prev.label}</button>
      <%= for page <- @pagination.pages do %>
        <span :if={page.kind == :gap} {page.attrs}>{page.label}</span>
        <button :if={page.kind != :gap} {page.attrs}>{page.label}</button>
      <% end %>
      <button {@pagination.next.attrs}>{@pagination.next.label}</button>
    </nav>
    """
  end
end
