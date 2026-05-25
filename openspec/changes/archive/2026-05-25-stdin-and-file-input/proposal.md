## Why

Currently, `slyc` only accepts a Lisp form as a positional CLI argument (`slyc "(+ 1 2)"`). AI agents and shell scripts often need to pipe forms via stdin or read them from files. Adding these input modes makes `slyc` more composable in Unix pipelines and scriptable workflows.

## What Changes

- **New `--file` / `-f` flag**: Read the Lisp form from a file path instead of a positional argument
- **New stdin mode**: If no positional form is provided and stdin is not a TTY, read the form from stdin (pipes, heredocs, redirection)
- **Updated help text**: Document the new `--file` option and stdin mode in usage
- **Precedence rules**: `--file` > positional arg > stdin — explicit sources override implicit ones

## Capabilities

### New Capabilities
- `stdin-input`: Accept a Lisp form from standard input (pipe, heredoc, redirection) when no positional form is given and stdin is not a TTY
- `file-input`: Accept a Lisp form from a file referenced via `--file` / `-f`

### Modified Capabilities
- `eval-form`: The form delivery mechanism expands from "positional CLI argument only" to support three sources (file, positional, stdin) with defined precedence

## Impact

- **Single file changed**: `src/main.janet` — `parse-args` function and `main` entry point
- **No new dependencies**: Janet's standard library (`file/open`, `os/with-din`, `os/isatty`) covers file/stream reading
- **No protocol changes**: The Slynk wire protocol is unchanged; only how the form string is obtained before sending
- **All existing tests must pass**: Backward compatible — positional arg mode is preserved
