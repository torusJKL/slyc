## Why

The version is currently hardcoded in two places (`src/main.janet:2` says `"0.1.0"`, `project.janet:3` says `"0.2.0"`) that must be manually kept in sync. `project.janet` is the canonical project manifest — the version displayed by `--version` should come from it automatically, eliminating duplication and drift.

## What Changes

- Remove the hardcoded `(def version ...)` from `src/main.janet`
- Parse `project.janet` at load time to extract the version from the `declare-project` form
- `slyc --version` will now always show whatever version is declared in `project.janet`

## Capabilities

No new capabilities or modified specs — this is a pure build/infrastructure improvement.

## Impact

- `src/main.janet`: ~2 lines replaced (hardcoded def → a `load-version` function call)
- `project.janet`: remains the single source of truth (no change needed)
- Runtime behavior: `--version` output should be identical in format, just sourced dynamically
