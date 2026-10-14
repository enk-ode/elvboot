#!/bin/sh
#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Dr. Johannes Brügmann
#
# quarantine.sh -- the quarantine system of a stage: the decoy root the
# loader diverts to on the duress way (zempty), built on the owner's
# machine as a ZFS dataset like the rescue, sent into a GELI container on
# an internal disk the TPM's file alone opens -- a defined content, a
# snapshot, a signed baseline, a witness. Nothing of the owner lies in it:
# the base set from the owner's repository, no kernel (the medium's,
# verified, boots it), no boot code on its disk, a random root password,
# no user, no sshd, securelevel 2, and the guard rc.d geomcheck that
# distrusts the chain it was booted by (every foreign pool exported, every
# idle GELI provider detached, tpm.ko unloaded, before anything else runs).
#
# The stage describes it, records under stage/<stage>/quarantine/:
#
#   quarantine/dataset    the build root on the production pool
#                         (zroot/ROOT/zempty), mountpoint /, canmount noauto;
#                         its basename is the name on the container's pool
#   quarantine/pool       the container's pool (zempty)
#   quarantine/partition  the container's partition (nda1p1), one, internal
#   quarantine/keyfile    the name of the TPM's file on the RAM disk
#                         (zempty.bin): the seed writes it there (workflow
#                         quarantine), geli opens the container with it alone
#   quarantine/swap       the swap device of the quarantine's fstab, optional
#                         (/dev/gpt/illyria-swap.eli): the production's swap,
#                         which the quarantine may use (geli onetime)
#   quarantine/rc         the lines of /etc/rc.conf, name="value" each: the
#                         whole configuration -- there is no rc.conf to
#                         mirror, the quarantine is nobody's system
#   quarantine/snapshot   the last snapshot taken (observation, not replayed)
#   quarantine/received   the snapshot the container holds (observation)
#   quarantine/baseline/  MANIFEST and MANIFEST.asc of the built root
#
# The build fills the opened root in phases -- package install (the base
# set through pkg --rootdir, the one bootstrap an empty root allows),
# rc write, frame write (fstab, localtime, the console insecure so single
# user asks the password, the root password random), guard write (the
# template quarantine/geomcheck into /etc/rc.d), baseline -- and the
# snapshot closes it. The push opens the container with the TPM's file,
# sends the snapshot (the whole tree the first time, the increment after),
# sets bootfs and readonly, proves the GUID, records the receipt and
# closes. Read-only root: a session leaves nothing; tmpmfs and varmfs in
# the rc lines give it /tmp and /var in memory. After every push the
# witness of the container moves (stage witness measure, conf, anchor).
# Pins: the acts that touch zfs, geli, pkg and the root run as root (sudo
# sh); the records as the owner (sh).

#@help ___stage_quarantine_dataset_add2
# @command stage quarantine dataset add <stage> <dataset>
# @completion dataset none
# @summary Record the quarantine's build root dataset (zroot/ROOT/zempty, a boot environment on the production pool whose basename names the root on the container's pool): the stage exists, the name is a ZFS dataset name; then written (immutable: identical re-add is a no-op, a differing one is refused -- drop first)
# @group   deploy
# @example elebake stage quarantine dataset add daily-v1 zroot/ROOT/zempty
# @see     stage quarantine dataset make
#@end
___stage_quarantine_dataset_add2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine name valid dataset '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine value write '$1' dataset '$2'"
}

#@help ___stage_quarantine_dataset_drop1
# @command stage quarantine dataset drop <stage>
# @summary Forget the build root record of the stage (the dataset itself stays): the stage exists and has the record; then it is removed
# @group   provisioning
# @example elebake stage quarantine dataset drop daily-v1
# @see     stage quarantine dataset add
#@end
___stage_quarantine_dataset_drop1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine value set '$1' dataset"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine value erase '$1' dataset"
}

#@help ___stage_quarantine_pool_add2
# @command stage quarantine pool add <stage> <pool>
# @completion pool none
# @summary Record the name of the container's pool (zempty): the stage exists, the name is a ZFS pool name; then written (immutable, drop first to change)
# @group   provisioning
# @example elebake stage quarantine pool add daily-v1 zempty
# @see     stage quarantine container init
#@end
___stage_quarantine_pool_add2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine name valid pool '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine value write '$1' pool '$2'"
}

#@help ___stage_quarantine_pool_drop1
# @command stage quarantine pool drop <stage>
# @summary Forget the pool name record of the stage: the stage exists and has the record; then it is removed
# @group   provisioning
# @example elebake stage quarantine pool drop daily-v1
# @see     stage quarantine pool add
#@end
___stage_quarantine_pool_drop1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine value set '$1' pool"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine value erase '$1' pool"
}

#@help ___stage_quarantine_partition_add2
# @command stage quarantine partition add <stage> <partition>
# @completion partition none
# @summary Record the container's partition (nda1p1, an internal disk of the machine): the stage exists, the name is a GPT partition name; then written (immutable, drop first to change)
# @group   provisioning
# @example elebake stage quarantine partition add daily-v1 nda1p1
# @see     stage quarantine container init
#@end
___stage_quarantine_partition_add2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine partition valid '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine value write '$1' partition '$2'"
}

#@help ___stage_quarantine_partition_drop1
# @command stage quarantine partition drop <stage>
# @summary Forget the partition record of the stage: the stage exists and has the record; then it is removed
# @group   provisioning
# @example elebake stage quarantine partition drop daily-v1
# @see     stage quarantine partition add
#@end
___stage_quarantine_partition_drop1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine value set '$1' partition"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine value erase '$1' partition"
}

#@help __stage_quarantine_partition_valid1
# @command stage quarantine partition valid <partition>
# @completion partition none
# @summary The name is a GPT partition name (<disk><n>p<m>): a comment line, else an error line
# @group   provisioning
# @internal
# @see     stage quarantine partition add
#@end
__stage_quarantine_partition_valid1() {
        if printf '%s\n' "$1" | grep -qx '[a-z][a-z]*[0-9][0-9]*p[0-9][0-9]*'; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'quarantine partition $1 is a GPT partition name'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage quarantine partition add: not a GPT partition name (<disk><n>p<m>): $1'"
        fi
}

#@help ___stage_quarantine_keyfile_add2
# @command stage quarantine keyfile add <stage> <name>
# @completion name none
# @summary Record the name of the TPM's file on the RAM disk (zempty.bin) that opens the container alone -- the seed writes it there before init, open and push (workflow quarantine): the stage exists, the name is a file name without a slash; then written (immutable, drop first to change)
# @group   provisioning
# @example elebake stage quarantine keyfile add daily-v1 zempty.bin
# @see     stage quarantine container open
#@end
___stage_quarantine_keyfile_add2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine name valid keyfile '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine value write '$1' keyfile '$2'"
}

#@help ___stage_quarantine_keyfile_drop1
# @command stage quarantine keyfile drop <stage>
# @summary Forget the key file name record of the stage: the stage exists and has the record; then it is removed
# @group   provisioning
# @example elebake stage quarantine keyfile drop daily-v1
# @see     stage quarantine keyfile add
#@end
___stage_quarantine_keyfile_drop1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine value set '$1' keyfile"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine value erase '$1' keyfile"
}

#@help ___stage_quarantine_swap_add2
# @command stage quarantine swap add <stage> <device>
# @completion device none
# @summary Record the swap device of the quarantine's fstab (/dev/gpt/illyria-swap.eli: the production's swap, geli onetime, usable by a system that holds no key of its own): the stage exists, the device is an absolute path; then written (immutable, drop first to change)
# @group   provisioning
# @example elebake stage quarantine swap add daily-v1 /dev/gpt/illyria-swap.eli
# @see     stage quarantine frame write
#@end
___stage_quarantine_swap_add2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine name valid swap '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine value write '$1' swap '$2'"
}

#@help ___stage_quarantine_swap_drop1
# @command stage quarantine swap drop <stage>
# @summary Forget the swap device record of the stage: the stage exists and has the record; then it is removed
# @group   provisioning
# @example elebake stage quarantine swap drop daily-v1
# @see     stage quarantine swap add
#@end
___stage_quarantine_swap_drop1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine value set '$1' swap"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine value erase '$1' swap"
}

#@help __stage_quarantine_name_valid2
# @command stage quarantine name valid <dataset|pool|keyfile|swap> <name>
# @completion name none
# @summary A dataset or pool name is a ZFS name (letters, digits, _ . - and, for a dataset, /), a keyfile name a file name without a slash or blank, a swap device an absolute path: a comment line, else an error line
# @group   provisioning
# @internal
# @see     stage quarantine dataset add
#@end
__stage_quarantine_name_valid2() {
        local form="" what=""
        case "$1" in
                dataset) form='[A-Za-z][A-Za-z0-9_.-]*\(/[A-Za-z0-9_.-][A-Za-z0-9_.-]*\)*'; what='ZFS dataset name' ;;
                pool)    form='[A-Za-z][A-Za-z0-9_.-]*'; what='ZFS pool name' ;;
                keyfile) form='[A-Za-z0-9_.-][A-Za-z0-9_.-]*'; what='file name (no slash, no blank)' ;;
                *)       form='/[^ 	][^ 	]*'; what='absolute path' ;;
        esac
        if printf '%s\n' "$2" | grep -qx "$form"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'quarantine $1 $2 has the form'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage quarantine $1 add: not a $what: $2'"
        fi
}

#@help __stage_quarantine_value_write3
# @command stage quarantine value write <stage> <record> <value>
# @completion record none
# @completion value none
# @summary The record exists: rewrite to 'stage quarantine value rewrite' (identical no-op, differing refused), else 'stage quarantine value record'
# @group   provisioning
# @internal
# @see     stage quarantine dataset add
#@end
__stage_quarantine_value_write3() {
        if test -f "$ELEBAKE_BASE/stage/$1/quarantine/$2"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine value rewrite '$1' '$2' '$3'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine value record '$1' '$2' '$3'"
        fi
}

#@help __stage_quarantine_value_rewrite3
# @command stage quarantine value rewrite <stage> <record> <value>
# @completion record none
# @completion value none
# @summary An existing record with the identical value is a no-op (a note); a different one is refused -- drop first
# @group   provisioning
# @internal
# @see     stage quarantine value write
#@end
__stage_quarantine_value_rewrite3() {
        if test "$(sed -n 1p "$ELEBAKE_BASE/stage/$1/quarantine/$2" 2>/dev/null)" = "$3"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" note 'quarantine $2 of $1 already recorded (unchanged)'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage quarantine $2 add: $1 has a different $2 (immutable; stage quarantine $2 drop first)'"
        fi
}

#@help _stage_quarantine_value_record3
# @command stage quarantine value record <stage> <record> <value>
# @completion record none
# @completion value none
# @summary Act terminal: write quarantine/<record> of the stage (one line), directory 0700, file 0600
# @group   provisioning
# @internal
# @see     stage quarantine value write
#@end
_stage_quarantine_value_record3() {
        printf '%s\n' "$MODIFY_DIR_CREATE '$ELEBAKE_BASE/stage/$1/quarantine'"
        printf '%s\n' "$MODIFY_FILE_PERMS 0700 '$ELEBAKE_BASE/stage/$1/quarantine'"
        printf '%s\n' "printf '%s\\n' $(sq "$3") > '$ELEBAKE_BASE/stage/$1/quarantine/$2'"
        printf '%s\n' "$MODIFY_FILE_PERMS 0600 '$ELEBAKE_BASE/stage/$1/quarantine/$2'"
        emit_note "quarantine $2 of $1: $3"
}

#@help __stage_quarantine_value_set2
# @command stage quarantine value set <stage> <record>
# @completion record none
# @summary The stage has the quarantine record (dataset, pool, partition, keyfile, swap, snapshot): a comment line, else an error line naming the command that records it
# @group   provisioning
# @internal
# @see     stage quarantine dataset add
#@end
__stage_quarantine_value_set2() {
        if test -s "$ELEBAKE_BASE/stage/$1/quarantine/$2"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'quarantine $2 of $1: $(sed -n 1p "$ELEBAKE_BASE/stage/$1/quarantine/$2")'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage $1 has no quarantine $2 (stage quarantine $2 add $1 <$2>, or stage quarantine snapshot $1 for the snapshot)'"
        fi
}

#@help _stage_quarantine_value_erase2
# @command stage quarantine value erase <stage> <record>
# @completion record none
# @summary Act terminal: remove quarantine/<record> of the stage
# @group   provisioning
# @internal
# @see     stage quarantine dataset drop
#@end
_stage_quarantine_value_erase2() {
        printf '%s\n' "$MODIFY_FILE_REMOVE '$ELEBAKE_BASE/stage/$1/quarantine/$2'"
        emit_note "quarantine $2 of $1 dropped"
}

#@help ___stage_quarantine_rc_add2
# @command stage quarantine rc add <stage> <line>
# @completion line none
# @summary Add a line of the quarantine's /etc/rc.conf (name="value": hostname, zfs_enable, sshd_enable="NO", kern_securelevel="2", devmatch_enable="NO", dumpdev="NO", tmpmfs="YES", varmfs="YES" -- the whole configuration, the quarantine mirrors no rc.conf): the stage exists, the line has the form; then appended once
# @group   provisioning
# @example elebake stage quarantine rc add daily-v1 'sshd_enable="NO"'
# @see     stage quarantine rc write
#@end
___stage_quarantine_rc_add2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine rc valid $(sq "$2")"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine entry write '$1' rc $(sq "$2")"
}

#@help ___stage_quarantine_rc_drop2
# @command stage quarantine rc drop <stage> <line>
# @completion line none
# @summary Remove a line from the quarantine's rc list: the stage exists, the line is listed; then it is removed
# @group   provisioning
# @example elebake stage quarantine rc drop daily-v1 'sshd_enable="NO"'
# @see     stage quarantine rc add
#@end
___stage_quarantine_rc_drop2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine entry listed '$1' rc $(sq "$2")"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine entry unlink '$1' rc $(sq "$2")"
}

#@help __stage_quarantine_rc_valid1
# @command stage quarantine rc valid <line>
# @completion line none
# @summary The line is an rc.conf line, name="value": a comment line, else an error line
# @group   provisioning
# @internal
# @see     stage quarantine rc add
#@end
__stage_quarantine_rc_valid1() {
        if printf '%s\n' "$1" | grep -qx '[A-Za-z_][A-Za-z0-9_]*="[^"]*"'; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'quarantine rc line has the form'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage quarantine rc add: not an rc.conf line (name=\"value\"): $1'"
        fi
}

#@help __stage_quarantine_entry_write3
# @command stage quarantine entry write <stage> <rc> <entry>
# @completion rc none
# @completion entry none
# @summary The list holds the entry already: a note; else 'stage quarantine entry append'
# @group   provisioning
# @internal
# @see     stage quarantine rc add
#@end
__stage_quarantine_entry_write3() {
        if grep -qxsF "$3" "$ELEBAKE_BASE/stage/$1/quarantine/$2"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" note 'quarantine $2 of $1 already list $3'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine entry append '$1' '$2' $(sq "$3")"
        fi
}

#@help _stage_quarantine_entry_append3
# @command stage quarantine entry append <stage> <rc> <entry>
# @completion rc none
# @completion entry none
# @summary Act terminal: append the entry to quarantine/<list> of the stage, directory 0700, file 0600
# @group   provisioning
# @internal
# @see     stage quarantine entry write
#@end
_stage_quarantine_entry_append3() {
        printf '%s\n' "$MODIFY_DIR_CREATE '$ELEBAKE_BASE/stage/$1/quarantine'"
        printf '%s\n' "$MODIFY_FILE_PERMS 0700 '$ELEBAKE_BASE/stage/$1/quarantine'"
        printf '%s\n' "printf '%s\\n' $(sq "$3") >> '$ELEBAKE_BASE/stage/$1/quarantine/$2'"
        printf '%s\n' "$MODIFY_FILE_PERMS 0600 '$ELEBAKE_BASE/stage/$1/quarantine/$2'"
        emit_note "quarantine $2 of $1: + $3"
}

#@help __stage_quarantine_entry_listed3
# @command stage quarantine entry listed <stage> <rc> <entry>
# @completion rc none
# @completion entry none
# @summary The list of the stage holds the entry: a comment line, else an error line
# @group   provisioning
# @internal
# @see     stage quarantine rc drop
#@end
__stage_quarantine_entry_listed3() {
        if grep -qxsF "$3" "$ELEBAKE_BASE/stage/$1/quarantine/$2"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'quarantine $2 of $1 list $3'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage quarantine $2 drop: not listed: $3'"
        fi
}

#@help _stage_quarantine_entry_unlink3
# @command stage quarantine entry unlink <stage> <rc> <entry>
# @completion rc none
# @completion entry none
# @summary Act terminal: remove the entry's line from quarantine/<list> of the stage
# @group   provisioning
# @internal
# @see     stage quarantine rc drop
#@end
_stage_quarantine_entry_unlink3() {
        printf '%s\n' "grep -vxF $(sq "$3") '$ELEBAKE_BASE/stage/$1/quarantine/$2' > '$ELEBAKE_BASE/stage/$1/quarantine/$2.new'; mv -f '$ELEBAKE_BASE/stage/$1/quarantine/$2.new' '$ELEBAKE_BASE/stage/$1/quarantine/$2'"
        emit_note "quarantine $2 of $1: - $3"
}

#@help __stage_quarantine_list_filled1
# @command stage quarantine list filled <stage>
# @summary The rc list of the stage has at least one line: a comment line, else an error line (stage quarantine rc add)
# @group   provisioning
# @internal
# @see     stage quarantine rc write
#@end
__stage_quarantine_list_filled1() {
        if grep -qs . "$ELEBAKE_BASE/stage/$1/quarantine/rc"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'quarantine rc of $1: $(grep -c . "$ELEBAKE_BASE/stage/$1/quarantine/rc") lines'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage $1: no quarantine rc lines (stage quarantine rc add $1 <line>)'"
        fi
}

#@help ___stage_quarantine_show1
# @command stage quarantine show <stage>
# @summary The quarantine description of the stage as notes: dataset, pool, partition, key file name, swap, the rc lines, the last snapshot and what the container received; the stage exists
# @group   provisioning
# @example elebake stage quarantine show daily-v1
# @see     stage quarantine verify
#@end
___stage_quarantine_show1() {
        local f="" line=""
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log '# quarantine of $1'"
        for f in dataset pool partition keyfile swap snapshot received; do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log '#   $f: $(sed -n 1p "$ELEBAKE_BASE/stage/$1/quarantine/$f" 2>/dev/null)'"
        done
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log '#   rc ($(grep -c . "$ELEBAKE_BASE/stage/$1/quarantine/rc" 2>/dev/null) lines):'"
        grep . "$ELEBAKE_BASE/stage/$1/quarantine/rc" 2>/dev/null | while IFS= read -r line; do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log $(sq "#     $line")"
        done
        line=$(grep -c . "$ELEBAKE_BASE/stage/$1/quarantine/baseline/MANIFEST" 2>/dev/null)
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log '#   baseline: ${line:-0} entries$(test -s "$ELEBAKE_BASE/stage/$1/quarantine/baseline/MANIFEST.asc" && printf ', signed')'"
}

#@help ___stage_dump_quarantine1
# @command stage dump quarantine <stage>
# @summary Dump block: the quarantine description replayed -- dataset, pool, partition, keyfile and swap add, one rc add per line; the snapshot, the receipt and the baseline are built or read, not replayed
# @group   provisioning
# @internal
# @see     stage dump
# @see     stage quarantine show
#@end
___stage_dump_quarantine1() {
        local r="" f=""
        for r in dataset pool partition keyfile swap; do
                test -s "$ELEBAKE_BASE/stage/$1/quarantine/$r" && printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine $r add '$1' '$(sed -n 1p "$ELEBAKE_BASE/stage/$1/quarantine/$r")'"
        done
        grep . "$ELEBAKE_BASE/stage/$1/quarantine/rc" 2>/dev/null | while IFS= read -r f; do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine rc add '$1' $(sq "$f")"
        done
        :
}

#@help ___stage_quarantine_dataset_make1
# @command stage quarantine dataset make <stage>
# @summary Create the build root on the production pool, empty: the stage exists, the dataset is recorded; then 'stage quarantine dataset create' (mountpoint / and canmount noauto -- a boot environment nothing mounts by itself; the base set fills it)
# @group   deploy
# @example elebake stage quarantine dataset make daily-v1
# @see     stage quarantine dataset open
#@end
___stage_quarantine_dataset_make1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine value set '$1' dataset"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine dataset create '$1'"
}

#@help _stage_quarantine_dataset_create1
# @command stage quarantine dataset create <stage>
# @summary Act terminal (root): zfs create of <dataset> (mountpoint /, canmount noauto, lz4, atime off); an existing dataset is kept
# @group   deploy
# @internal
#@end
_stage_quarantine_dataset_create1() {
        local ds=""
        ds=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/quarantine/dataset" 2>/dev/null)
        emit_note "stage quarantine dataset make '$1': $ds (mountpoint /, canmount noauto)"
        printf '%s\n' "zfs list -H '$ds' >/dev/null 2>&1 || zfs create -o mountpoint=/ -o canmount=noauto -o compression=lz4 -o atime=off '$ds' || exit 1"
        printf '%s\n' "zfs list -o name,mountpoint,canmount '$ds'"
}

#@help ___stage_quarantine_dataset_open1
# @command stage quarantine dataset open <stage>
# @summary Mount the build root for editing under $ELEBAKE_ROOT/mnt/<stage>-quarantine (mount -t zfs, so the mountpoint property stays /), devfs below it: the stage exists, the dataset is recorded, nothing is mounted there yet; then 'stage quarantine dataset mount'
# @group   provisioning
# @example elebake stage quarantine dataset open daily-v1
# @see     stage quarantine dataset close
# @see     stage quarantine build
#@end
___stage_quarantine_dataset_open1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine value set '$1' dataset"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine dataset closed '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine dataset mount '$1'"
}

#@help __stage_quarantine_dataset_closed1
# @command stage quarantine dataset closed <stage>
# @summary Nothing is mounted at the stage's quarantine mount point: a comment line, else an error line (stage quarantine dataset close)
# @group   provisioning
# @internal
# @see     stage quarantine dataset open
#@end
__stage_quarantine_dataset_closed1() {
        if mount | grep -q " on $ELEBAKE_ROOT/mnt/$1-quarantine "; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage quarantine dataset open: $ELEBAKE_ROOT/mnt/$1-quarantine is mounted (stage quarantine dataset close $1 first)'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'quarantine mount point of $1 is free'"
        fi
}

#@help __stage_quarantine_dataset_mounted1
# @command stage quarantine dataset mounted <stage>
# @summary The build root is mounted at $ELEBAKE_ROOT/mnt/<stage>-quarantine: a comment line, else an error line (stage quarantine dataset open)
# @group   provisioning
# @internal
# @see     stage quarantine dataset open
#@end
__stage_quarantine_dataset_mounted1() {
        if mount | grep -q " on $ELEBAKE_ROOT/mnt/$1-quarantine "; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'quarantine root of $1 mounted at $ELEBAKE_ROOT/mnt/$1-quarantine'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage $1: quarantine root not mounted (stage quarantine dataset open $1)'"
        fi
}

#@help _stage_quarantine_dataset_mount1
# @command stage quarantine dataset mount <stage>
# @summary Act terminal (root): mkdir of the mount point, mount -t zfs of <dataset> there, devfs below it
# @group   provisioning
# @internal
# @see     stage quarantine dataset open
#@end
_stage_quarantine_dataset_mount1() {
        local ds="" alt=""
        ds=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/quarantine/dataset" 2>/dev/null)
        alt="$ELEBAKE_ROOT/mnt/$1-quarantine"
        emit_note "stage quarantine dataset open '$1': $ds on $alt"
        printf '%s\n' "$MODIFY_DIR_CREATE '$alt'"
        printf '%s\n' "mount -t zfs '$ds' '$alt' || exit 1"
        printf '%s\n' "$MODIFY_DIR_CREATE '$alt/dev'"
        printf '%s\n' "mount -t devfs devfs '$alt/dev' || exit 1"
}

#@help ___stage_quarantine_dataset_close1
# @command stage quarantine dataset close <stage>
# @summary Unmount the build root and its devfs: the stage exists, the root is mounted; then 'stage quarantine dataset umount'
# @group   provisioning
# @example elebake stage quarantine dataset close daily-v1
# @see     stage quarantine dataset open
#@end
___stage_quarantine_dataset_close1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine dataset mounted '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine dataset umount '$1'"
}

#@help _stage_quarantine_dataset_umount1
# @command stage quarantine dataset umount <stage>
# @summary Act terminal (root): umount of the devfs and the build root
# @group   provisioning
# @internal
# @see     stage quarantine dataset close
#@end
_stage_quarantine_dataset_umount1() {
        local alt="$ELEBAKE_ROOT/mnt/$1-quarantine"
        emit_note "stage quarantine dataset close '$1': $alt"
        printf '%s\n' "umount '$alt/dev' 2>/dev/null; umount '$alt' || exit 1"
}

#@help ___stage_quarantine_build1
# @command stage quarantine build <stage>
# @summary Build the opened quarantine root, in phases: the stage exists, the root is mounted; then 'stage quarantine package install' (the base set, no kernel), 'rc write' (/etc/rc.conf from the rc lines), 'frame write' (fstab, localtime, the console insecure, the root password random, no user), 'guard write' (rc.d geomcheck from the template), 'baseline' (the signed manifest of the tree). Then close and snapshot
# @group   deploy
# @example elebake stage quarantine build daily-v1
# @see     stage quarantine dataset open
# @see     stage quarantine snapshot
#@end
___stage_quarantine_build1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine dataset mounted '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine package install '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine rc write '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine frame write '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine guard write '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine baseline '$1'"
}

#@help ___stage_quarantine_package_install1
# @command stage quarantine package install <stage>
# @summary Install the base set into the mounted quarantine root from this machine's repositories, no kernel (the medium's, verified, boots it -- a disk without kernel and boot code boots nowhere by itself): the stage exists, the root is mounted; then 'stage quarantine package pkg'
# @group   deploy
# @example elebake stage quarantine package install daily-v1
# @see     stage quarantine build
#@end
___stage_quarantine_package_install1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine dataset mounted '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine package pkg '$1'"
}

#@help _stage_quarantine_package_pkg1
# @command stage quarantine package pkg <stage>
# @summary Act terminal (root): the repository fingerprints copied under the root, pkg --rootdir update and install of FreeBSD-set-base (the bootstrap an empty root allows; no meta package, no tools, no kernel), then pkg --rootdir clean; the installed set listed
# @group   deploy
# @internal
#@end
_stage_quarantine_package_pkg1() {
        local alt="$ELEBAKE_ROOT/mnt/$1-quarantine"
        emit_note "stage quarantine package install '$1': FreeBSD-set-base into $alt, no kernel"
        printf '%s\n' "$MODIFY_DIR_CREATE '$alt/usr/share/keys'"
        printf '%s\n' "cp -a /usr/share/keys/pkg /usr/share/keys/pkgbase-* '$alt/usr/share/keys/' 2>/dev/null; :"
        printf '%s\n' "pkg --rootdir '$alt' -o REPOS_DIR=/etc/pkg,/usr/local/etc/pkg/repos update || exit 1"
        printf '%s\n' "pkg --rootdir '$alt' -o REPOS_DIR=/etc/pkg,/usr/local/etc/pkg/repos install -y FreeBSD-set-base || exit 1"
        printf '%s\n' "pkg --rootdir '$alt' -o REPOS_DIR=/etc/pkg,/usr/local/etc/pkg/repos clean -ay >/dev/null 2>&1; :"
        printf '%s\n' "pkg --rootdir '$alt' info -q | wc -l | sed 's/^ *//; s/\$/ packages in the quarantine root/' >&2"
}

#@help ___stage_quarantine_rc_write1
# @command stage quarantine rc write <stage>
# @summary Write /etc/rc.conf of the mounted quarantine root from the rc lines: the stage exists, the root is mounted, the list is not empty; then 'stage quarantine rc file'
# @group   deploy
# @example elebake stage quarantine rc write daily-v1
# @see     stage quarantine rc add
#@end
___stage_quarantine_rc_write1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine dataset mounted '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine list filled '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine rc file '$1'"
}

#@help _stage_quarantine_rc_file1
# @command stage quarantine rc file <stage>
# @summary Act terminal (root): the heredoc that writes <quarantine root>/etc/rc.conf (0644) from the recorded lines, with a header naming the stage
# @group   deploy
# @internal
#@end
_stage_quarantine_rc_file1() {
        local alt="$ELEBAKE_ROOT/mnt/$1-quarantine"
        emit_note "stage quarantine rc write '$1': $(grep -c . "$ELEBAKE_BASE/stage/$1/quarantine/rc" 2>/dev/null) lines into $alt/etc/rc.conf"
        printf '%s\n' "cat > '$alt/etc/rc.conf' <<'ELVQRC'"
        printf '# rc.conf of the quarantine system (elebake stage quarantine rc, stage %s): the whole configuration\n' "$1"
        grep . "$ELEBAKE_BASE/stage/$1/quarantine/rc" 2>/dev/null
        printf '%s\n' "ELVQRC"
        printf '%s\n' "$MODIFY_FILE_PERMS 0644 '$alt/etc/rc.conf'"
}

#@help ___stage_quarantine_frame_write1
# @command stage quarantine frame write <stage>
# @summary Write the frame of the mounted quarantine root: the stage exists, the root is mounted; then 'stage quarantine frame file' -- fstab (the swap line when a swap device is recorded, nothing else), localtime copied from this machine, the console marked insecure in ttys (single user asks the root password, which nobody knows), the root password set to 48 random bytes nobody keeps, no other user
# @group   deploy
# @example elebake stage quarantine frame write daily-v1
# @see     stage quarantine swap add
#@end
___stage_quarantine_frame_write1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine dataset mounted '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine frame file '$1'"
}

#@help _stage_quarantine_frame_file1
# @command stage quarantine frame file <stage>
# @summary Act terminal (root): the heredoc for <root>/etc/fstab (a comment and the swap line when recorded), cp of /etc/localtime, sed of the console line in <root>/etc/ttys to insecure, chroot pw usermod root with a random password from /dev/urandom (base64 of 48 bytes, never printed, never kept)
# @group   deploy
# @internal
#@end
_stage_quarantine_frame_file1() {
        local alt="$ELEBAKE_ROOT/mnt/$1-quarantine" swap=""
        swap=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/quarantine/swap" 2>/dev/null)
        emit_note "stage quarantine frame write '$1': fstab${swap:+ (swap $swap)}, localtime, console insecure, root password random, into $alt"
        printf '%s\n' "cat > '$alt/etc/fstab' <<'ELVQFSTAB'"
        printf '%s\n' "# fstab of the quarantine root (elebake stage quarantine frame write): the root is ZFS, opened by the loader; nothing else to mount"
        test -z "$swap" || printf '%s\t\t%s\t%s\t%s\t%s %s\n' "$swap" none swap sw 0 0
        printf '%s\n' "ELVQFSTAB"
        printf '%s\n' "$MODIFY_FILE_PERMS 0644 '$alt/etc/fstab'"
        printf '%s\n' "test ! -f /etc/localtime || cp /etc/localtime '$alt/etc/localtime'"
        printf '%s\n' "sed -i '' 's/^\\(console[[:space:]].*[[:space:]]\\)secure\$/\\1insecure/' '$alt/etc/ttys' && grep '^console' '$alt/etc/ttys' >&2"
        printf '%s\n' "head -c 48 /dev/urandom | b64encode - | sed -n 2p | chroot '$alt' pw usermod root -h 0 || exit 1"
        printf '%s\n' "printf '# quarantine root of %s: root password random, no other user\\n' '$1' >&2"
}

#@help ___stage_quarantine_guard_write1
# @command stage quarantine guard write <stage>
# @summary Write the guard into the mounted quarantine root: the stage exists, the root is mounted; then 'stage quarantine guard file' -- /etc/rc.d/geomcheck from the template quarantine/geomcheck of this elebake (after mountcritlocal, before zpool, kld and zfs: every pool but the root pool exported, every GELI provider not in use detached, foreign mounts unmounted, tpm.ko unloaded), checked with sh -n and placed in rcorder
# @group   deploy
# @example elebake stage quarantine guard write daily-v1
# @see     stage quarantine build
#@end
___stage_quarantine_guard_write1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine dataset mounted '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine guard file '$1'"
}

#@help _stage_quarantine_guard_file1
# @command stage quarantine guard file <stage>
# @summary Act terminal (root): the heredoc that writes <root>/etc/rc.d/geomcheck (0555) from the template, sh -n on it inside the root, the rcorder line showing it before zpool, kld and securelevel
# @group   deploy
# @internal
# @env     ELEBAKE_TEMPLATE_DIR  where quarantine/geomcheck is read from
#@end
_stage_quarantine_guard_file1() {
        local alt="$ELEBAKE_ROOT/mnt/$1-quarantine"
        emit_note "stage quarantine guard write '$1': rc.d geomcheck (template quarantine/geomcheck) into $alt/etc/rc.d"
        printf '%s\n' "$MODIFY_DIR_CREATE '$alt/etc/rc.d'"
        printf '%s\n' "cat > '$alt/etc/rc.d/geomcheck' <<'ELVQGUARD'"
        cat "$ELEBAKE_TEMPLATE_DIR/quarantine/geomcheck"
        printf '%s\n' "ELVQGUARD"
        printf '%s\n' "$MODIFY_FILE_PERMS 0555 '$alt/etc/rc.d/geomcheck'"
        printf '%s\n' "chroot '$alt' sh -n /etc/rc.d/geomcheck || exit 1"
        printf '%s\n' "chroot '$alt' sh -c 'rcorder /etc/rc.d/*' 2>/dev/null | grep -n 'geomcheck\$\\|/zpool\$\\|/kld\$\\|securelevel\$' >&2"
}

#@help ___stage_quarantine_baseline1
# @command stage quarantine baseline <stage>
# @summary Take the baseline of the quarantine root -- the manifest of its tree (every file and symlink, LC_ALL=C sorted, 'path sha256=hash' / 'path symlink=target') signed with the pinned attest key, into stage/<stage>/quarantine/baseline/MANIFEST(.asc): the stage exists, the root is mounted, the key is pinned; then 'stage quarantine baseline write' and 'attest'
# @group   deploy
# @env     ELEBAKE_ARCHIVE_ATTEST_KEY  the pinned attest key: the baseline is signed with it
# @example elebake stage quarantine baseline daily-v1
# @see     stage quarantine verify
#@end
___stage_quarantine_baseline1() {
        local key="${ELEBAKE_ARCHIVE_ATTEST_KEY:-}"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine dataset mounted '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" archive key pinned"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine baseline write '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" attest '$ELEBAKE_BASE/stage/$1/quarantine/baseline/MANIFEST' '$key'"
}

#@help _stage_quarantine_baseline_write1
# @command stage quarantine baseline write <stage>
# @summary Act terminal (root): find -x over the mounted quarantine root (files and symlinks, one file system), each hashed, LC_ALL=C sorted into baseline/MANIFEST.new, moved into place, the directory and the file handed to the owner (0644); the count on stderr
# @group   deploy
# @internal
# @see     stage quarantine baseline
#@end
_stage_quarantine_baseline_write1() {
        local alt="$ELEBAKE_ROOT/mnt/$1-quarantine" b="$ELEBAKE_BASE/stage/$1/quarantine/baseline"
        emit_note "stage quarantine baseline '$1': the manifest of $alt into $b/MANIFEST (every file hashed now, as root)"
        printf '%s\n' "$MODIFY_DIR_CREATE '$b'"
        printf '%s\n' "cd '$alt' && find -x . \\( -type f -o -type l \\) | sed 's|^\\./||' | LC_ALL=C sort | while IFS= read -r p; do if [ -L \"\$p\" ]; then printf '%s symlink=%s\\n' \"\$p\" \"\$(readlink \"\$p\")\"; else printf '%s sha256=%s\\n' \"\$p\" \"\$(sha256 -q \"\$p\")\"; fi; done > '$b/MANIFEST.new' || exit 1"
        printf '%s\n' "mv -f '$b/MANIFEST.new' '$b/MANIFEST' && chown '$(id -un)' '$b' '$b/MANIFEST' && $MODIFY_FILE_PERMS 0644 '$b/MANIFEST' || exit 1"
        printf '%s\n' "printf '# baseline of the quarantine of %s: %s entries\\n' '$1' \"\$(grep -c . '$b/MANIFEST')\" >&2"
}

#@help __stage_quarantine_baseline_present1
# @command stage quarantine baseline present <stage>
# @summary The baseline manifest and its signature are there (stage quarantine baseline): a comment line, else an error line
# @group   deploy
# @internal
# @see     stage quarantine verify
#@end
__stage_quarantine_baseline_present1() {
        if test -s "$ELEBAKE_BASE/stage/$1/quarantine/baseline/MANIFEST" && test -s "$ELEBAKE_BASE/stage/$1/quarantine/baseline/MANIFEST.asc"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'quarantine baseline of $1: $(grep -c . "$ELEBAKE_BASE/stage/$1/quarantine/baseline/MANIFEST" 2>/dev/null) entries, signed'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage quarantine: no signed baseline for $1 (stage quarantine baseline, with the root open, before the snapshot)'"
        fi
}

#@help ___stage_quarantine_snapshot1
# @command stage quarantine snapshot <stage>
# @summary Snapshot the quarantine root (<dataset>@<stage>-<stamp>, recursive) and record the name: the stage exists, the dataset is recorded, the root is not mounted (a quiescent tree), the baseline is signed; then 'stage quarantine snapshot take' and the record
# @group   provisioning
# @example elebake stage quarantine snapshot daily-v1
# @see     stage quarantine push
#@end
___stage_quarantine_snapshot1() {
        local snap=""
        snap="$1-$(date -u +%Y%m%dT%H%M%SZ)"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine value set '$1' dataset"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine dataset closed '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine baseline present '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine snapshot take '$1' '$snap'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine value record '$1' snapshot '$snap'"
}

#@help _stage_quarantine_snapshot_take2
# @command stage quarantine snapshot take <stage> <snapshot>
# @completion snapshot none
# @summary Act terminal (root): zfs snapshot -r <dataset>@<snapshot>
# @group   provisioning
# @internal
# @see     stage quarantine snapshot
#@end
_stage_quarantine_snapshot_take2() {
        local ds=""
        ds=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/quarantine/dataset" 2>/dev/null)
        emit_note "stage quarantine snapshot '$1': $ds@$2 (recursive)"
        printf '%s\n' "zfs snapshot -r '$ds@$2' || exit 1"
}

#@help __stage_quarantine_keyfile_present1
# @command stage quarantine keyfile present <stage>
# @summary The TPM's file of the recorded name lies on the RAM disk, not empty (the seed writes it: workflow quarantine): a comment line, else an error line
# @group   deploy
# @internal
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk (default .ram under the database)
# @see     stage quarantine container open
#@end
__stage_quarantine_keyfile_present1() {
        local d="$(ram_dir)" name=""
        name=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/quarantine/keyfile" 2>/dev/null)
        if test -s "$d/$name"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'quarantine key file $d/$name present'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage quarantine: no $d/${name:-<keyfile>} on the RAM disk (elebake ram open, then the seed line of workflow quarantine)'"
        fi
}

#@help ___stage_quarantine_container_init1
# @command stage quarantine container init <stage>
# @summary Prepare the container, once: GELI on the partition (AES-XTS 256, HMAC/SHA256, BOOT, NODELETE, the TPM's file alone, no passphrase, its own master key), every sector written with zeros (HMAC needs it -- a grown provider without this writes integrity failures on every read of the new space), the pool created on it with ROOT below, exported: the stage exists, partition, pool and keyfile are recorded, the RAM disk is mounted and the file on it; then 'stage quarantine container geli' and 'container pool'
# @group   deploy
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the key file lives on (default .ram under the database)
# @example elebake stage quarantine container init daily-v1
# @see     stage quarantine push
#@end
___stage_quarantine_container_init1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine value set '$1' partition"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine value set '$1' pool"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine value set '$1' keyfile"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm workdir ready"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine keyfile present '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine container geli '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine container pool '$1'"
}

#@help _stage_quarantine_container_geli1
# @command stage quarantine container geli <stage>
# @summary Act terminal (root): geli init of the partition (-e AES-XTS -l 256 -a HMAC/SHA256 -s 4096 -b -T -P -K <file>), attach with the file alone (-p -k), dd of zeros over the whole provider (ENOSPC ends it), the provider left attached for the pool
# @group   deploy
# @internal
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the key file lives on (default .ram under the database)
#@end
_stage_quarantine_container_geli1() {
        local part="" d="$(ram_dir)" name=""
        part=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/quarantine/partition" 2>/dev/null)
        name=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/quarantine/keyfile" 2>/dev/null)
        emit_note "stage quarantine container init '$1': geli on /dev/$part ($d/$name alone, no passphrase), then zeros over the whole provider (minutes)"
        printf '%s\n' "geli init -e AES-XTS -l 256 -a HMAC/SHA256 -s 4096 -b -T -P -K '$d/$name' '/dev/$part' || exit 1"
        printf '%s\n' "geli attach -p -k '$d/$name' '/dev/$part' || exit 1"
        printf '%s\n' "dd if=/dev/zero of='/dev/$part.eli' bs=1m 2>/dev/null; geli list '$part.eli' | grep -e Flags -e EncryptionAlgorithm -e KeyLength"
}

#@help _stage_quarantine_container_pool1
# @command stage quarantine container pool <stage>
# @summary Act terminal (root): zpool create of the recorded pool on the attached provider (ashift 12, autotrim off, mountpoint none, canmount off, lz4), ROOT below it, then export and geli detach -- the container is ready to receive
# @group   deploy
# @internal
#@end
_stage_quarantine_container_pool1() {
        local part="" pool="" alt=""
        part=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/quarantine/partition" 2>/dev/null)
        pool=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/quarantine/pool" 2>/dev/null)
        alt="$ELEBAKE_ROOT/mnt/$1-quarantine-container"
        emit_note "stage quarantine container init '$1': pool $pool with ROOT on /dev/$part.eli, exported"
        printf '%s\n' "$MODIFY_DIR_CREATE '$alt'"
        printf '%s\n' "zpool create -o altroot='$alt' -o ashift=12 -o autotrim=off -O mountpoint=none -O canmount=off -O compression=lz4 -O atime=off '$pool' '/dev/$part.eli' || exit 1"
        printf '%s\n' "zfs create -o mountpoint=none -o canmount=off '$pool/ROOT' || exit 1"
        printf '%s\n' "zpool export '$pool' && geli detach '/dev/$part' || exit 1"
}

#@help ___stage_quarantine_container_open1
# @command stage quarantine container open <stage>
# @summary Attach the container with the TPM's file and import its pool without mounting (altroot $ELEBAKE_ROOT/mnt/<stage>-quarantine-container): the stage exists, partition, pool and keyfile are recorded, the RAM disk is mounted and the file on it; then 'stage quarantine container attach'
# @group   deploy
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the key file lives on (default .ram under the database)
# @example elebake stage quarantine container open daily-v1
# @see     stage quarantine container close
#@end
___stage_quarantine_container_open1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine value set '$1' partition"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine value set '$1' pool"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine value set '$1' keyfile"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm workdir ready"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine keyfile present '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine container attach '$1'"
}

#@help _stage_quarantine_container_attach1
# @command stage quarantine container attach <stage>
# @summary Act terminal (root): geli attach -p -k with the TPM's file, zpool import -f -N of the recorded pool from the provider under the altroot (-f: a decoy boot leaves the pool in use by its hostid; the GUID is checked after)
# @group   deploy
# @internal
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the key file lives on (default .ram under the database)
# @see     stage quarantine container open
#@end
_stage_quarantine_container_attach1() {
        local part="" pool="" alt="" d="$(ram_dir)" name=""
        part=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/quarantine/partition" 2>/dev/null)
        pool=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/quarantine/pool" 2>/dev/null)
        name=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/quarantine/keyfile" 2>/dev/null)
        alt="$ELEBAKE_ROOT/mnt/$1-quarantine-container"
        emit_note "stage quarantine container open '$1': /dev/$part attached ($d/$name alone), pool $pool imported (-N, altroot $alt)"
        printf '%s\n' "$MODIFY_DIR_CREATE '$alt'"
        printf '%s\n' "geli status '$part.eli' >/dev/null 2>&1 || geli attach -p -k '$d/$name' '/dev/$part' || exit 1"
        printf '%s\n' "zpool import -f -d '/dev/$part.eli' -R '$alt' -N '$pool' || exit 1"
}

#@help ___stage_quarantine_container_close1
# @command stage quarantine container close <stage>
# @summary Export the container's pool and detach the partition: the stage exists, partition and pool are recorded; then 'stage quarantine container detach'
# @group   deploy
# @example elebake stage quarantine container close daily-v1
# @see     stage quarantine container open
#@end
___stage_quarantine_container_close1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine value set '$1' partition"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine value set '$1' pool"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine container detach '$1'"
}

#@help _stage_quarantine_container_detach1
# @command stage quarantine container detach <stage>
# @summary Act terminal (root): zpool export of the recorded pool, geli detach of the partition
# @group   deploy
# @internal
# @see     stage quarantine container close
#@end
_stage_quarantine_container_detach1() {
        local part="" pool=""
        part=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/quarantine/partition" 2>/dev/null)
        pool=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/quarantine/pool" 2>/dev/null)
        emit_note "stage quarantine container close '$1': pool $pool exported, /dev/$part detached"
        printf '%s\n' "zpool export '$pool' 2>/dev/null; geli detach '/dev/$part' 2>/dev/null; :"
}

#@help ___stage_quarantine_push1
# @command stage quarantine push <stage>
# @summary Send the recorded snapshot into the container: the stage exists, the snapshot is recorded, the container opens (stage quarantine container open), the stream goes (the whole tree the first time, the increment since the receipt after), bootfs is set, the root on the container is set read-only (a session leaves nothing), the GUID is proven, the receipt is recorded, the container closes. After it the witness of the container moves: stage witness measure, conf, anchor
# @group   deploy
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the key file lives on (default .ram under the database)
# @example elebake stage quarantine push daily-v1
# @see     stage quarantine snapshot
# @see     stage quarantine verify
#@end
___stage_quarantine_push1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine value set '$1' snapshot"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine container open '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine send '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine container bootfs '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine container readonly '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine container check '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine value record '$1' received '$(sed -n 1p "$ELEBAKE_BASE/stage/$1/quarantine/snapshot" 2>/dev/null)'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine container close '$1'"
}

#@help __stage_quarantine_send1
# @command stage quarantine send <stage>
# @summary The container received a snapshot before: rewrite to 'stage quarantine send increment' (zfs send -I from it), else 'stage quarantine send whole' (zfs send -R of the tree)
# @group   deploy
# @internal
# @see     stage quarantine push
#@end
__stage_quarantine_send1() {
        if test -s "$ELEBAKE_BASE/stage/$1/quarantine/received"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine send increment '$1'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine send whole '$1'"
        fi
}

#@help _stage_quarantine_send_whole1
# @command stage quarantine send whole <stage>
# @summary Act terminal (root): zfs send -R <dataset>@<snapshot> | zfs recv -F -u <pool>/ROOT/<name> -- the whole root, unmounted on arrival, under the dataset's basename
# @group   deploy
# @internal
#@end
_stage_quarantine_send_whole1() {
        local ds="" pool="" snap=""
        ds=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/quarantine/dataset" 2>/dev/null)
        pool=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/quarantine/pool" 2>/dev/null)
        snap=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/quarantine/snapshot" 2>/dev/null)
        emit_note "stage quarantine push '$1': the whole root $ds@$snap -> $pool/ROOT/${ds##*/}"
        printf '%s\n' "zfs send -R '$ds@$snap' | zfs recv -F -u '$pool/ROOT/${ds##*/}' || exit 1"
}

#@help _stage_quarantine_send_increment1
# @command stage quarantine send increment <stage>
# @summary Act terminal (root): zfs send -R -I @<received> <dataset>@<snapshot> | zfs recv -F -u <pool>/ROOT/<name> -- what changed since the container's receipt
# @group   deploy
# @internal
#@end
_stage_quarantine_send_increment1() {
        local ds="" pool="" snap="" prev=""
        ds=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/quarantine/dataset" 2>/dev/null)
        pool=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/quarantine/pool" 2>/dev/null)
        snap=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/quarantine/snapshot" 2>/dev/null)
        prev=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/quarantine/received" 2>/dev/null)
        emit_note "stage quarantine push '$1': the increment @$prev .. @$snap of $ds -> $pool/ROOT/${ds##*/}"
        printf '%s\n' "zfs send -R -I '@$prev' '$ds@$snap' | zfs recv -F -u '$pool/ROOT/${ds##*/}' || exit 1"
}

#@help _stage_quarantine_container_bootfs1
# @command stage quarantine container bootfs <stage>
# @summary Act terminal (root): zpool set bootfs=<pool>/ROOT/<name> on the container's pool -- what the loader's decoy root leaf names (loader.trust.tpm.decoy.root zfs:<pool>/ROOT/<name>)
# @group   deploy
# @internal
#@end
_stage_quarantine_container_bootfs1() {
        local ds="" pool=""
        ds=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/quarantine/dataset" 2>/dev/null)
        pool=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/quarantine/pool" 2>/dev/null)
        emit_note "stage quarantine push '$1': bootfs $pool/ROOT/${ds##*/}"
        printf '%s\n' "zpool set bootfs='$pool/ROOT/${ds##*/}' '$pool' || exit 1"
}

#@help _stage_quarantine_container_readonly1
# @command stage quarantine container readonly <stage>
# @summary Act terminal (root): zfs set readonly=on <pool>/ROOT/<name> -- the quarantine root is an image, a session leaves nothing on it (tmpmfs and varmfs in the rc lines give it /tmp and /var)
# @group   deploy
# @internal
#@end
_stage_quarantine_container_readonly1() {
        local ds="" pool=""
        ds=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/quarantine/dataset" 2>/dev/null)
        pool=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/quarantine/pool" 2>/dev/null)
        emit_note "stage quarantine push '$1': readonly=on $pool/ROOT/${ds##*/}"
        printf '%s\n' "zfs set readonly=on '$pool/ROOT/${ds##*/}' || exit 1"
}

#@help _stage_quarantine_container_check1
# @command stage quarantine container check <stage>
# @summary Act terminal (root): the GUID of <pool>/ROOT/<name>@<snapshot> in the container equals the GUID of the source snapshot -- the same data, proven by ZFS itself -- and the root is read-only; a mismatch or a writable root is an error
# @group   deploy
# @internal
#@end
_stage_quarantine_container_check1() {
        local ds="" pool="" snap=""
        ds=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/quarantine/dataset" 2>/dev/null)
        pool=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/quarantine/pool" 2>/dev/null)
        snap=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/quarantine/snapshot" 2>/dev/null)
        emit_note "stage quarantine verify '$1': GUID of $pool/ROOT/${ds##*/}@$snap against $ds@$snap"
        printf '%s\n' "a=\$(zfs get -H -o value guid '$pool/ROOT/${ds##*/}@$snap') && b=\$(zfs get -H -o value guid '$ds@$snap') && [ -n \"\$a\" ] && [ \"\$a\" = \"\$b\" ] && printf '# quarantine container: %s verified (guid %s)\\n' '$snap' \"\$a\" >&2 || { printf '# Error: the quarantine container does not hold %s (guid %s vs %s)\\n' '$snap' \"\$a\" \"\$b\" >&2; exit 1; }"
        printf '%s\n' "[ \"\$(zfs get -H -o value readonly '$pool/ROOT/${ds##*/}')\" = on ] && printf '# quarantine container: root read-only\\n' >&2 || { printf '# Error: quarantine container: the root is writable (readonly=off) -- not the image that was pushed\\n' >&2; exit 1; }"
}

#@help ___stage_quarantine_verify1
# @command stage quarantine verify <stage>
# @summary Check the container against the baseline without sending, three questions: does it hold the recorded snapshot (GUID) with a read-only root, is the baseline manifest signed by the pinned key, and is the tree in the container exactly the baseline (every entry present and unchanged, nothing beyond it): the stage exists, the snapshot is recorded, the baseline is signed; then attest verify, container open, check, mount, tree check, umount, close
# @group   deploy
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the key file lives on (default .ram under the database)
# @env     ELEBAKE_ARCHIVE_ATTEST_KEY  the pinned attest key: the baseline signature is checked against it
# @example elebake stage quarantine verify daily-v1
# @see     stage quarantine push
# @see     stage quarantine baseline
#@end
___stage_quarantine_verify1() {
        local key="${ELEBAKE_ARCHIVE_ATTEST_KEY:-}"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine value set '$1' snapshot"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine baseline present '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" attest verify '$ELEBAKE_BASE/stage/$1/quarantine/baseline/MANIFEST' '$key'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine container open '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine container check '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine container mount '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine tree check '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine container umount '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage quarantine container close '$1'"
}

#@help _stage_quarantine_container_mount1
# @command stage quarantine container mount <stage>
# @summary Act terminal (root): mount -t zfs -o ro of <pool>/ROOT/<name> on <root>/mnt/<stage>-quarantine-container/root -- the container's tree, readable, untouched
# @group   deploy
# @internal
# @see     stage quarantine verify
#@end
_stage_quarantine_container_mount1() {
        local ds="" pool="" alt="$ELEBAKE_ROOT/mnt/$1-quarantine-container/root"
        ds=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/quarantine/dataset" 2>/dev/null)
        pool=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/quarantine/pool" 2>/dev/null)
        emit_note "stage quarantine verify '$1': $pool/ROOT/${ds##*/} mounted read-only on $alt"
        printf '%s\n' "$MODIFY_DIR_CREATE '$alt'"
        printf '%s\n' "mount -t zfs -o ro '$pool/ROOT/${ds##*/}' '$alt' || exit 1"
}

#@help _stage_quarantine_container_umount1
# @command stage quarantine container umount <stage>
# @summary Act terminal (root): umount of the container's tree mounted by 'stage quarantine container mount'
# @group   deploy
# @internal
# @see     stage quarantine verify
#@end
_stage_quarantine_container_umount1() {
        local alt="$ELEBAKE_ROOT/mnt/$1-quarantine-container/root"
        emit_note "stage quarantine verify '$1': $alt unmounted"
        printf '%s\n' "umount '$alt' || exit 1"
}

#@help _stage_quarantine_tree_check1
# @command stage quarantine tree check <stage>
# @summary Act terminal (root): the mounted container tree against the baseline manifest -- every entry present and unchanged (MISSING, CHANGED, MISSING SYMLINK, RETARGETED), and nothing in the tree the manifest does not list (UNLISTED); the findings on stderr, any finding exits 1; the count line otherwise
# @group   deploy
# @internal
# @see     stage quarantine verify
#@end
_stage_quarantine_tree_check1() {
        local alt="$ELEBAKE_ROOT/mnt/$1-quarantine-container/root" m="$ELEBAKE_BASE/stage/$1/quarantine/baseline/MANIFEST"
        emit_note "stage quarantine verify '$1': the tree on $alt against the baseline ($(grep -c . "$m" 2>/dev/null) entries)"
        printf '%s\n' "cd '$alt' || exit 1"
        printf '%s\n' "t=\$(mktemp) || exit 1"
        printf '%s\n' "sed -E 's/ (sha256|symlink)=[^ ]*\$//' '$m' | LC_ALL=C sort > \"\$t\""
        printf '%s\n' "f=\$( { while IFS= read -r l; do p=\${l% *}; v=\${l##* }; case \"\$v\" in symlink=*) if [ ! -L \"\$p\" ]; then echo \"MISSING SYMLINK \$p\"; elif [ \"\$(readlink \"\$p\")\" != \"\${v#symlink=}\" ]; then echo \"RETARGETED \$p\"; fi;; sha256=*) if [ ! -f \"\$p\" ]; then echo \"MISSING \$p\"; elif [ \"\$(sha256 -q \"\$p\")\" != \"\${v#sha256=}\" ]; then echo \"CHANGED \$p\"; fi;; esac; done < '$m'; find -x . \\( -type f -o -type l \\) | sed 's|^\\./||' | LC_ALL=C sort | comm -13 \"\$t\" - | sed 's/^/UNLISTED /'; } )"
        printf '%s\n' "rm -f \"\$t\""
        printf '%s\n' "if [ -n \"\$f\" ]; then printf '%s\\n' \"\$f\" >&2; printf '# Error: the quarantine container differs from the baseline (%s findings)\\n' \"\$(printf '%s\\n' \"\$f\" | grep -c .)\" >&2; exit 1; fi"
        printf '%s\n' "printf '# quarantine container: the tree is the baseline (%s entries)\\n' \"\$(grep -c . '$m')\" >&2"
}
