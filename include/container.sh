#!/bin/sh
#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Dr. Johannes Brügmann
# elebake container - the phase containers: which hosts which phase, and the
# catalog listings. The emitters live in render.sh.
#
# A container HOSTS phases (docs/DESIGN_STAGE_FOUNDATION.md §1). The loader
# is the C container (foundation.c); earlboot and elvbootd are sh containers
# whose catalogs live in the checkout under stand/efi/loader/local/<container>/
# (policy.sh: PHASES + when_*; measure.sh: measure_*/diagnose_*; action.sh:
# <name>_act). The user binds the SAME arsenal records (gates, claims,
# policies) to a container's phases; the emitters here compose the
# referenced functions with the bindings into ONE hardened script per
# artifact:
#
#   stage earlboot mk <stage>     hooks/earlboot          rc.d, SYSINIT + MOUNTED
#   stage elvbootd mk <stage>     hooks/hook.<phase>.sh   one per bound runtime phase
#                                 hooks/elvbootd          glue for STARTUP (rc.d)
#                                 hooks/elvboot.devd.conf  glue for MEDIA (devd)
#   stage earlboot|elvbootd install <stage>   copy into place (sudo)
#
# Generation-time throughout: the catalog is read from the worktree, the
# constants from the stage records, the functions are copied verbatim from
# the sources -- nothing is looked up at runtime that elebake already knew.

#@help ___stage_measure1
# @command stage measure <stage> [<container>]
# @summary List the measurements the containers' catalogs offer in the stage's checkout, with their descriptions: one 'stage measure list <container> <stage>' per container of ELEBAKE_CONTAINERS, or the one container given
# @group   foundation
# @env     ELEBAKE_CONTAINERS  the containers and their order
# @example elebake stage measure daily-v1
# @see     stage action
# @see     stage when
# @see     stage measure list earlboot
#@end
___stage_measure1() {
        local c=""
        for c in $ELEBAKE_CONTAINERS; do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage measure list '$c' '$1'"
        done
}

#@help __stage_measure2
# @internal 2-arg sibling of 'stage measure': the one container given -- rewrites to 'stage measure list <container> <stage>'
#@end
__stage_measure2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage measure list '$2' '$1'"
}

#@help __stage_measure_list2
# @command stage measure list <container> <stage>
# @summary The total fallback behind the container-specific listings (dispatch binds the longer name): a container without its own 'stage measure list <container>' rewrites to an error line
# @group   foundation
# @internal
# @see     stage measure
# @env     ELEBAKE_CONTAINERS  the containers a catalog can be asked for
#@end
__stage_measure_list2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage measure list: no anchor for container $1 (ELEBAKE_CONTAINERS names it, elebake has no stage measure list $1)'"
}

#@help __stage_measure_list_loader1
# @command stage measure list loader <stage>
# @summary The stage's checkout is there: rewrite to the 2-arg form with its local/ directory, else an error line
# @group   foundation
# @internal
# @see     stage measure
#@end
__stage_measure_list_loader1() {
        local loc="$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local"
        if test -d "$loc"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage measure list loader '$1' '$loc'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage measure list loader: stage $1 has no worktree (stage checkout $1 <ref> first)'"
        fi
}

#@help ___stage_measure_list_loader2
# @internal 2-arg sibling of 'stage measure list loader': per catalog file of loader (measurement.h) a title and one 'catalog doc' per name the source declares
#@end
___stage_measure_list_loader2() {
        local nm=""
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" catalog title '$1' loader measure 'measurement.h'"
        for nm in $(sed -n 's/struct[[:space:]]measurement[[:space:]]*\([a-z_0-9]*\)(.*/\1/p' "$2/measurement.h" 2>/dev/null); do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" catalog doc '$2/measurement.h' '$nm'"
        done
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" catalog title '$1' loader diagnose 'measurement.h'"
        for nm in $(sed -n 's/void[[:space:]]*\([a-z_0-9]*\)(.*/\1/p' "$2/measurement.h" 2>/dev/null); do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" catalog doc '$2/measurement.h' '$nm'"
        done
}

#@help __stage_measure_list_earlboot1
# @command stage measure list earlboot <stage>
# @summary The stage's checkout is there: rewrite to the 2-arg form with its local/ directory, else an error line
# @group   foundation
# @internal
# @see     stage measure
#@end
__stage_measure_list_earlboot1() {
        local loc="$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local"
        if test -d "$loc"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage measure list earlboot '$1' '$loc'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage measure list earlboot: stage $1 has no worktree (stage checkout $1 <ref> first)'"
        fi
}

#@help ___stage_measure_list_earlboot2
# @internal 2-arg sibling of 'stage measure list earlboot': per catalog file of earlboot (earlboot/measure.sh) a title and one 'catalog doc' per name the source declares
#@end
___stage_measure_list_earlboot2() {
        local nm=""
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" catalog title '$1' earlboot measure 'earlboot/measure.sh'"
        for nm in $(sed -n 's/^\([a-z_0-9]*\)().*/\1/p' "$2/earlboot/measure.sh" 2>/dev/null); do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" catalog doc '$2/earlboot/measure.sh' '$nm'"
        done
}

#@help __stage_measure_list_elvbootd1
# @command stage measure list elvbootd <stage>
# @summary The stage's checkout is there: rewrite to the 2-arg form with its local/ directory, else an error line
# @group   foundation
# @internal
# @see     stage measure
#@end
__stage_measure_list_elvbootd1() {
        local loc="$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local"
        if test -d "$loc"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage measure list elvbootd '$1' '$loc'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage measure list elvbootd: stage $1 has no worktree (stage checkout $1 <ref> first)'"
        fi
}

#@help ___stage_measure_list_elvbootd2
# @internal 2-arg sibling of 'stage measure list elvbootd': per catalog file of elvbootd (elvbootd/measure.sh, earlboot/measure.sh) a title and one 'catalog doc' per name the source declares -- elvbootd inherits earlboot's sh catalog, a second section
#@end
___stage_measure_list_elvbootd2() {
        local nm=""
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" catalog title '$1' elvbootd measure 'elvbootd/measure.sh'"
        for nm in $(sed -n 's/^\([a-z_0-9]*\)().*/\1/p' "$2/elvbootd/measure.sh" 2>/dev/null); do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" catalog doc '$2/elvbootd/measure.sh' '$nm'"
        done
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" catalog title '$1' elvbootd measure 'earlboot/measure.sh'"
        for nm in $(sed -n 's/^\([a-z_0-9]*\)().*/\1/p' "$2/earlboot/measure.sh" 2>/dev/null); do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" catalog doc '$2/earlboot/measure.sh' '$nm'"
        done
}

#@help ___stage_action1
# @command stage action <stage> [<container>]
# @summary List the actions the containers' catalogs offer in the stage's checkout, with their descriptions: one 'stage action list <container> <stage>' per container of ELEBAKE_CONTAINERS, or the one container given
# @group   foundation
# @env     ELEBAKE_CONTAINERS  the containers and their order
# @example elebake stage action daily-v1
# @see     stage measure
# @see     stage when
# @see     stage action list earlboot
#@end
___stage_action1() {
        local c=""
        for c in $ELEBAKE_CONTAINERS; do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage action list '$c' '$1'"
        done
}

#@help __stage_action2
# @internal 2-arg sibling of 'stage action': the one container given -- rewrites to 'stage action list <container> <stage>'
#@end
__stage_action2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage action list '$2' '$1'"
}

#@help __stage_action_list2
# @command stage action list <container> <stage>
# @summary The total fallback behind the container-specific listings (dispatch binds the longer name): a container without its own 'stage action list <container>' rewrites to an error line
# @group   foundation
# @internal
# @see     stage action
# @env     ELEBAKE_CONTAINERS  the containers a catalog can be asked for
#@end
__stage_action_list2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage action list: no anchor for container $1 (ELEBAKE_CONTAINERS names it, elebake has no stage action list $1)'"
}

#@help __stage_action_list_loader1
# @command stage action list loader <stage>
# @summary The stage's checkout is there: rewrite to the 2-arg form with its local/ directory, else an error line
# @group   foundation
# @internal
# @see     stage action
#@end
__stage_action_list_loader1() {
        local loc="$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local"
        if test -d "$loc"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage action list loader '$1' '$loc'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage action list loader: stage $1 has no worktree (stage checkout $1 <ref> first)'"
        fi
}

#@help ___stage_action_list_loader2
# @internal 2-arg sibling of 'stage action list loader': per catalog file of loader (action.h) a title and one 'catalog doc' per name the source declares
#@end
___stage_action_list_loader2() {
        local nm=""
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" catalog title '$1' loader action 'action.h'"
        for nm in $(sed -n 's/extern[[:space:]]const[[:space:]]struct[[:space:]]action[[:space:]]*\([a-z_0-9]*\);.*/\1/p' "$2/action.h" 2>/dev/null); do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" catalog doc '$2/action.h' '$nm'"
        done
}

#@help __stage_action_list_earlboot1
# @command stage action list earlboot <stage>
# @summary The stage's checkout is there: rewrite to the 2-arg form with its local/ directory, else an error line
# @group   foundation
# @internal
# @see     stage action
#@end
__stage_action_list_earlboot1() {
        local loc="$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local"
        if test -d "$loc"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage action list earlboot '$1' '$loc'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage action list earlboot: stage $1 has no worktree (stage checkout $1 <ref> first)'"
        fi
}

#@help ___stage_action_list_earlboot2
# @internal 2-arg sibling of 'stage action list earlboot': per catalog file of earlboot (earlboot/action.sh) a title and one 'catalog doc' per name the source declares
#@end
___stage_action_list_earlboot2() {
        local nm=""
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" catalog title '$1' earlboot action 'earlboot/action.sh'"
        for nm in $(sed -n 's/^\([a-z_0-9]*\)().*/\1/p' "$2/earlboot/action.sh" 2>/dev/null); do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" catalog doc '$2/earlboot/action.sh' '$nm'"
        done
}

#@help __stage_action_list_elvbootd1
# @command stage action list elvbootd <stage>
# @summary The stage's checkout is there: rewrite to the 2-arg form with its local/ directory, else an error line
# @group   foundation
# @internal
# @see     stage action
#@end
__stage_action_list_elvbootd1() {
        local loc="$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local"
        if test -d "$loc"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage action list elvbootd '$1' '$loc'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage action list elvbootd: stage $1 has no worktree (stage checkout $1 <ref> first)'"
        fi
}

#@help ___stage_action_list_elvbootd2
# @internal 2-arg sibling of 'stage action list elvbootd': per catalog file of elvbootd (elvbootd/action.sh, earlboot/action.sh) a title and one 'catalog doc' per name the source declares -- elvbootd inherits earlboot's sh catalog, a second section
#@end
___stage_action_list_elvbootd2() {
        local nm=""
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" catalog title '$1' elvbootd action 'elvbootd/action.sh'"
        for nm in $(sed -n 's/^\([a-z_0-9]*\)().*/\1/p' "$2/elvbootd/action.sh" 2>/dev/null); do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" catalog doc '$2/elvbootd/action.sh' '$nm'"
        done
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" catalog title '$1' elvbootd action 'earlboot/action.sh'"
        for nm in $(sed -n 's/^\([a-z_0-9]*\)().*/\1/p' "$2/earlboot/action.sh" 2>/dev/null); do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" catalog doc '$2/earlboot/action.sh' '$nm'"
        done
}

#@help ___stage_when1
# @command stage when <stage> [<container>]
# @summary List the firing predicates the containers' catalogs offer in the stage's checkout, with their descriptions: one 'stage when list <container> <stage>' per container of ELEBAKE_CONTAINERS, or the one container given
# @group   foundation
# @env     ELEBAKE_CONTAINERS  the containers and their order
# @example elebake stage when daily-v1
# @see     stage measure
# @see     stage action
# @see     stage when list earlboot
#@end
___stage_when1() {
        local c=""
        for c in $ELEBAKE_CONTAINERS; do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage when list '$c' '$1'"
        done
}

#@help __stage_when2
# @internal 2-arg sibling of 'stage when': the one container given -- rewrites to 'stage when list <container> <stage>'
#@end
__stage_when2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage when list '$2' '$1'"
}

#@help __stage_when_list2
# @command stage when list <container> <stage>
# @summary The total fallback behind the container-specific listings (dispatch binds the longer name): a container without its own 'stage when list <container>' rewrites to an error line
# @group   foundation
# @internal
# @see     stage when
# @env     ELEBAKE_CONTAINERS  the containers a catalog can be asked for
#@end
__stage_when_list2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage when list: no anchor for container $1 (ELEBAKE_CONTAINERS names it, elebake has no stage when list $1)'"
}

#@help __stage_when_list_loader1
# @command stage when list loader <stage>
# @summary The stage's checkout is there: rewrite to the 2-arg form with its local/ directory, else an error line
# @group   foundation
# @internal
# @see     stage when
#@end
__stage_when_list_loader1() {
        local loc="$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local"
        if test -d "$loc"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage when list loader '$1' '$loc'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage when list loader: stage $1 has no worktree (stage checkout $1 <ref> first)'"
        fi
}

#@help ___stage_when_list_loader2
# @internal 2-arg sibling of 'stage when list loader': per catalog file of loader (policy.h) a title and one 'catalog doc' per name the source declares
#@end
___stage_when_list_loader2() {
        local nm=""
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" catalog title '$1' loader when 'policy.h'"
        for nm in $(sed -n 's/^bool[[:space:]]*\([a-z_0-9]*\)(.*/\1/p' "$2/policy.h" 2>/dev/null); do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" catalog doc '$2/policy.h' '$nm'"
        done
}

#@help __stage_when_list_earlboot1
# @command stage when list earlboot <stage>
# @summary The stage's checkout is there: rewrite to the 2-arg form with its local/ directory, else an error line
# @group   foundation
# @internal
# @see     stage when
#@end
__stage_when_list_earlboot1() {
        local loc="$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local"
        if test -d "$loc"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage when list earlboot '$1' '$loc'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage when list earlboot: stage $1 has no worktree (stage checkout $1 <ref> first)'"
        fi
}

#@help ___stage_when_list_earlboot2
# @internal 2-arg sibling of 'stage when list earlboot': per catalog file of earlboot (earlboot/policy.sh) a title and one 'catalog doc' per name the source declares
#@end
___stage_when_list_earlboot2() {
        local nm=""
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" catalog title '$1' earlboot when 'earlboot/policy.sh'"
        for nm in $(sed -n 's/^\([a-z_0-9]*\)().*/\1/p' "$2/earlboot/policy.sh" 2>/dev/null); do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" catalog doc '$2/earlboot/policy.sh' '$nm'"
        done
}

#@help __stage_when_list_elvbootd1
# @command stage when list elvbootd <stage>
# @summary The stage's checkout is there: rewrite to the 2-arg form with its local/ directory, else an error line
# @group   foundation
# @internal
# @see     stage when
#@end
__stage_when_list_elvbootd1() {
        local loc="$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local"
        if test -d "$loc"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage when list elvbootd '$1' '$loc'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage when list elvbootd: stage $1 has no worktree (stage checkout $1 <ref> first)'"
        fi
}

#@help ___stage_when_list_elvbootd2
# @internal 2-arg sibling of 'stage when list elvbootd': per catalog file of elvbootd (elvbootd/policy.sh) a title and one 'catalog doc' per name the source declares
#@end
___stage_when_list_elvbootd2() {
        local nm=""
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" catalog title '$1' elvbootd when 'elvbootd/policy.sh'"
        for nm in $(sed -n 's/^\([a-z_0-9]*\)().*/\1/p' "$2/elvbootd/policy.sh" 2>/dev/null); do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" catalog doc '$2/elvbootd/policy.sh' '$nm'"
        done
}

#@help _catalog_title4
# @command catalog title <stage> <container> <kind> <file>
# @summary The heading of one catalog section: kind, stage with its checkout ref, container, and the file of this checkout the entries come from
# @group   foundation
# @internal
# @see     stage measure
#@end
_catalog_title4() {
        local ref=""
        ref=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/checkout" 2>/dev/null)
        printf '#\n# %s catalog of stage %s (checkout: %s), container %s: %s\n' "$3" "$1" "${ref:--}" "$2" "$4"
}

#@help _catalog_doc2
# @command catalog doc <file> <name>
# @summary Print the entry's name and the description its source carries (template/awk/catalog-doc.awk over the catalog file); an entry without one says so
# @env     ELEBAKE_TEMPLATE_DIR  the template directory (awk programs, tables)
# @group   foundation
# @param   file  the catalog file, absolute (a header for the loader, a sh catalog for earlboot/elvbootd)
# @see     stage measure
#@end
_catalog_doc2() {
        printf '%s\n' "awk -v n='$2' -f '$ELEBAKE_TEMPLATE_DIR/awk/catalog-doc.awk' '$1'"
}

#@help ___stage_dump_hooks1
# @internal dump block (cat-pinned): hooks are never replayed -- one comment line says so
#@end
___stage_dump_hooks1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'hooks of $1 are generated: stage earlboot mk / stage elvbootd mk after restore'"
}

