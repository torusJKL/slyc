## Why

`slyc` replaces all newlines in the input form with spaces before sending (`string/replace-all "\n" " "` in `send-eval`). This corrupts string literals containing real newlines (e.g., a heredoc with a multi-line string), causing the Lisp server to evaluate a semantically different form and produce different output than when the same form is evaluated via SLY. As AI agents increasingly generate Lisp code with multi-line string content, this is no longer "extremely rare."

## What Changes

- **Remove newline flattening**: `string/replace-all "\n" " "` line in `send-eval` is removed — newlines in the form are preserved.
- **Replace `%q` with proper CL string escaping**: Instead of using Janet's `%q` (which produces Janet-format escapes that CL's reader misinterprets), implement a `quote-for-cl-reader` function that escapes `\` → `\\` and `"` → `\"` per CL's single-escape rules, and leaves newlines and all other characters as-is.
- **Wire format unchanged**: The `:emacs-rex` message format stays the same — only the escaping of the inner form string changes.
- **No CLI flag changes**: No new flags, no removed flags. Backward compatible for all inputs that don't contain real newlines inside string literals.

## Capabilities

### New Capabilities

- `multi-line-output`: Preserve newlines in Lisp string literals so that multi-line output is displayed correctly. This is a new capability — previously, multi-line string output was silently corrupted.

### Modified Capabilities

- `eval-form`: The form delivery mechanism changes from `%q`-with-flattening to CL-correct string escaping. The requirement "the form is sent to the server" remains — only the escaping implementation changes.

## Impact

- **Single file changed**: `src/main.janet` — `send-eval` gets a new `quote-for-cl-reader` helper, and `%q` is replaced with properly escaped `%s`.
- **No protocol changes**: Same `:emacs-rex` wire format, same length-prefixed TCP framing.
- **No new dependencies**: Pure string manipulation using Janet's standard library.
- **No CLI changes**: No new flags, no changed defaults.
- **Backward compatible**: All inputs without real newlines inside string literals produce identical output. Inputs with multi-line strings (previously corrupted) now produce correct output.
