## Context

Currently, `send-eval` (line 104) constructs the wire message by embedding the form as a Lisp string literal inside `slynk:eval-and-grab-output`:

```janet
(def wrapped (string/format "(cl:let ((slynk:*echo-number-alist* nil)) (slynk:eval-and-grab-output %q))" progn-form))
(def msg (string/format "(:emacs-rex %s %q t %d)" wrapped pkg id))
```

This produces a wire message like:
```
(:emacs-rex (cl:let ((slynk:*echo-number-alist* nil))
              (slynk:eval-and-grab-output "(+ 1 2)"))
            "CL-USER" t 1)
```

The form `(+ 1 2)` is inside a double-quoted string. Slynk's server evaluates the `cl:let` form, which calls `eval-and-grab-output`, which calls `read-from-string` on the string — adding an extra `read` pass that can trip on readtable customizations, reader macros, or package-specific reader behavior.

SLY sends the form as a direct sexpr in the message:
```
(:emacs-rex (+ 1 2) "CL-USER" nil 1)
```

Slynk's server directly evaluates `(+ 1 2)` in the specified package — no string round-trip.

## Goals / Non-Goals

**Goals:**
- Send the form as a direct sexpr in `:emacs-rex` (matching SLY's convention)
- Remove `slynk:eval-and-grab-output` and the surrounding `cl:let` wrapper
- Update `:return (:ok ...)` handler for the new single-value response format
- Change thread parameter from `t` to `nil`
- Preserve all existing features: `--no-progn`, `progn` wrapping, `--package`, exit codes, `:write-string` accumulation
- Keep output identical to today (accumulated stdout output + return value)

**Non-Goals:**
- Wire protocol version negotiation or changes
- Debugger interaction model changes
- Connection lifecycle changes
- SLY compatibility beyond the eval path

## Decisions

### Decision: Direct sexpr embedding via `%s`

The form string is inserted directly into the `:emacs-rex` message using `%s` (no quoting):

```janet
(def msg (string/format "(:emacs-rex %s %q nil %d)" progn-form pkg id))
```

This works because `progn-form` is already valid Lisp syntax as a string. The `%s` format inserts it verbatim into the `:emacs-rex` sexpr. The Slynk server then reads the entire sexpr in one pass — the form is read as part of the message, not from a secondary string.

### Decision: Thread parameter `nil` instead of `t`

Current code uses `t` (evaluate in a new thread). SLY uses `nil` (evaluate in the current connection thread). Switching to `nil`:
- Avoids thread-related variable capture issues
- Matches SLY's behavior exactly
- Simpler error handling (errors happen in the connection thread)

### Decision: Remove `cl:let` and `eval-and-grab-output` entirely

The `(cl:let ((slynk:*echo-number-alist* nil)) ...)` wrapper was specific to `eval-and-grab-output`'s internal numbering. Without `eval-and-grab-output`, this wrapper is unnecessary and is removed.

### Decision: Update `:return (:ok ...)` handler

Old response format (from `eval-and-grab-output`):
```
(:return (:ok ("printed-output" "return-value-string")) <id>)
```
Where value is a tuple of two strings: captured output stream + princ-to-string of result.

New response format (from direct eval):
```
(:return (:ok "return-value-string") <id>)
```
Where value is a single string: princ-to-string of the result. Printed output is captured separately via `:write-string` messages.

The `process-responses` function's `:return` handler changes from destructuring a pair to reading a single string. The `:write-string` accumulation buffer is preserved.

### Decision: Keep `princ-lisp` for `:abort` fallback

The `princ-lisp` function is no longer needed for `:ok` responses (value is already a string), but it's retained for `:abort` responses where the value might be an arbitrary sexpr that needs formatting.

## Wire Protocol Comparison

```
BEFORE (eval-and-grab-output):
  :emacs-rex
    (cl:let ((slynk:*echo-number-alist* nil))
      (slynk:eval-and-grab-output "<form-string>"))
    "PACKAGE" t 1

  :return (:ok ("printed-out" "result") 1)
              └─── tuple ───┘

AFTER (direct sexpr):
  :emacs-rex
    (+ 1 2)
    "PACKAGE" nil 1

  :return (:ok "result" 1)
              └─ string ─┘
```

Full flow:
```
CLIENT                                    SERVER
  │                                         │
  ├── :emacs-rex form "PACKAGE" nil id ────▶│
  │                                         ├── eval form in *package*
  │                                         │
  │◀── :write-string (output) ──────────────┤  (zero or more)
  │◀── :return (:ok "value") id ────────────┤
  │                                         │
  ├── print :write-string buffer            │
  ├── print "value"                         │
  ├── exit 0                                │
```

## Risks / Trade-offs

| Risk | Mitigation |
|---|---|
| Server-side eval-in-thread issues (nil thread param) | SLY has used nil for decades. If threading is needed, user starts Slynk with multiple connection threads. |
| `slynk:*echo-number-alist*` control is lost | This controlled echo-area numbering in Emacs. Not relevant for CLI output. |
| Form contains characters that break the `:emacs-rex` sexpr (e.g., unbalanced parens) | The form is a string in Janet — it's inserted verbatim. If the form has syntax errors, Slynk returns a reader-error, which slyc already handles. |
| `progn`-wrapped forms with embedded quotes | The form is inserted with `%s`, not `%q`. Quotes in the form are literal Lisp syntax and are read correctly as part of the sexpr. |
