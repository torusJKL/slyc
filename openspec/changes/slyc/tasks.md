## 1. Project Scaffolding

- [x] 1.1 Create `main.janet` entry point with basic CLI arg parsing (form, --port, --host, --package, --timeout)
- [x] 1.2 Create project structure: `src/` directory, verify Janet can compile standalone
- [x] 1.3 Add help text: `slyc --help` prints usage

## 2. Wire Protocol Implementation

- [x] 2.1 Implement `encode-message`: serialize an s-expression to Slynk wire format (6-hex-digit length + UTF-8 body)
- [x] 2.2 Implement `read-packet`: read a raw message from Slynk stream (6-byte hex length header + body bytes)
- [x] 2.3 Implement `read-message`: read packet, decode UTF-8, parse s-expression
- [x] 2.4 Implement `send-eval`: construct `(:emacs-rex <form> <package> nil <id>)` and send over TCP

## 3. Connection Management

- [x] 3.1 Implement TCP connect to host:port with error handling (connection refused → exit 2)
- [x] 3.2 Implement response reader loop: read messages until `:return` received
- [x] 3.3 Implement timeout mechanism: abort connection after configured seconds (exit 124)
- [x] 3.4 Implement connection teardown: close socket after `:return` or timeout

## 4. Response Handling

- [x] 4.1 Collect `:write-string` messages into output buffer (all targets)
- [x] 4.2 Handle `:return (:ok <value>)`: append princ'd value, flush to stdout, exit 0
- [x] 4.3 Handle `:return (:abort <reason>)`: print condition to stdout, exit 1
- [x] 4.4 Handle `:reader-error` and unknown messages: print to stderr, exit 2

## 5. Integration & Verification

- [x] 5.1 Start a Slynk server, run `slyc "(+ 1 2)"`, verify stdout is "3" and exit 0
- [x] 5.2 Test error form: `slyc '(error "test")'` → exit 1 with condition in stdout
- [x] 5.3 Test timeout: `slyc --timeout 2 "(sleep 10)"` → exit 124 after ~2s
- [x] 5.4 Test connection refused: `slyc --port 1 "(+ 1 2)"` → exit 2 with stderr
- [x] 5.5 Test custom flags: --port, --host, --package all work correctly
- [x] 5.6 Verify standalone binary: `janet -c main.janet slyc.jimage` produces working image (needs wrapper)

## 6. Polishing

- [x] 6.1 Add `--version` flag showing version number
- [x] 6.2 Handle edge case: empty form argument
- [x] 6.3 Handle edge case: extremely large output (multi-message response)
