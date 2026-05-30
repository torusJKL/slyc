## Context

The `slyc` codebase (`src/main.janet`, ~470 lines) contains ~20 functions — internal helpers, wire-protocol primitives, and the debugger REPL — all without docstrings. There are no architectural changes needed; this is purely a documentation-in-code effort.

## Goals / Non-Goals

**Goals:**
- Every `defn` and `defn-` form in `src/main.janet` receives a docstring describing its purpose, arguments, and return value
- Docstrings follow Janet conventions: a literal string as the first form in the function body
- Improve readability for contributors and AI agents reading the source

**Non-Goals:**
- No behavioral, API, or protocol changes
- No changes to tests, docs, or build system
- No automated enforcement (linting/CI) of docstring presence

## Decisions

| Decision | Choice | Rationale |
|---|---|---|
| **Docstring style** | Single-line for simple helpers, multi-line for complex functions | Matches common Janet practice and keeps trivial functions uncluttered |
| **Whether to doc private (`defn-`) functions** | Yes, all functions | Private helpers form the bulk of the code; they are still read by contributors |
| **What to include** | Purpose, each argument (by name), return value, and notable side effects | AI agents and new readers need signature-level understanding without tracing call sites |
| **Whether to doc `main`** | Yes | As the entry point it is especially important for orientation |

## Risks / Trade-offs

| Risk | Mitigation |
|---|---|
| Docstrings drift from behavior if code changes later | No mitigation in this change; can add linting in a follow-up |
| Verbose docstrings on trivial helpers clutter reading | Keep trivial helpers (e.g. `chomp`) to a single line |

## Migration Plan

1. Add docstrings to all functions in `src/main.janet` in a single commit
2. Verify no behavioral changes by running existing tests
