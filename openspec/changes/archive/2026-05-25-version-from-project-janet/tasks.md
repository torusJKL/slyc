## 1. Core Implementation

- [x] 1.1 Add `load-version` helper at top of `src/main.janet` that uses `peg/match` to extract `:version "..."` from `project.janet`, falling back to `"unknown"` if file is missing or PEG returns nil
- [x] 1.2 Replace hardcoded `(def version "0.1.0")` on line 2 with `(def version (load-version))`
- [x] 1.3 Verify `janet src/main.janet --version` prints version from `project.janet`
- [x] 1.4 Test `"unknown"` fallback by running from a temp directory without `project.janet`
- [x] 1.5 Run the test suite (`just test`) to ensure nothing is broken
