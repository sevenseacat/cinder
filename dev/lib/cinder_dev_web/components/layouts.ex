defmodule CinderDevWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use CinderDevWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  # Each page in the old shell, and its twin in the new one (`Cinder.Next`), with the
  # same collections as far as the new shell can render them
  @pages [
    {"/", "/next", "Table"},
    {"/filters", "/next/filters", "Filters"},
    {"/list", "/next/list", "List"},
    {"/grid", "/next/grid", "Grid"},
    {"/pagination", "/next/pagination", "Pagination"},
    {"/selection", "/next/selection", "Selection"},
    {"/controls", "/next/controls", "Controls"},
    {"/states", "/next/states", "States"}
  ]

  @doc "Every demo page, both shells', as `{path, label}`, for the smoke tests."
  def pages do
    for {old, new, label} <- @pages, page <- [{old, label}, {new, "#{label} (new)"}], do: page
  end

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :theme, :string, required: true, doc: "the Cinder theme in use"
  attr :current_path, :string, required: true
  attr :query_params, :map, required: true

  slot :inner_block, required: true

  def app(assigns) do
    pair = Enum.find(@pages, fn {old, new, _label} -> assigns.current_path in [old, new] end)
    assigns = assign(assigns, pages: @pages, pair: pair)

    ~H"""
    <%!-- Above the page: some Cinder themes give filter containers a z-index --%>
    <header class="navbar relative z-100 gap-4 px-4 sm:px-6 lg:px-8">
      <div class="flex flex-1 items-center gap-4">
        <span class="text-sm font-semibold">Cinder dev</span>
        <ul class="menu menu-horizontal">
          <li :for={{old, new, label} <- @pages}>
            <.link
              navigate={"#{old}?theme=#{@theme}"}
              class={@current_path in [old, new] && "menu-active"}
            >
              {label}
            </.link>
          </li>
        </ul>
      </div>
      <div class="flex flex-none items-center gap-4">
        <div :if={@pair} class="join">
          <.link
            :for={{path, shell} <- [{elem(@pair, 0), "Old"}, {elem(@pair, 1), "New"}]}
            navigate={"#{path}?theme=#{@theme}"}
            class={["btn btn-sm join-item", path == @current_path && "btn-active"]}
          >
            {shell}
          </.link>
        </div>
        <div class="dropdown dropdown-end">
          <div tabindex="0" role="button" class="btn btn-sm">Theme: {@theme}</div>
          <ul tabindex="0" class="dropdown-content menu z-10 w-48 rounded-box bg-base-100 shadow">
            <li :for={theme <- Cinder.Theme.presets()}>
              <.link patch={"?" <> Plug.Conn.Query.encode(Map.put(@query_params, "theme", theme))}>
                {theme}
              </.link>
            </li>
          </ul>
        </div>
        <.theme_toggle />
      </div>
    </header>

    <main class="px-4 py-10 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-7xl space-y-4">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  On a new-shell page, what its old-shell twin's collection does that this one
  can't yet, and what was changed on purpose. Each line goes when its feature lands.
  """
  attr :not_yet, :list, default: []
  attr :changed, :list, default: []

  def parity(assigns) do
    ~H"""
    <aside class="rounded-box border border-base-300 p-4 text-sm">
      <div :if={@not_yet != []}>
        <p class="font-semibold">Not yet</p>
        <ul class="list-disc pl-5">
          <li :for={item <- @not_yet}>{item}</li>
        </ul>
      </div>
      <div :if={@changed != []} class={@not_yet != [] && "mt-2"}>
        <p class="font-semibold">Changed on purpose</p>
        <ul class="list-disc pl-5">
          <li :for={item <- @changed}>{item}</li>
        </ul>
      </div>
    </aside>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={
          show(".phx-client-error #client-error")
          |> JS.remove_attribute("hidden", to: ".phx-client-error #client-error")
        }
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={
          show(".phx-server-error #server-error")
          |> JS.remove_attribute("hidden", to: ".phx-server-error #server-error")
        }
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 [[data-theme-source=system]_&]:!left-0 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
