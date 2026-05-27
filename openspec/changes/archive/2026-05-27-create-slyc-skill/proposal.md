## Why

`slyc` is designed for AI agents to evaluate Common Lisp forms against a Slynk server. For an agent to use `slyc` effectively, its project needs a SKILL.md file that tells the agent when and how to invoke the tool. Currently there's no such reference — users of `slyc` must figure out the invocation patterns themselves and have no template to copy into their own repos.

A reference SKILL.md that users can copy into their own projects solves this: it documents the correct flags, exit codes, common patterns, and how to install the file for each AI agent platform.

## What Changes

- **New doc file**: `doc/SKILL.md` — a ready-to-copy SKILL.md file that users can drop into their own project's `.agents/skills/slyc/` or `.claude/skills/slyc/`
- **Installation instructions in README.md**: Documents where each agent expects the SKILL.md file
- **No in-repo agent behavior change**: The SKILL.md is documentation for others, not wired into this project's `.opencode/`

## Capabilities

### New Capabilities

- `slyc-skill-doc`: A reference SKILL.md file documenting how AI agents should use `slyc`, structured as copyable documentation

### Modified Capabilities

- None

## Impact

- **New file**: `doc/SKILL.md` — the reference skill file
- **No source changes**: the `slyc` CLI is unchanged
- **No agent config changes in this repo**: the reference file lives in `doc/` only
