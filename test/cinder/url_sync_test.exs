defmodule Cinder.UrlSyncTest do
  use ExUnit.Case, async: true

  alias Cinder.UrlSync

  describe "patched_url/3" do
    @uri "http://localhost:4000/albums?theme=dark&title=old&page=2"

    test "the collection's params replace all it owns, and the app's own stay" do
      assert UrlSync.patched_url(@uri, %{"genre" => "rock"}, ~w(title genre page)) ==
               "/albums?theme=dark&genre=rock"
    end

    # An empty `sort` means unsorted, where no `sort` means the default
    test "empty params are kept" do
      assert UrlSync.patched_url(@uri, %{"sort" => ""}, ~w(title page sort)) ==
               "/albums?theme=dark&sort="
    end

    # A name can repeat, with brackets (as Phoenix's form helpers name inputs) or
    # without
    test "the app's repeated params all stay, in their order" do
      uri = "http://localhost:4000/albums?tag=a&tag=b&page=2&ids[]=1&ids[]=2"

      assert UrlSync.patched_url(uri, %{"page" => "3"}, ["page"]) ==
               "/albums?tag=a&tag=b&ids%5B%5D=1&ids%5B%5D=2&page=3"
    end

    test "with no params left, the path alone" do
      assert UrlSync.patched_url("http://localhost:4000/albums?page=2", %{}, ["page"]) ==
               "/albums"
    end
  end
end
