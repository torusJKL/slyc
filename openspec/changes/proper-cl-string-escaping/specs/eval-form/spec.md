## MODIFIED Requirements

### Requirement: Evaluate a Lisp form

The system SHALL accept a Lisp form as a string argument, wrap it in `(progn ...)`, and send it to the Slynk server for evaluation. The wrapping ensures that multiple top-level forms in a single input are all evaluated in sequence. The `--no-progn` flag SHALL disable wrapping, sending the raw form string as-is.

The form string SHALL be escaped for Common Lisp's `read-from-string` before embedding: `\` → `\\`, `"` → `\"`, with all other characters (including newlines) passed through literally. The system MUST NOT replace newlines with spaces.

#### Scenario: Simple numeric evaluation

- **WHEN** the user runs `slyc "(+ 1 2)"` against a Slynk server
- **THEN** the system SHALL exit with code 0 and print "3" to stdout

#### Scenario: String evaluation

- **WHEN** the user runs `slyc '(string-upcase "hello")'` against a Slynk server
- **THEN** the system SHALL exit with code 0 and print `"HELLO"` to stdout

#### Scenario: Form with printed output

- **WHEN** the user runs `slyc '(format t "hello, ~a" :world)'` against a Slynk server
- **THEN** the system SHALL exit with code 0 and print "hello, WORLD" to stdout

#### Scenario: Multi-line printed output

- **WHEN** the user evaluates a form that produces output with embedded newlines (e.g., via a multi-line string literal in the form)
- **THEN** the system SHALL preserve newlines in the output, printing each line separately

#### Scenario: Form in specific package

- **WHEN** the user runs `slyc --package CL-USER "(find-package :cl)"` against a Slynk server
- **THEN** the system SHALL evaluate the form in the CL-USER package

#### Scenario: Opt-out via `--no-progn`

- **WHEN** the user runs `slyc --no-progn "(+ 1 2) (* 3 4)"` against a Slynk server
- **THEN** the system SHALL evaluate ONLY the first form and exit with code 0, because wrapping is suppressed

#### Scenario: `--no-progn` with single form

- **WHEN** the user runs `slyc --no-progn "(+ 1 2)"` against a Slynk server
- **THEN** the system SHALL exit with code 0 and print "3" to stdout (identical to default behavior)

### Requirement: Accumulate streamed output from `:write-string` messages

(Unchanged — see existing spec at `openspec/specs/eval-form/spec.md`)
