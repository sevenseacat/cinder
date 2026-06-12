defmodule Cinder.Tailwind do
  @moduledoc false

  # Shared paths and helpers used by Cinder's install and upgrade Mix tasks
  # to keep their Tailwind configuration in sync with `priv/cinder.css` and
  # `priv/themes/*.css`.

  @subdirs ~w(filter filters renderers table theme)

  @doc "Non-theme subdirs under lib/cinder/ that contain Tailwind classes."
  def subdirs, do: @subdirs

  @doc """
  Builds the v3 `content:` array entries for `tailwind.config.js`. Includes
  the matching theme `.ex` path when `theme_name` is a built-in theme name.
  """
  def v3_content_lines(theme_name) when is_binary(theme_name) or is_nil(theme_name) do
    base = [
      "../deps/cinder/lib/cinder.ex",
      "../deps/cinder/lib/cinder/*.ex"
      | Enum.map(@subdirs, &"../deps/cinder/lib/cinder/#{&1}/**/*.ex")
    ]

    theme_paths =
      if theme_name, do: ["../deps/cinder/lib/cinder/themes/#{theme_name}.ex"], else: []

    Enum.map_join(base ++ theme_paths, &"    \"#{&1}\",\n")
  end
end
