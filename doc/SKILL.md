---
name: slyc
description: Instructs AI agents when and how to use slyc to evaluate Common Lisp forms against a Slynk server and read results from the REPL
license: MIT
compatibility: Requires slyc binary installed in PATH
metadata:
  author: Gal Buki
  version: "1.0"
---

# slyc — Slynk CLI client for AI agents

`slyc` evaluates a single Common Lisp form against a running [Slynk](https://github.com/joaotavora/sly) server and returns the result as plain text. It starts fast (~ms cold start) and uses exit codes so agents can reliably detect success, Lisp errors, connection failures, and timeouts without parsing unstructured output.

## When to use slyc

Use `slyc` when you need to:

- Evaluate a Lisp form and get the result (numeric, string, list, keyword, boolean)
- Call a function to check its return value
- Print output from `format t` or similar
- Check variable values in a running Lisp image
- Test a Lisp expression quickly without entering a REPL

Do NOT use `slyc` for:

- Persistent REPL sessions — each invocation is a fresh connection
- Code generation — `slyc` evaluates, it doesn't write files

(Interactive debugger use from a terminal is supported — see the dedicated section below.)

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

# Read form from file
slyc -f ./my-form.lisp

# Pipe form from stdin
echo "(+ 1 2)" | slyc

# Heredoc with multi-line form (implicitly wrapped in progn)
slyc << 'EOF'
(defun greet (name)
  (format nil "hello, ~a" name))
(greet "world")
EOF

# Timeout (seconds)
slyc --timeout 5 "(sleep 10)"
```

### Flags

| Flag | Short | Default | Description |
|------|-------|---------|-------------|
| `--port` | `-p` | `4005` | Slynk server port |
| `--host` | `-h` | `127.0.0.1` | Slynk server host |
| `--package` | | `(server default)` | Package to evaluate in |
| `--timeout` | `-t` | `30` | Read timeout in seconds |
| `--file` | `-f` | | Read form from file (mutually exclusive with positional form) |
| `--no-progn` | | `false` | Do not wrap input in `(progn ...)` |
| `--no-debug` | | `false` | Force batch abort on debugger entry (no interactive prompt) |
| `--help` | | | Show help text |
| `--version` | | | Show version number |

### Input modes

**Positional argument** — form is the first non-flag argument:
```bash
slyc "(+ 1 2)"
```

**File input** — read form from file (exclusive with positional form):
```bash
slyc -f ./my-form.lisp
```

**Stdin** — if no positional form and `--file` is not set, reads from stdin when stdin is not a TTY:
```bash
echo "(+ 1 2)" | slyc
printf "(+ 1 2)\n(* 3 4)" | slyc
```

### Multi-form input

Input is automatically wrapped in `(progn ...)` so multiple top-level forms are all evaluated in sequence. Only the return value of the last form is printed:
```bash
slyc "(setq x 1) (setq y 2) (+ x y)"
# → both forms evaluated, result is 3 (only (+ x y) printed)
```

Use `--no-progn` to disable wrapping — only the first form is evaluated:
```bash
slyc --no-progn "(+ 1 2) (* 3 4)"
# → only (+ 1 2) evaluated, result is 3
```

### String escaping

`slyc` accepts forms as a quoted string argument. The Common Lisp reader interprets the form string on the server side. When you embed a string literal inside your Lisp form, use standard shell quoting for the outer argument and Lisp string escaping for the inner string:

```bash
slyc '(string-upcase "hello")'
slyc '(format t "value: ~a" 42)'
slyc '(format t "path: \\"C:\\\\Users\\\\name\\"")'
```

Newlines in the form string are preserved correctly — multi-line heredocs work naturally:
```bash
slyc << 'EOF'
(format t "hello
world")
EOF
# Output:
# hello
# world
```

## Result handling

### Exit codes

| Code | Meaning | Details |
|------|---------|---------|
| 0 | Success | Form evaluated, result printed to stdout |
| 1 | Lisp error | Form signaled a condition, condition text on stderr |
| 2 | Connection/protocol error | Server unreachable, wrong port, broken protocol |
| 124 | Timeout | Form did not complete within `--timeout` seconds |

### stdout vs stderr

- **stdout**: form result text (successful return values only)
- **stderr**: Lisp error conditions, connection errors, protocol errors, file read errors, timeouts
- This means: for exit code 0, read stdout as the result. For exit codes 1, 2, and 124, read stderr for the explanation.

### Error handling

```bash
# Lisp error → exit 1, condition text on stderr
$ slyc '(error "my bad")'
# stderr: my bad
# exit: 1

# Connection refused → exit 2, error on stderr
$ slyc --port 1 "(+ 1 2)"
# stderr: connection refused: 127.0.0.1:1
# exit: 2

# Timeout → exit 124, error on stderr
$ slyc --timeout 2 "(sleep 10)"
# stderr: timed out after 2 seconds
# exit: 124
```

## Interactive debugger

When the Lisp server enters its debugger (the evaluated form signals a condition), `slyc` can either abort immediately or drop into an interactive debug loop. The behavior depends on the environment:

| Condition | Behavior |
|-----------|----------|
| `stdin` is a TTY, `--no-debug` not set | **Interactive** — drops into `slyc-db>` prompt |
| `stdin` is piped/redirected, or `--no-debug` set | **Batch abort** — sends ABORT restart, prints condition, exits with code 1 |

For AI agents (whose stdin is never a TTY), the debugger is **always non-interactive**: exit code 1 with the condition text on stderr.

### Interactive mode (`slyc-db>`)

When you run `slyc` from a terminal on a form that errors, you see:

```
<condition-type>: <condition-message>

Restarts:
0: ABORT — Return to SLIME's top level
1: CONTINUE — Continue execution
2: RETRY — Retry the same form

Backtrace (5 frames):
0: (ERROR "my bad")
1: (EVAL-TL "my bad")
2: (SB-INT:EVAL-IN-REVERSE ...)
...

Commands: N restart | bt backtrace | fr N frame | up/down | e FORM eval | r restarts | q quit | ? help
slyc-db>
```

Commands are read line by line from stdin:

| Command | Description |
|---------|-------------|
| `<N>` (number) | Invoke restart N from the list (0 = ABORT). If the restart name contains "ABORT", exits with code 1. |
| `bt [N]` | Show backtrace, N frames deep (default 20). Fetches from the server. |
| `fr N` | Set current frame to N, show local variables and catch tags. |
| `up` | Move one frame **up** the stack (toward the error site, frame 0). |
| `down` | Move one frame **down** the stack (away from the error site). |
| `e FORM` | Evaluate an arbitrary Lisp form in the lexical context of the current frame. Useful for inspecting locals, calling functions with error-time bindings. |
| `r` | Reprint the condition, restart list, and first 5 backtrace frames. |
| `q` | Quit — sends the ABORT restart (equivalent to `0`), exits with code 1. |
| `?` | Print the full command help text. |

#### Frame navigation

The `current-frame` starts at 0 (the error site). `up` decrements the index (moving toward frame 0), `down` increments it (moving deeper into the call stack). `fr N` jumps directly. When you move to a frame not yet fetched from the server, you see: `[frame not in cache — use bt to fetch]`.

#### Eval in context

The `e FORM` command sends the form as `(progn <form>)` to the server for evaluation in the current frame's lexical scope. Output from `format t` and other printed output is captured and shown inline. If the evaluated form itself signals a condition, the debugger re-enters recursively, allowing nested debugging.

#### Nested debuggers

If a form evaluated via `e` during debugging signals a new condition, `slyc` recursively enters the debugger for the nested condition. This allows debugging inside debugging sessions.

#### Thread awareness

When running in a multi-threaded Lisp, if a `:debug` message arrives from a different thread than the one being debugged, `slyc` prints a warning (`Warning: debugger entered in thread ...`) but still enters the debugger for the new thread.

### `--no-debug` flag

Use `--no-debug` to force batch-abort behavior even when stdin is a TTY. This is useful in scripts or when you want deterministic behavior:

```bash
slyc --no-debug "(error \"fail\")"
# → exits 1, condition text on stderr
```

### Agent behavior summary

For AI agents evaluating code:

- The agent will **never** see the interactive debugger because its stdin is not a TTY
- On Lisp errors, `slyc` exits with code 1 and the condition text is on stderr
- The agent should check the exit code: 0 = success (read stdout), 1 = Lisp error (read stderr), 2 = connection error (read stderr), 124 = timeout (read stderr)
- The `--no-debug` flag is redundant in agent use but can be used for explicit safety

## Common patterns

### Checking variable values
```bash
slyc "*package*"
slyc "*features*"
slyc "(boundp '*print-array*)"
```

### Calling functions
```bash
slyc "(machine-instance)"
slyc "(find-package :cl)"
slyc "(list 1 2 3)"
```

### Format output
```bash
slyc '(format t "hello, ~a" :world)'
slyc '(format nil "~{~/~a~}" (list "a" "b" "c"))'
```

### Working with packages
```bash
slyc --package CL-USER "(in-package :my-pkg) *package*"
slyc --package MY-PKG "(find-symbol \"foo\" :my-pkg)"
```

### Boolean results
```bash
slyc "(oddp 2)"      # → NIL
slyc "(evenp 2)"     # → T
slyc "(null nil)"    # → T
```

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| `connection refused: 127.0.0.1:4005` | Slynk server not running | Start Slynk in your Lisp, check port |
| `timed out after N seconds` | Form is slow or server is hung | Increase `--timeout`, or server may be in debugger (send abort) |
| Lisp error: `Package XYZ not found` | Wrong package name | Use `--package` with correct case-sensitive package name |
| Unexpected results with strings | Shell quoting vs Lisp quoting confusion | Use single quotes for the outer shell arg, double quotes inside for CL strings |
| `error: no form provided` | No input given | Pass form as arg, use `--file`, or pipe via stdin |
