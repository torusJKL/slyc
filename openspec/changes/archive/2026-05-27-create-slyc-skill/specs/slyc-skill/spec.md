## ADDED Requirements

### Requirement: Provide copyable reference SKILL.md

The system SHALL include a reference SKILL.md file at `doc/SKILL.md` that users can copy into their own projects to instruct AI agents how to use `slyc`.

#### Scenario: User copies doc to their project

- **WHEN** a user reads `doc/SKILL.md`
- **THEN** they SHALL have a complete, ready-to-copy SKILL.md that documents how AI agents should use `slyc`

#### Scenario: Covers correct invocation

- **WHEN** an AI agent reads the SKILL.md content
- **THEN** it SHALL find documentation for: basic syntax, available flags (`--port`, `--host`, `--package`, `--timeout`, `--file`, `--no-progn`, `--help`, `--version`), stdin/heredoc input, file input, exit codes (0, 1, 2, 124), stdout vs stderr conventions, and common usage patterns

#### Scenario: Covers result interpretation

- **WHEN** an AI agent reads the SKILL.md content
- **THEN** it SHALL find documentation on how to interpret exit codes, distinguish stdout from stderr, handle Lisp errors, and handle connection/timeout errors

### Requirement: Document platform installation paths

The README.md SHALL document where each AI agent platform expects the SKILL.md file.

#### Scenario: Claude Code path documented

- **WHEN** a user reads `README.md`
- **THEN** they SHALL see that Claude Code expects the file at `.claude/skills/slyc/SKILL.md` with YAML front matter

#### Scenario: OpenCode, Pi, Codex paths documented

- **WHEN** a user reads `README.md`
- **THEN** they SHALL see that OpenCode, Pi, and Codex expect the file at `.agents/skills/slyc/SKILL.md` with YAML front matter
