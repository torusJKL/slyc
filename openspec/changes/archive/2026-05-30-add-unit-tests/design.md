## Context

The project has zero unit tests. All testing is done via `tests/test.sh`, a Bash integration script that requires a running Slynk server (SBCL + Quicklisp + Slynk). This makes it impractical for quick local verification, CI-only testing, or testing pure utility functions (string escaping, argument parsing, wire formatting) in isolation. The existing `tests/test.janet` is a stub that never evolved beyond manual instructions.

Janet ships a built-in `test` module, but the Homebrew v1.41.2 distribution doesn't bundle it. Instead, `testament` (a Janet test library from the jpm registry) is used: `deftest`, `is`, `run-tests!`.

## Goals / Non-Goals

**Goals:**
- Unit tests for pure internal functions in `src/main.janet` that require no network or Lisp server
- Replace the stub in `tests/test.janet` with real unit tests using Janet's `test` module
- Update `just test` to run the unit tests
- CI runs unit tests before integration tests (fast feedback)

**Non-Goals:**
- No separate test runner — `tests/test.janet` is the single unit test file
- No integration or end-to-end tests — `test.sh` remains the sole integration test suite
- No mocking of the Slynk wire protocol (network-layer tests stay in `test.sh`)
- No behavioral or API changes to the source code

## Decisions

| Decision | Choice | Rationale |
|---|---|---|
| **Test framework** | `testament` (`import testament`) | Homebrew's Janet v1.41.2 doesn't bundle the standard `test` module; testament provides a similar API with `deftest`, `is`, `run-tests!` |
| **Test file location** | `tests/test.janet` | Replaces the existing stub directly; loads `src/main.janet` via `dofile` with a clean environment to access private functions |
| **Functions to unit test** | `chomp`, `quote-for-cl-reader`, `princ-lisp`, `load-version`, `print-debug-condition`, `print-restarts`, `print-frames`, `parse-args` (successful arg paths only — error paths call `os/exit`), plus wire-format string construction | Network- and IO-bound functions (`read-message`, `process-responses`, `handle-debugger`, `read-form-from-file/stdio`) require a server or mock. `parse-args` error paths (`os/exit`) tested by `test.sh` |
| **CI order** | Unit tests first, then integration tests | Fast feedback — unit tests run in <1s and fail fast if core logic breaks |
| **just test recipe** | Run both: `janet tests/test.janet && bash tests/test.sh` | Unit tests run first (fast, no server needed); integration tests follow |

## Risks / Trade-offs

| Risk | Mitigation |
|---|---|
| Unit tests may be brittle if internal function signatures change | Keep tests focused on behavior, not implementation details; update tests alongside code changes |
| `parse-args` calls `os/exit` for error cases — hard to unit test | Extract validation logic or test specific parsing paths that don't trigger exits; leave exit-path tests in `test.sh` |
| `load-version` calls `file/open` which fails if CWD isn't project root | Accept this limitation — unit tests run from project root (via `just test`)
