# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Changed

- Resolve exact Ecto migration aliases and imports lexically in
  `NoDatabaseConstraints`, including `create_if_not_exists/2` and
  `add_if_not_exists/3`, while skipping quoted and unsupported forms.

## [0.1.0] - 2026-07-10

### Added

- Shared Credo policy plugin with ExSlop and ExcellentMigrations checks.
- `NoDatabaseConstraints` and `RepoInsideLoop` custom Credo checks.
