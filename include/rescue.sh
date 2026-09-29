#!/bin/sh
#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Dr. Johannes Brügmann
#
# rescue.sh -- the rescue system of a stage: a ZFS dataset on the production
# pool, built and kept on the owner's machine, sent to a GELI partition of
# every boot medium (the "card"), from where it boots when the production
# root cannot -- a dead TPM seal, a repaired loader, a replaced board.
#
# The stage describes it, records under stage/<stage>/rescue/:
#
#   rescue/dataset      the source dataset (zroot/rescue): ROOT/default below it
#                       is the rescue root, mountpoint / canmount noauto
#   rescue/pool         the card's pool name (zcard): one per medium, same name
#   rescue/tools        one package per line: what the rescue system carries
#                       beyond the base system (tpm2-tools, gnupg, git ...)
#   rescue/config       one absolute path per line: files mirrored from the
#                       production root as they are (wpa_supplicant.conf, VPN,
#                       the seed as its encrypted file -- never a plaintext)
#   rescue/cards/<m>    the medium's rescue partition (da1p3)
#   rescue/snapshot     the last snapshot taken (observation, not replayed)
#   rescue/media/<m>    the snapshot the medium received (observation)
#
# The database itself travels as a DESCRIPTION, not as a copy: 'stage rescue
# database describe' exports the signed pair (dump + bundle, strategy full)
# into the dataset under /root/elvboot/<serial>/; the rescue system imports
# it into an empty database (workflow restore). What the dump replays is the
# description above (dataset, pool, tools, config, cards); snapshots and what
# a card holds are read from the card.
#
# The card: one GELI partition per medium, its own master key, slot 0 the
# rescue passphrase (typed hidden, twice, into <workdir>/auth-rescue.txt on
# the RAM disk; geli -J/-j take the file); a pool of the recorded name; the
# dataset arrives by zfs send -R (the first time) or zfs send -I (after),
# and the snapshot GUID on the card against the source is the proof. Threat
# model assumed: the card leaves the house, so nothing unrevocable lies
# behind the rescue passphrase alone (the seed keeps its own encryption);
# the passphrase is typed on a suspect machine only after its inspection.
# Pins: the acts that touch zfs, geli, the devices and the root run as root
# (sudo sh); the hidden read and the records as the owner (sh).

#@help ___stage_rescue_dataset_add2
# @command stage rescue dataset add <stage> <dataset>
# @completion dataset none
# @summary Record the source dataset of the rescue system (zroot/rescue): the stage exists, the name is a ZFS dataset name; then written (immutable: identical re-add is a no-op, a differing one is refused -- drop first)
# @group   provisioning
# @example elebake stage rescue dataset add daily-v1 zroot/rescue
# @see     stage rescue dataset make
# @see     stage rescue dataset drop
#@end
___stage_rescue_dataset_add2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue name valid dataset '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue value write '$1' dataset '$2'"
}

#@help ___stage_rescue_dataset_drop1
# @command stage rescue dataset drop <stage>
# @summary Forget the source dataset record of the stage (the dataset itself stays): the stage exists and has the record; then it is removed
# @group   provisioning
# @example elebake stage rescue dataset drop daily-v1
# @see     stage rescue dataset add
#@end
___stage_rescue_dataset_drop1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue value set '$1' dataset"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue value erase '$1' dataset"
}

#@help ___stage_rescue_pool_add2
# @command stage rescue pool add <stage> <pool>
# @completion pool none
# @summary Record the name of the pool every card carries (zcard): the stage exists, the name is a ZFS pool name; then written (immutable, drop first to change)
# @group   provisioning
# @example elebake stage rescue pool add daily-v1 zcard
# @see     stage rescue card init
#@end
___stage_rescue_pool_add2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue name valid pool '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue value write '$1' pool '$2'"
}

#@help ___stage_rescue_pool_drop1
# @command stage rescue pool drop <stage>
# @summary Forget the pool name record of the stage: the stage exists and has the record; then it is removed
# @group   provisioning
# @example elebake stage rescue pool drop daily-v1
# @see     stage rescue pool add
#@end
___stage_rescue_pool_drop1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue value set '$1' pool"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue value erase '$1' pool"
}

#@help __stage_rescue_name_valid2
# @command stage rescue name valid <dataset|pool> <name>
# @completion name none
# @summary The name is a ZFS name (letters, digits, _ . - and, for a dataset, /; no leading /, no blank): a comment line, else an error line
# @group   provisioning
# @internal
# @see     stage rescue dataset add
#@end
__stage_rescue_name_valid2() {
        if printf '%s\n' "$2" | grep -qx '[A-Za-z][A-Za-z0-9_.-]*\(/[A-Za-z0-9_.-][A-Za-z0-9_.-]*\)*'; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'rescue $1 name $2 is a ZFS name'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage rescue $1 add: not a ZFS name (letters, digits, _ . - and /): $2'"
        fi
}

#@help __stage_rescue_value_write3
# @command stage rescue value write <stage> <record> <value>
# @completion record none
# @completion value none
# @summary The record exists: rewrite to 'stage rescue value rewrite' (identical no-op, differing refused), else 'stage rescue value record'
# @group   provisioning
# @internal
# @see     stage rescue dataset add
#@end
__stage_rescue_value_write3() {
        if test -f "$ELEBAKE_BASE/stage/$1/rescue/$2"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue value rewrite '$1' '$2' '$3'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue value record '$1' '$2' '$3'"
        fi
}

#@help __stage_rescue_value_rewrite3
# @command stage rescue value rewrite <stage> <record> <value>
# @completion record none
# @completion value none
# @summary An existing record with the identical value is a no-op (a note); a different one is refused -- drop first
# @group   provisioning
# @internal
# @see     stage rescue value write
#@end
__stage_rescue_value_rewrite3() {
        if test "$(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/$2" 2>/dev/null)" = "$3"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" note 'rescue $2 of $1 already recorded (unchanged)'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage rescue $2 add: $1 has a different $2 (immutable; stage rescue $2 drop first)'"
        fi
}

#@help _stage_rescue_value_record3
# @command stage rescue value record <stage> <record> <value>
# @completion record none
# @completion value none
# @summary Act terminal: write rescue/<record> of the stage (one line), directory 0700, file 0600
# @group   provisioning
# @internal
# @see     stage rescue value write
#@end
_stage_rescue_value_record3() {
        local dir=""
        dir=$(dirname "$2")
        printf '%s\n' "$MODIFY_DIR_CREATE '$ELEBAKE_BASE/stage/$1/rescue/$dir'"
        printf '%s\n' "$MODIFY_FILE_PERMS 0700 '$ELEBAKE_BASE/stage/$1/rescue' '$ELEBAKE_BASE/stage/$1/rescue/$dir'"
        printf '%s\n' "printf '%s\\n' $(sq "$3") > '$ELEBAKE_BASE/stage/$1/rescue/$2'"
        printf '%s\n' "$MODIFY_FILE_PERMS 0600 '$ELEBAKE_BASE/stage/$1/rescue/$2'"
        emit_note "rescue $2 of $1: $3"
}

#@help __stage_rescue_value_set2
# @command stage rescue value set <stage> <record>
# @completion record none
# @summary The stage has the rescue record (dataset, pool, snapshot): a comment line, else an error line naming the command that records it
# @group   provisioning
# @internal
# @see     stage rescue dataset add
#@end
__stage_rescue_value_set2() {
        if test -s "$ELEBAKE_BASE/stage/$1/rescue/$2"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'rescue $2 of $1: $(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/$2")'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage $1 has no rescue $2 (stage rescue $2 add $1 <$2>, or stage rescue snapshot $1 for the snapshot)'"
        fi
}

#@help _stage_rescue_value_erase2
# @command stage rescue value erase <stage> <record>
# @completion record none
# @summary Act terminal: remove rescue/<record> of the stage
# @group   provisioning
# @internal
# @see     stage rescue dataset drop
#@end
_stage_rescue_value_erase2() {
        printf '%s\n' "$MODIFY_FILE_REMOVE '$ELEBAKE_BASE/stage/$1/rescue/$2'"
        emit_note "rescue $2 of $1 dropped"
}

#@help ___stage_rescue_tools_add2
# @command stage rescue tools add <stage> <package>
# @completion package none
# @summary Take one package into the rescue system's tool list: the stage exists, the name is a package name (pkg(8)); an entry already listed is a note
# @group   provisioning
# @example elebake stage rescue tools add daily-v1 tpm2-tools
# @see     stage rescue tools install
# @see     stage rescue tools drop
#@end
___stage_rescue_tools_add2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue entry valid tools '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue entry write '$1' tools '$2'"
}

#@help ___stage_rescue_tools_drop2
# @command stage rescue tools drop <stage> <package>
# @completion package none
# @summary Take one package out of the tool list: the stage exists and lists it; then the line is removed
# @group   provisioning
# @example elebake stage rescue tools drop daily-v1 tpm2-tools
# @see     stage rescue tools add
#@end
___stage_rescue_tools_drop2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue entry listed '$1' tools '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue entry unlink '$1' tools '$2'"
}

#@help ___stage_rescue_config_add2
# @command stage rescue config add <stage> <path>
# @completion path none
# @summary Take one absolute path into the mirror list (a file or a directory of the production root, copied as it is by stage rescue config mirror): the stage exists, the path is absolute; an entry already listed is a note. Nothing here is decrypted: the seed goes as seed.gpg, keys with their own passphrases
# @group   provisioning
# @example elebake stage rescue config add daily-v1 /etc/wpa_supplicant.conf
# @see     stage rescue config mirror
# @see     stage rescue config drop
#@end
___stage_rescue_config_add2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue entry valid config '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue entry write '$1' config '$2'"
}

#@help ___stage_rescue_config_drop2
# @command stage rescue config drop <stage> <path>
# @completion path none
# @summary Take one path out of the mirror list: the stage exists and lists it; then the line is removed
# @group   provisioning
# @example elebake stage rescue config drop daily-v1 /etc/wpa_supplicant.conf
# @see     stage rescue config add
#@end
___stage_rescue_config_drop2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue entry listed '$1' config '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue entry unlink '$1' config '$2'"
}

#@help __stage_rescue_entry_valid2
# @command stage rescue entry valid <tools|config> <entry>
# @completion entry none
# @summary A tools entry is a package name (letters, digits, _ . + -), a config entry an absolute path without blank or newline: a comment line, else an error line
# @group   provisioning
# @internal
# @see     stage rescue tools add
#@end
__stage_rescue_entry_valid2() {
        if printf '%s\n' "$2" | grep -qx "$(test "$1" = tools && printf '%s' '[A-Za-z0-9][A-Za-z0-9_.+-]*' || printf '%s' '/[^ 	][^ 	]*')"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'rescue $1 entry $2 has the form'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage rescue $1 add: not a $(test "$1" = tools && printf '%s' 'package name' || printf '%s' 'absolute path'): $2'"
        fi
}

#@help __stage_rescue_entry_write3
# @command stage rescue entry write <stage> <tools|config> <entry>
# @completion entry none
# @summary The list holds the entry already: a note; else 'stage rescue entry append'
# @group   provisioning
# @internal
# @see     stage rescue tools add
#@end
__stage_rescue_entry_write3() {
        if grep -qxsF "$3" "$ELEBAKE_BASE/stage/$1/rescue/$2"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" note 'rescue $2 of $1 already list $3'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue entry append '$1' '$2' '$3'"
        fi
}

#@help _stage_rescue_entry_append3
# @command stage rescue entry append <stage> <tools|config> <entry>
# @completion entry none
# @summary Act terminal: append the entry to rescue/<list> of the stage, directory 0700, file 0600
# @group   provisioning
# @internal
# @see     stage rescue entry write
#@end
_stage_rescue_entry_append3() {
        printf '%s\n' "$MODIFY_DIR_CREATE '$ELEBAKE_BASE/stage/$1/rescue'"
        printf '%s\n' "$MODIFY_FILE_PERMS 0700 '$ELEBAKE_BASE/stage/$1/rescue'"
        printf '%s\n' "printf '%s\\n' $(sq "$3") >> '$ELEBAKE_BASE/stage/$1/rescue/$2'"
        printf '%s\n' "$MODIFY_FILE_PERMS 0600 '$ELEBAKE_BASE/stage/$1/rescue/$2'"
        emit_note "rescue $2 of $1: + $3"
}

#@help __stage_rescue_entry_listed3
# @command stage rescue entry listed <stage> <tools|config> <entry>
# @completion entry none
# @summary The list of the stage holds the entry: a comment line, else an error line
# @group   provisioning
# @internal
# @see     stage rescue tools drop
#@end
__stage_rescue_entry_listed3() {
        if grep -qxsF "$3" "$ELEBAKE_BASE/stage/$1/rescue/$2"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'rescue $2 of $1 list $3'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage rescue $2 drop: not listed: $3'"
        fi
}

#@help _stage_rescue_entry_unlink3
# @command stage rescue entry unlink <stage> <tools|config> <entry>
# @completion entry none
# @summary Act terminal: remove the entry's line from rescue/<list> of the stage
# @group   provisioning
# @internal
# @see     stage rescue tools drop
#@end
_stage_rescue_entry_unlink3() {
        printf '%s\n' "grep -vxF '$3' '$ELEBAKE_BASE/stage/$1/rescue/$2' > '$ELEBAKE_BASE/stage/$1/rescue/$2.new'; mv -f '$ELEBAKE_BASE/stage/$1/rescue/$2.new' '$ELEBAKE_BASE/stage/$1/rescue/$2'"
        emit_note "rescue $2 of $1: - $3"
}

#@help ___stage_rescue_card_add3
# @command stage rescue card add <stage> <medium> <partition>
# @completion partition none
# @summary Record the rescue partition of a medium (da1p3): the stage and the medium exist, the name is a GPT partition name; then written under rescue/cards/<medium> (immutable, drop first to change)
# @group   deploy
# @example elebake stage rescue card add daily-v1 b da1p3
# @see     stage rescue card init
# @see     stage device
#@end
___stage_rescue_card_add3() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage medium exists '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue partition valid '$3'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue value write '$1' 'cards/$2' '$3'"
}

#@help ___stage_rescue_card_drop2
# @command stage rescue card drop <stage> <medium>
# @summary Forget the rescue partition record of a medium: the stage exists and has it; then it is removed
# @group   deploy
# @example elebake stage rescue card drop daily-v1 b
# @see     stage rescue card add
#@end
___stage_rescue_card_drop2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue value set '$1' 'cards/$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue value erase '$1' 'cards/$2'"
}

#@help __stage_rescue_partition_valid1
# @command stage rescue partition valid <partition>
# @completion partition none
# @summary The name is a GPT partition name (<disk><n>p<m>, e.g. da1p3): a comment line, else an error line
# @group   deploy
# @internal
# @see     stage rescue card add
#@end
__stage_rescue_partition_valid1() {
        if printf '%s\n' "$1" | grep -qx '[a-z][a-z]*[0-9][0-9]*p[0-9][0-9]*'; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'rescue partition $1 is a GPT partition name'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage rescue card add: not a GPT partition name (<disk><n>p<m>): $1'"
        fi
}

#@help ___stage_rescue_show1
# @command stage rescue show <stage>
# @summary The rescue description of the stage as notes: dataset, pool, tools, config, the cards, the last snapshot and what each medium received; the stage exists
# @group   provisioning
# @example elebake stage rescue show daily-v1
# @see     stage rescue status
#@end
___stage_rescue_show1() {
        local f=""
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log '# rescue of $1'"
        for f in dataset pool snapshot tools config; do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log '#   $f: $(grep . "$ELEBAKE_BASE/stage/$1/rescue/$f" 2>/dev/null | tr '\n' ' ')'"
        done
        for f in "$ELEBAKE_BASE/stage/$1"/rescue/cards/*; do
                test -f "$f" && printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log '#   card ${f##*/}: $(sed -n 1p "$f") received $(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/media/${f##*/}" 2>/dev/null)'"
        done
        :
}

#@help ___stage_dump_rescue1
# @command stage dump rescue <stage>
# @summary Dump block: the rescue description replayed -- dataset add, pool add, one tools add per package, one config add per path, one card add per medium; snapshots and what a card received are observations and stay out (the card says what it holds); a stage without a description emits nothing and succeeds
# @group   provisioning
# @internal
# @see     stage dump
# @see     stage rescue show
#@end
___stage_dump_rescue1() {
        local r="" f=""
        for r in dataset pool; do
                test -s "$ELEBAKE_BASE/stage/$1/rescue/$r" && printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue $r add '$1' '$(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/$r")'"
        done
        for r in tools config; do
                grep . "$ELEBAKE_BASE/stage/$1/rescue/$r" 2>/dev/null | while read -r f; do
                        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue $r add '$1' '$f'"
                done
        done
        for f in "$ELEBAKE_BASE/stage/$1"/rescue/cards/*; do
                test -f "$f" && printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue card add '$1' '${f##*/}' '$(sed -n 1p "$f")'"
        done
        :
}

#@help ___stage_rescue_dataset_make1
# @command stage rescue dataset make <stage>
# @summary Create the rescue dataset tree on the production pool: the stage exists, the dataset is recorded; then 'stage rescue dataset create' (the parent and ROOT with mountpoint none, ROOT/default with mountpoint / and canmount noauto -- a root the loader can name and nothing mounts by itself)
# @group   provisioning
# @example elebake stage rescue dataset make daily-v1
# @see     stage rescue dataset add
# @see     stage rescue dataset open
#@end
___stage_rescue_dataset_make1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue value set '$1' dataset"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue dataset create '$1'"
}

#@help _stage_rescue_dataset_create1
# @command stage rescue dataset create <stage>
# @summary Act terminal (root): zfs create of <dataset> (mountpoint none, canmount off, lz4, atime off), <dataset>/ROOT (the same) and <dataset>/ROOT/default (mountpoint /, canmount noauto); an existing dataset is kept
# @group   provisioning
# @internal
# @see     stage rescue dataset make
#@end
_stage_rescue_dataset_create1() {
        local ds=""
        ds=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/dataset" 2>/dev/null)
        emit_note "stage rescue dataset make '$1': $ds, $ds/ROOT, $ds/ROOT/default (mountpoint /, canmount noauto)"
        printf '%s\n' "zfs list -H '$ds' >/dev/null 2>&1 || zfs create -o mountpoint=none -o canmount=off -o compression=lz4 -o atime=off '$ds' || exit 1"
        printf '%s\n' "zfs list -H '$ds/ROOT' >/dev/null 2>&1 || zfs create -o mountpoint=none -o canmount=off '$ds/ROOT' || exit 1"
        printf '%s\n' "zfs list -H '$ds/ROOT/default' >/dev/null 2>&1 || zfs create -o mountpoint=/ -o canmount=noauto '$ds/ROOT/default' || exit 1"
        printf '%s\n' "zfs list -r -o name,mountpoint,canmount '$ds'"
}

#@help ___stage_rescue_dataset_open1
# @command stage rescue dataset open <stage>
# @summary Mount the rescue root for editing under $ELEBAKE_ROOT/mnt/<stage>-rescue (mount -t zfs, so the mountpoint property stays /), devfs below it: the stage exists, the dataset is recorded, nothing is mounted there yet; then 'stage rescue dataset mount'
# @group   provisioning
# @example elebake stage rescue dataset open daily-v1
# @see     stage rescue dataset close
# @see     stage rescue base install
#@end
___stage_rescue_dataset_open1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue value set '$1' dataset"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue dataset closed '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue dataset mount '$1'"
}

#@help __stage_rescue_dataset_closed1
# @command stage rescue dataset closed <stage>
# @summary Nothing is mounted at the stage's rescue mount point: a comment line, else an error line (stage rescue dataset close)
# @group   provisioning
# @internal
# @see     stage rescue dataset open
#@end
__stage_rescue_dataset_closed1() {
        if mount | grep -q " on $ELEBAKE_ROOT/mnt/$1-rescue "; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage rescue dataset open: $ELEBAKE_ROOT/mnt/$1-rescue is mounted (stage rescue dataset close $1 first)'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'rescue mount point of $1 is free'"
        fi
}

#@help __stage_rescue_dataset_mounted1
# @command stage rescue dataset mounted <stage>
# @summary The rescue root is mounted at $ELEBAKE_ROOT/mnt/<stage>-rescue: a comment line, else an error line (stage rescue dataset open)
# @group   provisioning
# @internal
# @see     stage rescue dataset open
#@end
__stage_rescue_dataset_mounted1() {
        if mount | grep -q " on $ELEBAKE_ROOT/mnt/$1-rescue "; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'rescue root of $1 mounted at $ELEBAKE_ROOT/mnt/$1-rescue'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage $1: rescue root not mounted (stage rescue dataset open $1)'"
        fi
}

#@help _stage_rescue_dataset_mount1
# @command stage rescue dataset mount <stage>
# @summary Act terminal (root): mkdir of the mount point, mount -t zfs of <dataset>/ROOT/default there, devfs below it
# @group   provisioning
# @internal
# @see     stage rescue dataset open
#@end
_stage_rescue_dataset_mount1() {
        local ds="" alt=""
        ds=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/dataset" 2>/dev/null)
        alt="$ELEBAKE_ROOT/mnt/$1-rescue"
        emit_note "stage rescue dataset open '$1': $ds/ROOT/default on $alt"
        printf '%s\n' "$MODIFY_DIR_CREATE '$alt'"
        printf '%s\n' "mount -t zfs '$ds/ROOT/default' '$alt' || exit 1"
        printf '%s\n' "$MODIFY_DIR_CREATE '$alt/dev'"
        printf '%s\n' "mount -t devfs devfs '$alt/dev' || exit 1"
}

#@help ___stage_rescue_dataset_close1
# @command stage rescue dataset close <stage>
# @summary Unmount the rescue root and its devfs: the stage exists, the root is mounted; then 'stage rescue dataset umount'
# @group   provisioning
# @example elebake stage rescue dataset close daily-v1
# @see     stage rescue dataset open
#@end
___stage_rescue_dataset_close1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue dataset mounted '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue dataset umount '$1'"
}

#@help _stage_rescue_dataset_umount1
# @command stage rescue dataset umount <stage>
# @summary Act terminal (root): umount of the devfs and the rescue root
# @group   provisioning
# @internal
# @see     stage rescue dataset close
#@end
_stage_rescue_dataset_umount1() {
        local alt="$ELEBAKE_ROOT/mnt/$1-rescue"
        emit_note "stage rescue dataset close '$1': $alt"
        printf '%s\n' "umount '$alt/dev' 2>/dev/null; umount '$alt' || exit 1"
}

#@help ___stage_rescue_base_install1
# @command stage rescue base install <stage>
# @summary Install the base system and the generic kernel into the mounted rescue root from the pkgbase repository of this machine (the rescue system boots on its own, so it carries a kernel): the stage exists, the root is mounted; then 'stage rescue base pkg'
# @group   provisioning
# @env     ELEBAKE_RESCUE_BASE_REPO  the pkgbase repository name (default FreeBSD-base)
# @example elebake stage rescue base install daily-v1
# @see     stage rescue dataset open
# @see     stage rescue tools install
#@end
___stage_rescue_base_install1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue dataset mounted '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue base pkg '$1'"
}

#@help _stage_rescue_base_pkg1
# @command stage rescue base pkg <stage>
# @summary Act terminal (root): the repository fingerprints copied under the rescue root (pkg reads them relative to --rootdir), pkg update of the base repository, pkg install of FreeBSD-set-base and FreeBSD-kernel-generic
# @group   provisioning
# @internal
# @env     ELEBAKE_RESCUE_BASE_REPO  the pkgbase repository name (default FreeBSD-base)
# @see     stage rescue base install
#@end
_stage_rescue_base_pkg1() {
        local alt="$ELEBAKE_ROOT/mnt/$1-rescue" repo="${ELEBAKE_RESCUE_BASE_REPO:-FreeBSD-base}"
        emit_note "stage rescue base install '$1': FreeBSD-set-base and FreeBSD-kernel-generic from $repo into $alt"
        printf '%s\n' "$MODIFY_DIR_CREATE '$alt/usr/share/keys'"
        printf '%s\n' "cp -a /usr/share/keys/pkg /usr/share/keys/pkgbase-* '$alt/usr/share/keys/' 2>/dev/null; :"
        printf '%s\n' "pkg --rootdir '$alt' -o REPOS_DIR=/etc/pkg,/usr/local/etc/pkg/repos update -r '$repo' || exit 1"
        printf '%s\n' "pkg --rootdir '$alt' -o REPOS_DIR=/etc/pkg,/usr/local/etc/pkg/repos install -y -r '$repo' FreeBSD-set-base FreeBSD-kernel-generic || exit 1"
}

#@help ___stage_rescue_tools_install1
# @command stage rescue tools install <stage>
# @summary Install the tool list into the mounted rescue root from the ports repository of this machine: the stage exists, the root is mounted, the list is not empty; then 'stage rescue tools pkg'
# @group   provisioning
# @env     ELEBAKE_RESCUE_TOOLS_REPO  the ports repository name (default FreeBSD-ports)
# @example elebake stage rescue tools install daily-v1
# @see     stage rescue tools add
#@end
___stage_rescue_tools_install1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue dataset mounted '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue list filled '$1' tools"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue tools pkg '$1'"
}

#@help __stage_rescue_list_filled2
# @command stage rescue list filled <stage> <tools|config>
# @summary The list has at least one entry: a comment line, else an error line naming the add command
# @group   provisioning
# @internal
# @see     stage rescue tools install
#@end
__stage_rescue_list_filled2() {
        if grep -q . "$ELEBAKE_BASE/stage/$1/rescue/$2" 2>/dev/null; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'rescue $2 of $1: $(grep -c . "$ELEBAKE_BASE/stage/$1/rescue/$2") entries'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage $1 has no rescue $2 (stage rescue $2 add $1 ...)'"
        fi
}

#@help _stage_rescue_tools_pkg1
# @command stage rescue tools pkg <stage>
# @summary Act terminal (root): pkg install of every listed package into the rescue root from the ports repository
# @group   provisioning
# @internal
# @env     ELEBAKE_RESCUE_TOOLS_REPO  the ports repository name (default FreeBSD-ports)
# @see     stage rescue tools install
#@end
_stage_rescue_tools_pkg1() {
        local alt="$ELEBAKE_ROOT/mnt/$1-rescue" repo="${ELEBAKE_RESCUE_TOOLS_REPO:-FreeBSD-ports}" list=""
        list=$(grep . "$ELEBAKE_BASE/stage/$1/rescue/tools" 2>/dev/null | tr '\n' ' ')
        emit_note "stage rescue tools install '$1': $list from $repo into $alt"
        printf '%s\n' "pkg --rootdir '$alt' -o REPOS_DIR=/etc/pkg,/usr/local/etc/pkg/repos update -r '$repo' || exit 1"
        printf '%s\n' "pkg --rootdir '$alt' -o REPOS_DIR=/etc/pkg,/usr/local/etc/pkg/repos install -y -r '$repo' $list || exit 1"
}

#@help ___stage_rescue_config_mirror1
# @command stage rescue config mirror <stage>
# @summary Copy every listed path from the production root into the mounted rescue root, as it is (owner, mode, an encrypted file stays encrypted): the stage exists, the root is mounted, the list is not empty; then 'stage rescue config copy'
# @group   provisioning
# @example elebake stage rescue config mirror daily-v1
# @see     stage rescue config add
#@end
___stage_rescue_config_mirror1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue dataset mounted '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue list filled '$1' config"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue config copy '$1'"
}

#@help _stage_rescue_config_copy1
# @command stage rescue config copy <stage>
# @summary Act terminal (root): per listed path mkdir of its parent under the rescue root and cp -a of the path; a path absent on this machine is reported and skipped
# @group   provisioning
# @internal
# @see     stage rescue config mirror
#@end
_stage_rescue_config_copy1() {
        local alt="$ELEBAKE_ROOT/mnt/$1-rescue" p=""
        emit_note "stage rescue config mirror '$1': $(grep -c . "$ELEBAKE_BASE/stage/$1/rescue/config" 2>/dev/null) paths into $alt"
        grep . "$ELEBAKE_BASE/stage/$1/rescue/config" 2>/dev/null | while read -r p; do
                printf '%s\n' "if [ -e '$p' ]; then mkdir -p \"\$(dirname '$alt$p')\" && cp -a '$p' '$alt$p' || exit 1; else printf '# rescue config: absent on this machine, skipped: %s\\n' '$p' >&2; fi"
        done
}

#@help ___stage_rescue_database_describe1
# @command stage rescue database describe <stage>
# @summary Put the description of this database into the mounted rescue root: the signed export pair of the strategy full (every stage) under /root/elvboot/<serial>/, so the rescue system rebuilds the database from it (workflow restore): the stage exists, the root is mounted, the attest key is pinned; then 'export full' into the work directory and 'stage rescue database place'
# @group   provisioning
# @env     ELEBAKE_ARCHIVE_ATTEST_KEY  the openpgp record that signs the pair
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the pair is written on before it is placed (default /tmp/ram)
# @example elebake stage rescue database describe daily-v1
# @see     export
# @see     stage rescue database place
#@end
___stage_rescue_database_describe1() {
        local serial="" d="${ELEBAKE_TPM_WORKDIR:-/tmp/ram}"
        serial=$(( $(sed -n 1p "$ELEBAKE_BASE/export/serial" 2>/dev/null || printf '0') + 1 ))
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue dataset mounted '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm workdir ready"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" archive key pinned"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" export full '$d/elvboot-$serial/dump.sh' '$d/elvboot-$serial/bundle.tar.gz' all"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue database place '$1' '$serial'"
}

#@help _stage_rescue_database_place2
# @command stage rescue database place <stage> <serial>
# @completion serial none
# @summary Act terminal (root): the pair from the work directory into <rescue root>/root/elvboot/<serial>/ (0700, root), the work copy wiped
# @group   provisioning
# @internal
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the pair was written on (default /tmp/ram)
# @see     stage rescue database describe
#@end
_stage_rescue_database_place2() {
        local alt="$ELEBAKE_ROOT/mnt/$1-rescue" d="${ELEBAKE_TPM_WORKDIR:-/tmp/ram}"
        emit_note "stage rescue database describe '$1': the pair of serial $2 into $alt/root/elvboot/$2/"
        printf '%s\n' "$MODIFY_DIR_CREATE '$alt/root/elvboot/$2'"
        printf '%s\n' "cp '$d/elvboot-$2/dump.sh' '$d/elvboot-$2/dump.sh.asc' '$d/elvboot-$2/bundle.tar.gz' '$alt/root/elvboot/$2/' || exit 1"
        printf '%s\n' "$MODIFY_FILE_PERMS 0700 '$alt/root/elvboot' '$alt/root/elvboot/$2'"
        printf '%s\n' "rm -P '$d/elvboot-$2'/* && rmdir '$d/elvboot-$2'"
}

#@help ___stage_rescue_snapshot1
# @command stage rescue snapshot <stage>
# @summary Snapshot the rescue dataset tree (<dataset>@<stage>-<stamp>, recursive) and record the name as the stage's rescue snapshot: the stage exists, the dataset is recorded, the root is not mounted (a quiescent tree); then 'stage rescue snapshot take', then the record
# @group   provisioning
# @example elebake stage rescue snapshot daily-v1
# @see     stage rescue push
#@end
___stage_rescue_snapshot1() {
        local snap=""
        snap="$1-$(date -u +%Y%m%dT%H%M%SZ)"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue value set '$1' dataset"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue dataset closed '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue snapshot take '$1' '$snap'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue value record '$1' snapshot '$snap'"
}

#@help _stage_rescue_snapshot_take2
# @command stage rescue snapshot take <stage> <snapshot>
# @completion snapshot none
# @summary Act terminal (root): zfs snapshot -r <dataset>@<snapshot>
# @group   provisioning
# @internal
# @see     stage rescue snapshot
#@end
_stage_rescue_snapshot_take2() {
        local ds=""
        ds=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/dataset" 2>/dev/null)
        emit_note "stage rescue snapshot '$1': $ds@$2 (recursive)"
        printf '%s\n' "zfs snapshot -r '$ds@$2' || exit 1"
}

#@help ___stage_rescue_passphrase1
# @command stage rescue passphrase <stage>
# @summary Read the rescue passphrase hidden, twice, into <workdir>/auth-rescue.txt on the RAM disk (geli init -J and geli attach -j take the file; it is what the owner types at the rescue boot): the stage exists, the work directory is a mounted RAM disk; then 'stage rescue passphrase read'
# @group   deploy
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the file lives on (default /tmp/ram)
# @example elebake stage rescue passphrase daily-v1
# @see     stage rescue card init
#@end
___stage_rescue_passphrase1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm workdir ready"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue passphrase read '$1'"
}

#@help _stage_rescue_passphrase_read1
# @command stage rescue passphrase read <stage>
# @summary Act terminal: the script that reads the passphrase twice on /dev/tty with echo off, refuses empty or differing entries, and writes it to <workdir>/auth-rescue.txt (0600) -- the passphrase never reaches argv
# @group   deploy
# @internal
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the file lives on (default /tmp/ram)
# @see     stage rescue passphrase
#@end
_stage_rescue_passphrase_read1() {
        local d="${ELEBAKE_TPM_WORKDIR:-/tmp/ram}"
        cat <<EOF
{ : < /dev/tty; } 2>/dev/null || { printf '# Error: %s\\n' 'stage rescue passphrase: needs a terminal to read the passphrase hidden' >&2; exit 1; }
printf 'rescue passphrase of the cards of %s (hidden): ' '$1' > /dev/tty; stty -echo < /dev/tty; IFS= read -r a < /dev/tty; stty echo < /dev/tty; printf '\\n' > /dev/tty
printf 'Again: ' > /dev/tty; stty -echo < /dev/tty; IFS= read -r b < /dev/tty; stty echo < /dev/tty; printf '\\n' > /dev/tty
[ -n "\$a" ] && [ "\$a" = "\$b" ] || { unset a b; printf '# Error: %s\\n' 'stage rescue passphrase: the two entries differ or are empty -- nothing done' >&2; exit 1; }
printf '%s' "\$a" > '$d/auth-rescue.txt' && chmod 0600 '$d/auth-rescue.txt'; unset a b
EOF
}

#@help __stage_rescue_passphrase_present0
# @command stage rescue passphrase present
# @summary <workdir>/auth-rescue.txt is there (stage rescue passphrase read it): a comment line, else an error line
# @group   deploy
# @internal
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the file lives on (default /tmp/ram)
# @see     stage rescue passphrase
#@end
__stage_rescue_passphrase_present0() {
        local d="${ELEBAKE_TPM_WORKDIR:-/tmp/ram}"
        if test -s "$d/auth-rescue.txt"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'rescue passphrase present on $d'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage rescue: no $d/auth-rescue.txt (stage rescue passphrase <stage> reads it)'"
        fi
}

#@help ___stage_rescue_card_init2
# @command stage rescue card init <stage> <medium>
# @summary Prepare a medium's rescue partition, once: GELI (AES-XTS 256, HMAC/SHA256, BOOT, NODELETE, the rescue passphrase as slot 0, its own master key), every sector written (HMAC needs it), the pool created on it, exported again: the stage exists, the medium is inserted, the partition and the pool are recorded, the passphrase file is there; then 'stage rescue card geli' and 'stage rescue card pool'
# @group   deploy
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the passphrase file lives on (default /tmp/ram)
# @example elebake stage rescue card init daily-v1 b
# @see     stage rescue card add
# @see     stage rescue push
#@end
___stage_rescue_card_init2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage medium present '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue value set '$1' 'cards/$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue value set '$1' pool"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue passphrase present"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue card geli '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue card pool '$1' '$2'"
}

#@help _stage_rescue_card_geli2
# @command stage rescue card geli <stage> <medium>
# @summary Act terminal (root): geli init of the medium's rescue partition (-e AES-XTS -l 256 -a HMAC/SHA256 -s 4096 -b -T, PBKDF2 iterations as zroot, the passphrase from the file), attach, dd of zeros over the whole provider (ENOSPC ends it), the provider left attached for the pool
# @group   deploy
# @internal
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the passphrase file lives on (default /tmp/ram)
# @see     stage rescue card init
#@end
_stage_rescue_card_geli2() {
        local part="" d="${ELEBAKE_TPM_WORKDIR:-/tmp/ram}"
        part=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/cards/$2" 2>/dev/null)
        emit_note "stage rescue card init '$1' medium '$2': geli on /dev/$part, then zeros over the whole provider (minutes)"
        printf '%s\n' "geli init -e AES-XTS -l 256 -a HMAC/SHA256 -s 4096 -b -T -i 9999999 -J '$d/auth-rescue.txt' '/dev/$part' || exit 1"
        printf '%s\n' "geli attach -j '$d/auth-rescue.txt' '/dev/$part' || exit 1"
        printf '%s\n' "dd if=/dev/zero of='/dev/$part.eli' bs=1m 2>/dev/null; geli list '$part.eli' | grep -e Flags -e EncryptionAlgorithm -e KeyLength"
}

#@help _stage_rescue_card_pool2
# @command stage rescue card pool <stage> <medium>
# @summary Act terminal (root): zpool create of the recorded pool on the attached provider (ashift 12, autotrim off, mountpoint none, canmount off, lz4), then export and geli detach -- the card is ready to receive
# @group   deploy
# @internal
# @see     stage rescue card init
#@end
_stage_rescue_card_pool2() {
        local part="" pool="" alt=""
        part=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/cards/$2" 2>/dev/null)
        pool=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/pool" 2>/dev/null)
        alt="$ELEBAKE_ROOT/mnt/$1-rescue-$2"
        emit_note "stage rescue card init '$1' medium '$2': pool $pool on /dev/$part.eli, exported"
        printf '%s\n' "$MODIFY_DIR_CREATE '$alt'"
        printf '%s\n' "zpool create -o altroot='$alt' -o ashift=12 -o autotrim=off -O mountpoint=none -O canmount=off -O compression=lz4 -O atime=off '$pool' '/dev/$part.eli' || exit 1"
        printf '%s\n' "zpool export '$pool' && geli detach '/dev/$part' || exit 1"
}

#@help ___stage_rescue_card_open2
# @command stage rescue card open <stage> <medium>
# @summary Attach the medium's rescue partition and import its pool without mounting (altroot $ELEBAKE_ROOT/mnt/<stage>-rescue-<medium>): the stage exists, the medium is inserted, the partition and the pool are recorded, the passphrase file is there; then 'stage rescue card attach'
# @group   deploy
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the passphrase file lives on (default /tmp/ram)
# @example elebake stage rescue card open daily-v1 b
# @see     stage rescue card close
#@end
___stage_rescue_card_open2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage medium present '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue value set '$1' 'cards/$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue value set '$1' pool"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue passphrase present"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue card attach '$1' '$2'"
}

#@help _stage_rescue_card_attach2
# @command stage rescue card attach <stage> <medium>
# @summary Act terminal (root): geli attach with the passphrase file, zpool import -N of the recorded pool from the provider under the altroot
# @group   deploy
# @internal
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the passphrase file lives on (default /tmp/ram)
# @see     stage rescue card open
#@end
_stage_rescue_card_attach2() {
        local part="" pool="" alt="" d="${ELEBAKE_TPM_WORKDIR:-/tmp/ram}"
        part=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/cards/$2" 2>/dev/null)
        pool=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/pool" 2>/dev/null)
        alt="$ELEBAKE_ROOT/mnt/$1-rescue-$2"
        emit_note "stage rescue card open '$1' medium '$2': /dev/$part attached, pool $pool imported (-N, altroot $alt)"
        printf '%s\n' "$MODIFY_DIR_CREATE '$alt'"
        printf '%s\n' "geli status '$part.eli' >/dev/null 2>&1 || geli attach -j '$d/auth-rescue.txt' '/dev/$part' || exit 1"
        printf '%s\n' "zpool import -d '/dev/$part.eli' -R '$alt' -N '$pool' || exit 1"
}

#@help ___stage_rescue_card_close2
# @command stage rescue card close <stage> <medium>
# @summary Export the medium's pool and detach its rescue partition: the stage exists, the partition and the pool are recorded; then 'stage rescue card detach'
# @group   deploy
# @example elebake stage rescue card close daily-v1 b
# @see     stage rescue card open
#@end
___stage_rescue_card_close2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue value set '$1' 'cards/$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue value set '$1' pool"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue card detach '$1' '$2'"
}

#@help _stage_rescue_card_detach2
# @command stage rescue card detach <stage> <medium>
# @summary Act terminal (root): zpool export of the recorded pool, geli detach of the partition
# @group   deploy
# @internal
# @see     stage rescue card close
#@end
_stage_rescue_card_detach2() {
        local part="" pool=""
        part=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/cards/$2" 2>/dev/null)
        pool=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/pool" 2>/dev/null)
        emit_note "stage rescue card close '$1' medium '$2': pool $pool exported, /dev/$part detached"
        printf '%s\n' "zpool export '$pool' 2>/dev/null; geli detach '/dev/$part' 2>/dev/null; :"
}

#@help ___stage_rescue_push2
# @command stage rescue push <stage> <medium>
# @summary Send the recorded snapshot to the medium's card: the stage exists, the snapshot is recorded, the card opens (stage rescue card open), the stream goes (the whole tree the first time, the increment since what the card holds after), bootfs is set, the snapshot on the card is verified against the source, the receipt is recorded, the card closes
# @group   deploy
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the passphrase file lives on (default /tmp/ram)
# @example elebake stage rescue push daily-v1 b
# @see     stage rescue snapshot
# @see     stage rescue verify
#@end
___stage_rescue_push2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue value set '$1' snapshot"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue card open '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue send '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue card bootfs '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue card check '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue value record '$1' 'media/$2' '$(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/snapshot" 2>/dev/null)'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue card close '$1' '$2'"
}

#@help __stage_rescue_send2
# @command stage rescue send <stage> <medium>
# @summary The medium received a snapshot before: rewrite to 'stage rescue send increment' (zfs send -I from it), else 'stage rescue send whole' (zfs send -R of the tree)
# @group   deploy
# @internal
# @see     stage rescue push
#@end
__stage_rescue_send2() {
        if test -s "$ELEBAKE_BASE/stage/$1/rescue/media/$2"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue send increment '$1' '$2'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue send whole '$1' '$2'"
        fi
}

#@help _stage_rescue_send_whole2
# @command stage rescue send whole <stage> <medium>
# @summary Act terminal (root): zfs send -R <dataset>/ROOT@<snapshot> | zfs recv -F -u <pool>/ROOT -- the whole tree, unmounted on arrival
# @group   deploy
# @internal
# @see     stage rescue send
#@end
_stage_rescue_send_whole2() {
        local ds="" pool="" snap=""
        ds=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/dataset" 2>/dev/null)
        pool=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/pool" 2>/dev/null)
        snap=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/snapshot" 2>/dev/null)
        emit_note "stage rescue push '$1' medium '$2': the whole tree $ds/ROOT@$snap -> $pool/ROOT"
        printf '%s\n' "zfs send -R '$ds/ROOT@$snap' | zfs recv -F -u '$pool/ROOT' || exit 1"
}

#@help _stage_rescue_send_increment2
# @command stage rescue send increment <stage> <medium>
# @summary Act terminal (root): zfs send -R -I @<received> <dataset>/ROOT@<snapshot> | zfs recv -F -u <pool>/ROOT -- what changed since the medium's last receipt
# @group   deploy
# @internal
# @see     stage rescue send
#@end
_stage_rescue_send_increment2() {
        local ds="" pool="" snap="" prev=""
        ds=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/dataset" 2>/dev/null)
        pool=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/pool" 2>/dev/null)
        snap=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/snapshot" 2>/dev/null)
        prev=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/media/$2" 2>/dev/null)
        emit_note "stage rescue push '$1' medium '$2': the increment @$prev .. @$snap of $ds/ROOT -> $pool/ROOT"
        printf '%s\n' "zfs send -R -I '@$prev' '$ds/ROOT@$snap' | zfs recv -F -u '$pool/ROOT' || exit 1"
}

#@help _stage_rescue_card_bootfs2
# @command stage rescue card bootfs <stage> <medium>
# @summary Act terminal (root): zpool set bootfs=<pool>/ROOT/default on the card's pool -- what the loader boots when it names the rescue root
# @group   deploy
# @internal
# @see     stage rescue push
#@end
_stage_rescue_card_bootfs2() {
        local pool=""
        pool=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/pool" 2>/dev/null)
        emit_note "stage rescue push '$1' medium '$2': bootfs $pool/ROOT/default"
        printf '%s\n' "zpool set bootfs='$pool/ROOT/default' '$pool' || exit 1"
}

#@help _stage_rescue_card_check2
# @command stage rescue card check <stage> <medium>
# @summary Act terminal (root): the GUID of <pool>/ROOT/default@<snapshot> on the card equals the GUID of the source snapshot -- the same data, proven by ZFS itself; a mismatch is an error
# @group   deploy
# @internal
# @see     stage rescue push
# @see     stage rescue verify
#@end
_stage_rescue_card_check2() {
        local ds="" pool="" snap=""
        ds=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/dataset" 2>/dev/null)
        pool=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/pool" 2>/dev/null)
        snap=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/snapshot" 2>/dev/null)
        emit_note "stage rescue verify '$1' medium '$2': GUID of $pool/ROOT/default@$snap against $ds/ROOT/default@$snap"
        printf '%s\n' "a=\$(zfs get -H -o value guid '$pool/ROOT/default@$snap') && b=\$(zfs get -H -o value guid '$ds/ROOT/default@$snap') && [ -n \"\$a\" ] && [ \"\$a\" = \"\$b\" ] && printf '# rescue on medium %s: %s verified (guid %s)\\n' '$2' '$snap' \"\$a\" >&2 || { printf '# Error: rescue on medium %s does not hold %s (guid %s vs %s)\\n' '$2' '$snap' \"\${a:-none}\" \"\${b:-none}\" >&2; exit 1; }"
}

#@help ___stage_rescue_verify2
# @command stage rescue verify <stage> <medium>
# @summary Check a card against the recorded snapshot without sending: the stage exists, the snapshot is recorded, the card opens, the GUIDs are compared, the card closes
# @group   deploy
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the passphrase file lives on (default /tmp/ram)
# @example elebake stage rescue verify daily-v1 b
# @see     stage rescue push
#@end
___stage_rescue_verify2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue value set '$1' snapshot"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue card open '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue card check '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue card close '$1' '$2'"
}

#@help ___stage_rescue_status1
# @command stage rescue status <stage>
# @summary What the machine holds against the description: the stage exists; then 'stage rescue status show' (the dataset tree and its snapshots as zfs lists them, the mount point, the description as notes)
# @group   provisioning
# @example elebake stage rescue status daily-v1
# @see     stage rescue show
#@end
___stage_rescue_status1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue show '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue status show '$1'"
}

#@help _stage_rescue_status_show1
# @command stage rescue status show <stage>
# @summary Act terminal: zfs list of the recorded dataset tree and its snapshots (a dataset not there says so), whether the rescue root is mounted
# @group   provisioning
# @internal
# @see     stage rescue status
#@end
_stage_rescue_status_show1() {
        local ds=""
        ds=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/dataset" 2>/dev/null)
        emit_note "stage rescue status '$1': dataset ${ds:--}, mount point $ELEBAKE_ROOT/mnt/$1-rescue"
        printf '%s\n' "zfs list -r -o name,used,mountpoint,canmount '${ds:-none}' 2>/dev/null || printf '# rescue dataset %s: not there (stage rescue dataset make)\\n' '${ds:-none}' >&2"
        printf '%s\n' "zfs list -t snapshot -r -o name,used,creation '${ds:-none}' 2>/dev/null; :"
        printf '%s\n' "mount | grep ' on $ELEBAKE_ROOT/mnt/$1-rescue ' || printf '# rescue root of %s: not mounted\\n' '$1' >&2"
}
