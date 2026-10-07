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
#   rescue/dataset      the rescue ROOT itself (zroot/ROOT/rescue): a boot
#                       environment on the production pool, mountpoint /,
#                       canmount noauto -- bectl sees it, it boots from zroot
#                       for a test and from the card in earnest
#   rescue/pool         the card's pool name (zcard): one per medium, same name
#   rescue/package      the name of the META PACKAGE that describes what the
#                       rescue system carries (illyria-rescue): a package with
#                       no files, only dependencies -- the base sets, every
#                       tool, elvboot and vpn-switch; pkg installs it and
#                       pulls the rest, pkg autoremove never removes what it
#                       needs, pkg info <name> is the inventory
#   rescue/tools        one package per line: the dependencies of the meta
#                       package beyond the base sets
#   rescue/sources/<t>  the checkout a tool is packaged from (elvboot,
#                       vpn-switch): 'make package' there builds the package
#                       into the stage's repository
#   rescue/keyfile      the GELI key file of the cards (/boot/keys/zroot.key,
#                       in the boot tree on the card itself): the slot opens
#                       with the rescue passphrase AND it, as zroot does --
#                       an image of the rescue partition alone is worthless
#   rescue/config       one absolute path per line: files mirrored from the
#                       production root as they are (rc.conf 1:1, pf.conf,
#                       wpa_supplicant.conf, the seed as its encrypted file,
#                       the SSH host keys -- never a plaintext of a secret
#                       that has its own encryption)
#   rescue/users/<n>    a user of the rescue system, read from the
#                       production's passwd when added (uid, gid, groups,
#                       home, shell, gecos); the password hash follows when
#                       the act runs as root
#   rescue/local        the lines of /etc/rc.conf.local: what the rescue
#                       deliberately keeps different from the production
#                       (sshd_enable="NO"); rc reads it after rc.conf
#   rescue/cards/<m>    the medium's rescue partition (da1p3)
#   rescue/patches/<n>  a patch of the built root, '<user>:<script>': the
#                       script is a path IN the image, run as root INSIDE
#                       the root (a one-shot jail on it, no network), 'sh
#                       <script> <user> <resources>', the resources being
#                       $ELEBAKE_BASE/.resource/<n>/ of this database -- a
#                       fixed place the owner fills with what the patch
#                       takes (an export pair, the signer's public key),
#                       hung into the root read-only for the run; the
#                       shipped scripts elvboot-import-db-patch.sh and
#                       vpn-switch-import-db-patch.sh (template/rescue/ of
#                       each tool, in the image under its lib/<tool>/template/)
#                       build the databases into the image this way, with
#                       the image's own tool
#   rescue/repo/        the stage's package repository (built, not replayed)
#   rescue/snapshot     the last snapshot taken (observation, not replayed)
#   rescue/media/<m>    the snapshot the medium received (observation)
#
# The rescue is FINISHED, not a kit: 'stage rescue build' fills the opened
# root in phases -- package install, config mirror, local write, user
# mirror, transient write, patch apply, baseline -- and the patches are
# where the databases get built into the image. elebake knows patches only
# (a script, a user, a resource directory) and runs them inside the root;
# dump and bundle are words of elvboot and vpn-switch, whose patch scripts
# call '<tool> import' as the user -- the tool of the IMAGE, so the database
# matches it -- and import makes the database when there is none (the
# profile from the dump, the signer from the user's keyring, which the
# script seeds with the public key the owner put beside the pair). What the
# dump replays is the description above; the repository, snapshots and what
# a card holds are built or read.
#
# The card: one GELI partition per medium, its own master key, slot 0 the
# rescue passphrase (typed hidden, twice, into <workdir>/auth-rescue.txt on
# the RAM disk; geli -J/-j take the file) together with the key file; a pool
# of the recorded name with ROOT below it; the rescue root arrives as
# <pool>/ROOT/<name> by zfs send -R (the first time) or zfs send -I (after),
# bootfs names it, and the snapshot GUID on the card against the source is
# the proof. Threat model assumed: the card leaves the house, so nothing
# unrevocable lies behind the rescue passphrase alone (the seed keeps its
# own encryption, the signing keys sit on the Nitrokey); the passphrase is
# typed on a suspect machine only after its inspection.
# Pins: the acts that touch zfs, geli, the devices and the root run as root
# (sudo sh); the hidden read, the records and the packaging as the owner (sh).

#@help ___stage_rescue_dataset_add2
# @command stage rescue dataset add <stage> <dataset>
# @completion dataset none
# @summary Record the rescue root dataset (zroot/ROOT/rescue, a boot environment on the production pool): the stage exists, the name is a ZFS dataset name; then written (immutable: identical re-add is a no-op, a differing one is refused -- drop first)
# @group   deploy
# @see     stage rescue dataset make
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
# @see     stage rescue package build
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
# @summary Take one absolute path into the mirror list (a file or a directory of the production root, copied as it is by stage rescue config mirror): the stage exists, the path is absolute; an entry already listed is a note. Nothing here is decrypted, and nothing that cannot be revoked belongs here: the card carries keys with their own passphrases, never the seed (seed.gpg stays on the production root)
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

#@help ___stage_rescue_transient_add2
# @command stage rescue transient add <stage> <path>
# @completion path none
# @summary Take one absolute path into the transient list -- a directory of the rescue root that gets a writable layer in memory at every boot (tmpfs over the read-only directory, unionfs): the stage exists, the path is absolute; an entry already listed is a note. The root itself is read-only on the card (stage rescue push), /tmp and /var are memory disks; what is written in a session is gone at the next boot
# @group   provisioning
# @example elebake stage rescue transient add daily-v1 /home
# @see     stage rescue transient write
# @see     stage rescue transient drop
#@end
___stage_rescue_transient_add2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue entry valid transient '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue entry write '$1' transient '$2'"
}
#@help ___stage_rescue_transient_drop2
# @command stage rescue transient drop <stage> <path>
# @completion path none
# @summary Take one path out of the transient list: the stage exists and lists it; then the line is removed
# @group   provisioning
# @see     stage rescue transient add
#@end
___stage_rescue_transient_drop2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue entry listed '$1' transient '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue entry unlink '$1' transient '$2'"
}
#@help ___stage_rescue_transient_write1
# @command stage rescue transient write <stage>
# @summary Write the transient frame into the mounted rescue root: the stage exists, the root is mounted, the transient list is not empty; then 'stage rescue transient file' -- the rc.d script rescue_union (from the template), the mount point of its memory layers (/.rescue-union), /etc/rc.conf.d/rescue_union naming the listed paths, /etc/rc.conf.d/tmp (tmpmfs) and /etc/rc.conf.d/var (varmfs, unless /var is itself in the list)
# @group   deploy
# @example elebake stage rescue transient write daily-v1
# @see     stage rescue transient add
# @see     stage rescue push
#@end
___stage_rescue_transient_write1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue dataset mounted '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue list filled '$1' transient"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue transient file '$1'"
}
#@help _stage_rescue_transient_file1
# @command stage rescue transient file <stage>
# @summary Act terminal (root): the heredocs that write <rescue root>/usr/local/etc/rc.d/rescue_union (0555, the template rescue/rescue_union of this elebake), the directory /.rescue-union the layers mount on, /etc/rc.conf.d/rescue_union (enable, the paths), /etc/rc.conf.d/tmp (tmpmfs="YES") and /etc/rc.conf.d/var (varmfs="YES", or "NO" when /var is a listed path: the image's /var is the base of its layer), each 0644
# @group   deploy
# @internal
# @env     ELEBAKE_TEMPLATE_DIR  where rescue/rescue_union is read from
#@end
_stage_rescue_transient_file1() {
        local alt="$ELEBAKE_ROOT/mnt/$1-rescue" paths="" varmfs=YES
        paths=$(grep . "$ELEBAKE_BASE/stage/$1/rescue/transient" 2>/dev/null | tr '\n' ' ' | sed 's/ $//')
        grep -qx /var "$ELEBAKE_BASE/stage/$1/rescue/transient" 2>/dev/null && varmfs=NO
        emit_note "stage rescue transient write '$1': rc.d rescue_union over $paths, tmpmfs, varmfs=$varmfs, into $alt"
        printf '%s\n' "$MODIFY_DIR_CREATE '$alt/usr/local/etc/rc.d' '$alt/etc/rc.conf.d' '$alt/.rescue-union'"
        printf '%s\n' "cat > '$alt/usr/local/etc/rc.d/rescue_union' <<'ELVUNION'"
        cat "$ELEBAKE_TEMPLATE_DIR/rescue/rescue_union"
        printf '%s\n' "ELVUNION"
        printf '%s\n' "$MODIFY_FILE_PERMS 0555 '$alt/usr/local/etc/rc.d/rescue_union'"
        printf '%s\n' "printf 'rescue_union_enable=\"YES\"\\nrescue_union_paths=\"%s\"\\n' '$paths' > '$alt/etc/rc.conf.d/rescue_union'"
        printf '%s\n' "printf 'tmpmfs=\"YES\"\\n' > '$alt/etc/rc.conf.d/tmp'"
        printf '%s\n' "printf 'varmfs=\"$varmfs\"\\n' > '$alt/etc/rc.conf.d/var'"
        printf '%s\n' "$MODIFY_FILE_PERMS 0644 '$alt/etc/rc.conf.d/rescue_union' '$alt/etc/rc.conf.d/tmp' '$alt/etc/rc.conf.d/var'"
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
# @command stage rescue entry valid <tools|config|local> <entry>
# @completion entry none
# @summary A tools entry is a package name (letters, digits, _ . + -), a config or transient entry an absolute path without blank or newline, a local entry an rc.conf line (name="value"): a comment line, else an error line
# @group   provisioning
# @internal
# @see     stage rescue tools add
#@end
__stage_rescue_entry_valid2() {
        local form="" what=""
        case "$1" in
                tools)  form='[A-Za-z0-9][A-Za-z0-9_.+-]*'; what='package name' ;;
                local)  form='[A-Za-z_][A-Za-z0-9_]*="[^"]*"'; what='rc.conf line (name="value")' ;;
                *)      form='/[^ 	][^ 	]*'; what='absolute path' ;;
        esac
        if printf '%s\n' "$2" | grep -qx "$form"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'rescue $1 entry $2 has the form'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage rescue $1 add: not a $what: $2'"
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
# @summary The rescue description of the stage as notes: dataset, pool, package, key file, tools, config, local lines, sources, users, the cards, the patches, the last snapshot and what each medium received; the stage exists
# @group   provisioning
# @example elebake stage rescue show daily-v1
# @see     stage rescue status
#@end
___stage_rescue_show1() {
        local f="" line=""
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log '# rescue of $1'"
        for f in dataset pool package keyfile snapshot; do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log '#   $f: $(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/$f" 2>/dev/null)'"
        done
        for f in tools config local transient; do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log '#   $f ($(grep -c . "$ELEBAKE_BASE/stage/$1/rescue/$f" 2>/dev/null) lines):'"
                grep . "$ELEBAKE_BASE/stage/$1/rescue/$f" 2>/dev/null | while IFS= read -r line; do
                        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log $(sq "#     $line")"
                done
        done
        for f in "$ELEBAKE_BASE/stage/$1"/rescue/sources/* "$ELEBAKE_BASE/stage/$1"/rescue/users/*; do
                test -f "$f" && printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log '#   $(basename "$(dirname "$f")") ${f##*/}: $(sed -n 1p "$f")'"
        done
        for f in "$ELEBAKE_BASE/stage/$1"/rescue/cards/*; do
                test -f "$f" && printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log '#   card ${f##*/}: $(sed -n 1p "$f") received $(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/media/${f##*/}" 2>/dev/null)'"
        done
        for f in "$ELEBAKE_BASE/stage/$1"/rescue/patches/*; do
                test -f "$f" || continue
                line=$(sed -n 1p "$f")
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log $(sq "#   patch ${f##*/}: ${line#*:} as ${line%%:*}")"
        done
        :
}

#@help ___stage_dump_rescue1
# @command stage dump rescue <stage>
# @summary Dump block: the rescue description replayed -- dataset, pool, package and keyfile add, one source add per tool, one patch add per patch, one user record per user (the record as it was read, not read again on the target), one tools, config, local and transient add per line, one card add per medium; the repository, snapshots and what a card received are built or observed and stay out; a stage without a description emits nothing and succeeds
# @group   provisioning
# @internal
# @see     stage dump
# @see     stage rescue show
#@end
___stage_dump_rescue1() {
        local r="" f=""
        for r in dataset pool package keyfile; do
                test -s "$ELEBAKE_BASE/stage/$1/rescue/$r" && printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue $r add '$1' '$(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/$r")'"
        done
        for f in "$ELEBAKE_BASE/stage/$1"/rescue/sources/*; do
                test -f "$f" && printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue source add '$1' '${f##*/}' '$(sed -n 1p "$f")'"
        done
        for f in "$ELEBAKE_BASE/stage/$1"/rescue/users/*; do
                test -f "$f" && printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue user record '$1' '${f##*/}' '$(sed -n 1p "$f")'"
        done
        for r in tools config local transient; do
                grep . "$ELEBAKE_BASE/stage/$1/rescue/$r" 2>/dev/null | while read -r f; do
                        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue $r add '$1' '$f'"
                done
        done
        for f in "$ELEBAKE_BASE/stage/$1"/rescue/cards/*; do
                test -f "$f" && printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue card add '$1' '${f##*/}' '$(sed -n 1p "$f")'"
        done
        for f in "$ELEBAKE_BASE/stage/$1"/rescue/patches/*; do
                test -f "$f" || continue
                r=$(sed -n 1p "$f")
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue patch add '$1' '${f##*/}' '${r#*:}' '${r%%:*}'"
        done
        :
}

#@help ___stage_rescue_dataset_make1
# @command stage rescue dataset make <stage>
# @summary Create the rescue root on the production pool, empty: the stage exists, the dataset is recorded; then 'stage rescue dataset create' (ONE dataset, mountpoint / and canmount noauto -- a boot environment the loader can name and nothing mounts by itself; the meta package fills it)
# @group   deploy
# @see     stage rescue package install
#@end
___stage_rescue_dataset_make1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue value set '$1' dataset"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue dataset create '$1'"
}

#@help _stage_rescue_dataset_create1
# @command stage rescue dataset create <stage>
# @summary Act terminal (root): zfs create of <dataset> (mountpoint /, canmount noauto, lz4, atime off); an existing dataset is kept
# @group   deploy
# @internal
#@end
_stage_rescue_dataset_create1() {
        local ds=""
        ds=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/dataset" 2>/dev/null)
        emit_note "stage rescue dataset make '$1': $ds (mountpoint /, canmount noauto)"
        printf '%s\n' "zfs list -H '$ds' >/dev/null 2>&1 || zfs create -o mountpoint=/ -o canmount=noauto -o compression=lz4 -o atime=off '$ds' || exit 1"
        printf '%s\n' "zfs list -o name,mountpoint,canmount '$ds'"
}

#@help ___stage_rescue_dataset_open1
# @command stage rescue dataset open <stage>
# @summary Mount the rescue root for editing under $ELEBAKE_ROOT/mnt/<stage>-rescue (mount -t zfs, so the mountpoint property stays /), devfs below it: the stage exists, the dataset is recorded, nothing is mounted there yet; then 'stage rescue dataset mount'
# @group   provisioning
# @example elebake stage rescue dataset open daily-v1
# @see     stage rescue dataset close
# @see     stage rescue package install
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
# @summary Act terminal (root): mkdir of the mount point, mount -t zfs of <dataset> there, devfs below it
# @group   provisioning
# @internal
# @see     stage rescue dataset open
#@end
_stage_rescue_dataset_mount1() {
        local ds="" alt=""
        ds=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/dataset" 2>/dev/null)
        alt="$ELEBAKE_ROOT/mnt/$1-rescue"
        emit_note "stage rescue dataset open '$1': $ds on $alt"
        printf '%s\n' "$MODIFY_DIR_CREATE '$alt'"
        printf '%s\n' "mount -t zfs '$ds' '$alt' || exit 1"
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

#@help __stage_rescue_list_filled2
# @command stage rescue list filled <stage> <tools|config>
# @summary The list has at least one entry: a comment line, else an error line naming the add command
# @group   provisioning
# @internal
# @see     stage rescue package build
#@end
__stage_rescue_list_filled2() {
        if grep -q . "$ELEBAKE_BASE/stage/$1/rescue/$2" 2>/dev/null; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'rescue $2 of $1: $(grep -c . "$ELEBAKE_BASE/stage/$1/rescue/$2") entries'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage $1 has no rescue $2 (stage rescue $2 add $1 ...)'"
        fi
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
# @summary Act terminal (root): per listed path a copy under the rescue root -- a directory (as seen here, at generation) has its CONTENT copied into the same directory there (made if missing: a directory the packages already placed, /etc/ssh say, keeps its name instead of gaining a nested copy), a file is copied beside its parent (made if missing); cp -a keeps owner, mode and time; a path absent on this machine is reported and skipped
# @group   provisioning
# @internal
# @see     stage rescue config mirror
#@end
_stage_rescue_config_copy1() {
        local alt="$ELEBAKE_ROOT/mnt/$1-rescue" p=""
        emit_note "stage rescue config mirror '$1': $(grep -c . "$ELEBAKE_BASE/stage/$1/rescue/config" 2>/dev/null) paths into $alt"
        grep . "$ELEBAKE_BASE/stage/$1/rescue/config" 2>/dev/null | while read -r p; do
                if test -d "$p"; then
                        printf '%s\n' "if [ -d '$p' ]; then mkdir -p '$alt$p' && cp -a '$p/.' '$alt$p' || exit 1; else printf '# rescue config: absent on this machine, skipped: %s\\n' '$p' >&2; fi"
                else
                        printf '%s\n' "if [ -e '$p' ]; then mkdir -p \"\$(dirname '$alt$p')\" && cp -a '$p' '$alt$p' || exit 1; else printf '# rescue config: absent on this machine, skipped: %s\\n' '$p' >&2; fi"
                fi
        done
}

#@help ___stage_rescue_snapshot1
# @command stage rescue snapshot <stage>
# @summary Snapshot the rescue root (<dataset>@<stage>-<stamp>, recursive for any child) and record the name as the stage's rescue snapshot: the stage exists, the dataset is recorded, the root is not mounted (a quiescent tree); then 'stage rescue snapshot take', then the record
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

#@help ___stage_rescue_baseline1
# @command stage rescue baseline <stage>
# @summary Take the baseline of the rescue root -- the manifest of its tree (every file and symlink, LC_ALL=C sorted, 'path sha256=hash' / 'path symlink=target', the format of the boot manifest) signed with the pinned attest key, into stage/<stage>/rescue/baseline/MANIFEST(.asc): the stage exists, the root is mounted, the key is pinned; then 'stage rescue baseline write' as root (the tree holds root-only files) and 'attest' as the owner. Close the root and take the snapshot right after: the snapshot and this manifest are one image, 'stage rescue verify' checks a card against it
# @group   deploy
# @env     ELEBAKE_ARCHIVE_ATTEST_KEY  the pinned attest key: the baseline is signed with it
# @example elebake stage rescue baseline daily-v1
# @see     stage rescue snapshot
# @see     stage rescue verify
#@end
___stage_rescue_baseline1() {
        local key="${ELEBAKE_ARCHIVE_ATTEST_KEY:-}"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue dataset mounted '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" archive key pinned"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue baseline write '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" attest '$ELEBAKE_BASE/stage/$1/rescue/baseline/MANIFEST' '$key'"
}
#@help _stage_rescue_baseline_write1
# @command stage rescue baseline write <stage>
# @summary Act terminal (root): find -x over the mounted rescue root (files and symlinks, one file system -- devfs and the like stay out), each hashed, LC_ALL=C sorted into baseline/MANIFEST.new, moved into place, the directory and the file handed to the owner (0644; the owner signs into the directory); the count on stderr. Minutes for a full root
# @group   deploy
# @internal
# @see     stage rescue baseline
#@end
_stage_rescue_baseline_write1() {
        local alt="$ELEBAKE_ROOT/mnt/$1-rescue" b="$ELEBAKE_BASE/stage/$1/rescue/baseline"
        emit_note "stage rescue baseline '$1': the manifest of $alt into $b/MANIFEST (every file hashed now, as root)"
        printf '%s\n' "$MODIFY_DIR_CREATE '$b'"
        printf '%s\n' "cd '$alt' && find -x . \\( -type f -o -type l \\) | sed 's|^\\./||' | LC_ALL=C sort | while IFS= read -r p; do if [ -L \"\$p\" ]; then printf '%s symlink=%s\\n' \"\$p\" \"\$(readlink \"\$p\")\"; else printf '%s sha256=%s\\n' \"\$p\" \"\$(sha256 -q \"\$p\")\"; fi; done > '$b/MANIFEST.new' || exit 1"
        printf '%s\n' "mv -f '$b/MANIFEST.new' '$b/MANIFEST' && chown '$(id -un)' '$b' '$b/MANIFEST' && $MODIFY_FILE_PERMS 0644 '$b/MANIFEST' || exit 1"	# the directory too: the owner signs into it
        printf '%s\n' "printf '# baseline of %s: %s entries\\n' '$1' \"\$(grep -c . '$b/MANIFEST')\" >&2"
}
#@help __stage_rescue_baseline_present1
# @command stage rescue baseline present <stage>
# @summary The baseline manifest and its signature are there (stage rescue baseline): a comment line, else an error line
# @group   deploy
# @internal
# @see     stage rescue verify
#@end
__stage_rescue_baseline_present1() {
        if test -s "$ELEBAKE_BASE/stage/$1/rescue/baseline/MANIFEST" && test -s "$ELEBAKE_BASE/stage/$1/rescue/baseline/MANIFEST.asc"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'baseline of $1: $(grep -c . "$ELEBAKE_BASE/stage/$1/rescue/baseline/MANIFEST" 2>/dev/null) entries, signed'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage rescue verify: no signed baseline for $1 (stage rescue baseline, with the root open, before the snapshot)'"
        fi
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
# @summary Prepare a medium's rescue partition, once: GELI (AES-XTS 256, HMAC/SHA256, BOOT, NODELETE, slot 0 = the rescue passphrase together with the key file, its own master key), every sector written (HMAC needs it), the pool created on it with ROOT below, exported again: the stage exists, the medium is inserted, the partition, the pool and the key file are recorded, the passphrase file is there; then 'stage rescue card geli' and 'stage rescue card pool'
# @group   deploy
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the passphrase file lives on (default /tmp/ram)
# @example elebake stage rescue card init daily-v1 b
# @see     stage rescue card add
# @see     stage rescue keyfile add
# @see     stage rescue push
#@end
___stage_rescue_card_init2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage medium present '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue value set '$1' 'cards/$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue value set '$1' pool"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue value set '$1' keyfile"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue passphrase present"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue card geli '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue card pool '$1' '$2'"
}

#@help _stage_rescue_card_geli2
# @command stage rescue card geli <stage> <medium>
# @summary Act terminal (root): geli init of the medium's rescue partition (-e AES-XTS -l 256 -a HMAC/SHA256 -s 4096 -b -T, PBKDF2 iterations as zroot, the passphrase from the file AND the recorded key file), attach, dd of zeros over the whole provider (ENOSPC ends it), the provider left attached for the pool
# @group   deploy
# @internal
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the passphrase file lives on (default /tmp/ram)
#@end
_stage_rescue_card_geli2() {
        local part="" key="" d="${ELEBAKE_TPM_WORKDIR:-/tmp/ram}"
        part=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/cards/$2" 2>/dev/null)
        key="$ELEBAKE_BASE/stage/$1/boot$(sed -n 's|^/boot||p' "$ELEBAKE_BASE/stage/$1/rescue/keyfile" 2>/dev/null)"	# the loader's path, in the stage's boot tree
        emit_note "stage rescue card init '$1' medium '$2': geli on /dev/$part (passphrase + $key), then zeros over the whole provider (minutes)"
        printf '%s\n' "test -s '$key' || { printf '# Error: key file %s missing or empty (the stage boot tree carries what the loader loads)\\n' '$key' >&2; exit 1; }"
        printf '%s\n' "geli init -e AES-XTS -l 256 -a HMAC/SHA256 -s 4096 -b -T -i 9999999 -J '$d/auth-rescue.txt' -K '$key' '/dev/$part' || exit 1"
        printf '%s\n' "geli attach -j '$d/auth-rescue.txt' -k '$key' '/dev/$part' || exit 1"
        printf '%s\n' "dd if=/dev/zero of='/dev/$part.eli' bs=1m 2>/dev/null; geli list '$part.eli' | grep -e Flags -e EncryptionAlgorithm -e KeyLength"
}

#@help _stage_rescue_card_pool2
# @command stage rescue card pool <stage> <medium>
# @summary Act terminal (root): zpool create of the recorded pool on the attached provider (ashift 12, autotrim off, mountpoint none, canmount off, lz4), ROOT below it (the container the rescue root arrives in), then export and geli detach -- the card is ready to receive
# @group   deploy
# @internal
#@end
_stage_rescue_card_pool2() {
        local part="" pool="" alt=""
        part=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/cards/$2" 2>/dev/null)
        pool=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/pool" 2>/dev/null)
        alt="$ELEBAKE_ROOT/mnt/$1-rescue-$2"
        emit_note "stage rescue card init '$1' medium '$2': pool $pool with ROOT on /dev/$part.eli, exported"
        printf '%s\n' "$MODIFY_DIR_CREATE '$alt'"
        printf '%s\n' "zpool create -o altroot='$alt' -o ashift=12 -o autotrim=off -O mountpoint=none -O canmount=off -O compression=lz4 -O atime=off '$pool' '/dev/$part.eli' || exit 1"
        printf '%s\n' "zfs create -o mountpoint=none -o canmount=off '$pool/ROOT' || exit 1"
        printf '%s\n' "zpool export '$pool' && geli detach '/dev/$part' || exit 1"
}

#@help ___stage_rescue_card_open2
# @command stage rescue card open <stage> <medium>
# @summary Attach the medium's rescue partition (passphrase and key file) and import its pool without mounting (altroot $ELEBAKE_ROOT/mnt/<stage>-rescue-<medium>): the stage exists, the medium is inserted, the partition, the pool and the key file are recorded, the passphrase file is there; then 'stage rescue card attach'
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
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue value set '$1' keyfile"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue passphrase present"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue card attach '$1' '$2'"
}

#@help _stage_rescue_card_attach2
# @command stage rescue card attach <stage> <medium>
# @summary Act terminal (root): geli attach with the passphrase file and the key file, zpool import -f -N of the recorded pool from the provider under the altroot (-f: a rescue boot leaves the pool in use by the rescue hostid; the key opened it, the GUID is checked after)
# @group   deploy
# @internal
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the passphrase file lives on (default /tmp/ram)
# @see     stage rescue card open
#@end
_stage_rescue_card_attach2() {
        local part="" pool="" key="" alt="" d="${ELEBAKE_TPM_WORKDIR:-/tmp/ram}"
        part=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/cards/$2" 2>/dev/null)
        pool=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/pool" 2>/dev/null)
        key="$ELEBAKE_BASE/stage/$1/boot$(sed -n 's|^/boot||p' "$ELEBAKE_BASE/stage/$1/rescue/keyfile" 2>/dev/null)"	# the loader's path, in the stage's boot tree
        alt="$ELEBAKE_ROOT/mnt/$1-rescue-$2"
        emit_note "stage rescue card open '$1' medium '$2': /dev/$part attached (passphrase + $key), pool $pool imported (-N, altroot $alt)"
        printf '%s\n' "$MODIFY_DIR_CREATE '$alt'"
        printf '%s\n' "geli status '$part.eli' >/dev/null 2>&1 || geli attach -j '$d/auth-rescue.txt' -k '$key' '/dev/$part' || exit 1"
        printf '%s\n' "zpool import -f -d '/dev/$part.eli' -R '$alt' -N '$pool' || exit 1"	# -f: a rescue boot leaves the pool in use by another hostid; GELI opened with our passphrase and key, the GUID is checked after
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
# @summary Send the recorded snapshot to the medium's card: the stage exists, the snapshot is recorded, the card opens (stage rescue card open), the stream goes (the whole tree the first time, the increment since what the card holds after), bootfs is set, the root on the card is set read-only (the rescue is transient), the snapshot on the card is verified against the source, the receipt is recorded, the card closes
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
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue card readonly '$1' '$2'"
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
# @summary Act terminal (root): zfs send -R <dataset>@<snapshot> | zfs recv -F -u <pool>/ROOT/<name> -- the whole root, unmounted on arrival, under the name it carries on the production pool
# @group   deploy
# @internal
#@end
_stage_rescue_send_whole2() {
        local ds="" pool="" snap=""
        ds=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/dataset" 2>/dev/null)
        pool=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/pool" 2>/dev/null)
        snap=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/snapshot" 2>/dev/null)
        emit_note "stage rescue push '$1' medium '$2': the whole root $ds@$snap -> $pool/ROOT/${ds##*/}"
        printf '%s\n' "zfs send -R '$ds@$snap' | zfs recv -F -u '$pool/ROOT/${ds##*/}' || exit 1"
}

#@help _stage_rescue_send_increment2
# @command stage rescue send increment <stage> <medium>
# @summary Act terminal (root): zfs send -R -I @<received> <dataset>@<snapshot> | zfs recv -F -u <pool>/ROOT/<name> -- what changed since the medium's last receipt
# @group   deploy
# @internal
#@end
_stage_rescue_send_increment2() {
        local ds="" pool="" snap="" prev=""
        ds=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/dataset" 2>/dev/null)
        pool=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/pool" 2>/dev/null)
        snap=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/snapshot" 2>/dev/null)
        prev=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/media/$2" 2>/dev/null)
        emit_note "stage rescue push '$1' medium '$2': the increment @$prev .. @$snap of $ds -> $pool/ROOT/${ds##*/}"
        printf '%s\n' "zfs send -R -I '@$prev' '$ds@$snap' | zfs recv -F -u '$pool/ROOT/${ds##*/}' || exit 1"
}

#@help _stage_rescue_card_bootfs2
# @command stage rescue card bootfs <stage> <medium>
# @summary Act terminal (root): zpool set bootfs=<pool>/ROOT/<name> on the card's pool -- what the loader boots when it names the rescue root
# @group   deploy
# @internal
#@end
_stage_rescue_card_bootfs2() {
        local ds="" pool=""
        ds=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/dataset" 2>/dev/null)
        pool=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/pool" 2>/dev/null)
        emit_note "stage rescue push '$1' medium '$2': bootfs $pool/ROOT/${ds##*/}"
        printf '%s\n' "zpool set bootfs='$pool/ROOT/${ds##*/}' '$pool' || exit 1"
}

#@help _stage_rescue_card_readonly2
# @command stage rescue card readonly <stage> <medium>
# @summary Act terminal (root): zfs set readonly=on <pool>/ROOT/<name> on the card -- the rescue root is an image, nothing persists on it (stage rescue transient gives the sessions their memory)
# @group   deploy
# @internal
#@end
_stage_rescue_card_readonly2() {
        local ds="" pool=""
        ds=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/dataset" 2>/dev/null)
        pool=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/pool" 2>/dev/null)
        emit_note "stage rescue push '$1' medium '$2': readonly=on $pool/ROOT/${ds##*/}"
        printf '%s\n' "zfs set readonly=on '$pool/ROOT/${ds##*/}' || exit 1"
}

#@help _stage_rescue_card_check2
# @command stage rescue card check <stage> <medium>
# @summary Act terminal (root): the GUID of <pool>/ROOT/<name>@<snapshot> on the card equals the GUID of the source snapshot -- the same data, proven by ZFS itself -- and the root on the card is read-only; a mismatch or a writable root is an error
# @group   deploy
# @internal
#@end
_stage_rescue_card_check2() {
        local ds="" pool="" snap=""
        ds=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/dataset" 2>/dev/null)
        pool=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/pool" 2>/dev/null)
        snap=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/snapshot" 2>/dev/null)
        emit_note "stage rescue verify '$1' medium '$2': GUID of $pool/ROOT/${ds##*/}@$snap against $ds@$snap"
        printf '%s\n' "a=\$(zfs get -H -o value guid '$pool/ROOT/${ds##*/}@$snap') && b=\$(zfs get -H -o value guid '$ds@$snap') && [ -n \"\$a\" ] && [ \"\$a\" = \"\$b\" ] && printf '# rescue on medium %s: %s verified (guid %s)\\n' '$2' '$snap' \"\$a\" >&2 || { printf '# Error: rescue on medium %s does not hold %s (guid %s vs %s)\\n' '$2' '$snap' \"\${a:-none}\" \"\${b:-none}\" >&2; exit 1; }"
        printf '%s\n' "[ \"\$(zfs get -H -o value readonly '$pool/ROOT/${ds##*/}')\" = on ] && printf '# rescue on medium %s: root read-only\\n' '$2' >&2 || { printf '# Error: rescue on medium %s: the root is writable (readonly=off) -- not the image that was pushed\\n' '$2' >&2; exit 1; }"
}

#@help ___stage_rescue_verify2
# @command stage rescue verify <stage> <medium>
# @summary Check a card against the baseline without sending, three questions: does the card hold the recorded snapshot (GUID) with a read-only root, is the baseline manifest signed by the pinned key, and is the tree on the card exactly the baseline (every entry present and unchanged, nothing beyond it) -- the stage exists, the snapshot is recorded, the baseline is there and verified, the card opens, the root is mounted read-only, the tree is checked, the root is unmounted, the card closes. Anything found is an error naming it
# @group   deploy
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the passphrase file lives on (default /tmp/ram)
# @env     ELEBAKE_ARCHIVE_ATTEST_KEY  the pinned attest key: the baseline signature is checked against it
# @example elebake stage rescue verify daily-v1 b
# @see     stage rescue push
# @see     stage rescue baseline
#@end
___stage_rescue_verify2() {
        local key="${ELEBAKE_ARCHIVE_ATTEST_KEY:-}"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue value set '$1' snapshot"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue baseline present '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" attest verify '$ELEBAKE_BASE/stage/$1/rescue/baseline/MANIFEST' '$key'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue card open '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue card check '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue card mount '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue tree check '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue card umount '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue card close '$1' '$2'"
}
#@help _stage_rescue_card_mount2
# @command stage rescue card mount <stage> <medium>
# @summary Act terminal (root): mount -t zfs -o ro of <pool>/ROOT/<name> on <root>/mnt/<stage>-rescue-<medium>/root -- the card's tree, readable, untouched
# @group   deploy
# @internal
# @see     stage rescue verify
#@end
_stage_rescue_card_mount2() {
        local ds="" pool="" alt="$ELEBAKE_ROOT/mnt/$1-rescue-$2/root"
        ds=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/dataset" 2>/dev/null)
        pool=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/pool" 2>/dev/null)
        emit_note "stage rescue verify '$1' medium '$2': $pool/ROOT/${ds##*/} mounted read-only on $alt"
        printf '%s\n' "$MODIFY_DIR_CREATE '$alt'"
        printf '%s\n' "mount -t zfs -o ro '$pool/ROOT/${ds##*/}' '$alt' || exit 1"
}
#@help _stage_rescue_card_umount2
# @command stage rescue card umount <stage> <medium>
# @summary Act terminal (root): umount of the card's tree mounted by 'stage rescue card mount'
# @group   deploy
# @internal
# @see     stage rescue verify
#@end
_stage_rescue_card_umount2() {
        local alt="$ELEBAKE_ROOT/mnt/$1-rescue-$2/root"
        emit_note "stage rescue verify '$1' medium '$2': $alt unmounted"
        printf '%s\n' "umount '$alt' || exit 1"
}
#@help _stage_rescue_tree_check2
# @command stage rescue tree check <stage> <medium>
# @summary Act terminal (root): the mounted card tree against the baseline manifest -- every entry present and unchanged (MISSING, CHANGED, MISSING SYMLINK, RETARGETED), and no file or symlink on the card the manifest does not list (UNLISTED); the findings on stderr, any finding exits 1; the count line otherwise. Minutes for a full root
# @group   deploy
# @internal
# @see     stage rescue verify
#@end
_stage_rescue_tree_check2() {
        local alt="$ELEBAKE_ROOT/mnt/$1-rescue-$2/root" m="$ELEBAKE_BASE/stage/$1/rescue/baseline/MANIFEST"
        emit_note "stage rescue verify '$1' medium '$2': the tree on $alt against the baseline ($(grep -c . "$m" 2>/dev/null) entries)"
        # POSIX sh for the root interpreter: no process substitution; the path list of the manifest goes to a temp file for comm
        printf '%s\n' "cd '$alt' || exit 1"
        printf '%s\n' "t=\$(mktemp) || exit 1"
        printf '%s\n' "sed -E 's/ (sha256|symlink)=[^ ]*\$//' '$m' | LC_ALL=C sort > \"\$t\""
        printf '%s\n' "f=\$( { while IFS= read -r l; do p=\${l% *}; v=\${l##* }; case \"\$v\" in symlink=*) if [ ! -L \"\$p\" ]; then echo \"MISSING SYMLINK \$p\"; elif [ \"\$(readlink \"\$p\")\" != \"\${v#symlink=}\" ]; then echo \"RETARGETED \$p\"; fi;; sha256=*) if [ ! -f \"\$p\" ]; then echo \"MISSING \$p\"; elif [ \"\$(sha256 -q \"\$p\")\" != \"\${v#sha256=}\" ]; then echo \"CHANGED \$p\"; fi;; esac; done < '$m'; find -x . \\( -type f -o -type l \\) | sed 's|^\\./||' | LC_ALL=C sort | LC_ALL=C comm -13 \"\$t\" - | sed 's/^/UNLISTED /'; } )"
        printf '%s\n' "rm -f \"\$t\""
        printf '%s\n' "if [ -n \"\$f\" ]; then printf '%s\\n' \"\$f\" >&2; printf '# Error: rescue on medium %s differs from the baseline (%s findings)\\n' '$2' \"\$(printf '%s\\n' \"\$f\" | grep -c .)\" >&2; exit 1; fi"
        printf '%s\n' "printf '# rescue on medium %s: the tree is the baseline (%s entries)\\n' '$2' \"\$(grep -c . '$m')\" >&2"
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

#@help ___stage_rescue_package_add2
# @command stage rescue package add <stage> <name>
# @completion name none
# @summary Record the name of the meta package that describes the rescue system (illyria-rescue): the stage exists, the name is a package name; then written (immutable, drop first to change)
# @group   deploy
# @example elebake stage rescue package add daily-v1 illyria-rescue
# @see     stage rescue package build
#@end
___stage_rescue_package_add2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue entry valid tools '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue value write '$1' package '$2'"
}

#@help ___stage_rescue_package_drop1
# @command stage rescue package drop <stage>
# @summary Forget the meta package name of the stage: the stage exists and has the record; then it is removed
# @group   deploy
#@end
___stage_rescue_package_drop1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue value set '$1' package"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue value erase '$1' package"
}

#@help ___stage_rescue_keyfile_add2
# @command stage rescue keyfile add <stage> <path>
# @completion path files
# @summary Record the GELI key file of the cards as the loader names it (/boot/keys/zroot.key, in the boot tree on the card; the host reads the stage copy, stage/<stage>/boot<path>): the stage exists, the path is absolute; then written (immutable, drop first to change). The slot opens with the rescue passphrase AND this file, as zroot does
# @group   deploy
# @example elebake stage rescue keyfile add daily-v1 /boot/keys/zroot.key
# @see     stage rescue card init
# @see     stage rescue card rekey
#@end
___stage_rescue_keyfile_add2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue entry valid config '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue value write '$1' keyfile '$2'"
}

#@help ___stage_rescue_keyfile_drop1
# @command stage rescue keyfile drop <stage>
# @summary Forget the key file record of the stage: the stage exists and has the record; then it is removed
# @group   deploy
#@end
___stage_rescue_keyfile_drop1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue value set '$1' keyfile"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue value erase '$1' keyfile"
}

#@help ___stage_rescue_source_add3
# @command stage rescue source add <stage> <tool> <path>
# @completion tool none
# @completion path dirs
# @summary Record the checkout a tool is packaged from (elvboot, vpn-switch): the stage exists, the tool is a package name, the path is absolute; then written under rescue/sources/<tool> (immutable, drop first to change). 'stage rescue tool package' runs 'make package' there
# @group   deploy
# @example elebake stage rescue source add daily-v1 elvboot /home/brj/git/elvboot
# @see     stage rescue tool package
#@end
___stage_rescue_source_add3() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue entry valid tools '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue entry valid config '$3'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue value write '$1' 'sources/$2' '$3'"
}

#@help ___stage_rescue_source_drop2
# @command stage rescue source drop <stage> <tool>
# @completion tool none
# @summary Forget the checkout record of a tool: the stage exists and has the record; then it is removed
# @group   deploy
#@end
___stage_rescue_source_drop2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue value set '$1' 'sources/$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue value erase '$1' 'sources/$2'"
}

#@help ___stage_rescue_local_add2
# @command stage rescue local add <stage> <line>
# @completion line none
# @summary Take one rc.conf line into /etc/rc.conf.local of the rescue system -- what the rescue deliberately keeps different from the production, whose rc.conf travels 1:1 (sshd_enable="NO"): the stage exists, the line is name="value"; a line already listed is a note
# @group   deploy
# @example elebake stage rescue local add daily-v1 'sshd_enable="NO"'
# @see     stage rescue local write
#@end
___stage_rescue_local_add2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue entry valid local $(sq "$2")"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue entry write '$1' local $(sq "$2")"
}

#@help ___stage_rescue_local_drop2
# @command stage rescue local drop <stage> <line>
# @completion line none
# @summary Take one line out of the rc.conf.local list: the stage exists and lists it; then the line is removed
# @group   deploy
#@end
___stage_rescue_local_drop2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue entry listed '$1' local $(sq "$2")"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue entry unlink '$1' local $(sq "$2")"
}

#@help ___stage_rescue_local_write1
# @command stage rescue local write <stage>
# @summary Write /etc/rc.conf.local of the mounted rescue root from the local lines: the stage exists, the root is mounted, the list is not empty; then 'stage rescue local file'
# @group   deploy
# @see     stage rescue local add
#@end
___stage_rescue_local_write1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue dataset mounted '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue list filled '$1' local"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue local file '$1'"
}

#@help _stage_rescue_local_file1
# @command stage rescue local file <stage>
# @summary Act terminal (root): the heredoc that writes <rescue root>/etc/rc.conf.local (0644) from the recorded lines, with a header naming the stage
# @group   deploy
# @internal
#@end
_stage_rescue_local_file1() {
        local alt="$ELEBAKE_ROOT/mnt/$1-rescue"
        emit_note "stage rescue local write '$1': $(grep -c . "$ELEBAKE_BASE/stage/$1/rescue/local" 2>/dev/null) lines into $alt/etc/rc.conf.local"
        printf '%s\n' "cat > '$alt/etc/rc.conf.local' <<'ELVLOCAL'"
        printf '# rc.conf.local of the rescue system (elebake stage rescue local, stage %s): what differs from rc.conf\n' "$1"
        grep . "$ELEBAKE_BASE/stage/$1/rescue/local" 2>/dev/null
        printf '%s\n' "ELVLOCAL"
        printf '%s\n' "$MODIFY_FILE_PERMS 0644 '$alt/etc/rc.conf.local'"
}

#@help ___stage_rescue_user_add2
# @command stage rescue user add <stage> <name>
# @completion name none
# @summary Take a user of this machine into the rescue system: the stage exists, the user exists here (pw usershow); then recorded under rescue/users/<name> as read from the production -- uid, gid, groups, home, shell, gecos (immutable, drop first to change). The password hash is not a record: 'stage rescue user mirror' takes it from master.passwd when it runs as root. 'root' takes its password only
# @group   deploy
# @example elebake stage rescue user add daily-v1 brj
# @see     stage rescue user mirror
#@end
___stage_rescue_user_add2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue user exists '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue user record '$1' '$2' $(sq "$(pw usershow -n "$2" 2>/dev/null | awk -F: '{print $3 ":" $4 ":" $9 ":" $10 ":" $8}'):$(id -Gn "$2" 2>/dev/null | tr ' ' ',')")"
}

#@help __stage_rescue_user_exists1
# @command stage rescue user exists <name>
# @completion name none
# @summary The user exists on this machine (pw usershow): a comment line, else an error line
# @group   deploy
# @internal
#@end
__stage_rescue_user_exists1() {
        if pw usershow -n "$1" > /dev/null 2>&1; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'user $1 exists here'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage rescue user add: no such user on this machine: $1'"
        fi
}

#@help ___stage_rescue_user_record3
# @command stage rescue user record <stage> <name> <fields>
# @completion name none
# @completion fields none
# @summary Record a user as read (uid:gid:home:shell:gecos:groups) -- the dump replays this line, so the target does not read its own passwd: the stage exists; then written under rescue/users/<name> (immutable, drop first to change)
# @group   deploy
# @internal
# @see     stage rescue user add
#@end
___stage_rescue_user_record3() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue entry valid tools '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue value write '$1' 'users/$2' $(sq "$3")"
}

#@help ___stage_rescue_user_drop2
# @command stage rescue user drop <stage> <name>
# @completion name none
# @summary Forget a user record of the stage: the stage exists and has the record; then it is removed
# @group   deploy
#@end
___stage_rescue_user_drop2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue value set '$1' 'users/$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue value erase '$1' 'users/$2'"
}

#@help ___stage_rescue_user_mirror1
# @command stage rescue user mirror <stage>
# @summary Create the recorded users in the mounted rescue root with the uid, gid, groups, home and shell they have here, and copy their password hashes (and root's) from master.passwd: the stage exists, the root is mounted, users are recorded; then 'stage rescue user write'
# @group   deploy
# @see     stage rescue user add
#@end
___stage_rescue_user_mirror1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue dataset mounted '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue users recorded '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue user write '$1'"
}

#@help __stage_rescue_users_recorded1
# @command stage rescue users recorded <stage>
# @summary At least one user is recorded under rescue/users/: a comment line, else an error line
# @group   deploy
# @internal
#@end
__stage_rescue_users_recorded1() {
        if test -n "$(ls "$ELEBAKE_BASE/stage/$1/rescue/users" 2>/dev/null)"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'rescue users of $1: $(ls "$ELEBAKE_BASE/stage/$1/rescue/users" | tr '\n' ' ')'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage $1 has no rescue users (stage rescue user add $1 <name>)'"
        fi
}

#@help _stage_rescue_user_write1
# @command stage rescue user write <stage>
# @summary Act terminal (root): per recorded user the primary group first (pw -R groupadd with the recorded gid and the first name of the recorded group list -- id -Gn names the primary group first; an existing group is left), then pw -R useradd with the recorded fields (an existing user is left), then the password hash from this machine's master.passwd into the rescue's (pw usermod -H 0); root gets its hash the same way
# @group   deploy
# @internal
#@end
_stage_rescue_user_write1() {
        local alt="$ELEBAKE_ROOT/mnt/$1-rescue" f="" u="" rec="" gid="" grp="" others=""
        emit_note "stage rescue user mirror '$1': $(ls "$ELEBAKE_BASE/stage/$1/rescue/users" 2>/dev/null | tr '\n' ' ')into $alt (hashes from master.passwd at run time)"
        for f in "$ELEBAKE_BASE/stage/$1"/rescue/users/*; do
                test -f "$f" || continue
                u=${f##*/}; rec=$(sed -n 1p "$f")
                if test "$u" != root; then
                        gid=$(printf '%s' "$rec" | cut -d: -f2)
                        grp=$(printf '%s' "$rec" | cut -d: -f6 | cut -d, -f1)
                        others=$(printf '%s' "$rec" | cut -d: -f6 | cut -d, -f2- -s)
                        printf '%s\n' "pw -R '$alt' groupshow -g '$gid' >/dev/null 2>&1 || pw -R '$alt' groupadd -n '$grp' -g '$gid' || exit 1"
                        printf '%s\n' "pw -R '$alt' usershow -n '$u' >/dev/null 2>&1 || pw -R '$alt' useradd -n '$u' -u '$(printf '%s' "$rec" | cut -d: -f1)' -g '$gid' -d '$(printf '%s' "$rec" | cut -d: -f3)' -s '$(printf '%s' "$rec" | cut -d: -f4)' -c $(sq "$(printf '%s' "$rec" | cut -d: -f5)") ${others:+-G '$others'} -m || exit 1"
                fi
                printf '%s\n' "grep '^$u:' /etc/master.passwd | cut -d: -f2 | pw -R '$alt' usermod -n '$u' -H 0 || exit 1"
                printf '%s\n' "printf '# user %s mirrored into the rescue (uid %s)\\n' '$u' \"\$(pw -R '$alt' usershow -n '$u' | cut -d: -f3)\" >&2"
        done
}

#@help ___stage_rescue_tool_package2
# @command stage rescue tool package <stage> <tool>
# @completion tool none
# @summary Build a tool's package from its recorded checkout into the stage's repository THROUGH ITS PORT: the stage exists, the checkout is recorded, the ports framework is installed (/usr/ports/Mk); then 'stage rescue tool build' -- the distfile as a git archive of the checkout (<tool>-0.0.<commit count>.tar.gz into the stage's distfiles), 'make makesum package' in <checkout>/port with the stage's work directory and repository; the meta package names the tool by the port's origin
# @group   deploy
# @example elebake stage rescue tool package daily-v1 elvboot
# @see     stage rescue source add
# @see     stage rescue package build
#@end
___stage_rescue_tool_package2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue value set '$1' 'sources/$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue ports present"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue tool build '$1' '$2'"
}
#@help __stage_rescue_ports_present0
# @command stage rescue ports present
# @summary The ports framework is installed (/usr/ports/Mk/bsd.port.mk -- a port builds with it, the tree need not hold every port): a comment line, else an error line naming the way (git clone of the ports tree into /usr/ports)
# @group   deploy
# @internal
# @see     stage rescue tool package
#@end
__stage_rescue_ports_present0() {
        if test -f /usr/ports/Mk/bsd.port.mk; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'ports framework present (/usr/ports/Mk)'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage rescue tool package: no ports framework in /usr/ports (git clone --depth 1 https://git.FreeBSD.org/ports.git /usr/ports)'"
        fi
}

#@help _stage_rescue_tool_build2
# @command stage rescue tool build <stage> <tool>
# @completion tool none
# @summary Act terminal (owner): the stage's distfiles, work and repository directories made; the distfile written as 'git archive' of the checkout's HEAD (<tool>-<version>.tar.gz, version 0.0.<commit count> read here); then 'make makesum package' in <checkout>/port with the version in the environment (ELEBAKE_DISTVERSION: a command-line variable would travel into the dependency ports) and DISTDIR, WRKDIRPREFIX, PACKAGES of the stage -- the package lands under <repo>/All, where 'stage rescue repo index' finds it. The port's build dependencies must be installed as packages (make -C <checkout>/port missing names them); the framework would otherwise build them from source as root
# @group   deploy
# @internal
#@end
_stage_rescue_tool_build2() {
        local src="" ver="" r="$ELEBAKE_BASE/stage/$1/rescue"
        src=$(sed -n 1p "$r/sources/$2" 2>/dev/null)
        ver="0.0.$(git -C "$src" rev-list --count HEAD 2>/dev/null || printf 0)"
        emit_note "stage rescue tool package '$1' $2: the port of $src, version $ver -> $r/repo/All"
        printf '%s\n' "$MODIFY_DIR_CREATE '$r/distfiles' '$r/work' '$r/repo'"
        printf '%s\n' "git -C '$src' archive --format=tar.gz --prefix='$2-$ver/' -o '$r/distfiles/$2-$ver.tar.gz' HEAD || exit 1"
        printf '%s\n' "env ELEBAKE_DISTVERSION='$ver' make -C '$src/port' DISTDIR='$r/distfiles' WRKDIRPREFIX='$r/work' PACKAGES='$r/repo' clean makesum package || exit 1"
}

#@help ___stage_rescue_package_build1
# @command stage rescue package build <stage>
# @summary Build the meta package into the stage's repository: the stage exists, the package name is recorded, the tool list is not empty; then 'stage rescue manifest render' into +MANIFEST, 'stage rescue package create' (pkg create -M), 'stage rescue repo index' (pkg repo, and the repository configuration the install reads)
# @group   deploy
# @example elebake stage rescue package build daily-v1
# @see     stage rescue package add
# @see     stage rescue package install
#@end
___stage_rescue_package_build1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue value set '$1' package"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue list filled '$1' tools"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue manifest render '$1' > '$ELEBAKE_BASE/stage/$1/rescue/+MANIFEST'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue package create '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue repo index '$1'"
}

#@help _stage_rescue_manifest_render1
# @command stage rescue manifest render <stage>
# @summary Text terminal: the +MANIFEST (UCL) of the meta package -- name, version = the next export serial, origin sysutils/<name>, arch of this machine, the dependencies: FreeBSD-set-base, FreeBSD-kernel-generic and every recorded tool with origin and version -- a tool the stage built itself read from its package file in repo/All (pkg query -F), every other as this machine's repositories report it now; a tool neither knows ends the render
# @group   deploy
# @internal
# @see     stage rescue package build
#@end
_stage_rescue_manifest_render1() {
        local name="" serial="" repo="$ELEBAKE_BASE/stage/$1/rescue/repo" t="" ov="" f=""
        name=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/package" 2>/dev/null)
        serial=$(( $(sed -n 1p "$ELEBAKE_BASE/export/serial" 2>/dev/null || printf '0') + 1 ))
        printf 'name: "%s"\nversion: "%s"\norigin: "sysutils/%s"\ncomment: "the rescue system of stage %s: what it carries beyond base"\n' "$name" "$serial" "$name" "$1"
        printf 'desc: "A meta package without files: its dependencies are the rescue system of stage %s -- the base sets, the tools, elvboot and vpn-switch. Built by elebake stage rescue package build (serial %s)."\n' "$1" "$serial"
        printf 'maintainer: "%s@%s"\nwww: "https://github.com/enk-ode/elvboot"\nprefix: "/usr/local"\narch: "%s"\nlicenselogic: "single"\nlicenses: ["BSD2CLAUSE"]\n' "$(id -un)" "$(hostname)" "$(pkg config ABI 2>/dev/null)"
        printf 'deps: {\n'
        for t in $(printf '%s\n' FreeBSD-set-base FreeBSD-kernel-generic $(grep . "$ELEBAKE_BASE/stage/$1/rescue/tools" 2>/dev/null) | awk '!seen[$0]++'); do	# the base sets once, even when recorded as tools
                # a tool this stage built itself (tool package) is read from its package file in repo/All --
                # the stage repository has no catalogue this user could query; everything else from the machine's repositories
                f=$(ls -t "$repo/All/$t"-[0-9]*.pkg 2>/dev/null | head -n1)	# the newest build (by time: 0.0.102 sorts before 0.0.98 by name)
                if test -n "$f"; then
                        ov=$(pkg query -F "$f" '%o %v' 2>/dev/null)
                else
                        ov=$(pkg -o REPOS_DIR=/etc/pkg,/usr/local/etc/pkg/repos rquery '%o %v' "$t" 2>/dev/null | head -n1)
                fi
                test -n "$ov" || { printf '# Error: stage rescue manifest render: no repository knows %s and the stage built no package of that name (pkg update; stage rescue tool package <stage> <tool> for a recorded source)\n' "$t" >&2; exit 1; }
                printf '    "%s": { origin: "%s", version: "%s" },\n' "$t" "${ov% *}" "${ov#* }"
        done
        printf '}\n'
}

#@help _stage_rescue_package_create1
# @command stage rescue package create <stage>
# @summary Act terminal (owner): the older versions of the meta package removed from the stage's repository (pkg reads every manifest of the catalogue: an old one keeps warning), pkg create -M +MANIFEST into it (a package without files)
# @group   deploy
# @internal
#@end
_stage_rescue_package_create1() {
        local r="$ELEBAKE_BASE/stage/$1/rescue" name=""
        name=$(sed -n 1p "$r/package" 2>/dev/null)
        emit_note "stage rescue package build '$1': pkg create -M $r/+MANIFEST -> $r/repo/ (older $name packages removed)"
        printf '%s\n' "$MODIFY_DIR_CREATE '$r/repo'"
        printf '%s\n' "rm -f '$r/repo/$name'-[0-9]*.pkg"
        printf '%s\n' "pkg create -M '$r/+MANIFEST' -o '$r/repo' || exit 1"
}

#@help _stage_rescue_repo_index1
# @command stage rescue repo index <stage>
# @summary Act terminal (owner): pkg repo over the stage's repository, and rescue/repos/rescue.conf naming it (file://, enabled) -- the REPOS_DIR entry the manifest render and the install add to this machine's
# @group   deploy
# @internal
#@end
_stage_rescue_repo_index1() {
        local r="$ELEBAKE_BASE/stage/$1/rescue"
        emit_note "stage rescue package build '$1': pkg repo $r/repo, repos/rescue.conf"
        printf '%s\n' "pkg repo '$r/repo' || exit 1"
        printf '%s\n' "$MODIFY_DIR_CREATE '$r/repos'"
        printf '%s\n' "printf 'rescue: { url: \"file://%s\", enabled: yes, priority: 10 }\\n' '$r/repo' > '$r/repos/rescue.conf'"
        printf '%s\n' "ls '$r/repo'"
}

#@help ___stage_rescue_package_install1
# @command stage rescue package install <stage>
# @summary Install the meta package into the mounted rescue root -- and with it the base sets, the kernel, every tool, elvboot and vpn-switch, from this machine's repositories and the stage's: the stage exists, the root is mounted, the package is built; then 'stage rescue package pkg'
# @group   deploy
# @example elebake stage rescue package install daily-v1
# @see     stage rescue package build
#@end
___stage_rescue_package_install1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue dataset mounted '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue package built '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue package pkg '$1'"
}

#@help __stage_rescue_package_built1
# @command stage rescue package built <stage>
# @summary The stage's repository holds the meta package (rescue/repo/<name>-*.pkg): a comment line, else an error line
# @group   deploy
# @internal
#@end
__stage_rescue_package_built1() {
        local name=""
        name=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/package" 2>/dev/null)
        if test -n "$(ls "$ELEBAKE_BASE/stage/$1/rescue/repo/$name"-*.pkg 2>/dev/null)"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'meta package $name built: $(ls "$ELEBAKE_BASE/stage/$1/rescue/repo/$name"-*.pkg | tr '\n' ' ')'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage $1: meta package ${name:-?} not built (stage rescue package build $1)'"
        fi
}

#@help _stage_rescue_package_pkg1
# @command stage rescue package pkg <stage>
# @summary Act terminal (root): the repository fingerprints copied under the rescue root (pkg reads them relative to --rootdir), pkg update over this machine's repositories plus the stage's, pkg install of the meta package and pkg upgrade (the tools built anew; install alone leaves an older elvboot in place), pkg info of the meta package
# @group   deploy
# @internal
#@end
_stage_rescue_package_pkg1() {
        local alt="$ELEBAKE_ROOT/mnt/$1-rescue" r="$ELEBAKE_BASE/stage/$1/rescue" name=""
        name=$(sed -n 1p "$r/package" 2>/dev/null)
        emit_note "stage rescue package install '$1': $name and everything it depends on into $alt"
        printf '%s\n' "$MODIFY_DIR_CREATE '$alt/usr/share/keys'"
        printf '%s\n' "cp -a /usr/share/keys/pkg /usr/share/keys/pkgbase-* '$alt/usr/share/keys/' 2>/dev/null; :"
        printf '%s\n' "pkg --rootdir '$alt' -o REPOS_DIR=/etc/pkg,/usr/local/etc/pkg/repos,'$r/repos' update || exit 1"
        printf '%s\n' "pkg --rootdir '$alt' -o REPOS_DIR=/etc/pkg,/usr/local/etc/pkg/repos,'$r/repos' install -y '$name' || exit 1"
        printf '%s\n' "pkg --rootdir '$alt' -o REPOS_DIR=/etc/pkg,/usr/local/etc/pkg/repos,'$r/repos' upgrade -y || exit 1"	# install takes the meta package only when its dependencies are there in SOME version: the tools built anew need the upgrade
        printf '%s\n' "pkg --rootdir '$alt' info '$name'"
}

#@help ___stage_rescue_patch_add4
# @command stage rescue patch add <stage> <name> <script> <user>
# @completion name none
# @completion script none
# @completion user none
# @summary Record a patch of the built rescue root: the stage exists, the name has the form of a record name, the script is an absolute path IN THE IMAGE (the package's own copy under its template tree, e.g. /usr/local/lib/elebake/template/rescue/elvboot-import-db-patch.sh), the user exists on this machine; then written under rescue/patches/<name> as '<user>:<script>' (immutable, drop first to change) and the resource directory $ELEBAKE_BASE/.resource/<name>/ made -- the fixed place the owner fills with what the script takes as its second argument (the export pair of a database: dump.sh with its .asc, bundle.tar.gz, and signer.asc, the signer's public key). 'stage rescue patch apply' runs every patch as root INSIDE the mounted root (a one-shot jail): sh <script> <user> <resources>
# @group   deploy
# @example elebake stage rescue patch add daily-v1 elvboot /usr/local/lib/elebake/template/rescue/elvboot-import-db-patch.sh brj
# @see     stage rescue patch apply
# @see     stage rescue patch drop
#@end
___stage_rescue_patch_add4() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue entry valid tools '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue entry valid config '$3'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue user exists '$4'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue value write '$1' 'patches/$2' '$4:$3'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue patch resource '$2'"
}

#@help _stage_rescue_patch_resource1
# @command stage rescue patch resource <name>
# @completion name none
# @summary Act terminal (owner): the resource directory of a patch, $ELEBAKE_BASE/.resource/<name>/ (0700), made -- what the owner places there is what the patch script receives as its third argument
# @group   deploy
# @internal
# @see     stage rescue patch add
#@end
_stage_rescue_patch_resource1() {
        printf '%s\n' "$MODIFY_DIR_CREATE '$ELEBAKE_BASE/.resource/$1'"
        printf '%s\n' "$MODIFY_FILE_PERMS 0700 '$ELEBAKE_BASE/.resource' '$ELEBAKE_BASE/.resource/$1'"
        emit_note "rescue patch $1: resources in $ELEBAKE_BASE/.resource/$1/"
}

#@help ___stage_rescue_patch_drop2
# @command stage rescue patch drop <stage> <name>
# @completion name none
# @summary Forget a patch record of the stage: the stage exists and has it; then it is removed (the resource directory stays: the owner's files)
# @group   deploy
# @example elebake stage rescue patch drop daily-v1 elvboot
# @see     stage rescue patch add
#@end
___stage_rescue_patch_drop2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue value set '$1' 'patches/$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue value erase '$1' 'patches/$2'"
}

#@help ___stage_rescue_patch_apply1
# @command stage rescue patch apply <stage>
# @summary Apply every recorded patch inside the mounted rescue root, in name order: the stage exists, the root is mounted; then per patch 'stage rescue patch complete' (its script in the root, its resource directory here) and 'stage rescue patch run' (the resources hung into the root read-only, a one-shot jail on the root, the script as root in it) -- fail-fast, the first failing patch stops the batch. No patch recorded is a note. A phase of 'stage rescue build', right before the baseline
# @group   deploy
# @example elebake stage rescue patch apply daily-v1
# @see     stage rescue patch add
# @see     stage rescue build
#@end
___stage_rescue_patch_apply1() {
        local f="" n=0
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue dataset mounted '$1'"
        for f in "$ELEBAKE_BASE/stage/$1"/rescue/patches/*; do
                test -f "$f" || continue
                n=$((n + 1))
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue patch complete '$1' '${f##*/}'"
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue patch run '$1' '${f##*/}'"
        done
        test "$n" -gt 0 || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" note 'stage $1: no rescue patch recorded (stage rescue patch add)'"
}

#@help __stage_rescue_patch_complete2
# @command stage rescue patch complete <stage> <name>
# @completion name none
# @summary The patch can run: the stage has the record, its script is a readable file IN the mounted root, its resource directory $ELEBAKE_BASE/.resource/<name> is there: a comment line, else an error line
# @group   deploy
# @internal
# @see     stage rescue patch apply
#@end
__stage_rescue_patch_complete2() {
        local alt="$ELEBAKE_ROOT/mnt/$1-rescue" rec="" user="" script=""
        rec=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/patches/$2" 2>/dev/null)
        user=${rec%%:*}; script=${rec#*:}
        if test -z "$rec"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage $1 has no rescue patch $2 (stage rescue patch add $1 $2 <script> <user>)'"
        elif ! test -r "$alt$script"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage rescue patch $2: script not in the rescue root: $alt$script (a path in the image; the package that ships it installed?)'"
        elif ! test -d "$ELEBAKE_BASE/.resource/$2"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage rescue patch $2: no resource directory $ELEBAKE_BASE/.resource/$2 (stage rescue patch add makes it)'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'rescue patch $2 complete: $script as $user in $alt, resources $ELEBAKE_BASE/.resource/$2'"
        fi
}

#@help _stage_rescue_patch_run2
# @command stage rescue patch run <stage> <name>
# @completion name none
# @summary Act terminal (root): the resource directory hung into the root read-only (nullfs on <root>/mnt/patch), a one-shot jail on the root (jail -c: no network, clean environment, gone when the command ends) running 'sh <script> <user> /mnt/patch' -- the contract of every patch script: $1 the user the patch is for, $2 the resource directory, the root is /; the mount taken down after, a non-zero exit fails the batch
# @group   deploy
# @internal
# @see     stage rescue patch apply
#@end
_stage_rescue_patch_run2() {
        local alt="$ELEBAKE_ROOT/mnt/$1-rescue" rec="" user="" script="" mnt=""
        rec=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/patches/$2" 2>/dev/null)
        user=${rec%%:*}; script=${rec#*:}; mnt="$alt/mnt/patch"
        emit_note "stage rescue patch run '$1' '$2': jail on $alt, sh $script $user /mnt/patch (resources $ELEBAKE_BASE/.resource/$2)"
        printf '%s\n' "$MODIFY_DIR_CREATE '$mnt' && mount -t nullfs -o ro '$ELEBAKE_BASE/.resource/$2' '$mnt' || exit 1"
        printf '%s\n' "jail -c path='$alt' ip4=disable ip6=disable exec.clean=1 command=/bin/sh '$script' '$user' /mnt/patch; rc=\$?"
        printf '%s\n' "umount '$mnt'; rmdir '$mnt'; test \"\$rc\" = 0 || { printf '# Error: stage rescue patch %s: the script failed (exit %s)\\n' '$2' \"\$rc\" >&2; exit 1; }"
        printf '%s\n' "printf '# rescue: patch %s applied inside %s as %s\\n' '$2' '$alt' '$user' >&2"
}

#@help ___stage_rescue_build1
# @command stage rescue build <stage>
# @summary Build the opened rescue root, in phases: the stage exists, the root is mounted; then 'stage rescue package install' (the meta package and everything it names), 'config mirror', 'local write', 'user mirror', 'transient write', 'patch apply' (the databases, built into the image by the recorded patches) and, last, 'baseline' (the signed manifest of the finished tree). Before: dataset open and package build; after: dataset close and snapshot
# @group   deploy
# @example elebake stage rescue build daily-v1
# @see     stage rescue dataset open
# @see     stage rescue package build
# @see     stage rescue patch apply
# @see     stage rescue snapshot
#@end
___stage_rescue_build1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue dataset mounted '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue package install '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue config mirror '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue local write '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue user mirror '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue transient write '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue patch apply '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue baseline '$1'"
}

#@help ___stage_rescue_card_rekey3
# @command stage rescue card rekey <stage> <medium> <old-keyfile>
# @completion old-keyfile files
# @summary After a rotation of the key file (zroot.key): set slot 0 of the medium's rescue partition to the rescue passphrase and the NEW recorded key file, opening it with the passphrase and the OLD one: the stage exists, the medium is inserted, the partition and the key file are recorded, the passphrase file is there; then 'stage rescue card setkey'
# @group   deploy
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the passphrase file lives on (default /tmp/ram)
# @example elebake stage rescue card rekey daily-v1 b /tmp/ram/zroot.key.old
# @see     stage rescue keyfile add
#@end
___stage_rescue_card_rekey3() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage medium present '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue value set '$1' 'cards/$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue value set '$1' keyfile"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue passphrase present"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rescue card setkey '$1' '$2' '$3'"
}

#@help _stage_rescue_card_setkey3
# @command stage rescue card setkey <stage> <medium> <old-keyfile>
# @completion old-keyfile files
# @summary Act terminal (root): geli setkey -n 0 with -j <passphrase> -k <old> as the opening pair and -J <passphrase> -K <new> as the new one
# @group   deploy
# @internal
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the passphrase file lives on (default /tmp/ram)
#@end
_stage_rescue_card_setkey3() {
        local part="" key="" d="${ELEBAKE_TPM_WORKDIR:-/tmp/ram}"
        part=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/rescue/cards/$2" 2>/dev/null)
        key="$ELEBAKE_BASE/stage/$1/boot$(sed -n 's|^/boot||p' "$ELEBAKE_BASE/stage/$1/rescue/keyfile" 2>/dev/null)"
        emit_note "stage rescue card rekey '$1' medium '$2': slot 0 of /dev/$part from $3 to $key (passphrase unchanged)"
        printf '%s\n' "test -s '$key' && test -s '$3' || { printf '# Error: key file missing: %s or %s\\n' '$key' '$3' >&2; exit 1; }"
        printf '%s\n' "geli setkey -n 0 -j '$d/auth-rescue.txt' -k '$3' -J '$d/auth-rescue.txt' -K '$key' '/dev/$part' || exit 1"
        printf '%s\n' "printf '# medium %s: rescue slot rekeyed to %s\\n' '$2' '$key' >&2"
}
