# CodeStyle

Shared deterministic Elixir code-quality policy and Credo checks.

CodeStyle composes a deliberately curated policy from Credo, focused third-party
check providers, migration safety, and a small number of custom checks. Adding a
provider dependency does not enable its full rule set: every enabled check is
allowlisted explicitly and covered by policy tests.

CodeStyle is intended to be used alongside ExDNA and Styler. Those tools are
not bundled with this library and should be configured separately in consuming
projects.

## Installation

Add `code_style` to a consuming Mix project:

```elixir
{:code_style, "~> 0.2.0", only: [:dev, :test], runtime: false}
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

The plugin registers the shared Credo policy, curated Jump.CredoChecks,
CredoMox, ForgeCredoChecks and ExSlop checks, ExcellentMigrations migration
safety, and the custom checks below. It does not override Credo's file
discovery; consuming projects can define their own `files` configuration when
needed.

## Policy model

A check belongs in the shared policy when its evidence is deterministic and the
rule is broadly applicable across Elixir repositories. Repository-specific
architecture rules remain with the repository that owns that architecture.

Third-party checks are selected individually. Dependency upgrades therefore do
not silently expand the policy.

## Custom Checks

- `CodeStyle.Check.Warning.EnvironmentVariableAccess` keeps OS environment
  access at the configuration boundary by reporting `System.get_env/*` and
  `System.fetch_env!/1` from `lib/` while allowing configuration under
  `config/`.
- `CodeStyle.Check.Warning.RepoInsideLoop` flags direct Repo operations that
  can execute once per element across collection and concurrency boundaries.

## Development

Run the package checks with Mix:

```bash
mix check
```
