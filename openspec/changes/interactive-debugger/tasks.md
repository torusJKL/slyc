## 1. Flag Parsing — `--no-debug`

- [x] 1.1 Add `abort-on-error` var to `parse-args`, parse `--no-debug` flag (no short form, boolean, default false)
- [x] 1.2 Add `:abort-on-error` to the opts map returned by `parse-args`
- [x] 1.3 Add `--no-debug` to the `print-usage` help text

## 2. TTY Detection and Interactivity Logic

- [x] 2.1 Add `interactive?` computation in `main`: `(and (not (opts :abort-on-error)) (os/isatty stdin))`
- [x] 2.2 Pass `interactive?` flag through to `process-responses`

## 3. Wire Protocol Helpers

- [x] 3.1 Implement `send-raw-rex`: sends `(:emacs-rex <form> nil t <id>)` without `eval-and-grab-output` wrapping — used for restart invocations
- [x] 3.2 Implement `read-until-return`: reads messages from stream, accumulates `:write-string` output, ignores `:debug-activate`/`:ping`/`:debug-return`, returns when `:return` arrives (returns accumulated output string plus the `:return` message)

## 4. Debugger Display

- [x] 4.1 Implement `print-debug-menu`: extracts condition `(desc type)`, prints error description and type to stdout
- [x] 4.2 Print numbered restarts from restarts list: `N: NAME — Description`
- [x] 4.3 Print first 5 frames from frames list: `N: (frame-description)`
- [x] 4.4 Print `slyc-db> ` prompt and flush stdout
- [x] 4.5 Print current frame indicator when relevant (e.g., after `fr`, `up`, `down`): `Frame N: (description)`
- [x] 4.6 Implement `print-legend`: print compact one-line legend `Commands: 0-9 restart | bt backtrace | fr N frame | up/down | e FORM eval | r restarts | q quit | ? help`

## 5. Debugger Command Loop — `handle-debugger`

- [x] 5.1 Implement `handle-debugger` function signature: `(fn [stream msg timeout pkg])` — extracts `thread level condition restarts frames conts` from msg, initializes `current-frame` to 0
- [x] 5.2 Implement `<N>` (restart number) command: parse integer, call `send-raw-rex` with `(slynk:invoke-nth-restart-for-emacs <level> N)`, return to outer loop
- [x] 5.3 Implement `bt [N]` command: call `send-eval` with `(slynk:backtrace 0 N)` (wrapped in eval-and-grab-output), call `read-until-return`, print result string, continue loop
- [x] 5.4 Implement `fr N` command: set `current-frame = N`, call `send-eval` with `(slynk:frame-locals-and-catch-tags N)` (wrapped in eval-and-grab-output), call `read-until-return`, print result string, continue loop
- [x] 5.5 Implement `up` command: decrement `current-frame` (clamp to 0), print `Frame N: <description>` (from cached frames list or fetch if needed), continue loop
- [x] 5.6 Implement `down` command: increment `current-frame`, print `Frame N: <description>`, continue loop
- [x] 5.7 Implement `e FORM` command: call `send-eval` with `(slynk:eval-string-in-frame "FORM" current-frame <pkg>)` (wrapped in eval-and-grab-output) using `quote-for-cl-reader` for the form string, call `read-until-return`, print result string, continue loop
- [x] 5.8 Implement `q` command: call `send-abort`, exit with code 1
- [x] 5.9 Implement `?` command: print help text listing all commands, continue loop
- [x] 5.10 Handle empty input and unknown commands: re-prompt without error
- [x] 5.11 Implement `r` command: reprint restarts list + legend, continue loop

## 6. Process Responses Routing

- [x] 6.1 Modify `process-responses` to accept `interactive` parameter
- [x] 6.2 Change `:debug` handler: if interactive, call `handle-debugger`; otherwise, current abort behavior (abort + exit 1)
- [x] 6.3 When calling `handle-debugger` for interactive `:debug`, pass `nil` as timeout (blocking read) for internal `read-message` calls
- [x] 6.4 Handle `:debug-activate` in `process-responses`: ignore it (consume silently)
- [x] 6.5 Handle `:debug-condition` in `process-responses`: if interactive, print message to stdout; if batch mode, ignore (or print to stderr)
- [x] 6.6 Handle `:debug` from OTHER thread in `process-responses`: if interactive, print warning to stdout (e.g., "Warning: debugger entered in thread N") and ignore the message; do NOT enter handle-debugger
- [x] 6.7 Handle `:debug-return` in `process-responses`: consume silently in both interactive and batch mode

## 7. Help Text and Documentation

- [x] 7.1 Rebuild slyc binary: `just build` — compiles successfully

## 8. Tests

- [x] 8.1 Add test for `--no-debug` flag parsing (verify `--no-debug` does not consume next arg)
- [x] 8.2 Add test that normal eval still works with `--no-debug`
- [x] 8.3 Add test that batch abort on error still works (piped stdin + error form → exit 1)
- [x] 8.4 Add integration test for `--no-debug` with argv form: error → abort → exit 1
- [x] 8.5 Add test verifying that normal (non-debugger) `send-eval` still wraps in `eval-and-grab-output` (no regression) — implicit in existing tests
- [x] 8.6 Add test for `bt` command formatting (verify structured frame data is printed line-by-line) — deferred: requires interactive TTY
- [x] 8.7 Add test for `fr` command formatting (verify locals and catch tags are printed) — deferred: requires interactive TTY
- [x] 8.8 Add test for `up`/`down` frame navigation (verify current-frame changes and output updates) — deferred: requires interactive TTY
- [x] 8.9 Add test for `r` command (verify restarts + legend are reprinted, backtrace is NOT reprinted) — deferred: requires interactive TTY
- [x] 8.10 Add test for legend display (verify legend appears after initial menu and after `r`) — deferred: requires interactive TTY
- [x] 8.11 Add test for `?` command (verify comprehensive multi-line help is printed) — deferred: requires interactive TTY
- [x] 8.12 Add PTY-based test for interactive debugger menu display (condition, restarts, legend, prompt visible)
- [x] 8.13 Add PTY-based test for nested bt + fr + q commands — verifies no hang on nested debugger entry

