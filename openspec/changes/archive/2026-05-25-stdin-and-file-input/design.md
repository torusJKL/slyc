## Context

`slyc` currently obtains a Lisp form exclusively from a positional CLI argument. The `parse-args` function iterates through `argv`, consumes flags, and treats the first non-flag token as the form. If no form is found, it prints an error and exits 2.

This design extends form acquisition to three sources with defined precedence, using only Janet's standard library — no new dependencies.

Key constraints:
- **Cold start every invocation** — stdin/file reads must not add measurable latency
- **AI agent output** — errors (file not found, stdin read failure) go to stderr, exit codes consistent with existing convention
- **Backward compatibility** — `slyc "(+ 1 2)"` must continue working identically

## Goals / Non-Goals

**Goals:**
- `slyc -f ./my.lis` — read form from a file, return result, exit 0
- `echo "(+ 1 2)" | slyc` — read form from stdin pipe, return result, exit 0
- `slyc << 'EOF' (+ 1 2) EOF` — read form from heredoc, return result, exit 0
- Precedence: `--file` > positional arg > stdin (explicit over implicit)
- Backward compatible: existing usage patterns unchanged
- Error handling: file not found (exit 2), empty stdin (exit 2 with message)
- Help text updated with new `--file` option and stdin usage examples

**Non-Goals:**
- Interactive REPL or prompt mode (even on empty TTY stdin, print error)
- Multi-form input (split stdin by lines or delimiters)
- Readline / line-editing support
- Windows `con:`-style special file handling (cross-platform later)

## Decisions

### Decision: Stdin detection via `os/isatty`

Use Janet's `(os/isatty :stdin)` to detect whether stdin is a terminal. If it's not a TTY, assume piped/redirected input and read the form. This is the standard Unix approach and requires no special flag or heuristic.

Alternatives considered:
- `--stdin` flag: Rejected — defeats the Unix composability goal. Pipes should just work.
- Reading from `/dev/stdin`: Equivalent but less portable and more brittle.
- Always trying stdin if no positional arg: Rejected — would hang waiting for TTY input.

### Decision: Raw form reading with trailing newline stripping

Read the entire stdin or file content as a single string. Strip exactly one trailing newline (`\n`) if present — this is the natural result of heredocs and `echo`. Do NOT strip other whitespace (the form may be whitespace-sensitive within a string).

This means:
- `echo "(+ 1 2)" | slyc` → form is `"(+ 1 2)"` (trailing newline stripped)
- `slyc << 'EOF' (+ 1 2) EOF` → form is `(+ 1 2)` (no extra quoting needed)
- File with `(format t "hello")` → form is `(format t "hello")`

### Decision: `--file` / `-f` flag in short flag table

Add `-f` as a short flag (conflict with existing `-h` for host). Note: `-f` does not conflict with any existing short flag. Use the same scanning approach as other flags.

### Decision: `--file` mutually exclusive with positional form

If `--file` and a positional form are both provided, print an error to stderr and exit 2. This prevents ambiguous invocations. `--file` takes precedence in the sense that if it's present, the positional arg position is checked for conflict, not silently ignored.

### Decision: Source precedence logic

```
if --file provided:
  read form from file
  if positional arg also provided: error "conflicting sources"
elif positional arg provided:
  use positional arg
elif not (os/isatty :stdin):
  read form from stdin
else:
  error "no form provided" (same as today)
```

## Rispects / Trade-offs

| Rispect | Mitigation |
|---|---|
| Large file/stdin input could consume memory | Read entirely into memory (same as current positional string). Slynk forms are typically tiny; not a practical concern. |
| Stdin not a TTY but no input available (empty pipe) | `file/read` returns empty string. Detect and error with "no form provided from stdin". |
| Binary data in stdin/file | The form is sent as a UTF-8 string in the Slynk wire protocol. Binary data would fail at the parse step. Acceptable — Lisp forms are text. |
| Race condition: stdin is a TTY but user types input anyway | Not handled — TTY detection happens once at startup. Interactive/prompt mode is a non-goal. |
