## Context

The response pipeline from the Slynk server to the client is:

```
CL server evaluates form
  → output string captured (may contain newlines)
  → CL printer (prin1-to-string) serializes as s-expression
  → wire: length-prefixed UTF-8
  → read-message: read-exactly → parse → Janet data structure
                        ↓                 ↓
                 raw bytes (may    parse strips 0x0A
                 contain 0x0A)    from strings → newlines LOST
```

The `parse` function interprets newlines inside strings as whitespace and discards them. This is correct Janet behavior for source code parsing (newlines separate tokens), but incorrect for wire protocol data where newlines are meaningful content.

## Goals / Non-Goals

**Goals:**
- Preserve newlines in all server response strings (both `:write-string` and `:return` content)
- Minimal change — single function modification in `src/main.janet`
- Zero behavioral change for all outputs without embedded newlines
- No new dependencies

**Non-Goals:**
- Fixing Janet's `parse` behavior (it's correct for its domain — we adapt)
- Protocol changes — same length-prefixed s-expression wire format
- Handling non-ASCII control characters in responses (tab, null, etc.) — they work naturally or aren't expected
- CLI changes — no new flags or options

## Decisions

### Decision: Escape newlines in raw wire data before `parse`

The fix is a single line in `read-message`:

```janet
(def raw (read-exactly stream len timeout))
(def escaped (string/replace-all "\n" "\\n" raw))
(parse escaped)
```

This converts real newline bytes (0x0A) into the two-character sequence `\` + `n`. Janet's `parse` interprets `\n` inside strings as a newline, producing the correct string.

### Decision: Replace ALL newlines, not just those inside strings

The wire format from Slynk uses compact s-expressions with newlines only inside string literals. All structural newlines (between s-expression elements) are already absent from the compact `prin1-to-string` output. If a future Slynk version added pretty-printing with structural newlines, they would be converted to `\n` before `parse`, which `parse` would treat as whitespace and skip — same as the current behavior. Safe by design.

### Decision: Pre-parse escape, not post-parse fix

Alternatives considered:
1. **Post-parse tree walk**: Recursively walk the parsed data structure and re-insert newlines. Rejected because once `parse` has stripped the newlines, we can't know where they were.
2. **Custom s-expression parser**: Write our own parser for the wire format. Rejected because `parse` handles everything else correctly; we just need this one fix.
3. **Server-side fix**: Modify Slynk to emit `\n` escape sequences. Rejected because it requires server cooperation and impacts all SLIME/SLY clients.

Pre-parse escaping is the simplest, most localized fix with zero side effects.

### Decision: No behavioral change for empty/non-newline output

`string/replace-all "\n" "\\n"` is a no-op when no newlines are present. All existing output is byte-identical to the current behavior for single-line output.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| A future Slynk version adds pretty-printing with structural newlines | Structural newlines become `\n` which `parse` treats as whitespace — same as real newlines today. No functional change. |
| A server response contains `\\n` (backslash followed by n) naturally | This would be double-escaped to `\\\\n`. In CL output, literal `\n` is rare. Post-parse tree walk could fix this but isn't worth the complexity. |
| Null bytes (0x00) or other control characters in output | Null bytes are not valid UTF-8 and would cause errors before `parse`. Not a concern for CL output. |
| Newlines in `:write-string` target field | The `:write-string` message format is `(:write-string <text> <target>)`. The target is typically a keyword like `:repl-result`. Newlines in the text field need preservation too — the fix applies to the entire message, covering both fields. |

## Wire Protocol Diagram

```
Current (newlines lost):
┌──────────────────────────────────────────────┐
│ CL server response (prin1-to-string):         │
│   (:return (:ok ("hello\nworld" "NIL")) 1)   │
│                         ↑                     │
│                 real 0x0A byte                │
│                                               │
│ Janet parse → "helloworld" ← newline stripped │
└──────────────────────────────────────────────┘

After fix (newlines preserved):
┌──────────────────────────────────────────────┐
│ Raw wire (same as before):                    │
│   (:return (:ok ("hello\nworld" "NIL")) 1)   │
│                         ↑                     │
│                 real 0x0A byte                │
│                                               │
│ string/replace-all "\n" "\\n" →               │
│   (:return (:ok ("hello\nworld" "NIL")) 1)   │
│                         ↑                     │
│              two chars: \ and n               │
│                                               │
│ Janet parse → "hello\nworld" ← newline kept   │
└──────────────────────────────────────────────┘
```
