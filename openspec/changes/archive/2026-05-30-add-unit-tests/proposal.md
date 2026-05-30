## Why

The project currently has no unit tests — `tests/test.janet` is a stub that only prints manual testing instructions, and all actual testing lives in `tests/test.sh` (a Bash integration test suite requiring a live Slynk server). Adding unit tests using Janet's built-in `test` module will enable fast, isolated validation of internal functions without a Lisp server, improve CI confidence, and lower the barrier for contributors to verify correctness.

## What Changes

- Create `tests/unit/` directory with unit tests for internal functions from `src/main.janet`
- Add a `just unit-test` recipe to run unit tests standalone
- Update CI (`pr-checks.yml`) to run unit tests alongside integration tests
- Remove the existing stub code from `tests/test.janet` that duplicates what `test.sh` already covers

## Capabilities

### New Capabilities

_(None — this is an internal testing change with no spec-level behavior changes.)_

### Modified Capabilities

_(None — no existing specs have requirement changes.)_

## Impact

- **Replaced**: `tests/test.janet` — replace the existing stub with real unit tests using `janet.test`
- **Modified**: `justfile` — update `test` recipe to run both `janet tests/test.janet` and `bash tests/test.sh`
- **Modified**: `.github/workflows/pr-checks.yml` — run unit tests before integration tests
- **No runtime or API changes** — tests only
