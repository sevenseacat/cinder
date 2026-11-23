defmodule Cinder.FilterBar do
  @moduledoc """
  The filter layout for `show_filters: :bar`: every filter is a pill with its
  label inside and its value beside it, and opens a dropdown to change it.

  Up to three filters every pill is always shown. Above that, only the pills of
  filters in use are, and the rest wait behind a "Filter" menu — the job the
  "Edit filters" drawer does for the row layout, which the bar leaves out.

  A filter declared `filter_default_visible: false` is never offered — not as a
  pill, not in the menu — and shows only once something (a link, the URL) sets
  it: the place for filters a page is reached through rather than one picked.

  Every filter's inputs stay in Cinder's form, inside its (hidden) dropdown, so
  the bar submits the params the row would and URL sync, state storage and
  query building are untouched.

  Selects and multi-selects get a list of options in the dropdown — with a
  search field above it once the list is longer than the dropdown shows, which
  narrows the list in the browser without leaving any option out; date and date
  range filters get relative shortcuts ("Last week") above their inputs, which
  the browser resolves to fixed dates in the reader's own calendar, so a URL
  keeps meaning the days it was made on. Every other type, custom filters
  included, renders its own input inside the dropdown.

  A filter module that declares `inline?/0` renders its own input straight in
  the bar, inside a pill beside its label: no dropdown, never in the menu. Every
  input the bar renders gets `in_bar?: true` among its assigns, so a filter can
  size its control to sit inside a pill.

  Dates in a pill render as `<time datetime="…" data-precision="day_month">`
  with the ISO date as text, for the host app's script to format.
  """

  use Phoenix.Component
  use Cinder.Messages

  alias Cinder.Filters.Registry
  alias Phoenix.LiveView.JS

  @always_shown 3

  # About as many options as the dropdown shows before it scrolls.
  @searchable_from 10

  @date_ranges ~w(today yesterday tomorrow this_week last_week past_7_days this_month last_month past_30_days)
  @single_dates ~w(today yesterday tomorrow)

  attr :controls, :map, required: true

  def render(assigns) do
    {inline, filters} =
      assigns.controls.filters
      |> Enum.map(fn {_key, filter} -> filter end)
      |> Enum.split_with(&inline?/1)

    all_shown? = Enum.count(filters, &offered?/1) <= @always_shown

    assigns =
      assign(assigns,
        bar_id: "#{assigns.controls.table_id}-filter-bar",
        theme: assigns.controls.theme,
        filters: filters,
        inline: Enum.filter(inline, &(offered?(&1) or active?(&1))),
        all_shown?: all_shown?,
        in_menu:
          if(all_shown?, do: [], else: Enum.filter(filters, &(offered?(&1) and not active?(&1))))
      )

    ~H"""
    <div id={@bar_id} class={[@theme.filter_bar_class, "relative"]} data-key="filter_bar_class" phx-hook=".FilterBar">
      <script :type={Phoenix.LiveView.ColocatedHook} name=".FilterBar">
        const pad = (n) => String(n).padStart(2, "0")
        const iso = (d) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`
        const plus = (d, days) => new Date(d.getFullYear(), d.getMonth(), d.getDate() + days)

        function range(name, today) {
          const monday = plus(today, -((today.getDay() + 6) % 7))
          const month = new Date(today.getFullYear(), today.getMonth(), 1)
          switch (name) {
            case "today": return [today, today]
            case "yesterday": return [plus(today, -1), plus(today, -1)]
            case "tomorrow": return [plus(today, 1), plus(today, 1)]
            case "this_week": return [monday, plus(monday, 6)]
            case "last_week": return [plus(monday, -7), plus(monday, -1)]
            case "past_7_days": return [plus(today, -6), today]
            case "this_month": return [month, new Date(today.getFullYear(), today.getMonth() + 1, 0)]
            case "last_month": return [new Date(today.getFullYear(), today.getMonth() - 1, 1), plus(month, -1)]
            case "past_30_days": return [plus(today, -29), today]
          }
        }

        export default {
          mounted() {
            this.open = null
            this.beside = null
            this.terms = {}
            this.held = false
            this.onClick = (event) => this.click(event)
            this.onHover = (event) => {
              const item = event.target.closest("[data-bar-submenu]")
              if (item && item !== this.beside) this.showBeside(item)
            }
            this.onKey = (event) => {
              if (event.key !== "Escape") return
              this.close()
              this.hideMenu()
            }
            this.onOutside = (event) => {
              const target = event.target
              if (this.open?.contains(target) || this.anchor()?.contains(target)) return
              if (this.menu()?.parentElement.contains(target)) return
              this.close()
              this.hideMenu()
            }
            this.el.addEventListener("click", this.onClick)
            this.el.addEventListener("mouseover", this.onHover)
            this.el.addEventListener("change", (event) => {
              if (event.target.type !== "radio" && !event.target.closest("[data-close-on-pick]")) return
              this.close()
              this.hideMenu()
            })
            this.el.addEventListener("input", (event) => {
              if (!event.target.matches("[data-bar-option-search]")) return
              this.terms[event.target.closest("[data-bar-dropdown]").id] = event.target.value
              this.narrow(event.target)
            })
            this.el.addEventListener("mouseleave", (event) => {
              if (!this.held || event.target !== this.open) return
              this.held = false
              this.position()
            }, true)
            document.addEventListener("keydown", this.onKey)
            document.addEventListener("mousedown", this.onOutside)
            this.updated()
          },
          updated() {
            this.el.querySelectorAll("[data-bar-dropdown]").forEach((el) => this.js().ignoreAttributes(el, ["style"]))
            this.el.querySelectorAll("[data-bar-pill]").forEach((el) => this.js().ignoreAttributes(el, ["data-open"]))
            this.markChosen()
            // A patch empties the search once picking an option took its focus, and redraws what it hid
            this.el.querySelectorAll("[data-bar-option-search]").forEach((input) => {
              input.value = this.terms[input.closest("[data-bar-dropdown]").id] ?? ""
              this.narrow(input)
            })
            if (!this.open) return
            // A value picked from the menu takes its filter out of it: the dropdown moves under the new pill,
            // but only once the mouse leaves it, so the option just picked doesn't jump away from the pointer
            if (this.beside && !this.beside.isConnected) {
              this.beside = null
              this.hideMenu()
              this.anchor()?.setAttribute("data-open", "")
              this.held = true
            }
            if (!this.held) this.position()
          },
          destroyed() {
            document.removeEventListener("keydown", this.onKey)
            document.removeEventListener("mousedown", this.onOutside)
          },
          click(event) {
            const item = event.target.closest("[data-bar-submenu]")
            if (item) return this.showBeside(item, true)
            if (event.target.closest(`#${this.el.id}-add`)) return this.close()
            const opener = event.target.closest("[data-bar-open]")
            if (opener) {
              this.hideMenu()
              const dropdown = document.getElementById(opener.dataset.barOpen)
              return dropdown === this.open ? this.close() : this.show(dropdown)
            }
            const shortcut = event.target.closest("[data-cinder-range]")
            if (shortcut) this.pickRange(shortcut)
          },
          menu() {
            return this.el.querySelector("[data-bar-menu]")
          },
          hideMenu() {
            const menu = this.menu()
            if (menu) this.js().hide(menu)
          },
          anchor() {
            return this.open && document.getElementById(this.open.dataset.pill)
          },
          show(dropdown) {
            this.close()
            this.open = dropdown
            this.anchor()?.setAttribute("data-open", "")
            this.js().show(dropdown)
            this.position()
            this.focusSearch()
          },
          showBeside(item, focus = false) {
            if (this.open && this.beside === item) return focus && this.focusSearch()
            this.close()
            this.open = document.getElementById(item.dataset.barSubmenu)
            this.beside = item
            this.js().show(this.open)
            this.position()
            if (focus) this.focusSearch()
          },
          focusSearch() {
            this.open?.querySelector("[data-bar-option-search]")?.focus()
          },
          narrow(input) {
            const dropdown = input.closest("[data-bar-dropdown]")
            const term = input.value.trim().toLowerCase()
            let any = false
            dropdown.querySelectorAll("[data-bar-option]").forEach((option) => {
              const match = term === "" || option.textContent.toLowerCase().includes(term)
              option.style.display = match ? "" : "none"
              any = any || match
            })
            const none = dropdown.querySelector("[data-bar-no-match]")
            if (none) none.style.display = any ? "none" : ""
          },
          close() {
            if (!this.open) return
            delete this.terms[this.open.id]
            this.open.querySelectorAll("[data-bar-option-search]").forEach((input) => {
              input.value = ""
              this.narrow(input)
            })
            this.anchor()?.removeAttribute("data-open")
            this.js().hide(this.open)
            this.open = null
            this.beside = null
            this.held = false
          },
          position() {
            const bar = this.el.getBoundingClientRect()
            const width = this.open.offsetWidth
            if (this.beside) {
              const menu = this.menu().getBoundingClientRect()
              const room = document.documentElement.clientWidth - menu.right - 4
              const left = room >= width ? menu.right + 4 : menu.left - 4 - width
              this.open.style.left = `${left - bar.left}px`
              this.open.style.top = `${this.beside.getBoundingClientRect().top - bar.top}px`
              return
            }
            const pill = this.anchor()
            if (!pill) return
            const at = pill.getBoundingClientRect()
            this.open.style.left = `${Math.max(0, Math.min(at.left - bar.left, bar.width - width))}px`
            this.open.style.top = `${at.bottom - bar.top + 4}px`
          },
          dateInputs(dropdown) {
            return [...dropdown.querySelectorAll("input[type=date], input[type=datetime-local]")]
          },
          pickRange(shortcut) {
            const dropdown = shortcut.closest("[data-bar-dropdown]")
            const [from, to] = range(shortcut.dataset.cinderRange, new Date())
            const inputs = this.dateInputs(dropdown)
            const values = inputs.length === 1 ? [from] : [from, to]
            inputs.forEach((input, i) => {
              const day = iso(values[i])
              input.value = input.type === "date" ? day : `${day}T${i === 0 ? "00:00" : "23:59"}`
            })
            inputs.at(-1)?.dispatchEvent(new Event("input", { bubbles: true }))
            this.close()
          },
          markChosen() {
            const today = new Date()
            this.el.querySelectorAll("[data-bar-dropdown]").forEach((dropdown) => {
              const held = this.dateInputs(dropdown).map((input) => input.value.slice(0, 10))
              dropdown.querySelectorAll("[data-cinder-range]").forEach((shortcut) => {
                const days = range(shortcut.dataset.cinderRange, today).map(iso).slice(0, held.length)
                const chosen = held.length > 0 && held.every((day, i) => day === days[i])
                shortcut.toggleAttribute("data-chosen", chosen)
              })
            })
          }
        }
      </script>

      <.search :if={@controls.search} search={@controls.search} theme={@theme} target={@controls.target} />

      <.pill
        :for={filter <- @filters}
        filter={filter}
        bar_id={@bar_id}
        theme={@theme}
        target={@controls.target}
        always_shown?={@all_shown? and offered?(filter)}
      />

      <div
        :for={filter <- @inline}
        class={@theme.filter_bar_inline_class}
        data-key="filter_bar_inline_class"
        data-active={active?(filter)}
      >
        <span class={@theme.filter_bar_pill_label_class} data-key="filter_bar_pill_label_class">{filter.label}</span>
        <.own_input filter={filter} controls={@controls} />
      </div>

      <div :if={@in_menu != []} class="relative">
        <button
          type="button"
          id={"#{@bar_id}-add"}
          class={@theme.filter_bar_add_class}
          data-key="filter_bar_add_class"
          phx-click={JS.toggle(to: "##{@bar_id}-menu")}
          aria-haspopup="menu"
        >
          <.icon name={:plus} class={@theme.filter_bar_icon_class} />
          {dgettext("cinder", "Filter")}
        </button>
        <div id={"#{@bar_id}-menu"} class={[@theme.filter_bar_menu_class, "hidden"]} data-key="filter_bar_menu_class" data-bar-menu role="menu">
          <button
            :for={filter <- @in_menu}
            type="button"
            role="menuitem"
            id={"#{dropdown_id(@bar_id, filter)}-item"}
            class={@theme.filter_bar_menu_item_class}
            data-key="filter_bar_menu_item_class"
            data-bar-submenu={dropdown_id(@bar_id, filter)}
            aria-haspopup="dialog"
          >
            {filter.label}
            <.icon name={:chevron_right} class={@theme.filter_bar_icon_class} />
          </button>
        </div>
      </div>

      <div class="flex flex-1 justify-end">
        <Cinder.Controls.render_clear_all
          active_filter_count={@controls.active_filter_count}
          theme={@theme}
          target={@controls.target}
        />
      </div>

      <.dropdown :for={filter <- @filters} filter={filter} bar_id={@bar_id} controls={@controls} />
    </div>
    """
  end

  attr :search, :map, required: true
  attr :theme, :map, required: true
  attr :target, :any, required: true

  defp search(assigns) do
    ~H"""
    <label class={@theme.filter_bar_search_class} data-key="filter_bar_search_class">
      <svg class={@theme.search_icon_class} data-key="search_icon_class" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
      </svg>
      <input
        type="text"
        id={@search.id}
        name={@search.name}
        value={@search.value}
        placeholder={@search.placeholder}
        aria-label={@search.label}
        phx-debounce="300"
        class={@theme.filter_bar_search_input_class}
        data-key="filter_bar_search_input_class"
      />
      <button
        :if={@search.value != ""}
        type="button"
        phx-click="clear_filter"
        phx-value-key="search"
        phx-target={@target}
        aria-label={dgettext("cinder", "Clear search")}
      >
        <.icon name={:x} class={@theme.filter_bar_icon_class} />
      </button>
    </label>
    """
  end

  attr :filter, :map, required: true
  attr :bar_id, :string, required: true
  attr :theme, :map, required: true
  attr :target, :any, required: true
  attr :always_shown?, :boolean, required: true

  defp pill(assigns) do
    assigns = assign(assigns, :active?, active?(assigns.filter))

    ~H"""
    <div
      id={pill_id(@bar_id, @filter)}
      class={[@theme.filter_bar_pill_class, not @always_shown? and "[&[data-hidden]:not([data-open])]:hidden"]}
      data-key="filter_bar_pill_class"
      data-bar-pill
      data-active={@active?}
      data-hidden={not @always_shown? and not @active?}
    >
      <button
        type="button"
        class={[@theme.filter_bar_pill_button_class, @active? and @filter.clearable? && "pr-2"]}
        data-key="filter_bar_pill_button_class"
        data-bar-open={dropdown_id(@bar_id, @filter)}
        aria-haspopup="dialog"
      >
        <span class={@theme.filter_bar_pill_label_class} data-key="filter_bar_pill_label_class">{@filter.label}</span>
        <span :if={@active?} class={@theme.filter_bar_pill_value_class} data-key="filter_bar_pill_value_class">
          <.summary filter={@filter} />
        </span>
        <.icon :if={not @active?} name={:chevron_down} class={@theme.filter_bar_icon_class} />
      </button>
      <button
        :if={@active? and @filter.clearable?}
        type="button"
        class={@theme.filter_bar_pill_clear_class}
        data-key="filter_bar_pill_clear_class"
        phx-click="clear_filter"
        phx-value-key={@filter.field}
        phx-target={@target}
        aria-label={dgettext("cinder", "Clear filter")}
      >
        <.icon name={:x} class={@theme.filter_bar_icon_class} />
      </button>
    </div>
    """
  end

  attr :filter, :map, required: true
  attr :bar_id, :string, required: true
  attr :controls, :map, required: true

  defp dropdown(assigns) do
    assigns = assign(assigns, :theme, assigns.controls.theme)

    ~H"""
    <div
      id={dropdown_id(@bar_id, @filter)}
      class={[@theme.filter_bar_dropdown_class, "hidden"]}
      data-key="filter_bar_dropdown_class"
      data-bar-dropdown
      data-pill={pill_id(@bar_id, @filter)}
      role="dialog"
      aria-label={@filter.label}
    >
      <.body filter={@filter} controls={@controls} theme={@theme} />
    </div>
    """
  end

  attr :filter, :map, required: true
  attr :controls, :map, required: true
  attr :theme, :map, required: true

  defp body(%{filter: %{type: :select}} = assigns) do
    rows = select_rows(assigns.filter)
    assigns = assign(assigns, rows: rows, searchable?: length(rows) > @searchable_from)

    ~H"""
    <.option_search :if={@searchable?} theme={@theme} />
    <div data-close-on-pick>
      <label
        :for={{label, value} <- @rows}
        class={@theme.filter_bar_option_class}
        data-key="filter_bar_option_class"
        data-bar-option
      >
        <input type="radio" name={@filter.name} value={to_string(value)} checked={to_string(value) == chosen_value(@filter)} class="sr-only" />
        <.icon name={:check} class={[@theme.filter_bar_icon_class, to_string(value) != chosen_value(@filter) && "invisible"]} />
        {label}
      </label>
      <.no_match :if={@searchable?} theme={@theme} />
    </div>
    """
  end

  defp body(%{filter: %{type: :autocomplete}} = assigns) do
    options = Keyword.get(assigns.filter.options || [], :options, [])
    max_results = Keyword.get(assigns.filter.options || [], :max_results, 10)
    search_key = "#{assigns.filter.field}_autocomplete_search"
    term = Map.get(assigns.controls.raw_filter_params, search_key, "")
    matches = options |> Enum.filter(&matches?(&1, term)) |> Enum.take(max_results)
    current = to_string(assigns.filter.value)

    assigns =
      assign(assigns,
        search_name: "filters[#{search_key}]",
        term: term,
        matches: matches,
        more?: length(matches) == max_results and length(options) > max_results,
        current: current,
        keep_current?:
          current != "" and current not in Enum.map(matches, &to_string(elem(&1, 1))),
        placeholder:
          Keyword.get(
            assigns.filter.options || [],
            :placeholder,
            dgettext("cinder", "Search %{label}...", label: assigns.filter.label)
          )
      )

    ~H"""
    <div class={@theme.filter_bar_inputs_class} data-key="filter_bar_inputs_class">
      <input
        type="text"
        name={@search_name}
        value={@term}
        placeholder={@placeholder}
        aria-label={@placeholder}
        autocomplete="off"
        phx-debounce="300"
        class={@theme.filter_text_input_class}
        data-key="filter_text_input_class"
      />
    </div>
    <div data-close-on-pick>
      <input :if={@keep_current?} type="hidden" name={@filter.name} value={@current} />
      <label :for={{label, value} <- @matches} class={@theme.filter_bar_option_class} data-key="filter_bar_option_class">
        <input type="radio" name={@filter.name} value={to_string(value)} checked={to_string(value) == @current} class="sr-only" />
        <.icon name={:check} class={[@theme.filter_bar_icon_class, to_string(value) != @current && "invisible"]} />
        {label}
      </label>
      <p :if={@matches == []} class={@theme.filter_bar_option_class} data-key="filter_bar_option_class">
        {dgettext("cinder", "No results found")}
      </p>
      <p :if={@more?} class={[@theme.filter_bar_option_class, "text-xs italic"]} data-key="filter_bar_option_class">
        {dgettext("cinder", "Type to search more options...")}
      </p>
    </div>
    """
  end

  defp body(%{filter: %{type: :multi_select}} = assigns) do
    rows = option_list(assigns.filter)
    assigns = assign(assigns, rows: rows, searchable?: length(rows) > @searchable_from)

    ~H"""
    <.option_search :if={@searchable?} theme={@theme} />
    <label
      :for={{label, value} <- @rows}
      class={@theme.filter_bar_option_class}
      data-key="filter_bar_option_class"
      data-bar-option
    >
      <input
        type="checkbox"
        name={@filter.name <> "[]"}
        value={to_string(value)}
        checked={to_string(value) in Enum.map(@filter.value, &to_string/1)}
        class={@theme.filter_bar_checkbox_class}
        data-key="filter_bar_checkbox_class"
      />
      {label}
    </label>
    <.no_match :if={@searchable?} theme={@theme} />
    """
  end

  defp body(%{filter: %{type: type}} = assigns) when type in [:date, :date_range] do
    assigns =
      assign(assigns, :shortcuts, if(type == :date, do: @single_dates, else: @date_ranges))

    ~H"""
    <div class={@theme.filter_bar_shortcuts_class} data-key="filter_bar_shortcuts_class">
      <button
        :for={shortcut <- @shortcuts}
        type="button"
        class={@theme.filter_bar_shortcut_class}
        data-key="filter_bar_shortcut_class"
        data-cinder-range={shortcut}
      >
        {shortcut_label(shortcut)}
      </button>
    </div>
    <div class={@theme.filter_bar_inputs_class} data-key="filter_bar_inputs_class">
      <.own_input filter={@filter} controls={@controls} />
    </div>
    """
  end

  defp body(assigns) do
    ~H"""
    <div class={@theme.filter_bar_inputs_class} data-key="filter_bar_inputs_class">
      <.own_input filter={@filter} controls={@controls} />
    </div>
    """
  end

  attr :theme, :map, required: true

  # `form` names no form, so LiveView sees no form to send: typing only narrows the list.
  defp option_search(assigns) do
    ~H"""
    <div class={@theme.filter_bar_inputs_class} data-key="filter_bar_inputs_class">
      <input
        type="text"
        form="cinder-filter-bar-option-search"
        data-bar-option-search
        autocomplete="off"
        placeholder={dgettext("cinder", "Search...")}
        aria-label={dgettext("cinder", "Search...")}
        class={@theme.filter_text_input_class}
        data-key="filter_text_input_class"
      />
    </div>
    """
  end

  attr :theme, :map, required: true

  defp no_match(assigns) do
    ~H"""
    <p class={@theme.filter_bar_option_class} data-key="filter_bar_option_class" data-bar-no-match style="display: none">
      {dgettext("cinder", "No results found")}
    </p>
    """
  end

  attr :filter, :map, required: true
  attr :controls, :map, required: true

  defp own_input(assigns) do
    column = %{
      field: assigns.filter.field,
      label: assigns.filter.label,
      filter_type: assigns.filter.type,
      filter_options: assigns.filter.options
    }

    filter_assigns = %{
      table_id: assigns.controls.table_id,
      target: assigns.controls.target,
      filter_values: assigns.controls.filter_values,
      raw_filter_params: assigns.controls.raw_filter_params,
      in_bar?: true
    }

    module = Registry.get_filter(assigns.filter.type) || Registry.get_filter(:text)

    assigns =
      assign(
        assigns,
        :content,
        module.render(column, assigns.filter.value, assigns.controls.theme, filter_assigns)
      )

    ~H"{@content}"
  end

  attr :filter, :map, required: true

  @doc false
  def summary(%{filter: %{type: :date_range, value: %{from: from, to: to}}} = assigns) do
    assigns = assign(assigns, from: iso_day(from), to: iso_day(to))

    ~H"""
    <%= cond do %>
      <% @from && @from == @to -> %><.day value={@from} />
      <% @from && @to -> %><.day value={@from} /> – <.day value={@to} />
      <% @from -> %><.day value={@from} /> –
      <% true -> %>– <.day value={@to} />
    <% end %>
    """
  end

  def summary(%{filter: %{type: :date, value: value}} = assigns) do
    assigns = assign(assigns, :value, iso_day(value))

    ~H"<.day value={@value} />"
  end

  def summary(assigns) do
    assigns = assign(assigns, :text, summary_text(assigns.filter))

    ~H"{@text}"
  end

  attr :value, :string, required: true

  defp day(assigns) do
    ~H"""
    <time datetime={@value} data-precision="day_month">{@value}</time>
    """
  end

  @doc """
  The text a pill shows for a filter's value, for every type but the dates
  (which render as `<time>` elements). A filter module's own `summary/2` wins.
  """
  @spec summary_text(map()) :: String.t() | nil
  def summary_text(%{type: type, value: value, options: options} = filter) do
    module = Registry.get_filter(type)

    if module && function_exported?(module, :summary, 2) do
      module.summary(value, %{
        field: filter.field,
        label: filter.label,
        filter_type: type,
        filter_options: options
      })
    else
      default_summary(filter)
    end
  end

  defp default_summary(%{type: :number_range, value: %{min: min, max: max}}) do
    case {to_string(min), to_string(max)} do
      {"", max} -> "≤ #{max}"
      {min, ""} -> "≥ #{min}"
      {min, max} -> "#{min} – #{max}"
    end
  end

  defp default_summary(%{type: :boolean, value: value, options: options}) do
    labels = Keyword.get(options || [], :labels, %{})

    case to_string(value) do
      "true" -> Map.get(labels, true, dgettext("cinder", "True"))
      _ -> Map.get(labels, false, dgettext("cinder", "False"))
    end
  end

  defp default_summary(%{type: :checkbox}), do: nil

  defp default_summary(%{value: [value]} = filter), do: option_label(filter, value)

  defp default_summary(%{value: values}) when is_list(values),
    do: dgettext("cinder", "%{count} selected", count: length(values))

  defp default_summary(%{value: value} = filter), do: option_label(filter, value)

  defp option_label(filter, value) do
    Enum.find_value(select_rows(filter), to_string(value), fn {label, option} ->
      to_string(option) == to_string(value) && label
    end)
  end

  @doc "Whether a filter holds a value, so its pill shows it rather than waiting in the menu."
  @spec active?(map()) :: boolean()
  def active?(%{value: value}),
    do: value not in [nil, "", [], %{from: "", to: ""}, %{min: "", max: ""}]

  defp matches?(_option, ""), do: true

  defp matches?({label, _value}, term),
    do: label |> to_string() |> String.downcase() |> String.contains?(String.downcase(term))

  defp offered?(filter), do: Map.get(filter, :offered?, true)

  defp inline?(%{type: type}) do
    module = Registry.get_filter(type)

    module != nil and Code.ensure_loaded?(module) and function_exported?(module, :inline?, 0) and
      module.inline?()
  end

  defp option_list(%{options: options}), do: Keyword.get(options || [], :options, [])

  defp select_rows(%{type: :select, options: options, label: label} = filter) do
    prompt = Keyword.get(options || [], :prompt, dgettext("cinder", "All %{label}", label: label))
    prompt_value = Keyword.get(options || [], :prompt_value, "")

    case Keyword.get(options || [], :prompt_position, :first) do
      :last -> option_list(filter) ++ [{prompt, prompt_value}]
      _first -> [{prompt, prompt_value} | option_list(filter)]
    end
  end

  defp select_rows(filter), do: option_list(filter)

  defp chosen_value(%{value: value, options: options}) when value in [nil, ""],
    do: to_string(Keyword.get(options || [], :prompt_value, ""))

  defp chosen_value(%{value: value}), do: to_string(value)

  defp iso_day(value) when is_binary(value) do
    case value |> String.slice(0, 10) |> Date.from_iso8601() do
      {:ok, date} -> Date.to_iso8601(date)
      {:error, _reason} -> nil
    end
  end

  defp iso_day(%Date{} = date), do: Date.to_iso8601(date)
  defp iso_day(_value), do: nil

  defp shortcut_label("today"), do: dgettext("cinder", "Today")
  defp shortcut_label("yesterday"), do: dgettext("cinder", "Yesterday")
  defp shortcut_label("tomorrow"), do: dgettext("cinder", "Tomorrow")
  defp shortcut_label("this_week"), do: dgettext("cinder", "This week")
  defp shortcut_label("last_week"), do: dgettext("cinder", "Last week")
  defp shortcut_label("past_7_days"), do: dgettext("cinder", "Past 7 days")
  defp shortcut_label("this_month"), do: dgettext("cinder", "This month")
  defp shortcut_label("last_month"), do: dgettext("cinder", "Last month")
  defp shortcut_label("past_30_days"), do: dgettext("cinder", "Past 30 days")

  defp pill_id(bar_id, %{field: field}),
    do: "#{bar_id}-pill-#{Cinder.Filter.sanitized_field_name(field)}"

  defp dropdown_id(bar_id, %{field: field}),
    do: "#{bar_id}-dropdown-#{Cinder.Filter.sanitized_field_name(field)}"

  attr :name, :atom, required: true
  attr :class, :any, default: nil

  defp icon(assigns) do
    ~H"""
    <svg class={@class} fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24" aria-hidden="true">
      <path :if={@name == :plus} stroke-linecap="round" stroke-linejoin="round" d="M12 5v14M5 12h14" />
      <path :if={@name == :x} stroke-linecap="round" stroke-linejoin="round" d="M6 6l12 12M18 6L6 18" />
      <path :if={@name == :check} stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7" />
      <path :if={@name == :chevron_down} stroke-linecap="round" stroke-linejoin="round" d="M19 9l-7 7-7-7" />
      <path :if={@name == :chevron_right} stroke-linecap="round" stroke-linejoin="round" d="M9 5l7 7-7 7" />
    </svg>
    """
  end
end
