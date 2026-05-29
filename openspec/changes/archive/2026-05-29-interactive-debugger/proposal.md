## Why

Slyc currently aborts on any Lisp debugger entry — it sends `(slynk:invoke-nth-restart 0)`, prints the error condition, and exits with code 1. This is correct for AI agents (batch mode) but useless for human developers who want to inspect the error, examine backtraces, inspect local variables, and select a meaningful restart to continue debugging.

## What Changes

- Slyc detects when a human is at the terminal and enters interactive debugger mode
- Interactive mode presents the SBCL debugger menu (condition, restarts, frames) and accepts user commands for restart selection, backtrace, frame locals, and eval-in-frame
- New `--no-debug` flag forces batch abort behavior (backward compatibility)
- No network read timeout during interactive debugger sessions
- Slynk wire protocol `:debug` message is parsed and presented to the user instead of silently aborting

## Capabilities

### New Capabilities
- `interactive-debugger`: Auto-detected interactive debugger session — presents condition, restart list, and stack frames; accepts commands for restart selection (`<N>`), backtrace (`bt`), frame locals (`fr N`), eval-in-frame (`e FORM`), quit (`q`), and help (`?`). No timeout during debugger interaction.
- `no-debug-flag`: The `--no-debug` command-line flag that forces batch abort behavior on debugger entry, overriding auto-detection.

### Modified Capabilities
- (none)

## Impact

- `src/main.janet`: Core changes to `process-responses`, new `handle-debugger` function, new `send-raw-rex` function, new `read-until-return` helper, flag parsing for `--no-debug`
- `tests/test.sh`: New tests for interactive debugger commands, `--no-debug` flag
- No new dependencies
- No breaking changes to existing API (exit codes, output format in batch mode unchanged)
