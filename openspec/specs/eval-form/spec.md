# eval-form Specification

## Purpose
TBD - created by archiving change slyc. Update Purpose after archive.
## Requirements
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

### Requirement: Accumulate streamed output from `:write-string` messages

The system SHALL accumulate text from zero or more `:write-string` messages received before the final `:return`, and print that accumulated text to stdout along with the evaluation result. The accumulated text SHALL preserve newline characters (0x0A) that appear within any `:write-string` message text.

#### Scenario: Multi-message streamed output

- **WHEN** the user runs a form that produces output across multiple `:write-string` messages (e.g., chunked `force-output`) followed by a `:return`
- **THEN** the system SHALL print all accumulated `:write-string` text to stdout in order, followed by the return value, and exit with code 0

#### Scenario: Extremely large output

- **WHEN** the user runs a form that produces extremely large output spanning many `:write-string` messages or a single large `:return` body
- **THEN** the system SHALL correctly print all output without truncation, bounded only by available memory

#### Scenario: Multi-message streamed output with newlines

- **WHEN** the user runs a form that produces multi-line output across multiple `:write-string` messages
- **THEN** the system SHALL print all accumulated `:write-string` text to stdout in order, with newlines preserved in the concatenated output

### Requirement: Parse server response strings with newlines

The system SHALL correctly parse string values in the s-expression wire format that contain newline characters (0x0A). The parsing mechanism SHALL ensure that newlines in server response strings are preserved as newline characters in the resulting Janet strings, not stripped or lost.

#### Scenario: Newlines in `:return` value strings

- **WHEN** the server sends a `:return` message containing a string value with an embedded newline (e.g., captured output from `format t "hello~%world"`)
- **THEN** the system SHALL produce a Janet string that contains the newline character at the correct position

