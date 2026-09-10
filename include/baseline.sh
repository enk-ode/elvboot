#!/bin/sh
#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Dr. Johannes Brügmann
# elebake baseline - the per-stage VALUES the signed loader is built with.
#
# Three record families, all per stage, all dumb stores, all replayed by
# the dump:
#
#   baselines/<MACRO>   "<type> <value>": one -D macro the loader sources
#                       consume -- windows (int), lists and passphrase
#                       hashes (string), learned digests (digest). The
#                       gate SLOTS name these macros (gate add); this is
#                       where the values come from. site mk renders them.
#   disks               the internal GELI partitions (nda0p1 ...) whose
#                       metadata sectors and partition tables the loader
#                       measures; site mk hashes them from userland into
#                       LOADER_TRUST_GELI_PARTS / _GELI_DIGEST / _GPT_DIGEST.
#   conf/<key>          loader.trust.* kenv values the bound actions read
#                       at boot (question, salt, rescue root, deadline ...);
#                       loaderconf mk writes them into boot/loader.trust.conf,
#                       the require chain says which are mandatory.
#
# Top down like the arsenal: add is a batch (the stage exists, then the write
# chain: there already? unchanged or refused : valid? record : error), drop is
# exists + erase, show is exists + a text terminal. Measuring (site mk disks,
# baseline learn) happens when the batch RUNS: the terminals print the
# commands, the generator never reads a device or the kenv. The predicates
# live in predicate.sh, the leaf parser in template/awk/action-leafs.awk.

BASELINE_TYPES="digest string int"

#@help __stage_baseline_fields_valid3
# @command stage baseline fields valid <MACRO> <type> <value>
# @summary The fields of a 'stage baseline add' carry no single quote: a comment line, else an error line
# @group   provisioning
# @internal
# @see     stage baseline add
#@end
__stage_baseline_fields_valid3() {
        if fnd_fields_ok "$1" "$2" "$3"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'baseline fields without single quotes'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage baseline add: a field carries a single quote: $1'"
        fi
}

#@help ___stage_baseline_add4
# @command stage baseline add <stage> <MACRO> <digest|string|int> <value>
# @summary Store one build-provided value of the stage: a LOADER_TRUST_* macro the loader sources consume, rendered into site.mk by 'stage site mk' (digest: 64 hex -> byte list; string: C string; int: bare). Immutable: an identical re-add is a no-op, a differing one is refused (drop first). This is where gate slots (gate add) and provider windows get their values; the dump replays every record
# @group   provisioning
# @example elebake stage baseline add daily-v1 LOADER_TRUST_TIME_BOOT_MAX_MS int 90000
# @see     stage baseline learn
# @see     stage site mk
# @see     gate add
#@end
___stage_baseline_add4() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage baseline fields valid '$2' '$3' $(sq "$4")"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage baseline write '$1' '$2' '$3' $(sq "$4")"
}

#@help __stage_baseline_write4
# @command stage baseline write <stage> <MACRO> <type> <value>
# @summary The record is there already: rewrite to 'stage baseline rewrite', else to 'stage baseline store'
# @group   provisioning
# @internal
# @see     stage baseline add
#@end
__stage_baseline_write4() {
        if test -f "$ELEBAKE_BASE/stage/$1/baselines/$2"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage baseline rewrite '$1' '$2' '$3' '$4'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage baseline store '$1' '$2' '$3' '$4'"
        fi
}

#@help __stage_baseline_rewrite4
# @command stage baseline rewrite <stage> <MACRO> <type> <value>
# @summary An existing record with the identical 'type value' is a no-op (a comment line); a different one is refused -- baselines are immutable, drop first
# @group   provisioning
# @internal
# @see     stage baseline add
#@end
__stage_baseline_rewrite4() {
        if test "$(cat "$ELEBAKE_BASE/stage/$1/baselines/$2" 2>/dev/null)" = "$3 $4"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" note 'baseline $2 of $1 already recorded (unchanged)'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage baseline add: $2 of $1 exists with a different value (immutable; stage baseline drop first)'"
        fi
}

#@help __stage_baseline_store4
# @command stage baseline store <stage> <MACRO> <type> <value>
# @summary The macro is LOADER_TRUST_<NAME>, the type one of digest, string, int, and the value fits the type (digest: 64 hex; int: digits; no quotes, spaces or backslashes): rewrite to 'stage baseline record', else an error line
# @group   provisioning
# @internal
# @see     stage baseline add
#@end
__stage_baseline_store4() {
        if baseline_macro_ok "$2" && baseline_type_ok "$3" && baseline_value_ok "$3" "$4"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage baseline record '$1' '$2' '$3' '$4'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage baseline add: macro must be LOADER_TRUST_<NAME>, the type digest|string|int, and the value does not fit otherwise (digest 64 hex, int digits, no quotes/spaces/backslashes): $2 $3 $4'"
        fi
}

#@help _stage_baseline_record4
# @command stage baseline record <stage> <MACRO> <type> <value>
# @summary Act terminal: write baselines/<MACRO> ('type value') of the stage, directory 0700, file 0600
# @group   provisioning
# @internal
# @see     stage baseline add
#@end
_stage_baseline_record4() {
        printf '%s\n' "$MODIFY_DIR_CREATE '$ELEBAKE_BASE/stage/$1/baselines'"
        printf '%s\n' "$MODIFY_FILE_PERMS 0700 '$ELEBAKE_BASE/stage/$1/baselines'"
        printf '%s\n' "printf '%s\\n' '$3 $4' > '$ELEBAKE_BASE/stage/$1/baselines/$2'"
        printf '%s\n' "$MODIFY_FILE_PERMS 0600 '$ELEBAKE_BASE/stage/$1/baselines/$2'"
        emit_note "baseline $2 of $1: $3 (site mk renders it; rebuild + sign + deploy to arm it)"
}

#@help ___stage_baseline_drop2
# @command stage baseline drop <stage> <MACRO>
# @summary Remove one build-provided value of the stage: the stage and the record exist, then it is erased
# @group   provisioning
# @example elebake stage baseline drop daily-v1 LOADER_TRUST_TIME_BOOT_MAX_MS
# @see     stage baseline add
#@end
___stage_baseline_drop2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage baseline exists '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage baseline erase '$1' '$2'"
}

#@help __stage_baseline_exists2
# @command stage baseline exists <stage> <MACRO>
# @summary The baseline record of the stage is there: a comment line, else an error line
# @group   provisioning
# @internal
# @see     stage baseline drop
#@end
__stage_baseline_exists2() {
        if test -f "$ELEBAKE_BASE/stage/$1/baselines/$2"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'baseline $2 of $1 recorded'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'no baseline $2 of $1'"
        fi
}

#@help _stage_baseline_erase2
# @command stage baseline erase <stage> <MACRO>
# @summary Act terminal: remove baselines/<MACRO> of the stage
# @group   provisioning
# @internal
# @see     stage baseline drop
#@end
_stage_baseline_erase2() {
        printf '%s\n' "$MODIFY_FILE_REMOVE '$ELEBAKE_BASE/stage/$1/baselines/$2'"
        emit_note "baseline $2 of $1 dropped"
}

#@help ___stage_baseline_show1
# @command stage baseline show <stage> [<MACRO>]
# @summary Show the stage's build-provided values (or one) as the -D lines site mk would render: one 'stage baseline show <stage> <MACRO>' per record; none is a note
# @group   provisioning
# @example elebake stage baseline show daily-v1
# @see     stage baseline add
#@end
___stage_baseline_show1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        local f="" lines=0
        for f in "$ELEBAKE_BASE/stage/$1"/baselines/*; do
                [ -f "$f" ] || continue
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage baseline show '$1' '${f##*/}'"
                lines=$((lines + 1))
        done
        test "$lines" -gt 0 || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log 'no baselines of $1 -- stage baseline add $1 <MACRO> <type> <value>'"
}

#@help ___stage_baseline_show2
# @internal 2-arg sibling of 'stage baseline show': one baseline in detail -- the record exists, then its head (type, value) and the rendered -D line
#@end
___stage_baseline_show2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage baseline exists '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage baseline render head '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage baseline render show '$1' '$2'"
}

#@help _stage_baseline_render_head2
# @command stage baseline render head <stage> <MACRO>
# @summary Print the head line of one baseline: the macro, its type and value
# @group   provisioning
# @internal
# @see     stage baseline show
#@end
_stage_baseline_render_head2() {
        local type="" value=""
        read -r type value 2>/dev/null < "$ELEBAKE_BASE/stage/$1/baselines/$2"
        printf '# %s (%s): %s\n' "$2" "$type" "$value"
}

#@help __stage_baseline_render_show2
# @command stage baseline render show <stage> <MACRO>
# @summary The record's type word dispatches the rendering (lifting): 'stage baseline show <type> <MACRO> <value>'
# @group   provisioning
# @internal
# @see     stage baseline show
#@end
__stage_baseline_render_show2() {
        local type="" value=""
        read -r type value 2>/dev/null < "$ELEBAKE_BASE/stage/$1/baselines/$2"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage baseline show $type '$2' '$value'"
}

#@help _stage_baseline_show_digest2
# @command stage baseline show digest <MACRO> <value>
# @summary Print the -D line site mk renders for a digest baseline: the digest as a byte list 0x..,0x..
# @group   provisioning
# @internal
# @see     stage baseline show
#@end
_stage_baseline_show_digest2() {
        printf "#   CFLAGS+= -D%s='%s'\n" "$1" "$(printf '%s' "$2" | sed 's/\(..\)/0x\1,/g; s/,$//')"
}

#@help _stage_baseline_line_digest2
# @command stage baseline line digest <MACRO> <value>
# @summary Print the site.mk line of a digest baseline: the digest as a byte list 0x..,0x..
# @group   provisioning
# @internal
# @see     stage site mk baselines
#@end
_stage_baseline_line_digest2() {
        printf "CFLAGS+= -D%s='%s'\n" "$1" "$(printf '%s' "$2" | sed 's/\(..\)/0x\1,/g; s/,$//')"
}

#@help _stage_baseline_show_string2
# @command stage baseline show string <MACRO> <value>
# @summary Print the -D line site mk renders for a string baseline: the string as a C string literal
# @group   provisioning
# @internal
# @see     stage baseline show
#@end
_stage_baseline_show_string2() {
        printf '#   CFLAGS+= -D%s=\\"%s\\"\n' "$1" "$2"
}

#@help _stage_baseline_line_string2
# @command stage baseline line string <MACRO> <value>
# @summary Print the site.mk line of a string baseline: the string as a C string literal
# @group   provisioning
# @internal
# @see     stage site mk baselines
#@end
_stage_baseline_line_string2() {
        printf 'CFLAGS+= -D%s=\\"%s\\"\n' "$1" "$2"
}

#@help _stage_baseline_show_int2
# @command stage baseline show int <MACRO> <value>
# @summary Print the -D line site mk renders for a int baseline: the int bare
# @group   provisioning
# @internal
# @see     stage baseline show
#@end
_stage_baseline_show_int2() {
        printf '#   CFLAGS+= -D%s=%s\n' "$1" "$2"
}

#@help _stage_baseline_line_int2
# @command stage baseline line int <MACRO> <value>
# @summary Print the site.mk line of a int baseline: the int bare
# @group   provisioning
# @internal
# @see     stage site mk baselines
#@end
_stage_baseline_line_int2() {
        printf 'CFLAGS+= -D%s=%s\n' "$1" "$2"
}

#@help ___stage_baseline_learn3
# @command stage baseline learn <stage> <MACRO> <kenv-variable>
# @summary Take a digest baseline from THIS machine's kenv when the batch runs -- the value a trusted boot's loader published (loader.trust.<gate>.<leaf>, 64 hex) -- and record it as 'stage baseline add <stage> <MACRO> digest <value>'. For the witnesses userland cannot compute (loaded EFI images, ACPI tables, EFI variables, PCI devices, PCR bank, soft PCR, guarded kenv). Assumes: the boot that published the value was the owner's own, on the intended firmware -- learning on a tampered platform bakes the tampering in
# @group   provisioning
# @example elebake stage baseline learn daily-v1 LOADER_TRUST_IMAGES_DIGEST loader.trust.platform.images.sha256
# @see     stage baseline add
#@end
___stage_baseline_learn3() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage baseline learn valid '$2' '$3'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage baseline learn read '$1' '$2' '$3'"
}

#@help __stage_baseline_learn_valid2
# @command stage baseline learn valid <MACRO> <kenv-variable>
# @summary The macro is LOADER_TRUST_<NAME> and the variable loader.trust.*: a comment line, else an error line
# @group   provisioning
# @internal
# @see     stage baseline learn
#@end
__stage_baseline_learn_valid2() {
        if printf '%s\n' "$1" | grep -qx 'LOADER_TRUST_[A-Z0-9_]*' && printf '%s\n' "$2" | grep -qx 'loader\.trust\..*'; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'learn $1 from $2'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage baseline learn: macro must be LOADER_TRUST_<NAME> and the variable loader.trust.*: $1 $2'"
        fi
}

#@help __stage_baseline_learn_read3
# @command stage baseline learn read <stage> <MACRO> <kenv-variable>
# @summary The variable is a published 64-hex digest in the running kenv: rewrite to 'stage baseline add <stage> <MACRO> digest <value>', else an error line (boot the provisioned loader here first)
# @group   provisioning
# @internal
# @see     stage baseline learn
#@end
__stage_baseline_learn_read3() {
        local value=""
        value=$(kenv -q "$3" 2>/dev/null)
        if printf '%s\n' "$value" | grep -qx '[0-9a-f]\{64\}'; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage baseline add '$1' '$2' digest '$value'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage baseline learn: $3 is not a published 64-hex digest on this machine (boot the provisioned loader here first)'"
        fi
}

#@help ___stage_dump_baselines1
# @internal dump block (cat-pinned): one 'stage baseline add' replay per record
#@end
___stage_dump_baselines1() {
        local f="" type="" value=""
        for f in "$ELEBAKE_BASE/stage/$1"/baselines/*; do
                [ -f "$f" ] || continue
                read -r type value 2>/dev/null < "$f"
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage baseline add '$1' '${f##*/}' '$type' '$value'"
        done
}

#@help ___stage_site_mk_baselines1
# @command stage site mk baselines <stage>
# @summary The stage's build-provided values as -D lines of site.mk: one 'stage site mk baseline <stage> <MACRO>' per record (none prints nothing)
# @group   provisioning
# @internal
# @see     stage site mk
# @see     stage baseline add
#@end
___stage_site_mk_baselines1() {
        local f="" lines=0
        for f in "$ELEBAKE_BASE/stage/$1"/baselines/*; do
                [ -f "$f" ] || continue
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage site mk baseline '$1' '${f##*/}'"
                lines=$((lines + 1))
        done
        test "$lines" -gt 0 || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'stage $1 has no baselines'"
}

#@help __stage_site_mk_baseline2
# @command stage site mk baseline <stage> <MACRO>
# @summary The record's type word dispatches the line (lifting): 'stage baseline line <type> <MACRO> <value>'
# @group   provisioning
# @internal
# @see     stage site mk baselines
#@end
__stage_site_mk_baseline2() {
        local type="" value=""
        read -r type value 2>/dev/null < "$ELEBAKE_BASE/stage/$1/baselines/$2"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage baseline line $type '$2' '$value'"
}

#@help ___stage_disks_add2
# @command stage disks add <stage> <partition>
# @summary Record one internal GPT partition (nda0p1) whose GELI metadata sector and whose disk's partition table the loader measures (measure_geli, measure_gpt); 'stage site mk' hashes them when it runs. Order of the records = order of hashing. Assumes: the partitions are GELI providers on GPT disks the firmware exposes via Block I/O; a legitimate setkey/delkey or repartitioning moves the digest -- re-run site mk afterwards
# @group   provisioning
# @example elebake stage disks add daily-v1 nda0p1
# @see     stage disks drop
# @see     stage site mk disks
#@end
___stage_disks_add2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage disks write '$1' '$2'"
}

#@help __stage_disks_write2
# @command stage disks write <stage> <partition>
# @summary The name is a GPT partition name (<disk><n>p<m>): recorded already is a comment line, else 'stage disks append'; an invalid name is an error line
# @group   provisioning
# @internal
# @see     stage disks add
#@end
__stage_disks_write2() {
        if disk_name_ok "$2" && grep -qxF "$2" "$ELEBAKE_BASE/stage/$1/disks" 2>/dev/null; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" note 'disks of $1: $2 already recorded'"
        elif disk_name_ok "$2"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage disks append '$1' '$2'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage disks add: not a GPT partition name (<disk><n>p<m>): $2'"
        fi
}

#@help _stage_disks_append2
# @command stage disks append <stage> <partition>
# @summary Act terminal: append the partition to the stage's disks record, mode 0600
# @group   provisioning
# @internal
# @see     stage disks add
#@end
_stage_disks_append2() {
        printf '%s\n' "printf '%s\\n' '$2' >> '$ELEBAKE_BASE/stage/$1/disks'"
        printf '%s\n' "$MODIFY_FILE_PERMS 0600 '$ELEBAKE_BASE/stage/$1/disks'"
        emit_note "disks of $1: + $2 (stage site mk measures it)"
}

#@help ___stage_disks_drop2
# @command stage disks drop <stage> <partition>
# @summary Remove one partition from the stage's disks record: the stage exists and lists it, then the line is removed
# @group   provisioning
# @see     stage disks add
#@end
___stage_disks_drop2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage disks listed '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage disks unlink '$1' '$2'"
}

#@help __stage_disks_listed2
# @command stage disks listed <stage> <partition>
# @summary The stage's disks record lists the partition: a comment line, else an error line
# @group   provisioning
# @internal
# @see     stage disks drop
#@end
__stage_disks_listed2() {
        if grep -qxsF "$2" "$ELEBAKE_BASE/stage/$1/disks"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'disks of $1 list $2'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage disks drop: not recorded: $2'"
        fi
}

#@help _stage_disks_unlink2
# @command stage disks unlink <stage> <partition>
# @summary Act terminal: remove the partition's line from the disks record
# @group   provisioning
# @internal
# @see     stage disks drop
#@end
_stage_disks_unlink2() {
        printf '%s\n' "grep -vxF '$2' '$ELEBAKE_BASE/stage/$1/disks' > '$ELEBAKE_BASE/stage/$1/disks.new'; mv '$ELEBAKE_BASE/stage/$1/disks.new' '$ELEBAKE_BASE/stage/$1/disks'"
        emit_note "disks of $1: - $2"
}

#@help ___stage_disks_show1
# @command stage disks show <stage>
# @summary List the stage's recorded partitions as notes; none says so
# @group   provisioning
# @see     stage disks add
#@end
___stage_disks_show1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log 'disks of $1'"
        local dev="" lines=0
        grep . "$ELEBAKE_BASE/stage/$1/disks" 2>/dev/null | while read -r dev; do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log '  $dev'"
        done
        test -s "$ELEBAKE_BASE/stage/$1/disks" || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log '  (empty -- stage disks add $1 <partition>)'"
}

#@help ___stage_dump_disks1
# @internal dump block (cat-pinned): one 'stage disks add' replay per record
#@end
___stage_dump_disks1() {
        local dev=""
        grep . "$ELEBAKE_BASE/stage/$1/disks" 2>/dev/null | while read -r dev; do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage disks add '$1' '$dev'"
        done
}

#@help __stage_site_mk_disks1
# @command stage site mk disks <stage>
# @summary The stage has a disks record: rewrite to 'stage disks measure <stage>' (the measurements when the batch runs, then the three site.mk lines), else a comment line -- no disks record prints nothing
# @group   provisioning
# @internal
# @see     stage site mk
# @see     stage disks add
#@end
__stage_site_mk_disks1() {
        if test -s "$ELEBAKE_BASE/stage/$1/disks"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage disks measure '$1'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'stage $1 has no disks record'"
        fi
}

#@help ___stage_disks_measure1
# @command stage disks measure <stage>
# @summary Measure the recorded partitions when the batch runs (raw device reads: run under sudo) -- their GPT UUIDs (gpart), the last 512 bytes of each provider (GELI metadata), the GPT header and entry array of each disk once -- into a scratch directory of the stage, then print LOADER_TRUST_GELI_PARTS, _GELI_DIGEST and _GPT_DIGEST; an unreadable device fails the batch
# @group   provisioning
# @internal
# @see     stage site mk disks
#@end
___stage_disks_measure1() {
        local dev="" disk=""
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage disks scratch mk '$1'"
        grep . "$ELEBAKE_BASE/stage/$1/disks" 2>/dev/null | while read -r dev; do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage disk uuid record '$1' '$dev'"
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage disk geli measure '$1' '$dev'"
        done
        grep . "$ELEBAKE_BASE/stage/$1/disks" 2>/dev/null | sed "s/p[0-9]*$//" | sort -u | while read -r disk; do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage disk gpt measure '$1' '$disk'"
        done
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage disks lines '$1'"
}

#@help _stage_disks_scratch_mk1
# @command stage disks scratch mk <stage>
# @summary Act terminal: a fresh scratch directory disks.measure/ of the stage with empty parts, geli and gpt files
# @group   provisioning
# @internal
# @see     stage site mk disks
#@end
_stage_disks_scratch_mk1() {
        printf '%s\n' "rm -rf '$ELEBAKE_BASE/stage/$1/disks.measure' && mkdir -p '$ELEBAKE_BASE/stage/$1/disks.measure' && : > '$ELEBAKE_BASE/stage/$1/disks.measure/parts' && : > '$ELEBAKE_BASE/stage/$1/disks.measure/geli' && : > '$ELEBAKE_BASE/stage/$1/disks.measure/gpt' && chown '$(id -un)' -R '$ELEBAKE_BASE/stage/$1/disks.measure' 2>/dev/null || true"
}

#@help _stage_disk_uuid_record2
# @command stage disk uuid record <stage> <partition>
# @summary Act terminal: the partition's GPT rawuuid (gpart list, lower case) appended to the scratch parts list; none fails
# @group   provisioning
# @internal
# @see     stage site mk disks
#@end
_stage_disk_uuid_record2() {
        printf '%s\n' "u=\$(gpart list '${2%p[0-9]*}' | awk -v want='$2' '\$1 == \"Name:\" { cur = \$2 } \$1 == \"rawuuid:\" && cur == want { print tolower(\$2); exit }'); test -n \"\$u\" && printf '%s\\n' \"\$u\" >> '$ELEBAKE_BASE/stage/$1/disks.measure/parts'"
}

#@help _stage_disk_geli_measure2
# @command stage disk geli measure <stage> <partition>
# @summary Act terminal: the last 512 bytes of the provider (the GELI metadata sector) appended to the scratch geli file
# @group   provisioning
# @internal
# @see     stage site mk disks
#@end
_stage_disk_geli_measure2() {
        printf '%s\n' "s=\$(diskinfo '/dev/$2' | awk '{ print \$3 }'); test \"\${s:-0}\" -ge 512 && dd if='/dev/$2' bs=512 skip=\$((s / 512 - 1)) count=1 2>/dev/null >> '$ELEBAKE_BASE/stage/$1/disks.measure/geli'"
}

#@help _stage_disk_gpt_measure2
# @command stage disk gpt measure <stage> <disk>
# @summary Act terminal: the GPT header (first 92 bytes of LBA 1) followed by the partition entry array of the disk, exactly what measure_gpt hashes, appended to the scratch gpt file
# @group   provisioning
# @internal
# @see     stage site mk disks
#@end
_stage_disk_gpt_measure2() {
        cat <<EOF
ss=\$(diskinfo '/dev/$2' | awk '{ print \$2 }'); test "\${ss:-0}" -ge 512 || exit 1
h=\$(mktemp) || exit 1; dd if='/dev/$2' bs="\$ss" skip=1 count=1 of="\$h" 2>/dev/null || exit 1
test "\$(dd if="\$h" bs=1 count=8 2>/dev/null)" = "EFI PART" || exit 1
t=\$(od -An -tu8 -j72 -N8 "\$h" | tr -d ' '); e=\$(od -An -tu4 -j80 -N4 "\$h" | tr -d ' '); z=\$(od -An -tu4 -j84 -N4 "\$h" | tr -d ' ')
dd if="\$h" bs=1 count=92 2>/dev/null >> '$ELEBAKE_BASE/stage/$1/disks.measure/gpt'; rm -f "\$h"
dd if='/dev/$2' bs="\$ss" skip="\$t" count="\$(((e * z + ss - 1) / ss))" 2>/dev/null | head -c "\$((e * z))" >> '$ELEBAKE_BASE/stage/$1/disks.measure/gpt'
EOF
}

#@help _stage_disks_lines1
# @command stage disks lines <stage>
# @summary Act terminal: print the three site.mk lines from the scratch files (parts joined by ',', the geli and gpt digests as byte lists) and remove the scratch directory
# @group   provisioning
# @internal
# @see     stage site mk disks
#@end
_stage_disks_lines1() {
        cat <<EOF
printf 'CFLAGS+= -DLOADER_TRUST_GELI_PARTS=\\\\"%s\\\\"\\n' "\$(paste -sd, '$ELEBAKE_BASE/stage/$1/disks.measure/parts')"
printf "CFLAGS.foundation.c += -DLOADER_TRUST_GELI_DIGEST='%s'\\n" "\$(sha256 -q '$ELEBAKE_BASE/stage/$1/disks.measure/geli' | sed 's/\\(..\\)/0x\\1,/g; s/,\$//')"
printf "CFLAGS.foundation.c += -DLOADER_TRUST_GPT_DIGEST='%s'\\n" "\$(sha256 -q '$ELEBAKE_BASE/stage/$1/disks.measure/gpt' | sed 's/\\(..\\)/0x\\1,/g; s/,\$//')"
rm -rf '$ELEBAKE_BASE/stage/$1/disks.measure'
EOF
}

#@help ___stage_conf_add3
# @command stage conf add <stage> <key> <value>
# @summary Store one loader.trust.* kenv value of the stage (dumb store, immutable: identical re-add is a no-op, a differing one is refused); 'stage loaderconf mk' writes every record into boot/loader.trust.conf, 'stage require' says which the bound actions demand. Values that are secrets (hashes) belong here only as HASHES; the medium carries this file in clear, covered by the manifest
# @group   provisioning
# @example elebake stage conf add daily-v1 loader.trust.kernellock.rescue zfs:zcard/ROOT/rescue
# @see     stage conf drop
# @see     stage require
# @see     stage loaderconf mk
#@end
___stage_conf_add3() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage conf write '$1' '$2' $(sq "$3")"
}

#@help __stage_conf_write3
# @command stage conf write <stage> <key> <value>
# @summary The record is there already: rewrite to 'stage conf rewrite', else to 'stage conf store'
# @group   provisioning
# @internal
# @see     stage conf add
#@end
__stage_conf_write3() {
        if test -f "$ELEBAKE_BASE/stage/$1/conf/$2"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage conf rewrite '$1' '$2' $(sq "$3")"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage conf store '$1' '$2' $(sq "$3")"
        fi
}

#@help __stage_conf_rewrite3
# @command stage conf rewrite <stage> <key> <value>
# @summary An existing record with the identical value is a no-op (a comment line); a different one is refused -- drop first
# @group   provisioning
# @internal
# @see     stage conf add
#@end
__stage_conf_rewrite3() {
        if test "$(sed -n 1p "$ELEBAKE_BASE/stage/$1/conf/$2" 2>/dev/null)" = "$3"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" note 'conf $2 of $1 already recorded (unchanged)'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage conf add: $2 of $1 exists with a different value (immutable; stage conf drop first)'"
        fi
}

#@help __stage_conf_store3
# @command stage conf store <stage> <key> <value>
# @summary The key is loader.trust.<gate>.<leaf> (a-z, 0-9, ., _) and the value fits one loader.conf line (no double quotes, backslashes or newlines): rewrite to 'stage conf record', else an error line
# @group   provisioning
# @internal
# @see     stage conf add
#@end
__stage_conf_store3() {
        if conf_key_ok "$2" && conf_value_ok "$3"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage conf record '$1' '$2' $(sq "$3")"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage conf add: invalid key or value (loader.trust.<gate>.<leaf>; one loader.conf line): $2'"
        fi
}

#@help _stage_conf_record3
# @command stage conf record <stage> <key> <value>
# @summary Act terminal: write conf/<key> of the stage, directory 0700, file 0600
# @group   provisioning
# @internal
# @see     stage conf add
#@end
_stage_conf_record3() {
        printf '%s\n' "$MODIFY_DIR_CREATE '$ELEBAKE_BASE/stage/$1/conf'"
        printf '%s\n' "$MODIFY_FILE_PERMS 0700 '$ELEBAKE_BASE/stage/$1/conf'"
        printf '%s\n' "printf '%s\\n' $(sq "$3") > '$ELEBAKE_BASE/stage/$1/conf/$2'"
        printf '%s\n' "$MODIFY_FILE_PERMS 0600 '$ELEBAKE_BASE/stage/$1/conf/$2'"
        emit_note "conf $2 of $1 recorded (stage loaderconf mk writes it)"
}

#@help ___stage_conf_drop2
# @command stage conf drop <stage> <key>
# @summary Remove one loader.trust.* value of the stage: the stage and the record exist, then it is erased
# @group   provisioning
# @see     stage conf add
#@end
___stage_conf_drop2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage conf exists '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage conf erase '$1' '$2'"
}

#@help __stage_conf_exists2
# @command stage conf exists <stage> <key>
# @summary The conf record of the stage is there: a comment line, else an error line
# @group   provisioning
# @internal
# @see     stage conf drop
#@end
__stage_conf_exists2() {
        if test -f "$ELEBAKE_BASE/stage/$1/conf/$2"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'conf $2 of $1 recorded'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'no conf $2 of $1'"
        fi
}

#@help _stage_conf_erase2
# @command stage conf erase <stage> <key>
# @summary Act terminal: remove conf/<key> of the stage
# @group   provisioning
# @internal
# @see     stage conf drop
#@end
_stage_conf_erase2() {
        printf '%s\n' "$MODIFY_FILE_REMOVE '$ELEBAKE_BASE/stage/$1/conf/$2'"
        emit_note "conf $2 of $1 dropped"
}

#@help ___stage_conf_show1
# @command stage conf show <stage> [<key>]
# @summary Show the stage's loader.trust.* values (or one) as the lines loaderconf mk would write: one 'stage conf show <stage> <key>' per record; none is a note
# @group   provisioning
# @example elebake stage conf show daily-v1
# @see     stage conf add
#@end
___stage_conf_show1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        local f="" lines=0
        for f in "$ELEBAKE_BASE/stage/$1"/conf/*; do
                [ -f "$f" ] || continue
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage conf show '$1' '${f##*/}'"
                lines=$((lines + 1))
        done
        test "$lines" -gt 0 || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log 'no conf of $1 -- stage conf add $1 <key> <value>'"
}

#@help ___stage_conf_show2
# @internal 2-arg sibling of 'stage conf show': the record exists, then its loader.conf line
#@end
___stage_conf_show2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage conf exists '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage conf render show '$1' '$2'"
}

#@help _stage_conf_render_show2
# @command stage conf render show <stage> <key>
# @summary Print one conf value as its loader.conf line, prefixed
# @group   provisioning
# @internal
# @see     stage conf show
#@end
_stage_conf_render_show2() {
        printf '# %s="%s"\n' "$2" "$(sed -n 1p "$ELEBAKE_BASE/stage/$1/conf/$2" 2>/dev/null)"
}

#@help ___stage_dump_conf1
# @internal dump block (cat-pinned): one 'stage conf add' replay per record
#@end
___stage_dump_conf1() {
        local f=""
        for f in "$ELEBAKE_BASE/stage/$1"/conf/*; do
                [ -f "$f" ] || continue
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage conf add '$1' '${f##*/}' $(sq "$(sed -n 1p "$f" 2>/dev/null)")"
        done
}

#@help ___stage_require1
# @command stage require <stage>
# @summary Report what the stage's BOUND loader policies demand: the loader.trust.<gate>.<leaf> keys the actions read at boot (parsed from the kenv(a, ...) calls in the checkout's action.c, attributed per gate), each with its conf record or MISSING; then the LOADER_TRUST_* baselines the measurements and actions consume without a code default, each ok or MISSING. With a container argument: the demands of that container's bound measurements on the boot tree
# @group   provisioning
# @example elebake stage require daily-v1
# @see     stage conf add
# @see     stage loaderconf mk
# @see     stage requirements ensure earlboot
#@end
___stage_require1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage checkout exists '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log 'require of $1 (bound actions -> kenv leafs)'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage leafs '$1' demand"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log 'baselines the bound measurements and actions demand (no default in the code):'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage baselines report '$1'"
}

#@help ___stage_leafs2
# @command stage leafs <stage> <require|demand>
# @summary Every phase of the stage with a policy record: 'stage phase leafs <stage> <phase> <verb>' -- require ends in an error line at a missing conf value, demand in a note
# @group   provisioning
# @internal
# @see     stage require
# @see     stage loaderconf mk
#@end
___stage_leafs2() {
        local f="" lines=0
        for f in "$ELEBAKE_BASE/stage/$1"/phases/*; do
                [ -f "$f" ] || continue
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage phase leafs '$1' '${f##*/}' '$2'"
                lines=$((lines + 1))
        done
        test "$lines" -gt 0 || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'stage $1 binds nothing: no leaf demanded'"
}

#@help ___stage_phase_leafs3
# @command stage phase leafs <stage> <phase> <require|demand>
# @summary Every policy the phase binds: 'stage policy leafs <stage> <policy> <verb>'
# @group   provisioning
# @internal
# @see     stage leafs
#@end
___stage_phase_leafs3() {
        local p="" lines=0
        while read -r p; do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage policy leafs '$1' '$p' '$3'"
                lines=$((lines + 1))
        done 2>/dev/null < "$ELEBAKE_BASE/stage/$1/phases/$2"
        test "$lines" -gt 0 || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'phase $2 of stage $1 binds no policy'"
}

#@help ___stage_policy_leafs3
# @command stage policy leafs <stage> <policy> <require|demand>
# @summary The policy's gate and every trigger it lists: 'stage trigger leafs <stage> <gate> <trigger> <verb>'
# @group   provisioning
# @internal
# @see     stage phase leafs
#@end
___stage_policy_leafs3() {
        local gate="" t="" lines=0
        gate=$(sed -n "s/^gate //p" "$ELEBAKE_BASE/foundation/policies/$2" 2>/dev/null)
        sed -n "s/^trigger //p" "$ELEBAKE_BASE/foundation/policies/$2" 2>/dev/null | while read -r t; do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage trigger leafs '$1' '$gate' '$t' '$3'"
        done
        grep -qs "^trigger " "$ELEBAKE_BASE/foundation/policies/$2" || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'policy $2 fires no trigger: no leaf demanded'"
}

#@help __stage_trigger_leafs4
# @command stage trigger leafs <stage> <gate> <trigger> <require|demand>
# @summary The trigger's action: rewrite to 'stage action leafs <stage> <gate> <action> <verb>'
# @group   provisioning
# @internal
# @see     stage policy leafs
#@end
__stage_trigger_leafs4() {
        local when="" action=""
        read -r when action 2>/dev/null < "$ELEBAKE_BASE/foundation/triggers/$3"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage action leafs '$1' '$2' '$action' '$4'"
}

#@help ___stage_action_leafs4
# @command stage action leafs <stage> <gate> <action> <require|demand>
# @summary Every kenv leaf the action reads (template/awk/action-leafs.awk over the checkout's action.c, the action_<name>() body): 'stage conf <verb> <stage> <gate> <action> <leaf>'; an action reading none says so
# @env     ELEBAKE_TEMPLATE_DIR  the template directory (awk programs, tables)
# @group   provisioning
# @internal
# @see     stage conf demand
# @see     stage conf require
#@end
___stage_action_leafs4() {
        local leaf="" lines=0
        awk -v action="${3%_act}" -f "$ELEBAKE_TEMPLATE_DIR/awk/action-leafs.awk" "$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local/action.c" 2>/dev/null | while read -r leaf; do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage conf '$4' '$1' '$2' '$3' '$leaf'"
        done
        awk -v action="${3%_act}" -f "$ELEBAKE_TEMPLATE_DIR/awk/action-leafs.awk" "$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local/action.c" 2>/dev/null | grep -q . || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'action $3 reads no kenv leaf'"
}

#@help __stage_conf_demand4
# @command stage conf demand <stage> <gate> <action> <leaf>
# @summary The stage has a conf record for loader.trust.<gate>.<leaf>: a note with the value, else a note MISSING with the remedy
# @group   provisioning
# @internal
# @see     stage action leafs
#@end
__stage_conf_demand4() {
        if test -f "$ELEBAKE_BASE/stage/$1/conf/loader.trust.$2.$4"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log '  loader.trust.$2.$4  ($3)  = "$(sed -n 1p "$ELEBAKE_BASE/stage/$1/conf/loader.trust.$2.$4" 2>/dev/null)"'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log '  loader.trust.$2.$4  ($3)  MISSING -- stage conf add $1 loader.trust.$2.$4 <value>'"
        fi
}

#@help __stage_conf_require4
# @command stage conf require <stage> <gate> <action> <leaf>
# @summary The stage has a conf record for loader.trust.<gate>.<leaf>: a comment, else an error line
# @group   provisioning
# @internal
# @see     stage action leafs
#@end
__stage_conf_require4() {
        if test -f "$ELEBAKE_BASE/stage/$1/conf/loader.trust.$2.$4"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'loader.trust.$2.$4 has its value'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage loaderconf mk $1: no value for loader.trust.$2.$4 (stage conf add first; stage require lists them)'"
        fi
}

#@help ___stage_loaderconf_mk1
# @command stage loaderconf mk <stage>
# @summary Write boot/loader.trust.conf of the stage from its conf records: the stage and its checkout exist, boot/loader.conf names the file in loader_conf_files (stage edit adds it), every leaf a bound action reads has its value (stage require), then the file is written. It rides on the medium in clear, the manifest covers it (stage manifest after this)
# @group   provisioning
# @example elebake stage loaderconf mk daily-v1
# @see     stage require
# @see     stage loaderconf check
#@end
___stage_loaderconf_mk1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage checkout exists '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage loaderconf named '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage leafs '$1' require"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage loaderconf write '$1'"
}

#@help __stage_loaderconf_named1
# @command stage loaderconf named <stage>
# @summary boot/loader.conf of the stage names loader.trust.conf in loader_conf_files: a comment line, else an error line
# @group   provisioning
# @internal
# @see     stage loaderconf mk
#@end
__stage_loaderconf_named1() {
        if grep -qs "loader_conf_files=.*loader\.trust\.conf" "$ELEBAKE_BASE/stage/$1/boot/loader.conf"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'loader.conf of $1 names loader.trust.conf'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage loaderconf mk $1: boot/loader.conf must name the file: loader_conf_files="/boot/loader.trust.conf" (stage edit $1 loader.conf)'"
        fi
}

#@help _stage_loaderconf_write1
# @command stage loaderconf write <stage>
# @summary Act terminal: the script that writes boot/loader.trust.conf.new from the conf records (one key="value" per record, byte order, deterministic) and moves it into place, mode 0644
# @group   provisioning
# @internal
# @see     stage loaderconf mk
#@end
_stage_loaderconf_write1() {
        cat <<EOF
{ printf '# generated by elebake stage loaderconf mk -- do not edit\\n'; for f in '$ELEBAKE_BASE/stage/$1'/conf/*; do test -f "\$f" && printf '%s="%s"\\n' "\${f##*/}" "\$(sed -n 1p "\$f")"; done; } > '$ELEBAKE_BASE/stage/$1/boot/loader.trust.conf.new'
mv '$ELEBAKE_BASE/stage/$1/boot/loader.trust.conf.new' '$ELEBAKE_BASE/stage/$1/boot/loader.trust.conf' && chmod 0644 '$ELEBAKE_BASE/stage/$1/boot/loader.trust.conf'
printf '# loader.trust.conf of %s written -- stage manifest, sign, push to arm it\\n' '$1' >&2
EOF
}

#@help ___stage_loaderconf_check1
# @command stage loaderconf check <stage>
# @summary Regenerate loader.trust.conf from the conf records and compare with the stage's boot/loader.trust.conf: drift per key is reported, agreement is one line -- the conf under tamper detection
# @group   provisioning
# @example elebake stage loaderconf check daily-v1
# @see     stage loaderconf mk
#@end
___stage_loaderconf_check1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage loaderconf exists '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage loaderconf compare '$1'"
}

#@help __stage_loaderconf_exists1
# @command stage loaderconf exists <stage>
# @summary boot/loader.trust.conf of the stage is there: a comment line, else an error line
# @group   provisioning
# @internal
# @see     stage loaderconf check
#@end
__stage_loaderconf_exists1() {
        if test -f "$ELEBAKE_BASE/stage/$1/boot/loader.trust.conf"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'loader.trust.conf of $1 written'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage loaderconf check $1: no boot/loader.trust.conf (stage loaderconf mk first)'"
        fi
}

#@help _stage_loaderconf_compare1
# @command stage loaderconf compare <stage>
# @summary Act terminal: the script that renders the records to a temporary file and compares it with boot/loader.trust.conf (agreement one line, drift as a diff: - medium, + database)
# @group   provisioning
# @internal
# @see     stage loaderconf check
#@end
_stage_loaderconf_compare1() {
        cat <<EOF
t=\$(mktemp) || exit 1
{ printf '# generated by elebake stage loaderconf mk -- do not edit\\n'; for f in '$ELEBAKE_BASE/stage/$1'/conf/*; do test -f "\$f" && printf '%s="%s"\\n' "\${f##*/}" "\$(sed -n 1p "\$f")"; done; } > "\$t"
if cmp -s "\$t" '$ELEBAKE_BASE/stage/$1/boot/loader.trust.conf'; then printf '# loaderconf of %s: agrees with the records\\n' '$1'; else printf '# loaderconf DRIFT of %s (- medium, + database):\\n' '$1'; diff '$ELEBAKE_BASE/stage/$1/boot/loader.trust.conf' "\$t" | sed 's/^/#   /'; fi
rm -f "\$t"
EOF
}

#@help ___stage_require2
# @internal arity-2 sibling of 'stage require' (stage require <stage> <container>): Report what the container's bound measurements demand of the stage's boot tree (measure_bootlock: loader.conf mac_bootlock_load="YES" and boot/kernel/mac_bootlock.ko, the module the loader preloads from the manifest-covered tree), each ok or MISSING with its remedy; 'stage earlboot|elvbootd mk' refuse while one is MISSING
#@end
___stage_require2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage checkout exists '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log 'require of $1 for $2 (bound measurements -> boot tree)'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage requirements report '$2' '$1'"
}

