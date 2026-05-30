#!/usr/bin/env janet
(defn- load-version []
  "Read the project version from project.janet via PEG parse of the :version field."
  (def f (file/open "project.janet"))
  (if (nil? f)
    "unknown"
    (do
      (def raw (file/read f :all))
      (file/close f)
      (def captured (peg/match ~(sequence (thru ":version") (drop (any (set " \t\r\n\v\f"))) "\"" (capture (some (if-not "\"" 1))) "\"") raw))
      (if captured (first captured) "unknown"))))

(def version (load-version))
(def default-port 4005)
(def default-host "127.0.0.1")

(def default-timeout 30)

(defn- print-usage []
  "Print the command-line usage and option reference."
  (print "slyc - Slynk CLI client for AI agents")
  (print)
  (print "Usage: slyc [options] [<form>]")
  (print)
  (print "Options:")
  (print "  -p, --port <port>      Slynk server port (default: 4005)")
  (print "  -h, --host <host>      Slynk server host (default: 127.0.0.1)")
  (print "  -f, --file <path>      Read form from file")
  (print "      --package <pkg>    Package to evaluate in (default: server default)")
  (print "  -t, --timeout <secs>   Read timeout in seconds (default: 30)")
  (print "      --no-progn         Do not wrap input in (progn ...)")
  (print "      --no-debug         Force batch abort on debugger entry")
  (print "      --help             Show this help")
  (print "      --version          Show version")
  (print)
  (print "The form input is automatically wrapped in (progn ...) so multiple")
  (print "top-level forms are all evaluated. Use --no-progn to disable this.")
  (print)
  (print "If <form> is omitted and stdin is not a TTY, the form is read from stdin.")
  (print)
  (print "Examples:")
  (print "  slyc \"(+ 1 2)\"")
  (print "  slyc -f ./my-form.lisp")
  (print "  echo \"(+ 1 2)\" | slyc")
  (print "  echo -e \"(+ 1 2)\\n(* 3 4)\" | slyc")
  (print "  slyc -p 4005 --package CL-USER \"(format t \\\"hello\\\")\"")
  (print "  slyc --timeout 5 \"(sleep 10)\""))

(defn- chomp [s]
  "Strip a single trailing newline from string `s`."
  (def str (string s))
  (if (string/has-suffix? "\n" str)
    (string/slice str 0 (dec (length str)))
    str))

(defn- read-form-from-file [path]
  "Read and return content from file at `path`. Exits with code 2 on error or empty file."
  (def f (file/open path))
  (when (nil? f)
    (eprintf "error: cannot open file: %s" path)
    (os/exit 2))
  (def content (chomp (file/read f :all)))
  (file/close f)
  (when (empty? content)
    (eprint "error: empty form from file")
    (os/exit 2))
  content)

(defn- read-form-from-stdin []
  "Read and return content from stdin. Exits with code 2 if empty."
  (def content (chomp (file/read stdin :all)))
  (when (empty? content)
    (eprint "error: no form provided from stdin")
    (os/exit 2))
  content)

(defn- parse-args [argv]
  "Parse command-line arguments into an options table. Handles --help, --version, flags, and positional form."
  (var port default-port)
  (var host default-host)
  (var pkg nil)
  (var timeout default-timeout)
  (var no-progn false)
  (var no-debug false)
  (var form nil)
  (var file-path nil)
  (var i 1)
  (while (< i (length argv))
    (def arg (get argv i))
    (cond
      (= arg "--help") (do (print-usage) (os/exit 0))
      (= arg "--version") (do (print version) (os/exit 0))
      (or (= arg "--host") (= arg "-h")) (do (++ i) (set host (get argv i)))
      (or (= arg "--port") (= arg "-p")) (do (++ i) (set port (scan-number (get argv i) 10)))
      (or (= arg "--file") (= arg "-f")) (do (++ i) (set file-path (get argv i)))
      (= arg "--package") (do (++ i) (set pkg (get argv i)))
      (or (= arg "--timeout") (= arg "-t")) (do (++ i) (set timeout (scan-number (get argv i) 10)))
      (= arg "--no-progn") (set no-progn true)
      (= arg "--no-debug") (set no-debug true)
      (do (set form arg) (break)))
    (++ i))
  (cond
    (and file-path form) (do
      (eprint "error: --file and a positional form cannot be used together")
      (os/exit 2))
    file-path (set form (read-form-from-file file-path))
    (nil? form)
    (if (not (os/isatty stdin))
      (set form (read-form-from-stdin))
      (do
        (eprint "error: no form provided")
        (print-usage)
        (os/exit 2))))
  {:port port :host host :package pkg :timeout timeout :form form :no-progn no-progn :no-debug no-debug})

(defn- write-wire [stream sexpr]
  "Write an s-expression to `stream` using Slynk's length-prefixed wire format (6-char hex header + payload)."
  (def octets (string sexpr))
  (def header (string/format "%06x" (length octets)))
  (net/write stream header)
  (net/write stream octets)
  (net/flush stream))

(defn- quote-for-cl-reader [s]
  "Escape string `s` so it is readable by the Common Lisp reader (escapes backslash and double-quote, wraps in double-quotes)."
  (def escaped
    (string/replace-all "\"" "\\\""
      (string/replace-all "\\" "\\\\" s)))
  (string/format "\"%s\"" escaped))

(defn- send-eval [stream form-str pkg id &opt no-progn]
  "Send an eval-and-grab-output REX for `form-str` to `stream`. Wraps in (progn ...) unless `no-progn` is set."
  (def progn-form (if no-progn form-str (string/format "(progn %s)" form-str)))
  (def wrapped (string/format "(cl:let ((slynk:*echo-number-alist* nil)) (slynk:eval-and-grab-output %s))" (quote-for-cl-reader progn-form)))
  (def pkg-str (if pkg (quote-for-cl-reader pkg) "nil"))
  (def msg (string/format "(:emacs-rex %s %s t %d)" wrapped pkg-str id))
  (write-wire stream msg))

(defn- send-raw-rex [stream form id &opt thread]
  "Send an arbitrary REX `form` to `stream` with no package context. Optionally specify a thread."
  (def thread-str (if thread (string thread) "t"))
  (def msg (string/format "(:emacs-rex %s nil %s %d)" form thread-str id))
  (write-wire stream msg))

(defn- send-abort [stream id]
  "Send an abort REX (invoke-nth-restart 0) to `stream`."
  (def msg (string/format "(:emacs-rex (slynk:invoke-nth-restart 0) nil t %d)" id))
  (write-wire stream msg))

(defn- read-exactly [stream n timeout]
  "Read exactly `n` bytes from `stream` with `timeout`. Errors on premature EOF."
  (var buf (buffer/new n))
  (while (< (length buf) n)
    (def result (protect (net/read stream (- n (length buf)) buf timeout)))
    (match result
      [true _] nil
      [false err] (error err)))
  (string buf))

(defn- read-message [stream timeout]
  "Read a single Slynk wire message from `stream`: 6-byte hex length header, then payload. Returns parsed s-expression."
  (def header (read-exactly stream 6 timeout))
  (def len (scan-number header 16))
  (def raw (read-exactly stream len timeout))
  (def escaped (string/replace-all "\n" "\\n" raw))
  (parse escaped))

(defn- princ-lisp [x]
  "Convert Janet value `x` to its Lisp printed representation for display."
  (cond
    (string? x) x
    (keyword? x) (string/format ":%s" (string/slice x 1 -1))
    (symbol? x) (string x)
    (number? x) (string x)
    (boolean? x) (if x "T" "NIL")
    (nil? x) "NIL"
    (tuple? x) (string/format "(%s)" (string/join (map princ-lisp x) " "))
    (array? x) (string/format "(%s)" (string/join (map princ-lisp x) " "))
    (buffer? x) (string x)
    true (string/format "%q" x)))

(defn- print-legend []
  "Print the one-line debugger command legend."
  (print)
  (print "Commands: 0-9 restart | bt backtrace | fr N frame | up/down | e FORM eval | r restarts | q quit | ? help"))

(defn- print-help []
  "Print the full interactive debugger command reference."
  (print)
  (print "Interactive Debugger Commands")
  (print "═════════════════════════════")
  (print)
  (print "<N>        Invoke restart N. Restarts are listed above with numbers.")
  (print "bt [N]     Show backtrace. N defaults to 20 frames.")
  (print "fr N       Set current frame to N and show local variables.")
  (print "up         Move current frame up (toward frame 0).")
  (print "down       Move current frame down (away from frame 0).")
  (print "e FORM     Evaluate FORM in the current frame's context.")
  (print "r          Reprint available restarts.")
  (print "q          Abort and exit slyc.")
  (print "?          Show this help.")
  (print)
  (print "Frame navigation:")
  (print "  The \"current frame\" starts at 0 (the error site). Use fr/up/down")
  (print "  to change it. Commands like 'e' evaluate in the current frame.")
  (print)
  (print "Examples:")
  (print "  fr 2       Show locals for frame 2")
  (print "  e (* 2 x)  Evaluate (* 2 x) in the current frame")
  (print "  bt 5       Show top 5 backtrace frames")
  (print))

(var read-until-return nil)

(defn- print-debug-condition [condition]
  "Print the condition description from a debugger message."
  (print (get condition 0))
  (when (> (length condition) 1)
    (print (get condition 1))))

(defn- print-restarts [restarts]
  "Print each restart with its numeric index and description."
  (var i 0)
  (each restart restarts
    (def [name desc] restart)
    (print (string/format "%d: %s — %s" i name desc))
    (++ i)))

(defn- print-frames [frames]
  "Print each backtrace frame with its index and description."
  (var i 0)
  (each frame frames
    (def [num desc] frame)
    (print (string/format "%d: %s" num desc))
    (++ i)))

(defn- handle-debugger [stream msg timeout pkg]
  "Enter the interactive debugger REPL. Reads commands (restart number, bt, fr, up, down, e, q, ?, r) from stdin."
  (def [_ thread level condition restarts frames _conts] msg)
  (var current-frame 0)
  (var frame-cache frames)

  (print)
  (print-debug-condition condition)
  (print)
  (print "Restarts:")
  (print-restarts restarts)
  (print)
  (print "Backtrace:")
  (print-frames (slice frames 0 5))
  (print-legend)

  (while true
    (prin "slyc-db> ")
    (flush)
    (def input (chomp (file/read stdin :line)))
    (cond
      (= input "q") (do
        (send-abort stream 2)
        (print-debug-condition condition)
        (os/exit 1))

      (= input "?") (do
        (print-help))

      (= input "r") (do
        (print)
        (print "Restarts:")
        (print-restarts restarts)
        (print)
        (print "Backtrace:")
        (print-frames (slice frames 0 5))
        (print-legend))

      (= input "up") (do
        (when (> current-frame 0)
          (-- current-frame))
        (def frame-desc (if (< current-frame (length frame-cache))
                          (get (get frame-cache current-frame) 1)
                          "[frame not in cache — use bt to fetch]"))
        (print (string/format "Frame %d: %s" current-frame frame-desc)))

      (= input "down") (do
        (++ current-frame)
        (def frame-desc (if (< current-frame (length frame-cache))
                          (get (get frame-cache current-frame) 1)
                          "[frame not in cache — use bt to fetch]"))
        (print (string/format "Frame %d: %s" current-frame frame-desc)))

      (do
        (def parts (string/split " " input 2))
        (def cmd (get parts 0))
        (def arg (get parts 1))

        (cond
          (= cmd "bt") (do
            (def count (if arg (or (scan-number arg 10) 20) 20))
            (send-eval stream (string/format "(cl:let ((slynk-sbcl::*sly-db-stack-top* (sb-di:top-frame))) (slynk:backtrace 0 %d))" count) pkg 3 true)
            (def [output return-msg] (read-until-return stream timeout pkg))
            (when (pos? (length output))
              (print output))
            (when return-msg
              (def [_ ok-pair _id] return-msg)
              (def [tag value] ok-pair)
              (if (= tag :ok)
                (when (tuple? value)
                  (def [out-str val-str] value)
                  (when (and (string? out-str) (pos? (length out-str)))
                    (print out-str))
                  (when (and (string? val-str) (pos? (length val-str)))
                    (print val-str)))
                (print (if (string? value) value (princ-lisp value))))))

          (= cmd "fr") (do
            (when arg
              (set current-frame (or (scan-number arg 10) current-frame)))
            (send-eval stream (string/format "(cl:let ((slynk-sbcl::*sly-db-stack-top* (sb-di:top-frame))) (slynk:frame-locals-and-catch-tags %d))" current-frame) pkg 4 true)
            (def [output return-msg] (read-until-return stream timeout pkg))
            (when (pos? (length output))
              (print output))
            (when return-msg
              (def [_ ok-pair _id] return-msg)
              (def [tag value] ok-pair)
              (if (= tag :ok)
                (when (tuple? value)
                  (def [out-str val-str] value)
                  (when (and (string? out-str) (pos? (length out-str)))
                    (print out-str))
                  (when (and (string? val-str) (pos? (length val-str)))
                    (print val-str)))
                (print (if (string? value) value (princ-lisp value)))))))

          (= cmd "e") (do
            (def form (string/slice input (+ 1 (length "e"))))
            (when (pos? (length form))
              (send-eval stream form "CL-USER" 5 true)
              (def [output return-msg] (read-until-return stream timeout pkg))
              (when (pos? (length output))
                (print output))
              (when return-msg
                (def [_ ok-pair _id] return-msg)
                (def [tag value] ok-pair)
                (if (= tag :ok)
                  (when (tuple? value)
                    (def [out-str val-str] value)
                    (when (and (string? out-str) (pos? (length out-str)))
                      (print out-str))
                    (when (and (string? val-str) (pos? (length val-str)))
                      (print val-str)))
                  (print (if (string? value) value (princ-lisp value)))))))

          # Check if input is a bare integer (restart selection)
        (when (and (not (= cmd "")) (nil? arg))
          (def n (scan-number cmd 10))
          (when (number? n)
            (send-raw-rex stream (string/format "(slynk:invoke-nth-restart %d)" n) 6 thread)
            (if (and (< n (length restarts))
                     (string/find "ABORT" (string (get (get restarts n) 0))))
              (os/exit 1)
              (break))))))))

(set read-until-return (fn [stream timeout pkg]
  "Read Slynk messages until a :return message is received. Returns [output-string, return-msg]."
  (var output-buf (buffer/new 64))
  (var return-msg nil)
  (while true
    (def msg (read-message stream timeout))
    (case (first msg)
      :write-string (do
        (def [_ text _target] msg)
        (buffer/push-string output-buf text))
      :debug-activate nil
      :debug-return nil
      :ping nil
      :debug (handle-debugger stream msg timeout pkg)
      :debug-condition (print (string/format "Internal debugger error: %s" (get msg 2)))
      :read-from-minibuffer (do
        (def [_ thread tag prompt _initial-value] msg)
        (print prompt)
        (flush)
        (def input (chomp (file/read stdin :line)))
        (write-wire stream (string/format "(:emacs-return %s %s %s)"
                                           (string thread) (string tag)
                                           (quote-for-cl-reader input))))
      :return (do
        (set return-msg msg)
        (break))
      (eprintf "warning: unexpected message: %s" (princ-lisp msg))))
  [(string output-buf) return-msg]))

(defn- process-responses [stream timeout interactive pkg]
  "Read and handle all messages from the Slynk server until a :return for id 1 is received. Handles debugger, write-string, and other message types."
  (var aborted false)
  (var output-buf (buffer/new 64))
  (var current-thread nil)
  (while true
    (def result (protect (read-message stream timeout)))
    (match result
      [false err]
      (if timeout
        (do
          (eprintf "timed out after %d seconds" timeout)
          (os/exit 124))
        (do
          (eprintf "connection error: %s" err)
          (os/exit 2)))
      [true msg]
      (case (first msg)
        :new-features nil
        :new-package nil
        :indentation-update nil
        :ping nil
        :debug-activate nil
        :debug-return nil
        :write-string (do
          (def [_ text _target] msg)
          (buffer/push-string output-buf text))
        :debug-condition (when interactive
          (print (string/format "Internal debugger error: %s" (get msg 2))))
        :debug (if interactive
          (if (and current-thread (not (= (get msg 1) current-thread)))
            (print (string/format "Warning: debugger entered in thread %s" (princ-lisp (get msg 1))))
            (do
              (handle-debugger stream msg nil pkg)
              (set current-thread nil)))
          (do
            (def [_ _ _ condition-info _ _] msg)
            (def err-str (if (tuple? condition-info) (get condition-info 0) "Lisp error"))
            (unless aborted
              (set aborted true)
              (send-abort stream 2))
            (eprint err-str)
            (os/exit 1)))
        :read-from-minibuffer (do
          (def [_ thread tag prompt _initial-value] msg)
          (print prompt)
          (flush)
          (def input (chomp (file/read stdin :line)))
          (write-wire stream (string/format "(:emacs-return %s %s %s)"
                                             (string thread) (string tag)
                                             (quote-for-cl-reader input))))
        :reader-error (do (eprint (get msg 2)) (os/exit 2))
        :invalid-rpc (do (eprintf "server error: %s" (get msg 2)) (os/exit 2))
        :return (do
          (def [_ ok-pair ret-id] msg)
          (when (= ret-id 1)
            (def buf-str (string output-buf))
            (when (pos? (length buf-str))
              (print buf-str))
            (def [tag value] ok-pair)
            (if (= tag :ok)
              (do
                (when (tuple? value)
                  (def [out-str val-str] value)
                  (when (and (string? out-str) (pos? (length out-str)))
                    (print out-str))
                  (when (and (string? val-str) (pos? (length val-str)))
                    (print val-str)))
                (os/exit 0))
              (do
                (eprint (if (string? value) value (princ-lisp value)))
                (os/exit 1)))))
        (do
          (eprintf "warning: unexpected message: %s" (princ-lisp msg)))))))

(defn main [& argv]
  "CLI entry point. Parse arguments, connect to Slynk server, send the form, and process responses."
  (def opts (parse-args argv))
  (def form (opts :form))
  (def host (opts :host))
  (def port (opts :port))
  (def pkg (opts :package))
  (def timeout (opts :timeout))
  (def interactive (and (not (opts :no-debug)) (os/isatty stdin)))
  (def conn
    (protect (net/connect host port)))
  (match conn
    [false _]
    (do
      (eprintf "connection refused: %s:%d" host port)
      (os/exit 2))
    [true stream]
    (do
      (send-eval stream form pkg 1 (opts :no-progn))
      (process-responses stream timeout interactive pkg))))

(def args (dyn :args))
(def first (get args 0))
(when (and first
           (or (string/has-suffix? "main.janet" first)
               (string/has-suffix? "main.jimage" first)))
  (apply main args))
