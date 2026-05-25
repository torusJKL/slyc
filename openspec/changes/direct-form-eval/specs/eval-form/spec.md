## MODIFIED Requirements

### Requirement: Evaluate a Lisp form

The system SHALL accept a Lisp form as a string argument and send it to the Slynk server for evaluation. The form SHALL be sent as a direct s-expression argument in a `:emacs-rex` message over the Slynk wire protocol, not embedded in a string. The thread parameter SHALL be `nil`.

#### Scenario: Simple numeric evaluation

- **WHEN** the user runs `slyc "(+ 1 2)"` against a Slynk server
- **THEN** the system SHALL exit with code 0 and print "3" to stdout

#### Scenario: String evaluation

- **WHEN** the user runs `slyc '(string-upcase "hello")'` against a Slynk server
- **THEN** the system SHALL exit with code 0 and print `"HELLO"` to stdout

#### Scenario: Form with printed output

- **WHEN** the user runs `slyc '(format t "hello, ~a" :world)'` against a Slynk server
- **THEN** the system SHALL exit with code 0 and print "hello, WORLD" to stdout

#### Scenario: Form with reader macro

- **WHEN** the user runs `slyc '#(1 2 3)'` against a Slynk server
- **THEN** the system SHALL print "#(1 2 3)" to stdout and exit 0, because the form is sent as a direct sexpr and the Lisp reader processes the `#()` reader macro

#### Scenario: Form in specific package

- **WHEN** the user runs `slyc --package CL-USER "(find-package :cl)"` against a Slynk server
- **THEN** the system SHALL evaluate the form in the CL-USER package

#### Scenario: Multi-form via stdin with `progn` wrapping

- **WHEN** the user pipes two forms via stdin, e.g., `echo -e "(+ 1 2)\n(* 3 4)" | slyc`
- **THEN** the system SHALL evaluate all forms and print "12" to stdout (result of the last form)

### Requirement: Accumulate streamed output from `:write-string` messages

The system SHALL accumulate text from zero or more `:write-string` messages received before the final `:return`, and print that accumulated text to stdout along with the evaluation result.

#### Scenario: Multi-message streamed output

- **WHEN** the user runs a form that produces output across multiple `:write-string` messages (e.g., chunked `force-output`) followed by a `:return`
- **THEN** the system SHALL print all accumulated `:write-string` text to stdout in order, followed by the return value, and exit with code 0

#### Scenario: Extremely large output

- **WHEN** the user runs a form that produces extremely large output spanning many `:write-string` messages or a single large `:return` body
- **THEN** the system SHALL correctly print all output without truncation, bounded only by available memory
