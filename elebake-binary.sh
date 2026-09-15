#!/bin/sh
#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Dr. Johannes Brügmann
#
# elebake-binary.sh -- elebake in ONE process (prototype, 14.09.2026).
#
#   sh elebake-binary.sh  <database> <command> [args...]   run the command
#   sh elebake-binary.sh  <database> batch <file>          run a batch or dump
#   sh elebake-compile.sh <database> <command> [args...]   write the script instead
#   sh elebake-compile.sh <database> batch <file>          the script of a whole dump
#
# The "binary" is elebake.sh sourced: all 945 anchors are functions of this
# process (main does not run -- $0 is not elebake.sh). The one new
# ingredient: "$ELEBAKE_CONTEXT_SCRIPT" is the function elv, not a path.
# Every line an anchor emits,
#     "$ELEBAKE_CONTEXT_SCRIPT" stage check stage 'daily-v1'
# eval'd in this process, is therefore a call of elv: resolve the words,
# run the anchor, hand its emission on by class and pin -- the work of
# process_arguments, without a process per line, without sourcing per
# line, without the pipeline of mktemp/tee/trace, without the batch ring
# on disk. The anchors are untouched; they do not know who runs them.
#
# Two modes, chosen by the name this file is called by:
#   elebake-binary.sh   -- INTERPRET: a terminal pinned to sh runs at once,
#                          in a subshell; the database advances line by
#                          line, so every predicate of a later line sees
#                          what the earlier lines made.
#   elebake-compile.sh  -- COMPILE: a terminal pinned to sh is written to
#                          stdout as a fragment; nothing acts. A CHECK --
#                          a combinator whose one line is a comment or an
#                          error -- is not answered at compile time but
#                          written as a call, 'elv <words> || exit 1', so
#                          the script asks it when it runs, after the
#                          fragments before it acted; the script sources
#                          this file in its header for that. The rest
#                          (batches, rewriting combinators) is expanded
#                          for the state the database has at compile
#                          time -- the state a run of the script starts
#                          from. Compiled and run on the same database,
#                          the script does what the interpreter does.
#
# Fail-fast and keep-going as in the batch runner: ELEBAKE_BATCH_KEEP_GOING=1
# lets a batch continue after a failing line; otherwise it stops there.
#
# The helpers this prototype began with (quoting, the environment cache,
# resolution, the pin) are the engine's since 14.09. -- test_engine_helpers_equal
# in the unit suite proves them equal to the ones before.

# ---------------------------------------------------------------- the binary
if [ -n "${ELV_SOURCED:-}" ]; then
        # sourced by a compiled script: the binary is where the script says
        ELEBAKE_LIBDIR=$ELV_LIBDIR
        ELV_MODE=run
else
        ELEBAKE_LIBDIR=$(cd "$(dirname "$0")" && pwd)
        case "${0##*/}" in elebake-compile.sh) ELV_MODE=compile ;; *) ELV_MODE=run ;; esac
        ELEBAKE_BASE=${1:?database}; shift
fi
ELEBAKE_ROOT=$(dirname "$ELEBAKE_BASE")
ELEBAKE_CONTEXT_SCRIPT=elv
ELEBAKE_INCLUDES=$(head -1 "$ELEBAKE_LIBDIR/template/environment/ELEBAKE_INCLUDES")
export ELEBAKE_LIBDIR ELEBAKE_BASE ELEBAKE_ROOT ELEBAKE_CONTEXT_SCRIPT ELEBAKE_INCLUDES
. "$ELEBAKE_LIBDIR/elebake.sh"          # metadata, engine, predicates, all includes
[ -s "$ELEBAKE_BASE/.env/local/ELEBAKE_CACHE_ENV_ARGS" ] || { echo "# Error: $ELEBAKE_BASE has no environment cache (elebake environment cache on)" >&2; exit 1; }
eval "export $(cat "$ELEBAKE_BASE/.env/local/ELEBAKE_CACHE_ENV_ARGS")"   # the pins, as the engine sees them
set +e                                   # elebake.sh sets -e; here elv decides

# The quoting (q, sq), the environment cache (build_env_args_full,
# should_skip_env_value), the resolution (resolve_call) and the pin
# (pin_of) are the engine's own since 14.09.: sourced above, no copies.
# env_reload -- after a setenv/unsetenv/cache-on act: every child of the
# per-process model reads the cache file; the one process re-reads it
env_reload() {
        local f="$ELEBAKE_BASE/.env/local/ELEBAKE_CACHE_ENV_ARGS"
        [ -s "$f" ] || return 0
        eval "export $(cat "$f")"
}

# ------------------------------------------------------------ 4. the runner
ELV_TMP=$ELEBAKE_BASE/.tmp/elv-gen.$$
ELV_DEPTH=0          # an act may call "$ELEBAKE_CONTEXT_SCRIPT" -- elv again, in its subshell: own file per depth
# only_comments <file> -- 0 when every non-empty line starts with #: such an
# emission does nothing under sh (a comment terminal); no subshell for it
only_comments() {
        local line
        while IFS= read -r line || [ -n "$line" ]; do
                case "$line" in ""|\#*) ;; *) return 1 ;; esac
        done < "$1"
        return 0
}
# elv_text <text> -- run every "$ELEBAKE_CONTEXT_SCRIPT" line of a batch
# (a dump, or an emission) through elv; other lines are printed. The
# batch runner's rule: keep-going counts failures, fail-fast stops at the
# first. Returns 1 when a line failed. Pure shell: the text is cut line by
# line with parameter expansion, no pipe, no subshell.
elv_text() {
        local text=$1 line rc=0 failed=0
        while [ -n "$text" ]; do
                line=${text%%
*}
                case "$text" in *"
"*) text=${text#*
} ;; *) text="" ;; esac
                case "$line" in
                'env '*'"$ELEBAKE_CONTEXT_SCRIPT" '*)
                        # env NAME=value ... "$ELEBAKE_CONTEXT_SCRIPT" words (restore replay):
                        # without env the assignments prefix the call of elv --
                        # the shell hands them into the function
                        if ! eval "${line#env }"; then
                                failed=$((failed + 1))
                                printf '# failed: %s\n' "$line" >&2
                                [ "${ELEBAKE_BATCH_KEEP_GOING:-0}" = 1 ] || return 1
                        fi ;;
                '"$ELEBAKE_CONTEXT_SCRIPT" '*' > '*|'"$ELEBAKE_CONTEXT_SCRIPT" '*' >> '*)
                        # a line that redirects (stage site mk, environment cache on):
                        # interpreted, the redirection binds this process's call;
                        # compiled, the line itself is the fragment -- the script
                        # runs it under the header's ELEBAKE_CONTEXT_SCRIPT
                        if [ "$ELV_MODE" != run ]; then
                                printf '%s\n' "$line"
                        elif ! eval "$line"; then
                                failed=$((failed + 1))
                                printf '# failed: %s\n' "$line" >&2
                                [ "${ELEBAKE_BATCH_KEEP_GOING:-0}" = 1 ] || return 1
                        fi ;;
                '"$ELEBAKE_CONTEXT_SCRIPT" '*)
                        if ! eval "$line"; then
                                failed=$((failed + 1))
                                printf '# failed: %s\n' "$line" >&2
                                [ "${ELEBAKE_BATCH_KEEP_GOING:-0}" = 1 ] || return 1
                        fi ;;
                *) printf '%s\n' "$line" ;;
                esac
        done
        [ "$failed" -eq 0 ] || rc=1
        return $rc
}
# elv_file <file> -- the file's lines, read once, then elv_text
elv_file() {
        local text="" line
        while IFS= read -r line || [ -n "$line" ]; do text="$text$line
"; done < "$1"
        elv_text "$text"
}
# elv <word>... -- the context script as a function.
#   batch <file>: the file's lines, here (the engine's _batch2 would spawn
#             a process per line)
#   generate: the anchor runs in THIS process, its emission goes to a file
#             (a $( ) capture forks the whole big process, 1.3 ms; the
#             file costs 0.13 ms)
#   batch / combinator: the emitted lines are read into a variable (the
#             recursion reuses the file) and go through elv_text
#   terminal: cat prints; sh runs the script in a subshell (interpret) or
#             writes it out as a fragment (compile); any other pin gets the
#             script on stdin, as today
elv() {
        local call name rc=0 own line ELV_TMP="$ELV_TMP.$ELV_DEPTH"
        ELV_DEPTH=$((ELV_DEPTH + 1))
        case "$1" in batch) [ $# -eq 2 ] && { elv_file "$2"; rc=$?; ELV_DEPTH=$((ELV_DEPTH - 1)); return $rc; } ;; esac
        resolve_call "$ANCHOR_FUNCTIONS" "$@"; call=$CALL
        name=${call%% *}
        eval "$call" > "$ELV_TMP"
        case "$name" in
        __*)
                own=""
                while IFS= read -r line || [ -n "$line" ]; do own="$own$line
"; done < "$ELV_TMP"
                case "$ELV_MODE:$own" in
                compile:'"$ELEBAKE_CONTEXT_SCRIPT" comment '*|compile:'"$ELEBAKE_CONTEXT_SCRIPT" error '*)
                        # a check: asked when the script runs, not answered now
                        own=""
                        for line in "$@"; do q "$line"; own="$own $Q"; done
                        if [ "${ELEBAKE_BATCH_KEEP_GOING:-0}" = 1 ]; then
                                printf 'elv%s || printf %s >&2\n' "$own" "'# failed: %s\\n' '$*'"
                        else
                                printf 'elv%s || exit 1\n' "$own"
                        fi ;;
                *)      elv_text "$own"; rc=$? ;;
                esac ;;
        ___*)
                own=""
                while IFS= read -r line || [ -n "$line" ]; do own="$own$line
"; done < "$ELV_TMP"
                elv_text "$own"; rc=$? ;;
        *)
                pin_of "$name"
                case "$PIN" in
                cat) cat "$ELV_TMP" ;;
                sh)
                        if only_comments "$ELV_TMP"; then
                                [ "$ELV_MODE" = run ] || cat "$ELV_TMP"
                        elif [ "$ELV_MODE" = run ]; then
                                ( . "$ELV_TMP" ); rc=$?
                        else
                                # the fragment: a subshell, so an exit inside stays inside; the
                                # clause after it is the batch rule -- stop, or note and go on
                                printf '# -- %s %s\n(\n' "$name" "$*"
                                cat "$ELV_TMP"
                                if [ "${ELEBAKE_BATCH_KEEP_GOING:-0}" = 1 ]; then
                                        q "$*"; printf ') || printf %s >&2\n' "'# failed: %s\\n' $Q"
                                else
                                        printf ') || exit 1\n'
                                fi
                        fi ;;
                *)   eval "$PIN" < "$ELV_TMP"; rc=$? ;;
                esac
                case "$name" in
                _setenv_write2|_unsetenv_erase1|_environment_cache_place0) [ "$ELV_MODE" = run ] && env_reload ;;
                esac ;;
        esac
        rm -f "$ELV_TMP"
        ELV_DEPTH=$((ELV_DEPTH - 1))
        return $rc
}

# ------------------------------------------------------------------ main
# sourced by a compiled script: elv is defined, nothing to run here
[ -z "${ELV_SOURCED:-}" ] || return 0 2>/dev/null || exit 0
# a dump names its archive base in the header (# Serial: N -> incoming/N)
case "$1" in
batch)  [ -n "${ELEBAKE_ARCHIVE_BASE:-}" ] || ELEBAKE_ARCHIVE_BASE="$ELEBAKE_ROOT/incoming/$(sed -n 's/^# Serial: //p' "$2" 2>/dev/null | head -1)"
        export ELEBAKE_ARCHIVE_BASE ;;
esac
if [ "$ELV_MODE" != run ]; then
        # the header of a compiled script: the database, then this file
        # sourced (elv for the checks; "$ELEBAKE_CONTEXT_SCRIPT" is elv, so a
        # redirecting line runs in-process), then the batch rule
        printf '#!/bin/sh\n# compiled by elebake-compile.sh from: %s\n# database %s, %s\n' "$*" "$ELEBAKE_BASE" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        printf 'ELEBAKE_BASE=%s; export ELEBAKE_BASE\n' "$(sq "$ELEBAKE_BASE")"
        printf 'ELV_SOURCED=1; ELV_LIBDIR=%s; . %s          # elv: the checks below ask the database when they run\n' "$(sq "$ELEBAKE_LIBDIR")" "$(sq "$ELEBAKE_LIBDIR/elebake-binary.sh")"
        printf 'ELEBAKE_BATCH_KEEP_GOING=%s\n' "${ELEBAKE_BATCH_KEEP_GOING:-0}"
fi
elv "$@"; rc=$?
exit $rc
