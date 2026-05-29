## Context

`src/main.janet` always sends a hard-coded `"CL-USER"` in the `:emacs-rex` wire packet's package slot. This overrides the Slynk server's own preferred package — any server that sets `slynk:*default-package-for-slime-interactions*` (or similar) will have its preference ignored. The fix is small: default to `nil` (the Lisp nil symbol, sent unquoted), which tells Slynk "use the server default."

Current wire format (always):
```
(:emacs-rex <form> "CL-USER" t <id>)
```

Desired wire format (without --package):
```
(:emacs-rex <form> nil t <id>)
```

Desired wire format (with --package):
```
(:emacs-rex <form> "MY-PKG" t <id>)
```

## Goals / Non-Goals

**Goals:**
- Remove the `CL-USER` default so Slynk servers control the package when no `--package` is given
- Keep `--package` working identically when explicitly used
- Clean up `send-abort` to use `nil` for consistency
- Update help text, SKILL.md, and README to reflect new default

**Non-Goals:**
- No other protocol changes
- No changes to connection handling, eval flow, or result processing
- No new CLI flags

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Sentinel value | `nil` (not a separate boolean) | Package names are always non-empty strings; `nil` is naturally disjoint. No need for a separate `explicit-package?` flag. |
| `send-eval` condition | `(if pkg (quote-for-cl-reader pkg) "nil")` | When pkg is nil, emit the bare symbol `nil` (not the string `"nil"`). `quote-for-cl-reader` always produces a quoted string, so we skip it for nil. |
| `send-abort` | Change to `nil` | `slynk:invoke-nth-restart 0` is package-independent. Sending a package at all is unnecessary but harmless — switching to `nil` is cleaner and internally consistent. |
| Remove `default-package` constant | Yes | It's only used in `parse-args` as the initial value for the `pkg` var. `(var pkg nil)` is clearer and removes one line. |

## Risks / Trade-offs

- **[Backward compatibility] → Accepted**: Users relying on implicit CL-USER evaluation will see different symbol resolution. This is a **BREAKING** change.
- **[nil vs "nil" confusion] → Unlikely**: `nil` in a Janet `string/format` is printed as `"nil"` by default. We must explicitly emit the string `"nil"` (unquoted) to get the bare Lisp symbol. This is handled correctly by the conditional in `send-eval`.
