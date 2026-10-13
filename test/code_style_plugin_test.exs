defmodule CodeStylePluginTest do
  use Credo.Test.Case, async: false

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
end
