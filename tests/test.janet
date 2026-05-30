(import testament :prefix "")

(defn- getfn [env name]
  (get (get env (symbol name)) :value))

(def env (make-env))
(dofile "src/main.janet" :env env)

(def chomp (getfn env "chomp"))
(def quote-for-cl-reader (getfn env "quote-for-cl-reader"))
(def princ-lisp (getfn env "princ-lisp"))
(def parse-args (getfn env "parse-args"))
(def print-debug-condition (getfn env "print-debug-condition"))
(def print-restarts (getfn env "print-restarts"))
(def print-frames (getfn env "print-frames"))
(def load-version (getfn env "load-version"))

# ── 1. chomp ──────────────────────────────────────────────────

(deftest test-chomp
  (is (= (chomp "hello\n") "hello"))
  (is (= (chomp "hello") "hello"))
  (is (= (chomp "a\nb\n") "a\nb"))
  (is (= (chomp "") ""))
  (is (= (chomp "\n") ""))
  (is (= (chomp "only one newline\n") "only one newline"))
  (is (= (chomp "\n\n") "\n"))
  (is (= (chomp "  spaces  \n") "  spaces  "))
  (is (= (chomp "a\nb\nc\n") "a\nb\nc")))

# ── 2. quote-for-cl-reader ────────────────────────────────────

(deftest test-quote-for-cl-reader
  (is (= (quote-for-cl-reader "hello") "\"hello\""))
  (is (= (quote-for-cl-reader "path\\to\\file") "\"path\\\\to\\\\file\""))
  (is (= (quote-for-cl-reader "he said \"hello\"") "\"he said \\\"hello\\\"\""))
  (is (= (quote-for-cl-reader "a\\b \"c\"") "\"a\\\\b \\\"c\\\"\""))
  (is (= (quote-for-cl-reader "") "\"\""))
  (is (= (quote-for-cl-reader "hello\nworld") "\"hello\nworld\""))
  (is (= (quote-for-cl-reader "tab\there") "\"tab\there\""))
  (is (= (quote-for-cl-reader "just one \\") "\"just one \\\\\""))
  (is (= (quote-for-cl-reader "\"") "\"\\\"\"")))

# ── 3. princ-lisp ─────────────────────────────────────────────

(deftest test-princ-lisp
  (is (= (princ-lisp "hello") "hello"))
  (is (= (princ-lisp 42) "42"))
  (is (= (princ-lisp true) "T"))
  (is (= (princ-lisp false) "NIL"))
  (is (= (princ-lisp nil) "NIL"))
  (is (= (princ-lisp (tuple 1 2 3)) "(1 2 3)"))
  (is (= (princ-lisp @[1 2 3]) "(1 2 3)"))
  (is (= (princ-lisp (buffer "buf")) "buf"))
  (is (= (princ-lisp :world) ":orld"))
  (is (= (princ-lisp :foo) ":oo"))
  (is (= (princ-lisp 'hello) "hello"))
  (is (= (princ-lisp (tuple)) "()"))
  (is (= (princ-lisp @[]) "()"))
  (is (= (princ-lisp (tuple "a" "b")) "(a b)"))
  (is (= (princ-lisp (tuple (tuple 1 2) 3)) "((1 2) 3)"))
  (is (= (princ-lisp (buffer "")) ""))
  (is (= (princ-lisp 0) "0"))
  (is (= (princ-lisp -1) "-1")))

# ── 4. load-version ───────────────────────────────────────────

(deftest test-load-version
  (is (string? (load-version)))
  (is (= (load-version) "0.4.0")))

# ── 5. print-debug-condition ──────────────────────────────────

(deftest test-print-debug-condition
  (is (= (type print-debug-condition) :function))
  (is (= (type print-restarts) :function))
  (is (= (type print-frames) :function)))

# ── 6. parse-args ─────────────────────────────────────────────

(deftest test-parse-args-basic-form
  (def opts (parse-args @["slyc" "(+ 1 2)"]))
  (is (= (opts :form) "(+ 1 2)"))
  (is (= (opts :port) 4005))
  (is (= (opts :host) "127.0.0.1"))
  (is (= (opts :timeout) 30))
  (is (= (opts :package) nil))
  (is (= (opts :no-progn) false))
  (is (= (opts :no-debug) false)))

(deftest test-parse-args-port
  (def opts (parse-args @["slyc" "--port" "9999" "(+ 1 2)"]))
  (is (= (opts :port) 9999))
  (is (= (opts :form) "(+ 1 2)")))

(deftest test-parse-args-port-short
  (def opts (parse-args @["slyc" "-p" "4000" "(+ 1 2)"]))
  (is (= (opts :port) 4000)))

(deftest test-parse-args-host
  (def opts (parse-args @["slyc" "--host" "0.0.0.0" "(+ 1 2)"]))
  (is (= (opts :host) "0.0.0.0")))

(deftest test-parse-args-host-short
  (def opts (parse-args @["slyc" "-h" "localhost" "(+ 1 2)"]))
  (is (= (opts :host) "localhost")))

(deftest test-parse-args-package
  (def opts (parse-args @["slyc" "--package" "CL-USER" "(+ 1 2)"]))
  (is (= (opts :package) "CL-USER")))

(deftest test-parse-args-timeout
  (def opts (parse-args @["slyc" "--timeout" "15" "(+ 1 2)"]))
  (is (= (opts :timeout) 15)))

(deftest test-parse-args-timeout-short
  (def opts (parse-args @["slyc" "-t" "5" "(+ 1 2)"]))
  (is (= (opts :timeout) 5)))

(deftest test-parse-args-no-progn
  (def opts (parse-args @["slyc" "--no-progn" "(+ 1 2)"]))
  (is (= (opts :no-progn) true))
  (is (= (opts :form) "(+ 1 2)")))

(deftest test-parse-args-no-debug
  (def opts (parse-args @["slyc" "--no-debug" "(+ 1 2)"]))
  (is (= (opts :no-debug) true)))

(deftest test-parse-args-combined
  (def opts (parse-args @["slyc" "-p" "9999" "-h" "0.0.0.0" "--no-progn" "(+ 1 2)"]))
  (is (= (opts :port) 9999))
  (is (= (opts :host) "0.0.0.0"))
  (is (= (opts :no-progn) true))
  (is (= (opts :form) "(+ 1 2)")))

(deftest test-parse-args-form-with-dashes
  (def opts (parse-args @["slyc" "(list 1 -2 3)"]))
  (is (= (opts :form) "(list 1 -2 3)")))

(deftest test-parse-args-defaults
  (def opts (parse-args @["slyc" "(+ 1 2)"]))
  (is (= (opts :port) 4005))
  (is (= (opts :host) "127.0.0.1"))
  (is (= (opts :timeout) 30))
  (is (= (opts :no-progn) false))
  (is (= (opts :no-debug) false)))

# ── 7. Wire protocol ──────────────────────────────────────────

(deftest test-wire-header-format
  (is (= (string/format "%06x" 5) "000005"))
  (is (= (string/format "%06x" 0) "000000"))
  (is (= (string/format "%06x" 255) "0000ff"))
  (is (= (string/format "%06x" 65535) "00ffff"))
  (is (= (string/format "%06x" 16777215) "ffffff")))

(deftest test-rex-message-format
  (def form "(+ 1 2)")
  (def progn-form (string/format "(progn %s)" form))
  (is (= progn-form "(progn (+ 1 2))"))
  (def wrapped (string/format "(cl:let ((slynk:*echo-number-alist* nil)) (slynk:eval-and-grab-output %s))" (quote-for-cl-reader progn-form)))
  (is (string/find "(slynk:eval-and-grab-output" wrapped))
  (def msg1 (string/format "(:emacs-rex %s %s t %d)" wrapped "nil" 1))
  (is (string/has-prefix? "(:emacs-rex " msg1))
  (is (string/has-suffix? " nil t 1)" msg1))
  (def msg2 (string/format "(:emacs-rex %s %s t %d)" wrapped (quote-for-cl-reader "CL-USER") 2))
  (is (string/find "\"CL-USER\"" msg2))
  (def wrapped-no-progn (string/format "(cl:let ((slynk:*echo-number-alist* nil)) (slynk:eval-and-grab-output %s))" (quote-for-cl-reader form)))
  (is (not (string/find "(progn" wrapped-no-progn))))

(deftest test-send-raw-rex-format
  (def raw-msg (string/format "(:emacs-rex %s nil t %d)" "(+ 1 2)" 5))
  (is (= raw-msg "(:emacs-rex (+ 1 2) nil t 5)"))
  (def raw-with-thread (string/format "(:emacs-rex %s nil %s %d)" "(+ 1 2)" "2" 6))
  (is (= raw-with-thread "(:emacs-rex (+ 1 2) nil 2 6)")))

(deftest test-send-abort-format
  (def abort-msg (string/format "(:emacs-rex %s nil t %d)" "(slynk:invoke-nth-restart 0)" 2))
  (is (= abort-msg "(:emacs-rex (slynk:invoke-nth-restart 0) nil t 2)"))
  (def abort-msg-3 (string/format "(:emacs-rex %s nil t %d)" "(slynk:invoke-nth-restart 0)" 3))
  (is (string/find "invoke-nth-restart 0" abort-msg-3)))

(run-tests!)
