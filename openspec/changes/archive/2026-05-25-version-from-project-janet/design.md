## Context

`slyc --version` currently prints a hardcoded string `"0.1.0"` defined at `src/main.janet:2`. The project's canonical version is declared in `project.janet:3` as `"0.2.0"`. These values have drifted. The project uses `jpm build` to compile a standalone native binary; the binary embeds all Janet source but does not bundle `project.janet`.

## Goals / Non-Goals

**Goals:**
- Single source of truth for version: `project.janet`
- `--version` always reflects `project.janet`'s version, regardless of build mode
- Minimal code change to `src/main.janet`

**Non-Goals:**
- Changing `project.janet`'s format or `declare-project` macro
- Adding new build steps or external dependencies
- Modifying `--version` output format

## Decisions

**Use PEG to extract `:version` from `project.janet`.**
Janet's built-in PEG engine can directly match the pattern `:version "..."` with a single `peg/match` call: sequence of `(thru ":version")`, skip whitespace, then capture the content between double quotes. This is simpler, faster, and more robust than parsing the full file as Janet source.

**Load at module level, not per-invocation.**
The version is constant for the lifetime of the process. Compute it once at load time (top-level `def`), same as the current hardcoded def.

**Resolution order:**
1. PEG-match `./project.janet` for `:version "..."` (CWD — works for `janet src/main.janet` and running from project root)
2. Fallback to `"unknown"` if file is missing or PEG returns nil

## Risks / Trade-offs

| Risk | Mitigation |
|------|-----------|
| `project.janet` not found when running compiled binary outside project dir | Fallback to `"unknown"` — version is cosmetic, not functional |
| PEG match fails (malformed or unexpected format) | Return nil from `peg/match`; fall back to `"unknown"` |
| PEG match runs at load time (minor startup cost) | Single-pass scan of ~8 lines; negligible vs. TCP connect |
