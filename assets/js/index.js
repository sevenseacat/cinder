/**
 * Cinder LiveView hooks.
 *
 *   import { createCinderHooks } from "cinder"
 *   import Sortable from "sortablejs" // optional — needed for column drag-to-reorder
 *
 *   const liveSocket = new LiveSocket("/live", Socket, {
 *     hooks: { ...createCinderHooks({ Sortable }) }
 *   })
 *
 * Without `sortablejs`, column visibility and persistence still work; only
 * drag-to-reorder is disabled.
 */

const STORAGE_PREFIX = "cinder:column_prefs:";

/** Per-table localStorage I/O for column visibility and order. */
function createColumnPrefsHook() {
  return {
    mounted() {
      this.tableId = this.el.dataset.cinderTableId;
      this.storageKey = STORAGE_PREFIX + this.tableId;

      this.handleEvent("cinder:column_prefs_changed", (payload) => {
        if (!payload || payload.id !== this.tableId) return;
        this.writePrefs({ order: payload.order, hidden: payload.hidden });
      });

      const stored = this.readPrefs() || {};
      this.pushEventTo(this.el, "apply_column_preferences", stored);
    },

    readPrefs() {
      try {
        const raw = window.localStorage.getItem(this.storageKey);
        return raw ? JSON.parse(raw) : null;
      } catch (e) {
        console.warn("[cinder] failed to read column prefs", e);
        return null;
      }
    },

    writePrefs(prefs) {
      try {
        window.localStorage.setItem(this.storageKey, JSON.stringify(prefs));
      } catch (e) {
        console.warn("[cinder] failed to persist column prefs", e);
      }
    },
  };
}

/** SortableJS binding on the prefs drawer's column list. No-op without Sortable. */
function createColumnSortableHook(Sortable) {
  return {
    mounted() {
      if (!Sortable) return;
      this.sortable = Sortable.create(this.el, this.sortableOptions());
    },

    updated() {
      if (Sortable && !this.sortable) {
        this.sortable = Sortable.create(this.el, this.sortableOptions());
      }
    },

    sortableOptions() {
      return {
        animation: 150,
        filter: '[data-reorderable="false"], input',
        preventOnFilter: false,
        onEnd: () => this.pushOrder(),
      };
    },

    destroyed() {
      if (this.sortable) {
        this.sortable.destroy();
        this.sortable = null;
      }
    },

    pushOrder() {
      const order = Array.from(this.el.children)
        .filter((el) => el.dataset.reorderable !== "false")
        .map((el) => el.dataset.field)
        .filter(Boolean);

      this.pushEventTo(this.el, "reorder_columns", { order });
    },
  };
}

/** Pass `{ Sortable }` to enable drag-to-reorder. */
export function createCinderHooks({ Sortable } = {}) {
  return {
    CinderColumnPrefs: createColumnPrefsHook(),
    CinderColumnSortable: createColumnSortableHook(Sortable),
  };
}

export default createCinderHooks;
