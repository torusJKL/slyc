# multi-form-input Specification

## Purpose
TBD - created by archiving change add-progn-wrapping. Update Purpose after archive.
## Requirements
### Requirement: Evaluate multiple Lisp forms in sequence

The system SHALL evaluate all Lisp forms provided in a single input when the input contains multiple top-level forms. The forms SHALL be wrapped in `(progn ...)` before sending, so they are evaluated sequentially and only the last form's return value is printed.

#### Scenario: Two forms via stdin

- **WHEN** the user pipes two forms via stdin, e.g., `echo -e "(+ 1 2)\n(* 3 4)" | slyc`
- **THEN** the system SHALL evaluate both forms and print "12" to stdout (the result of the last form)

#### Scenario: Two forms via positional argument

- **WHEN** the user runs `slyc "(setq x 1) (+ x 2)"`
- **THEN** the system SHALL evaluate both forms and print "3" to stdout

#### Scenario: Two forms from file

- **WHEN** the user runs `slyc -f ./multi.lis` and the file contains `(defun a () 1)\n(defun b () 2)\n(a)`
- **THEN** the system SHALL evaluate all forms (defining `a` and `b`, then calling `(a)`) and print "1" to stdout

#### Scenario: Single form unchanged

- **WHEN** the user runs `slyc "(+ 1 2)"`
- **THEN** the system SHALL exit with code 0 and print "3" to stdout (identical to current behavior)

#### Scenario: Progn suppression via `--no-progn`

- **WHEN** the user runs `slyc --no-progn "(+ 1 2) (* 3 4)"`
- **THEN** the system SHALL evaluate only the first form `(+ 1 2)` and print "3" to stdout, ignoring `(* 3 4)`

### Requirement: Last return value only

The system SHALL print only the return value of the last form when multiple forms are provided, matching `progn` semantics.

#### Scenario: Multiple forms with different return values

- **WHEN** the user runs `slyc "(list 1 2) (list 3 4)"`
- **THEN** the system SHALL print "(3 4)" to stdout (result of the last form only)

#### Scenario: Forms with printed output

- **WHEN** the user runs `slyc '(format t "a") (format t "b")'`
- **THEN** the system SHALL print "ab" to stdout (printed output from both forms accumulated, last return value is NIL)

