# file-input Specification

## Purpose
Accept a Lisp form from a file via `--file` / `-f` flag.

## Requirements
### Requirement: Accept form from file

The system SHALL accept a Lisp form from a file specified via `--file` or `-f` flag.

#### Scenario: File with valid form

- **WHEN** the user runs `slyc -f ./my.lis` and the file contains `(+ 1 2)`
- **THEN** the system SHALL evaluate the form and print "3" to stdout, exiting with code 0

#### Scenario: File with newline suffix

- **WHEN** the file specified via `--file` ends with a trailing newline
- **THEN** the system SHALL strip exactly one trailing newline (`\n`) before sending the form for evaluation

### Requirement: Report file-not-found errors

The system SHALL report when the file specified via `--file` does not exist or cannot be read.

#### Scenario: Non-existent file

- **WHEN** the user runs `slyc -f /nonexistent/file.lis`
- **THEN** the system SHALL print an error to stderr and exit with code 2

### Requirement: Reject conflicting input sources

The system SHALL detect when `--file` and a positional form are both provided.

#### Scenario: Conflicting `--file` and positional arg

- **WHEN** the user runs `slyc -f ./my.lis "(+ 1 2)"`
- **THEN** the system SHALL print an error to stderr and exit with code 2
