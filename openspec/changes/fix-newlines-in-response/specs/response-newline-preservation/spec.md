## ADDED Requirements

### Requirement: Preserve newlines in server response strings

The system SHALL preserve newline characters (0x0A) that appear inside string values in `:return` and `:write-string` messages from the Slynk server. The system MUST NOT strip, replace, or otherwise lose newlines when parsing server responses from the wire format. The system SHALL ensure that a newline character produced by CL's `format t "~%"` or embedded in a CL string literal appears as a newline in the final stdout output.

#### Scenario: Newline via `~%` format directive

- **WHEN** the user runs `slyc '(format t "hello~%world")'` against a Slynk server
- **THEN** the system SHALL print exactly "hello" followed by a newline followed by "world" to stdout

#### Scenario: Newline at start of output

- **WHEN** the user runs `slyc '(format t "~%world")'` against a Slynk server
- **THEN** the system SHALL print a blank line followed by "world" to stdout

#### Scenario: Multiple newlines in output

- **WHEN** the user runs `slyc '(format t "line1~%line2~%line3~%")'` against a Slynk server
- **THEN** the system SHALL print "line1", "line2", and "line3" on separate lines to stdout

#### Scenario: Newlines via `:write-string` messages

- **WHEN** the user runs a form that produces output across multiple `:write-string` messages, some containing newlines
- **THEN** the system SHALL preserve newlines within each `:write-string` text and in the accumulated concatenation
