## Why

The `slyc` codebase has ~20 functions with zero docstrings, making it difficult for contributors and AI agents to understand the code without reading every line. Adding docstrings will improve maintainability, reduce onboarding friction, and make the code self-documenting.

## What Changes

- Add a docstring to every public and private function across all source files
- Docstrings follow Janet conventions: a string literal as the first form in the function body, describing the function's purpose, arguments, and return value
- No behavioral or API changes — strictly documentation

## Capabilities

### New Capabilities

_(None — this is a purely internal code quality change with no spec-level behavior.)_

### Modified Capabilities

_(None — no existing specs have requirement changes.)_

## Impact

- **Single source file affected**: `src/main.janet`
- **~20 functions** will receive docstrings
- Zero runtime impact (docstrings are compile-time constants in Janet)
- No API, protocol, or behavioral changes
