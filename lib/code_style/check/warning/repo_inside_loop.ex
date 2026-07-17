defmodule CodeStyle.Check.Warning.RepoInsideLoop do
  @moduledoc false

  use Credo.Check,
    base_priority: :higher,
    category: :warning,
    explanations: [
      check: """
      Avoid calling Repo from inside repeated execution.

      This check follows callback execution rather than lexical nesting. It
      covers callback positions on `Enum` and `Stream` operations,
      `Task.async_stream/2` and its related Task and Task.Supervisor variants,
      and `for` comprehensions. Reads, writes, preload/reload operations, and
      transaction or connection entry are all reportable because each can cause
      repeated database work.

      ### Execution model

      For lazy streams and async streams, a callback is reportable because it
      runs once per consumed element even though it does not run when the stream
      is constructed.

      Expressions evaluated once at the top level are not reported. These
      include loop inputs, initial values and options, callback construction,
      the first `for` generator's right-hand side, and once-only start,
      finalizer, and fallback callbacks. Such expressions remain reportable
      when an enclosing repeated boundary causes them to execute repeatedly.

      ### Matching and limitations

      Repo matching is syntactic and exact: `Repo` and literal module paths
      ending in `Repo` are recognized. Helper modules, dynamic module
      expressions, and fuzzy names are not.

      Custom aliases such as `DB`, callback variables or factories, third-party
      boundaries, and interprocedural inference are deliberately outside the
      check's scope.
      """
    ]

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

  @repeated_boundaries Enum.map(@enum_position_2, &{:Enum, &1, 2, [2]}) ++
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
                           {:Enum, :min_max_by, 4, [2, 3]},
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
                           {:Stream, :filter_map, 3, [2, 3]},
                           {:Task, :async_stream, 2, [2]},
                           {:Task, :async_stream, 3, [2]},
                           {Task.Supervisor, :async_stream, 3, [3]},
                           {Task.Supervisor, :async_stream, 4, [3]},
                           {Task.Supervisor, :async_stream_nolink, 3, [3]},
                           {Task.Supervisor, :async_stream_nolink, 4, [3]}
                         ] ++
                         Enum.map(@stream_position_2, &{:Stream, &1, 2, [2]})

  @conditional_boundaries [
    {:Enum, :with_index, 2, 2},
    {:Stream, :from_index, 1, 1},
    {:Stream, :with_index, 2, 2}
  ]

  @once_callback_boundaries [
    {:Enum, :max, 2, [2]},
    {:Enum, :max, 3, [3]},
    {:Enum, :min, 2, [2]},
    {:Enum, :min, 3, [3]},
    {:Enum, :min_max, 3, [3]},
    {:Enum, :max_by, 3, [3]},
    {:Enum, :max_by, 4, [4]},
    {:Enum, :min_by, 3, [3]},
    {:Enum, :min_by, 4, [4]},
    {:Enum, :min_max_by, 3, [3]},
    {:Enum, :min_max_by, 4, [4]},
    {:Stream, :resource, 3, [1, 3]},
    {:Stream, :chunk_while, 4, [4]},
    {:Stream, :transform, 4, [2, 4]},
    {:Stream, :transform, 5, [2, 4, 5]}
  ]

  @repeated_mfa_boundaries [
    {:Task, :async_stream, 4, {2, 3, 4}},
    {:Task, :async_stream, 5, {2, 3, 4}},
    {Task.Supervisor, :async_stream, 5, {3, 4, 5}},
    {Task.Supervisor, :async_stream, 6, {3, 4, 5}},
    {Task.Supervisor, :async_stream_nolink, 5, {3, 4, 5}},
    {Task.Supervisor, :async_stream_nolink, 6, {3, 4, 5}}
  ]

  @task_function_bridges [
    {:Task, :async, 1, 1},
    {:Task, :start, 1, 1},
    {:Task, :start_link, 1, 1},
    {Task.Supervisor, :async, 2, 2},
    {Task.Supervisor, :async, 3, 2},
    {Task.Supervisor, :async_nolink, 2, 2},
    {Task.Supervisor, :async_nolink, 3, 2},
    {Task.Supervisor, :start_child, 2, 2},
    {Task.Supervisor, :start_child, 3, 2}
  ]

  @task_mfa_bridges [
    {:Task, :async, 3, {1, 2, 3}},
    {:Task, :start, 3, {1, 2, 3}},
    {:Task, :start_link, 3, {1, 2, 3}},
    {Task.Supervisor, :async, 4, {2, 3, 4}},
    {Task.Supervisor, :async, 5, {2, 3, 4}},
    {Task.Supervisor, :async_nolink, 4, {2, 3, 4}},
    {Task.Supervisor, :async_nolink, 5, {2, 3, 4}},
    {Task.Supervisor, :start_child, 4, {2, 3, 4}},
    {Task.Supervisor, :start_child, 5, {2, 3, 4}}
  ]

  @repo_functions ~w(
    aggregate all all_by delete_all exists? get get! get_by get_by! one one!
    stream update_all query query! delete delete! insert insert! insert_all
    insert_or_update insert_or_update! preload reload reload! update update!
    checkout transact transaction
  )a

  @impl Credo.Check
  def run(%SourceFile{} = source_file, params) do
    acc = %{issue_meta: IssueMeta.for(source_file, params), seen: MapSet.new(), issues: []}

    source_file
    |> SourceFile.ast()
    |> traverse(:once, acc)
    |> Map.fetch!(:issues)
    |> Enum.reverse()
  end

  defp traverse({:quote, _meta, _args}, _context, acc), do: acc
  defp traverse({:fn, _meta, _clauses}, _context, acc), do: acc

  defp traverse({:for, _meta, args}, context, acc) when is_list(args) do
    traverse_for(args, context, acc)
  end

  defp traverse({:|>, _meta, [input, call]}, context, acc) do
    case call do
      {{:., dot_meta, [module_ast, function_name]}, call_meta, args}
      when is_list(args) and is_atom(function_name) ->
        traverse_remote_call(
          module_ast,
          function_name,
          [input | args],
          context,
          acc,
          call_meta,
          dot_meta
        )

      _other ->
        acc = traverse(input, context, acc)
        traverse(call, context, acc)
    end
  end

  defp traverse({{:., dot_meta, [module_ast, function_name]}, call_meta, args}, context, acc)
       when is_list(args) and is_atom(function_name) do
    traverse_remote_call(
      module_ast,
      function_name,
      args,
      context,
      acc,
      call_meta,
      dot_meta
    )
  end

  defp traverse({form, _meta, args}, context, acc) when is_list(args) and is_atom(form) do
    traverse(args, context, acc)
  end

  defp traverse(list, context, acc) when is_list(list) do
    Enum.reduce(list, acc, fn child, acc -> traverse(child, context, acc) end)
  end

  defp traverse(tuple, context, acc) when is_tuple(tuple) do
    tuple
    |> Tuple.to_list()
    |> traverse(context, acc)
  end

  defp traverse(_literal, _context, acc), do: acc

  defp traverse_remote_call(module_ast, function_name, args, context, acc, call_meta, dot_meta) do
    call_shape = {boundary_module(module_ast), function_name, length(args)}

    cond do
      repeated_positions = repeated_positions(call_shape, args) ->
        traverse_boundary(args, repeated_positions, once_positions(call_shape, args), context, acc)

      mfa_positions = descriptor_positions(@repeated_mfa_boundaries, call_shape) ->
        acc = add_mfa_issue(acc, args, mfa_positions, :repeated, call_meta, dot_meta)
        traverse(args, context, acc)

      callback_position = descriptor_position(@task_function_bridges, call_shape) ->
        traverse_bridge(args, callback_position, context, acc)

      mfa_positions = descriptor_positions(@task_mfa_bridges, call_shape) ->
        acc = add_mfa_issue(acc, args, mfa_positions, context, call_meta, dot_meta)
        traverse(args, context, acc)

      context == :repeated and function_name in @repo_functions and repo_module?(module_ast) ->
        acc = add_issue(acc, module_ast, function_name, call_meta, dot_meta)
        traverse(args, context, acc)

      true ->
        acc = traverse(module_ast, context, acc)
        traverse(args, context, acc)
    end
  end

  defp repeated_positions(call_shape, args) do
    case Enum.find(@repeated_boundaries, &descriptor?(&1, call_shape)) do
      {_module, _function, _arity, positions} ->
        positions

      nil ->
        conditional_repeated_positions(call_shape, args) || once_only_positions(call_shape)
    end
  end

  defp conditional_repeated_positions({:Enum, :min_max, 2}, [_enumerable, callback]) do
    case callable_arity(callback) do
      2 -> [2]
      0 -> []
      _arity -> nil
    end
  end

  defp conditional_repeated_positions(call_shape, args) do
    case Enum.find(@conditional_boundaries, &descriptor?(&1, call_shape)) do
      {_module, _function, _arity, position} ->
        if callable?(Enum.at(args, position - 1)), do: [position]

      nil ->
        nil
    end
  end

  defp descriptor?({module, function, arity, _positions}, {module, function, arity}), do: true
  defp descriptor?(_descriptor, _call_shape), do: false

  defp descriptor_position(descriptors, call_shape) do
    case Enum.find(descriptors, &descriptor?(&1, call_shape)) do
      {_module, _function, _arity, position} -> position
      nil -> nil
    end
  end

  defp descriptor_positions(descriptors, call_shape) do
    descriptor_position(descriptors, call_shape)
  end

  defp once_only_positions(call_shape) do
    if descriptor_position(@once_callback_boundaries, call_shape), do: []
  end

  defp once_positions({:Enum, :min_max, 2}, [_enumerable, callback]) do
    if callable_arity(callback) == 0, do: [2], else: []
  end

  defp once_positions(call_shape, _args) do
    descriptor_position(@once_callback_boundaries, call_shape) || []
  end

  defp traverse_boundary(args, repeated_positions, once_positions, context, acc) do
    args
    |> Enum.with_index(1)
    |> Enum.reduce(acc, fn {argument, position}, acc ->
      cond do
        position in repeated_positions and callable?(argument) ->
          traverse_callback(argument, :repeated, acc)

        position in once_positions and callable?(argument) ->
          traverse_callback(argument, context, acc)

        true ->
          traverse(argument, context, acc)
      end
    end)
  end

  defp traverse_bridge(args, callback_position, context, acc) do
    args
    |> Enum.with_index(1)
    |> Enum.reduce(acc, fn
      {callback, ^callback_position}, acc -> traverse_callback(callback, context, acc)
      {argument, _position}, acc -> traverse(argument, context, acc)
    end)
  end

  defp traverse_callback({:fn, _meta, clauses}, context, acc), do: traverse(clauses, context, acc)

  defp traverse_callback({:&, _meta, [body]}, context, acc), do: traverse(body, context, acc)
  defp traverse_callback(callback, context, acc), do: traverse(callback, context, acc)

  defp add_mfa_issue(acc, args, {module_position, function_position, _args_position}, context, call_meta, dot_meta) do
    module_ast = Enum.at(args, module_position - 1)
    function_name = Enum.at(args, function_position - 1)

    if context == :repeated and function_name in @repo_functions and repo_module?(module_ast) do
      add_issue(acc, module_ast, function_name, call_meta, dot_meta, column: false)
    else
      acc
    end
  end

  defp traverse_for(args, context, acc) do
    {qualifiers, options} = Enum.split_while(args, &(not keyword_options?(&1)))

    acc =
      qualifiers
      |> Enum.map_reduce(false, fn
        {:<-, _meta, [pattern, enumerable]}, false ->
          {{pattern, enumerable, context}, true}

        {:<-, _meta, [pattern, enumerable]}, true ->
          {{pattern, enumerable, :repeated}, true}

        qualifier, generator_seen? ->
          {{nil, qualifier, :repeated}, generator_seen?}
      end)
      |> elem(0)
      |> Enum.reduce(acc, fn {pattern, expression, expression_context}, acc ->
        acc = traverse(pattern, context, acc)
        traverse(expression, expression_context, acc)
      end)

    Enum.reduce(options, acc, &traverse_for_options(&1, context, &2))
  end

  defp keyword_options?(value), do: is_list(value) and Keyword.keyword?(value)

  defp traverse_for_options(options, context, acc) do
    Enum.reduce(options, acc, fn
      {:do, body}, acc -> traverse(body, :repeated, acc)
      {_option, value}, acc -> traverse(value, context, acc)
    end)
  end

  defp callable?({:fn, _meta, _clauses}), do: true
  defp callable?({:&, _meta, [_body]}), do: true
  defp callable?(_ast), do: false

  defp callable_arity({:fn, _meta, [{:->, _arrow_meta, [arguments, _body]} | clauses]}) do
    arity = length(arguments)

    if Enum.all?(clauses, fn
         {:->, _meta, [clause_arguments, _body]} -> length(clause_arguments) == arity
         _other -> false
       end) do
      arity
    end
  end

  defp callable_arity({:&, _meta, [{:/, _slash_meta, [_function, arity]}]}) when is_integer(arity), do: arity

  defp callable_arity({:&, _meta, [body]}) do
    {_body, arity} =
      Macro.prewalk(body, 0, fn
        {:&, _meta, [position]} = ast, arity when is_integer(position) ->
          {ast, max(arity, position)}

        ast, arity ->
          {ast, arity}
      end)

    arity
  end

  defp callable_arity(_ast), do: nil

  defp add_issue(acc, module_ast, function_name, call_meta, dot_meta, options \\ []) do
    location =
      module_ast
      |> issue_location(call_meta, dot_meta)
      |> maybe_remove_column(options)

    trigger = trigger_for(module_ast, function_name)
    key = {location[:line_no], location[:column], trigger}

    if MapSet.member?(acc.seen, key) do
      acc
    else
      issue = issue_for(acc.issue_meta, location, trigger)
      %{acc | seen: MapSet.put(acc.seen, key), issues: [issue | acc.issues]}
    end
  end

  defp maybe_remove_column(location, options) do
    if Keyword.get(options, :column, true), do: location, else: Keyword.put(location, :column, nil)
  end

  defp issue_for(issue_meta, location, trigger) do
    format_issue(
      issue_meta,
      message:
        "Repo call in repeated execution can cause repeated database work. Batch or preload before iterating when possible.",
      trigger: trigger,
      line_no: location[:line_no],
      column: location[:column]
    )
  end

  defp issue_location(module_ast, call_meta, dot_meta) do
    module_meta = alias_meta(module_ast)

    [
      line_no: module_meta[:line] || call_meta[:line] || dot_meta[:line],
      column: module_meta[:column] || dot_meta[:column] || call_meta[:column]
    ]
  end

  defp trigger_for(module_ast, function_name) do
    module_ast
    |> alias_segments()
    |> Enum.concat([function_name])
    |> Enum.map_join(".", &Atom.to_string/1)
  end

  defp boundary_module(module_ast) do
    case canonical_alias_segments(module_ast) do
      [:Enum] -> :Enum
      [:Stream] -> :Stream
      [:Task] -> :Task
      [:Task, :Supervisor] -> Task.Supervisor
      _segments -> nil
    end
  end

  defp repo_module?(module_ast) do
    case canonical_alias_segments(module_ast) do
      [] -> false
      segments -> repo_segments?(segments)
    end
  end

  defp repo_segments?([:Repo]), do: true
  defp repo_segments?([_segment | remaining_segments]), do: repo_segments?(remaining_segments)
  defp repo_segments?([]), do: false

  defp canonical_alias_segments(module_ast) do
    case alias_segments(module_ast) do
      [Elixir | segments] -> segments
      segments -> segments
    end
  end

  defp alias_segments({:__aliases__, _meta, segments}), do: segments
  defp alias_segments(_other), do: []

  defp alias_meta({:__aliases__, meta, _segments}), do: meta
  defp alias_meta(_other), do: []
end
