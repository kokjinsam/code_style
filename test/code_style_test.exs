defmodule CodeStyleTest do
  use Credo.Test.Case, async: false

  alias CodeStyle.Check.Warning.EnvironmentVariableAccess
  alias CodeStyle.Check.Warning.RepoInsideLoop
  alias Credo.Check.Readability.BlockPipe

  @expected_jump_checks [
    {Jump.CredoChecks.AssertElementSelectorCanNeverFail, []},
    {Jump.CredoChecks.AvoidFunctionLevelElse, []},
    {Jump.CredoChecks.AvoidModifyingStructBeforeChangeset, []},
    {Jump.CredoChecks.AvoidSocketAssignsInTest, []},
    {Jump.CredoChecks.ConditionalAssertion, []},
    {Jump.CredoChecks.LiveViewFormCanBeRehydrated, []},
    {Jump.CredoChecks.LiveViewPubSubRequiresConnected, []},
    {Jump.CredoChecks.NoManualContentDisposition, []},
    {Jump.CredoChecks.SafeBinaryToTerm, []},
    {Jump.CredoChecks.UndeclaredExternalResource, []},
    {Jump.CredoChecks.WeakAssertion, []}
  ]

  @expected_credo_mox_checks [
    {CredoMox.Checks.UnverifiedMox, [files: %{included: ["**/*_test.exs"]}]}
  ]

  @expected_forge_checks [
    {ForgeCredoChecks.FilterMap, []},
    {ForgeCredoChecks.RejectMap, []},
    {ForgeCredoChecks.MapReject, []},
    {ForgeCredoChecks.MapGetWithOr, []},
    {ForgeCredoChecks.InconsistentParamNames, []},
    {ForgeCredoChecks.NamespaceTrespassing, []},
    {ForgeCredoChecks.NoSourceInspectionInTest, []},
    {ForgeCredoChecks.NoDetsInfoOpenGuard, []}
  ]

  @expected_ex_slop_checks [
    {ExSlop.Check.Warning.BlanketRescue, []},
    {ExSlop.Check.Warning.RescueWithoutReraise, []},
    {ExSlop.Check.Warning.RepoAllThenFilter, []},
    {ExSlop.Check.Warning.GenserverAsKvStore, []},
    {ExSlop.Check.Warning.PathExpandPriv, []},
    {ExSlop.Check.Warning.DualKeyAccess, []},
    {ExSlop.Check.Refactor.FilterNil, []},
    {ExSlop.Check.Refactor.RejectNil, []},
    {ExSlop.Check.Refactor.WithIdentityDo, []},
    {ExSlop.Check.Refactor.ReduceMapPut, []},
    {ExSlop.Check.Refactor.LengthComparison, []},
    {ExSlop.Check.Readability.NarratorDoc, []},
    {ExSlop.Check.Readability.BoilerplateDocParams, []},
    {ExSlop.Check.Readability.NarratorComment, []},
    {ExSlop.Check.Refactor.RedundantEnumJoinSeparator, []},
    {ExSlop.Check.Refactor.GraphemesLength, []},
    {ExSlop.Check.Refactor.ManualStringReverse, []},
    {ExSlop.Check.Refactor.SortForTopK, []},
    {ExSlop.Check.Refactor.ExplicitSumReduce, []},
    {ExSlop.Check.Readability.DocFalseOnPublicFunction, []},
    {ExSlop.Check.Readability.ObviousComment, []},
    {ExSlop.Check.Refactor.LengthInGuard, []}
  ]

  test "BlockPipe backstops multi-stage pipelines ending in block expressions" do
    assert {BlockPipe, []} in CodeStyle.checks()

    """
    defmodule Example do
      @moduledoc false

      def classify(items) do
        items
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
        |> case do
          [] -> :empty
          _items -> :present
        end
      end
    end
    """
    |> to_source_file("lib/example.ex")
    |> run_check(BlockPipe)
    |> assert_issue(%{trigger: "|>"})
  end

  test "registers custom Credo checks" do
    assert {EnvironmentVariableAccess, []} in CodeStyle.checks()
    assert {RepoInsideLoop, []} in CodeStyle.checks()
  end

  test "registers exact third-party allowlists without duplicates" do
    assert provider_checks("Elixir.Jump.CredoChecks.") == @expected_jump_checks
    assert provider_checks("Elixir.CredoMox.") == @expected_credo_mox_checks
    assert provider_checks("Elixir.ForgeCredoChecks.") == @expected_forge_checks
    assert provider_checks("Elixir.ExSlop.") == @expected_ex_slop_checks

    all_third_party =
      @expected_jump_checks ++
        @expected_credo_mox_checks ++
        @expected_forge_checks ++
        @expected_ex_slop_checks

    assert length(all_third_party) == all_third_party |> MapSet.new() |> MapSet.size()
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
      for {check, params} <- CodeStyle.checks(),
          params != false,
          run_check(source_file, check, params) != [] do
        check
      end

    assert owners == [RepoInsideLoop]
  end

  defp provider_checks(prefix) do
    Enum.filter(CodeStyle.checks(), fn {check, _params} ->
      check
      |> Atom.to_string()
      |> String.starts_with?(prefix)
    end)
  end
end
