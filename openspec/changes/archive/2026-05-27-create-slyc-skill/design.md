## Context

`slyc` is a CLI tool for AI agents to evaluate CL forms against a Slynk server. AI agents discover tools through SKILL.md-style files placed in their project.

Each AI agent platform has its own SKILL.md conventions:

| Platform | File Location | Front Matter |
|----------|--------------|-------------|
| **Claude Code** | `.claude/skills/slyc/SKILL.md` | YAML front matter with name, description, license, compatibility, metadata |
| **OpenCode** | `.agents/skills/slyc/SKILL.md` | YAML front matter with name, description, license, compatibility, metadata |
| **Pi** | `.agents/skills/slyc/SKILL.md` | YAML front matter with name, description, license, compatibility, metadata |
| **Codex** | `.agents/skills/slyc/SKILL.md` | YAML front matter with name, description, license, compatibility, metadata |

This change produces a reference SKILL.md in `doc/SKILL.md`. The file is documentation — users copy it into their own project and adapt per their agent.

## Goals / Non-Goals

**Goals:**
- A complete, copyable SKILL.md file at `doc/SKILL.md`
- Documents all `slyc` flags (`--port`, `--host`, `--package`, `--timeout`, `--file`, `--no-progn`, `--help`, `--version`), stdin/heredoc input, exit codes, common patterns, troubleshooting
- Documents the formatting differences between OpenCode, Claude Code, and Pi so the user can adapt
- Self-contained — everything the agent needs is in the skill file, no cross-references to README

**Non-Goals:**
- Placing the file in `.opencode/` or any other active agent config directory
- Creating companion files (AGENTS.md, PI.md, etc.)
- Installing this skill in the `slyc` repo itself — this is documentation for downstream users

## Decisions

### Decision: Output to `doc/SKILL.md` as a reference document

The file lives in `doc/` because it's project documentation, not active agent configuration. Users copy it from here to their own project.

### Decision: README.md documents platform adaptation, not the skill file

Platform adaptation instructions belong in `README.md` so `doc/SKILL.md` stays a pure copyable template with no self-referential metadata.

### Decision: Agent skill content structure

```
---
YAML front matter for OpenCode
---

## Overview
- What slyc is, what problem it solves

## When to use slyc
- Trigger conditions: need to eval CL code, check Lisp values, test forms
- When NOT to use: debugging/stepping, multi-form sessions, code generation

## Usage
- Basic syntax: slyc "<form>"
- Flags table: --port, --host, --package, --timeout, --file, --no-progn, --help, --version
- Multi-form input (stdin, heredocs)
- File input via --file

## Result handling
- Exit code reference (0, 1, 2, 124)
- stdout vs stderr conventions
- Error handling patterns

## Common patterns
- Checking variable values
- Calling functions
- Format output
- Working with packages

## Troubleshooting
- Connection refused
- Timeout
- Package not found
- String escaping (CL vs agent quoting)

## Platform adaptation
- How to install for OpenCode
- How to adapt for Claude Code
- How to adapt for Pi
```

### Decision: Front matter metadata

```yaml
---
name: slyc
description: Instructs AI agents when and how to use slyc to evaluate Common Lisp forms against a Slynk server and read results from the REPL
license: MIT
compatibility: Requires slyc binary installed in PATH
metadata:
  author: slyc
  version: "1.0"
---
```

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| User copies the file and doesn't remove YAML front matter for non-OpenCode agents | The doc explicitly calls out which parts to add/remove per platform |
| SKILL.md goes stale as slyc gains new flags | Located in `doc/` alongside other docs; update as part of feature work |
| Agent platforms evolve their format | Adaptation notes make migration easy to update |
