## ADDED Requirements

### Requirement: Parse --no-debug flag

`slyc` SHALL accept a `--no-debug` command-line flag. When provided, `slyc` SHALL use batch abort behavior on debugger entry regardless of TTY detection.

The flag has no short form. It takes no argument.

#### Scenario: --no-debug with argv form
- **WHEN** user runs `slyc --no-debug "(error \"test\")"` with TTY stdin
- **THEN** `slyc` sends abort and exits with code 1, printing the error condition to stdout

#### Scenario: --no-debug with --file
- **WHEN** user runs `slyc --no-debug -f myfile.lisp` with TTY stdin
- **THEN** `slyc` sends abort and exits with code 1 on debugger entry

#### Scenario: --no-debug in help output
- **WHEN** user runs `slyc --help`
- **THEN** the help text includes `--no-debug` with a description

#### Scenario: --no-debug with piped stdin (redundant but harmless)
- **WHEN** user runs `echo "(error \"test\")" | slyc --no-debug`
- **THEN** `slyc` sends abort and exits with code 1 (same as without the flag, since piped stdin already triggers batch mode)

### Requirement: Flag parsing behavior

The `--no-debug` flag SHALL be a boolean option. It SHALL be `false` by default. It SHALL NOT consume any following argument.

#### Scenario: Positional form still works after --no-debug
- **WHEN** user runs `slyc --no-debug "(+ 1 2)"`
- **THEN** the form `(+ 1 2)` is correctly parsed and evaluated, result is `3`, exit 0

#### Scenario: --no-debug does not conflict with other flags
- **WHEN** user runs `slyc --no-debug --port 4006 --package CL-USER "(error \"test\")"`
- **THEN** all flags are parsed correctly and batch abort is used on debugger entry
