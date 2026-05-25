## ADDED Requirements

### Requirement: Accept form from stdin

The system SHALL accept a Lisp form from standard input when stdin is not a TTY and no positional form or `--file` flag is provided.

#### Scenario: Piped input

- **WHEN** the user pipes a form to `slyc`, e.g., `echo "(+ 1 2)" | slyc`
- **THEN** the system SHALL read the form from stdin, evaluate it, and print the result to stdout

#### Scenario: Heredoc input

- **WHEN** the user passes a form via heredoc, e.g., `slyc << 'EOF' (+ 1 2) EOF`
- **THEN** the system SHALL read the form from stdin, evaluate it, and print the result to stdout

#### Scenario: Redirected input

- **WHEN** the user redirects a file to stdin, e.g., `slyc < ./my.lis`
- **THEN** the system SHALL read the form from stdin, evaluate it, and print the result to stdout

#### Scenario: Trailing newline stripped

- **WHEN** the form read from stdin ends with a newline character
- **THEN** the system SHALL strip exactly one trailing newline (`\n`) before sending the form for evaluation

### Requirement: Reject empty stdin

The system SHALL detect when stdin is piped/redirected but contains no input.

#### Scenario: Empty piped input

- **WHEN** the user pipes an empty string, e.g., `echo "" | slyc` or `echo -n "" | slyc`
- **THEN** the system SHALL print an error to stderr and exit with code 2

### Requirement: TTY stdin ignored

The system SHALL NOT attempt to read from a TTY stdin when no positional form is provided.

#### Scenario: Interactive terminal with no form

- **WHEN** the user runs `slyc` in an interactive terminal without a positional form or `--file`
- **THEN** the system SHALL print "error: no form provided" to stderr and exit with code 2 (unchanged from current behavior)
