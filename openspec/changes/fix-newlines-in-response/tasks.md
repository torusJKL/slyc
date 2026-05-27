## 1. Core Implementation

- [x] 1.1 In `read-message` in `src/main.janet`, add `string/replace-all "\n" "\\n"` before `parse` to escape real newlines in the raw wire data

## 2. Testing

- [x] 2.1 Add integration test for newline via `~%` format directive (e.g., `(format t "hello~%world")`)
- [x] 2.2 Add integration test for newline at start of output (e.g., `(format t "~%world")`)
- [x] 2.3 Add integration test for multiple newlines in output (e.g., `(format t "line1~%line2~%line3~%")`)
- [x] 2.4 Tighten existing multi-line test (test.sh line 229) to check exact line count, not just `>= 2`
- [x] 2.5 Run existing test suite to verify no regression

## 3. Documentation

- [x] 3.1 Update README.md if any caveat about response-path newline handling was documented
