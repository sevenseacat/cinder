defmodule Cinder.Next.Dsl do
  @moduledoc """
  Spike: a collection declared in a module of its own, with a Spark DSL.

      defmodule MyAppWeb.AlbumsCollection do
        use Cinder.Next.Dsl

        collection do
          resource MyApp.Music.Album
          page_size 12
          load [:artist]
          search ["title", "artist.name"]

          filters do
            filter :genre, :select, prompt: "Any genre"
            filter :price, :number_range
          end

          sorts do
            sort :title
            sort :release_date, label: "Released"
          end
        end
      end

  Then, in a LiveView (`use Cinder.Next.LiveView`), with whatever only the page
  knows:

      assign_collection(socket, :albums, MyAppWeb.AlbumsCollection, url: true, actor: user)

  The DSL takes the same options as `<Cinder.Next.collection>`'s attrs and slots
  and `assign_collection/4`'s keyword lists, checked by the same schemas
  (`Cinder.Next.Schema`). The whole collection is built when the module compiles,
  so a field, argument or option that doesn't fit the resource is a compile
  error, not a crash on mount. What only makes sense per request (`url`, the
  scope or actor, saved column choices, callbacks, a prepared query) is given
  to `assign_collection/4`, and overrides what's declared.
  """
  use Spark.Dsl, default_extensions: [extensions: [Cinder.Next.Dsl.Extension]]

  @doc "Whether `module` is a collection declared with this DSL."
  def collection?(module) when is_atom(module) do
    Code.ensure_loaded?(module) and function_exported?(module, :spark_dsl_config, 0) and
      Cinder.Next.Dsl.Extension in Spark.extensions(module)
  end

  def collection?(_other), do: false

  @doc """
  The module's declarations as `assign_collection/4`'s options: the collection's
  own, and its filters, arguments, sorts and bulk actions as keyword lists.
  """
  def options(module) do
    own =
      for key <- Keyword.keys(Cinder.Next.Schema.dsl_collection()),
          value = Spark.Dsl.Extension.get_opt(module, [:collection], key),
          value != nil,
          do: {key, value}

    own ++
      for section <- Cinder.Next.Schema.dsl_sections(),
          do:
            {section,
             entries(
               module,
               section,
               if(section in [:arguments, :bulk_actions], do: :name, else: :field)
             )}
  end

  # `{field, [option: value]}` for each entity, as the keyword lists have them
  defp entries(module, section, key) do
    for entity <- Spark.Dsl.Extension.get_entities(module, [:collection, section]) do
      attrs =
        entity
        |> Map.from_struct()
        |> Map.drop([key, :__spark_metadata__])
        |> Enum.reject(fn {_key, value} -> is_nil(value) end)

      {to_atom(Map.fetch!(entity, key)), attrs}
    end
  end

  # Keyword lists key by atom; a field like `artist.name` was declared as one
  defp to_atom(name) when is_atom(name), do: name
  defp to_atom(name), do: String.to_atom(name)
end

defmodule Cinder.Next.Dsl.Filter do
  @moduledoc false
  defstruct Keyword.keys(Cinder.Next.Schema.dsl_entity(:filter)) ++ [:__spark_metadata__]
end

defmodule Cinder.Next.Dsl.Argument do
  @moduledoc false
  defstruct Keyword.keys(Cinder.Next.Schema.dsl_entity(:argument)) ++ [:__spark_metadata__]
end

defmodule Cinder.Next.Dsl.Sort do
  @moduledoc false
  defstruct Keyword.keys(Cinder.Next.Schema.dsl_entity(:sort)) ++ [:__spark_metadata__]
end

defmodule Cinder.Next.Dsl.BulkAction do
  @moduledoc false
  defstruct Keyword.keys(Cinder.Next.Schema.dsl_entity(:bulk_action)) ++ [:__spark_metadata__]
end

defmodule Cinder.Next.Dsl.Extension do
  @moduledoc false
  alias Cinder.Next.Schema

  @filter %Spark.Dsl.Entity{
    name: :filter,
    describe: "A filter, as `<:filter>` declares one",
    examples: ["filter :genre, :select, prompt: \"Any genre\"", "filter :price, :number_range"],
    target: Cinder.Next.Dsl.Filter,
    args: [:field, {:optional, :type}],
    schema: Schema.dsl_entity(:filter)
  }

  @argument %Spark.Dsl.Entity{
    name: :argument,
    describe: "An input for the read action's argument, as `<:argument>` declares one",
    examples: ["argument :min_tracks, label: \"At least this many tracks\""],
    target: Cinder.Next.Dsl.Argument,
    args: [:name, {:optional, :type}],
    schema: Schema.dsl_entity(:argument)
  }

  @sort %Spark.Dsl.Entity{
    name: :sort,
    describe: "A sortable field, as `<:sort>` declares one",
    examples: ["sort :title", "sort :release_date, label: \"Released\""],
    target: Cinder.Next.Dsl.Sort,
    args: [:field],
    schema: Schema.dsl_entity(:sort)
  }

  @bulk_action %Spark.Dsl.Entity{
    name: :bulk_action,
    describe: "An action on the selected records, as `<:bulk_action>` declares one",
    examples: ["bulk_action :delete, :destroy, confirm: \"Delete {count} albums?\""],
    target: Cinder.Next.Dsl.BulkAction,
    args: [:name, :action],
    schema: Schema.dsl_entity(:bulk_action)
  }

  @collection %Spark.Dsl.Section{
    name: :collection,
    describe: "The collection: what it reads, and how it can be filtered, sorted and shown",
    schema: Schema.dsl_collection(),
    sections: [
      %Spark.Dsl.Section{name: :filters, describe: "Its filters, in order", entities: [@filter]},
      %Spark.Dsl.Section{
        name: :arguments,
        describe: "Inputs for the read action's arguments, in order",
        entities: [@argument]
      },
      %Spark.Dsl.Section{name: :sorts, describe: "Its sortable fields", entities: [@sort]},
      %Spark.Dsl.Section{
        name: :bulk_actions,
        describe: "Actions on selected records",
        entities: [@bulk_action]
      }
    ]
  }

  use Spark.Dsl.Extension,
    sections: [@collection],
    transformers: [Cinder.Next.Dsl.Check]
end

defmodule Cinder.Next.Dsl.Check do
  @moduledoc false
  # Builds the whole collection when the module compiles, so anything that
  # doesn't fit the resource (a field, an argument, a filter type's options) is a
  # compile error rather than a crash on mount. A transformer that changes
  # nothing, rather than a verifier: Spark reports a verifier's errors as warnings.
  use Spark.Dsl.Transformer

  @impl true
  def transform(dsl_state) do
    module = Spark.Dsl.Transformer.get_persisted(dsl_state, :module)
    opts = Cinder.Next.Dsl.options(dsl_state)

    case Keyword.fetch(opts, :resource) do
      {:ok, resource} ->
        try do
          Cinder.Next.LiveView.config!(:collection, resource, Keyword.delete(opts, :resource))
          {:ok, dsl_state}
        rescue
          error in ArgumentError ->
            {:error,
             Spark.Error.DslError.exception(
               module: module,
               path: [:collection],
               message: Exception.message(error)
             )}
        end

      :error ->
        # Given at runtime instead: `assign_collection/4`'s query
        {:ok, dsl_state}
    end
  end
end
