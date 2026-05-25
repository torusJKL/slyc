# Changelog

## 0.2.1 (2026-05-25)

### Added

- Version read dynamically from `project.janet` at runtime instead of being hardcoded

## 0.2.0 (2026-05-25)

### Added

- Stdin mode: when no positional form is given and stdin is not a TTY, read the form from stdin (pipes, heredocs, redirection)
- `--file` / `-f` flag to read the Lisp form from a file
- Form precedence: `--file` > positional arg > stdin > error
- Progn wrapping: stdin/file/positional forms are wrapped in `(progn ...)` so multiple top-level forms are all evaluated; `--no-progn` flag to suppress wrapping
- Newlines in form strings are flattened to spaces before sending, avoiding wire-format issues with multi-line heredocs

### Infrastructure

- Release workflow with binary artifact upload (#3)

## 0.1.0 (2026-05-24)

Initial release. `slyc` is a CLI client for the Slynk debugging protocol, designed for AI agents to evaluate Common Lisp forms on a running Slynk server.

### Added

- One-shot eval: send a single Lisp form and get the result as plain text
- CLI flags: `--port`, `--host`, `--package`, `--timeout`, `--help`, `--version`
- Slynk wire protocol over TCP (6-byte hex length prefix + UTF-8 s-expression)
- Form evaluation via `slynk:eval-and-grab-output` for correct package resolution
- Stream output capture (`:write-string` messages from the server)
- Debugger handling: prints condition and aborts on debugger entry
- Clean exit codes: 0 (success), 1 (lisp error), 2 (connection/protocol error), 124 (timeout)
- Connection refused reporting
- Configurable timeout (default 30s)
