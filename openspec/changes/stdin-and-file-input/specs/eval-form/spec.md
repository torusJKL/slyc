## MODIFIED Requirements

### Requirement: Evaluate a Lisp form

The system SHALL accept a Lisp form and send it to the Slynk server for evaluation. The form SHALL be obtained from one of three sources in order of precedence: `--file` flag, positional CLI argument, or stdin (when not a TTY). The form SHALL be sent as a `:emacs-rex` message over the Slynk wire protocol.

#### Scenario: Form from positional argument

- **WHEN** the user runs `slyc "(+ 1 2)"` against a Slynk server
- **THEN** the system SHALL exit with code 0 and print "3" to stdout

#### Scenario: Form from file

- **WHEN** the user runs `slyc -f ./add.lis` and `./add.lis` contains `(+ 1 2)`
- **THEN** the system SHALL exit with code 0 and print "3" to stdout

#### Scenario: Form from stdin

- **WHEN** the user pipes a form, e.g., `echo "(+ 1 2)" | slyc`
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
