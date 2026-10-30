<!--
SPDX-FileCopyrightText: 2025 Cinder contributors <https://github.com/sevenseacat/cinder/graphs/contributors>

SPDX-License-Identifier: MIT
-->

# Localization

Cinder's own text, like pagination, filter labels and buttons, comes translated into:

- Brazilian Portuguese (`pt_BR`)
- Danish (`da`)
- Dutch (`nl`)
- English (`en`), the default
- French (`fr`)
- German (`de`)
- Norwegian (`no`)
- Spanish (`es`)
- Swedish (`sv`)

## Choosing the Language

Cinder uses the current Gettext locale. Set it with `Gettext.put_locale/1`, which applies to
every Gettext backend, in the LiveView process: in `mount`, or an `on_mount` hook shared by your
LiveViews. A locale set in a plug doesn't reach the LiveView once it connects.

```elixir
defmodule MyAppWeb.UserLive.Index do
  use MyAppWeb, :live_view

  def mount(_params, session, socket) do
    Gettext.put_locale(session["locale"] || "en")
    {:ok, socket}
  end
end
```

## Changing the Language on a Mounted Page

Cinder translates its text as it renders, and LiveView only re-renders what depends on changed
assigns, so after a locale change on a mounted page some of Cinder's text stays in the old
language. Give the collection a new `id` when the locale changes, so it starts afresh:

```heex
<Cinder.collection id={"users-#{@locale}"} resource={MyApp.User}>
  <:col :let={user} field="name">{user.name}</:col>
</Cinder.collection>
```

The new collection starts on its first page with no filters, unless it uses URL sync, which
restores them from the URL.

## Using Your Own Translations

To change Cinder's text, or translate it into another language, point Cinder at your app's
Gettext backend:

```elixir
# config/config.exs
config :cinder, gettext_backend: MyAppWeb.Gettext
```

Cinder reads this when it's compiled, so recompile it after changing it:

```bash
mix deps.compile cinder --force
```

Then add a `cinder.po` file for each language to your app's Gettext directory, with the text you
want. `i18n/gettext/cinder.pot` in Cinder's source lists every string:

```po
# priv/gettext/en/LC_MESSAGES/cinder.po
msgid "Filters"
msgstr "Refine"

msgid "Loading..."
msgstr "Please wait..."
```

Your backend replaces Cinder's, so Cinder's own translations are no longer used: any string your
files don't translate shows in English, in every language. Copy Cinder's `.po` files for the
languages you support as a starting point.

## Contributing Translations

To add a language to Cinder itself:

1. Copy `i18n/gettext/cinder.pot` to `i18n/gettext/<locale>/LC_MESSAGES/cinder.po`.
2. Translate each `msgstr`.
3. Open a pull request.
