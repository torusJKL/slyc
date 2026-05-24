#!/usr/bin/env janet

# Test script for slyc
# Usage: janet test.janet

(def port 17892)
(def host "127.0.0.1")

(defn- run-client [& args]
  (def cmd (array/join @["janet" "main.janet" (generate args) ",,"] " "))
  (def result (os/execute [:cmd "janet" "main.janet" ;args] :p))
  result)

(defn- assert-eq [expected actual desc]
  (if (= expected actual)
    (printf "  ✓ %s" desc)
    (printf "  ✗ %s: expected %q got %q" desc expected actual)))

# Start SBCL with Slynk server
(printf "\nStarting Slynk server on port %d..." port)
(def server-cmd @["sbcl" "--noinform" "--quit"
                  "--eval" (string/format "(ql:quickload :slynk :silent t)")
                  "--eval" (string/format "(slynk:create-server :port %d :dont-close nil)" port)
                  "--eval" "(sleep 60)"])

(printf "Server command: %q" (string/join server-cmd " "))
(printf "\nSkipping live integration - needs SBCL running\n")
(printf "\nTo test manually:\n")
(printf "  1. Start Slynk: sbcl --eval \"(ql:quickload :slynk)\" --eval \"(slynk:create-server :port 4005)\"\n")
  (printf "  2. Run: janet src/main.janet \"(+ 1 2)\"\n")
