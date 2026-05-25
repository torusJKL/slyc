## 1. Argument Parsing — `--file` Flag

- [x] 1.1 Add `-f`/`--file` flag to `parse-args` in `src/main.janet` — store file path in opts table
- [x] 1.2 Add conflict detection: error + exit 2 if `--file` and positional form are both provided
- [x] 1.3 Update form acquisition logic: `--file` > positional arg > stdin (non-TTY) > error

## 2. File Input

- [x] 2.1 Implement file reading function: open file, read all content, strip trailing newline, close
- [x] 2.2 Handle file-not-found error: print to stderr, exit 2

## 3. Stdin Input

- [x] 3.1 Implement stdin detection: use `(os/isatty :stdin)` to check if stdin is a terminal
- [x] 3.2 Implement stdin reading function: read all from stdin, strip trailing newline
- [x] 3.3 Handle empty stdin: detect empty string, print error to stderr, exit 2

## 4. Help Text & Edge Cases

- [x] 4.1 Update `print-usage` help text with `--file`/`-f` flag and stdin examples
- [x] 4.2 Handle edge case: empty file (same as empty stdin — error + exit 2)
- [x] 4.3 Handle edge case: file with only whitespace (strip newline, form is empty — error + exit 2)

## 5. Tests

- [x] 5.1 Verify `slyc "(+ 1 2)"` still works (backward compat — no regression)
- [x] 5.2 Test `slyc -f ./test.lis` with a valid form file
- [x] 5.3 Test `echo "(+ 1 2)" | slyc` piped stdin
- [x] 5.4 Test `slyc -f /nonexistent` — error + exit 2
- [x] 5.5 Test `slyc -f ./test.lis "(+ 1 2)"` — conflicting sources error + exit 2
- [x] 5.6 Test interactive terminal with no args — error + exit 2 (unchanged behavior)
