# CodeStyle

Shared Credo policy and custom checks for Elixir codebases.

## Installation

Add `code_style` to a consuming Mix project:

```elixir
{:code_style, github: "kokjinsam/code_style", only: [:dev, :test], runtime: false}
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

The plugin registers the shared Credo policy, ExSlop checks, and the custom
checks below.

## Custom Checks

`CodeStyle.Check.Design.NoDatabaseConstraints` flags business-logic column options in
Ecto migration table blocks.

`CodeStyle.Check.Warning.RepoInsideLoop` flags direct `Repo.*` calls inside
`Enum`, `Stream`, and `for` loop bodies where the code is likely to create N+1 query
behavior.

## Development

Run the package checks with Mix:

```bash
mix check
```
