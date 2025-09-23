# Theme Contributing

Cinder provides a comprehensive theming system that allows complete visual
customization of your tables. With 9 built-in themes and a powerful DSL for
creating custom themes, you can match any design system or create unique visual
experiences.

If you want to create a theme for everyone, and contribute it to the Cinder
repository, then you can use these steps to create it and contribute it.

## Get Cinder

Get the Cinder codebase by forking the Cinder repository or by cloning it.

## README

Edit file `README.md`.

Find this line:

```md
- **🎨 Advanced Theming**: 8 built-in themes (modern, retro, futuristic, dark, daisy_ui, flowbite, compact, pastel)
```

Increment the number and append your theme:

```md
- **🎨 Advanced Theming**: 9 built-in themes (modern, retro, futuristic, dark, daisy_ui, flowbite, compact, pastel, my_theme)
```

## Usage rules

Edit file `usage-rules.md`. 

Find this line:

```md
`theme="modern"` - built-in theme (default, modern, retro, futuristic, dark, daisy_ui, flowbite, compact, pastel)
```

Append your theme:

```md
`theme="modern"` - built-in theme (default, modern, retro, futuristic, dark, daisy_ui, flowbite, compact, pastel, my_theme)
```

## DSL module

Edit file `lib/cinder/theme/dsl_module.ex`

Find this section:

```elixir
:pastel ->
  Cinder.Themes.Pastel.resolve_theme()
```

Append your theme:

```elixir
:pastel ->
  Cinder.Themes.Pastel.resolve_theme()

:my_theme ->
  Cinder.Themes.MyTheme.resolve_theme()
```

## Theme

Edit file `lib/cinder/theme.ex`.

Find this section:

```elixir
def merge("pastel"),
  do:
    Cinder.Themes.Pastel.resolve_theme()
    |> apply_theme_property_mapping()
    |> apply_theme_data_attributes()
```

Append your theme

```elixir
def merge("pastel"),
  do:
    Cinder.Themes.Pastel.resolve_theme()
    |> apply_theme_property_mapping()
    |> apply_theme_data_attributes()

def merge("my_theme"),
  do:
    Cinder.Themes.MyTheme.resolve_theme()
    |> apply_theme_property_mapping()
    |> apply_theme_data_attributes()
```      

## my_theme.ex

Run:

```
cp lib/cinder/themes/pastel.ex lib/cinder/themes/my_theme.ex
```

Edit the file to customize it as you wish.

## CHANGELOG

Edit file `CHANGELOG.md`.

Add your new version:

```md
## v0.7.0 (2025-09-23)

## Features

* Add "smart" theme.

```

## mix.exs

Edit file `mix.exs`.

Find the current version such as:

```elixir
@version "0.6.1"
```

Increment to the next minor version such as:

```elixir
@version "0.7.0"
```

## Push

Commit your changes and push to your fork.

## Deps

In your own project, not in your Cinder fork, edit file `mix.exs`.

Find the current dep such as:

```exs
{:cinder, "~> 0.6.1"},
```

Change it to point to your new version and your new fork such as:

```exs
{:cinder, "~> 0.7.0",  git: "https://github.com/joelparkerhenderson/cinder"},
```

Get it working in your own app.

## Pull request

When you're satisfied, push your code to your fork, then create a pull request.
