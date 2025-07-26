# Changelog

## Unreleased

### Bug fixes

* Merge provided `filter_options` with default options for a column, instead of overwriting them

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
