defmodule Cinder.ColumnPrefsRenderTest do
  @moduledoc """
  Render-level tests for the column-prefs drawer UI.

  Hits two layers:
    * `Cinder.Renderers.ColumnPrefs.render/1` directly — for the drawer content
      that depends on internal `open?` state we can't reach through the public
      collection component without a full LV mount.
    * `Cinder.Collection.collection/1` via `render_component` — for the
      "Edit columns" button being present (or absent) based on the public attrs.
  """

  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  alias Cinder.{ColumnPreferences, Theme}
  alias Cinder.Renderers.ColumnPrefs

  defmodule TestUser do
    use Ash.Resource,
      domain: nil,
      data_layer: Ash.DataLayer.Ets,
      validate_domain_inclusion?: false

    ets do
      private?(true)
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string)
      attribute(:email, :string)
      attribute(:archived_at, :utc_datetime)
    end

    actions do
      defaults([:create, :read, :update, :destroy])
    end
  end

  defp col(field, opts \\ []) do
    %{
      field: field,
      label: Keyword.get(opts, :label, field),
      hideable: Keyword.get(opts, :hideable, true),
      reorderable: Keyword.get(opts, :reorderable, true),
      default_visible: Keyword.get(opts, :default_visible, true),
      filterable: false,
      sortable: false,
      class: ""
    }
  end

  describe "ColumnPrefs.render/1 — closed drawer" do
    test "renders the toggle button and the hydration hook" do
      assigns = %{
        id: "users",
        myself: 1,
        theme: Theme.default(),
        enabled: true,
        open?: false,
        drawer_columns: [col("name"), col("email")],
        prefs: ColumnPreferences.empty()
      }

      html = render_component(&ColumnPrefs.render/1, assigns)

      assert html =~ "users-column-prefs-hook"
      assert html =~ ~s(phx-hook="CinderColumnPrefs")
      assert html =~ "Edit columns"
      assert html =~ ~s(phx-click="toggle_column_prefs_drawer")

      assert html =~ ~s(data-key="column_prefs_panel_class")
      assert html =~ "translate-x-full"
      refute html =~ "translate-x-0"
      assert html =~ ~s(aria-modal="false")
      assert html =~ "inert"

      assert html =~ "opacity-0"
      assert html =~ "pointer-events-none"
    end

    test "open drawer drops translate-x-full and gains aria-modal=true" do
      assigns = %{
        id: "users",
        myself: 1,
        theme: Theme.default(),
        enabled: true,
        open?: true,
        drawer_columns: [col("name")],
        prefs: ColumnPreferences.empty()
      }

      html = render_component(&ColumnPrefs.render/1, assigns)

      assert html =~ "translate-x-0"
      refute html =~ "translate-x-full"
      assert html =~ ~s(aria-modal="true")
      refute html =~ ~r/\sinert(=|\s|>)/
    end

    test "renders nothing when disabled" do
      assigns = %{
        id: "users",
        myself: 1,
        theme: Theme.default(),
        enabled: false,
        open?: false,
        drawer_columns: [col("name")],
        prefs: ColumnPreferences.empty()
      }

      html = render_component(&ColumnPrefs.render/1, assigns)

      refute html =~ "Edit columns"
      refute html =~ "users-column-prefs-hook"
    end

    test "honors theme classes" do
      theme =
        Theme.default()
        |> Map.put(:column_prefs_button_class, "custom-prefs-btn-xyz")

      assigns = %{
        id: "users",
        myself: 1,
        theme: theme,
        enabled: true,
        open?: false,
        drawer_columns: [col("name")],
        prefs: ColumnPreferences.empty()
      }

      html = render_component(&ColumnPrefs.render/1, assigns)

      assert html =~ "custom-prefs-btn-xyz"
      assert html =~ ~s(data-key="column_prefs_button_class")
    end
  end

  describe "ColumnPrefs.render/1 — open drawer" do
    test "renders one row per declared column with its label" do
      assigns = %{
        id: "users",
        myself: 1,
        theme: Theme.default(),
        enabled: true,
        open?: true,
        drawer_columns: [col("name", label: "Name"), col("email", label: "Email")],
        prefs: ColumnPreferences.empty()
      }

      html = render_component(&ColumnPrefs.render/1, assigns)

      assert html =~ "users-column-prefs-list"
      assert html =~ ~s(phx-hook="CinderColumnSortable")
      assert html =~ ~s(data-field="name")
      assert html =~ ~s(data-field="email")
      assert html =~ "Reset to defaults"
      assert html =~ "Done"
    end

    test "checkbox is unchecked for hidden columns and disabled for non-hideable ones" do
      hidden_prefs = %{order: nil, hidden: MapSet.new(["email"])}

      assigns = %{
        id: "users",
        myself: 1,
        theme: Theme.default(),
        enabled: true,
        open?: true,
        drawer_columns: [col("id", hideable: false), col("name"), col("email")],
        prefs: hidden_prefs
      }

      html = render_component(&ColumnPrefs.render/1, assigns)

      [id_row] = Regex.run(~r/<li[^>]*data-field="id"[\s\S]*?<\/li>/, html)
      [name_row] = Regex.run(~r/<li[^>]*data-field="name"[\s\S]*?<\/li>/, html)
      [email_row] = Regex.run(~r/<li[^>]*data-field="email"[\s\S]*?<\/li>/, html)

      assert Regex.match?(~r/<input[^>]*\schecked[\s>]/, id_row)
      assert Regex.match?(~r/<input[^>]*\sdisabled[\s>]/, id_row)

      assert Regex.match?(~r/<input[^>]*\schecked[\s>]/, name_row)
      refute Regex.match?(~r/<input[^>]*\sdisabled[\s>]/, name_row)

      refute Regex.match?(~r/<input[^>]*\schecked[\s>]/, email_row)
    end

    test "non-reorderable columns get the pinned indicator and no drag handle" do
      assigns = %{
        id: "users",
        myself: 1,
        theme: Theme.default(),
        enabled: true,
        open?: true,
        drawer_columns: [col("name"), col("actions", reorderable: false)],
        prefs: ColumnPreferences.empty()
      }

      html = render_component(&ColumnPrefs.render/1, assigns)

      [name_row] = Regex.run(~r/<li[^>]*data-field="name"[\s\S]*?<\/li>/, html)
      [actions_row] = Regex.run(~r/<li[^>]*data-field="actions"[\s\S]*?<\/li>/, html)

      assert name_row =~ ~s(data-reorderable="true")
      assert name_row =~ "cinder-drag-handle"

      assert actions_row =~ ~s(data-reorderable="false")
      refute actions_row =~ "cinder-drag-handle"
    end
  end

  describe "Cinder.collection — public surface" do
    test "renders the Edit columns button when column_preferences? is true" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        id: "users-table",
        column_preferences?: true,
        col: [
          %{field: "name", __slot__: :col},
          %{field: "email", __slot__: :col}
        ]
      }

      html = render_component(&Cinder.Collection.collection/1, assigns)

      assert html =~ "Edit columns"
      assert html =~ "users-table-column-prefs-hook"
    end

    test "does not render the button when column_preferences? is false (default)" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        id: "users-table",
        col: [
          %{field: "name", __slot__: :col}
        ]
      }

      html = render_component(&Cinder.Collection.collection/1, assigns)

      refute html =~ ~s(phx-click="toggle_column_prefs_drawer")
      refute html =~ "column-prefs-hook"
    end

    test "table_wrapper gets `invisible` until prefs are hydrated, then drops it" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        id: "users-table",
        column_preferences?: true,
        col: [%{field: "name", __slot__: :col}]
      }

      html = render_component(&Cinder.Collection.collection/1, assigns)

      assert html =~ ~r/data-key="table_wrapper_class"[^>]*invisible/ or
               html =~ ~r/invisible[^"]*"\s+data-key="table_wrapper_class"/
    end

    test "wrapper has no `invisible` class when prefs are disabled" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        id: "users-table",
        col: [%{field: "name", __slot__: :col}]
      }

      html = render_component(&Cinder.Collection.collection/1, assigns)

      refute html =~ ~r/data-key="table_wrapper_class"[^>]*invisible/
      refute html =~ ~r/invisible[^"]*"\s+data-key="table_wrapper_class"/
    end

    test "default_visible: false columns are hidden in the table headers from the start" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        id: "users-table",
        column_preferences?: true,
        col: [
          %{field: "name", label: "Name", __slot__: :col},
          %{field: "archived_at", label: "Archived At", default_visible: false, __slot__: :col}
        ]
      }

      html = render_component(&Cinder.Collection.collection/1, assigns)

      assert html =~ ~r/<th[^>]*>[\s\S]*?Name[\s\S]*?<\/th>/
      refute html =~ ~r/<th[^>]*>[\s\S]*?Archived At[\s\S]*?<\/th>/
      assert html =~ ~r/<li[^>]*data-field="archived_at"/
    end
  end
end
