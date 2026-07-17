defmodule CodeStyleTest do
  use Credo.Test.Case, async: false

  alias CodeStyle.Check.Warning.RepoInsideLoop

  test "registers custom Credo checks" do
    assert {CodeStyle.Check.Design.NoDatabaseConstraints, []} in CodeStyle.checks()
    assert {RepoInsideLoop, []} in CodeStyle.checks()
  end

  test "registers ExSlop checks without the subsumed QueryInEnumMap check" do
    assert {ExSlop.Check.Warning.BlanketRescue, []} in CodeStyle.checks()
    assert {ExSlop.Check.Warning.RepoAllThenFilter, []} in CodeStyle.checks()
    assert {ExSlop.Check.Refactor.PreferEnumSlice, []} in CodeStyle.checks()
    assert {ExSlop.Check.Readability.DocFalseOnPublicFunction, []} in CodeStyle.checks()

    refute {ExSlop.Check.Warning.QueryInEnumMap, []} in CodeStyle.checks()
  end

  test "registers migration safety checks" do
    assert {ExcellentMigrations.CredoCheck.MigrationsSafety, []} in CodeStyle.checks()
  end

  test "bundled checks assign an overlapping Enum.map Repo call to one owner" do
    source_file =
      to_source_file(
        """
        defmodule Example do
          @moduledoc false

          def load(users) do
            Enum.map(users, fn user ->
              Repo.get(User, user.id)
            end)
          end
        end
        """,
        "lib/example.ex"
      )

    owners =
      CodeStyle.checks()
      |> Enum.filter(fn {check, params} ->
        params != false and run_check(source_file, check, params) != []
      end)
      |> Enum.map(&elem(&1, 0))

    assert owners == [RepoInsideLoop]
  end
end
