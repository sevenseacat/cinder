defmodule Cinder.Renderers.ColumnPrefs do
  @moduledoc """
  Renders the "Edit columns" control: a toggle button, a hydration hook,
  and a slide-in drawer with checkboxes + drag handles for show/hide and
  reorder of declared columns.

  Mounted by the table/list/grid renderers when `column_preferences?` is true.
  """

  use Phoenix.Component
  use Cinder.Messages

  attr(:id, :string, required: true, doc: "Cinder table id; used as localStorage key")
  attr(:myself, :any, required: true, doc: "LiveComponent CID for phx-target")

  attr(:enabled, :boolean,
    default: false,
    doc: "Master switch — equals @column_preferences? from the parent"
  )

  attr(:open?, :boolean, default: false, doc: "Whether the drawer is open")

  attr(:drawer_columns, :list,
    default: [],
    doc:
      "Columns to render in the drawer, in display order: visible columns in the user's preferred order followed by hidden columns at the end."
  )

  attr(:prefs, :map, required: true, doc: "Current %{order, hidden} preferences")
  attr(:theme, :map, required: true, doc: "Resolved theme map")

  def render(assigns) do
    ~H"""
    <div :if={@enabled}
         class={@theme.column_prefs_container_class}
         data-key="column_prefs_container_class">
      <div
        id={"#{@id}-column-prefs-hook"}
        phx-hook="CinderColumnPrefs"
        phx-target={@myself}
        data-cinder-table-id={@id}
        class="hidden"
      />

      <button
        type="button"
        phx-click="toggle_column_prefs_drawer"
        phx-target={@myself}
        class={@theme.column_prefs_button_class}
        data-key="column_prefs_button_class"
        aria-haspopup="dialog"
        aria-expanded={to_string(@open?)}
        title={dgettext("cinder", "Edit columns")}
      >
        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24"
             stroke-width="1.5" stroke="currentColor"
             class={@theme.column_prefs_button_icon_class}
             data-key="column_prefs_button_icon_class">
          <path stroke-linecap="round" stroke-linejoin="round"
                d="M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5" />
        </svg>
        <span>{dgettext("cinder", "Edit columns")}</span>
      </button>

      <div
        class={[
          @theme.column_prefs_backdrop_class,
          drawer_backdrop_state_class(@open?)
        ]}
        data-key="column_prefs_backdrop_class"
        phx-click="toggle_column_prefs_drawer"
        phx-target={@myself}
        aria-hidden="true"
      />

      <div class={[
             @theme.column_prefs_panel_class,
             drawer_panel_state_class(@open?)
           ]}
           data-key="column_prefs_panel_class"
           role="dialog"
           aria-modal={to_string(@open?)}
           aria-label={dgettext("cinder", "Edit columns")}
           inert={not @open?}>
          <div class={@theme.column_prefs_header_class}
               data-key="column_prefs_header_class">
            <h2 class={@theme.column_prefs_title_class}
                data-key="column_prefs_title_class">{dgettext("cinder", "Edit columns")}</h2>
            <button
              type="button"
              phx-click="toggle_column_prefs_drawer"
              phx-target={@myself}
              class={@theme.column_prefs_close_button_class}
              data-key="column_prefs_close_button_class"
              aria-label={dgettext("cinder", "Close")}
            >
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24"
                   stroke-width="1.5" stroke="currentColor"
                   class={@theme.column_prefs_close_icon_class}
                   data-key="column_prefs_close_icon_class">
                <path stroke-linecap="round" stroke-linejoin="round" d="M6 18 18 6M6 6l12 12" />
              </svg>
            </button>
          </div>

          <ul
            id={"#{@id}-column-prefs-list"}
            phx-hook="CinderColumnSortable"
            phx-target={@myself}
            data-cinder-table-id={@id}
            class={@theme.column_prefs_list_class}
            data-key="column_prefs_list_class"
          >
            <li
              :for={column <- @drawer_columns}
              data-field={column.field}
              data-reorderable={to_string(Map.get(column, :reorderable, true))}
              class={[
                @theme.column_prefs_item_class,
                Map.get(column, :reorderable, true) && @theme.column_prefs_item_reorderable_class,
                not Map.get(column, :reorderable, true) && @theme.column_prefs_item_pinned_class
              ]}
              data-key="column_prefs_item_class"
            >
              <span :if={Map.get(column, :reorderable, true)}
                    class={@theme.column_prefs_drag_handle_class}
                    data-key="column_prefs_drag_handle_class"
                    aria-hidden="true"
                    title={dgettext("cinder", "Drag to reorder")}>
                <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"
                     fill="currentColor"
                     class={@theme.column_prefs_drag_handle_icon_class}
                     data-key="column_prefs_drag_handle_icon_class">
                  <circle cx="9" cy="6" r="1.5" />
                  <circle cx="9" cy="12" r="1.5" />
                  <circle cx="9" cy="18" r="1.5" />
                  <circle cx="15" cy="6" r="1.5" />
                  <circle cx="15" cy="12" r="1.5" />
                  <circle cx="15" cy="18" r="1.5" />
                </svg>
              </span>
              <span :if={not Map.get(column, :reorderable, true)}
                    class={@theme.column_prefs_pinned_icon_class}
                    data-key="column_prefs_pinned_icon_class"
                    aria-hidden="true">
                <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"
                     fill="currentColor"
                     class={@theme.column_prefs_drag_handle_icon_class}
                     data-key="column_prefs_drag_handle_icon_class">
                  <path d="M12 2a3 3 0 0 0-3 3v3H6a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-9a2 2 0 0 0-2-2h-3V5a3 3 0 0 0-3-3zm-1 6V5a1 1 0 1 1 2 0v3h-2z" />
                </svg>
              </span>

              <input
                id={"#{@id}-prefs-cb-#{column.field}"}
                type="checkbox"
                checked={not MapSet.member?(@prefs.hidden, column.field)}
                disabled={not Map.get(column, :hideable, true)}
                phx-click="toggle_column_visibility"
                phx-value-field={column.field}
                phx-target={@myself}
                class={@theme.column_prefs_checkbox_class}
                data-key="column_prefs_checkbox_class"
              />

              <label for={"#{@id}-prefs-cb-#{column.field}"}
                     class={@theme.column_prefs_label_class}
                     data-key="column_prefs_label_class">{column.label}</label>
            </li>
          </ul>

          <div class={@theme.column_prefs_footer_class}
               data-key="column_prefs_footer_class">
            <button
              type="button"
              phx-click="reset_column_preferences"
              phx-target={@myself}
              class={@theme.column_prefs_reset_button_class}
              data-key="column_prefs_reset_button_class"
            >
              {dgettext("cinder", "Reset to defaults")}
            </button>
            <button
              type="button"
              phx-click="toggle_column_prefs_drawer"
              phx-target={@myself}
              class={@theme.column_prefs_done_button_class}
              data-key="column_prefs_done_button_class"
            >
              {dgettext("cinder", "Done")}
            </button>
          </div>
      </div>
    </div>
    """
  end

  defp drawer_panel_state_class(true), do: "translate-x-0"
  defp drawer_panel_state_class(false), do: "translate-x-full"

  defp drawer_backdrop_state_class(true), do: "opacity-100"
  defp drawer_backdrop_state_class(false), do: "opacity-0 pointer-events-none"
end
