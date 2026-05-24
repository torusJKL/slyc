## ADDED Requirements

### Requirement: Evaluate a Lisp form

The system SHALL accept a Lisp form as a string argument and send it to the Slynk server for evaluation. The form SHALL be sent as a `:emacs-rex` message over the Slynk wire protocol.

#### Scenario: Simple numeric evaluation

- **WHEN** the user runs `slyc "(+ 1 2)"` against a Slynk server
- **THEN** the system SHALL exit with code 0 and print "3" to stdout

#### Scenario: String evaluation

- **WHEN** the user runs `slyc '(string-upcase "hello")'` against a Slynk server
- **THEN** the system SHALL exit with code 0 and print `"HELLO"` to stdout

#### Scenario: Form with printed output

- **WHEN** the user runs `slyc '(format t "hello, ~a" :world)'` against a Slynk server
- **THEN** the system SHALL exit with code 0 and print "hello, WORLD" to stdout

#### Scenario: Form in specific package

- **WHEN** the user runs `slyc --package CL-USER "(find-package :cl)"` against a Slynk server
- **THEN** the system SHALL evaluate the form in the CL-USER package

### Requirement: Handle Lisp errors

The system SHALL detect when a form signals a Lisp error and report it appropriately.

#### Scenario: Form signals an error

- **WHEN** the user runs `slyc '(error "my bad")'` against a Slynk server
- **THEN** the system SHALL exit with code 1 and print the condition message to stdout

### Requirement: Handle timeout

The system SHALL abort if the form takes longer than the configured timeout.

#### Scenario: Form exceeds timeout

- **WHEN** the user runs `slyc --timeout 1 "(sleep 10)"` against a Slynk server
- **THEN** the system SHALL exit with code 124 after approximately 1 second

#### Scenario: Default timeout

- **WHEN** the user runs `slyc "(sleep 35)"` against a Slynk server without specifying `--timeout`
- **THEN** the system SHALL exit with code 124 after approximately 30 seconds

### Requirement: Return value presentation

The system SHALL print the return value in a human-readable format suitable for AI agent consumption.

#### Scenario: Boolean result

- **WHEN** the user runs `slyc "(oddp 2)"` against a Slynk server
- **THEN** the system SHALL print "NIL" to stdout and exit 0

#### Scenario: List result

- **WHEN** the user runs `slyc "(list 1 2 3)"` against a Slynk server
- **THEN** the system SHALL exit with code 0 and print "(1 2 3)" to stdout

#### Scenario: Keyword result

- **WHEN** the user runs `slyc ":hello"` against a Slynk server
- **THEN** the system SHALL exit with code 0 and print ":HELLO" to stdout
