## Context

Slyc is a single-file Janet CLI that evaluates one Lisp form against Slynk and exits. The wire protocol uses length-prefixed s-expressions over TCP. Currently, when Slynk enters the debugger, it sends a `:debug` message containing the condition, restarts, and stack frames. Slyc ignores all of this, sends abort (`(slynk:invoke-nth-restart 0)`), prints the condition text to stderr, and exits 1.

The Slynk debugger protocol is a loop — after sending `:debug` + `:debug-activate`, the server waits for more `:emacs-rex` commands (restart invocation, backtrace queries, eval requests). This means the client can participate interactively without any server changes.

## Goals / Non-Goals

**Goals:**
- Interactive debugger mode when a human is at the terminal (form from argv/`--file` + TTY stdin)
- Present error condition, restart list, and backtrace frames in a readable format
- Accept user commands: restart selection by number, backtrace, frame locals, eval-in-frame, quit
- `--no-debug` flag to force batch abort (current behavior) even when auto-detect would choose interactive
- Disable network read timeout during interactive debugger sessions
- All changes confined to `src/main.janet` — no server-side modifications

**Non-Goals:**
- Not a full REPL — only one form evaluated per slyc invocation, debugger interaction is for that form
- No source-location display or source-level debugging
- No thread control (only the thread that hit the error)
- No persistent debugger state between slyc invocations

## Decisions

### Decision 1: Auto-detection via `os/isatty`

**Chosen:** `(and (not abort-on-error) (os/isatty stdin))`

- If stdin is a TTY, the form cannot have come from stdin (current code only reads stdin when not a TTY). So the user is present at a terminal.
- If stdin is not a TTY (pipe, redirect, heredoc), no user is present — batch mode.
- `--no-debug` overrides regardless.

Alternatives considered:
- An explicit `--interactive` flag instead of auto-detect. Rejected because auto-detect covers all real scenarios — you can't have both "form from stdin" and "user waiting at terminal" simultaneously.
- A `--debug` flag that enables interactive mode. Rejected because the default should be interactive-when-possible, with `--no-debug` as the escape hatch for AI agent use or scripting.

### Decision 2: Debugger command set

**Chosen:** Minimal but complete set, matching SLY's effective surface:

| Command | Action | Wire message |
|---------|--------|-------------|
| `<N>` | Invoke restart N | `(slynk:invoke-nth-restart-for-emacs <level> N)` |
| `bt [N]` | Show backtrace (top N frames, default 20) | `(slynk:backtrace 0 N)` |
| `fr N` | Set current frame to N and show locals | `(slynk:frame-locals-and-catch-tags N)` |
| `up` | Move current frame up (decrement) | (local state change) |
| `down` | Move current frame down (increment) | (local state change) |
| `e FORM` | Eval FORM in current frame context | `(slynk:eval-string-in-frame "FORM" <current-frame> <pkg>)` |
| `r` | Reprint restarts + legend | (local, no wire message) |
| `q` | Abort and exit (restart 0) | `(slynk:invoke-nth-restart 0)` |
| `?` | Print comprehensive help | (local, no wire message) |

- `fr N` both sets the "current frame" cursor and displays locals for that frame.
- `up`/`down` adjust the current frame cursor without hitting the wire.
- `e FORM` evaluates in the current frame, not hardcoded frame 0.
- `r` reprints the restarts list and the compact legend, but not the backtrace.
- `?` prints multi-line comprehensive help with examples.

Alternatives considered:
- More complex command grammar (`frame N locals`, separate `set-frame` command). Rejected — `fr N` is idiomatic (like SLY's frame-button actions) and the combined set+show is natural.
- pprint-eval instead of eval. `slynk:eval-string-in-frame` is the SLY standard and results are formatted by the server via `echo-for-emacs`.

### Decision 3: Two-level message loop architecture

**Chosen:** `process-responses` outer loop delegates to `handle-debugger` which has its own inner message loop.

```
process-responses (outer loop):
  read-message from wire
  case type:
    :debug (current thread) → handle-debugger (enters inner loop)
    :debug (other thread)   → print warning, ignore
    :debug-condition        → print to stdout (debugger internal error)
    :debug-return            → consume silently
    :debug-activate          → consume silently
    :return                  → print result, exit
    :write-string             → buffer output
    :ping                     → ignore
    ...

handle-debugger (inner loop):
  print debug menu from :debug message
  set current-frame = 0
  loop:
    read user input from stdin
    case command:
      <N>  → send-raw-rex (invoke-nth-restart-for-emacs level N), return to outer loop
      bt   → send-direct-rex (backtrace ...), read-until-return, format frames, continue
      fr   → set current-frame = N, send-direct-rex (frame-locals ...), read-until-return, format locals, continue
      up   → current-frame--, print frame header, continue
      down → current-frame++, print frame header, continue
      e    → send-direct-rex (eval-string-in-frame "FORM" current-frame pkg), read-until-return, print, continue
      r    → print restarts + legend, continue
      q    → send-abort, exit 1
      ?    → print comprehensive help, continue
```

After `invoke-nth-restart-for-emacs` (a number command), control returns to `process-responses`. The server will either:
- Send another `:debug` (restart didn't resolve the error — e.g., "continue" into another error)
- Send `:return` (restart resolved the error — original form completes)

For `bt`, `fr`, `e` commands, the inner loop uses `read-until-return` to wait for the specific `:return` response to that command's `:emacs-rex`, then continues prompting the user.

### Decision 4: Wire request types for debugger commands

**Chosen:** Use `send-raw-rex` for restart invocations (`invoke-nth-restart-for-emacs` and `invoke-nth-restart`), and the existing `send-eval` (with `eval-and-grab-output` wrapping) for all debugger queries (`backtrace`, `frame-locals-and-catch-tags`, `eval-string-in-frame`).

`send-raw-rex` sends the form directly as `(:emacs-rex <form> nil t <id>)` without wrapping — needed for restart invocations since they may transfer control rather than return normally.

`send-eval` wraps the form in `(cl:let ((slynk:*echo-number-alist* nil)) (slynk:eval-and-grab-output ...))`. This produces a standard `:return (:ok (output-string result-string))` that the existing `:return` handler can process. The result is a Lisp-printed string representation, which we print directly. This is slightly less pretty than structured formatting but significantly simpler to implement and maintain.

Normal `send-eval` is unchanged and continues to be used for the initial form evaluation.

| Wire message | Helper | Purpose |
|---|---|---|
| `(:emacs-rex (slynk:invoke-nth-restart-for-emacs <level> N) nil t <id>)` | `send-raw-rex` | Restart invocation (control may transfer) |
| `(:emacs-rex (slynk:eval-and-grab-output "(slynk:backtrace 0 20)") nil t <id>)` | `send-eval` | Backtrace query (string return) |
| `(:emacs-rex (slynk:eval-and-grab-output "(slynk:frame-locals-and-catch-tags N)") nil t <id>)` | `send-eval` | Frame locals (string return) |
| `(:emacs-rex (slynk:eval-and-grab-output "(slynk:eval-string-in-frame \\"FORM\\" N \\"PKG\\")") nil t <id>)` | `send-eval` | Eval in frame (string return) |

### Decision 5: Timeout disabled during interactive debugger

**Chosen:** Pass `nil` as timeout to `read-message` when in interactive debugger mode.

The Slynk server responds immediately to `:emacs-rex` commands during `sly-db-loop` — there is no long operation to wait for. Blocking indefinitely is safe. The user controls the session duration.

If the server goes away (crash, network drop), the network read will fail with a connection error, which we handle the same way as current timeout/connection errors (exit 2).

### Decision 6: Initial frame display

**Chosen:** Show top 5 frames from the `:debug` message's frame list on initial entry. The user can request more with `bt N`.

The `:debug` message includes `(debugger-info-for-emacs 0 *sly-db-initial-frames*)` where `*sly-db-initial-frames*` defaults to 20 on the server. We display only 5 by default to keep the initial output manageable, and `bt 20` shows the full set.

### Decision 7: Output channel for debug menus

**Chosen:** Print debugger interaction (menu, prompts, results of bt/fr/e) to stdout.

The current contract (stdout = result/info) still holds — in interactive mode, the debug menu IS the relevant output. Since slyc is connected to a user's terminal, stdout is the natural display channel. stderr remains for infrastructure errors.

### Decision 8: Current frame tracking

**Chosen:** `handle-debugger` maintains a mutable `current-frame` integer, initialized to 0 on every debugger entry.

- `fr N` sets `current-frame = N` and fetches locals for that frame.
- `up` decrements `current-frame` (clamped to 0).
- `down` increments `current-frame` (no upper clamp — if the user goes past the backtrace end, the next wire request will simply return empty data, which we display as "[no such frame]").
- `e FORM` uses `current-frame` in the wire request.

This mirrors SLY's implicit "selected frame" behavior without requiring a full Emacs buffer model.

### Decision 9: Handling auxiliary debugger messages

**Chosen:** `process-responses` explicitly handles three additional message types during interactive mode:

- **`:debug-condition <thread> <message>`** — printed to stdout inline (e.g., "Error printing condition: ..."). The inner loop continues.
- **`:debug <thread> <level> ...>` from a *different* thread** — a warning is printed to stdout (e.g., "Warning: debugger entered in thread N"), and the message is ignored. We continue with the current thread's debugger.
- **`:debug-return <thread> <level> <stepping>`** — consumed silently. It signals that a debugger level has unwound. We don't need to act on it because we already returned to `process-responses` after `invoke-nth-restart-for-emacs`, but consuming it prevents misrouting it as an unknown message type.

### Decision 10: Command legend display

**Chosen:** Print a compact one-line legend after every debugger menu (initial entry and `r` command).

Legend format:
```
Commands: 0-9 restart | bt backtrace | fr N frame | up/down | e FORM eval | r restarts | q quit | ? help
```

- Printed to stdout as the last line before the `slyc-db> ` prompt.
- On initial `:debug` entry, the legend appears after the condition + restarts + backtrace.
- On `r`, only restarts + legend are reprinted (no backtrace, keeping it compact).
- `?` prints a separate multi-line comprehensive help, then the prompt (no legend after `?`).
- Modern terminals wrap long lines automatically, so no manual wrapping is implemented.

## Risks / Trade-offs

- **[TTY detection false positive]** If stdin is a TTY but no human is watching (e.g., launched from a script that allocates a PTY), slyc will enter interactive mode and hang waiting for input. → Mitigation: `--no-debug` is always available as an override. Scripts should use it.
- **[Readline/editing]** The stdin read is raw — no line editing, history, or tab completion. → Mitigation: Acceptable for an MVP. Future enhancement could add linenoise or similar.
- **[Concurrent :debug from other threads]** Slynk could send `:debug` for a different thread while we're debugging the current one. → Mitigation: We print a warning and ignore it (Decision 9). This is safer than the previous plan of silently replacing the menu.
- **[Backquote in forms]** `e FORM` uses Lisp string escaping via `quote-for-cl-reader`. Complex forms with nested quotes may be hard to type correctly. → Mitigation: `e` uses `eval-string-in-frame` which takes a string and parses it — users write normal Lisp syntax. String escaping of the outer string is handled by slyc's existing `quote-for-cl-reader`.
- **[Structured data parsing complexity]** Using direct `:emacs-rex` means we must parse backtrace frames and frame locals in Janet instead of relying on Lisp `prin1` output. → Mitigation: The data structures are regular s-expressions; Janet's `parse` handles them natively. The formatting logic is straightforward.

