# multi-line-output Specification

## Purpose
Preserve newlines in Lisp string literals so that multi-line output is displayed correctly.

## Requirements
### Requirement: Preserve newlines in string literals

The system SHALL preserve actual newline characters (0x0A) that appear inside string literals in the input form. The system MUST NOT replace newlines with spaces or any other character. Newlines MUST be passed through to the Slynk server unmodified within the string argument to `slynk:eval-and-grab-output`.

#### Scenario: Multi-line string in heredoc input

- **WHEN** the user pipes a form with a multi-line string via heredoc:
  ```
  slyc << 'EOF'
  (format t "hello
  world")
  EOF
  ```
- **THEN** the system SHALL print exactly "hello" followed by a newline followed by "world" to stdout

#### Scenario: Multi-line string from file

- **WHEN** the user specifies `--file` with a file containing a form with a multi-line string literal
- **THEN** the system SHALL preserve the newline inside the string and print the correct multi-line output

#### Scenario: Backward compat — single-line string unchanged

- **WHEN** the user runs `slyc '(format t "hello world")'` against a Slynk server
- **THEN** the system SHALL print "hello world" to stdout (identical output to previous versions)

### Requirement: Correct escaping for CL reader

The system SHALL escape characters in the form string that are special to Common Lisp's `read-from-string` before embedding them in the `:emacs-rex` message. Specifically, the system SHALL escape `\` as `\\` and `"` as `\"`. All other characters (including newlines, tabs, and Unicode) SHALL pass through literally.

#### Scenario: Form with backslash in string

- **WHEN** the user runs `slyc '(format t "path\\\\to\\\\file")'` against a Slynk server
- **THEN** the system SHALL print "path\to\file" to stdout

#### Scenario: Form with escaped double-quote

- **WHEN** the user runs `slyc '(format t "he said \\"hello\\"")'` against a Slynk server
- **THEN** the system SHALL print `he said "hello"` to stdout
