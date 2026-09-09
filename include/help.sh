#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Dr. Johannes Brügmann
# help.sh - the generated help system (ported from vpn-switch, its source of
# truth for mechanically assembled help).
#
# Help text is assembled from #@help doc-blocks declared above each anchor
# function. This module owns:
#   - the @defgroup taxonomy and @topic entries (below),
#   - the runtime parser + renderer (help_render),
#   - the user-facing entry points (_help0 overview, _help1/_help2 detail).
# A doc-block that lies is a bug; hand-maintained overviews are not accepted.

# --- Help taxonomy: overview sections, ordered by @order ---------------------

#@help
# @defgroup setup  Without a database
# @order   10
#   The only commands that run without an existing database. Start here.
#@end

#@help
# @defgroup configuration  Configuration
# @order   20
#   Read and change elebake environment variables and interpreter pins.
#@end

#@help
# @defgroup database  Database lifecycle
# @order   30
#   Back up, restore and batch-drive the database itself.
#@end

#@help
# @defgroup keys  Keys
# @order   40
#   Key registries. Records hold REFERENCES (paths, URIs, key ids) -- never
#   private material; custody stays with the token, keyring, or root file.
#@end

#@help
# @defgroup stage  Stage pipeline
# @order   50
#   A stage is one named workspace for one boot tree: bind keys, check out a
#   worktree, embed trust, build isolated, curate, sign, attest.
#@end

#@help
# @defgroup provisioning  Provisioning
# @order   60
#   The machine-bound trust expectations: the NVRAM boot marker and the
#   compiled-in baselines (local/site.mk). What turns a generic loader into
#   THIS machine's tamper detector.
#@end

#@help
# @defgroup deploy  Medium
# @order   70
#   The physical boot medium: bind it, back up its loader, swap, roll back.
#@end

#@help
# @defgroup diagnostics  Diagnostics
# @defgroup foundation  Trust foundation (catalogs and, soon, claims/gates/policies)
# @order   80
#   Toolchain readiness checks; each backend answers for itself.
#@end

#@help
# @topic Inspect-by-default
# @group setup
#   Pipeline commands PRINT their shell: review, then append '| sh' to run
#   ('| sudo sh' where the ESP or root-only keys are involved). Bookkeeping
#   (add/bind/setenv/filter) is pinned to sh and acts directly.
#   Experienced users may flip the safety default so EVERY terminal acts:
#   elebake setenv ELEBAKE_TERMINAL_INTERPRETER sh
#   (inspect any single command via setintp <family> cat, or per run
#   under an explicit interpreter).
#@end

# --- Generated-help engine ---------------------------------------------------
# help_source_files: the files scanned for #@help doc-blocks at runtime.

help_source_files() {
        echo "$ELEBAKE_CONTEXT_SCRIPT"
        local m
        for m in "$ELEBAKE_LIBDIR"/include/*.sh; do
                [ -f "$m" ] || continue
                [ "$m" = "$ELEBAKE_CONTEXT_SCRIPT" ] && continue
                echo "$m"
        done
}

# help_render MODE [TARGET] -- feed every source with doc-blocks to
# template/awk/help-render.awk (overview | query <target> | group <target> |
# manpage). Honours ELEBAKE_DISPLAY_ANSI. Pure read of the doc-blocks.

help_render() {
        local mode="$1" target="${2:-}"
        local ch="" cc="" cg="" cr=""
        if [ "${ELEBAKE_DISPLAY_ANSI:-0}" = "1" ]; then
                ch="$COLOR_BLUE"; cc="$COLOR_CYAN"; cg="$COLOR_GRAY"; cr="$COLOR_RESET"
        fi
        help_source_files | tr '\n' '\0' | xargs -0 cat 2>>"$LOG_FILE" | awk \
        -v mode="$mode" -v target="$target" \
        -v ch="$ch" -v cc="$cc" -v cg="$cg" -v cr="$cr" \
        -f "$ELEBAKE_TEMPLATE_DIR/awk/help-render.awk"
}

#@help _help0
# @command help [<command|group|topic>]
# @summary Show the grouped overview, or detail for a command, group or topic
# @group   setup
# @param   command  any command path, unquoted (stage sign key), a group (keys, stage,
# @param            provisioning, deploy, ...) or a topic (environment)
# @returns help text (no database required)
# @env     ELEBAKE_DISPLAY_ANSI  0 disables colored output
# @example elebake help stage
# @example elebake help stage sign
#@end
_help0() {
        local c_reset="" c_heading="" c_gray=""
        if [ "${ELEBAKE_DISPLAY_ANSI:-0}" = "1" ]; then
                c_reset="$COLOR_RESET"; c_heading="$COLOR_BLUE"; c_gray="$COLOR_GRAY"
        fi
        printf '%b\n' "${c_heading}elebake${c_reset} - emit-and-inspect tooling for verified boot / tamper detection"
        echo ""
        printf '%b\n' "${c_gray}Usage:${c_reset} elebake <command> [arguments]"
        printf '%b\n' "${c_gray}Detail for any command:${c_reset} elebake help <command>   ${c_gray}(e.g. elebake help stage sign)${c_reset}"
        echo ""
        help_render overview
        echo ""
        printf '%b\n' "${c_gray}Concept topic:${c_reset} elebake help environment"
}

#@help _help1
# @internal arity-1 sibling of 'help' (a group, a topic, a one-word command path): help_render query
#@end
_help1() {
        help_render query "$1"
}

#@help _help_environment0
# @command help environment
# @summary The concept topic: the environment system and the safety-first design (interpreters, pins, the three-layer cascade, profiles, logs) -- template/manual/topic-environment.md
# @group   setup
# @env     ELEBAKE_TEMPLATE_DIR  where the topic text lives
# @example elebake help environment
# @see     help env
# @see     setintp
#@end
_help_environment0() {
        cat "$ELEBAKE_TEMPLATE_DIR/manual/topic-environment.md"
}

#@help _help2
# @internal arity-2 sibling of 'help' (detail for two-word command paths)
#@end
_help2() {
        help_render query "$1 $2"
}

#@help _help3
# @internal arity-3 sibling of 'help' (three-word command paths, e.g. stage sign key)
#@end
_help3() {
        help_render query "$1 $2 $3"
}

#@help _help4
# @internal arity-4 sibling of 'help' (four-word command paths, e.g. stage prerequisites exist add)
#@end
_help4() {
        help_render query "$1 $2 $3 $4"
}

#@help _help5
# @internal arity-5 sibling of 'help' (five-word command paths, e.g. stage action exists in loader)
#@end
_help5() {
        help_render query "$1 $2 $3 $4 $5"
}

#@help _help6
# @internal arity-6 sibling of 'help' (six-word command paths)
#@end
_help6() {
        help_render query "$1 $2 $3 $4 $5 $6"
}

#@help ___help_manual0
# @command help manual
# @summary Emit the complete manual as Pandoc Markdown, part by part: the title block, the prose building blocks from template/manual/, COMMANDS from the help corpus, ENVIRONMENT from the variable templates -- one truth per content kind (make man renders elebake.8 from it)
# @group   setup
# @returns Pandoc Markdown on stdout (no database required)
# @example elebake help manual | pandoc -s -f markdown -t man -o docs/elebake.8
# @example elebake help manual | lowdown -sTterm | less -R
# @see     help
# @see     help manual part
#@end
___help_manual0() {
        local part
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" help manual title"
        for part in name synopsis description sources; do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" help manual part $part"
        done
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" help manual commands"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" help manual environment"
        for part in files examples see-also authors; do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" help manual part $part"
        done
}

#@help _help_manual_title0
# @command help manual title
# @summary The Pandoc title block of the manual: name, section, author, today's date
# @group   setup
# @see     help manual
#@end
_help_manual_title0() {
        printf '%s\n' "% ELEBAKE(8) elebake | System Manager's Manual" "% Dr. Johannes Brügmann" "% $(date '+%B') $(date '+%e' | tr -d ' '), $(date '+%Y')" ""
}

#@help ___help_manual_part1
# @command help manual part <part>
# @summary One part of the manual page (template/manual/<part>.md): the part exists; then 'help manual part print'
# @group   setup
# @internal
# @see     help manual
#@end
___help_manual_part1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" help manual part exists '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" help manual part print '$1'"
}

#@help __help_manual_part_exists1
# @command help manual part exists <part>
# @summary The part is a name and template/manual/<part>.md exists: a comment line, else an error line
# @group   setup
# @internal
# @see     help manual
# @env     ELEBAKE_TEMPLATE_DIR  where template/manual lives
#@end
__help_manual_part_exists1() {
        if record_name_ok "$1" && test -f "$ELEBAKE_TEMPLATE_DIR/manual/$1.md"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'manual part $1 shipped'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'help manual part: template/manual/$1.md missing (or not a part name)'"
        fi
}

#@help _help_manual_part_print1
# @command help manual part print <part>
# @summary Text terminal: the part's markdown and a blank line
# @group   setup
# @internal
# @see     help manual
# @env     ELEBAKE_TEMPLATE_DIR  where template/manual lives
#@end
_help_manual_part_print1() {
        cat "$ELEBAKE_TEMPLATE_DIR/manual/$1.md"; printf '\n'
}

#@help _help_manual_commands0
# @command help manual commands
# @summary The COMMANDS section of the manual, generated from the help corpus and grouped as 'elebake help' groups it
# @group   setup
# @see     help manual
#@end
_help_manual_commands0() {
        printf '%s\n' "# COMMANDS" "" "Every command, grouped as \`elebake help\` groups it. \`elebake help <command>\` shows parameters, environment and examples." ""
        help_render manpage
}

#@help _help_manual_environment0
# @command help manual environment
# @summary The ENVIRONMENT section of the manual: one entry per shipped variable template, its @summary as the body -- the templates ARE the corpus (help env reads the same files)
# @group   setup
# @env     ELEBAKE_TEMPLATE_DIR  the shipped templates: variables under environment/
# @env     ELEBAKE_TERMINAL_INTERPRETER  named in the prose as the class default
# @env     ELEBAKE_INTERPRETER_<function>  named in the prose as the per-function pin
# @env     ELEBAKE_PROFILE_*  skipped: profiles are install lists, not settings
# @see     help manual
#@end
_help_manual_environment0() {
        local f v sm
        printf '%s\n' "# ENVIRONMENT" ""
        printf '%s\n' "All configuration lives in \`ELEBAKE_*\` variables, layered as \`.env/local\` (override, written by \`setenv\`), \`.env/default\` (the installed profile) and the shipped templates. Interpreter pins \`ELEBAKE_INTERPRETER_<function>\` decide per function whether emitted shell is displayed or executed: arity-specific before arity-agnostic before the class default (\`ELEBAKE_TERMINAL_INTERPRETER\`, default \`cat\`). Every variable answers \`elebake help env <VAR>\`." ""
        for f in "$ELEBAKE_TEMPLATE_DIR"/environment/ELEBAKE_*; do
                [ -f "$f" ] || continue
                v=$(basename "$f")
                case "$v" in ELEBAKE_PROFILE_*) continue ;; esac
                sm=$(sed -n 's/^#[ \t]*@summary[ \t]*//p' "$f" | head -n1)
                [ -n "$sm" ] || continue
                printf '%s\n' "**$v**" ":   $(printf '%s' "$sm" | sed 's/[<>|]/\\&/g')" ""
        done
}
