## Context

`slyc` currently sends the raw form string to `slynk:eval-and-grab-output`, which calls `read-from-string` once — consuming exactly one form. Any remaining text in the string is silently ignored.

When users pipe multiple forms via heredocs or stdin, only the first form is evaluated:

```
$ slyc << 'EOF'
(apply-theme :dark)
(display :s (make-sphere 20))
EOF
;; → only (apply-theme :dark) evaluated, second form lost
```

The fix: wrap the form string in `(progn ...)` before quoting and sending. `progn` is a CL special operator that evaluates forms sequentially and returns the last value. For single forms, `(progn form)` ≡ `form`.

## Goals / Non-Goals

**Goals:**
- All forms in stdin/file/positional input are evaluated in sequence
- Single-form input produces identical output to today (backward compatible)
- `--no-progn` flag to opt out of wrapping for edge cases
- Single file change to `src/main.janet`, no new dependencies
- No protocol or wire format changes

**Non-Goals:**
- Capturing return values of intermediate forms (only last value is printed, matching `progn` semantics)
- Per-form error isolation (one error aborts all forms, same as `progn`)
- Form splitting or multi-form detection logic
- Parallel or async evaluation

## Decisions

### Decision: Progn wrapping over Values wrapping

`progn` wrapping is syntactically trivial — just prepend `"(progn "` and append ` ")"` to the form string. The Lisp reader handles nested parentheses correctly. `values` wrapping would require form detection to avoid capturing only the primary value.

```
progn:    (progn (apply-theme :dark) (display :s (make-sphere 20)))
values:   (values (apply-theme :dark) (display :s (make-sphere 20)))
                          ↕
           eval-and-grab-output only captures primary value (values → :DARK only)
```

Decision: Always use `progn`. Simple, correct, zero parsing.

### Decision: Always wrap, never detect

No form-counting or detection logic. Every non-empty form string is wrapped:

```
(+ 1 2)      → (progn (+ 1 2))       ← identical behavior
(+ 1 2)      → (progn (+ 1 2))       ← still identical
(foo) (bar)  → (progn (foo) (bar))   ← works
```

`(progn single-form)` is semantically identical to `single-form` in CL — same return value (including multiple values, which `progn` passes through). Zero-cost abstraction.

### Decision: `--no-progn` opt-out flag

Some forms may have semantics that change inside `progn`. For example:
- `(defparameter *x* 1)` at top level vs inside `progn` — both work identically in live evaluation
- But a user might have a deliberate single-form that wraps its own `progn`-like logic

The `--no-progn` flag restores today's raw behavior. The flag is orthogonal to input source (works with stdin, file, and positional args).

Alternatives considered:
- `--raw`: Rejected — `--no-progn` is self-documenting about what's being disabled
- Always wrap, no opt-out: Rejected — breaks the principle of least surprise for users who send deliberately single-form input
- Auto-detect multi-form and only wrap then: Rejected — requires form detection logic for zero behavioral benefit

### Decision: Wrap in `send-eval`, not in `parse-args`

The wrapping belongs in `send-eval` because it's a protocol-level concern (how the form is packaged for the server), not an input concern (where the form comes from).

```
parse-args:   stdin/file/positional → raw form string
send-eval:    raw form string → flatten newlines → progn wrap → quote → :emacs-rex
```

This keeps `parse-args` clean and means all three input sources automatically get the same wrapping behavior.

### Decision: Flatten newlines before wrapping

Multi-line form strings (from heredocs, file input) contain literal newline characters. These can interact badly with the `%q` quoting and Lisp string escaping on the wire. The fix is to replace all newlines with spaces before any further processing:

```
raw string:  "(progn\n    (display :s (make-sphere 20)))"
flattened:   "(progn     (display :s (make-sphere 20)))"
```

In Lisp, newlines outside of strings and character literals are semantically equivalent to whitespace, so flattening is safe for all code forms.

### Decision: No wire protocol change

The `:emacs-rex` message format is unchanged:

```
Before:
  (:emacs-rex (cl:let (...) (slynk:eval-and-grab-output "(+ 1 2)")) "CL-USER" t 1)

After:
  (:emacs-rex (cl:let (...) (slynk:eval-and-grab-output "(progn (+ 1 2))")) "CL-USER" t 1)
```

Response handling (`process-responses`) is unchanged — still reads one `:return` message and exits.

## Wire Protocol Flow

```
CLIENT                                    SERVER
  │                                         │
  ├── :emacs-rex (progn-wrapped form) ─────▶│
  │                                         ├── (read-from-string "(progn ...)")
  │                                         │    reads ONE form (the progn)
  │                                         ├── evaluates all sub-forms
  │                                         │
  │◀── :write-string (output) ──────────────┤
  │◀── :return (:ok (out-str val-str)) ─────┤
  │                                         │
  ├── print out-str, print val-str          │
  ├── exit 0                                │
```

## Risks / Trade-offs

| Risk | Mitigation |
|---|---|
| `progn` changes semantics for some form (e.g., tagbody, return-from) | These are rare in one-shot eval. `--no-progn` flag provides escape hatch. |
| User sends an explicit `progn` as their single form, double-wrapping | `(progn (progn (foo) (bar)))` is correct and identical to `(progn (foo) (bar))` — no change. |
| User relies on only-first-form semantics (bug compat) | This was undocumented behavior. The fix matches user expectation (all forms run). `--no-progn` preserves old behavior. |
| Large multi-form input could hit length limit in eval-and-grab-output string parsing | Extremely unlikely — Slynk forms are typically small. Same limit exists today for large single forms. |
| Newline flattening corrupts string literals that contain intentional newlines (e.g., `(format t "hello\nworld")`) | Extremely rare in one-shot eval forms. If needed, the user should write the form on a single line or avoid literal newlines in strings. |
