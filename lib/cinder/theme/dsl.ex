defmodule Cinder.Theme.Dsl do
  @moduledoc """
  Spark DSL for defining Cinder themes.

  This module provides a DSL for creating modular, reusable theme definitions
  that can be used across projects. It follows the same pattern as AshAuthentication's
  override system.

  ## Example

      defmodule MyApp.CustomTheme do
        use Cinder.Theme

        component Cinder.Components.Table do
          set :container_class, "my-custom-table-container"
          set :row_class, "my-custom-row hover:bg-blue-50"
        end

        component Cinder.Components.Filters do
          set :container_class, "my-filter-container"
          set :text_input_class, "my-text-input"
        end
      end

  """

  @theme_sections [
    Cinder.Components.Table,
    Cinder.Components.Filters,
    Cinder.Components.Pagination,
    Cinder.Components.Sorting,
    Cinder.Components.Loading
  ]

  @doc false
  def sections, do: @theme_sections

  @doc """
  Defines the theme DSL structure.
  """
  def dsl do
    [
      %Spark.Dsl.Section{
        name: :overrides,
        describe: "Theme overrides for different components",
        entities: [
          %Spark.Dsl.Entity{
            name: :override,
            target: Cinder.Theme.Override,
            args: [:component],
            describe: "Override theme properties for a specific component",
            examples: [
              """
              component Cinder.Components.Table do
                set :container_class, "custom-table-container"
                set :row_class, "custom-row"
              end
              """
            ],
            entities: [
              %Spark.Dsl.Entity{
                name: :set,
                target: Cinder.Theme.Property,
                args: [:key, :value],
                describe: "Set a theme property",
                examples: [
                  "set :container_class, \"custom-container\"",
                  "set :table_class, \"w-full border-collapse\""
                ],
                schema: [
                  key: [
                    type: :atom,
                    required: true,
                    doc: "The theme property key"
                  ],
                  value: [
                    type: :string,
                    required: true,
                    doc: "The CSS class string value"
                  ]
                ]
              }
            ],
            schema: [
              component: [
                type: {:in, @theme_sections},
                required: true,
                doc: "The component to override theme properties for"
              ]
            ]
          }
        ]
      }
    ]
  end
end
