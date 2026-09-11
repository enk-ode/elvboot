#!/bin/sh
#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Dr. Johannes Brügmann
# elebake ensure - the prerequisites of a policy in a container, top down.
#
# 'stage phase policy add <stage> <phase> <policy>' is two lines: ensure the
# policy's prerequisites, then append the binding.
#
# INVARIANT (the arsenal keeps it at add/drop time): a record never dangles
# and is never empty. policy add writes the gate line; gate add takes the
# first claim; gate claim add, policy trigger add, claim add and
# expectation add name only records that exist; a drop is refused while a
# record is referenced. So the chain reads records without looking, and
# consists of enumerations and leaves only:
#
#   stage policy ensure  <stage> <container> <policy>    every record line
#       '<kind> <name>' is one 'stage <kind> ensure'
#   stage gate ensure    <stage> <container> <gate>      every claim of the
#       gate: its measurement and diagnose in the container's catalog, its
#       expectation's type word dispatched (lifting)
#   stage trigger ensure <stage> <container> <trigger>   its when and action
#       in the container's catalog
#
# The leaves live in the checkout of the stage:
#
#   stage <kind> exists in <container> <stage> <name>          2: the
#       checkout is there -> rewrite to 3 with its local/ directory
#   stage <kind> exists in <container> <stage> <name> <local>  3: one grep
#
# Every function is one step and holds at most ONE level of control
# structure (nesting level 1). Its class follows its output: one line in,
# one line out (an if/else that rewrites or errs) is a combinator (__); many
# lines (a while that enumerates) is a batch (___). Nothing is ever empty:
# where there is nothing to ensure, the line is 'comment <why>' (the
# engine's comment terminal), and an enumeration counts its lines and says
# so when it produced none.
#
# Arguments are ordered by hierarchy, <stage> <container> ... <smallest>.
# The container stands first only where an override is meant: 'stage phase
# policy ensure <container> ...' binds the container's own anchor through
# dispatch (the longer name wins), the generic name behind it is a
# combinator rewriting to an error line. At the leaves the container is
# part of the name ('exists in earlboot'). A partial verb is lifted to a
# total one the same way: the type word of an expectation record dispatches
# 'stage <type> ensure' -- macro to the loader's macro records, byte, sha256
# and string to a comment line.
#
# Every terminal prints one command; the sh pin runs it, the cat pin shows
# it. KEEP_GOING=0 throughout: the first missing prerequisite stops the chain.
#
# Records (the tables the batches enumerate):
#   foundation/policies/<policy>        lines 'gate <gate>', 'trigger <trigger>'
#   foundation/gates/<gate>/claims      one claim per line
#   foundation/claims/<claim>           'measurement diagnose publish expectation'
#   foundation/expectations/<exp>       'type label value'
#   foundation/triggers/<trigger>       'when action'
#   foundation/macros/<stem>            'type label [defined [else]]'

#@help ___stage_phase_policy_add3
# @command stage phase policy add <stage> <phase> <policy> [<position>]
# @summary Bind a policy into a phase of the stage: ensure its prerequisites in the container that hosts the phase, then append it to the phase's policy list (a position inserts instead)
# @group   foundation
# @example elebake stage phase policy add daily-v1 SYSINIT fish-0
# @see     stage phase policy ensure
# @see     stage phase policy drop
#@end
___stage_phase_policy_add3() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage phase exists '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage phase policy ensure '$1' '$2' '$3'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage phase policy append '$1' '$2' '$3'"
}

#@help ___stage_phase_policy_add4
# @internal 4-arg sibling of 'stage phase policy add': insert at a 1-based
# position among the phase's policy lines
#@end
___stage_phase_policy_add4() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage phase exists '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage phase policy ensure '$1' '$2' '$3'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage phase policy append '$1' '$2' '$3' '$4'"
}

#@help ___stage_phase_policy_ensure3
# @command stage phase policy ensure <stage> <phase> <policy>
# @summary Unroll the containers: one 'stage phase policy ensure <container> <stage> <phase> <policy>' per container of ELEBAKE_CONTAINERS; the container that hosts the phase ensures the policy, the others say so in a comment line
# @group   foundation
# @env     ELEBAKE_CONTAINERS  the containers, in this order
# @example elebake stage phase policy ensure daily-v1 SYSINIT fish-0
# @see     stage phase policy ensure loader
# @see     stage phase policy ensure earlboot
# @see     stage phase policy ensure elvbootd
#@end
___stage_phase_policy_ensure3() {
        local c=""
        for c in $ELEBAKE_CONTAINERS; do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage phase policy ensure '$c' '$1' '$2' '$3'"
        done
}

#@help __stage_phase_policy_ensure4
# @internal arity-4 sibling of 'stage phase policy ensure' (stage phase policy ensure <container> <stage> <phase> <policy>): The fallback behind the container-specific forms (dispatch binds the longer name when it exists): a container of ELEBAKE_CONTAINERS without its own anchor rewrites to an error line, not to silence
#@end
__stage_phase_policy_ensure4() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage phase policy ensure: no anchor for container $1 (ELEBAKE_CONTAINERS names it, elebake has no stage phase policy ensure $1)'"
}

#@help __stage_phase_policy_ensure_loader3
# @command stage phase policy ensure loader <stage> <phase> <policy>
# @summary The stage's checkout is there: rewrite to the 4-arg form with its local/ directory, else an error line
# @group   foundation
# @internal
# @see     stage policy ensure
#@end
__stage_phase_policy_ensure_loader3() {
        local loc="$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local"
        if test -d "$loc"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage phase policy ensure loader '$1' '$2' '$3' '$loc'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage phase policy ensure loader: stage $1 has no worktree (stage checkout $1 <ref> first)'"
        fi
}

#@help __stage_phase_policy_ensure_loader4
# @internal 4-arg sibling of 'stage phase policy ensure loader': a combinator --
# loader hosts the phase when 'enum phase' of policy.h in the checkout lists it: then
# 'stage policy ensure <stage> loader <policy>', else a comment line (nothing to
# ensure here)
#@end
__stage_phase_policy_ensure_loader4() {
        if sed -n '/enum phase {/,/};/p' "$4/policy.h" 2>/dev/null | grep -o 'PHASE_[A-Z_]*' | grep -qx "$2"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage policy ensure '$1' loader '$3'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'loader does not host phase $2: nothing to ensure for policy $3 of stage $1'"
        fi
}

#@help __stage_phase_policy_ensure_earlboot3
# @command stage phase policy ensure earlboot <stage> <phase> <policy>
# @summary The stage's checkout is there: rewrite to the 4-arg form with its local/ directory, else an error line
# @group   foundation
# @internal
# @see     stage policy ensure
#@end
__stage_phase_policy_ensure_earlboot3() {
        local loc="$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local"
        if test -d "$loc"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage phase policy ensure earlboot '$1' '$2' '$3' '$loc'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage phase policy ensure earlboot: stage $1 has no worktree (stage checkout $1 <ref> first)'"
        fi
}

#@help __stage_phase_policy_ensure_earlboot4
# @internal 4-arg sibling of 'stage phase policy ensure earlboot': a combinator --
# earlboot hosts the phase when the PHASES= line of earlboot/policy.sh in the checkout lists it: then
# 'stage policy ensure <stage> earlboot <policy>', else a comment line (nothing to
# ensure here)
#@end
__stage_phase_policy_ensure_earlboot4() {
        if sed -n 's/^PHASES="\([A-Z_ ]*\)".*/\1/p' "$4/earlboot/policy.sh" 2>/dev/null | tr ' ' '\n' | grep -qx "$2"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage policy ensure '$1' earlboot '$3'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'earlboot does not host phase $2: nothing to ensure for policy $3 of stage $1'"
        fi
}

#@help __stage_phase_policy_ensure_elvbootd3
# @command stage phase policy ensure elvbootd <stage> <phase> <policy>
# @summary The stage's checkout is there: rewrite to the 4-arg form with its local/ directory, else an error line
# @group   foundation
# @internal
# @see     stage policy ensure
#@end
__stage_phase_policy_ensure_elvbootd3() {
        local loc="$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local"
        if test -d "$loc"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage phase policy ensure elvbootd '$1' '$2' '$3' '$loc'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage phase policy ensure elvbootd: stage $1 has no worktree (stage checkout $1 <ref> first)'"
        fi
}

#@help __stage_phase_policy_ensure_elvbootd4
# @internal 4-arg sibling of 'stage phase policy ensure elvbootd': a combinator --
# elvbootd hosts the phase when the PHASES= line of elvbootd/policy.sh in the checkout lists it: then
# 'stage policy ensure <stage> elvbootd <policy>', else a comment line (nothing to
# ensure here)
#@end
__stage_phase_policy_ensure_elvbootd4() {
        if sed -n 's/^PHASES="\([A-Z_ ]*\)".*/\1/p' "$4/elvbootd/policy.sh" 2>/dev/null | tr ' ' '\n' | grep -qx "$2"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage policy ensure '$1' elvbootd '$3'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'elvbootd does not host phase $2: nothing to ensure for policy $3 of stage $1'"
        fi
}

#@help ___stage_policy_ensure3
# @command stage policy ensure <stage> <container> <policy>
# @summary The policy's prerequisites in the container: every line '<kind> <name>' of the record ('gate <gate>', 'trigger <trigger>') is one 'stage <kind> ensure <stage> <container> <name>'
# @group   foundation
# @example elebake stage policy ensure daily-v1 earlboot fish-0
# @see     stage gate ensure
# @see     stage trigger ensure
#@end
___stage_policy_ensure3() {
        local kind="" name="" lines=0
        while read -r kind name; do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage $kind ensure '$1' '$2' '$name'"
                lines=$((lines + 1))
        done 2>/dev/null < "$ELEBAKE_BASE/foundation/policies/$3"
        test "$lines" -gt 0 || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'policy $3 references nothing: no prerequisites in $2 of stage $1'"
}

#@help ___stage_gate_ensure3
# @command stage gate ensure <stage> <container> <gate>
# @summary The gate's prerequisites in the container, per claim the gate lists: the claim's measurement exists in the container's catalog of the stage's checkout, its diagnose likewise (or a comment when it has none), and its expectation's type word dispatches 'stage <type> ensure' (lifting: macro to the loader's macro records, byte and string to a comment)
# @group   foundation
# @internal
# @example elebake stage gate ensure daily-v1 earlboot fish_0
# @see     stage claim diagnose ensure
# @see     stage macro ensure
#@end
___stage_gate_ensure3() {
        local claim="" measurement="" diagnose="" publish="" expectation="" type="" label="" value="" lines=0
        while read -r claim; do
                read -r measurement diagnose publish expectation 2>/dev/null < "$ELEBAKE_BASE/foundation/claims/$claim"
                read -r type label value 2>/dev/null < "$ELEBAKE_BASE/foundation/expectations/$expectation"
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage measurement exists in '$2' '$1' '$measurement'"
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage claim diagnose ensure '$1' '$2' '$diagnose'"
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage $type ensure '$1' '$2' '$value'"
                lines=$((lines + 1))
        done 2>/dev/null < "$ELEBAKE_BASE/foundation/gates/$3/claims"
        test "$lines" -gt 0 || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'gate $3 lists no claims: no prerequisites in $2 of stage $1'"
}

#@help __stage_claim_diagnose_ensure3
# @command stage claim diagnose ensure <stage> <container> <diagnose>
# @summary A claim's diagnose is optional ('-' in the record): a diagnose exists in the container's catalog, '-' lifts to a comment
# @group   foundation
# @internal
# @see     comment
#@end
__stage_claim_diagnose_ensure3() {
        if test "$3" != -; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage diagnose exists in '$2' '$1' '$3'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'claim without diagnose: nothing to ensure in $2 of stage $1'"
        fi
}

#@help ___stage_trigger_ensure3
# @command stage trigger ensure <stage> <container> <trigger>
# @summary The trigger's prerequisites in the container: every leaf of its when and of its action exists in the container's catalog of the stage's checkout
# @group   foundation
# @internal
# @example elebake stage trigger ensure daily-v1 earlboot react-halt
# @see     stage when exists in earlboot
# @see     stage action exists in earlboot
#@end
___stage_trigger_ensure3() {
        local when="" action="" w="" a=""
        read -r when action 2>/dev/null < "$ELEBAKE_BASE/foundation/triggers/$3"
        for w in $(fnd_expr_render when leaves "$when"); do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage when exists in '$2' '$1' '$w'"
        done
        for a in $(fnd_expr_render action leaves "$action"); do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage action exists in '$2' '$1' '$a'"
        done
}

#@help __stage_macro_ensure3
# @command stage macro ensure <stage> <container> <macro>
# @summary The macro's prerequisites in the container: a macro record of the arsenal defines it for this container ('macro exists in <container>'; only the loader has compiled baselines). stage foundation check adds the stage's baseline here
# @group   foundation
# @internal
# @example elebake stage macro ensure daily-v1 loader BOARD_EXPECTED
# @see     macro exists in
#@end
__stage_macro_ensure3() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" macro exists in '$2' '$3'"
}

#@help __stage_byte_ensure3
# @command stage byte ensure <stage> <container> <value>
# @summary A byte expectation has no prerequisites: rewrites to a comment line saying so. It exists so that the record's type word dispatches totally (lifting)
# @group   foundation
# @internal
# @see     stage gate ensure
#@end
__stage_byte_ensure3() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'byte expectation $3 in $2 of stage $1: no prerequisites'"
}

#@help __stage_sha256_ensure3
# @command stage sha256 ensure <stage> <container> <value>
# @summary A sha256 expectation has no prerequisites: rewrites to a comment line saying so. It exists so that the record's type word dispatches totally (lifting)
# @group   foundation
# @internal
# @see     stage gate ensure
#@end
__stage_sha256_ensure3() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'sha256 expectation $3 in $2 of stage $1: no prerequisites'"
}

#@help __stage_string_ensure3
# @command stage string ensure <stage> <container> <value>
# @summary A string expectation is a container type (the loader compares BYTE and SHA256 only): in earlboot or elvbootd a comment line (no prerequisites), in the loader an error line. It exists so that the record's type word dispatches totally (lifting)
# @group   foundation
# @internal
# @see     stage gate ensure
#@end
__stage_string_ensure3() {
        if test "$2" != loader; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'string expectation $3 in $2 of stage $1: no prerequisites'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage $1: a string expectation ($3) cannot be bound in the loader -- it compares BYTE and SHA256 only; string expectations belong to earlboot and elvbootd policies'"
        fi
}

#@help __macro_exists_in2
# @command macro exists in <container> <macro>
# @summary The total fallback behind 'macro exists in loader' (dispatch binds the longer name): macro expectations are compiled baselines and exist only in the loader, so any other container rewrites to an error line
# @group   foundation
# @internal
# @see     macro exists in loader
#@end
__macro_exists_in2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'macro $2: macro expectations exist only in the loader (compiled baselines); $1 takes byte or string'"
}

#@help __macro_exists_in_loader1
# @command macro exists in loader <macro>
# @summary The loader takes macro expectations, and expectation add saw to it that a macro record defines the macro: nothing left to ensure, a comment line
# @group   foundation
# @internal
# @see     macro exists in
#@end
__macro_exists_in_loader1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'macro $1: defined by a macro record (expectation add checked it)'"
}
#@help ___stage_foundation_check1
# @command stage foundation check <stage>
# @summary The stage exists; every bound policy has its prerequisites (stage phase policy ensure, per phase and policy); every baseline the bound policies demand is reported when missing (gate slots, macro expectations, and what the catalog names demand per template/tbl/baseline-demands.tbl); then the summary
# @group   foundation
# @example elebake stage foundation check daily-v1
# @see     stage bindings ensure
# @see     stage baselines report
# @see     stage foundation make
#@end
___stage_foundation_check1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage bindings ensure '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage baselines report '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage foundation summary '$1'"
}

#@help ___stage_bindings_ensure1
# @command stage bindings ensure <stage>
# @summary Every phase of the stage with a policy record: one 'stage phase ensure <stage> <phase>'; a stage without bindings says so in a note
# @group   foundation
# @internal
# @see     stage phase ensure
#@end
___stage_bindings_ensure1() {
        local f="" lines=0
        for f in "$ELEBAKE_BASE/stage/$1"/phases/*; do
                [ -f "$f" ] || continue
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage phase ensure '$1' '${f##*/}'"
                lines=$((lines + 1))
        done
        test "$lines" -gt 0 || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log 'foundation check: nothing bound yet (stage phase policy add)'"
}

#@help ___stage_phase_ensure2
# @command stage phase ensure <stage> <phase>
# @summary Every policy the phase record lists: one 'stage phase policy ensure <stage> <phase> <policy>'; an empty phase record says so in a comment
# @group   foundation
# @internal
# @see     stage phase policy ensure
#@end
___stage_phase_ensure2() {
        local p="" lines=0
        while read -r p; do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage phase policy ensure '$1' '$2' '$p'"
                lines=$((lines + 1))
        done 2>/dev/null < "$ELEBAKE_BASE/stage/$1/phases/$2"
        test "$lines" -gt 0 || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'phase $2 of stage $1 binds no policy'"
}

#@help ___stage_baselines_report1
# @command stage baselines report <stage>
# @summary Every phase of the stage with a policy record: one 'stage phase baselines report <stage> <phase>'; nothing bound is a comment
# @group   foundation
# @internal
# @see     stage phase baselines report
#@end
___stage_baselines_report1() {
        local f="" lines=0
        for f in "$ELEBAKE_BASE/stage/$1"/phases/*; do
                [ -f "$f" ] || continue
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage phase baselines report '$1' '${f##*/}'"
                lines=$((lines + 1))
        done
        test "$lines" -gt 0 || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'stage $1: no phase bound, nothing to provision'"
}

#@help ___stage_phase_baselines_report2
# @command stage phase baselines report <stage> <phase>
# @summary Every policy the phase lists: one 'stage policy baselines report <stage> <policy>'
# @group   foundation
# @internal
# @see     stage policy baselines report
#@end
___stage_phase_baselines_report2() {
        local p="" lines=0
        while read -r p; do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage policy baselines report '$1' '$p'"
                lines=$((lines + 1))
        done 2>/dev/null < "$ELEBAKE_BASE/stage/$1/phases/$2"
        test "$lines" -gt 0 || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'phase $2 of stage $1 binds no policy'"
}

#@help ___stage_policy_baselines_report2
# @command stage policy baselines report <stage> <policy>
# @summary Every line '<kind> <name>' of the policy record: one 'stage <kind> baselines report <stage> <name>' -- the gate (its slots and claims) and each trigger (its action)
# @group   foundation
# @internal
# @see     stage gate baselines report
# @see     stage trigger baselines report
#@end
___stage_policy_baselines_report2() {
        local kind="" name="" lines=0
        while read -r kind name; do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage $kind baselines report '$1' '$name'"
                lines=$((lines + 1))
        done 2>/dev/null < "$ELEBAKE_BASE/foundation/policies/$2"
        test "$lines" -gt 0 || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'policy $2 references nothing'"
}

#@help ___stage_gate_baselines_report2
# @command stage gate baselines report <stage> <gate>
# @summary The gate's two lock slots (secret, duress), then per claim 'stage claim baselines report'
# @group   foundation
# @internal
# @see     stage gate slot demand
# @see     stage claim baselines report
#@end
___stage_gate_baselines_report2() {
        local claim=""
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage gate slot demand '$1' '$2' secret"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage gate slot demand '$1' '$2' duress"
        while read -r claim; do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage claim baselines report '$1' '$claim'"
        done 2>/dev/null < "$ELEBAKE_BASE/foundation/gates/$2/claims"
}

#@help __stage_gate_slot_demand3
# @command stage gate slot demand <stage> <gate> <secret|duress>
# @summary The gate carries the slot: rewrite to 'stage slot demand <stage> <gate> <MACRO>' with the -D macro the slot names, else a comment line
# @group   foundation
# @internal
# @see     stage slot demand
#@end
__stage_gate_slot_demand3() {
        local macro; macro=$(sed -n 1p "$ELEBAKE_BASE/foundation/gates/$2/$3" 2>/dev/null)
        if test -n "$macro"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage slot demand '$1' '$2' '$3' '$macro'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'gate $2 has no $3 slot'"
        fi
}

#@help ___stage_trigger_baselines_report2
# @command stage trigger baselines report <stage> <trigger>
# @summary Every action the trigger names may demand a baseline: one 'stage demands <stage> <action>' per leaf of its action expression
# @group   foundation
# @internal
# @see     stage demands
#@end
___stage_trigger_baselines_report2() {
        local when="" action="" a=""
        read -r when action 2>/dev/null < "$ELEBAKE_BASE/foundation/triggers/$2"
        for a in $(fnd_expr_render action leaves "$action"); do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage demands '$1' '$a'"
        done
}

#@help ___stage_claim_baselines_report2
# @command stage claim baselines report <stage> <claim>
# @summary The claim's measurement may demand a baseline ('stage demands'), its expectation may name a macro ('stage expectation demands')
# @group   foundation
# @internal
# @see     stage demands
# @see     stage expectation demands
#@end
___stage_claim_baselines_report2() {
        local measurement="" diagnose="" publish="" expectation=""
        read -r measurement diagnose publish expectation 2>/dev/null < "$ELEBAKE_BASE/foundation/claims/$2"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage demands '$1' '$measurement'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage expectation demands '$1' '$expectation'"
}

#@help ___stage_demands2
# @command stage demands <stage> <catalog-name>
# @summary The baselines a catalog name demands, per row '<name> <MACRO>' of template/tbl/baseline-demands.tbl: one 'stage baseline demand <stage> <name> <MACRO>'; a name without a row demands none (a comment)
# @env     ELEBAKE_TEMPLATE_DIR  the template directory (awk programs, tables)
# @group   foundation
# @internal
# @see     stage baseline demand
#@end
___stage_demands2() {
        local name="" macro="" lines=0
        while read -r name macro; do
                [ "$name" = "$2" ] || continue
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage baseline demand '$1' '$2' '$macro'"
                lines=$((lines + 1))
        done 2>/dev/null < "$ELEBAKE_TEMPLATE_DIR/tbl/baseline-demands.tbl"
        test "$lines" -gt 0 || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment '$2 demands no baseline'"
}

#@help __stage_expectation_demands2
# @command stage expectation demands <stage> <expectation>
# @summary The record's type word dispatches: 'stage <type> demands <stage> <value>' -- macro demands the baseline of the macro record that defines it, byte, sha256 and string demand none (lifting)
# @group   foundation
# @internal
# @see     stage macro demands
#@end
__stage_expectation_demands2() {
        local type="" label="" value=""
        read -r type label value 2>/dev/null < "$ELEBAKE_BASE/foundation/expectations/$2"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage $type demands '$1' '$value'"
}

#@help __stage_macro_demands2
# @command stage macro demands <stage> <MACRO>
# @summary The macro record that defines the macro (template/awk/macro-defines.awk -v stem=1 prints its stem) names the baseline LOADER_TRUST_<stem>: rewrite to 'stage macro demand', else an error line
# @env     ELEBAKE_TEMPLATE_DIR  the template directory (awk programs, tables)
# @group   foundation
# @internal
# @see     stage macro demand
#@end
__stage_macro_demands2() {
        local stem; stem=$(awk -v want="$2" -v stem=1 -f "$ELEBAKE_TEMPLATE_DIR/awk/macro-defines.awk" "$ELEBAKE_BASE"/foundation/macros/* 2>/dev/null)
        if test -n "$stem"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage macro demand '$1' '$stem' 'LOADER_TRUST_$stem'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage macro demands: no macro record defines $2 (macro add first)'"
        fi
}

#@help __stage_byte_demands2
# @command stage byte demands <stage> <value>
# @summary A byte expectation demands no baseline: a comment line (lifting)
# @group   foundation
# @internal
# @see     stage expectation demands
#@end
__stage_byte_demands2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'byte expectation $2: no baseline demanded'"
}

#@help __stage_sha256_demands2
# @command stage sha256 demands <stage> <value>
# @summary A sha256 expectation demands no baseline: a comment line (lifting)
# @group   foundation
# @internal
# @see     stage expectation demands
#@end
__stage_sha256_demands2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'sha256 expectation $2: no baseline demanded'"
}

#@help __stage_string_demands2
# @command stage string demands <stage> <value>
# @summary A string expectation demands no baseline: a comment line (lifting)
# @group   foundation
# @internal
# @see     stage expectation demands
#@end
__stage_string_demands2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'string expectation $2: no baseline demanded'"
}

#@help __stage_slot_demand4
# @command stage slot demand <stage> <gate> <secret|duress> <MACRO>
# @summary The slot's -D macro has a baseline in the stage (a baseline record or a CFLAGS line of site.mk): provisioned, else no baseline -- the lock is empty, unlock_act reports and continues (both as report lines)
# @group   foundation
# @internal
# @see     stage baseline add
#@end
__stage_slot_demand4() {
        if test -f "$ELEBAKE_BASE/stage/$1/baselines/$4" || grep -qs "^CFLAGS+=[[:space:]]*-D$4[=[:space:]]" "$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local/site.mk"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log 'gate $2: $3 slot $4 provisioned'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log 'gate $2: $3 slot $4 has no baseline -- the lock is empty, unlock_act reports and continues (stage baseline add $1 $4 string <sha256 hex>)'"
        fi
}

#@help __stage_macro_demand3
# @command stage macro demand <stage> <MACRO> <BASELINE>
# @summary The macro's baseline is in the stage (a baseline record or a CFLAGS line of site.mk): a comment, else a note -- its claims skip at boot
# @group   foundation
# @internal
# @see     stage baseline add
#@end
__stage_macro_demand3() {
        if test -f "$ELEBAKE_BASE/stage/$1/baselines/$3" || grep -qs "^CFLAGS+=[[:space:]]*-D$3[=[:space:]]" "$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local/site.mk"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log 'macro $2: $3 provisioned'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log 'macro $2: $3 has no value yet -- its claims skip at boot (stage baseline add|learn $1 $3 ..., or stage site mk for board, keys, marker, origin and the disks)'"
        fi
}

#@help __stage_baseline_demand3
# @command stage baseline demand <stage> <who> <MACRO>
# @summary The demanded baseline is in the stage (a baseline record or a CFLAGS line of site.mk): a comment, else a note -- the code has no default, what it guards is absent at boot
# @group   foundation
# @internal
# @see     stage baseline add
#@end
__stage_baseline_demand3() {
        if test -f "$ELEBAKE_BASE/stage/$1/baselines/$3" || grep -qs "^CFLAGS+=[[:space:]]*-D$3[=[:space:]]" "$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local/site.mk"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log '$2: $3 provisioned'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log '$2 needs $3 -- no baseline yet, the code has no default: what it guards is absent at boot (stage baseline add $1 $3 ..., or stage site mk disks for GELI_PARTS)'"
        fi
}

#@help __stage_foundation_summary1
# @command stage foundation summary <stage>
# @summary The closing note of 'stage foundation check': how many bindings across how many phases the stage has, once every chain above passed
# @group   foundation
# @internal
# @see     stage foundation check
#@end
__stage_foundation_summary1() {
        local phases="" bindings=""
        phases=$(ls "$ELEBAKE_BASE/stage/$1/phases" 2>/dev/null | wc -l | tr -d " ")
        bindings=$(cat "$ELEBAKE_BASE/stage/$1"/phases/* 2>/dev/null | grep -c .)
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log 'foundation check ok: $bindings binding(s) across $phases phase(s), every chain in this checkout'"
}

#@help __stage_measurement_exists_in_loader2
# @internal arity-2 sibling of 'stage measurement exists in loader' (stage measurement exists in loader <stage> <name>): The stage's checkout is there: rewrite to the 3-arg form with its local/ directory, else an error line
#@end
__stage_measurement_exists_in_loader2() {
        local loc="$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local"
        if test -d "$loc"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage measurement exists in loader '$1' '$2' '$loc'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage measurement exists in loader: stage $1 has no worktree (stage checkout $1 <ref> first)'"
        fi
}

#@help __stage_measurement_exists_in_loader3
# @command stage measurement exists in loader <stage> <name> <local>
# @summary The loader catalog of the checkout (measurement.h) declares the measurement: a comment line, else an error line naming the catalog
# @group   foundation
# @internal
# @see     stage measurement exists in loader
#@end
__stage_measurement_exists_in_loader3() {
        if grep -qs "struct[[:space:]]measurement[[:space:]]*$2(" "$3/measurement.h"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'measurement $2 is in the loader catalog of stage $1'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'measurement $2 not in the loader catalog of this checkout (stage measure $1 loader lists it)'"
        fi
}

#@help __stage_diagnose_exists_in_loader2
# @internal arity-2 sibling of 'stage diagnose exists in loader' (stage diagnose exists in loader <stage> <name>): The stage's checkout is there: rewrite to the 3-arg form with its local/ directory, else an error line
#@end
__stage_diagnose_exists_in_loader2() {
        local loc="$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local"
        if test -d "$loc"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage diagnose exists in loader '$1' '$2' '$loc'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage diagnose exists in loader: stage $1 has no worktree (stage checkout $1 <ref> first)'"
        fi
}

#@help __stage_diagnose_exists_in_loader3
# @command stage diagnose exists in loader <stage> <name> <local>
# @summary The loader catalog of the checkout (measurement.h) declares the diagnose: a comment line, else an error line naming the catalog
# @group   foundation
# @internal
# @see     stage diagnose exists in loader
#@end
__stage_diagnose_exists_in_loader3() {
        if grep -qs "void[[:space:]]*$2(" "$3/measurement.h"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'diagnose $2 is in the loader catalog of stage $1'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'diagnose $2 not in the loader catalog of this checkout (stage measure $1 loader lists it)'"
        fi
}

#@help __stage_when_exists_in_loader2
# @internal arity-2 sibling of 'stage when exists in loader' (stage when exists in loader <stage> <name>): The stage's checkout is there: rewrite to the 3-arg form with its local/ directory, else an error line
#@end
__stage_when_exists_in_loader2() {
        local loc="$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local"
        if test -d "$loc"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage when exists in loader '$1' '$2' '$loc'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage when exists in loader: stage $1 has no worktree (stage checkout $1 <ref> first)'"
        fi
}

#@help __stage_when_exists_in_loader3
# @command stage when exists in loader <stage> <name> <local>
# @summary The loader catalog of the checkout (policy.h) declares the when: a comment line, else an error line naming the catalog
# @group   foundation
# @internal
# @see     stage when exists in loader
#@end
__stage_when_exists_in_loader3() {
        if grep -qs "^bool[[:space:]]*$2(" "$3/policy.h"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'when $2 is in the loader catalog of stage $1'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'when $2 not in the loader catalog of this checkout (stage when $1 loader lists it)'"
        fi
}

#@help __stage_action_exists_in_loader2
# @internal arity-2 sibling of 'stage action exists in loader' (stage action exists in loader <stage> <name>): The stage's checkout is there: rewrite to the 3-arg form with its local/ directory, else an error line
#@end
__stage_action_exists_in_loader2() {
        local loc="$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local"
        if test -d "$loc"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage action exists in loader '$1' '$2' '$loc'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage action exists in loader: stage $1 has no worktree (stage checkout $1 <ref> first)'"
        fi
}

#@help __stage_action_exists_in_loader3
# @command stage action exists in loader <stage> <name> <local>
# @summary The loader catalog of the checkout (action.h) declares the action: a comment line, else an error line naming the catalog
# @group   foundation
# @internal
# @see     stage action exists in loader
#@end
__stage_action_exists_in_loader3() {
        if grep -qs "extern[[:space:]]const[[:space:]]struct[[:space:]]action[[:space:]]*$2;" "$3/action.h"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'action $2 is in the loader catalog of stage $1'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'action $2 not in the loader catalog of this checkout (stage action $1 loader lists it)'"
        fi
}

#@help __stage_measurement_exists_in_earlboot2
# @internal arity-2 sibling of 'stage measurement exists in earlboot' (stage measurement exists in earlboot <stage> <name>): The stage's checkout is there: rewrite to the 3-arg form with its local/ directory, else an error line
#@end
__stage_measurement_exists_in_earlboot2() {
        local loc="$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local"
        if test -d "$loc"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage measurement exists in earlboot '$1' '$2' '$loc'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage measurement exists in earlboot: stage $1 has no worktree (stage checkout $1 <ref> first)'"
        fi
}

#@help __stage_measurement_exists_in_earlboot3
# @command stage measurement exists in earlboot <stage> <name> <local>
# @summary The earlboot catalog of the checkout (earlboot/measure.sh) declares the measurement: a comment line, else an error line naming the catalog
# @group   foundation
# @internal
# @see     stage measurement exists in earlboot
#@end
__stage_measurement_exists_in_earlboot3() {
        if grep -qs "^$2()" "$3/earlboot/measure.sh"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'measurement $2 is in the earlboot catalog of stage $1'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'measurement $2 not in the earlboot catalog of this checkout (stage measure $1 earlboot lists it)'"
        fi
}

#@help __stage_diagnose_exists_in_earlboot2
# @internal arity-2 sibling of 'stage diagnose exists in earlboot' (stage diagnose exists in earlboot <stage> <name>): The stage's checkout is there: rewrite to the 3-arg form with its local/ directory, else an error line
#@end
__stage_diagnose_exists_in_earlboot2() {
        local loc="$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local"
        if test -d "$loc"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage diagnose exists in earlboot '$1' '$2' '$loc'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage diagnose exists in earlboot: stage $1 has no worktree (stage checkout $1 <ref> first)'"
        fi
}

#@help __stage_diagnose_exists_in_earlboot3
# @command stage diagnose exists in earlboot <stage> <name> <local>
# @summary The earlboot catalog of the checkout (earlboot/measure.sh) declares the diagnose: a comment line, else an error line naming the catalog
# @group   foundation
# @internal
# @see     stage diagnose exists in earlboot
#@end
__stage_diagnose_exists_in_earlboot3() {
        if grep -qs "^$2()" "$3/earlboot/measure.sh"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'diagnose $2 is in the earlboot catalog of stage $1'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'diagnose $2 not in the earlboot catalog of this checkout (stage measure $1 earlboot lists it)'"
        fi
}

#@help __stage_when_exists_in_earlboot2
# @internal arity-2 sibling of 'stage when exists in earlboot' (stage when exists in earlboot <stage> <name>): The stage's checkout is there: rewrite to the 3-arg form with its local/ directory, else an error line
#@end
__stage_when_exists_in_earlboot2() {
        local loc="$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local"
        if test -d "$loc"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage when exists in earlboot '$1' '$2' '$loc'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage when exists in earlboot: stage $1 has no worktree (stage checkout $1 <ref> first)'"
        fi
}

#@help __stage_when_exists_in_earlboot3
# @command stage when exists in earlboot <stage> <name> <local>
# @summary The earlboot catalog of the checkout (earlboot/policy.sh) declares the when: a comment line, else an error line naming the catalog
# @group   foundation
# @internal
# @see     stage when exists in earlboot
#@end
__stage_when_exists_in_earlboot3() {
        if grep -qs "^$2()" "$3/earlboot/policy.sh"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'when $2 is in the earlboot catalog of stage $1'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'when $2 not in the earlboot catalog of this checkout (stage when $1 earlboot lists it)'"
        fi
}

#@help __stage_action_exists_in_earlboot2
# @internal arity-2 sibling of 'stage action exists in earlboot' (stage action exists in earlboot <stage> <name>): The stage's checkout is there: rewrite to the 3-arg form with its local/ directory, else an error line
#@end
__stage_action_exists_in_earlboot2() {
        local loc="$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local"
        if test -d "$loc"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage action exists in earlboot '$1' '$2' '$loc'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage action exists in earlboot: stage $1 has no worktree (stage checkout $1 <ref> first)'"
        fi
}

#@help __stage_action_exists_in_earlboot3
# @command stage action exists in earlboot <stage> <name> <local>
# @summary The earlboot catalog of the checkout (earlboot/action.sh) declares the action: a comment line, else an error line naming the catalog
# @group   foundation
# @internal
# @see     stage action exists in earlboot
#@end
__stage_action_exists_in_earlboot3() {
        if grep -qs "^$2()" "$3/earlboot/action.sh"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'action $2 is in the earlboot catalog of stage $1'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'action $2 not in the earlboot catalog of this checkout (stage action $1 earlboot lists it)'"
        fi
}

#@help __stage_measurement_exists_in_elvbootd2
# @internal arity-2 sibling of 'stage measurement exists in elvbootd' (stage measurement exists in elvbootd <stage> <name>): The stage's checkout is there: rewrite to the 3-arg form with its local/ directory, else an error line
#@end
__stage_measurement_exists_in_elvbootd2() {
        local loc="$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local"
        if test -d "$loc"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage measurement exists in elvbootd '$1' '$2' '$loc'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage measurement exists in elvbootd: stage $1 has no worktree (stage checkout $1 <ref> first)'"
        fi
}

#@help __stage_measurement_exists_in_elvbootd3
# @command stage measurement exists in elvbootd <stage> <name> <local>
# @summary The elvbootd catalog of the checkout (elvbootd/measure.sh, earlboot/measure.sh; earlboot's inherited) declares the measurement: a comment line, else an error line naming the catalog
# @group   foundation
# @internal
# @see     stage measurement exists in elvbootd
#@end
__stage_measurement_exists_in_elvbootd3() {
        if grep -qs "^$2()" "$3/elvbootd/measure.sh" "$3/earlboot/measure.sh"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'measurement $2 is in the elvbootd catalog of stage $1'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'measurement $2 not in the elvbootd catalog of this checkout (stage measure $1 elvbootd lists it)'"
        fi
}

#@help __stage_diagnose_exists_in_elvbootd2
# @internal arity-2 sibling of 'stage diagnose exists in elvbootd' (stage diagnose exists in elvbootd <stage> <name>): The stage's checkout is there: rewrite to the 3-arg form with its local/ directory, else an error line
#@end
__stage_diagnose_exists_in_elvbootd2() {
        local loc="$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local"
        if test -d "$loc"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage diagnose exists in elvbootd '$1' '$2' '$loc'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage diagnose exists in elvbootd: stage $1 has no worktree (stage checkout $1 <ref> first)'"
        fi
}

#@help __stage_diagnose_exists_in_elvbootd3
# @command stage diagnose exists in elvbootd <stage> <name> <local>
# @summary The elvbootd catalog of the checkout (elvbootd/measure.sh, earlboot/measure.sh; earlboot's inherited) declares the diagnose: a comment line, else an error line naming the catalog
# @group   foundation
# @internal
# @see     stage diagnose exists in elvbootd
#@end
__stage_diagnose_exists_in_elvbootd3() {
        if grep -qs "^$2()" "$3/elvbootd/measure.sh" "$3/earlboot/measure.sh"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'diagnose $2 is in the elvbootd catalog of stage $1'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'diagnose $2 not in the elvbootd catalog of this checkout (stage measure $1 elvbootd lists it)'"
        fi
}

#@help __stage_when_exists_in_elvbootd2
# @internal arity-2 sibling of 'stage when exists in elvbootd' (stage when exists in elvbootd <stage> <name>): The stage's checkout is there: rewrite to the 3-arg form with its local/ directory, else an error line
#@end
__stage_when_exists_in_elvbootd2() {
        local loc="$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local"
        if test -d "$loc"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage when exists in elvbootd '$1' '$2' '$loc'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage when exists in elvbootd: stage $1 has no worktree (stage checkout $1 <ref> first)'"
        fi
}

#@help __stage_when_exists_in_elvbootd3
# @command stage when exists in elvbootd <stage> <name> <local>
# @summary The elvbootd catalog of the checkout (elvbootd/policy.sh; earlboot's inherited) declares the when predicate: a comment line, else an error line naming the catalog
# @group   foundation
# @internal
# @see     stage when exists in elvbootd
#@end
__stage_when_exists_in_elvbootd3() {
        if grep -qs "^$2()" "$3/elvbootd/policy.sh"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'when $2 is in the elvbootd catalog of stage $1'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'when $2 not in the elvbootd catalog of this checkout (stage when $1 elvbootd lists it)'"
        fi
}

#@help __stage_action_exists_in_elvbootd2
# @internal arity-2 sibling of 'stage action exists in elvbootd' (stage action exists in elvbootd <stage> <name>): The stage's checkout is there: rewrite to the 3-arg form with its local/ directory, else an error line
#@end
__stage_action_exists_in_elvbootd2() {
        local loc="$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local"
        if test -d "$loc"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage action exists in elvbootd '$1' '$2' '$loc'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage action exists in elvbootd: stage $1 has no worktree (stage checkout $1 <ref> first)'"
        fi
}

#@help __stage_action_exists_in_elvbootd3
# @command stage action exists in elvbootd <stage> <name> <local>
# @summary The elvbootd catalog of the checkout (elvbootd/action.sh, earlboot/action.sh; earlboot's inherited) declares the action: a comment line, else an error line naming the catalog
# @group   foundation
# @internal
# @see     stage action exists in elvbootd
#@end
__stage_action_exists_in_elvbootd3() {
        if grep -qs "^$2()" "$3/elvbootd/action.sh" "$3/earlboot/action.sh"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'action $2 is in the elvbootd catalog of stage $1'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'action $2 not in the elvbootd catalog of this checkout (stage action $1 elvbootd lists it)'"
        fi
}

#@help ___stage_phase_show1
# @command stage phase show <stage> [<phase>]
# @summary List the phases the stage's checkout offers per container (ELEBAKE_CONTAINERS, in that order), each with its bound policies: one 'stage phase show <container> <stage>' per container; one phase in detail with the 2-arg form
# @group   foundation
# @env     ELEBAKE_CONTAINERS  the containers whose phases are listed, in this order
# @example elebake stage phase show daily-v1
# @see     stage phase policy add
#@end
___stage_phase_show1() {
        local ref="" c=""
        ref=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/checkout" 2>/dev/null)
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage checkout exists '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log 'phase catalog of stage $1 (checkout: ${ref:--})'"
        for c in $ELEBAKE_CONTAINERS; do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage phase show '$c' '$1'"
        done
}

#@help ___stage_phase_show_loader1
# @command stage phase show loader <stage>
# @summary The phases loader offers in the stage's checkout, each with its bound policies ('stage phase report')
# @group   foundation
# @internal
# @see     stage phase show
#@end
___stage_phase_show_loader1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log '  [loader]'"
        local ph=""
        for ph in $(sed -n '/enum phase {/,/};/p' "$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local/policy.h" 2>/dev/null | grep -o 'PHASE_[A-Z_]*'); do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage phase report '$1' '$ph'"
        done
}

#@help ___stage_phase_show_earlboot1
# @command stage phase show earlboot <stage>
# @summary The phases earlboot offers in the stage's checkout, each with its bound policies ('stage phase report')
# @group   foundation
# @internal
# @see     stage phase show
#@end
___stage_phase_show_earlboot1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log '  [earlboot]'"
        local ph=""
        for ph in $(sed -n 's/^PHASES="\([A-Z_ ]*\)".*/\1/p' "$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local/earlboot/policy.sh" 2>/dev/null | tr ' ' '\n'); do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage phase report '$1' '$ph'"
        done
}

#@help ___stage_phase_show_elvbootd1
# @command stage phase show elvbootd <stage>
# @summary The phases elvbootd offers in the stage's checkout, each with its bound policies ('stage phase report')
# @group   foundation
# @internal
# @see     stage phase show
#@end
___stage_phase_show_elvbootd1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log '  [elvbootd]'"
        local ph=""
        for ph in $(sed -n 's/^PHASES="\([A-Z_ ]*\)".*/\1/p' "$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local/elvbootd/policy.sh" 2>/dev/null | tr ' ' '\n'); do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage phase report '$1' '$ph'"
        done
}

#@help ___stage_phase_show2
# @internal 2-arg sibling of 'stage phase show': one phase in detail -- its bound policies and its <phase>_policies[] table as the emission writes it
#@end
___stage_phase_show2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage phase exists '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage phase report '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage phase render c '$1' '$2'"
}

#@help __stage_phase_exists2
# @command stage phase exists <stage> <phase>
# @summary One container of the stage's checkout lists the phase (enum phase of policy.h, PHASES= of the sh containers): a comment line, else an error line
# @group   foundation
# @internal
# @see     stage phase policy add
#@end
__stage_phase_exists2() {
        if { sed -n '/enum phase {/,/};/p' "$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local/policy.h" 2>/dev/null | grep -o 'PHASE_[A-Z_]*'; sed -n 's/^PHASES="\([A-Z_ ]*\)".*/\1/p' "$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local"/*/policy.sh 2>/dev/null | tr ' ' '\n'; } | grep -qx "$2"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'phase $2 is in the checkout of stage $1'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'unknown phase $2 (stage phase show $1 lists them)'"
        fi
}

#@help _stage_phase_policy_append3
# @internal arity-3 sibling of 'stage phase policy append' (stage phase policy append <stage> <phase> <policy>): Act terminal of 'stage phase policy add': the idempotent append of the policy name to phases/<phase> (dumps replay this line directly; the checks ran at the original binding)
#@end
_stage_phase_policy_append3() {
        printf '%s\n' "$MODIFY_DIR_CREATE '$ELEBAKE_BASE/stage/$1/phases'"
        printf '%s\n' "grep -qxF '$3' '$ELEBAKE_BASE/stage/$1/phases/$2' 2>/dev/null || printf '%s\\n' '$3' >> '$ELEBAKE_BASE/stage/$1/phases/$2'"
        emit_note "stage '$1': policy '$3' bound to $2"
}

#@help __stage_phase_policy_append4
# @command stage phase policy append <stage> <phase> <policy> <position>
# @summary The policy is bound already: an error line (position is placement, not a move; drop first), else 'stage phase policy place'
# @group   foundation
# @internal
# @see     stage phase policy add
#@end
__stage_phase_policy_append4() {
        if grep -qxF "$3" "$ELEBAKE_BASE/stage/$1/phases/$2" 2>/dev/null; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage phase policy add: $3 already bound to $2 (position is placement, not a move; drop first)'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage phase policy place '$1' '$2' '$3' '$4'"
        fi
}

#@help __stage_phase_policy_place4
# @command stage phase policy place <stage> <phase> <policy> <position>
# @summary The position is within 1..lines+1: 'stage phase policy splice', else an error line
# @group   foundation
# @internal
# @see     stage phase policy add
#@end
__stage_phase_policy_place4() {
        local n; n=$(grep -c "" "$ELEBAKE_BASE/stage/$1/phases/$2" 2>/dev/null)
        if line_pos_ok "$4" "${n:-0}"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage phase policy splice '$1' '$2' '$3' '$4'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage phase policy add: position $4 out of range (1..$((${n:-0} + 1)))'"
        fi
}

#@help _stage_phase_policy_splice4
# @command stage phase policy splice <stage> <phase> <policy> <position>
# @summary Act terminal: insert the policy at the position of phases/<phase> (the record created when absent)
# @group   foundation
# @internal
# @see     stage phase policy add
#@end
_stage_phase_policy_splice4() {
        printf '%s\n' "$MODIFY_DIR_CREATE '$ELEBAKE_BASE/stage/$1/phases'"
        printf '%s\n' "test -f '$ELEBAKE_BASE/stage/$1/phases/$2' || : > '$ELEBAKE_BASE/stage/$1/phases/$2'"
        line_insert_emit "$ELEBAKE_BASE/stage/$1/phases/$2" "$4" "$3"
        emit_note "stage '$1': policy '$3' bound to $2 at $4"
}

#@help ___stage_phase_policy_drop3
# @command stage phase policy drop <stage> <phase> <policy>
# @summary Unbind a policy from a stage's phase (the policy itself survives): the stage exists and the phase binds the policy, then the line is removed
# @group   foundation
# @example elebake stage phase policy drop daily-v1 SYSINIT fish-0
# @see     stage phase policy add
#@end
___stage_phase_policy_drop3() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage phase policy bound '$1' '$2' '$3'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage phase policy unbind '$1' '$2' '$3'"
}

#@help __stage_phase_policy_bound3
# @command stage phase policy bound <stage> <phase> <policy>
# @summary The phase record of the stage lists the policy: a comment line, else an error line
# @group   foundation
# @internal
# @see     stage phase policy drop
#@end
__stage_phase_policy_bound3() {
        if grep -qxsF "$3" "$ELEBAKE_BASE/stage/$1/phases/$2"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'policy $3 is bound to $2'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage phase policy drop: $3 not bound to $2'"
        fi
}

#@help _stage_phase_policy_unbind3
# @command stage phase policy unbind <stage> <phase> <policy>
# @summary Act terminal: remove the policy's line from phases/<phase>
# @group   foundation
# @internal
# @see     stage phase policy drop
#@end
_stage_phase_policy_unbind3() {
        printf '%s\n' "grep -vxF '$3' '$ELEBAKE_BASE/stage/$1/phases/$2' > '$ELEBAKE_BASE/stage/$1/phases/$2.new'; mv '$ELEBAKE_BASE/stage/$1/phases/$2.new' '$ELEBAKE_BASE/stage/$1/phases/$2'"
        emit_note "stage '$1': policy '$3' unbound from $2"
}

