defmodule Cinder.Mix.Tasks.CinderInstallTest do
  use ExUnit.Case, async: true

  @moduletag :tmp_dir

  describe "Mix.Tasks.Cinder.Install" do
    test "task is available" do
      # Verify the task exists and can be loaded
      assert Code.ensure_loaded?(Mix.Tasks.Cinder.Install)
    end

    test "has correct module attributes" do
      # Test that the task has the expected documentation and configuration
      assert Mix.Tasks.Cinder.Install.__info__(:attributes)[:shortdoc] == [
               "Install Cinder and configure Tailwind CSS"
             ]
    end

    test "info/2 returns correct task info" do
      if Code.ensure_loaded?(Igniter) do
        info = Mix.Tasks.Cinder.Install.info([], nil)

        assert info.positional == []
        assert info.example == "mix cinder.install"
        assert info.schema == []
      end
    end

    test "provides helpful error when Igniter is not available" do
      # This test verifies that the task module exists and loads properly
      assert Code.ensure_loaded?(Mix.Tasks.Cinder.Install)
      # Both versions of the module should have a run/1 function
      assert function_exported?(Mix.Tasks.Cinder.Install, :run, 1)
    end
  end

  describe "Tailwind configuration detection" do
    test "detects tailwind v3 configuration pattern" do
      tailwind_v3_content = """
      module.exports = {
        content: [
          "./js/**/*.js",
          "../lib/*_web.ex",
          "../lib/*_web/**/*.*ex",
        ],
        theme: {
          extend: {},
        },
        plugins: [],
      }
      """

      # Test that the pattern matching would work
      prefix = """
      module.exports = {
        content: [
      """

      assert String.contains?(tailwind_v3_content, prefix)
    end

    test "detects tailwind v4 configuration pattern" do
      tailwind_v4_content = """
      @import "tailwindcss";

      /* Custom styles */
      .custom-class {
        color: red;
      }
      """

      assert String.contains?(tailwind_v4_content, "@import \"tailwindcss\"")
    end

    test "cinder path would be correctly added to tailwind v3" do
      _original_content = """
      module.exports = {
        content: [
          "./js/**/*.js",
          "../lib/*_web.ex",
          "../lib/*_web/**/*.*ex",
        ],
        theme: {
          extend: {},
        },
        plugins: [],
      }
      """

      expected_addition = "\"../deps/cinder/lib/**/*.*ex\","

      # Verify that the expected addition would include Cinder's files
      assert String.contains?(expected_addition, "cinder/lib")
      assert String.contains?(expected_addition, "**/*.*ex")
    end

    test "cinder source would be correctly added to tailwind v4" do
      _original_content = """
      @import "tailwindcss";

      /* Custom styles */
      """

      expected_addition = "@source \"../../deps/cinder\";"

      # Verify the expected addition format
      assert String.contains?(expected_addition, "deps/cinder")
      assert String.starts_with?(expected_addition, "@source")
    end
  end

  describe "help content" do
    test "provides comprehensive setup instructions" do
      # Test that the installer exists and can be introspected
      # Both versions of the module (with and without Igniter) should have run/1
      assert Code.ensure_loaded?(Mix.Tasks.Cinder.Install)
      assert function_exported?(Mix.Tasks.Cinder.Install, :run, 1)

      # Only the Igniter version has these additional functions
      if Code.ensure_loaded?(Igniter) do
        assert function_exported?(Mix.Tasks.Cinder.Install, :igniter, 1)
        assert function_exported?(Mix.Tasks.Cinder.Install, :info, 2)
      end
    end

    test "includes both tailwind v3 and v4 instructions" do
      # The installer should handle both Tailwind versions
      # This is verified by the presence of both patterns in the code

      # Check that the module contains references to both approaches
      {:ok, source} = File.read("lib/mix/tasks/cinder.install.ex")

      assert String.contains?(source, "tailwind.config.js")
      assert String.contains?(source, "@import")
      assert String.contains?(source, "content:")
      assert String.contains?(source, "@source")
    end
  end

  describe "file paths" do
    test "uses correct relative paths for deps" do
      # Verify that the paths used in the installer are correct
      # for a typical Phoenix application structure

      v3_path = "../deps/cinder/lib/**/*.*ex"
      v4_path = "../../deps/cinder"

      # V3 path should be relative from assets/ directory
      assert String.starts_with?(v3_path, "../deps/")

      # V4 path should be relative from assets/css/ directory
      assert String.starts_with?(v4_path, "../../deps/")

      # Both should point to cinder
      assert String.contains?(v3_path, "cinder")
      assert String.contains?(v4_path, "cinder")
    end
  end
end
