defmodule CodeStyle.Check.Warning.EnvironmentVariableAccess do
  @moduledoc false

  use Credo.Check,
    base_priority: :high,
    category: :warning,
    explanations: [
      check: """
      OS environment access belongs in the configuration boundary, not application source.

      Calls to `System.get_env/0,1` and `System.fetch_env!/1` are allowed from
      `config/`, where runtime configuration is assembled, and are reported from
      `lib/` application source.

      Application code should consume application configuration rather than read
      the operating-system environment directly.
      """
    ]

  @env_functions [:get_env, :fetch_env!]

  @impl Credo.Check
  def run(%SourceFile{filename: filename} = source_file, params) when is_binary(filename) do
    if library_source?(filename) and not configuration_source?(filename) do
      issue_meta = IssueMeta.for(source_file, params)
      Credo.Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
    else
      []
    end
  end

  def run(%SourceFile{}, _params), do: []

  defp traverse(
         {{:., _dot_meta, [{:__aliases__, _alias_meta, [:System]}, function]}, meta, _arguments} = ast,
         issues,
         issue_meta
       )
       when function in @env_functions do
    {ast,
     [
       format_issue(
         issue_meta,
         message: "Read OS environment variables from config/ and consume application configuration from lib/.",
         trigger: "System.#{function}",
         line_no: meta[:line]
       )
       | issues
     ]}
  end

  defp traverse(ast, issues, _issue_meta), do: {ast, issues}

  defp library_source?(filename), do: "lib" in Path.split(filename)
  defp configuration_source?(filename), do: "config" in Path.split(filename)
end
