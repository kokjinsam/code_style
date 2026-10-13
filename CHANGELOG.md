# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

## [0.1.2] - 2026-10-13

### Changed

- Re-enabled `Credo.Check.Readability.BlockPipe` as a lint backstop even though
  Styler recommends disabling it, because Styler can leave some multi-stage
  pipelines ending in block expressions formatted.
- Kept `Credo.Check.Readability.SingleFunctionToBlockPipe` enabled alongside
  the broader `BlockPipe` policy.

### Added

- Regression coverage for a multi-stage pipeline ending in a `case` block.

### Removed

- Removed `CodeStyle.Check.Design.NoDatabaseConstraints`; database-constraint
  policy is no longer part of the shared CodeStyle checks.

## [0.1.1] - 2026-07-17

### Changed

- Reworked `RepoInsideLoop` around repeated execution across `Enum`, `Stream`,
  `Task`, `Task.Supervisor`, and `for` comprehensions.
- Removed the overlapping ExSlop `QueryInEnumMap` check so
  `RepoInsideLoop` is the single owner of that policy.
- Made coverage compilation part of `mix check` and fixed `RepoInsideLoop` to
  compile safely under coverage.
- Left Credo file discovery to consumers and Credo's defaults instead of
  replacing it from the plugin.
- Pinned the curated ExSlop policy to an explicit, version-stable check set.
- Resolved exact Ecto migration aliases and imports lexically in
  `NoDatabaseConstraints`, including `create_if_not_exists/2` and
  `add_if_not_exists/3`, while skipping quoted and unsupported forms.

## [0.1.0] - 2026-07-10

### Added

- Shared Credo policy plugin with ExSlop and ExcellentMigrations checks.
- `NoDatabaseConstraints` and `RepoInsideLoop` custom Credo checks.
