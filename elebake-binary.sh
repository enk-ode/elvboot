#!/bin/sh
#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Dr. Johannes Brügmann
#
# elebake-binary.sh -- elebake in ONE process.
#
#   sh elebake-binary.sh  <database> <command> [args...]   run the command
#   sh elebake-binary.sh  <database> batch <file>          run a batch or dump
#   sh elebake-compile.sh <database> <command> [args...]   write the script instead
#   sh elebake-compile.sh <database> batch <file>          the script of a whole dump
#   sh elebake-walkthrough.sh <database> <command> [args...]   show the tree, act on nothing
#
# The binary is elebake.sh sourced: every anchor, the engine's main, its
# batch runner _batch2, the batch ring and the exit arithmetic are
# functions of this process (elebake.sh's own main does not run -- $0 is
# not elebake.sh). Three things differ from a run of elebake.sh:
#
#   1. "$ELEBAKE_CONTEXT_SCRIPT" is the word main. A line an anchor emits,
#          "$ELEBAKE_CONTEXT_SCRIPT" stage check stage 'daily-v1'
#      eval'd in this process, calls the engine's main: the same checks,
#      the same process_arguments, the same 0 or 1 the child process
#      would have exited with. A function is not inherited by a process,
#      so the line must be run by the shell that owns it -- that is 3.
#   2. env is a function. A line 'env NAME=value ... "$ELEBAKE_CONTEXT_SCRIPT" ...'
#      (restore replay, bootstrap init) becomes a prefix assignment to
#      the call: the shell keeps the value for the call and drops it
#      after, as env does for a process. An env with an option (run_env's
#      env -) is the program.
#   3. process_arguments is overridden. The engine's runs a pipeline per
#      call -- mktemp, produce | consume, run_env, a process per pin, a
#      process per combinator line (the context script, sourcing
#      everything again). Here: resolve, dispatch into a file, hand the
#      emission on by pin -- cat prints; a batch combinator's lines go
#      through main batch, a combinator's one line through eval, both in
#      this process; a terminal pinned to sh runs in a subshell; any
#      other pin gets the file on stdin through run_env, as today. Then
#      combine_exit_codes, the engine's, with the same five arguments.
#      Fail-fast, keep-going and the batch codes are the engine's.
#
# Three modes, chosen by the name this file is called by:
#   elebake-binary.sh   -- INTERPRET: a terminal pinned to sh runs at once;
#                          the database advances line by line, so every
#                          predicate of a later line sees what the earlier
#                          lines made.
#   elebake-compile.sh  -- COMPILE: a terminal pinned to sh is written to
#                          stdout as a fragment; nothing acts. A CHECK --
#                          a combinator whose one line is a comment or an
#                          error -- is not answered at compile time but
#                          written as a call, 'main <words> || exit 1', so
#                          the script asks it when it runs, after the
#                          fragments before it acted; the script sources
#                          this file in its header for that. A batch line
#                          that redirects ('... > file') is written as it
#                          is: the script runs it, in its own process. The
#                          rest is expanded for the state the database has
#                          at compile time -- the state a run of the script
#                          starts from. Compiled and run on the same
#                          database, the script does what the interpreter
#                          does.
#   elebake-walkthrough.sh -- WALK: what the command would do, as text,
#                          in one process and in seconds: every terminal
#                          prints its script under a '# -- <anchor> <words>'
#                          line, whatever its pin; checks are answered now,
#                          against the database as it is; a batch line that
#                          redirects is shown, not run. Nothing acts, no
#                          fragment wrappers, no header. The database is
#                          read, never written (the batch ring under .tmp
#                          aside). The reading of a walkthrough is the
#                          tutorial's: see what a step means before it runs.
#
# The database must carry an environment cache (elebake environment cache
# on; init writes it): the binary binds it once and never builds it.

# ---------------------------------------------------------------- the binary
if [ -n "${ELV_SOURCED:-}" ]; then
        # sourced by a compiled script: the binary is where the script says
        ELEBAKE_LIBDIR=$ELV_LIBDIR
        ELV_MODE=run
else
        ELEBAKE_LIBDIR=$(cd "$(dirname "$0")" && pwd)
        case "${0##*/}" in
        elebake-compile.sh)     ELV_MODE=compile ;;
        elebake-walkthrough.sh) ELV_MODE=walk ;;
        *)                      ELV_MODE=run ;;
        esac
        ELEBAKE_BASE=${1:?database}; shift
fi
ELEBAKE_ROOT=$(dirname "$ELEBAKE_BASE")
ELEBAKE_CONTEXT_SCRIPT=main
ELEBAKE_BASE_EXPLICIT=1                  # what elebake.sh's startup notes for main
ELEBAKE_CONTEXT_EXIT_BITS=${ELEBAKE_CONTEXT_EXIT_BITS:-0}
ELEBAKE_INCLUDES=$(head -1 "$ELEBAKE_LIBDIR/template/environment/ELEBAKE_INCLUDES")
export ELEBAKE_LIBDIR ELEBAKE_BASE ELEBAKE_ROOT ELEBAKE_CONTEXT_SCRIPT ELEBAKE_INCLUDES ELEBAKE_CONTEXT_EXIT_BITS
. "$ELEBAKE_LIBDIR/elebake.sh"          # metadata, engine, predicates, all includes
[ -s "$ELEBAKE_BASE/.env/local/ELEBAKE_CACHE_ENV_ARGS" ] || { echo "# Error: $ELEBAKE_BASE has no environment cache (elebake environment cache on)" >&2; exit 1; }
eval "export $(cat "$ELEBAKE_BASE/.env/local/ELEBAKE_CACHE_ENV_ARGS")"   # the pins, as the engine sees them
set +e                                   # elebake.sh sets -e; here the exit codes are values
ELV_DEPTH=0                              # a nested call has its own generation file, reused
trap 'rm -f "$ELEBAKE_BASE"/.tmp/elv.$$.*' EXIT

# env NAME=value ... <command> ... -- the assignments prefix the call:
# the shell binds them for the call and restores them after, as env does
# for a process. env with an option (env -, run_env's isolated call) is
# the program.
env() {
        local pre="" cmd="" w
        case "${1:-}" in -*) command env "$@"; return ;; esac
        while [ $# -gt 0 ]; do
                case "$1" in
                [A-Za-z_]*=*)
                        case "${1%%=*}" in *[!A-Za-z0-9_]*) break ;; esac
                        q "${1#*=}"; pre="$pre ${1%%=*}=$Q"; shift ;;
                *)      break ;;
                esac
        done
        for w in "$@"; do q "$w"; cmd="$cmd $Q"; done
        eval "${pre# }$cmd"
}

# env_reload -- after a setenv/unsetenv/cache-place act: every later call
# of this process sees the environment the act wrote (a child process
# would have read it at its start).
env_reload() {
        local f="$ELEBAKE_BASE/.env/local/ELEBAKE_CACHE_ENV_ARGS"
        [ -s "$f" ] || return 0
        eval "export $(cat "$f")"
}

# only_comments <file> -- the emission is comment lines only (a check
# that passed, a note): nothing to run, nothing to compile but the text
only_comments() {
        local line
        while IFS= read -r line || [ -n "$line" ]; do
                case "$line" in ""|\#*) ;; *) return 1 ;; esac
        done < "$1"
        return 0
}

# elv_batch <file> -- the emission of a batch combinator: main batch runs
# it (the engine's _batch2 -- the lines, the ring, keep-going, fail-fast).
# Compiling or walking, the lines are walked here: a comment or a
# redirecting line is written as it is, every other line is a call whose
# emission compiles, or shows.
elv_batch() {
        local line
        if [ "$ELV_MODE" = run ]; then
                main batch "$1" true
                return
        fi
        while IFS= read -r line || [ -n "$line" ]; do
                case "$line" in
                ''|'#'*|*' > '*|*' >> '*) printf '%s\n' "$line" ;;
                *) eval "$line" ;;
                esac
        done < "$1"
}

# elv_line <file> <word>... -- the one line of a combinator, eval'd: main,
# or env ... main. Compiling, a check (the line is a comment or an error)
# becomes a call the script makes when it runs.
elv_line() {
        local line file="$1" own="" w
        shift
        read -r line < "$file"
        case "$ELV_MODE:$line" in
        compile:'"$ELEBAKE_CONTEXT_SCRIPT" comment '*|compile:'"$ELEBAKE_CONTEXT_SCRIPT" error '*)
                for w in "$@"; do q "$w"; own="$own $Q"; done
                if [ "${ELEBAKE_BATCH_KEEP_GOING:-0}" = 1 ]; then
                        printf 'main%s || printf %s >&2\n' "$own" "'# failed: %s\\n' '$*'"
                else
                        printf 'main%s || exit 1\n' "$own"
                fi ;;
        *)      eval "$line" ;;
        esac
}

# elv_act <file> <name> <word>... -- a terminal pinned to sh: run in a
# subshell, written as the fragment of the script (a subshell, so an
# exit inside stays inside; the clause after it is the batch rule), or
# shown under its anchor line (walk).
elv_act() {
        local file="$1" name="$2"
        shift 2
        if only_comments "$file"; then
                [ "$ELV_MODE" = run ] || cat "$file"
        elif [ "$ELV_MODE" = run ]; then
                ( . "$file" )
        elif [ "$ELV_MODE" = walk ]; then
                printf '# -- %s %s\n' "$name" "$*"
                cat "$file"
        else
                printf '# -- %s %s\n(\n' "$name" "$*"
                cat "$file"
                if [ "${ELEBAKE_BATCH_KEEP_GOING:-0}" = 1 ]; then
                        q "$*"; printf ') || printf %s >&2\n' "'# failed: %s\\n' $Q"
                else
                        printf ') || exit 1\n'
                fi
        fi
}

# process_arguments <word>... -- the engine's, without its pipeline: the
# resolution and dispatch are the engine's; the emission goes to a file
# and on by pin, in this process wherever the pin would have spawned the
# context script; the exit codes combine as the engine combines them.
process_arguments() {
        local bits="${ELEBAKE_CONTEXT_EXIT_BITS:-0}" call name pe ce=0 pb=0 cb=0
        local file="$ELEBAKE_BASE/.tmp/elv.$$.$ELV_DEPTH"
        if [ $# -gt 0 ]; then alias_of "$1"; shift; set -- "$ALIAS" "$@"; fi
        resolve_call "$ANCHOR_FUNCTIONS" "$@"; call=$CALL; name=${call%% *}
        export ELEBAKE_CONTEXT_CALL="$call"
        case "$name" in _batch2) pb=1 ;; ___*) cb=1 ;; esac
        ELV_DEPTH=$((ELV_DEPTH + 1))
        dispatch < /dev/null > "$file"; pe=$?
        pin_of "$name"
        case "$PIN:$name" in
        cat:*)  cat "$file" ;;
        *:___*) elv_batch "$file"; ce=$? ;;
        *:__*)  elv_line "$file" "$@"; ce=$? ;;
        sh:*)   elv_act "$file" "$name" "$@"; ce=$? ;;
        *)      if [ "$ELV_MODE" = walk ]; then
                        printf '# -- %s %s (pin: %s)\n' "$name" "$*" "$PIN"
                        cat "$file"
                else
                        eval "run_env -- $PIN" < "$file"; ce=$?
                fi ;;
        esac
        ELV_DEPTH=$((ELV_DEPTH - 1))
        case "$name" in
        _setenv_write2|_unsetenv_erase1|_environment_cache_place0) [ "$ELV_MODE" = run ] && env_reload ;;
        esac
        ELEBAKE_CONTEXT_CALL=$call       # main reads it after the call
        combine_exit_codes "$bits" "$pe" "$ce" "$pb" "$cb"
}

# ------------------------------------------------------------------ main
# sourced by a compiled script: main and the override are defined, nothing to run here
[ -z "${ELV_SOURCED:-}" ] || return 0 2>/dev/null || exit 0
# a dump names its archive base in the header (# Serial: N -> incoming/N)
case "$1" in
batch)  [ -n "${ELEBAKE_ARCHIVE_BASE:-}" ] || ELEBAKE_ARCHIVE_BASE="$ELEBAKE_ROOT/incoming/$(sed -n 's/^# Serial: //p' "$2" 2>/dev/null | head -1)"
        export ELEBAKE_ARCHIVE_BASE ;;
esac
if [ "$ELV_MODE" = compile ]; then
        # the header of a compiled script: the database, then this file
        # sourced (main for the checks; "$ELEBAKE_CONTEXT_SCRIPT" is main, so a
        # redirecting line runs in the script's process), then the batch rule
        printf '#!/bin/sh\n# compiled by elebake-compile.sh from: %s\n# database %s, %s\n' "$*" "$ELEBAKE_BASE" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        printf 'ELEBAKE_BASE=%s; export ELEBAKE_BASE\n' "$(sq "$ELEBAKE_BASE")"
        printf 'ELV_SOURCED=1; ELV_LIBDIR=%s; . %s          # main: the checks below ask the database when they run\n' "$(sq "$ELEBAKE_LIBDIR")" "$(sq "$ELEBAKE_LIBDIR/elebake-binary.sh")"
        printf 'ELEBAKE_BATCH_KEEP_GOING=%s\n' "${ELEBAKE_BATCH_KEEP_GOING:-0}"
fi
main "$@"
