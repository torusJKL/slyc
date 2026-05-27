## 1. Core Implementation

- [x] 1.1 Add `quote-for-cl-reader` function in `src/main.janet` that escapes `\` → `\\` and `"` → `\"` per CL's single-escape rules, wrapping the result in double quotes
- [x] 1.2 Remove `string/replace-all "\n" " "` from `send-eval` in `src/main.janet`
- [x] 1.3 Replace `%q` with `%s` + `quote-for-cl-reader` for the form string argument in `send-eval`
- [x] 1.4 Replace `%q` with `%s` + `quote-for-cl-reader` for the package name for consistency

## 2. Testing

- [x] 2.1 Add test for multi-line string output (heredoc with literal newline in string)
- [x] 2.2 Add test for backslash escaping in form strings
- [x] 2.3 Add test for double-quote escaping in form strings
- [x] 2.4 Run existing test suite to verify no regression

## 3. Documentation

- [x] 3.1 Update README.md to remove the newline-flattening caveat and replace with description of correct CL string escaping
