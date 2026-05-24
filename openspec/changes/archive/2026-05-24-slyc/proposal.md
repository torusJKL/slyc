## Why

AI agents (Claude Code, Codex, OpenCode) need to evaluate Common Lisp forms against a running Slynk server. Existing tools like SLIME/SLY are interactive GUI clients — heavy, session-oriented, and designed for human use. A lightweight CLI that sends a single form and returns the result textually gives AI agents a fast, reliable way to interact with a live Lisp image.

## What Changes

- **New CLI binary `slyc`** — a Janet-lang CLI tool that connects to a Slynk server, sends a form for evaluation, reads the response, and prints the result
- **Protocol implementation**: Handles the Slynk wire protocol (TCP, length-prefixed s-expressions) — including optional auth, `:write-string` output collection, and `:return` result handling
- **Agent-friendly output**: Clean stdout (result text), stderr (infra errors), and standard exit codes (0=success, 1=lisp-error, 2=protocol-error, 124=timeout)
- **Cross-platform foundation**: Linux MVP, architecture supports Windows/macOS later

## Capabilities

### New Capabilities

- `eval-form`: One-shot evaluation of a single Lisp form against a Slynk server, returning the result as plain text
- `connection-management`: TCP connection lifecycle — connect, authenticate, timeout, disconnect

### Modified Capabilities

- None (no existing capabilities)

## Impact

- **New dependency**: Janet-lang runtime (for development; standalone binary for distribution)
- **No changes to existing code** in the `main/` project
- **New binary**: `slyc` — small, fast-starting CLI
