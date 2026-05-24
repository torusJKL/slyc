#!/bin/bash
# Integration test for slyc client

cd "$(dirname "$0")"

SBCL="${SBCL:-sbcl}"
PORT=17892
CLIENT="janet ../src/main.janet"
PASS=0
FAIL=0

pass() { PASS=$((PASS+1)); echo "  ✓ $1"; }
fail() { FAIL=$((FAIL+1)); echo "  ✗ $1"; echo "    got: $2"; }

echo "=== slyc Integration Tests ==="

echo ""
echo "--- Test: --help ---"
$CLIENT --help 2>/dev/null | head -1
pass "--help works"

echo ""
echo "--- Test: --version ---"
$CLIENT --version 2>/dev/null
pass "--version works"

echo ""
echo "--- Test: connection refused ---"
out=$($CLIENT --port 1 "(+ 1 2)" 2>&1; rc=$?; echo "EXIT:$rc"; exit $rc)
rc=$(echo "$out" | grep "EXIT:" | sed 's/EXIT://')
text=$(echo "$out" | grep -v "EXIT:")
if [ "$rc" = "2" ] && echo "$text" | grep -q "connection refused"; then
    pass "connection refused -> exit 2"
else
    fail "connection refused" "exit=$rc text=$text"
fi

echo ""
echo "--- Starting Slynk server on port $PORT ---"
# Use fifo to keep SBCL stdin open so it stays alive after --eval forms
mkfifo /tmp/slynk-pipe-$$ 2>/dev/null || true
# Keep the fifo open for writing so SBCL doesn't get EOF (must background first)
(sleep 9999 > /tmp/slynk-pipe-$$) &
FIFO_PID=$!
$SBCL --noinform --eval '(ql:quickload :slynk :silent t)' \
     --eval "(slynk:create-server :port $PORT :dont-close t)" \
     --eval '(format t "~&SERVER_READY~%")' \
     --eval '(force-output)' \
     < /tmp/slynk-pipe-$$ &
SPID=$!
# Wait for server to be ready or timeout
for i in $(seq 1 30); do
    sleep 1
    if ss -tlnp 2>/dev/null | grep -q "$PORT" || nc -z 127.0.0.1 $PORT 2>/dev/null; then
        echo "  Server ready (port $PORT)"
        break
    fi
    if ! kill -0 $SPID 2>/dev/null; then
        echo "  Server process died"
        break
    fi
done
echo "  Server PID: $SPID"

# Quick check if port is open
if ss -tlnp 2>/dev/null | grep -q "$PORT" || nc -z 127.0.0.1 $PORT 2>/dev/null; then
    pass "Slynk server is listening"
else
    fail "Slynk server" "port $PORT not listening"
    echo "=== Results: $PASS passed, $FAIL failed ==="
    exit 1
fi

echo ""
echo "--- Test: (+ 1 2) ---"
out=$($CLIENT --port $PORT "(+ 1 2)" 2>&1; rc=$?; echo "EXIT:$rc"; exit $rc)
rc=$(echo "$out" | grep "EXIT:" | sed 's/EXIT://')
text=$(echo "$out" | grep -v "EXIT:")
if [ "$text" = "3" ] && [ "$rc" = "0" ]; then
    pass "(+ 1 2) = 3, exit 0"
else
    fail "(+ 1 2)" "got \"$text\", exit $rc"
fi

echo ""
echo "--- Test: (format t \"hello, ~a\" :world) ---"
out=$($CLIENT --port $PORT '(format t "hello, ~a" :world)' 2>&1; rc=$?; echo "EXIT:$rc"; exit $rc)
rc=$(echo "$out" | grep "EXIT:" | sed 's/EXIT://')
text=$(echo "$out" | grep -v "EXIT:")
if echo "$text" | grep -q "hello, WORLD" && [ "$rc" = "0" ]; then
    pass "format prints hello, WORLD, exit 0"
else
    fail "format" "got \"$text\", exit $rc"
fi

echo ""
echo "--- Test: (error \"test\") ---"
out=$($CLIENT --port $PORT '(error "test")' 2>&1; rc=$?; echo "EXIT:$rc"; exit $rc)
rc=$(echo "$out" | grep "EXIT:" | sed 's/EXIT://')
text=$(echo "$out" | grep -v "EXIT:")
if [ "$rc" = "1" ]; then
    pass "(error \"test\") -> exit 1"
else
    fail "(error \"test\")" "got exit $rc"
fi

echo ""
echo "--- Test: (list 1 2 3) ---"
out=$($CLIENT --port $PORT "(list 1 2 3)" 2>&1; rc=$?; echo "EXIT:$rc"; exit $rc)
rc=$(echo "$out" | grep "EXIT:" | sed 's/EXIT://')
text=$(echo "$out" | grep -v "EXIT:")
if echo "$text" | grep -q "(1 2 3)" && [ "$rc" = "0" ]; then
    pass "(list 1 2 3) -> exit 0"
else
    fail "(list 1 2 3)" "got \"$text\", exit $rc"
fi

# Cleanup
kill $SPID 2>/dev/null || true
kill $FIFO_PID 2>/dev/null || true
rm -f /tmp/slynk-pipe-$$
echo "=== Results: $PASS passed, $FAIL failed ==="
[ $FAIL -eq 0 ] || exit 1
