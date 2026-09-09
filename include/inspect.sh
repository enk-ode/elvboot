#!/bin/sh
#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Dr. Johannes Brügmann
# elebake inspect - look at what the last invocations actually did.
#
# Every invocation leaves a trace (the full cascade, commands and output
# interleaved) and a stderr log under .log/YYYY-MM-DD/. 'last' lists them,
# 'last <n>' opens one in the pager (pipe to sh).

#@help _last0
# @command last
# @summary Text terminal: the most recent invocations (trace files, newest first) with their verdict from the trace's final EXIT_BITS; view one with 'last <n> | sh'
# @group   diagnostics
# @env     ELEBAKE_RETENTION_DAYS_TRACE  must be > 0 for traces to exist at all
# @env     ELEBAKE_PAGER  the pager 'last <n> | sh' opens (profile pin)
# @example elebake last
# @see     last
#@end
_last0() {
        local f="" n=0
        printf '# last invocations (newest first) -- view one: elebake last <n> | sh\n'
        for f in $(ls -t "$ELEBAKE_BASE"/.log/*/*.trace 2>/dev/null | head -10); do
                n=$((n + 1))
                printf '# %2d  %-9s %s %s  %s (%s lines)\n' "$n" "$(trace_verdict "$f")" "$(basename "$(dirname "$f")")" "$(basename "$f" | cut -d. -f1)" "$(basename "$f" | sed 's/^[0-9.]*_*//;s/\.trace$//')" "$(wc -l < "$f" | tr -d ' ')"
        done
        test "${n:-0}" -gt 0 || printf '# (no traces -- is ELEBAKE_RETENTION_DAYS_TRACE > 0?)\n'
}

#@help ___last1
# @internal arity-1 of 'last' (last <n>): open the n-th newest trace in the pager -- the index is a number, the trace exists, the pager is pinned, then 'last open'; pipe to sh
#@end
___last1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" last index valid '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" last trace exists '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" pager set"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" last open '$1'"
}

#@help __last_index_valid1
# @command last index valid <n>
# @summary The index is a positive number: a comment line, else an error line
# @group   diagnostics
# @internal
# @see     last
#@end
__last_index_valid1() {
        if printf '%s\n' "$1" | grep -qx '[1-9][0-9]*'; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'trace index $1'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'last: not an index: $1'"
        fi
}

#@help __last_trace_exists1
# @command last trace exists <n>
# @summary The n-th newest trace exists: a comment line, else an error line
# @group   diagnostics
# @internal
# @see     last
#@end
__last_trace_exists1() {
        if test -n "$(ls -t "$ELEBAKE_BASE"/.log/*/*.trace 2>/dev/null | sed -n "${1}p" 2>/dev/null)"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'trace $1 exists'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'last: no trace at index $1 (see: elebake last)'"
        fi
}

#@help __pager_set0
# @command pager set
# @summary ELEBAKE_PAGER is set: a comment line, else an error line (environment init <profile>)
# @group   diagnostics
# @internal
# @env     ELEBAKE_PAGER  the pager
# @see     last
#@end
__pager_set0() {
        if test -n "${ELEBAKE_PAGER:-}"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'pager ${ELEBAKE_PAGER:-} pinned'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'ELEBAKE_PAGER not set (environment init <profile>)'"
        fi
}

#@help _last_open1
# @command last open <n>
# @summary Act terminal: the pager on the n-th newest trace, stdin and the screen on /dev/tty (under a pipe the pager would read the script instead of the keyboard)
# @group   diagnostics
# @internal
# @env     ELEBAKE_PAGER  the pager
# @see     last
#@end
_last_open1() {
        printf '%s\n' "$ELEBAKE_PAGER '$(ls -t "$ELEBAKE_BASE"/.log/*/*.trace 2>/dev/null | sed -n "${1}p")' </dev/tty >/dev/tty 2>&1"
}
