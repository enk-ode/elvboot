#!/bin/sh
#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Dr. Johannes Brügmann
#
# elebake-walkthrough.sh -- walk the resolution tree of one elebake command:
# the counterpart of vpn-switch's scripts/vpn-switch-walkthrough.sh.
#
# Every node of the tree is run ONCE with its interpreter pinned to cat, so
# it prints what it would hand on (a combinator: one line, a batch: its
# lines, a terminal: its script) and acts on nothing; the walker then
# descends into the printed lines. The pins are set with setenv and removed
# with unsetenv, so the database's .env/local is touched and restored --
# use a test or probe database. Predicates are evaluated against the
# database AS IT IS: the tree is the one this state produces, no state
# advances during the walk.
#
# Usage:
#   scripts/elebake-walkthrough.sh --database <path> [--depth <n>] <command> [args...]
#
# Output: the tree, then a count of nodes by class -- the number of elebake
# processes a real run of the command starts (one per node), the
# interpreters not counted.

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ELEBAKE="${SCRIPT_DIR}/../elebake.sh"
ARCH_TEST="${SCRIPT_DIR}/../elebake-architecture-test.sh"

DATABASE=""
MAX_DEPTH=""
N_BATCH=0; N_COMB=0; N_TERM=0; N_UNRESOLVED=0
TERMINAL_LINES=0

usage() {
        sed -n '8,26p' "$0" | sed 's/^# \{0,1\}//'
        exit 0
}

# the anchor list is the one make metadata writes into the architecture suite
ANCHOR_FUNCTIONS=$(sed -n 's/^ANCHOR_FUNCTIONS="\(.*\)"$/\1/p' "$ARCH_TEST" | head -1)

elebake() { env ELEBAKE_BASE="$DATABASE" "$ELEBAKE" "$@"; }

known() { case " $ANCHOR_FUNCTIONS " in *" $1 "*) return 0 ;; esac; return 1; }

# resolve <word>... -- the function the words name, by the dispatch rule:
# the longest prefix of words that is a function name wins, the rest are
# arguments; an arity suffix equal to the argument count first, then none;
# batch before combinator before terminal.
resolve() {
        local n=$# k name arity cand pfx
        k=$n
        while [ "$k" -ge 1 ]; do
                name=$(printf '%s\n' "$@" | head -n "$k" | tr '\n' '_' | sed 's/_$//; s/-/_/g')
                arity=$((n - k))
                for cand in "${name}${arity}" "$name"; do
                        for pfx in ___ __ _; do
                                if known "${pfx}${cand}"; then
                                        printf '%s\n' "${pfx}${cand}"
                                        return 0
                                fi
                        done
                done
                k=$((k - 1))
        done
        return 1
}

indent() { printf '%*s' $(($1 * 2)) ''; }

# walk <depth> <word>... -- one node: pin cat, run, print, descend
walk() {
        local depth="$1"; shift
        local func mangled output status count line
        if [ -n "$MAX_DEPTH" ] && [ "$depth" -ge "$MAX_DEPTH" ]; then
                printf '%s... depth limit: %s\n' "$(indent "$depth")" "$*"
                return 0
        fi
        if ! func=$(resolve "$@"); then
                N_UNRESOLVED=$((N_UNRESOLVED + 1))
                printf '%s?  unresolved: %s\n' "$(indent "$depth")" "$*"
                return 0
        fi
        mangled=${func#___}; mangled=${mangled#__}; mangled=${mangled#_}
        elebake setenv "ELEBAKE_INTERPRETER_${mangled}" cat > /dev/null 2>&1
        set +e
        output=$(elebake "$@" 2>&1)
        status=$?
        set -e
        elebake unsetenv "ELEBAKE_INTERPRETER_${mangled}" > /dev/null 2>&1 || true
        case "$func" in
        ___*)
                count=$(printf '%s\n' "$output" | grep -c '^"\$ELEBAKE_CONTEXT_SCRIPT"' || true)
                N_BATCH=$((N_BATCH + 1))
                printf '%s├─ BATCH      %s  [%s, exit %s, %s lines]\n' "$(indent "$depth")" "$*" "$func" "$status" "$count"
                printf '%s\n' "$output" | while IFS= read -r line; do
                        case "$line" in
                        '"$ELEBAKE_CONTEXT_SCRIPT" '*)
                                line=${line#\"\$ELEBAKE_CONTEXT_SCRIPT\" }
                                eval "walk $((depth + 1)) $line"
                                ;;
                        \#*|"") ;;
                        *) printf '%s   (text) %s\n' "$(indent "$depth")" "$line" ;;
                        esac
                done
                ;;
        __*)
                N_COMB=$((N_COMB + 1))
                line=$(printf '%s\n' "$output" | grep '^"\$ELEBAKE_CONTEXT_SCRIPT"' | head -1 || true)
                printf '%s├─ COMBINATOR %s  [%s, exit %s]\n' "$(indent "$depth")" "$*" "$func" "$status"
                if [ -n "$line" ]; then
                        line=${line#\"\$ELEBAKE_CONTEXT_SCRIPT\" }
                        eval "walk $((depth + 1)) $line"
                else
                        printf '%s   (no line) %s\n' "$(indent "$depth")" "$(printf '%s\n' "$output" | head -1)"
                fi
                ;;
        *)
                N_TERM=$((N_TERM + 1))
                count=$(printf '%s\n' "$output" | grep -c . || true)
                TERMINAL_LINES=$((TERMINAL_LINES + count))
                printf '%s└─ TERMINAL   %s  [%s, exit %s, %s script lines]\n' "$(indent "$depth")" "$*" "$func" "$status" "$count"
                printf '%s\n' "$output" | sed "s/^/$(indent "$depth")      | /"
                ;;
        esac
}

while [ $# -gt 0 ]; do
        case "$1" in
        --database) DATABASE="$2"; shift 2 ;;
        --depth) MAX_DEPTH="$2"; shift 2 ;;
        --help|-h) usage ;;
        *) break ;;
        esac
done
test -n "$DATABASE" || { echo "Error: --database <path> is required" >&2; exit 1; }
test $# -gt 0 || { echo "Error: no command" >&2; exit 1; }
test -n "$ANCHOR_FUNCTIONS" || { echo "Error: no ANCHOR_FUNCTIONS in $ARCH_TEST (make metadata)" >&2; exit 1; }

echo "elebake walkthrough -- database $DATABASE"
echo "command: $*"
echo ""
# the counters live in this shell: the batch loop runs in a subshell (pipe),
# so the totals are collected from the printed tree instead
walk 0 "$@" | tee "${TMPDIR:-/tmp}/elebake-walkthrough.$$"
tree="${TMPDIR:-/tmp}/elebake-walkthrough.$$"
echo ""
printf 'nodes: %s batches, %s combinators, %s terminals, %s unresolved -- %s elebake processes in a real run, %s script lines\n' \
        "$(grep -c '├─ BATCH' "$tree" || true)" "$(grep -c '├─ COMBINATOR' "$tree" || true)" \
        "$(grep -c '└─ TERMINAL' "$tree" || true)" "$(grep -c '?  unresolved' "$tree" || true)" \
        "$(grep -c '├─ \|└─ ' "$tree" || true)" \
        "$(grep -c '      | ' "$tree" || true)"
rm -f "$tree"
