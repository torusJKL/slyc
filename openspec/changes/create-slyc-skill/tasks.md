## 1. Create `doc/` directory and reference SKILL.md

- [x] 1.1 Create `doc/` directory if it doesn't exist
- [x] 1.2 Write `doc/SKILL.md` with YAML front matter for OpenCode format
- [x] 1.3 Write "Overview" section: what slyc is, when agents should use it
- [x] 1.4 Write "Usage" section: full flags reference, stdin/file input, heredocs
- [x] 1.5 Write "Result handling" section: exit codes, stdout/stderr, error patterns
- [x] 1.6 Write "Common patterns" section: variable checks, function calls, format output, package work
- [x] 1.7 Write "Troubleshooting" section: connection refused, timeout, package not found, string escaping
- [x] 1.8a Write "Platform adaptation" section in `doc/SKILL.md` (moved to README)
- [x] 1.8b Remove "Platform adaptation" section from `doc/SKILL.md`, add to `README.md` instead

## 2. Verification

- [x] 2.1 Verify all `slyc` flags are correctly documented (compare flags against `src/main.janet` parse-args)
- [x] 2.2 Verify exit codes match implementation (0=success, 1=lisp-error, 2=protocol-error, 124=timeout)
- [x] 2.3 Verify YAML front matter is syntactically correct in the OpenCode variant
- [x] 2.4 Verify platform adaptation notes are accurate
