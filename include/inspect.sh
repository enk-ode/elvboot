#!/bin/sh
#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Dr. Johannes Brügmann
# elebake inspect - look at what the last invocations actually did.
#
# Every invocation leaves a trace (the full cascade, commands and output
# interleaved) and a stderr log under .log/YYYY-MM-DD/. These terminals make
# them reachable without spelunking: `last` lists, `last <n>` opens one.
#
# ARCHITECTURE: TERMINALS — display-style (the emission IS the display) for
# the list; the viewer emits a pager command reading from /dev/tty.

#@help _last0
# @command last
# @summary List the most recent invocations (trace/log files, newest first)
# @group   diagnostics
# @env     ELEBAKE_RETENTION_DAYS_TRACE  must be > 0 for traces to exist at all
# @example elebake last
#@end
_last0() {
  local base="$ELEBAKE_BASE" f n=0
  printf '# last invocations (newest first) — view one: elebake last <n> | sh\n'
  local bits verdict
  for f in $(ls -t "$base"/.log/*/*.trace 2>/dev/null | head -10); do
    n=$((n+1))
    # the last 'final EXIT_BITS' line is the invocation's outcome; emitted
    # error BRANCHES ('# Error: ...' inside command text) are code, not
    # failures -- this column answers "did it actually fail?" at a glance.
    bits=$(grep -o 'final EXIT_BITS: [0-9.]*' "$f" | tail -n1 | sed 's/.*: //')
    case "$bits" in ''|0|0.0|0.0.0) verdict=ok ;; *) verdict="FAIL($bits)" ;; esac
    printf '# %2d  %-9s %s %s  %s (%s lines)\n' "$n" "$verdict" \
      "$(basename "$(dirname "$f")")" \
      "$(basename "$f" | cut -d. -f1)" \
      "$(basename "$f" | sed 's/^[0-9.]*_*//;s/\.trace$//')" \
      "$(wc -l < "$f" | tr -d ' ')"
  done
  [ "$n" -gt 0 ] || printf '# (no traces — is ELEBAKE_RETENTION_DAYS_TRACE > 0?)\n'
}

#@help _last1
# @internal arity sibling of 'last': open the n-th newest trace (pipe to sh);
# n = index from `elebake last` (1 = newest), e.g. `elebake last 1 | sh`
#@end
_last1() {
  local base="$ELEBAKE_BASE" k="$1" f
  case "$k" in ''|*[!0-9]*)
    generate_error "last: not an index: '$k'"; return 0 ;;
  esac
  f=$(ls -t "$base"/.log/*/*.trace 2>/dev/null | sed -n "${k}p")
  [ -n "$f" ] || {
    generate_error "last: no trace at index $k (see: elebake last)"; return 0; }
  # </dev/tty: under `... | sh` the script arrives on stdin, and a pager
  # inheriting that pipe would read the script instead of the keyboard.
  printf '%s\n' "\${PAGER:-less} '$f' </dev/tty"
}
