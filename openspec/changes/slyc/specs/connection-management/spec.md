## ADDED Requirements

### Requirement: Connect to Slynk server

The system SHALL establish a TCP connection to a Slynk server.

#### Scenario: Default connection

- **WHEN** the user runs `slyc "(+ 1 2)"` without specifying `--host` or `--port`
- **THEN** the system SHALL connect to `127.0.0.1:4005`

#### Scenario: Custom port

- **WHEN** the user runs `slyc --port 7889 "(+ 1 2)"`
- **THEN** the system SHALL connect to `127.0.0.1:7889`

#### Scenario: Custom host

- **WHEN** the user runs `slyc --host 10.0.0.1 "(+ 1 2)"`
- **THEN** the system SHALL connect to `10.0.0.1:4005`

#### Scenario: Custom host and port

- **WHEN** the user runs `slyc --host example.com --port 9999 "(+ 1 2)"`
- **THEN** the system SHALL connect to `example.com:9999`

### Requirement: Connection failure handling

The system SHALL report connection failures clearly.

#### Scenario: Connection refused

- **WHEN** the user runs `slyc --port 1 "(+ 1 2)"` and no server is listening on that port
- **THEN** the system SHALL exit with code 2 and print an error to stderr

#### Scenario: Host not found

- **WHEN** the user runs `slyc --host nonexistent.example.com "(+ 1 2)"`
- **THEN** the system SHALL exit with code 2 and print an error to stderr

### Requirement: Wire protocol encoding

The system SHALL encode messages using the Slynk wire protocol format (6-byte hex length prefix + UTF-8 s-expression body).

#### Scenario: Correct message format

- **WHEN** the system sends a form to the Slynk server
- **THEN** the message SHALL be formatted as `0000XX<s-expression>` where `XXXXXX` is the 6-hex-digit length of the UTF-8 encoded body

### Requirement: Wire protocol decoding

The system SHALL decode messages received from the Slynk server.

#### Scenario: Read incoming message

- **WHEN** the system receives data from the Slynk server
- **THEN** it SHALL read a 6-byte hex length prefix, then read that many bytes, and parse the result as an s-expression

### Requirement: Optional authentication

The system SHALL support sending the `.slynk-secret` if required by the server.

#### Scenario: Secret not required

- **WHEN** the Slynk server does not require auth (no `.slynk-secret` file on the server)
- **THEN** the system SHALL immediately send the eval form

#### Scenario: Secret required (stretch)

- **WHEN** the Slynk server requires auth
- **THEN** the system SHALL read `~/.slynk-secret` and send the secret string before the eval form

### Requirement: Clean connection teardown

The system SHALL close the TCP connection after receiving the final response or on timeout/error.

#### Scenario: Normal teardown

- **WHEN** the system receives a `:return` message
- **THEN** the system SHALL close the TCP connection and exit

#### Scenario: Timeout teardown

- **WHEN** the system times out waiting for a response
- **THEN** the system SHALL close the TCP connection immediately and exit with code 124
