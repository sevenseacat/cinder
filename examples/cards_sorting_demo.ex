defmodule CardsortingDemo do
  @moduledoc """
  Demo of Cards component with sorting functionality.
  
  This example shows how Cards component now supports sorting 
  with clickable sort buttons that appear above the card grid.
  """

  use Phoenix.Component

  def render(assigns) do
    ~H"""
    <div class="p-8">
      <h1 class="text-2xl font-bold mb-6">Cards Sorting Demo</h1>
      
      <div class="mb-8">
        <h2 class="text-xl font-semibold mb-4">Modern Theme with Sorting</h2>
        <Cinder.Cards.cards resource={DemoApp.Product} actor={nil} theme="modern">
          <:prop field="name" filter sort />
          <:prop field="price" sort />
          <:prop field="category" filter />
          <:prop field="created_at" sort />
          <:card :let={product}>
            <div class="product-card">
              <h3 class="font-bold text-lg">{product.name}</h3>
              <p class="text-lg font-semibold text-green-600">${product.price}</p>
              <p class="text-gray-600">{product.category}</p>
              <small class="text-gray-500">
                Created: {Calendar.strftime(product.created_at, "%B %d, %Y")}
              </small>
            </div>
          </:card>
        </Cinder.Cards.cards>
      </div>
      
      <div class="mb-8">
        <h2 class="text-xl font-semibold mb-4">Dark Theme with Sorting</h2>
        <Cinder.Cards.cards resource={DemoApp.User} actor={nil} theme="dark">
          <:prop field="name" filter sort />
          <:prop field="email" filter />
          <:prop field="age" sort />
          <:prop field="created_at" sort />
          <:card :let={user}>
            <div class="user-card">
              <h3 class="font-bold text-lg text-white">{user.name}</h3>
              <p class="text-gray-300">{user.email}</p>
              <p class="text-gray-400">Age: {user.age}</p>
              <small class="text-gray-500">
                Joined: {Calendar.strftime(user.created_at, "%B %d, %Y")}
              </small>
            </div>
          </:card>
        </Cinder.Cards.cards>
      </div>
      
      <div class="bg-blue-50 p-6 rounded-lg">
        <h3 class="font-semibold mb-2">Sorting Features:</h3>
        <ul class="list-disc list-inside space-y-1 text-gray-700">
          <li>Click sort buttons to cycle: None → Ascending → Descending → None</li>
          <li>Visual indicators show current sort state with themed colors</li>
          <li>Supports multi-column sorting with priority order</li>
          <li>Sort controls only appear when sortable properties exist</li>
          <li>Consistent with Table component sorting behavior</li>
          <li>Full theme customization support</li>
        </ul>
      </div>
    </div>
    """
  end
end