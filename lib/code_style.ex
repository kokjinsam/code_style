defmodule CodeStyle do
  @moduledoc """
  Shared Credo policy and custom checks for Elixir codebases.
  """

  import Credo.Plugin

  @credo_checks [
    # Consistency Checks
    {Credo.Check.Consistency.ExceptionNames, []},
    {Credo.Check.Consistency.LineEndings, []},
    {Credo.Check.Consistency.SpaceAroundOperators, []},
    {Credo.Check.Consistency.SpaceInParentheses, []},
    {Credo.Check.Consistency.TabsOrSpaces, []},
    {Credo.Check.Consistency.UnusedVariableNames, [force: :meaningful]},

    # Design Checks
    {Credo.Check.Design.SkipTestWithoutComment, []},
    {Credo.Check.Design.TagFIXME, []},
    {Credo.Check.Design.TagTODO, [exit_status: 2]},

    # Readability Checks
    {Credo.Check.Readability.AliasAs, []},
    {Credo.Check.Readability.FunctionNames, []},
    {Credo.Check.Readability.ImplTrue, []},
    {Credo.Check.Readability.MaxLineLength, [priority: :low, max_length: 120]},
    {Credo.Check.Readability.ModuleAttributeNames, []},
    {Credo.Check.Readability.ModuleNames, []},
    {Credo.Check.Readability.NestedFunctionCalls, []},
    {Credo.Check.Readability.ParenthesesInCondition, []},
    {Credo.Check.Readability.PredicateFunctionNames, []},
    {Credo.Check.Readability.PreferUnquotedAtoms, false},
    {Credo.Check.Readability.RedundantBlankLines, []},
    {Credo.Check.Readability.Semicolons, []},
    {Credo.Check.Readability.SeparateAliasRequire, []},
    {Credo.Check.Readability.SingleFunctionToBlockPipe, []},
    {Credo.Check.Readability.SpaceAfterCommas, []},
    {Credo.Check.Readability.Specs, false},
    {Credo.Check.Readability.TrailingBlankLine, []},
    {Credo.Check.Readability.TrailingWhiteSpace, []},
    {Credo.Check.Readability.VariableNames, []},
    {Credo.Check.Readability.WithCustomTaggedTuple, []},

    # Refactoring Opportunities
    {Credo.Check.Refactor.ABCSize, false},
    {Credo.Check.Refactor.AppendSingleItem, []},
    {Credo.Check.Refactor.Apply, []},
    {Credo.Check.Refactor.CondInsteadOfIfElse, false},
    {Credo.Check.Refactor.CyclomaticComplexity, []},
    {Credo.Check.Refactor.DoubleBooleanNegation, []},
    {Credo.Check.Refactor.FilterFilter, []},
    {Credo.Check.Refactor.FilterReject, []},
    {Credo.Check.Refactor.FunctionArity, []},
    {Credo.Check.Refactor.IoPuts, []},
    {Credo.Check.Refactor.LongQuoteBlocks, []},
    {Credo.Check.Refactor.MapMap, []},
    {Credo.Check.Refactor.MatchInCondition, []},
    {Credo.Check.Refactor.ModuleDependencies, false},
    {Credo.Check.Refactor.NegatedIsNil, []},
    {Credo.Check.Refactor.Nesting, []},
    {Credo.Check.Refactor.PassAsyncInTestCases, false},
    {Credo.Check.Refactor.PerceivedComplexity, []},
    {Credo.Check.Refactor.RejectFilter, []},
    {Credo.Check.Refactor.RejectReject, []},
    {Credo.Check.Refactor.UtcNowTruncate, []},
    {Credo.Check.Refactor.VariableRebinding, []},

    # Warnings
    {Credo.Check.Warning.ApplicationConfigInModuleAttribute, []},
    {Credo.Check.Warning.BoolOperationOnSameValues, []},
    {Credo.Check.Warning.Dbg, []},
    {Credo.Check.Warning.ExpensiveEmptyEnumCheck, []},
    {Credo.Check.Warning.IExPry, []},
    {Credo.Check.Warning.IoInspect, []},
    {Credo.Check.Warning.LeakyEnvironment, []},
    {Credo.Check.Warning.MapGetUnsafePass, []},
    {Credo.Check.Warning.MissedMetadataKeyInLoggerConfig, []},
    {Credo.Check.Warning.MixEnv, []},
    {Credo.Check.Warning.OperationOnSameValues, []},
    {Credo.Check.Warning.OperationWithConstantResult, []},
    {Credo.Check.Warning.RaiseInsideRescue, []},
    {Credo.Check.Warning.SpecWithStruct, []},
    {Credo.Check.Warning.StructFieldAmount, []},
    {Credo.Check.Warning.UnsafeExec, []},
    {Credo.Check.Warning.UnsafeToAtom, []},
    {Credo.Check.Warning.UnusedEnumOperation, []},
    {Credo.Check.Warning.UnusedFileOperation, []},
    {Credo.Check.Warning.UnusedKeywordOperation, []},
    {Credo.Check.Warning.UnusedListOperation, []},
    {Credo.Check.Warning.UnusedMapOperation, []},
    {Credo.Check.Warning.UnusedPathOperation, []},
    {Credo.Check.Warning.UnusedRegexOperation, []},
    {Credo.Check.Warning.UnusedStringOperation, []},
    {Credo.Check.Warning.UnusedTupleOperation, []},
    {Credo.Check.Warning.WrongTestFilename, []},

    # ExDNA owns duplicated-code analysis.
    {Credo.Check.Design.DuplicatedCode, false},

    # Styler owns these rewrites.
    {Credo.Check.Consistency.MultiAliasImportRequireUse, false},
    {Credo.Check.Consistency.ParameterPatternMatching, false},
    {Credo.Check.Design.AliasUsage, false},
    {Credo.Check.Readability.AliasOrder, false},
    {Credo.Check.Readability.BlockPipe, false},
    {Credo.Check.Readability.LargeNumbers, false},
    {Credo.Check.Readability.ModuleDoc, false},
    {Credo.Check.Readability.MultiAlias, false},
    {Credo.Check.Readability.OneArityFunctionInPipe, false},
    {Credo.Check.Readability.OnePipePerLine, false},
    {Credo.Check.Readability.ParenthesesOnZeroArityDefs, false},
    {Credo.Check.Readability.PipeIntoAnonymousFunctions, false},
    {Credo.Check.Readability.PreferImplicitTry, false},
    {Credo.Check.Readability.SinglePipe, false},
    {Credo.Check.Readability.StrictModuleLayout, false},
    {Credo.Check.Readability.StringSigils, false},
    {Credo.Check.Readability.UnnecessaryAliasExpansion, false},
    {Credo.Check.Readability.WithSingleClause, false},
    {Credo.Check.Refactor.CaseTrivialMatches, false},
    {Credo.Check.Refactor.CondStatements, false},
    {Credo.Check.Refactor.FilterCount, false},
    {Credo.Check.Refactor.MapInto, false},
    {Credo.Check.Refactor.MapJoin, false},
    {Credo.Check.Refactor.NegatedConditionsInUnless, false},
    {Credo.Check.Refactor.NegatedConditionsWithElse, false},
    {Credo.Check.Refactor.PipeChainStart, false},
    {Credo.Check.Refactor.RedundantWithClauseResult, false},
    {Credo.Check.Refactor.UnlessWithElse, false},
    {Credo.Check.Refactor.WithClauses, false},

    # Deprecated.
    {Credo.Check.Warning.LazyLogging, false}
  ]

  @code_style_checks [
    {CodeStyle.Check.Design.NoDatabaseConstraints, []},
    {CodeStyle.Check.Warning.RepoInsideLoop, []}
  ]

  @migration_checks [
    {ExcellentMigrations.CredoCheck.MigrationsSafety, []}
  ]

  @ex_slop_opt_in_checks [
    {ExSlop.Check.Readability.DocFalseOnPublicFunction, []},
    {ExSlop.Check.Readability.ObviousComment, []},
    {ExSlop.Check.Refactor.LengthInGuard, []},
    {ExSlop.Check.Refactor.ListFold, []},
    {ExSlop.Check.Refactor.ListLast, []},
    {ExSlop.Check.Refactor.PreferEnumSlice, []}
  ]

  @checks @credo_checks ++
            @code_style_checks ++
            @migration_checks ++
            Enum.map(ExSlop.recommended_checks(), &{&1, []}) ++
            @ex_slop_opt_in_checks

  @default_config inspect(
                    %{
                      configs: [
                        %{
                          name: "default",
                          files: %{
                            included: [
                              "lib/",
                              "config/",
                              "priv/repo/migrations/",
                              "test/",
                              "apps/*/lib/",
                              "apps/*/config/",
                              "apps/*/priv/repo/migrations/",
                              "apps/*/test/"
                            ],
                            excluded: [~r"/_build/", ~r"/deps/", ~r"/node_modules/"]
                          },
                          strict: true,
                          checks: %{extra: @checks}
                        }
                      ]
                    },
                    limit: :infinity
                  )

  @doc false
  def init(exec) do
    register_default_config(exec, @default_config)
  end

  @doc """
  Returns the Credo checks registered by the shared style policy.
  """
  def checks, do: @checks
end
