## Why

`slyc` currently embeds the form inside a string and routes it through `slynk:eval-and-grab-output`, forcing a `read-from-string` round-trip on the server. This means the form is read in the context of a fresh string stream rather than directly as a wire sexpr — breaking forms that depend on the current readtable, reader macros, or certain package interactions.

SLY (and SLIME) send the form as a native sexpr in the `:emacs-rex` message. The form is part of the wire protocol's s-expression, evaluated directly by Slynk without an intermediate `read-from-string`. Moving to direct `:emacs-rex` makes slyc behave identically to SLY: if a form works in SLY, it works in slyc.

## What Changes

- **Direct `:emacs-rex`**: The form string is embedded directly as a sexpr in the `:emacs-rex` message, not inside a string passed to `eval-and-grab-output`. **BREAKING**: the response format changes — `:return (:ok ...)` now carries a single `princ-to-string` result instead of the `(out-str val-str)` pair from `eval-and-grab-output`.
- **Thread parameter**: Change from `t` to `nil` (matching SLY's convention, avoiding thread-related issues).
- **Remove `eval-and-grab-output` wrapper**: The `(cl:let ((slynk:*echo-number-alist* nil)) ...)` and `slynk:eval-and-grab-output` are removed entirely.
- **Progn wrapping**: The existing `(progn ...)` wrapping still applies, but now wraps the actual sexpr rather than a string inside `eval-and-grab-output`.
- **`--no-progn`**: Kept as-is — continues to suppress wrapping.
- **Response handling**: `process-responses` `:return (:ok ...)` arm changed to read a single value instead of a pair.
- **`princ-lisp`**: No longer needed for `:return` value formatting (the value is already a string), but kept for `:abort` fallback.

## Capabilities

### New Capabilities
- (none)

### Modified Capabilities
- `eval-form`: The form delivery mechanism changes from `eval-and-grab-output` string embedding to direct `:emacs-rex` sexpr. The response format of `:ok` changes from a value pair to a single string. All existing eval scenarios remain valid with updated implementation.

## Impact

- **Single file changed**: `src/main.janet` — `send-eval` rewritten, `process-responses` `:return (:ok ...)` handler updated
- **No new dependencies**: All changes use existing standard library functions
- **No protocol change**: The wire protocol (`:emacs-rex` type, format, response types) is identical — only the content of the form argument changes
- **Backward compatible for users**: Same CLI interface, same exit codes, same output format
