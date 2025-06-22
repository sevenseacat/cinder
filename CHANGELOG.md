# Changelog

## Unreleased

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
