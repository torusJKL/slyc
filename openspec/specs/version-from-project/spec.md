# version-from-project Specification

## Purpose
Read the project version from `project.janet` at startup, so `--version` always reflects the canonical source of truth.

## Requirements
### Requirement: Display version from project.janet

The system SHALL read the project version from `project.janet` at load time and display it when `--version` is passed.

#### Scenario: Version printed from project.janet

- **WHEN** the user runs `slyc --version` and `project.janet` contains `:version "0.2.0"`
- **THEN** the system SHALL print "0.2.0" to stdout and exit with code 0

#### Scenario: Version matches declare-project

- **WHEN** the user runs `slyc --version` and `project.janet` declares `(declare-project :version "1.0.0")`
- **THEN** the system SHALL print "1.0.0" to stdout

### Requirement: Fallback when project.janet is missing

The system SHALL display `"unknown"` when `project.janet` cannot be found.

#### Scenario: No project.janet in CWD

- **WHEN** the user runs `slyc --version` from a directory that does not contain `project.janet`
- **THEN** the system SHALL print "unknown" to stdout and exit with code 0

### Requirement: Version resolution on module load

The system SHALL resolve the version string exactly once, at module load time, using a PEG match against `project.janet`.

#### Scenario: Version constant for process lifetime

- **WHEN** the system starts
- **THEN** the version SHALL be determined before any form is evaluated and remain constant for the lifetime of the process
