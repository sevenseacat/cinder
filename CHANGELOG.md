# Changelog

## Unreleased 

### Features

* Add in-memory item updates for efficient PubSub-driven changes without re-querying the entire table (#77)
  * `update_item/4` and `update_items/4` for direct updates
  * `update_if_visible/4` and `update_items_if_visible/4` for lazy loading patterns

### Bug fixes 

* Fix sort indicators not displaying for embedded field default sorts (#83)
* Raise helpful error for invalid filter types instead of silently falling back to text filter
* Fix custom `fn` attribute on filter-only slots not being passed to QueryBuilder
* Pass the full provided scope to `Ash.read` when running queries (#71)
* Fix table reloading data unnecessarily when parent LiveView re-renders with unchanged state

## v0.9.0-beta.2 (2025-12-16)

### Features 

* Add keyset pagination support via `pagination="keyset"` for better performance on large datasets (#15)
* Allow filters for non-existent fields when a custom `filter_fn` is attached
* Add basic `autocomplete` filter type, for searchable dropdowns with large preloaded option lists

## v0.9.0-beta.1 (2025-12-15)

### Features

* Add unified `Cinder.collection` component supporting table, list, and grid layouts (#9)

### Deprecations

* `Cinder.Table.table` is deprecated in favor of `Cinder.collection`
* `Cinder.Table.UrlSync` and `Cinder.Table.Refresh` are deprecated in favor of `Cinder.UrlSync` and `Cinder.Refresh`

See the [Upgrading Guide](docs/upgrading.md) for migration instructions.

## v0.8.1 (2025-12-04)

### Bug fixes 

* Fix page size resetting to default when parent LiveView re-renders - user-selected page size now persists across parent state changes
* Fix filters section not showing automatically when search is enabled but no filterable columns exist (#70)

## v0.8.0 (2025-11-08)

### Features

* Add i18n support with gettext (#53)

### Bug fixes

* Fix URL sync overwriting existing query parameters instead of merging them - custom query parameters (like `?tab=overview`) are now preserved when table state changes while allowing filters to be properly cleared (#67)
* Fix custom theme extension with `extends` by using `Code.ensure_loaded/1` to load modules before checking for `resolve_theme/0` (#64)
* Use existing `filter_placeholder_class` theme key for selects/multiselects when no value is selected

## v0.7.2 (2025-09-30)

### Bug fixes

* Fix date range filters not converting end dates to end-of-day for datetime fields, causing records on the end date to be excluded
* Fix filter forms using browser submit when the enter key is pressed (#65)

## v0.7.1 (2025-09-28)

### Bug fixes

* Fix filter-only slots not receiving `options` attribute, causing select filters to show "No options available"
* Ensure that field names have special characters stripped before being used in HTML attributes (#62)
* Remove double-processing of select/multi-select options and ensure that falsy values are still processed (#63)

## v0.7.0 (2025-09-24)

### Features

* Add filter-only slots for filtering on fields without displaying them as columns (#34)

### Changes

* Remove "All" option from boolean filters - this is equivalent to clearing the filter
* Use labels when generating options from `Ash.Type.Enum` modules, instead of descriptions (#35)

### Bug fixes

* Fix checkbox filters in filter-only slots not applying on first click when URL sync is enabled
* Fix sorting regression where sort-only columns were not sortable via URL parameters
* Fix aggregate field type inference using wrong property name (aggregates now correctly infer as `:number_range` instead of `:text`)
* Fix `show_filters` option not being respected when rendering table (#56)
* Fix search parameter not being stored in the socket after being decoded (#54)

## v0.6.1 (2025-09-05)

### Features

* Add custom prompt support for multi-select filters

### Bug fixes

* Fix filter type inference for relationship attributes
* Fix unified filter options to default to auto-inference when no type is specified
* Fix atoms in Enum modules generating missing labels in filters (#52)
* Fix embedded field sorting using calc expressions (#51)
* Don't empty data when refreshing tables, to prevent flickering (#48)

## v0.6.0 (2025-08-26)

### Features

* Allow custom filter functions to be defined for a column
* Allow custom sort cycles to be defined for a column
* Allow searching multiple fields in a table at once, with a new `search` config option on tables and columns (#40)

### Bug fixes

* Fix URL sync double processing causing duplicate data loads on sort/filter events
* Fix table refresh error when page_size on a table is set to a number (not a map of data) (#45)
* Fix table refresh resetting current sort/search state
* Add warning when table has pagination configured but Ash action lacks pagination support

## v0.5.5 (2025-08-14)

### Bug fixes

* Fix field validation for embedded fields using underscore notation (e.g., `profile__first_name`)

## v0.5.4 (2025-08-11)

### Features

* Support configurable page sizes with dropdown selector
  * Use `page_size={25}` for fixed page sizes (existing behaviour), or `page_size={[default: 25, options: [10, 25, 50, 100]]}` for user-selectable page sizes
* Support unified filter API with options in single parameter (`filter={[type: :select, options: [...]]}`)
  * Legacy `filter_options` parameter logs a deprecation warning, and will be removed in v1.0

### Chores

* Support string format for filter types (e.g., `filter="select"` in addition to `filter={:select}`)

## v0.5.3 (2025-08-07)

### Bug fixes

* Fix `query` not preserving filters/sorts when using `Ash.Query.filter(Resource, ...)` pattern (#36)
* Ensure query tenant context is properly recognized

## v0.5.2 (2025-08-06)

### Bug fixes

* Log warnings about invalid column config in all environments, at the `info` log level

## v0.5.1 (2025-08-03)

### Features

* Allow `🔍 Filters` text to be customized via new `filters_label` table assign (#26)
* Set up the "modern" theme by default (#27)

### Bug fixes

* Merge provided `filter_options` with default options for a column, instead of overwriting them
* Fix slight input jumping issues across all themes and duplicate select arrows from DaisyUI theme
* Load all records for actions without pagination configured, showing a performance warning message
* Fix crashes when attempting to sort or filter by invalid fields, such as in-memory calculations or non-existent attributes (#32)

### Chores

* Replace native select boxes with custom HTML implementation for better customizability
* Add `cinder` to the `import_deps` list for custom formatting, on installation
* Use the provided `empty_message` and `loading_message` when rendering the table (#25)

## v0.5.0 (2025-07-26)

### Features

* Add `match_mode` option to multi-select and multi-checkboxes filters for array fields

### Bug fixes

* Fix compilation issue caused by other libraries redefining the `uuid` shortcode (#17)
* Cast all string-like fields to string before using them in queries. (#8)
* Filters for array fields should be `filter_val in field_name`, not `field_name in filter_val`, eg. `"suspense" in tags`

## v0.4.0 (2025-06-27)

### Features

* Support working with embedded attributes via a new `__` notation
* Add action column support - columns can now omit the `field` attribute to create action columns with buttons, links, and other interactive elements
* Add `Cinder.Table.Refresh` to refresh table data while maintaining filters, sorting, and pagination state

### Bug fixes

* Fix multiselect dropdowns not being visible outside the filter container
* Allow table sorting to override predefined sorts on a provided query

## v0.3.0 (2025-06-23)

### Features

* Add `row_click` option for `Cinder.Table.table`, to make entire rows clickable
* Support `scope` and `tenant` options to `Cinder.Table.table`
  * `tenant` can also be passed in as part of the `query_opts` option
* Support `timeout`, `authorize?`, and `max_concurrency` options in `query_opts`

### Bug fixes

* Tweaked layout of filters to avoid overlapping input content

## v0.2.1 (2025-06-19)

### Features

* Default to `date_range` fields for all datetime-related types

### Bug fixes

* Prevent crashing when an error occurs while loading table data - the error will be properly logged instead
* Fix errors when attempting to filter on `NaiveDatetime` attribute

## v0.2.0 (2025-06-18)

### Features

* Allow a default theme to be specified for all tables, in application config (eg. `config :cinder, default_theme: "dark"`)
* Reorder arguments to `UrlSync.handle_params` to be consistent with LiveView's `handle_params`
  * Replace `Cinder.Table.UrlSync.handle_params(socket, params, url)` with `Cinder.Table.UrlSync.handle_params(params, uri, socket)`

## v0.1.1 (2025-06-16)

### Bug fixes

* Fix bug where invalid sorts would sometimes raise `(Protocol.UndefinedError) protocol String.Chars not implemented for type Ash.Query (a struct)`
* Fix incorrect environment specification for `sourcerer` and `igniter` dependencies - these should only ever be installed in `dev` and `test`
* Fix styling of table row borders in `flowbite` theme (light mode)

## v0.1.0 (2025-06-15)

* Initial release
