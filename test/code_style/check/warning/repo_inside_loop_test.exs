defmodule CodeStyle.Check.Warning.RepoInsideLoopTest do
  use Credo.Test.Case, async: false

  alias CodeStyle.Check.Warning.RepoInsideLoop

  @enum_position_2 ~w(
    all? any? chunk_by count dedup_by drop_while each filter find
    find_index find_value flat_map frequencies_by group_by map map_join
    partition product_by reduce reject scan sort sort_by split_while split_with
    sum_by take_while uniq uniq_by
  )a
  @enum_position_3 ~w(
    find find_value flat_map_reduce into map_every map_intersperse map_join
    map_reduce reduce reduce_while scan
  )a
  @stream_position_2 ~w(
    chunk_by dedup_by drop_while each filter flat_map iterate map reject scan
    take_while unfold uniq uniq_by zip_with
  )a

  @enum_boundaries Enum.map(@enum_position_2, &{:Enum, &1, 2, [2]}) ++
                     Enum.map(@enum_position_3, &{:Enum, &1, 3, [3]}) ++
                     [
                       {:Enum, :filter_map, 3, [2, 3]},
                       {:Enum, :count_until, 3, [2]},
                       {:Enum, :group_by, 3, [2, 3]},
                       {:Enum, :sort_by, 3, [2, 3]},
                       {:Enum, :chunk_while, 4, [3]},
                       {:Enum, :zip_reduce, 3, [3]},
                       {:Enum, :zip_reduce, 4, [4]},
                       {:Enum, :zip_with, 2, [2]},
                       {:Enum, :zip_with, 3, [3]},
                       {:Enum, :max, 3, [2]},
                       {:Enum, :min, 3, [2]},
                       {:Enum, :min_max, 3, [2]},
                       {:Enum, :max_by, 2, [2]},
                       {:Enum, :max_by, 3, [2]},
                       {:Enum, :max_by, 4, [2, 3]},
                       {:Enum, :min_by, 2, [2]},
                       {:Enum, :min_by, 3, [2]},
                       {:Enum, :min_by, 4, [2, 3]},
                       {:Enum, :min_max_by, 2, [2]},
                       {:Enum, :min_max_by, 3, [2]},
                       {:Enum, :min_max_by, 4, [2, 3]}
                     ]

  @stream_boundaries Enum.map(@stream_position_2, &{:Stream, &1, 2, [2]}) ++
                       [
                         {:Stream, :repeatedly, 1, [1]},
                         {:Stream, :resource, 3, [2]},
                         {:Stream, :chunk_while, 4, [3]},
                         {:Stream, :into, 3, [3]},
                         {:Stream, :map_every, 3, [3]},
                         {:Stream, :scan, 3, [3]},
                         {:Stream, :transform, 3, [3]},
                         {:Stream, :transform, 4, [3]},
                         {:Stream, :transform, 5, [3]},
                         {:Stream, :zip_with, 3, [3]},
                         {:Stream, :filter_map, 3, [2, 3]}
                       ]

  @task_callback_boundaries [
    {:Task, :async_stream, 2, [2]},
    {:Task, :async_stream, 3, [2]},
    {Task.Supervisor, :async_stream, 3, [3]},
    {Task.Supervisor, :async_stream, 4, [3]},
    {Task.Supervisor, :async_stream_nolink, 3, [3]},
    {Task.Supervisor, :async_stream_nolink, 4, [3]}
  ]

  @task_mfa_boundaries [
    {:Task, :async_stream, 4, {2, 3, 4}},
    {:Task, :async_stream, 5, {2, 3, 4}},
    {Task.Supervisor, :async_stream, 5, {3, 4, 5}},
    {Task.Supervisor, :async_stream, 6, {3, 4, 5}},
    {Task.Supervisor, :async_stream_nolink, 5, {3, 4, 5}},
    {Task.Supervisor, :async_stream_nolink, 6, {3, 4, 5}}
  ]

  @repo_functions ~w(
    aggregate all all_by delete_all exists? get get! get_by get_by! one one!
    stream update_all query query! delete delete! insert insert! insert_all
    insert_or_update insert_or_update! preload reload reload! update update!
    checkout transact transaction
  )a

  test "reports Repo calls inside Enum callbacks" do
    """
    defmodule Example do
      alias MyApp.Repo

      def load(users) do
        Enum.map(users, fn user ->
          Repo.get(User, user.id)
        end)
      end
    end
    """
    |> to_source_file()
    |> run_check(RepoInsideLoop)
    |> assert_issue(%{
      line_no: 6,
      trigger: "Repo.get",
      message:
        "Repo call in repeated execution can cause repeated database work. Batch or preload before iterating when possible."
    })
  end

  test "reports Repo preload inside for comprehensions" do
    """
    defmodule Example do
      def load(users) do
        for user <- users do
          MyApp.Repo.preload(user, :posts)
        end
      end
    end
    """
    |> to_source_file()
    |> run_check(RepoInsideLoop)
    |> assert_issue(%{
      line_no: 4,
      trigger: "MyApp.Repo.preload"
    })
  end

  test "reports Repo calls inside Stream callbacks" do
    """
    defmodule Example do
      def load(users) do
        Stream.map(users, fn user ->
          MyApp.Repo.all(from p in Post, where: p.user_id == ^user.id)
        end)
      end
    end
    """
    |> to_source_file()
    |> run_check(RepoInsideLoop)
    |> assert_issue(%{
      line_no: 4,
      trigger: "MyApp.Repo.all"
    })
  end

  test "reports Repo calls inside piped Enum callbacks" do
    """
    defmodule Example do
      alias MyApp.Repo

      def load(users) do
        users
        |> Enum.map(fn user ->
          Repo.get(User, user.id)
        end)
      end
    end
    """
    |> to_source_file()
    |> run_check(RepoInsideLoop)
    |> assert_issue(%{
      line_no: 7,
      trigger: "Repo.get"
    })
  end

  test "does not report Repo calls before the loop body" do
    """
    defmodule Example do
      alias MyApp.Repo

      def names do
        Repo.all(User)
        |> Enum.map(fn user -> user.name end)
      end
    end
    """
    |> to_source_file()
    |> run_check(RepoInsideLoop)
    |> refute_issues()
  end

  test "does not report Repo calls used as the loop input" do
    """
    defmodule Example do
      alias MyApp.Repo

      def names do
        Enum.map(Repo.all(User), fn user -> user.name end)
      end
    end
    """
    |> to_source_file()
    |> run_check(RepoInsideLoop)
    |> refute_issues()
  end

  test "does not report Repo calls used to construct the callback" do
    """
    defmodule Example do
      alias MyApp.Repo

      def load(users) do
        Enum.map(users, callback(Repo.all(User)))
      end
    end
    """
    |> to_source_file()
    |> run_check(RepoInsideLoop)
    |> refute_issues()
  end

  test "does not report Repo calls in a nested function returned by a callback" do
    """
    defmodule Example do
      alias MyApp.Repo

      def loaders(users) do
        Enum.map(users, fn user ->
          fn -> Repo.get(User, user.id) end
        end)
      end
    end
    """
    |> to_source_file()
    |> run_check(RepoInsideLoop)
    |> refute_issues()
  end

  test "reports Repo calls in direct function callbacks and captures" do
    """
    defmodule Example do
      alias MyApp.Repo

      def load(users) do
        Enum.map(users, fn user -> Repo.get(User, user.id) end)
        Enum.map(users, &Repo.get(User, &1))
      end
    end
    """
    |> to_source_file()
    |> run_check(RepoInsideLoop)
    |> assert_issues(fn issues ->
      assert Enum.map(issues, &{&1.line_no, &1.trigger}) == [
               {5, "Repo.get"},
               {6, "Repo.get"}
             ]
    end)
  end

  test "does not traverse quoted code as executable code" do
    """
    defmodule Example do
      alias MyApp.Repo

      def expressions(users) do
        Enum.map(users, fn user ->
          quote do
            Repo.get(User, unquote(user.id))
          end
        end)
      end
    end
    """
    |> to_source_file()
    |> run_check(RepoInsideLoop)
    |> refute_issues()
  end

  test "direct and piped calls apply the same execution contexts" do
    direct = """
    defmodule Direct do
      alias MyApp.Repo

      def load(users) do
        Enum.reduce(Repo.all(User), Repo.all(Acc), fn user, acc ->
          Repo.get(User, user.id) || acc
        end)
      end
    end
    """

    piped = """
    defmodule Piped do
      alias MyApp.Repo

      def load(users) do
        Repo.all(User)
        |> Enum.reduce(Repo.all(Acc), fn user, acc ->
          Repo.get(User, user.id) || acc
        end)
      end
    end
    """

    for source <- [direct, piped] do
      issues =
        source
        |> to_source_file()
        |> run_check(RepoInsideLoop)

      assert Enum.map(issues, & &1.trigger) == ["Repo.get"]
    end
  end

  test "for evaluates qualifiers sequentially and keeps options in the inherited context" do
    """
    defmodule Example do
      alias MyApp.Repo

      def load do
        for user <- Repo.all(User),
            Repo.exists?(user),
            post <- Repo.all(Post),
            into: Repo.all(Result) do
          Repo.get(Post, post.id)
        end

        for user <- Repo.all(User), reduce: Repo.all(Result) do
          acc -> Repo.update(acc || user)
        end
      end
    end
    """
    |> to_source_file()
    |> run_check(RepoInsideLoop)
    |> assert_issues(fn issues ->
      assert Enum.map(issues, &{&1.line_no, &1.trigger}) == [
               {6, "Repo.exists?"},
               {7, "Repo.all"},
               {9, "Repo.get"},
               {13, "Repo.update"}
             ]
    end)
  end

  test "once-evaluated nested loop expressions inherit the enclosing repeated context" do
    """
    defmodule Example do
      alias MyApp.Repo

      def load(groups) do
        Enum.map(groups, fn group ->
          Enum.map(Repo.all(User), callback(Repo.all(User)))

          for user <- Repo.all(User), into: Repo.all(Result) do
            {group, user}
          end
        end)
      end
    end
    """
    |> to_source_file()
    |> run_check(RepoInsideLoop)
    |> assert_issues(fn issues ->
      assert Enum.map(issues, &{&1.line_no, &1.trigger}) == [
               {6, "Repo.all"},
               {6, "Repo.all"},
               {8, "Repo.all"},
               {8, "Repo.all"}
             ]
    end)
  end

  test "nested recognized boundaries emit one issue per Repo call" do
    issues =
      """
      defmodule Example do
        alias MyApp.Repo

        def load(users, posts) do
          Enum.map(users, fn user ->
            Enum.map(posts, fn post -> Repo.get(Post, {user.id, post.id}) end)
          end)
        end
      end
      """
      |> to_source_file()
      |> run_check(RepoInsideLoop)

    assert Enum.map(issues, & &1.trigger) == ["Repo.get"]
  end

  test "covers every exact Enum callback position in direct and piped calls" do
    for descriptor <- @enum_boundaries,
        syntax <- [:direct, :piped] do
      assert_boundary_issues(descriptor, syntax)
    end
  end

  test "count_until/3 repeats argument 2 in direct and piped calls" do
    """
    defmodule Example do
      def run(values) do
        Enum.count_until(values, fn value -> Repo.get(User, value) end, 10)
        values |> Enum.count_until(fn value -> Repo.get(User, value) end, 10)
      end
    end
    """
    |> to_source_file()
    |> run_check(RepoInsideLoop)
    |> assert_issues(fn issues ->
      assert Enum.map(issues, & &1.trigger) == ["Repo.get", "Repo.get"]
    end)
  end

  test "count_until/3 evaluates its limit once in the inherited context" do
    top_level = """
    defmodule TopLevel do
      def run(values) do
        Enum.count_until(values, fn value -> value end, limit(Repo.get(Config, :limit)))
      end
    end
    """

    nested = """
    defmodule Nested do
      def run(groups, values) do
        Enum.each(groups, fn _group ->
          Enum.count_until(values, fn value -> value end, limit(Repo.get(Config, :limit)))
        end)
      end
    end
    """

    top_level
    |> to_source_file()
    |> run_check(RepoInsideLoop)
    |> refute_issues()

    nested
    |> to_source_file()
    |> run_check(RepoInsideLoop)
    |> assert_issue(%{trigger: "Repo.get"})
  end

  test "covers every exact Stream callback position in direct and piped calls" do
    for descriptor <- @stream_boundaries,
        syntax <- [:direct, :piped] do
      assert_boundary_issues(descriptor, syntax)
    end
  end

  test "covers every Task callback boundary in direct and piped calls" do
    for descriptor <- @task_callback_boundaries,
        syntax <- [:direct, :piped] do
      assert_boundary_issues(descriptor, syntax)
    end
  end

  test "covers every Task MFA boundary in direct and piped calls" do
    for descriptor <- @task_mfa_boundaries,
        syntax <- [:direct, :piped] do
      source = mfa_boundary_source(descriptor, syntax)

      issues =
        source
        |> to_source_file()
        |> run_check(RepoInsideLoop)

      assert Enum.map(issues, & &1.trigger) == ["Repo.get"],
             "expected #{inspect(descriptor)} in #{syntax} form to report its Repo MFA target"
    end
  end

  test "covers every default Repo operation" do
    for operation <- @repo_functions do
      issues =
        """
        defmodule Example do
          def run(values) do
            Enum.map(values, fn value -> Repo.#{operation}(value) end)
          end
        end
        """
        |> to_source_file()
        |> run_check(RepoInsideLoop)

      assert Enum.map(issues, & &1.trigger) == ["Repo.#{operation}"],
             "expected Repo.#{operation} to be covered"
    end
  end

  test "recognizes only callable with_index and from_index forms" do
    """
    defmodule Example do
      def run(values) do
        Enum.with_index(values, fn value, index -> Repo.get(value, index) end)
        values |> Enum.with_index(&Repo.get(&1, &2))
        Stream.with_index(values, fn value, index -> Repo.get(value, index) end)
        values |> Stream.with_index(&Repo.get(&1, &2))
        Stream.from_index(fn index -> Repo.get(User, index) end)
        (fn index -> Repo.get(User, index) end) |> Stream.from_index()

        Enum.with_index(values, Repo.get(Config, :offset))
        Stream.with_index(values, Repo.get(Config, :offset))
        Stream.from_index(Repo.get(Config, :offset))
      end
    end
    """
    |> to_source_file()
    |> run_check(RepoInsideLoop)
    |> assert_issues(fn issues ->
      assert Enum.map(issues, & &1.trigger) == List.duplicate("Repo.get", 6)
    end)
  end

  test "distinguishes the overloaded min_max/2 callback by callable arity" do
    """
    defmodule Example do
      def run(values) do
        Enum.min_max(values, fn left, right -> Repo.get(left, right) end)
        Enum.min_max(values, &Repo.get/2)
        Enum.min_max(values, fn -> Repo.get(Config, :empty) end)
        Enum.min_max(values, &Repo.get/0)
      end
    end
    """
    |> to_source_file()
    |> run_check(RepoInsideLoop)
    |> assert_issues(fn issues ->
      assert Enum.map(issues, & &1.trigger) == ["Repo.get", "Repo.get"]
    end)
  end

  test "keeps ordering empty fallbacks once while repeating comparators and mappers" do
    """
    defmodule Example do
      def run(values) do
        Enum.max(values, fn left, right -> Repo.get(left, right) end, fn -> Repo.all(Empty) end)
        Enum.min(values, fn left, right -> Repo.get(left, right) end, fn -> Repo.all(Empty) end)
        Enum.min_max(values, fn left, right -> Repo.get(left, right) end, fn -> Repo.all(Empty) end)

        Enum.max_by(values, fn value -> Repo.get(Item, value) end, fn -> Repo.all(Empty) end)

        Enum.min_by(
          values,
          fn value -> Repo.get(Item, value) end,
          fn left, right -> Repo.get(left, right) end,
          fn -> Repo.all(Empty) end
        )

        Enum.min_max_by(values, fn value -> Repo.get(Item, value) end, fn -> Repo.all(Empty) end)
      end
    end
    """
    |> to_source_file()
    |> run_check(RepoInsideLoop)
    |> assert_issues(fn issues ->
      assert Enum.map(issues, & &1.trigger) == List.duplicate("Repo.get", 7)
    end)
  end

  test "max/2 and min/2 fallbacks are once-only at top level" do
    """
    defmodule Example do
      def run(values) do
        Enum.max(values, fn -> Repo.all(Empty) end)
        values |> Enum.min(fn -> Repo.all(Empty) end)
      end
    end
    """
    |> to_source_file()
    |> run_check(RepoInsideLoop)
    |> refute_issues()
  end

  test "max/2 and min/2 fallbacks inherit an outer repeated context" do
    """
    defmodule Example do
      def run(groups, values) do
        Enum.each(groups, fn _group ->
          Enum.max(values, fn -> Repo.all(Empty) end)
          values |> Enum.min(fn -> Repo.all(Empty) end)
        end)
      end
    end
    """
    |> to_source_file()
    |> run_check(RepoInsideLoop)
    |> assert_issues(fn issues ->
      assert Enum.map(issues, & &1.trigger) == ["Repo.all", "Repo.all"]
    end)
  end

  test "keeps Stream start and finalizer callbacks once per enumeration" do
    """
    defmodule Example do
      def run(values) do
        Stream.resource(
          fn -> Repo.all(Start) end,
          fn state -> Repo.get(Next, state) end,
          fn state -> Repo.update(state) end
        )

        Stream.chunk_while(
          values,
          Repo.all(Acc),
          fn value, acc -> Repo.get(value, acc) end,
          fn acc -> Repo.update(acc) end
        )

        Stream.transform(
          values,
          fn -> Repo.all(Start) end,
          fn value, acc -> Repo.get(value, acc) end,
          fn acc -> Repo.one(acc) end,
          fn acc -> Repo.update(acc) end
        )
      end
    end
    """
    |> to_source_file()
    |> run_check(RepoInsideLoop)
    |> assert_issues(fn issues ->
      assert Enum.map(issues, &{&1.line_no, &1.trigger}) == [
               {5, "Repo.get"},
               {12, "Repo.get"},
               {19, "Repo.get"}
             ]
    end)
  end

  test "once-per-enumeration callbacks inherit an enclosing repeated context" do
    """
    defmodule Example do
      def run(groups, values) do
        Enum.map(groups, fn _group ->
          Enum.max(values, fn left, right -> left >= right end, fn -> Repo.all(Empty) end)

          Stream.resource(
            fn -> Repo.all(Start) end,
            fn state -> {[state], state} end,
            fn state -> Repo.update(state) end
          )

          Stream.transform(
            values,
            fn -> Repo.all(Start) end,
            fn value, acc -> {[value], acc} end,
            fn acc -> Repo.one(acc) end,
            fn acc -> Repo.update(acc) end
          )
        end)
      end
    end
    """
    |> to_source_file()
    |> run_check(RepoInsideLoop)
    |> assert_issues(fn issues ->
      assert Enum.map(issues, & &1.trigger) == [
               "Repo.all",
               "Repo.all",
               "Repo.update",
               "Repo.all",
               "Repo.one",
               "Repo.update"
             ]
    end)
  end

  test "transform/3 treats argument 2 as accumulator data, not an executed callback" do
    issues =
      """
      defmodule Example do
        def run(groups, values) do
          Enum.each(groups, fn _group ->
            Stream.transform(
              values,
              fn -> Repo.all(AccumulatorData) end,
              fn value, acc -> Repo.get(value, acc) end
            )
          end)
        end
      end
      """
      |> to_source_file()
      |> run_check(RepoInsideLoop)

    assert Enum.map(issues, & &1.trigger) == ["Repo.get"]
  end

  test "does not treat non-callback arguments as repeated execution" do
    """
    defmodule Example do
      def run(values) do
        Enum.reduce(Repo.all(Input), Repo.all(Acc), fn value, acc -> value || acc end)
        Enum.map_every(Repo.all(Input), Repo.get(Config, :step), fn value -> value end)
        Stream.into(Repo.all(Input), Repo.all(Target), fn value -> value end)
        Task.async_stream(Repo.all(Input), fn value -> value end, Repo.all(Options))
      end
    end
    """
    |> to_source_file()
    |> run_check(RepoInsideLoop)
    |> refute_issues()
  end

  test "requires exact boundary and Repo alias paths" do
    """
    defmodule Example do
      def run(values) do
        Elixir.Enum.map(values, fn value -> Elixir.MyApp.Repo.get(User, value) end)
        Elixir.Stream.map(values, fn value -> Repo.get(User, value) end)
        Elixir.Task.async_stream(values, fn value -> MyApp.Repo.get(User, value) end)

        My.Enum.map(values, fn value -> Repo.get(User, value) end)
        Enum.Helpers.map(values, fn value -> Repo.get(User, value) end)
        SomeEnumerable.map(values, fn value -> Repo.get(User, value) end)

        Enum.map(values, fn value -> MyApp.Repo.Helpers.get(User, value) end)
        Enum.map(values, fn value -> SomeRepository.get(User, value) end)
        Enum.map(values, fn value -> repo.get(User, value) end)
        Enum.map(values, fn value -> module().get(User, value) end)
      end
    end
    """
    |> to_source_file()
    |> run_check(RepoInsideLoop)
    |> assert_issues(fn issues ->
      assert Enum.map(issues, & &1.trigger) == [
               "Elixir.MyApp.Repo.get",
               "Repo.get",
               "MyApp.Repo.get"
             ]
    end)
  end

  test "defers callback variables and factories" do
    """
    defmodule Example do
      def run(values, callback) do
        Enum.map(values, callback)
        Stream.map(values, callback_factory(Repo.all(Config)))
        Task.async_stream(values, callback_factory(Repo.all(Config)))
      end
    end
    """
    |> to_source_file()
    |> run_check(RepoInsideLoop)
    |> refute_issues()
  end

  test "single-task APIs bridge execution without creating top-level repetition" do
    """
    defmodule Example do
      def run(supervisor) do
        Task.async(fn -> Repo.get(User, 1) end)
        Task.async(Repo, :get, [User, 1])
        Task.start(fn -> Repo.get(User, 1) end)
        Task.start(Repo, :get, [User, 1])
        Task.start_link(fn -> Repo.get(User, 1) end)
        Task.start_link(Repo, :get, [User, 1])
        Task.Supervisor.async(supervisor, fn -> Repo.get(User, 1) end)
        Task.Supervisor.async(supervisor, Repo, :get, [User, 1])
        Task.Supervisor.async_nolink(supervisor, fn -> Repo.get(User, 1) end)
        Task.Supervisor.async_nolink(supervisor, Repo, :get, [User, 1])
        Task.Supervisor.start_child(supervisor, fn -> Repo.get(User, 1) end)
        Task.Supervisor.start_child(supervisor, Repo, :get, [User, 1])
      end
    end
    """
    |> to_source_file()
    |> run_check(RepoInsideLoop)
    |> refute_issues()
  end

  test "single-task APIs inherit an enclosing repeated context and report once" do
    """
    defmodule Example do
      def run(values, supervisor) do
        Enum.map(values, fn value ->
          Task.async(fn -> Repo.get(User, value) end)
          Task.start(Repo, :get, [User, value])
          Task.Supervisor.async_nolink(supervisor, fn -> Repo.get(User, value) end)
          Task.Supervisor.start_child(supervisor, Repo, :get, [User, value])
        end)
      end
    end
    """
    |> to_source_file()
    |> run_check(RepoInsideLoop)
    |> assert_issues(fn issues ->
      assert Enum.map(issues, & &1.trigger) == List.duplicate("Repo.get", 4)
    end)
  end

  test "Task MFA args and options stay inherited while the literal Repo target repeats" do
    """
    defmodule Example do
      def run(values, supervisor) do
        Task.async_stream(values, Repo, :get, Repo.all(Args), Repo.all(Options))

        Task.Supervisor.async_stream_nolink(
          supervisor,
          values,
          Repo,
          :get,
          Repo.all(Args),
          Repo.all(Options)
        )

        Task.async_stream(values, Accounts, :get, Repo.all(Args), Repo.all(Options))
      end
    end
    """
    |> to_source_file()
    |> run_check(RepoInsideLoop)
    |> assert_issues(fn issues ->
      assert Enum.map(issues, & &1.trigger) == ["Repo.get", "Repo.get"]
    end)
  end

  test "excludes pure, introspective, configuration, and process Repo functions" do
    """
    defmodule Example do
      def run(values) do
        Enum.map(values, fn value ->
          Repo.load(value)
          Repo.checked_out?()
          Repo.in_transaction?()
          Repo.default_options(:all)
          Repo.config()
          Repo.all_running()
          Repo.put_dynamic_repo(value)
          Repo.get_dynamic_repo()
        end)
      end
    end
    """
    |> to_source_file()
    |> run_check(RepoInsideLoop)
    |> refute_issues()
  end

  test "does not report non-Repo calls inside loop callbacks" do
    """
    defmodule Example do
      def load(users) do
        Enum.map(users, fn user ->
          Accounts.get_user(user.id)
        end)
      end
    end
    """
    |> to_source_file()
    |> run_check(RepoInsideLoop)
    |> refute_issues()
  end

  test "does not report non-Repo modules using Repo function names" do
    """
    defmodule Example do
      def unload(modules) do
        for module <- modules do
          :code.delete(module)
        end
      end
    end
    """
    |> to_source_file()
    |> run_check(RepoInsideLoop)
    |> refute_issues()
  end

  defp assert_boundary_issues({module, function, arity, positions} = descriptor, syntax) do
    issues =
      descriptor
      |> boundary_source(syntax)
      |> to_source_file()
      |> run_check(RepoInsideLoop)

    assert Enum.map(issues, & &1.trigger) == List.duplicate("Repo.all", length(positions)),
           "expected #{module}.#{function}/#{arity} in #{syntax} form to repeat #{inspect(positions)}"
  end

  defp boundary_source({module, function, arity, positions}, syntax) do
    arguments =
      for position <- 1..arity do
        if position in positions do
          "fn value -> Repo.all(value) end"
        else
          "value"
        end
      end

    call = call_source(module, function, arguments, syntax)

    """
    defmodule Example do
      def run(value) do
        #{call}
      end
    end
    """
  end

  defp mfa_boundary_source({module, function, arity, {module_position, function_position, args_position}}, syntax) do
    arguments =
      for position <- 1..arity do
        cond do
          position == module_position -> "Repo"
          position == function_position -> ":get"
          position == args_position -> "[User, value]"
          true -> "value"
        end
      end

    call = call_source(module, function, arguments, syntax)

    """
    defmodule Example do
      def run(value) do
        #{call}
      end
    end
    """
  end

  defp call_source(module, function, arguments, :direct) do
    "#{module_source(module)}.#{function}(#{Enum.join(arguments, ", ")})"
  end

  defp call_source(module, function, [input | arguments], :piped) do
    "#{input} |> #{module_source(module)}.#{function}(#{Enum.join(arguments, ", ")})"
  end

  defp module_source(:Enum), do: "Enum"
  defp module_source(:Stream), do: "Stream"
  defp module_source(:Task), do: "Task"
  defp module_source(Task.Supervisor), do: "Task.Supervisor"
end
