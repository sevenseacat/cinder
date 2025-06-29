# Card-Based Layouts

Cinder now supports card-based layouts as an alternative to traditional table views. The `Cinder.Cards` component provides the same powerful filtering, sorting, and pagination features as `Cinder.Table` but renders data as flexible cards instead of rows.

## Basic Usage

### Simple Cards

```elixir
<Cinder.Cards.cards resource={MyApp.User} actor={@current_user}>
  <:prop field="name" filter sort />
  <:prop field="email" filter />
  <:prop field="created_at" sort />
  <:card :let={user}>
    <div class="user-card">
      <h3 class="font-bold text-lg">{user.name}</h3>
      <p class="text-gray-600">{user.email}</p>
      <small class="text-gray-500">
        Joined {Calendar.strftime(user.created_at, "%B %d, %Y")}
      </small>
    </div>
  </:card>
</Cinder.Cards.cards>
```

### Cards with Images

```elixir
<Cinder.Cards.cards resource={MyApp.Product} actor={@current_user}>
  <:prop field="name" filter sort />
  <:prop field="category" filter={:select} />
  <:prop field="price" sort />
  <:card :let={product}>
    <div class="product-card">
      <img src={product.image_url} alt={product.name} class="w-full h-48 object-cover rounded-t-lg" />
      <div class="p-4">
        <h3 class="font-bold text-lg">{product.name}</h3>
        <p class="text-gray-600">{product.category}</p>
        <p class="text-xl font-bold text-green-600">${product.price}</p>
      </div>
    </div>
  </:card>
</Cinder.Cards.cards>
```

## Advanced Usage

### With Custom Read Actions

```elixir
<Cinder.Cards.cards 
  query={Ash.Query.for_read(MyApp.User, :active_users)} 
  actor={@current_user}
>
  <:prop field="name" filter sort />
  <:prop field="department.name" filter sort />
  <:prop field="last_login" sort />
  <:card :let={user}>
    <div class="employee-card">
      <div class="flex items-center space-x-3">
        <img src={user.avatar_url} class="w-12 h-12 rounded-full" />
        <div>
          <h3 class="font-bold">{user.name}</h3>
          <p class="text-gray-600">{user.department.name}</p>
          <p class="text-sm text-gray-500">
            Last seen: {format_time_ago(user.last_login)}
          </p>
        </div>
      </div>
    </div>
  </:card>
</Cinder.Cards.cards>
```

### With Interactive Cards

```elixir
<Cinder.Cards.cards 
  resource={MyApp.Article} 
  actor={@current_user}
  card_click={fn article -> JS.navigate(~p"/articles/#{article.id}") end}
>
  <:prop field="title" filter sort />
  <:prop field="author.name" filter sort />
  <:prop field="published_at" sort />
  <:card :let={article}>
    <article class="article-card hover:shadow-lg transition-shadow">
      <h2 class="text-xl font-bold mb-2">{article.title}</h2>
      <p class="text-gray-600 mb-3">{String.slice(article.excerpt, 0, 120)}...</p>
      <div class="flex justify-between items-center text-sm text-gray-500">
        <span>By {article.author.name}</span>
        <time>{Calendar.strftime(article.published_at, "%B %d, %Y")}</time>
      </div>
    </article>
  </:card>
</Cinder.Cards.cards>
```

## Configuration Options

### Pagination and Theming

```elixir
<Cinder.Cards.cards
  resource={MyApp.Album}
  actor={@current_user}
  page_size={12}
  theme="modern"
  class="my-custom-cards"
>
  <:prop field="title" filter sort />
  <:prop field="artist.name" filter sort />
  <:prop field="genre" filter={:select} />
  <:card :let={album}>
    <div class="album-card">
      <img src={album.cover_url} alt={album.title} class="w-full aspect-square object-cover" />
      <div class="p-4">
        <h3 class="font-bold">{album.title}</h3>
        <p class="text-gray-600">{album.artist.name}</p>
        <span class="inline-block bg-blue-100 text-blue-800 text-xs px-2 py-1 rounded">
          {album.genre}
        </span>
      </div>
    </div>
  </:card>
</Cinder.Cards.cards>
```

### URL State Management

```elixir
defmodule MyAppWeb.ProductsLive do
  use MyAppWeb, :live_view
  use Cinder.Table.UrlSync

  def handle_params(params, uri, socket) do
    socket = Cinder.Table.UrlSync.handle_params(params, uri, socket)
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <Cinder.Cards.cards 
      resource={MyApp.Product} 
      actor={@current_user} 
      url_state={@url_state}
    >
      <:prop field="name" filter sort />
      <:prop field="category" filter={:select} />
      <:prop field="price" sort />
      <:card :let={product}>
        <div class="product-card">
          <h3>{product.name}</h3>
          <p>{product.category}</p>
          <p>${product.price}</p>
        </div>
      </:card>
    </Cinder.Cards.cards>
    """
  end
end
```

## Properties vs Columns

Cards use `:prop` slots instead of `:col` slots to define filterable and sortable properties:

```elixir
<!-- Table columns -->
<Cinder.Table.table resource={MyApp.User} actor={@current_user}>
  <:col field="name" filter sort>Name</:col>
  <:col field="email" filter>Email</:col>
</Cinder.Table.table>

<!-- Card properties -->
<Cinder.Cards.cards resource={MyApp.User} actor={@current_user}>
  <:prop field="name" filter sort />
  <:prop field="email" filter />
  <:card :let={user}>
    <div>
      <h3>{user.name}</h3>
      <p>{user.email}</p>
    </div>
  </:card>
</Cinder.Cards.cards>
```

## Theming

Cards support all the same themes as tables. Additionally, cards have their own theme properties for customizing the card layout:

```elixir
# Built-in themes
<Cinder.Cards.cards theme="modern" ... />
<Cinder.Cards.cards theme="dark" ... />
<Cinder.Cards.cards theme="retro" ... />
```

### Custom Card Themes

```elixir
defmodule MyApp.CustomTheme do
  use Cinder.Theme

  component Cinder.Components.Cards do
    set :cards_grid_class, "grid grid-cols-1 md:grid-cols-3 lg:grid-cols-4 gap-8"
    set :card_class, "bg-white rounded-xl shadow-lg p-6 hover:shadow-2xl transition-all"
    set :empty_class, "text-center py-16 text-gray-500 col-span-full"
  end
end
```

## When to Use Cards vs Tables

**Use Cards when:**
- Displaying rich content (images, multiple text fields)
- Content varies significantly in length
- Visual appeal is important
- Mobile-first design is priority

**Use Tables when:**
- Comparing data across rows
- Displaying structured, uniform data
- Dense information display is needed
- Traditional business applications

## API Reference

### Cinder.Cards.cards/1

All the same attributes as `Cinder.Table.table/1` except:

- Uses `:prop` slots instead of `:col` slots
- Requires `:card` slot for custom card rendering
- Supports `card_click` instead of `row_click`
- Additional theme properties for card layouts

### Prop Slot Attributes

- `field` - Field name (supports dot notation and `__` for embedded fields)
- `filter` - Enable filtering (boolean or filter type atom)
- `sort` - Enable sorting (boolean) 
- `label` - Custom property label
- `filter_options` - Custom filter options

### Card Slot

The `:card` slot receives the data item as a parameter and allows complete customization of the card layout.