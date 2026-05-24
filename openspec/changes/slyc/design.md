## Context

The Slynk wire protocol (defined in `slynk-rpc.lisp`) transports s-expressions over TCP. Each message is a 6-byte hex length prefix followed by UTF-8 encoded s-expression body. The server listens on a configurable port (default 4005) and accepts connections. The client sends `:emacs-rex` forms for evaluation; the server responds with `:write-string` (streamed output) and `:return` (final result).

Current state: No CLI client exists. The `main/` project in this repo handles Slynk server management. This is the missing client half.

Key constraints:
- **Cold start every invocation** — AI agents spawn `slyc` fresh each time
- **Janet-lang** — chosen for native s-expression handling and fast startup
- **Agent-consumed output** — exit codes + clean stdout

## Goals / Non-Goals

**Goals:**
- One-shot eval: `slyc "(+ 1 2)"` → stdout `3`, exit 0
- Support `--port`, `--host`, `--package`, `--timeout` flags
- Handle optional `.slynk-secret` auth (ignore for MVP)
- Collect `:write-string` output and `:return` result
- Exit 0 on success, 1 on Lisp error, 2 on protocol/connection error, 124 on timeout
- Standalone binary (via `janet -m`)

**Non-Goals:**
- Debugger interaction (entering debugger = abort)
- SLIME/SLY compatibility layer
- REPL mode or persistent session
- Multiple eval forms in one invocation
- Windows/macOS in MVP

## Decisions

### Language: Janet over Rust

| Factor | Janet | Rust |
|---|---|---|
| S-expr parsing | `(parse string)` — built in | Need crate or 100+ lines |
| S-expr generation | `(string/format "~S" ...)` — built in | Need crate |
| TCP networking | `(net/connect ...)` — built in | `std::net` or tokio |
| CLI argument parsing | `(dynarr/dynacl-argv ...)` or manual | `clap` crate |
| Cold start | ~2-5ms | ~0-5ms |
| Standalone binary | `janet -m` → ~1MB | `cargo build` → ~5MB |
| Lines of code | ~80-120 | ~200-300 |

Decision: Janet. The native s-expression support eliminates the single biggest complexity of the protocol.

### Protocol: Direct `:emacs-rex` vs `eval-and-grab-output`

Approach: Use `:emacs-rex` directly with the user's form, collecting `:write-string` messages and the final `:return`. This avoids hard-wiring the client to internal Slynk helper functions.

### Output: Clean text for agents

The client collects all `:write-string` output in order, appends the return value, and writes to stdout. Stderr is reserved for infrastructure errors (connection refused, timeout). Exit codes distinguish success from Lisp errors from infra errors.

## Wire Protocol Detail

```
CONNECTION:
  TCP → host:port

CLIENT SENDS (if auth required):
  00000e                    ← 6 hex digit length
  <secret>                  ← raw secret string

CLIENT SENDS (eval):
  00002c
  (:emacs-rex (+ 1 2) "CL-USER" nil 1)
   ─┬── ───┬── ──┬──── ─┬─ ─┬
    form   pkg   id     thr  opts

SERVER RESPONDS (zero or more of each):
  000022
  (:write-string "hello" :repl-result)
   ───┬─── ───┬── ──────┬─────
     type    text      target

  000017
  (:return (:ok "hello\n3") 1)
  ───┬── ───────┬─────── ─┬
   type  (:ok val) /   continuation id
         (:abort reason)
```

### Server Message Handling

| Message | Action |
|---|---|
| `(:write-string <text> <target>)` | Append text to output buffer (all targets) |
| `(:return (:ok <value>) <id>)` | Append `(princ-to-string value)` to output, flush to stdout, exit 0 |
| `(:return (:abort <reason>) <id>)` | Append reason to stdout, exit 1 |
| `(:debug ...)` | Send abort restart, flush, exit 1 |
| `(:reader-error <packet> <cause>)` | Print cause to stderr, exit 2 |
| Any unknown message | Ignore, continue reading |

### Exit Code Design

```
0  — Success. Lisp form evaluated, result in stdout.
1  — Lisp error. Form aborted/signaled error, condition text in stdout.
2  — Protocol/connection error. Wrong port, connection refused, broken protocol.
124 — Timeout. Form did not complete within --timeout seconds.
```

## Risks / Trade-offs

| Risk | Mitigation |
|---|---|
| Connection hangs on debugger entry | Timeout kills the connection. No debugger interaction = no hanging. |
| Large output buffers (`:write-string` floods) | Read in a loop, append to buffer. Memory-bound only by available RAM. |
| Binary size with embedded Janet | `janet -m` produces ~1MB standalone; acceptable. |
| Slynk protocol version mismatch | The protocol is stable (decades of SLIME/SLY). `:emacs-rex` format hasn't changed. |

## Open Questions

- Should we compile via `janet -m` (single jimage) or distribute the source with Janet dependency?
- Add `--file` for reading form from file? (Post-MVP)
- Should `:write-string` to `:error-output` go to stderr or stdout? (Currently: all to stdout for agent simplicity)
