defmodule CinderDevWeb.Collections.Albums do
  @moduledoc """
  The shell-rewrite spike's `/next/live` collection, declared in a module of its
  own with `Cinder.Next.Dsl`, and checked against `Music.Album` when it compiles.
  """
  use Cinder.Next.Dsl

  collection do
    resource(Music.Album)
    load([:artist])
    page_size(12)
    layouts([:grid])
    grid_columns(xs: 1, sm: 2, lg: 3)
    selectable(true)
    search(["title", "artist.name"])

    filters do
      filter(:genre, :select, prompt: "Any genre")
      filter(:price, :number_range)
    end

    sorts do
      sort(:title)
      sort(:price)
      sort(:release_date, label: "Released")
    end

    bulk_actions do
      bulk_action(:remaster, :remaster)
      bulk_action(:delete, :destroy, confirm: "Delete {count} albums?")
    end
  end
end
