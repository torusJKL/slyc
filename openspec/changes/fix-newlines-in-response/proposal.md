## Why

The `proper-cl-string-escaping` change fixed how forms are sent to the server (request path), but the response path (server → client) still loses newlines. When CL output contains newlines, SBCL's `prin1-to-string` serializes them as real 0x0A bytes in the wire format. Janet's `parse` function strips 0x0A bytes from parsed strings, so multi-line output arrives at the client with all newlines removed. The same `(format t "hello~%world")` that produces `hello\nworld` in SLIME produces `helloworld` in slyc.

## What Changes

- **Escape newlines in server responses**: Before calling `parse` on wire messages, replace real newline characters (0x0A) with `\n` escape sequences so that `parse` correctly interprets them as newlines in the parsed strings.
- **No protocol changes**: The wire format remains identical — only the client-side parsing pipeline changes.
- **No CLI flag changes**: All existing flags and behavior are preserved. Newlines in output now work correctly.

## Capabilities

### New Capabilities

- `response-newline-preservation`: Preserve newline characters (0x0A) in server response strings so that multi-line output from CL forms like `(format t "hello~%world")` is displayed correctly to the user.

### Modified Capabilities

- `eval-form`: The output delivery mechanism for the `:return` response gains newline-preserving parsing of the wire format. All existing scenarios remain behaviorally identical for single-line output. Multi-line output scenarios (previously silently corrupted) now work correctly.

## Impact

- **Single file changed**: `src/main.janet` — the `read-message` function gains a `string/replace-all` step before `parse` to escape real newlines.
- **No protocol changes**: Same `:return` wire format, same length-prefixed TCP framing.
- **No new dependencies**: Pure string manipulation using Janet's standard library.
- **No CLI changes**: No new flags, no changed defaults.
- **Backward compatible**: All output without embedded newlines produces identical output. Output with embedded newlines (previously corrupted) now works correctly.
