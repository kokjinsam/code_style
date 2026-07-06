defmodule CodeStyleTest do
  use ExUnit.Case, async: true

  test "registers custom Credo checks" do
    assert {CodeStyle.Check.Design.NoDatabaseConstraints, []} in CodeStyle.checks()
    assert {CodeStyle.Check.Warning.RepoInsideLoop, []} in CodeStyle.checks()
  end

  test "registers ExSlop recommended checks" do
    assert {ExSlop.Check.Warning.QueryInEnumMap, []} in CodeStyle.checks()
  end
end
