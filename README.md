# CodeStyle

Shared Credo policy and custom checks for Elixir codebases.

## Installation

Add `code_style` to a consuming Mix project:

```elixir
{:code_style, "~> 0.1.0", only: [:dev, :test], runtime: false}
```

Then load the Credo plugin in `.credo.exs`:

```elixir
%{
  configs: [
    %{
      name: "default",
      plugins: [{CodeStyle, []}]
    }
  ]
}
```

The plugin registers the shared Credo policy, ExSlop checks, migration safety,
and the custom checks below.

## Custom Checks

- `CodeStyle.Check.Design.NoDatabaseConstraints` flags business-logic column
  options in Ecto migration table blocks.
- `CodeStyle.Check.Warning.RepoInsideLoop` flags direct Repo operations that
  can execute once per element across collection and concurrency boundaries.

The module documentation defines each check's precise contract and scope.

`RepoInsideLoop` is CodeStyle's sole owner of the `Enum.map` case also covered
by `ExSlop.Check.Warning.QueryInEnumMap`, so CodeStyle excludes that check while
retaining the rest of `ExSlop.recommended_checks/0`. Consumers that separately
load both CodeStyle and ExSlop should disable `QueryInEnumMap` to avoid this
deliberate overlap.

## Development

Run the package checks with Mix:

```bash
mix check
```
