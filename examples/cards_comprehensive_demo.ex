defmodule CardsComprehensiveDemo do
  @moduledoc """
  Comprehensive demonstration of the Cinder Cards component.
  
  This example showcases all the features and use cases for the Cards component,
  including filtering, sorting, pagination, themes, and advanced configurations.
  
  Cards provide the same powerful filtering, sorting, and pagination features as
  Tables but render data as flexible cards instead of rows.
  """

  use Phoenix.Component

  def render(assigns) do
    ~H"""
    <div class="p-8 space-y-12">
      <div class="text-center">
        <h1 class="text-3xl font-bold mb-4">Cinder Cards Component Demo</h1>
        <p class="text-gray-600 text-lg">
          Flexible card-based layouts with filtering, sorting, and pagination
        </p>
      </div>

      <!-- Basic Usage -->
      <section>
        <h2 class="text-2xl font-semibold mb-6">Basic Usage</h2>
        
        <div class="mb-8">
          <h3 class="text-xl font-medium mb-4">Simple User Cards</h3>
          <Cinder.Cards.cards resource={DemoApp.User} actor={nil}>
            <:prop field="name" filter sort />
            <:prop field="email" filter />
            <:prop field="created_at" sort />
            <:card :let={user}>
              <div class="user-card bg-white rounded-lg shadow-md p-6">
                <h3 class="font-bold text-lg">{user.name}</h3>
                <p class="text-gray-600">{user.email}</p>
                <small class="text-gray-500">
                  Joined {Calendar.strftime(user.created_at, "%B %d, %Y")}
                </small>
              </div>
            </:card>
          </Cinder.Cards.cards>
        </div>
      </section>

      <!-- Cards with Images -->
      <section>
        <h2 class="text-2xl font-semibold mb-6">Cards with Images</h2>
        
        <div class="mb-8">
          <h3 class="text-xl font-medium mb-4">Product Catalog</h3>
          <Cinder.Cards.cards resource={DemoApp.Product} actor={nil} theme="modern">
            <:prop field="name" filter sort />
            <:prop field="category" filter={:select} />
            <:prop field="price" sort />
            <:card :let={product}>
              <div class="product-card bg-white rounded-lg shadow-lg overflow-hidden">
                <img src={product.image_url || "/images/placeholder.jpg"} 
                     alt={product.name} 
                     class="w-full h-48 object-cover" />
                <div class="p-4">
                  <h3 class="font-bold text-lg">{product.name}</h3>
                  <p class="text-gray-600">{product.category}</p>
                  <p class="text-xl font-bold text-green-600">${product.price}</p>
                </div>
              </div>
            </:card>
          </Cinder.Cards.cards>
        </div>
      </section>

      <!-- Advanced Usage with Custom Read Actions -->
      <section>
        <h2 class="text-2xl font-semibold mb-6">Advanced Usage</h2>
        
        <div class="mb-8">
          <h3 class="text-xl font-medium mb-4">Employee Directory (Custom Query)</h3>
          <Cinder.Cards.cards 
            query={Ash.Query.for_read(DemoApp.User, :active_users)} 
            actor={nil}
            theme="dark"
          >
            <:prop field="name" filter sort />
            <:prop field="department.name" filter sort />
            <:prop field="last_login" sort />
            <:card :let={user}>
              <div class="employee-card bg-gray-800 rounded-lg p-6 text-white">
                <div class="flex items-center space-x-3">
                  <img src={user.avatar_url || "/images/default-avatar.png"} 
                       class="w-12 h-12 rounded-full" 
                       alt={user.name} />
                  <div>
                    <h3 class="font-bold">{user.name}</h3>
                    <p class="text-gray-300">{user.department.name}</p>
                    <p class="text-sm text-gray-400">
                      Last seen: {format_time_ago(user.last_login)}
                    </p>
                  </div>
                </div>
              </div>
            </:card>
          </Cinder.Cards.cards>
        </div>
      </section>

      <!-- Interactive Cards -->
      <section>
        <h2 class="text-2xl font-semibold mb-6">Interactive Cards</h2>
        
        <div class="mb-8">
          <h3 class="text-xl font-medium mb-4">Article Browser (Clickable Cards)</h3>
          <Cinder.Cards.cards 
            resource={DemoApp.Article} 
            actor={nil}
            card_click={fn article -> JS.navigate(~p"/articles/#{article.id}") end}
          >
            <:prop field="title" filter sort />
            <:prop field="author.name" filter sort />
            <:prop field="published_at" sort />
            <:card :let={article}>
              <article class="article-card bg-white rounded-lg shadow-md p-6 hover:shadow-lg transition-shadow cursor-pointer">
                <h2 class="text-xl font-bold mb-2">{article.title}</h2>
                <p class="text-gray-600 mb-3">{String.slice(article.excerpt, 0, 120)}...</p>
                <div class="flex justify-between items-center text-sm text-gray-500">
                  <span>By {article.author.name}</span>
                  <time>{Calendar.strftime(article.published_at, "%B %d, %Y")}</time>
                </div>
              </article>
            </:card>
          </Cinder.Cards.cards>
        </div>
      </section>

      <!-- Theme Showcase -->
      <section>
        <h2 class="text-2xl font-semibold mb-6">Theme Showcase</h2>
        
        <!-- Modern Theme -->
        <div class="mb-8">
          <h3 class="text-xl font-medium mb-4">Modern Theme</h3>
          <Cinder.Cards.cards
            resource={DemoApp.Album}
            actor={nil}
            page_size={6}
            theme="modern"
            class="my-custom-cards"
          >
            <:prop field="title" filter sort />
            <:prop field="artist.name" filter sort />
            <:prop field="genre" filter={:select} />
            <:card :let={album}>
              <div class="album-card bg-white rounded-xl shadow-lg overflow-hidden">
                <img src={album.cover_url || "/images/album-placeholder.jpg"} 
                     alt={album.title} 
                     class="w-full aspect-square object-cover" />
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
        </div>

        <!-- Dark Theme -->
        <div class="mb-8">
          <h3 class="text-xl font-medium mb-4">Dark Theme</h3>
          <div class="bg-gray-900 p-6 rounded-lg">
            <Cinder.Cards.cards
              resource={DemoApp.User}
              actor={nil}
              theme="dark"
              page_size={4}
            >
              <:prop field="name" filter sort />
              <:prop field="email" filter />
              <:prop field="status" filter={:select} />
              <:card :let={user}>
                <div class="user-card-dark bg-gray-800 rounded-lg p-6 border border-gray-700">
                  <h3 class="font-bold text-lg text-white">{user.name}</h3>
                  <p class="text-gray-300">{user.email}</p>
                  <div class="mt-2">
                    <span class={"inline-block px-2 py-1 rounded text-xs #{status_color(user.status)}"}>
                      {user.status}
                    </span>
                  </div>
                </div>
              </:card>
            </Cinder.Cards.cards>
          </div>
        </div>
      </section>

      <!-- URL State Management -->
      <section>
        <h2 class="text-2xl font-semibold mb-6">URL State Management</h2>
        
        <div class="mb-8">
          <div class="bg-blue-50 p-6 rounded-lg mb-4">
            <h4 class="font-semibold mb-2">LiveView Integration:</h4>
            <pre class="text-sm bg-white p-4 rounded border overflow-x-auto"><code>defmodule MyAppWeb.ProductsLive do
  use MyAppWeb, :live_view
  use Cinder.Table.UrlSync

  def handle_params(params, uri, socket) do
    socket = Cinder.Table.UrlSync.handle_params(params, uri, socket)
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    &lt;Cinder.Cards.cards 
      resource={MyApp.Product} 
      actor={@current_user} 
      url_state={@url_state}
    &gt;
      &lt;:prop field="name" filter sort /&gt;
      &lt;:card :let={product}&gt;
        &lt;div class="product-card"&gt;
          &lt;h3&gt;{product.name}&lt;/h3&gt;
        &lt;/div&gt;
      &lt;/:card&gt;
    &lt;/Cinder.Cards.cards&gt;
    """
  end
end</code></pre>
          </div>
          
          <h3 class="text-xl font-medium mb-4">Cards with URL State (Example)</h3>
          <Cinder.Cards.cards 
            resource={DemoApp.Product} 
            actor={nil}
            url_state={%{}}
            loading_message="Loading products..."
            empty_message="No products found"
          >
            <:prop field="name" filter sort />
            <:prop field="category" filter={:select} />
            <:prop field="price" sort />
            <:card :let={product}>
              <div class="product-card bg-white rounded-lg shadow-md p-4">
                <h3 class="font-bold">{product.name}</h3>
                <p class="text-gray-600">{product.category}</p>
                <p class="text-lg font-semibold text-green-600">${product.price}</p>
              </div>
            </:card>
          </Cinder.Cards.cards>
        </div>
      </section>

      <!-- Sorting Features -->
      <section>
        <h2 class="text-2xl font-semibold mb-6">Sorting Features</h2>
        
        <div class="bg-green-50 p-6 rounded-lg mb-6">
          <h4 class="font-semibold mb-3">Sorting Behavior:</h4>
          <ul class="list-disc list-inside space-y-2 text-gray-700">
            <li><strong>Click once:</strong> Sort ascending</li>
            <li><strong>Click twice:</strong> Sort descending</li>
            <li><strong>Click third time:</strong> Remove sort</li>
            <li><strong>Multiple columns:</strong> Supports multi-column sorting with priority order</li>
            <li><strong>Visual indicators:</strong> ↑ (ascending), ↓ (descending), ↕ (available)</li>
          </ul>
        </div>

        <Cinder.Cards.cards resource={DemoApp.Product} actor={nil}>
          <:prop field="name" filter sort />
          <:prop field="price" sort />
          <:prop field="created_at" sort />
          <:card :let={product}>
            <div class="product-card bg-white rounded-lg shadow-md p-4">
              <h3 class="font-bold text-lg">{product.name}</h3>
              <p class="text-xl font-semibold text-green-600">${product.price}</p>
              <p class="text-sm text-gray-500">
                Created: {Calendar.strftime(product.created_at, "%B %d, %Y")}
              </p>
            </div>
          </:card>
        </Cinder.Cards.cards>
      </section>

      <!-- Performance and Lifecycle -->
      <section>
        <h2 class="text-2xl font-semibold mb-6">Performance Features</h2>
        
        <div class="grid md:grid-cols-2 gap-6 mb-6">
          <div class="bg-purple-50 p-6 rounded-lg">
            <h4 class="font-semibold mb-3">Asynchronous Loading</h4>
            <ul class="text-sm space-y-1 text-gray-700">
              <li>• UI remains interactive while loading</li>
              <li>• Automatic loading state management</li>
              <li>• Graceful error handling</li>
              <li>• Non-blocking interface</li>
            </ul>
          </div>
          
          <div class="bg-orange-50 p-6 rounded-lg">
            <h4 class="font-semibold mb-3">Refresh Functionality</h4>
            <ul class="text-sm space-y-1 text-gray-700">
              <li>• Programmatic refresh support</li>
              <li>• Maintains current filters/sorting</li>
              <li>• Client-side refresh triggers</li>
              <li>• State preservation</li>
            </ul>
          </div>
        </div>

        <!-- Refresh Example -->
        <div class="bg-gray-50 p-6 rounded-lg">
          <h4 class="font-semibold mb-3">Refresh Example:</h4>
          <pre class="text-sm bg-white p-4 rounded border overflow-x-auto"><code># In your LiveView
def handle_event("refresh_cards", _params, socket) do
  send_update(Cinder.Cards.LiveComponent, id: "my-cards", refresh: true)
  {:noreply, socket}
end

# Or from JavaScript
liveSocket.execJS("#my-cards", "[[\"refresh\"]]");</code></pre>
        </div>
      </section>

      <!-- When to Use Cards vs Tables -->
      <section>
        <h2 class="text-2xl font-semibold mb-6">Cards vs Tables</h2>
        
        <div class="grid md:grid-cols-2 gap-6">
          <div class="bg-green-50 p-6 rounded-lg">
            <h4 class="font-semibold mb-3 text-green-800">Use Cards when:</h4>
            <ul class="text-sm space-y-1 text-green-700">
              <li>• Displaying rich content (images, multiple text fields)</li>
              <li>• Content varies significantly in length</li>
              <li>• Visual appeal is important</li>
              <li>• Mobile-first design is priority</li>
              <li>• User profiles, products, articles</li>
            </ul>
          </div>
          
          <div class="bg-blue-50 p-6 rounded-lg">
            <h4 class="font-semibold mb-3 text-blue-800">Use Tables when:</h4>
            <ul class="text-sm space-y-1 text-blue-700">
              <li>• Comparing data across rows</li>
              <li>• Displaying structured, uniform data</li>
              <li>• Dense information display is needed</li>
              <li>• Traditional business applications</li>
              <li>• Financial data, logs, reports</li>
            </ul>
          </div>
        </div>
      </section>
    </div>
    """
  end

  # Helper functions for the demo
  defp format_time_ago(datetime) do
    case DateTime.diff(DateTime.utc_now(), datetime, :day) do
      0 -> "Today"
      1 -> "Yesterday"
      days when days < 7 -> "#{days} days ago"
      days when days < 30 -> "#{div(days, 7)} weeks ago"
      days -> "#{div(days, 30)} months ago"
    end
  end

  defp status_color("active"), do: "bg-green-100 text-green-800"
  defp status_color("inactive"), do: "bg-red-100 text-red-800"
  defp status_color("pending"), do: "bg-yellow-100 text-yellow-800"
  defp status_color(_), do: "bg-gray-100 text-gray-800"
end