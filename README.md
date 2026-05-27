# slyc — Slynk CLI client for AI agents

`slyc` is a command-line client for [Slynk](https://github.com/joaotavora/sly), the Common Lisp IDE server.
It sends a single Lisp form to a running Slynk server and returns the result as plain text.

Designed for AI agents (Claude Code, OpenCode, Pi, etc.) that need fast, one-shot evaluation of Lisp forms on a live image.

Source repository: [github.com/torusJKL/slyc](https://github.com/torusJKL/slyc)

## Features

- **One-shot eval**: `slyc "(+ 1 2)"` → stdout `3`, exit 0
- **Streaming output**: Captures `format t` and other printed output
- **Error handling**: Lisp errors → exit 1 with condition text
- **Timeout**: configurable via `--timeout` (default 30s, exit 124)
- **Connection failure**: server not reachable → exit 2 with error on stderr
- **Cross-platform**: written in [Janet](https://janet-lang.org) (Linux, macOS, Windows)

## Usage

```bash
# Basic eval
slyc "(+ 1 2)"

# Custom port
slyc --port 4005 "(list 1 2 3)"

# Short flags
slyc -p 4005 "(format t \"hello, ~a\" :world)"

# Specific package
slyc --package CL-USER "(find-package :cl)"

# Timeout (seconds)
slyc --timeout 5 "(sleep 10)"

# Remote host
slyc --host 10.0.0.1 --port 7889 "(machine-instance)"
```

## Exit codes

| Code | Meaning |
|------|---------|
| 0 | Success — form evaluated, result in stdout |
| 1 | Lisp error — condition text printed to stderr |
| 2 | Connection/protocol error — message on stderr |
| 124 | Timeout — form did not complete in time |

## Run with Janet

```bash
# Prerequisites: janet (>= 1.30)
janet src/main.janet "(+ 1 2)"
```

## Build

```bash
jpm build        # → build/slyc (native binary)
```

### What is built

A single `src/main.janet` (~150 lines) with no external dependencies.
The Slynk wire protocol, TCP connection handling, CLI argument parsing, and response formatting are all implemented using Janet's standard library (built-in `net/`, `parse`, `string/format`).

## Protocol

`slyc` communicates with Slynk using its native TCP protocol:

1. Connect to `host:port`
2. Send a length-prefixed s-expression message (`:emacs-rex`)
3. Read responses until a `:return` message is received

The form is sent as a string argument to `slynk:eval-and-grab-output`, ensuring symbols are resolved in the correct package (the form is re-read by `read-from-string` with `*package*` bound to the target package). The `--package` flag controls which package the form is evaluated in.

The form string is escaped for Common Lisp's `read-from-string` before sending: backslashes (`\`) are doubled and double-quotes (`"`) are backslash-escaped. All other characters — including actual newline bytes — pass through literally and are read correctly by the Lisp reader. This means multi-line string literals in heredocs or file input work correctly and produce multi-line output.

## Requirements

- **Build**: [Janet](https://janet-lang.org) ≥ 1.30 + `jpm` (for native binary) or just Janet (for script mode)
- **Server**: A running Slynk server

## AI agent skill

[`doc/SKILL.md`](doc/SKILL.md) is a ready-to-copy skill file that teaches AI agents when and how to use `slyc`. Copy it to your project depending on your agent:

- **Claude Code** — copy to `.claude/skills/slyc/SKILL.md`
- **OpenCode, Pi, Codex** — copy to `.agents/skills/slyc/SKILL.md`

## Related

- [Slynk](https://github.com/joaotavora/sly) — the Common Lisp server
- [SLY](https://github.com/joaotavora/sly) — Emacs Lisp IDE for Common Lisp
- [slynk-client](https://github.com/Shookakko/slynk-client) — Common Lisp client library
