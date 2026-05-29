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
echo "--- Test: double-quote in string ---"
out=$($CLIENT --port $PORT '(princ "he said \"hello\"")' 2>&1; rc=$?; echo "EXIT:$rc"; exit $rc)
rc=$(echo "$out" | grep "EXIT:" | sed 's/EXIT://')
text=$(echo "$out" | grep -v "EXIT:")
if echo "$text" | grep -Fq 'he said "hello"' && [ "$rc" = "0" ]; then
    pass "double-quote in string prints correctly"
else
    fail "double-quote" "got \"$text\", exit $rc"
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

# Give the server a moment to recover from debugger entry
sleep 0.5

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

echo ""
echo "--- Test: stdin pipe (+ 1 2) ---"
out=$(echo "(+ 1 2)" | $CLIENT --port $PORT 2>&1; rc=$?; echo "EXIT:$rc"; exit $rc)
rc=$(echo "$out" | grep "EXIT:" | sed 's/EXIT://')
text=$(echo "$out" | grep -v "EXIT:")
if [ "$text" = "3" ] && [ "$rc" = "0" ]; then
    pass "stdin pipe (+ 1 2) = 3, exit 0"
else
    fail "stdin pipe" "got \"$text\", exit $rc"
fi

echo ""
echo "--- Test: stdin redirect from file ---"
tmpf=$(mktemp)
echo "(+ 1 2)" > "$tmpf"
out=$($CLIENT --port $PORT < "$tmpf" 2>&1; rc=$?; echo "EXIT:$rc"; exit $rc)
rc=$(echo "$out" | grep "EXIT:" | sed 's/EXIT://')
text=$(echo "$out" | grep -v "EXIT:")
rm -f "$tmpf"
if [ "$text" = "3" ] && [ "$rc" = "0" ]; then
    pass "stdin redirect (+ 1 2) = 3, exit 0"
else
    fail "stdin redirect" "got \"$text\", exit $rc"
fi

echo ""
echo "--- Test: empty stdin ---"
out=$(echo -n "" | $CLIENT --port $PORT 2>&1; rc=$?; echo "EXIT:$rc"; exit $rc)
rc=$(echo "$out" | grep "EXIT:" | sed 's/EXIT://')
text=$(echo "$out" | grep -v "EXIT:")
if echo "$text" | grep -q "no form provided" && [ "$rc" = "2" ]; then
    pass "empty stdin -> exit 2"
else
    fail "empty stdin" "got \"$text\", exit $rc"
fi

echo ""
echo "--- Test: heredoc with multiple forms ---"
out=$($CLIENT --port $PORT 2>&1 << 'EOF'
(+ 1 2)
(* 3 4)
EOF
)
rc=$?
if [ "$out" = "12" ] && [ "$rc" = "0" ]; then
    pass "heredoc multiple forms = 12 (progn), exit 0"
else
    fail "heredoc multi" "got \"$out\", exit $rc"
fi

echo ""
echo "--- Test: --file with valid form ---"
tmpf=$(mktemp)
echo "(+ 1 2)" > "$tmpf"
out=$($CLIENT --port $PORT -f "$tmpf" 2>&1; rc=$?; echo "EXIT:$rc"; exit $rc)
rc=$(echo "$out" | grep "EXIT:" | sed 's/EXIT://')
text=$(echo "$out" | grep -v "EXIT:")
rm -f "$tmpf"
if [ "$text" = "3" ] && [ "$rc" = "0" ]; then
    pass "--file (+ 1 2) = 3, exit 0"
else
    fail "--file" "got \"$text\", exit $rc"
fi

echo ""
echo "--- Test: --file with multiple forms (progn) ---"
tmpf=$(mktemp)
printf "(defun a () 1)\n(defun b () 2)\n(a)\n" > "$tmpf"
out=$($CLIENT --port $PORT --file "$tmpf" 2>&1; rc=$?; echo "EXIT:$rc"; exit $rc)
rc=$(echo "$out" | grep "EXIT:" | sed 's/EXIT://')
text=$(echo "$out" | grep -v "EXIT:")
rm -f "$tmpf"
if [ "$text" = "1" ] && [ "$rc" = "0" ]; then
    pass "--file multi form (progn) = 1, exit 0"
else
    fail "--file multi" "got \"$text\", exit $rc"
fi

echo ""
echo "--- Test: --file with non-existent file ---"
out=$($CLIENT --port $PORT -f "/nonexistent/file-$$.lisp" 2>&1; rc=$?; echo "EXIT:$rc"; exit $rc)
rc=$(echo "$out" | grep "EXIT:" | sed 's/EXIT://')
text=$(echo "$out" | grep -v "EXIT:")
if echo "$text" | grep -q "cannot open file" && [ "$rc" = "2" ]; then
    pass "--file non-existent -> exit 2"
else
    fail "--file non-existent" "got \"$text\", exit $rc"
fi

echo ""
echo "--- Test: --file and positional arg conflict ---"
tmpf=$(mktemp)
echo "(+ 1 2)" > "$tmpf"
out=$($CLIENT --port $PORT -f "$tmpf" "(+ 3 4)" 2>&1; rc=$?; echo "EXIT:$rc"; exit $rc)
rc=$(echo "$out" | grep "EXIT:" | sed 's/EXIT://')
text=$(echo "$out" | grep -v "EXIT:")
rm -f "$tmpf"
if echo "$text" | grep -q "cannot be used together" && [ "$rc" = "2" ]; then
    pass "--file with positional arg -> exit 2"
else
    fail "--file conflict" "got \"$text\", exit $rc"
fi

echo ""
echo "--- Test: multi-line string preserves newlines ---"
out=$($CLIENT --port $PORT 2>&1 << 'EOF'
(format t "hello
world")
EOF
)
rc=$?
if [ "$rc" = "0" ] && echo "$out" | head -1 | grep -q "^hello$" && echo "$out" | sed -n '2p' | grep -q "^world$"; then
    pass "multi-line output has newlines"
else
    fail "multi-line" "got \"$out\", exit $rc"
fi

echo ""
echo "--- Test: newline via ~% format directive ---"
out=$($CLIENT --port $PORT '(format t "hello~%world")' 2>&1; rc=$?; echo "EXIT:$rc"; exit $rc)
rc=$(echo "$out" | grep "EXIT:" | sed 's/EXIT://')
text=$(echo "$out" | grep -v "EXIT:")
if [ "$rc" = "0" ] && echo "$text" | sed -n '1p' | grep -q "^hello$" && echo "$text" | sed -n '2p' | grep -q "^world$" && echo "$text" | sed -n '3p' | grep -q "^NIL$"; then
    pass "newline via ~%: hello on line 1, world on line 2"
else
    fail "newline via ~%" "got \"$text\", exit $rc"
fi

echo ""
echo "--- Test: newline at start of output ---"
out=$($CLIENT --port $PORT '(format t "~%world")' 2>&1; rc=$?; echo "EXIT:$rc"; exit $rc)
rc=$(echo "$out" | grep "EXIT:" | sed 's/EXIT://')
text=$(echo "$out" | grep -v "EXIT:")
if [ "$rc" = "0" ] && echo "$text" | sed -n '1p' | grep -q "^$" && echo "$text" | sed -n '2p' | grep -q "^world$" && echo "$text" | sed -n '3p' | grep -q "^NIL$"; then
    pass "newline at start: blank line then world"
else
    fail "newline at start" "got \"$text\", exit $rc"
fi

echo ""
echo "--- Test: multiple newlines in output ---"
out=$($CLIENT --port $PORT '(format t "line1~%line2~%line3~%")' 2>&1; rc=$?; echo "EXIT:$rc"; exit $rc)
rc=$(echo "$out" | grep "EXIT:" | sed 's/EXIT://')
text=$(echo "$out" | grep -v "EXIT:")
if [ "$rc" = "0" ] && echo "$text" | sed -n '1p' | grep -q "^line1$" && echo "$text" | sed -n '2p' | grep -q "^line2$" && echo "$text" | sed -n '3p' | grep -q "^line3$" && echo "$text" | sed -n '4p' | grep -q "^$" && echo "$text" | sed -n '5p' | grep -q "^NIL$"; then
    pass "3 newlines: line1, line2, line3, blank, NIL"
else
    fail "multiple newlines" "got \"$text\", exit $rc"
fi

echo ""
echo "--- Test: backslash in string ---"
out=$($CLIENT --port $PORT '(princ "path\\to\\file")' 2>&1; rc=$?; echo "EXIT:$rc"; exit $rc)
rc=$(echo "$out" | grep "EXIT:" | sed 's/EXIT://')
text=$(echo "$out" | grep -v "EXIT:")
if echo "$text" | grep -Fq "path\to\file" && [ "$rc" = "0" ]; then
    pass "backslash in string prints correctly"
else
    fail "backslash" "got \"$text\", exit $rc"
fi

echo ""
echo "--- Test: --no-debug flag with success ---"
out=$($CLIENT --no-debug --port $PORT "(+ 1 2)" 2>&1; rc=$?; echo "EXIT:$rc"; exit $rc)
rc=$(echo "$out" | grep "EXIT:" | sed 's/EXIT://')
text=$(echo "$out" | grep -v "EXIT:")
if [ "$text" = "3" ] && [ "$rc" = "0" ]; then
    pass "--no-debug (+ 1 2) = 3, exit 0"
else
    fail "--no-debug success" "got \"$text\", exit $rc"
fi

echo ""
echo "--- Test: --no-debug flag with error ---"
out=$($CLIENT --no-debug --port $PORT '(error "test")' 2>&1; rc=$?; echo "EXIT:$rc"; exit $rc)
rc=$(echo "$out" | grep "EXIT:" | sed 's/EXIT://')
text=$(echo "$out" | grep -v "EXIT:")
if [ "$rc" = "1" ]; then
    pass "--no-debug (error \"test\") -> exit 1"
else
    fail "--no-debug error" "got exit $rc"
fi

echo ""
echo "--- Test: piped stdin + error -> batch abort ---"
out=$(echo '(error "batch")' | $CLIENT --port $PORT 2>&1; rc=$?; echo "EXIT:$rc"; exit $rc)
rc=$(echo "$out" | grep "EXIT:" | sed 's/EXIT://')
text=$(echo "$out" | grep -v "EXIT:")
if [ "$rc" = "1" ]; then
    pass "piped stdin error -> exit 1"
else
    fail "piped stdin error" "got exit $rc"
fi

echo ""
echo "--- Test: --no-debug does not consume next arg ---"
out=$($CLIENT --no-debug --port $PORT "(+ 1 2)" 2>&1; rc=$?; echo "EXIT:$rc"; exit $rc)
rc=$(echo "$out" | grep "EXIT:" | sed 's/EXIT://')
text=$(echo "$out" | grep -v "EXIT:")
if [ "$text" = "3" ] && [ "$rc" = "0" ]; then
    pass "--no-debug does not consume next arg"
else
    fail "--no-debug arg consumption" "got \"$text\", exit $rc"
fi

echo ""
echo "--- Test: interactive debugger displays menu ---"
out=$(printf "q\n" | script -q -c "$CLIENT --port $PORT '(error \"interactive-test\")'" /dev/null 2>&1)
# script doesn't propagate exit codes, so check output content
rc=0
if echo "$out" | grep -q "interactive-test" && echo "$out" | grep -q "Restarts:" && echo "$out" | grep -q "slyc-db>"; then
    pass "interactive debugger shows condition, restarts, and prompt"
else
    fail "interactive debugger menu" "output: $out"
fi

echo ""
echo "--- Test: interactive debugger handles nested commands ---"
out=$(printf "bt\nfr 0\nq\n" | script -q -c "$CLIENT --port $PORT 'error'" /dev/null 2>&1)
if echo "$out" | grep -q "Backtrace:" && echo "$out" | grep -q "slyc-db>"; then
    pass "bt + fr + q works without hanging"
else
    fail "nested commands" "output: $out"
fi

# Cleanup
kill $SPID 2>/dev/null || true
kill $FIFO_PID 2>/dev/null || true
rm -f /tmp/slynk-pipe-$$
echo "=== Results: $PASS passed, $FAIL failed ==="
[ $FAIL -eq 0 ] || exit 1
