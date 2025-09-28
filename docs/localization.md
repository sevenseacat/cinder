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

- **English** (en) - Default
- **Dutch** (nl) 
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

## Custom Backend (Optional)

If needed, you can use your app's Gettext backend:

```elixir
# config/config.exs
config :cinder, gettext_backend: MyAppWeb.Gettext
```

Note: Requires copying Cinder's translations to your app's `priv/gettext`.

## Contributing Translations

1. Fork Cinder
2. Add `i18n/gettext/<locale>/LC_MESSAGES/cinder.po`
3. Translate messages from `i18n/gettext/cinder.pot`
4. Submit PR