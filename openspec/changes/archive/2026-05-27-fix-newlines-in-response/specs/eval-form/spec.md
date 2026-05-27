## MODIFIED Requirements

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

## ADDED Requirements

### Requirement: Parse server response strings with newlines

The system SHALL correctly parse string values in the s-expression wire format that contain newline characters (0x0A). The parsing mechanism SHALL ensure that newlines in server response strings are preserved as newline characters in the resulting Janet strings, not stripped or lost.

#### Scenario: Newlines in `:return` value strings

- **WHEN** the server sends a `:return` message containing a string value with an embedded newline (e.g., captured output from `format t "hello~%world"`)
- **THEN** the system SHALL produce a Janet string that contains the newline character at the correct position
