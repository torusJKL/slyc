## ADDED Requirements

### Requirement: Auto-detect interactive mode

When `slyc` evaluates a form and the form signals an error that enters the debugger, `slyc` SHALL auto-detect whether to enter interactive debugger mode or abort (batch mode).

Interactive mode SHALL be activated when ALL of the following are true:
- `--no-debug` flag was NOT provided
- `stdin` is a TTY (`os/isatty stdin` returns true)
- The form was provided via positional argument or `--file` (not from stdin)

Otherwise, batch abort mode SHALL be used.

#### Scenario: argv form + TTY stdin — interactive mode
- **WHEN** user runs `slyc "(error \"test\")"` and stdin is a TTY
- **THEN** `slyc` enters interactive debugger mode on error

#### Scenario: piped stdin — batch mode
- **WHEN** user runs `echo "(error \"test\")" | slyc` (stdin is not a TTY)
- **THEN** `slyc` sends abort and exits with code 1

#### Scenario: --file + TTY stdin — interactive mode
- **WHEN** user runs `slyc -f myfile.lisp` and stdin is a TTY
- **THEN** `slyc` enters interactive debugger mode on error

#### Scenario: argv form + --no-debug — batch mode
- **WHEN** user runs `slyc --no-debug "(error \"test\")"`
- **THEN** `slyc` sends abort and exits with code 1 (batch mode) even though stdin is a TTY

### Requirement: Display debugger menu

When entering interactive debugger mode, `slyc` SHALL display a debugger menu to stdout containing:
- The error condition description and type
- A numbered list of available restarts with name and description
- The top 5 stack frames from the backtrace
- A command prompt (`slyc-db> `)

#### Scenario: Display condition
- **WHEN** Slynk sends a `:debug` message with condition `("Arithmetic error DIVISION-BY-ZERO signalled." "[Condition of type DIVISION-BY-ZERO]")`
- **THEN** `slyc` prints both the condition description and type to stdout

#### Scenario: Display restart list
- **WHEN** Slynk sends a `:debug` message with restarts `(("ABORT" "Return to sly-db level 1.") ("ABORT" "Return to top level."))`
- **THEN** `slyc` prints a numbered list: `0: ABORT — Return to sly-db level 1.` and `1: ABORT — Return to top level.`

#### Scenario: Display initial frames
- **WHEN** Slynk sends a `:debug` message with 10 frames in the frames list
- **THEN** `slyc` prints only the first 5 frames: `0: (...)` through `4: (...)`

#### Scenario: Display prompt
- **WHEN** the debugger menu has been displayed
- **THEN** `slyc` prints `slyc-db> ` and waits for user input from stdin

### Requirement: Accept restart selection

In interactive debugger mode, when the user types a non-negative integer and presses enter, `slyc` SHALL invoke the corresponding restart by sending `(slynk:invoke-nth-restart-for-emacs <level> N)` to the server, where `<level>` is the debug level from the `:debug` message.

After invoking the restart, `slyc` SHALL return to the main message loop to wait for the next `:debug` or `:return` message.

#### Scenario: Select valid restart
- **WHEN** user types `1` at the `slyc-db> ` prompt
- **THEN** `slyc` sends `(:emacs-rex (slynk:invoke-nth-restart-for-emacs <level> 1) nil t <id>)` and returns to the main message loop

#### Scenario: Select restart that resolves error
- **WHEN** user types `0` at the prompt, and the abort restart causes the original eval to complete
- **THEN** `slyc` receives `:return` and prints the result, exiting with code 0

#### Scenario: Select restart that re-enters debugger
- **WHEN** user types `1` at the prompt, and the restart continues into another error
- **THEN** `slyc` receives a new `:debug` message and displays the updated debugger menu

### Requirement: Backtrace command

In interactive debugger mode, when the user types `bt` or `bt N`, `slyc` SHALL fetch and display the backtrace frames.

- `bt` fetches 20 frames starting from frame 0
- `bt N` fetches N frames starting from frame 0
- The wire request uses `(slynk:eval-and-grab-output "(slynk:backtrace 0 N)")` via `send-eval`
- The response is `:return (:ok (output-string result-string))`; `slyc` SHALL print `result-string`

After displaying the backtrace, `slyc` SHALL re-display the prompt.

#### Scenario: bt with default count
- **WHEN** user types `bt` at the prompt
- **THEN** `slyc` sends `(slynk:eval-and-grab-output "(slynk:backtrace 0 20)")` via `send-eval` and displays the resulting string, then shows `slyc-db> ` again

#### Scenario: bt with explicit count
- **WHEN** user types `bt 5` at the prompt
- **THEN** `slyc` sends `(slynk:eval-and-grab-output "(slynk:backtrace 0 5)")` and displays the resulting string

### Requirement: Frame locals command

In interactive debugger mode, when the user types `fr N`, `slyc` SHALL:
1. Set the "current frame" to N
2. Fetch and display the local variables and catch tags for frame N

- The wire request uses `(slynk:eval-and-grab-output "(slynk:frame-locals-and-catch-tags N)")` via `send-eval`
- The response is `:return (:ok (output-string result-string))`; `slyc` SHALL print `result-string`

After displaying the locals, `slyc` SHALL re-display the prompt.

#### Scenario: fr with valid frame number
- **WHEN** user types `fr 0` at the prompt
- **THEN** `slyc` sets current frame to 0, sends `(slynk:eval-and-grab-output "(slynk:frame-locals-and-catch-tags 0)")` via `send-eval`, and displays the resulting string

### Requirement: Frame navigation commands

In interactive debugger mode, `slyc` SHALL support `up` and `down` commands to change the current frame without hitting the wire.

- `up` decrements the current frame number (clamped to 0)
- `down` increments the current frame number
- After `up` or `down`, `slyc` SHALL print the new current frame description (e.g., `Frame N: (description)`) and re-display the prompt

#### Scenario: up from frame 1
- **WHEN** user types `up` at the prompt and the current frame is 1
- **THEN** the current frame becomes 0 and `slyc` prints `Frame 0: (...)`

#### Scenario: down from frame 0
- **WHEN** user types `down` at the prompt and the current frame is 0
- **THEN** the current frame becomes 1 and `slyc` prints `Frame 1: (...)`

### Requirement: Eval-in-frame command

In interactive debugger mode, when the user types `e FORM`, `slyc` SHALL evaluate FORM in the **current frame** and display the result.

- The wire request uses `(slynk:eval-and-grab-output "(slynk:eval-string-in-frame \\"FORM\\" <current-frame> \\"PKG\\")")` via `send-eval`
- The response is `:return (:ok (output-string result-string))`; `slyc` SHALL print `result-string`

After displaying the result, `slyc` SHALL re-display the prompt.

#### Scenario: Simple expression evaluation in current frame
- **WHEN** user types `e (* 2 3)` at the prompt
- **THEN** `slyc` sends `(slynk:eval-and-grab-output "(slynk:eval-string-in-frame \\"(* 2 3)\\" <current-frame> \\"PKG\\")")` via `send-eval` and displays the result string

### Requirement: Quit command

In interactive debugger mode, when the user types `q`, `slyc` SHALL send abort (invoke restart 0) and exit with code 1.

#### Scenario: Quit interactive mode
- **WHEN** user types `q` at the prompt
- **THEN** `slyc` sends abort via `(slynk:invoke-nth-restart 0)`, prints the error condition to stdout, and exits with code 1

### Requirement: Help command

In interactive debugger mode, when the user types `?`, `slyc` SHALL print a comprehensive multi-line help summary of available commands and re-display the prompt.

#### Scenario: Display help
- **WHEN** user types `?` at the prompt
- **THEN** `slyc` prints comprehensive help text and shows `slyc-db> ` again

### Requirement: No timeout during interactive debugger

While in the interactive debugger's inner command loop, `slyc` SHALL pass `nil` (blocking) as the timeout for `read-message`, allowing the session to wait indefinitely for user input.

#### Scenario: Read timeout disabled
- **WHEN** user enters interactive debugger mode and `read-message` is called to read Slynk responses to `bt`/`fr`/`e` commands
- **THEN** the timeout parameter SHALL be `nil` (blocking read)

### Requirement: Handle multiple debugger levels

If a restart invocation causes Slynk to unwind to a higher debug level and send another `:debug` message, `slyc` SHALL display the new debugger menu and continue accepting commands.

#### Scenario: Nested debugger unwinding
- **WHEN** user is at debug level 2, selects restart to abort to level 1, and Slynk sends `:debug` at level 1
- **THEN** `slyc` displays the new debugger menu for level 1 and continues the interactive session

### Requirement: Handle :debug-condition messages

If Slynk sends a `:debug-condition` message during an interactive debugger session, `slyc` SHALL print the condition text to stdout and continue the interactive session.

#### Scenario: Internal debugger error
- **WHEN** Slynk sends `(:debug-condition <thread> "Error printing condition")` while in interactive debugger mode
- **THEN** `slyc` prints the message to stdout and continues accepting commands

### Requirement: Handle cross-thread :debug

If Slynk sends a `:debug` message for a thread other than the one currently being debugged, `slyc` SHALL print a warning to stdout and ignore the message.

#### Scenario: Another thread enters debugger
- **WHEN** Slynk sends `:debug` for thread 42 while `slyc` is debugging thread 12
- **THEN** `slyc` prints a warning (e.g., "Warning: debugger entered in thread 42") to stdout and continues with thread 12's debugger session

### Requirement: Display command legend

When `slyc` enters interactive debugger mode, and whenever the user types `r`, `slyc` SHALL print a compact one-line command legend to stdout before the `slyc-db> ` prompt.

The legend SHALL contain all available commands: `0-9 restart | bt backtrace | fr N frame | up/down | e FORM eval | r restarts | q quit | ? help`

#### Scenario: Legend on initial debugger entry
- **WHEN** `slyc` enters interactive debugger mode after a `:debug` message
- **THEN** after printing condition, restarts, and backtrace, `slyc` prints the compact legend line to stdout

#### Scenario: Legend on `r` command
- **WHEN** user types `r` at the prompt
- **THEN** `slyc` reprints the restarts list and the compact legend line

### Requirement: Reprint restarts

In interactive debugger mode, when the user types `r`, `slyc` SHALL reprint the numbered restart list and the command legend to stdout, then re-display the prompt. The backtrace SHALL NOT be reprinted.

#### Scenario: User requests restarts after scrolling
- **WHEN** user types `r` at the prompt
- **THEN** `slyc` prints the numbered restarts and legend, then shows `slyc-db> ` again

### Requirement: Comprehensive help command

In interactive debugger mode, when the user types `?`, `slyc` SHALL print a multi-line comprehensive help summary to stdout containing:
- A description of each command
- Frame navigation explanation
- Usage examples

After printing the help, `slyc` SHALL re-display the prompt without printing the compact legend.

#### Scenario: Display comprehensive help
- **WHEN** user types `?` at the prompt
- **THEN** `slyc` prints multi-line help text and shows `slyc-db> ` again

### Requirement: Handle :debug-return messages

If Slynk sends a `:debug-return` message, `slyc` SHALL consume it silently without printing anything or affecting the session state.

#### Scenario: Debugger level unwinds
- **WHEN** Slynk sends `(:debug-return <thread> <level> nil)` after a restart resolves an error
- **THEN** `slyc` consumes the message silently and continues waiting for the next message

