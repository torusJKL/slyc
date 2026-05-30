## 1. Create Unit Tests in test.janet

- [x] 1.1 Replace `tests/test.janet` stub with real unit tests using `testament` and proper module imports
- [x] 1.2 Write tests for `chomp` — newline, no newline, multiple newlines, empty, spaces, consecutive newlines
- [x] 1.3 Write tests for `quote-for-cl-reader` — plain, backslash, double-quote, both, empty, control chars, trailing backslash
- [x] 1.4 Write tests for `princ-lisp` — string, number, boolean, nil, tuple, array, buffer, keyword, symbol, empty collections, nested tuples, zero, negative
- [x] 1.5 Write tests for `load-version` — returns a string, value check
- [x] 1.6 Write tests for `print-debug-condition` / `print-restarts` / `print-frames` — type checks

## 2. Argument Parsing Tests

- [x] 2.1 Test `parse-args` with basic form — defaults (port, host, timeout, no-progn, no-debug)
- [x] 2.2 Test `parse-args` with port (long/short), host (long/short), package, timeout (long/short)
- [x] 2.3 Test `parse-args` with flags —no-progn, --no-debug
- [x] 2.4 Test `parse-args` with combined options and form containing dashes

## 3. Wire Protocol Tests

- [x] 3.1 Write tests for wire header format — 6-char hex strings at various lengths
- [x] 3.2 Write tests for REX message structure — progn wrapping, with/without package, with/without progn
- [x] 3.3 Write tests for `send-raw-rex` and `send-abort` message format

## 3. Update Build & CI

- [x] 3.1 Update `justfile` — change `test` recipe to run `janet tests/test.janet && bash tests/test.sh`
- [x] 3.2 Update `.github/workflows/pr-checks.yml` to install testament and run unit tests before integration tests
- [x] 3.3 Verify unit tests pass — 7 tests, 35 assertions, all pass
