# Localization

Cinder includes built-in translations for table UI elements (pagination, filtering, sorting controls).

## How It Works

Cinder ships with its own Gettext backend (`Cinder.Gettext`). When your Phoenix app sets a locale, Cinder automatically uses it:

```elixir
# In your app (e.g., in a plug or LiveView mount)
Gettext.put_locale("nl")  # Dutch

# Cinder tables automatically show Dutch UI text
```

No additional configuration needed!

## Available Translations

- **Brazilian Portuguese** (pt_BR)
- **Danish** (da)
- **Dutch** (nl)
- **English** (en) - Default
- **German** (de)
- **Norwegian** (no)
- **Swedish** (sv)

## Phoenix LiveView Example

```elixir
defmodule MyAppWeb.UserLive.Index do
  use MyAppWeb, :live_view

  def mount(_params, %{"locale" => locale}, socket) do
    Gettext.put_locale(locale)  # Set locale from session
    {:ok, socket}
  end
end
```

## Using Your App's Gettext Backend

By default, Cinder uses its own built-in Gettext backend. To override labels or provide your own translations, point Cinder at your app's backend:

```elixir
# config/config.exs
config :cinder, gettext_backend: MyAppWeb.Gettext
```

Then create a `cinder.po` file in your app's gettext directory. You only need to include the strings you want to change — anything missing falls back to the default English text:

```po
# priv/gettext/en/LC_MESSAGES/cinder.po
msgid "Filters"
msgstr "Filter"

msgid "Loading..."
msgstr "Please wait..."
```

For a full list of available strings, see `i18n/gettext/cinder.pot` in the Cinder source.

## Contributing Translations

1. Fork Cinder
2. Add `i18n/gettext/<locale>/LC_MESSAGES/cinder.po`
3. Translate messages from `i18n/gettext/cinder.pot`
4. Submit PR