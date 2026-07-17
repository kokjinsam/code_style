defmodule CodeStyle.Check.Design.NoDatabaseConstraints do
  @moduledoc false

  use Credo.Check,
    base_priority: :higher,
    category: :design,
    explanations: [
      check: """
      Avoid setting business-logic column constraints in Ecto migrations.

      This check resolves direct and aliased `use Ecto.Migration` directives,
      literal `import Ecto.Migration` filters, and qualified Ecto migration
      calls in lexical source order. It analyzes each module independently and
      ignores quoted code.

      Inside `create/2` and `create_if_not_exists/2` blocks it inspects `add/3`.
      Inside `alter/2` blocks it inspects `add/3`, `add_if_not_exists/3`, and
      `modify/3`. The table object can be any expression.

      It reports the column options `:null`, `:default`, `:size`, `:precision`,
      and `:scale`. Calls whose literal options contain `primary_key: true` are
      excluded because their defaults and sizing are structural database
      concerns.

      Dynamic options, helper macros, `remove/3`, arity-one table operations,
      and wrapper migration modules are deliberately outside the check's scope.
      """
    ]

  @ecto_migration [:Ecto, :Migration]
  @forbidden_options ~w(null default size precision scale)a
  @table_operations %{
    create: MapSet.new([{:add, 3}]),
    create_if_not_exists: MapSet.new([{:add, 3}]),
    alter: MapSet.new([{:add, 3}, {:add_if_not_exists, 3}, {:modify, 3}])
  }
  @known_pairs MapSet.new([
                 {:create, 2},
                 {:create_if_not_exists, 2},
                 {:alter, 2},
                 {:add, 3},
                 {:add_if_not_exists, 3},
                 {:modify, 3}
               ])

  @impl Credo.Check
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)
    state = %{issue_meta: issue_meta, issues: [], seen: MapSet.new()}

    source_file
    |> Credo.SourceFile.ast()
    |> analyze_top_level(state)
    |> Map.fetch!(:issues)
    |> Enum.reverse()
  end

  defp analyze_top_level({:quote, _meta, _args}, state), do: state

  defp analyze_top_level({:defmodule, _meta, [_name, options]}, state) when is_list(options) do
    case Keyword.fetch(options, :do) do
      {:ok, body} ->
        {_env, state} = analyze(body, empty_env(), nil, state)
        state

      :error ->
        state
    end
  end

  defp analyze_top_level({:__block__, _meta, forms}, state) when is_list(forms) do
    Enum.reduce(forms, state, &analyze_top_level/2)
  end

  defp analyze_top_level({_name, _meta, args}, state) when is_list(args) do
    Enum.reduce(args, state, &analyze_top_level/2)
  end

  defp analyze_top_level(list, state) when is_list(list) do
    Enum.reduce(list, state, &analyze_top_level/2)
  end

  defp analyze_top_level(_ast, state), do: state

  defp analyze({:quote, _meta, _args}, env, _targets, state), do: {env, state}

  defp analyze({:defmodule, _meta, [_name, options]}, env, _targets, state) when is_list(options) do
    state =
      case Keyword.fetch(options, :do) do
        {:ok, body} ->
          {_module_env, state} = analyze(body, empty_env(), nil, state)
          state

        :error ->
          state
      end

    {env, state}
  end

  defp analyze({:__block__, _meta, forms}, env, targets, state) when is_list(forms) do
    Enum.reduce(forms, {env, state}, fn form, {env, state} ->
      analyze(form, env, targets, state)
    end)
  end

  defp analyze({:alias, _meta, args}, env, _targets, state) when is_list(args) do
    {put_alias(env, args), state}
  end

  defp analyze({:import, _meta, args}, env, _targets, state) when is_list(args) do
    {put_import(env, args), state}
  end

  defp analyze({:use, _meta, [module_ast | _options]}, env, _targets, state) do
    env =
      if resolve_module(module_ast, env) == @ecto_migration do
        import_pairs(env, @known_pairs, @ecto_migration)
      else
        env
      end

    {env, state}
  end

  defp analyze(ast, env, targets, state) do
    case call_identity(ast, env) do
      {operation, 2, _meta, [_object, options]} ->
        case {Map.fetch(@table_operations, operation), literal_do_block(options)} do
          {{:ok, block_targets}, {:ok, body}} ->
            {_block_env, state} = analyze(body, env, block_targets, state)
            {env, state}

          _unsupported ->
            analyze_children(ast, env, targets, state)
        end

      {function_name, arity, meta, args} ->
        state = maybe_add_issue(targets, function_name, arity, meta, args, state)
        analyze_children(ast, env, targets, state)

      nil ->
        analyze_children(ast, env, targets, state)
    end
  end

  defp analyze_children({_name, _meta, args}, env, targets, state) when is_list(args) do
    state = Enum.reduce(args, state, &analyze_scoped(&1, env, targets, &2))
    {env, state}
  end

  defp analyze_children(list, env, targets, state) when is_list(list) do
    state = Enum.reduce(list, state, &analyze_scoped(&1, env, targets, &2))
    {env, state}
  end

  defp analyze_children(tuple, env, targets, state) when is_tuple(tuple) do
    state =
      tuple
      |> Tuple.to_list()
      |> Enum.reduce(state, &analyze_scoped(&1, env, targets, &2))

    {env, state}
  end

  defp analyze_children(_literal, env, _targets, state), do: {env, state}

  defp analyze_scoped(ast, env, targets, state) do
    {_inner_env, state} = analyze(ast, env, targets, state)
    state
  end

  defp maybe_add_issue(nil, _function_name, _arity, _meta, _args, state), do: state

  defp maybe_add_issue(targets, function_name, arity, meta, args, state) do
    if MapSet.member?(targets, {function_name, arity}) do
      case forbidden_options(args) do
        [] -> state
        options -> add_issue(state, function_name, meta, options)
      end
    else
      state
    end
  end

  defp forbidden_options([_object, _type, opts]) when is_list(opts) do
    if Keyword.keyword?(opts) and not primary_key_column?(opts) do
      opts
      |> Keyword.keys()
      |> Enum.filter(&Enum.member?(@forbidden_options, &1))
      |> Enum.uniq()
    else
      []
    end
  end

  defp forbidden_options(_args), do: []

  defp primary_key_column?(opts), do: Keyword.get(opts, :primary_key) == true

  defp add_issue(state, function_name, meta, options) do
    key = {meta[:line], meta[:column], function_name, options}

    if MapSet.member?(state.seen, key) do
      state
    else
      option_list = Enum.map_join(options, ", ", &"`#{&1}`")

      issue =
        format_issue(
          state.issue_meta,
          message: "Column option(s) #{option_list} should not be set in migrations. Enforce at the application layer.",
          trigger: Atom.to_string(function_name),
          line_no: meta[:line],
          column: meta[:column]
        )

      %{state | issues: [issue | state.issues], seen: MapSet.put(state.seen, key)}
    end
  end

  defp call_identity({name, meta, args}, env) when is_atom(name) and is_list(args) do
    pair = {name, length(args)}

    if Map.get(env.imports, pair) == @ecto_migration do
      {name, length(args), meta, args}
    end
  end

  defp call_identity({{:., _dot_meta, [module_ast, name]}, meta, args}, env) when is_atom(name) and is_list(args) do
    if resolve_module(module_ast, env) == @ecto_migration do
      {name, length(args), meta, args}
    end
  end

  defp call_identity(_ast, _env), do: nil

  defp literal_do_block(options) when is_list(options) do
    if Keyword.keyword?(options), do: Keyword.fetch(options, :do), else: :error
  end

  defp literal_do_block(_options), do: :error

  defp empty_env, do: %{aliases: %{}, imports: %{}}

  defp put_alias(env, [module_ast | options]) do
    with module when is_list(module) <- resolve_module(module_ast, env),
         alias_name when is_atom(alias_name) <- alias_name(module, options) do
      put_in(env, [:aliases, alias_name], module)
    else
      _unsupported -> env
    end
  end

  defp alias_name([name], []), do: name
  defp alias_name([_segment | rest], []), do: alias_name(rest, [])

  defp alias_name(_module, [options]) when is_list(options) do
    case Keyword.get(options, :as) do
      {:__aliases__, _meta, [name]} -> name
      _unsupported -> nil
    end
  end

  defp alias_name(_module, _options), do: nil

  defp put_import(env, [module_ast | options]) do
    with module when is_list(module) <- resolve_module(module_ast, env),
         {:ok, pairs} <- imported_pairs(options) do
      import_pairs(env, pairs, module)
    else
      _unsupported -> env
    end
  end

  defp imported_pairs([]), do: {:ok, @known_pairs}

  defp imported_pairs([options]) when is_list(options) do
    if Keyword.keyword?(options) do
      cond do
        Keyword.has_key?(options, :only) -> literal_pairs(Keyword.fetch!(options, :only))
        Keyword.has_key?(options, :except) -> except_pairs(Keyword.fetch!(options, :except))
        true -> {:ok, @known_pairs}
      end
    else
      :error
    end
  end

  defp imported_pairs(_options), do: :error

  defp literal_pairs(pairs) when is_list(pairs) do
    if Keyword.keyword?(pairs) and Enum.all?(pairs, &valid_name_arity?/1) do
      {:ok, MapSet.intersection(@known_pairs, MapSet.new(pairs))}
    else
      :error
    end
  end

  defp literal_pairs(_pairs), do: :error

  defp except_pairs(pairs) do
    case literal_pairs(pairs) do
      {:ok, excluded} -> {:ok, MapSet.difference(@known_pairs, excluded)}
      :error -> :error
    end
  end

  defp valid_name_arity?({name, arity}), do: is_atom(name) and is_integer(arity) and arity >= 0
  defp valid_name_arity?(_pair), do: false

  defp import_pairs(env, pairs, module) do
    imports = Enum.reduce(pairs, env.imports, &Map.put(&2, &1, module))
    %{env | imports: imports}
  end

  defp resolve_module({:__aliases__, _meta, [first | rest]}, env) do
    case Map.fetch(env.aliases, first) do
      {:ok, prefix} -> prefix ++ rest
      :error -> [first | rest]
    end
  end

  defp resolve_module(_module_ast, _env), do: nil
end
