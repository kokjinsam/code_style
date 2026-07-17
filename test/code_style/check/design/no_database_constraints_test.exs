defmodule CodeStyle.Check.Design.NoDatabaseConstraintsTest do
  use Credo.Test.Case, async: false

  alias CodeStyle.Check.Design.NoDatabaseConstraints

  test "reports forbidden column options inside migration table blocks" do
    """
    defmodule Remark.Repo.Migrations.CreateProducts do
      use Ecto.Migration

      def change do
        create table(:products) do
          add :price, :decimal, null: false, precision: 10, scale: 2, default: 0
        end
      end
    end
    """
    |> to_source_file("priv/repo/migrations/20260624000000_create_products.exs")
    |> run_check(NoDatabaseConstraints)
    |> assert_issue(%{
      line_no: 6,
      trigger: "add",
      message:
        "Column option(s) `null`, `precision`, `scale`, `default` should not be set in migrations. Enforce at the application layer."
    })
  end

  test "does not report structural primary key options" do
    """
    defmodule Remark.Repo.Migrations.CreateWidgets do
      use Ecto.Migration

      def change do
        create table(:widgets, primary_key: false) do
          add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
        end
      end
    end
    """
    |> to_source_file("priv/repo/migrations/20260624000000_create_widgets.exs")
    |> run_check(NoDatabaseConstraints)
    |> refute_issues()
  end

  test "reports modify options inside alter table blocks" do
    """
    defmodule Remark.Repo.Migrations.AlterUsers do
      use Ecto.Migration

      def change do
        alter table(:users) do
          modify :name, :string, from: :text, null: false, default: ""
        end
      end
    end
    """
    |> to_source_file("priv/repo/migrations/20260624000000_alter_users.exs")
    |> run_check(NoDatabaseConstraints)
    |> assert_issue(%{
      line_no: 6,
      trigger: "modify",
      message: "Column option(s) `null`, `default` should not be set in migrations. Enforce at the application layer."
    })
  end

  test "supports create_if_not_exists with add and alter with add_if_not_exists" do
    """
    defmodule Example.Migration do
      use Ecto.Migration

      def change do
        create_if_not_exists products_table do
          add :name, :string, size: 80
        end

        alter table_for(:products) do
          add_if_not_exists :status, :string, default: "new"
        end
      end
    end
    """
    |> to_source_file()
    |> run_check(NoDatabaseConstraints)
    |> assert_issues_match([
      %{line_no: 6, trigger: "add"},
      %{line_no: 10, trigger: "add_if_not_exists"}
    ])
  end

  test "resolves direct and aliased use directives in lexical order" do
    """
    defmodule Direct do
      use Ecto.Migration
      def change, do: create(source(), do: add(:direct, :string, null: false))
    end

    defmodule Aliased do
      alias Ecto.Migration, as: MigrationDsl
      use MigrationDsl
      def change, do: alter(source(), do: modify(:aliased, :string, precision: 4))
    end

    defmodule BeforeUse do
      def change, do: create(source(), do: add(:early, :string, null: false))
      use Ecto.Migration
      def later, do: create(source(), do: add(:late, :string, null: false))
    end
    """
    |> to_source_file()
    |> run_check(NoDatabaseConstraints)
    |> assert_issues_match([
      %{line_no: 3, trigger: "add"},
      %{line_no: 9, trigger: "modify"},
      %{line_no: 15, trigger: "add"}
    ])
  end

  test "honors literal only and except filters on exact migration imports" do
    """
    defmodule Only do
      import Ecto.Migration, only: [create: 2, add: 3]
      def change, do: create(source(), do: add(:only, :string, null: false))
    end

    defmodule Except do
      import Ecto.Migration, except: [modify: 3]
      def change do
        alter source() do
          add :included, :string, default: ""
          modify :excluded, :string, null: false
        end
      end
    end
    """
    |> to_source_file()
    |> run_check(NoDatabaseConstraints)
    |> assert_issues_match([
      %{line_no: 3, trigger: "add"},
      %{line_no: 10, trigger: "add"}
    ])
  end

  test "resolves an aliased migration import" do
    """
    defmodule AliasedImport do
      alias Ecto.Migration, as: M
      import M, only: [alter: 2, add_if_not_exists: 3]

      def change do
        alter source() do
          add_if_not_exists :status, :string, null: false
        end
      end
    end
    """
    |> to_source_file()
    |> run_check(NoDatabaseConstraints)
    |> assert_issue(%{line_no: 7, trigger: "add_if_not_exists"})
  end

  test "supports fully qualified and alias-qualified migration calls" do
    """
    defmodule Qualified do
      alias Ecto.Migration, as: M

      def change do
        Ecto.Migration.create source() do
          Ecto.Migration.add :direct, :string, null: false
        end

        M.alter source() do
          M.modify :aliased, :decimal, scale: 2
        end
      end
    end
    """
    |> to_source_file()
    |> run_check(NoDatabaseConstraints)
    |> assert_issues_match([
      %{line_no: 6, trigger: "add"},
      %{line_no: 10, trigger: "modify"}
    ])
  end

  test "reports multiple offenses once in source and option order" do
    """
    defmodule Ordered do
      use Ecto.Migration

      def change do
        create object do
          add :first, :decimal, scale: 2, null: false, scale: 3, default: 0
          add :second, :string, size: 20
        end
      end
    end
    """
    |> to_source_file()
    |> run_check(NoDatabaseConstraints)
    |> then(fn issues ->
      assert Enum.map(issues, & &1.line_no) == [6, 7]

      assert Enum.map(issues, & &1.message) == [
               "Column option(s) `scale`, `null`, `default` should not be set in migrations. Enforce at the application layer.",
               "Column option(s) `size` should not be set in migrations. Enforce at the application layer."
             ]

      issues
    end)
    |> assert_issues(2)
  end

  test "keeps the broad primary-key exemption and allows non-forbidden options" do
    """
    defmodule Allowed do
      use Ecto.Migration

      def change do
        create source() do
          add :id, :binary_id, null: false, primary_key: true, default: fragment("uuid()")
          add :name, :string, comment: "display name"
        end
      end
    end
    """
    |> to_source_file()
    |> run_check(NoDatabaseConstraints)
    |> refute_issues()
  end

  test "ignores arity-one table operations, helper macros, and remove" do
    """
    defmodule UnsupportedForms do
      use Ecto.Migration

      def change do
        create table(:one)
        create_if_not_exists table(:two)

        alter source() do
          helper :name, :string, null: false
          remove :legacy, :string, null: false
        end
      end
    end
    """
    |> to_source_file()
    |> run_check(NoDatabaseConstraints)
    |> refute_issues()
  end

  test "ignores unrelated same-named DSLs and keeps modules independent" do
    """
    defmodule RealMigration do
      use Ecto.Migration
      def change, do: create(source(), do: add(:real, :string, null: false))
    end

    defmodule OtherDsl do
      use Other.Migration
      def change, do: create(source(), do: add(:fake, :string, null: false))
    end

    defmodule NoDirective do
      def change, do: create(source(), do: add(:also_fake, :string, null: false))
    end
    """
    |> to_source_file()
    |> run_check(NoDatabaseConstraints)
    |> assert_issue(%{line_no: 3, trigger: "add"})
  end

  test "skips quoted directives and calls" do
    """
    defmodule Quoted do
      quote do
        use Ecto.Migration
        create source() do
          add :quoted, :string, null: false
        end
      end

      use Ecto.Migration

      def expression do
        quote do
          alter source() do
            modify :quoted_too, :string, default: ""
          end
        end
      end
    end
    """
    |> to_source_file()
    |> run_check(NoDatabaseConstraints)
    |> refute_issues()
  end

  test "ignores excluded imports and dynamic import filters" do
    """
    defmodule Excluded do
      import Ecto.Migration, only: [create: 2]
      def change, do: create(source(), do: add(:excluded, :string, null: false))
    end

    defmodule Dynamic do
      import Ecto.Migration, options()
      def change, do: create(source(), do: add(:dynamic, :string, null: false))
    end
    """
    |> to_source_file()
    |> run_check(NoDatabaseConstraints)
    |> refute_issues()
  end

  test "ignores dynamic column options and forbidden-looking nested from options" do
    """
    defmodule DynamicOptions do
      use Ecto.Migration

      def change do
        alter source() do
          add :dynamic, :string, options()
          modify :nested, :string, from: {:text, [null: false, default: ""]}
        end
      end
    end
    """
    |> to_source_file()
    |> run_check(NoDatabaseConstraints)
    |> refute_issues()
  end
end
