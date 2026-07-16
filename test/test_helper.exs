ExUnit.start()

if Process.whereis(Credo.Service.SourceFileAST) == nil do
  {:ok, _started_apps} = Application.ensure_all_started(:credo)
end
