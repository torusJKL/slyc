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

- Debugger interaction (stepping, inspecting stack frames) — `slyc` aborts on debugger entry
- Persistent REPL sessions — each invocation is a fresh connection
- Code generation — `slyc` evaluates, it doesn't write files

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
| 1 | Lisp error | Form signaled a condition, condition text on stdout |
| 2 | Connection/protocol error | Server unreachable, wrong port, broken protocol |
| 124 | Timeout | Form did not complete within `--timeout` seconds |

### stdout vs stderr

- **stdout**: form result text (both successful return values and Lisp error condition text)
- **stderr**: infrastructure errors — connection refused, protocol errors, file read errors
- This means: for exit code 0, read stdout as the result value. For exit code 1, read stdout as the error condition. For exit codes 2 and 124, read stderr for the explanation.

### Error handling

```bash
# Lisp error → exit 1, condition text on stdout
$ slyc '(error "my bad")'
# stdout: my bad
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
