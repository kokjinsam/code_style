defmodule CodeStyleTest do
  use Credo.Test.Case, async: false

  alias CodeStyle.Check.Warning.RepoInsideLoop

  @expected_ex_slop_checks [
    {ExSlop.Check.Warning.BlanketRescue, []},
    {ExSlop.Check.Warning.RescueWithoutReraise, []},
    {ExSlop.Check.Warning.RepoAllThenFilter, []},
    {ExSlop.Check.Warning.GenserverAsKvStore, []},
    {ExSlop.Check.Warning.PathExpandPriv, []},
    {ExSlop.Check.Warning.DualKeyAccess, []},
    {ExSlop.Check.Refactor.FilterNil, []},
    {ExSlop.Check.Refactor.RejectNil, []},
    {ExSlop.Check.Refactor.ReduceAsMap, []},
    {ExSlop.Check.Refactor.MapIntoLiteral, []},
    {ExSlop.Check.Refactor.IdentityPassthrough, []},
    {ExSlop.Check.Refactor.IdentityMap, []},
    {ExSlop.Check.Refactor.TryRescueWithSafeAlternative, []},
    {ExSlop.Check.Refactor.WithIdentityElse, []},
    {ExSlop.Check.Refactor.WithIdentityDo, []},
    {ExSlop.Check.Refactor.SortThenReverse, []},
    {ExSlop.Check.Refactor.StringConcatInReduce, []},
    {ExSlop.Check.Refactor.ReduceMapPut, []},
    {ExSlop.Check.Refactor.RedundantBooleanIf, []},
    {ExSlop.Check.Refactor.FlatMapFilter, []},
    {ExSlop.Check.Refactor.LengthComparison, []},
    {ExSlop.Check.Readability.NarratorDoc, []},
    {ExSlop.Check.Readability.BoilerplateDocParams, []},
    {ExSlop.Check.Readability.NarratorComment, []},
    {ExSlop.Check.Refactor.RedundantEnumJoinSeparator, []},
    {ExSlop.Check.Refactor.GraphemesLength, []},
    {ExSlop.Check.Refactor.ManualStringReverse, []},
    {ExSlop.Check.Refactor.SortThenAt, []},
    {ExSlop.Check.Refactor.SortForTopK, []},
    {ExSlop.Check.Refactor.ExplicitSumReduce, []},
    {ExSlop.Check.Readability.DocFalseOnPublicFunction, []},
    {ExSlop.Check.Readability.ObviousComment, []},
    {ExSlop.Check.Refactor.LengthInGuard, []},
    {ExSlop.Check.Refactor.ListFold, []},
    {ExSlop.Check.Refactor.ListLast, []},
    {ExSlop.Check.Refactor.PreferEnumSlice, []}
  ]

  test "registers custom Credo checks" do
    assert {CodeStyle.Check.Design.NoDatabaseConstraints, []} in CodeStyle.checks()
    assert {RepoInsideLoop, []} in CodeStyle.checks()
  end

  test "registers the complete curated ExSlop policy without duplicates" do
    ex_slop_checks =
      Enum.filter(CodeStyle.checks(), fn {check, _params} ->
        check
        |> Atom.to_string()
        |> String.starts_with?("Elixir.ExSlop.")
      end)

    assert ex_slop_checks == @expected_ex_slop_checks

    assert length(ex_slop_checks) ==
             ex_slop_checks
             |> MapSet.new()
             |> MapSet.size()
  end

  test "plugin config leaves file discovery to Credo or the consumer" do
    exec = Credo.Execution.ExecutionConfigFiles.start_server(%Credo.Execution{initializing_plugin: CodeStyle})

    on_exit(fn ->
      if Process.alive?(exec.config_files_pid), do: GenServer.stop(exec.config_files_pid)
    end)

    initialized_exec = CodeStyle.init(exec)
    [{:plugin, CodeStyle, config_source}] = Credo.Execution.get_config_files(initialized_exec)
    {config, []} = Code.eval_string(config_source)
    [default_config] = config.configs

    refute Map.has_key?(default_config, :files)
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
