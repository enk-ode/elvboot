#!/bin/sh
#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Dr. Johannes Brügmann
# audit-env-docs.sh -- which environment variables does each function use,
# and does its #@help block document them (@env tag or literal mention)?
#
# Usage: sh scripts/audit-env-docs.sh <PREFIX> <file.sh> [...]
#   PREFIX   variable prefix, e.g. ELEBAKE or VPN_SWITCH
#
# Output, one line per finding:
#   MISSING <file> <function> <VAR>     used but not documented
#   OK      <file> <function> <VAR>     used and documented
#
# Whitelisted (never reported): engine-internal plumbing and globals that are
# documented centrally, not per function.
set -eu

PREFIX="${1:?usage: audit-env-docs.sh <PREFIX> <files...>}"
shift

# engine plumbing + centrally documented globals
WHITELIST="CONTEXT_SCRIPT CONTEXT_BOOTSTRAPPED CONTEXT_EXIT_BITS CONTEXT_CALL \
CONTEXT_COMMAND BASE ROOT INIT_DIR_CONFIG FUNCTION_OVERRIDE \
TRACE_FILE TRACE_DEPTH LIBDIR"

awk -v prefix="$PREFIX" -v wl="$WHITELIST" '
BEGIN {
  n = split(wl, w, /[ \t]+/)
  for (i = 1; i <= n; i++) if (w[i] != "") white[prefix "_" w[i]] = 1
}
function flush_fn(   v, doc, kind) {
  if (fn == "") return
  kind = "none"
  if (helpblob ~ /@command/)  kind = "command"
  else if (helpblob ~ /@internal/) kind = "internal"
  for (v in used) {
    doc = (index(helpblob, v) > 0) ? "OK" : "MISSING"
    printf "%s %s %s %s %s\n", doc, kind, FILENAME, fn, v
  }
  fn = ""; delete used
}
# collect a help block; it documents the NEXT function definition
/^#@help/ { inhelp = 1; blob = ""; next }
inhelp && /^#@end/ { inhelp = 0; pend_blob = blob; next }
inhelp { blob = blob "\n" $0; next }
# function definition starts a new scope
/^_*[a-z][a-z0-9_]*\(\) *\{/ {
  flush_fn()
  fn = $0; sub(/\(\).*/, "", fn)
  helpblob = pend_blob; pend_blob = ""
  depth = 0
}
fn != "" {
  # track function body (brace depth on unquoted braces is approximated by
  # counting; good enough for this codebase style: closing } at column 1)
  if ($0 ~ /^\}/) { flush_fn(); next }
  # extract PREFIX_* variable references (both $VAR and ${VAR...} and
  # emitted \$VAR forms; assignments inside the function count as usage too)
  line = $0
  while (match(line, prefix "_[A-Z][A-Z0-9_]*")) {
    v = substr(line, RSTART, RLENGTH)
    if (!(v in white)) used[v] = 1
    line = substr(line, RSTART + RLENGTH)
  }
  # selected external variables worth documenting when used
  if ($0 ~ /\$\{?EDITOR/)    used["EDITOR"] = 1
  if ($0 ~ /\$\{?GNUPGHOME/) used["GNUPGHOME"] = 1
}
END { flush_fn() }
' "$@"
