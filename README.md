# CodeStyle

Shared Credo policy and custom checks for Elixir codebases.

CodeStyle is intended to be used alongside ExDNA and Styler. Those tools are
not bundled with this library and should be configured separately in consuming
projects.

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

## Development

Run the package checks with Mix:

```bash
mix check
```
