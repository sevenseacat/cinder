defmodule Cinder.PageSizeTest do
  @moduledoc """
  Tests for global default page size configuration.
  """
  use ExUnit.Case, async: false

  alias Cinder.PageSize

  describe "get_default_page_size/0" do
    test "returns 25 when no configuration is set" do
      Application.delete_env(:cinder, :default_page_size)
      assert PageSize.get_default_page_size() == 25
    end

    test "returns configured integer value" do
      Application.put_env(:cinder, :default_page_size, 50)
      assert PageSize.get_default_page_size() == 50
      Application.delete_env(:cinder, :default_page_size)
    end

    test "returns configured keyword list" do
      config = [default: 100, options: [25, 50, 100, 200]]
      Application.put_env(:cinder, :default_page_size, config)
      assert PageSize.get_default_page_size() == config
      Application.delete_env(:cinder, :default_page_size)
    end
  end
end
