## 1. Argument Parsing — `--no-progn` Flag

- [x] 1.1 Add `no-progn` variable to `parse-args` in `src/main.janet`, defaulting to `false`
- [x] 1.2 Add `--no-progn` flag to the argument loop — no value consumed, just sets `no-progn` to `true`
- [x] 1.3 Include `:no-progn` key in the returned opts table from `parse-args`
- [x] 1.4 Update `print-usage` help text with `--no-progn` flag description and multi-form example

## 2. Progn Wrapping in `send-eval`

- [x] 2.1 Modify `send-eval` to accept a `no-progn` parameter (default `false`)
- [x] 2.2 Flatten newlines in form string (replace `\n` with space) before wrapping — avoids wire-format issues with multi-line forms
- [x] 2.3 When `no-progn` is `false`, wrap flattened form as `"(progn %s)"` before quoting and wrapping in `eval-and-grab-output`
- [x] 2.4 When `no-progn` is `true`, use the flattened `form-str` (current behavior plus flattening)

## 3. Wire Through to Main

- [x] 3.1 In `main`, extract `no-progn` from opts and pass to `send-eval`

## 4. Tests

- [x] 4.1 Verify single form works identically with wrapping — `slyc "(+ 1 2)"` prints "3", exit 0
- [x] 4.2 Test multi-form via stdin — `echo -e "(+ 1 2)\n(* 3 4)" | slyc` prints "12", exit 0
- [x] 4.3 Test multi-form via positional arg — `slyc "(setq x 1) (+ x 2)"` prints "3", exit 0
- [x] 4.4 Test `--no-progn` suppresses wrapping — `slyc --no-progn "(+ 1 2) (* 3 4)"` prints "3" (only first form)
- [x] 4.5 Test `--no-progn` with single form — identical to default behavior
- [x] 4.6 Test backward compatibility — all existing test.sh scenarios still pass
