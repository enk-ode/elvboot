#!/bin/sh
#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Dr. Johannes Brügmann
#
# workflow.sh -- the recurring sequences of commands, as text to read.
#
# A workflow is a file template/workflow/<name>.md: a first line '# <title>',
# then the commands in the order they are run, with the comments that say
# why each one is there and what to expect. Nothing here runs anything --
# the family prints (pin cat): 'workflow' lists the names with their titles,
# 'workflow show <name>' prints the file. The user runs the commands
# himself, stage by stage, and reads the checks between them. Knowledge in
# tables (JB): the sequences that were typed from memory in the walkthroughs
# of September 2026 -- rebuild, pcr-learn, kenv-change, baseline-relearn,
# inventory-drop, policy-change, tpm-seal, halt-relearn, restore -- live here, once.
#

#@help ___workflow0
# @command workflow
# @summary List the workflows: one line per file of template/workflow, name and title (the file's first line); the same as 'workflow list'
# @group   workflow
# @env     ELEBAKE_TEMPLATE_DIR  the template directory (workflow/)
# @example elebake workflow
# @see     workflow show
#@end
___workflow0() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" workflow list"
}

#@help ___workflow_list0
# @command workflow list
# @summary List the workflows: per file of template/workflow one 'workflow line <name>'; none is a comment line
# @group   workflow
# @env     ELEBAKE_TEMPLATE_DIR  the template directory (workflow/)
# @example elebake workflow list
# @see     workflow show
#@end
___workflow_list0() {
        local f="" lines=0
        for f in "$ELEBAKE_TEMPLATE_DIR"/workflow/*.md; do
                [ -f "$f" ] || continue
                f=${f##*/}
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" workflow line '${f%.md}'"
                lines=$((lines + 1))
        done
        test "$lines" -gt 0 || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'no workflows in $ELEBAKE_TEMPLATE_DIR/workflow'"
}

#@help _workflow_line1
# @command workflow line <name>
# @summary Text terminal: '<name>  <title>' -- the title is the first line of the file without its '# '
# @group   workflow
# @internal
# @env     ELEBAKE_TEMPLATE_DIR  the template directory (workflow/)
# @see     workflow list
#@end
_workflow_line1() {
        printf '%-18s %s\n' "$1" "$(sed -n '1s/^# *//p' "$ELEBAKE_TEMPLATE_DIR/workflow/$1.md" 2>/dev/null)"
}

#@help ___workflow_show1
# @command workflow show <name>
# @summary Print a workflow: the file exists (workflow exists), then its text as it is (workflow render) -- commands and the comments between them, to read and to type after
# @group   workflow
# @env     ELEBAKE_TEMPLATE_DIR  the template directory (workflow/)
# @example elebake workflow show rebuild
# @see     workflow list
#@end
___workflow_show1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" workflow exists '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" workflow render '$1'"
}

#@help __workflow_exists1
# @command workflow exists <name>
# @summary template/workflow/<name>.md is there: a comment line, else an error line naming 'workflow list'
# @group   workflow
# @internal
# @env     ELEBAKE_TEMPLATE_DIR  the template directory (workflow/)
# @see     workflow show
#@end
__workflow_exists1() {
        if test -f "$ELEBAKE_TEMPLATE_DIR/workflow/$1.md"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'workflow $1'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'workflow show: no such workflow $1 (workflow list)'"
        fi
}

#@help _workflow_render1
# @command workflow render <name>
# @summary Text terminal: the workflow file as it is
# @group   workflow
# @internal
# @env     ELEBAKE_TEMPLATE_DIR  the template directory (workflow/)
# @see     workflow show
#@end
_workflow_render1() {
        cat "$ELEBAKE_TEMPLATE_DIR/workflow/$1.md"
}
