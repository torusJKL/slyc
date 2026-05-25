#!/usr/bin/env janet
(def version "0.1.0")
(def default-port 4005)
(def default-host "127.0.0.1")
(def default-package "CL-USER")
(def default-timeout 30)

(defn- print-usage []
  (print "slyc - Slynk CLI client for AI agents")
  (print)
  (print "Usage: slyc [options] [<form>]")
  (print)
  (print "Options:")
  (print "  -p, --port <port>      Slynk server port (default: 4005)")
  (print "  -h, --host <host>      Slynk server host (default: 127.0.0.1)")
  (print "  -f, --file <path>      Read form from file")
  (print "      --package <pkg>    Package to evaluate in (default: CL-USER)")
  (print "  -t, --timeout <secs>   Read timeout in seconds (default: 30)")
  (print "      --help             Show this help")
  (print "      --version          Show version")
  (print)
  (print "If <form> is omitted and stdin is not a TTY, the form is read from stdin.")
  (print)
  (print "Examples:")
  (print "  slyc \"(+ 1 2)\"")
  (print "  slyc -f ./my-form.lis")
  (print "  echo \"(+ 1 2)\" | slyc")
  (print "  slyc -p 4005 --package CL-USER \"(format t \\\"hello\\\")\"")
  (print "  slyc --timeout 5 \"(sleep 10)\""))

(defn- chomp [s]
  (def str (string s))
  (if (string/has-suffix? "\n" str)
    (string/slice str 0 (dec (length str)))
    str))

(defn- read-form-from-file [path]
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
  (def content (chomp (file/read stdin :all)))
  (when (empty? content)
    (eprint "error: no form provided from stdin")
    (os/exit 2))
  content)

(defn- parse-args [argv]
  (var port default-port)
  (var host default-host)
  (var pkg default-package)
  (var timeout default-timeout)
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
  {:port port :host host :package pkg :timeout timeout :form form})

(defn- write-wire [stream sexpr]
  (def octets (string sexpr))
  (def header (string/format "%06x" (length octets)))
  (net/write stream header)
  (net/write stream octets)
  (net/flush stream))

(defn- send-eval [stream form-str pkg id]
  (def wrapped (string/format "(cl:let ((slynk:*echo-number-alist* nil)) (slynk:eval-and-grab-output %q))" form-str))
  (def msg (string/format "(:emacs-rex %s %q t %d)" wrapped pkg id))
  (write-wire stream msg))

(defn- send-abort [stream id]
  (def msg (string/format "(:emacs-rex (slynk:invoke-nth-restart 0) \"CL-USER\" t %d)" id))
  (write-wire stream msg))

(defn- read-exactly [stream n timeout]
  (var buf (buffer/new n))
  (while (< (length buf) n)
    (def result (protect (net/read stream (- n (length buf)) buf timeout)))
    (match result
      [true _] nil
      [false err] (error err)))
  (string buf))

(defn- read-message [stream timeout]
  (def header (read-exactly stream 6 timeout))
  (def len (scan-number header 16))
  (def raw (read-exactly stream len timeout))
  (parse raw))

(defn- princ-lisp [x]
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

(defn- process-responses [stream timeout]
  (var aborted false)
  (var output-buf (buffer/new 64))
  (while true
    (def result (protect (read-message stream timeout)))
    (match result
      [false _]
      (do
        (eprintf "timed out after %d seconds" timeout)
        (os/exit 124))
      [true msg]
      (case (first msg)
        :new-features nil
        :new-package nil
        :indentation-update nil
        :ping nil
        :write-string (do
          (def [_ text _target] msg)
          (buffer/push-string output-buf text))
        :debug (do
          (def [_ _ _ condition-info _ _] msg)
          (def err-str (if (tuple? condition-info) (get condition-info 0) "Lisp error"))
          (unless aborted
            (set aborted true)
            (send-abort stream 2))
          (eprint err-str)
          (os/exit 1))
        :reader-error (do (eprint (get msg 2)) (os/exit 2))
        :invalid-rpc (do (eprintf "server error: %s" (get msg 2)) (os/exit 2))
        :return (do
          (def buf-str (string output-buf))
          (when (pos? (length buf-str))
            (print buf-str))
          (def [_ ok-pair _id] msg)
          (def [tag value] ok-pair)
          (if (= tag :ok)
            (do
              (def [out-str val-str] value)
              (when (and (string? out-str) (pos? (length out-str)))
                (print out-str))
              (when (and (string? val-str) (pos? (length val-str)))
                (print val-str))
              (os/exit 0))
            (do
              (eprint (if (string? value) value (princ-lisp value)))
              (os/exit 1))))
        ()))))

(defn main [& argv]
  (def opts (parse-args argv))
  (def form (opts :form))
  (def host (opts :host))
  (def port (opts :port))
  (def pkg (opts :package))
  (def timeout (opts :timeout))
  (def conn
    (protect (net/connect host port)))
  (match conn
    [false _]
    (do
      (eprintf "connection refused: %s:%d" host port)
      (os/exit 2))
    [true stream]
    (do
      (send-eval stream form pkg 1)
      (process-responses stream timeout))))

(def args (dyn :args))
(def first (get args 0))
(when (and first
           (or (string/has-suffix? ".janet" first)
               (string/has-suffix? ".jimage" first)))
  (apply main args))
