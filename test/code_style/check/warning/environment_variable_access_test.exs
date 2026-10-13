defmodule CodeStyle.Check.Warning.EnvironmentVariableAccessTest do
  use Credo.Test.Case, async: false

  alias CodeStyle.Check.Warning.EnvironmentVariableAccess

  test "reports System.get_env in lib application source" do
    """
    defmodule Example do
      def token, do: System.get_env("TOKEN")
    end
    """
    |> to_source_file("lib/example.ex")
    |> run_check(EnvironmentVariableAccess)
    |> assert_issue(%{trigger: "System.get_env"})
  end

  test "reports System.fetch_env! in nested lib application source" do
    """
    defmodule Example do
      def token, do: System.fetch_env!("TOKEN")
    end
    """
    |> to_source_file("apps/example/lib/example.ex")
    |> run_check(EnvironmentVariableAccess)
    |> assert_issue(%{trigger: "System.fetch_env!"})
  end

  test "allows OS environment access from config" do
    """
    import Config
    config :example, :token, System.fetch_env!("TOKEN")
    """
    |> to_source_file("config/runtime.exs")
    |> run_check(EnvironmentVariableAccess)
    |> refute_issues()
  end

  test "does not police tooling outside lib" do
    """
    defmodule Mix.Tasks.Example do
      use Mix.Task

      def run(_args), do: System.get_env("TOKEN")
    end
    """
    |> to_source_file("mix/tasks/example.ex")
    |> run_check(EnvironmentVariableAccess)
    |> refute_issues()
  end
end
