defmodule Cinder.TestCollections.Albums do
  @moduledoc "A collection declared with `Cinder.Next.Dsl`, for the tests."
  use Cinder.Next.Dsl

  collection do
    resource(Music.Album)
    page_size(2)
    reorderable(true)
    search(["title"])

    filters do
      filter(:genre, :select, prompt: "Any genre")
      filter(:track_count, type: :number_range, label: "Tracks")
    end

    sorts do
      sort(:title)
      sort(:release_date, label: "Released")
    end

    bulk_actions do
      bulk_action(:remaster, :remaster)
    end
  end
end
