defmodule Cinder.Integration.QuerySortExtractionTest do
  use ExUnit.Case, async: true

  # Mock Ash resources for testing
  defmodule TestUser do
    use Ash.Resource,
      domain: nil,
      data_layer: Ash.DataLayer.Ets,
      validate_domain_inclusion?: false

    ets do
      private?(true)
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string, public?: true)
      attribute(:email, :string, public?: true)
      attribute(:created_at, :utc_datetime, public?: true)
    end

    actions do
      defaults([:read, :update, :destroy])

      create :create do
        accept([:name, :email])
      end
    end
  end

  defmodule TestDomain do
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource(TestUser)
    end
  end

  describe "query sort extraction integration" do
    test "table sorting overrides existing query sorts during data loading" do
      # Create test data
      {:ok, _user1} =
        TestUser
        |> Ash.Changeset.for_create(:create, %{name: "Alice", email: "alice@example.com"},
          domain: TestDomain
        )
        |> Ash.create(domain: TestDomain)

      {:ok, _user2} =
        TestUser
        |> Ash.Changeset.for_create(:create, %{name: "Bob", email: "bob@example.com"},
          domain: TestDomain
        )
        |> Ash.create(domain: TestDomain)

      # Create a query with existing sorts
      query =
        TestUser
        |> Ash.Query.for_read(:read, %{}, domain: TestDomain)
        |> Ash.Query.sort([{:name, :desc}])

      # Test that apply_sorting clears existing sorts and applies new ones
      new_sort_by = [{"email", :asc}]

      result_query = Cinder.QueryBuilder.apply_sorting(query, new_sort_by)

      # The result should only have the new sort, not the original query sort
      assert result_query.sort == [{:email, :asc}]
      refute result_query.sort == [{:name, :desc}, {:email, :asc}]
    end

    test "gracefully handles resource modules without sorts" do
      # Test passing a resource module instead of a query
      extracted_sorts =
        Cinder.QueryBuilder.extract_query_sorts(TestUser, [
          %{field: "name"},
          %{field: "email"}
        ])

      assert extracted_sorts == []
    end

    test "filters extracted sorts to only include defined table columns" do
      # Create query with sorts for fields that may not all be in the table
      query =
        TestUser
        |> Ash.Query.for_read(:read, %{}, domain: TestDomain)
        |> Ash.Query.sort([{:name, :desc}, {:email, :asc}, {:created_at, :desc}])

      # Only include some columns in the table definition
      columns = [
        %{field: "name"},
        %{field: "email"}
        # Note: created_at not included
      ]

      extracted_sorts = Cinder.QueryBuilder.extract_query_sorts(query, columns)

      # Should only include sorts for columns that exist in the table
      assert extracted_sorts == [{"name", :desc}, {"email", :asc}]
      refute Enum.any?(extracted_sorts, fn {field, _} -> field == "created_at" end)
    end
  end
end
