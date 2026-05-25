## Why

When piping multiple Lisp forms via stdin (heredocs, multi-line input), only the first form is evaluated — the rest are silently ignored. Wrapping stdin input in `(progn ...)` ensures all forms are evaluated in sequence, making `slyc` work naturally with multi-form input sources.

## What Changes

- **`progn` wrapping by default**: All form input (stdin, file, positional) is wrapped in `(progn ...)` before sending to the Slynk server. This is a no-op for single forms (`(progn (+ 1 2))` ≡ `(+ 1 2)`) but evaluates all forms for multi-form input.
- **New `--no-progn` flag**: Suppresses `progn` wrapping for cases where the user explicitly wants a single-form context (e.g., testing a form that happens to contain multiple top-level expressions).
- **Updated help text**: Document the new `--no-progn` flag.

## Capabilities

### New Capabilities
- `multi-form-input`: Accept multiple Lisp forms from any input source (stdin, file, positional) and evaluate all of them in sequence. Only the last form's return value is printed, matching `progn` semantics.

### Modified Capabilities
- `eval-form`: The form delivery mechanism now wraps all input in `(progn ...)` by default. Users can suppress wrapping with `--no-progn`.

## Impact

- **Single file changed**: `src/main.janet` — `send-eval` wrapping logic and `parse-args` for the new `--no-progn` flag
- **No protocol changes**: The Slynk wire protocol is unchanged; only the form string is transformed before quoting
- **No new dependencies**: Janet's `string/format` covers the wrapping
- **Backward compatible**: Single forms produce identical results. `--no-progn` matches today's behavior exactly.
