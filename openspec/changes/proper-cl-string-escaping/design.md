## Context

`slyc` sends Lisp forms to a Slynk server by embedding the form as a quoted string inside an `:emacs-rex` s-expression. The current flow:

```
raw form string
  → string/replace-all "\n" " "      ← flatten newlines to spaces
  → (progn ...) wrap                  ← multi-form support
  → (string/format "%q" ...)          ← Janet %q quoting for inner string
  → embed in (:emacs-rex ...) message
  → write-wire (length-prefixed TCP)
```

The `%q` specifier produces Janet-format string escapes (e.g., `\n` for newline, `\"` for double-quote). These are then parsed by Common Lisp's `read-from-string` on the server side, which uses different escaping conventions — CL's single-escape backslash treats `\n` as just `n` (not a newline), creating a mismatch.

The newline flattening was added as a workaround to avoid this mismatch, but it corrupts string literals containing real newlines. We now replace both the flattening AND the `%q` usage with proper CL-aware string escaping.

## Goals / Non-Goals

**Goals:**
- Preserve newlines in form string literals (multi-line strings pass through uncorrupted)
- Correctly escape `\` and `"` for Common Lisp's `read-from-string`
- Maintain backward compatibility for inputs without real newlines in strings
- Single file change to `src/main.janet`, no new dependencies

**Non-Goals:**
- Supporting input with other control characters in string literals (tab, null, etc.) — these work naturally but aren't a target
- Wire protocol changes — same `:emacs-rex` format, same TCP framing
- CLI UI changes — no new flags or options
- Multi-byte encoding handling — inputs are assumed to be UTF-8 (same as today)

## Decisions

### Decision: Write `quote-for-cl-reader` helper instead of using `%q`

The core insight: Common Lisp's `read-from-string` treats strings with specific escaping rules:
- `\\` → literal backslash
- `\"` → literal double-quote
- All other characters (including real newlines) are literal

Janet's `%q` produces valid Janet-format escapes (`\n`, `\t`, etc.) which do NOT match CL's reader. So we need our own quoting function:

```
CL string escaping:
  \  →  \\        (backslash → escaped backslash)
  "  →  \"        (double-quote → escaped double-quote)
  \n →  preserved  (real newline stays as-is in the string)
```

The new flow:

```
raw form string
  → (progn ...) wrap                   ← unchanged
  → quote-for-cl-reader               ← NEW: CL-correct escaping + surrounding quotes
  → embed with %s instead of %q       ← changed from %q to %s
  → embed in (:emacs-rex ...) message
  → write-wire
```

The `%s` specifier inserts the already-quoted string directly — no additional escaping.

### Decision: Remove flattening, not just work around it

We considered keeping `string/replace-all "\n" " "` and converting newlines to CL-recognizable escape sequences like `~%` before `%q`. Rejected because:
- `~%` is a format directive, not a string escape — it only works with `format`, not `read-from-string`
- Converting to `\\n` (backslash-n, two chars) before `%q` would have `%q` re-escape the backslash to `\\\\n` — producing literal `\n` in CL, not a newline
- Any pre/post processing scheme around `%q` is fragile and has edge cases

The cleanest fix is to own the full escaping pipeline rather than patching around `%q`.

### Decision: No CLI flag for old behavior

The behavior change only affects forms with real newlines inside string literals — which were producing WRONG results before. There's no legitimate use case for the old behavior. Adding a `--legacy-escaping` flag would add surface area for no benefit.

### Decision: Keep `%q` for package name

Only the form string escaping needs to change. The package name argument (`%q` on line 118) goes through the same `:emacs-rex` format string but is a simple keyword/symbol name — unlikely to contain backslashes or quotes. `%q` is fine for that slot. However, for consistency and to avoid future surprises, both `%q` uses are replaced.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Edge case: form contains a real `\` that `quote-for-cl-reader` doubles, changing semantics | `\` outside of strings in CL code is the single-escape character — doubling it changes nothing (escaped-nothing = nothing). `\` inside strings needs to be `\\` to mean literal `\` in CL, which is exactly what we do. Correct by design. |
| Edge case: form contains a standalone `"` not part of a string (CL syntax error) | CL reader would reject this regardless of our escaping. No regression. |
| Regression: `%q` handled some character we haven't thought of | We only need to handle `\` and `"` for CL string safety. All other characters (including newlines, tabs, Unicode, nulls) pass through literally, which is valid in CL strings. |
| Large input with many `\` or `"` characters has slightly larger wire size | Escaping adds at most 2x for those characters. Wire size is negligible at slyc's scale. |
| Slynk readtable modifications affect string parsing | Slynk uses `read-from-string` with `*readtable*` potentially bound. Standard CL string escaping is well-defined and should not be affected by readtable modifications (string syntax is fixed by the reader algorithm, not the readtable). |

## Wire Protocol Diagram

```
Before (current):
┌─────────────────────────────────────────────────────────┐
│ (:emacs-rex                                              │
│   (cl:let ((slynk:*echo-number-alist* nil))             │
│     (slynk:eval-and-grab-output                         │
│       "(progn (format t \"hello world\"))"))             │
│   "CL-USER" t 1)                                         │
└─────────────────────────────────────────────────────────┘
                           ↑
                    newline→space, string corrupted

After (new):
┌─────────────────────────────────────────────────────────┐
│ (:emacs-rex                                              │
│   (cl:let ((slynk:*echo-number-alist* nil))             │
│     (slynk:eval-and-grab-output                         │
│       "(progn (format t \"hello                           │
│ world\"))"))                                             │
│   "CL-USER" t 1)                                         │
└─────────────────────────────────────────────────────────┘
                           ↑
                   real newline preserved in CL string
```
