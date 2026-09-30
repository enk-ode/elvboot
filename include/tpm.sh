#!/bin/sh
#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Dr. Johannes Brügmann
#
# tpm.sh -- the TPM 2.0 of the machine, provisioned from the stage's leafs.
#
# The loader (fork elvboot-15.1, stand/efi/loader/local/tpm.c)
# unseals a GELI key file from a persistent object under a policy the
# TPM replays step by step; every session is salted to a persistent
# storage key. Two objects, two policies (the order of the steps is
# the order the loader replays, tpm_keyfile.h):
#
#   owner   PolicyPCR, PolicyAuthValue (the owner's passphrase), PolicyNV
#           (duress.count.nv == the value at seal time) -- the production
#           root's key file
#   duress  PolicySecret (duress.nv, the duress passphrase), PolicyPCR --
#           the decoy root's key file; duress.nv is a TPM_NT_PIN_PASS index
#           with pinLimit 0xffffffff: the TPM counts every opening and
#           never spends it -- the decoy opens as often as the line is
#           spoken, and pinCount tells the owner how often it was
#
# A boot answer of the coercion class raises duress.count.nv from earlboot
# (duress_count_act, before the stop): the second way the seal dies. The
# decoy root then opens the way every duress boot does, at the loader.
#
# An increment-only NV counter (counter.nv) is the trace of a duress boot.
# What the loader expects is in the stage's kenv leafs (template/tbl/boot-leafs.tbl):
#
#   loader.trust.tpm.key.handle        the storage key (0x81000001)
#   loader.trust.tpm.keyfile.handles   "<owner> <duress>" (0x81010001 0x81010002)
#   loader.trust.tpm.keyfile.pcrs      the policy (0,2,7)
#   loader.trust.tpm.counter.nv        the counter index (0x01c10e20)
#   loader.trust.tpm.duress.nv         the PIN index (0x01c10e24)
#   loader.trust.tpm.duress.count.nv   the second counter (0x01c10e25)
#   loader.trust.tpm.duress.count.sealed  its value when the owner object
#                                      was sealed (16 hex characters, as
#                                      tpm2_nvread prints the 8 bytes)
#   loader.trust.tpm.decoy.providers   the decoy root's provider (nda1p1)
#   loader.trust.tpm.decoy.root        the decoy root (zfs:zempty/ROOT/default)
#   loader.trust.tpm.anchor.nv         the time anchor (0x01c10e22): written
#                                      by the loader under PolicyPCR over the cap
#                                      PCR in its BOOT state, then capped
#   loader.trust.tpm.shutdown.nv       the shutdown index (0x01c10e23): written
#                                      by elvbootd under PolicyPCR over the cap PCR
#                                      in its CAPPED state (runtime only)
#   loader.trust.tpm.cap.pcr           the cap PCR (14): extended with
#                                      sha256("elvboot cap") by the loader after the
#                                      anchor write and by elvbootd after the shutdown write
#
# The owner and lockout hierarchies carry a password the machine never
# holds: 32 bytes from the owner's seed, on the RAM disk as
# auth-hierarchy.hex for the duration of a run (stage tpm hierarchy sets
# it once; every act that defines, evicts or writes as the owner passes
# the file). The boot path needs none of it -- the loader and earlboot
# authorize PolicyNV and the counter reads through the index itself
# (authread, empty index auth) -- so a root on the decoy system, or
# anywhere on the machine, can neither evict the objects nor undefine the
# counters nor rewrite pinCount.
#
# Every auth value goes to tpm2-tools as hex: -- never as file: with raw
# bytes. tpm2-tools reads a file: auth as a string and stops at the first
# NUL byte; a sha256 with a zero byte inside would seal the object under a
# truncated auth value, and the loader, which computes the full digest,
# would never open it. (illyria, the owner seal: 09 00 27 ... became the
# one byte 09.) The hex string sits in the root process's argv for the
# moment of the call; security.bsd.see_other_uids=0 keeps it to root.
#
# This family renders the tpm2-tools commands that set the TPM up to
# match, in the order the workflow tpm-seal walks them: hierarchy, key, duress (the
# PIN index), duress count (the second counter) and its record, policy,
# seal (owner, duress), counter, anchor, probe, clean; duress reset
# after a duress event. Every act runs on the RAM disk
# ELEBAKE_TPM_WORKDIR (/tmp/ram): the secret, the auth hashes and the
# session contexts never touch a disk. Threat model assumed: the machine
# is the owner's, the TPM its own, the passphrases are typed at the
# terminal and reach neither argv nor history (a hidden read, twice); the
# secret file comes from the owner's seed (hkdf-tree), its path is the
# argument. Pins: the acts that talk to the TPM run as root (sudo sh),
# the hidden read as the user (sh); with cat every act is a script to read.
#

#@help ___stage_tpm_key1
# @command stage tpm key <stage>
# @summary Make the storage key the loader's sessions salt to persistent under loader.trust.tpm.key.handle: the stage exists, the leaf is set, the work directory is a mounted RAM disk; then 'stage tpm key make' (createprimary from the owner seed -- the same key every time on the same TPM -- evictcontrol, readpublic: the name's digest is what stage baseline learn takes from loader.trust.tpm.key.sha256 after the first boot)
# @group   provisioning
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the contexts live on (default /tmp/ram)
# @example elebake stage tpm key daily-v1
# @see     stage tpm policy
# @see     stage baseline learn
#@end
___stage_tpm_key1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm leaf set '$1' loader.trust.tpm.key.handle"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm workdir ready"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm hierarchy present"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm key make '$1'"
}

#@help __stage_tpm_leaf_set2
# @command stage tpm leaf set <stage> <key>
# @summary The stage has the kenv record: a comment line, else an error line naming stage kenv add
# @group   provisioning
# @internal
# @see     stage tpm key
#@end
__stage_tpm_leaf_set2() {
        if test -s "$ELEBAKE_BASE/stage/$1/kenv/$2"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment '$2 of $1 = $(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/$2")'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage tpm: $1 has no $2 (stage kenv add $1 $2 <value>; template/tbl/boot-leafs.tbl)'"
        fi
}

#@help __stage_tpm_workdir_ready0
# @command stage tpm workdir ready
# @summary The work directory ELEBAKE_TPM_WORKDIR is a mount point (a RAM disk, so nothing lands on a disk): a comment line, else an error line with the mount command
# @group   provisioning
# @internal
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the contexts live on (default /tmp/ram)
# @see     stage tpm key
#@end
__stage_tpm_workdir_ready0() {
        local d="${ELEBAKE_TPM_WORKDIR:-/tmp/ram}"
        if mount | grep -q " on $d "; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'work directory $d is mounted'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage tpm: $d is not a mount point (sudo mount -t tmpfs -o size=64m tmpfs $d && sudo chown \$(id -un) $d)'"
        fi
}

#@help _stage_tpm_key_make1
# @command stage tpm key make <stage>
# @summary Act terminal (root): tpm2_createprimary (owner hierarchy, RSA, sha256), the old entry under the handle evicted, the new one persisted, readpublic of the name; prints the name's 32-byte digest as hex
# @group   provisioning
# @internal
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the contexts live on (default /tmp/ram)
# @see     stage tpm key
#@end
_stage_tpm_key_make1() {
        local d="${ELEBAKE_TPM_WORKDIR:-/tmp/ram}" h=""
        h=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.tpm.key.handle" 2>/dev/null)
        emit_note "stage tpm key '$1': storage key -> $h"
        cat <<EOF
export TPM2TOOLS_TCTI=device:/dev/tpm0
cd '$d' || exit 1
tpm2_flushcontext --transient-object
tpm2_createprimary --hierarchy=o --hash-algorithm=sha256 --key-algorithm=rsa --key-context=primary.ctx --hierarchy-auth="hex:\$(cat '$d/auth-hierarchy.hex')" || exit 1
tpm2_getcap handles-persistent | grep -qi '$h' && tpm2_evictcontrol --hierarchy=o --object-context='$h' --auth="hex:\$(cat '$d/auth-hierarchy.hex')"
tpm2_evictcontrol --hierarchy=o --object-context=primary.ctx '$h' --auth="hex:\$(cat '$d/auth-hierarchy.hex')" || exit 1
tpm2_readpublic --object-context='$h' --name=srk.name > /dev/null || exit 1
printf '# storage key %s name sha256: ' '$h'; tail -c 32 srk.name | hexdump -ve '1/1 "%02x"'; echo
rm -P primary.ctx srk.name
EOF
}

#@help ___stage_tpm_policy1
# @command stage tpm policy <stage>
# @summary Write the two policies the sealed objects are created under, on the RAM disk: owner.policy (PolicyPCR over loader.trust.tpm.keyfile.pcrs, PolicyAuthValue, PolicyNV duress.count.nv == duress.count.sealed, authorized by the index itself), duress.policy (PolicySecret against duress.nv, PolicyPCR). First the checks (stage tpm policy check), then the operands, then one trial session per role; the trial PolicySecret counts the PIN index, so pinCount is written back to 0 at the end
# @group   provisioning
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the contexts live on (default /tmp/ram)
# @example elebake stage tpm policy daily-v1
# @see     stage tpm duress
# @see     stage tpm seal
#@end
___stage_tpm_policy1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm policy check '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm policy operands '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm policy make role owner '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm policy make role duress '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm hierarchy present"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm duress reset write '$1'"
}

#@help ___stage_tpm_policy_check1
# @command stage tpm policy check <stage>
# @summary The prerequisites of the policies: the four leafs are set (keyfile.pcrs, duress.nv, duress.count.nv, duress.count.sealed), the sealed value has its form, the work directory is a mounted RAM disk, the duress passphrase was read (stage tpm duress left auth-duress.hex)
# @group   provisioning
# @internal
# @see     stage tpm policy
#@end
___stage_tpm_policy_check1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm leaf set '$1' loader.trust.tpm.keyfile.pcrs"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm leaf set '$1' loader.trust.tpm.duress.nv"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm leaf set '$1' loader.trust.tpm.duress.count.nv"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm leaf set '$1' loader.trust.tpm.duress.count.sealed"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm count sealed valid '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm workdir ready"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm auth present duress"
}

#@help __stage_tpm_count_sealed_valid1
# @command stage tpm count sealed valid <stage>
# @summary loader.trust.tpm.duress.count.sealed of the stage is 16 hex characters (the 8 bytes of the counter as tpm2_nvread prints them): a comment line, else an error line naming stage tpm duress count record
# @group   provisioning
# @internal
# @see     stage tpm policy check
#@end
__stage_tpm_count_sealed_valid1() {
        if sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.tpm.duress.count.sealed" 2>/dev/null | grep -qx '[0-9a-f]\{16\}'; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'duress.count.sealed of $1 has its form'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage tpm: loader.trust.tpm.duress.count.sealed of $1 is not 16 hex characters (stage tpm duress count $1, then stage tpm duress count record $1)'"
        fi
}

#@help _stage_tpm_policy_operands1
# @command stage tpm policy operands <stage>
# @summary Act terminal: the PolicyNV operand as a file on the work directory -- sealed8.bin (the 8 bytes of loader.trust.tpm.duress.count.sealed, rendered here as octal escapes: nothing is converted at run time)
# @group   provisioning
# @internal
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the contexts live on (default /tmp/ram)
# @see     stage tpm policy
#@end
_stage_tpm_policy_operands1() {
        local d="${ELEBAKE_TPM_WORKDIR:-/tmp/ram}" sealed="" oct="" pair=""
        sealed=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.tpm.duress.count.sealed" 2>/dev/null)
        for pair in $(printf '%s' "$sealed" | sed 's/../& /g'); do
                oct="$oct\\$(printf '%03o' "0x$pair")"
        done
        emit_note "stage tpm policy '$1': operand sealed8.bin ($sealed) on $d"
        cat <<EOF
cd '$d' || exit 1
printf '$oct' > sealed8.bin
EOF
}

#@help _stage_tpm_policy_make_role_owner1
# @command stage tpm policy make role owner <stage>
# @summary Act terminal (root): a trial session -- tpm2_policypcr over the stage's PCR list, tpm2_policyauthvalue, tpm2_policynv == sealed8.bin over duress.count.nv (the index itself authorizes the read) -- the digest written to <workdir>/owner.policy, the session flushed
# @group   provisioning
# @internal
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the contexts live on (default /tmp/ram)
# @see     stage tpm policy
#@end
_stage_tpm_policy_make_role_owner1() {
        local d="${ELEBAKE_TPM_WORKDIR:-/tmp/ram}" pcrs="" pin="" cnt=""
        pcrs=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.tpm.keyfile.pcrs" 2>/dev/null)
        pin=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.tpm.duress.nv" 2>/dev/null)
        cnt=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.tpm.duress.count.nv" 2>/dev/null)
        emit_note "stage tpm policy '$1' owner: PolicyPCR sha256:$pcrs + PolicyAuthValue + PolicyNV($cnt == sealed8.bin) -> $d/owner.policy"
        cat <<EOF
export TPM2TOOLS_TCTI=device:/dev/tpm0
cd '$d' || exit 1
tpm2_flushcontext --loaded-session
tpm2_startauthsession --session=session.ctx || exit 1
tpm2_policypcr --session=session.ctx --pcr-list='sha256:$pcrs' || exit 1
tpm2_policyauthvalue --session=session.ctx || exit 1
tpm2_policynv --session=session.ctx --hierarchy='$cnt' --input=sealed8.bin --offset=0 --policy=owner.policy '$cnt' eq || exit 1
tpm2_flushcontext session.ctx
rm -P session.ctx
EOF
}

#@help _stage_tpm_policy_make_role_duress1
# @command stage tpm policy make role duress <stage>
# @summary Act terminal (root): a trial session -- tpm2_policysecret against duress.nv with the auth in <workdir>/auth-duress.hex (this counts pinCount: stage tpm policy writes it back), tpm2_policypcr over the stage's list -- the digest written to <workdir>/duress.policy, the session flushed
# @group   provisioning
# @internal
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the contexts live on (default /tmp/ram)
# @see     stage tpm policy
#@end
_stage_tpm_policy_make_role_duress1() {
        local d="${ELEBAKE_TPM_WORKDIR:-/tmp/ram}" pcrs="" pin=""
        pcrs=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.tpm.keyfile.pcrs" 2>/dev/null)
        pin=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.tpm.duress.nv" 2>/dev/null)
        emit_note "stage tpm policy '$1' duress: PolicySecret($pin) + PolicyPCR sha256:$pcrs -> $d/duress.policy"
        cat <<EOF
export TPM2TOOLS_TCTI=device:/dev/tpm0
cd '$d' || exit 1
tpm2_flushcontext --loaded-session
tpm2_startauthsession --session=session.ctx || exit 1
tpm2_policysecret --session=session.ctx --object-context='$pin' "hex:\$(cat auth-duress.hex)" >/dev/null || exit 1
tpm2_policypcr --session=session.ctx --pcr-list='sha256:$pcrs' --policy=duress.policy || exit 1
tpm2_flushcontext session.ctx
rm -P session.ctx
EOF
}

#@help __stage_tpm_auth_present1
# @command stage tpm auth present <owner|duress>
# @summary <workdir>/auth-<role>.hex and .bin are there (stage tpm seal read left them): a comment line, else an error line naming the act that reads the passphrase
# @group   provisioning
# @internal
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the contexts live on (default /tmp/ram)
# @see     stage tpm policy
#@end
__stage_tpm_auth_present1() {
        local d="${ELEBAKE_TPM_WORKDIR:-/tmp/ram}"
        if test -s "$d/auth-$1.hex" && test -s "$d/auth-$1.bin"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'auth of $1 present on $d'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage tpm: no $d/auth-$1.hex (stage tpm duress <stage> reads the duress passphrase; stage tpm seal <stage> owner the owner one)'"
        fi
}

#@help __stage_tpm_hierarchy_present0
# @command stage tpm hierarchy present
# @summary <workdir>/auth-hierarchy.hex is there (32 bytes from the owner's seed as 64 hex characters, workflow tpm-seal puts it on the RAM disk): a comment line, else an error line -- every act that defines, evicts or writes as the owner passes it
# @group   provisioning
# @internal
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the contexts live on (default /tmp/ram)
# @see     stage tpm hierarchy
#@end
__stage_tpm_hierarchy_present0() {
        local d="${ELEBAKE_TPM_WORKDIR:-/tmp/ram}"
        if test -s "$d/auth-hierarchy.hex"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'hierarchy password present on $d'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage tpm: no $d/auth-hierarchy.hex (the owner and lockout password of the TPM, 32 bytes from the seed as 64 hex characters; workflow tpm-seal writes it)'"
        fi
}

#@help ___stage_tpm_hierarchy0
# @command stage tpm hierarchy
# @summary Set the owner and the lockout password of the TPM to the 32 bytes <workdir>/auth-hierarchy.hex spells, once, from empty: the work directory is a mounted RAM disk, the file is there; then 'stage tpm hierarchy set'. Every later act that defines, evicts or writes as the owner passes the file; the boot path needs none of it (the loader and earlboot authorize through the indices themselves). Lost: the firmware's TPM clear, then everything anew
# @group   provisioning
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the contexts live on (default /tmp/ram)
# @example elebake stage tpm hierarchy
# @see     stage tpm key
# @see     stage tpm status
#@end
___stage_tpm_hierarchy0() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm workdir ready"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm hierarchy present"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm hierarchy set"
}

#@help _stage_tpm_hierarchy_set0
# @command stage tpm hierarchy set
# @summary Act terminal (root): tpm2_changeauth of the owner hierarchy and of the lockout hierarchy from the empty password to the file's bytes (a hierarchy that has one already refuses: change it by hand, the old file as --object-auth), tpm2_getcap as the receipt
# @group   provisioning
# @internal
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the contexts live on (default /tmp/ram)
# @see     stage tpm hierarchy
#@end
_stage_tpm_hierarchy_set0() {
        local d="${ELEBAKE_TPM_WORKDIR:-/tmp/ram}"
        emit_note "stage tpm hierarchy: owner and lockout password from $d/auth-hierarchy.hex"
        cat <<EOF
export TPM2TOOLS_TCTI=device:/dev/tpm0
cd '$d' || exit 1
tpm2_changeauth --object-context=o "hex:\$(cat '$d/auth-hierarchy.hex')" || exit 1
tpm2_changeauth --object-context=l "hex:\$(cat '$d/auth-hierarchy.hex')" || exit 1
tpm2_getcap properties-variable | grep -iE 'ownerAuthSet|lockoutAuthSet'
EOF
}

#@help ___stage_tpm_seal3
# @command stage tpm seal <stage> <owner|duress> <secret-file>
# @summary Seal the secret into the persistent object of the role: owner -- the first handle of loader.trust.tpm.keyfile.handles, under owner.policy, with the owner passphrase's sha256 as auth value (read hidden twice); duress -- the second handle, under duress.policy, no auth value (the PIN index proves the passphrase). The stage exists, the role's prerequisites hold (stage tpm seal check role), the passphrase is read where the role has one, the object is created, loaded, persisted. The owner's secret is the production root's key file; the duress one is the decoy root's key file
# @group   provisioning
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the contexts live on (default /tmp/ram)
# @example elebake stage tpm seal daily-v1 owner /tmp/ram/secret.bin
# @example elebake stage tpm seal daily-v1 duress /tmp/ram/zempty.bin
# @see     stage tpm policy
# @see     stage tpm probe
#@end
___stage_tpm_seal3() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm seal check role '$2' '$1' $(sq "$3")"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm seal read role '$2' '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm seal object role '$2' '$1' $(sq "$3")"
}

#@help ___stage_tpm_seal_check_role_owner2
# @command stage tpm seal check role owner <stage> <secret-file>
# @summary The prerequisites of the owner's seal: loader.trust.tpm.keyfile.handles is set, the secret file holds 32 bytes, owner.policy is on the work directory, the counter duress.count.nv still reads duress.count.sealed
# @group   provisioning
# @internal
# @see     stage tpm seal
#@end
___stage_tpm_seal_check_role_owner2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm leaf set '$1' loader.trust.tpm.keyfile.handles"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm secret readable $(sq "$2")"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm policy present owner"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm hierarchy present"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm count sealed '$1'"
}

#@help ___stage_tpm_seal_check_role_duress2
# @command stage tpm seal check role duress <stage> <secret-file>
# @summary The prerequisites of the duress seal: loader.trust.tpm.keyfile.handles is set, the secret file holds 32 bytes, duress.policy is on the work directory
# @group   provisioning
# @internal
# @see     stage tpm seal
#@end
___stage_tpm_seal_check_role_duress2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm leaf set '$1' loader.trust.tpm.keyfile.handles"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm secret readable $(sq "$2")"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm policy present duress"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm hierarchy present"
}

#@help __stage_tpm_seal_check_role3
# @command stage tpm seal check role <role> <stage> <secret-file>
# @completion role none
# @summary A role that is not owner or duress (those have their own check): an error line
# @group   provisioning
# @internal
# @see     stage tpm seal
#@end
__stage_tpm_seal_check_role3() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage tpm: role must be owner or duress: $1'"
}

#@help _stage_tpm_count_sealed1
# @command stage tpm count sealed <stage>
# @summary Act terminal (root): tpm2_nvread of loader.trust.tpm.duress.count.nv as the owner, compared with loader.trust.tpm.duress.count.sealed; a different value fails with the way back (the object would be dead at birth: stage tpm duress count record, stage tpm policy, then seal again)
# @group   provisioning
# @internal
# @see     stage tpm seal check role owner
#@end
_stage_tpm_count_sealed1() {
        local cnt="" sealed=""
        cnt=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.tpm.duress.count.nv" 2>/dev/null)
        sealed=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.tpm.duress.count.sealed" 2>/dev/null)
        emit_note "stage tpm seal '$1' owner: counter $cnt must read $sealed"
        cat <<EOF
export TPM2TOOLS_TCTI=device:/dev/tpm0
now=\$(tpm2_nvread --hierarchy='$cnt' --size=8 '$cnt' 2>/dev/null | hexdump -ve '1/1 "%02x"')
[ "\$now" = '$sealed' ] || { printf '# Error: %s reads %s, the stage sealed against %s (stage tpm duress count record, stage tpm policy, then seal again)\\n' '$cnt' "\$now" '$sealed' >&2; exit 1; }
EOF
}

#@help __stage_tpm_seal_read_role_owner1
# @command stage tpm seal read role owner <stage>
# @summary The owner's object has an auth value: rewrite to 'stage tpm seal read <stage> owner' (the hidden read, twice)
# @group   provisioning
# @internal
# @see     stage tpm seal
#@end
__stage_tpm_seal_read_role_owner1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm seal read '$1' owner"
}

#@help _stage_tpm_seal_read_role_duress1
# @command stage tpm seal read role duress <stage>
# @summary Act terminal: nothing to read -- the duress object carries no auth value, the PIN index proves the passphrase (a note)
# @group   provisioning
# @internal
# @see     stage tpm seal
#@end
_stage_tpm_seal_read_role_duress1() {
        emit_note "stage tpm seal '$1' duress: no auth value to read, the PIN index proves the passphrase"
}

#@help __stage_tpm_seal_read_role2
# @command stage tpm seal read role <role> <stage>
# @completion role none
# @summary A role that is not owner or duress: an error line
# @group   provisioning
# @internal
# @see     stage tpm seal
#@end
__stage_tpm_seal_read_role2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage tpm: role must be owner or duress: $1'"
}

#@help _stage_tpm_seal_object_role_owner2
# @command stage tpm seal object role owner <stage> <secret-file>
# @summary Act terminal (root): tpm2_create under the parent loader.trust.tpm.key.handle with owner.policy and the auth value from <workdir>/auth-owner.bin (fixedtpm|fixedparent|adminwithpolicy|noda -- a typo must not lock the TPM), the old object under the first handle of keyfile.handles evicted, the new one loaded and persisted; the transient objects flushed after every step, the pub/priv/ctx files wiped
# @group   provisioning
# @internal
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the contexts live on (default /tmp/ram)
# @see     stage tpm seal
#@end
_stage_tpm_seal_object_role_owner2() {
        local d="${ELEBAKE_TPM_WORKDIR:-/tmp/ram}" parent="" h=""
        parent=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.tpm.key.handle" 2>/dev/null)
        h=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.tpm.keyfile.handles" 2>/dev/null | cut -d' ' -f1)
        emit_note "stage tpm seal '$1' owner: object $h under $parent, owner.policy, auth value from auth-owner.bin"
        cat <<EOF
export TPM2TOOLS_TCTI=device:/dev/tpm0
cd '$d' || exit 1
tpm2_flushcontext --transient-object
tpm2_create --parent-context='$parent' --policy=owner.policy --key-auth="hex:\$(cat auth-owner.hex)" --sealing-input=$(sq "$2") --public=owner.pub --private=owner.priv --attributes='fixedtpm|fixedparent|adminwithpolicy|noda' || exit 1
tpm2_getcap handles-persistent | grep -qi '$h' && tpm2_evictcontrol --hierarchy=o --object-context='$h' --auth="hex:\$(cat '$d/auth-hierarchy.hex')"
tpm2_flushcontext --transient-object
tpm2_load --parent-context='$parent' --public=owner.pub --private=owner.priv --key-context=owner.ctx || exit 1
tpm2_evictcontrol --hierarchy=o --object-context=owner.ctx '$h' --auth="hex:\$(cat '$d/auth-hierarchy.hex')" || exit 1
tpm2_flushcontext --transient-object
rm -P owner.pub owner.priv owner.ctx
printf '# object %s sealed for owner\\n' '$h'
EOF
}

#@help _stage_tpm_seal_object_role_duress2
# @command stage tpm seal object role duress <stage> <secret-file>
# @summary Act terminal (root): tpm2_create under the parent loader.trust.tpm.key.handle with duress.policy and no auth value (fixedtpm|fixedparent|adminwithpolicy|noda), the old object under the second handle of keyfile.handles evicted, the new one loaded and persisted; the transient objects flushed after every step, the pub/priv/ctx files wiped
# @group   provisioning
# @internal
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the contexts live on (default /tmp/ram)
# @see     stage tpm seal
#@end
_stage_tpm_seal_object_role_duress2() {
        local d="${ELEBAKE_TPM_WORKDIR:-/tmp/ram}" parent="" h=""
        parent=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.tpm.key.handle" 2>/dev/null)
        h=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.tpm.keyfile.handles" 2>/dev/null | cut -d' ' -f2)
        emit_note "stage tpm seal '$1' duress: object $h under $parent, duress.policy, no auth value"
        cat <<EOF
export TPM2TOOLS_TCTI=device:/dev/tpm0
cd '$d' || exit 1
tpm2_flushcontext --transient-object
tpm2_create --parent-context='$parent' --policy=duress.policy --sealing-input=$(sq "$2") --public=duress.pub --private=duress.priv --attributes='fixedtpm|fixedparent|adminwithpolicy|noda' || exit 1
tpm2_getcap handles-persistent | grep -qi '$h' && tpm2_evictcontrol --hierarchy=o --object-context='$h' --auth="hex:\$(cat '$d/auth-hierarchy.hex')"
tpm2_flushcontext --transient-object
tpm2_load --parent-context='$parent' --public=duress.pub --private=duress.priv --key-context=duress.ctx || exit 1
tpm2_evictcontrol --hierarchy=o --object-context=duress.ctx '$h' --auth="hex:\$(cat '$d/auth-hierarchy.hex')" || exit 1
tpm2_flushcontext --transient-object
rm -P duress.pub duress.priv duress.ctx
printf '# object %s sealed for duress\\n' '$h'
EOF
}

#@help __stage_tpm_seal_object_role3
# @command stage tpm seal object role <role> <stage> <secret-file>
# @completion role none
# @summary A role that is not owner or duress: an error line
# @group   provisioning
# @internal
# @see     stage tpm seal
#@end
__stage_tpm_seal_object_role3() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage tpm: role must be owner or duress: $1'"
}

#@help __stage_tpm_secret_readable1
# @command stage tpm secret readable <secret-file>
# @summary The secret file is readable and holds exactly 32 bytes (the reflected seed, hkdf-tree ... | base64 -d): a comment line, else an error line
# @group   provisioning
# @internal
# @see     stage tpm seal
#@end
__stage_tpm_secret_readable1() {
        if test -r "$1" && test "$(wc -c < "$1" | tr -d ' ')" = 32; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'secret file holds 32 bytes'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage tpm: secret file is not readable or not 32 bytes: $1'"
        fi
}

#@help __stage_tpm_policy_present1
# @command stage tpm policy present <owner|duress>
# @summary <workdir>/<role>.policy is there (stage tpm policy wrote it): a comment line, else an error line
# @group   provisioning
# @internal
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the contexts live on (default /tmp/ram)
# @see     stage tpm seal
#@end
__stage_tpm_policy_present1() {
        local d="${ELEBAKE_TPM_WORKDIR:-/tmp/ram}"
        if test -s "$d/$1.policy"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'policy $d/$1.policy present'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage tpm: no $d/$1.policy (stage tpm policy <stage> first)'"
        fi
}

#@help _stage_tpm_seal_read2
# @command stage tpm seal read <stage> <owner|duress>
# @summary Act terminal: the script that reads the role's passphrase twice on /dev/tty with echo off, refuses empty or differing entries, hashes it with sha256 and writes the hex to <workdir>/auth-<role>.hex (the probe's hex: form) and the raw bytes to auth-<role>.bin (tpm2_create's file: form) -- the passphrase never leaves the script
# @group   provisioning
# @internal
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the contexts live on (default /tmp/ram)
# @see     stage tpm seal
#@end
_stage_tpm_seal_read2() {
        local d="${ELEBAKE_TPM_WORKDIR:-/tmp/ram}"
        cat <<EOF
{ : < /dev/tty; } 2>/dev/null || { printf '# Error: %s\\n' 'stage tpm seal: needs a terminal to read the passphrase hidden' >&2; exit 1; }
printf 'passphrase of the %s object for %s (hidden): ' '$2' '$1' > /dev/tty; stty -echo < /dev/tty; IFS= read -r a < /dev/tty; stty echo < /dev/tty; printf '\\n' > /dev/tty
printf 'Again: ' > /dev/tty; stty -echo < /dev/tty; IFS= read -r b < /dev/tty; stty echo < /dev/tty; printf '\\n' > /dev/tty
[ -n "\$a" ] && [ "\$a" = "\$b" ] || { unset a b; printf '# Error: %s\\n' 'stage tpm seal: the two entries differ or are empty -- nothing done' >&2; exit 1; }
printf '%s' "\$a" | sha256 -q > '$d/auth-$2.hex' && chmod 0600 '$d/auth-$2.hex' && printf '%s' "\$a" | openssl dgst -sha256 -binary > '$d/auth-$2.bin' && chmod 0600 '$d/auth-$2.bin'; unset a b
EOF
}

#@help ___stage_tpm_counter1
# @command stage tpm counter <stage>
# @summary Define the increment-only counters: loader.trust.tpm.counter.nv (the loader raises it when the duress object opened) and, when the stage names it, loader.trust.halt.nv (earlboot raises it before a shutdown it was bound to; the loader's HaltQuiet claim reads it against the learned halt.expected): the stage exists, the counter leaf is set, the work directory ready; then 'stage tpm counter make' (policy = PolicyCommandCode NV_Increment, attributes nt=counter|policywrite|authread|no_da: anyone reads the number, nobody lowers it -- the trace of a duress boot, of a halt)
# @group   provisioning
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the contexts live on (default /tmp/ram)
# @example elebake stage tpm counter daily-v1
# @see     stage tpm seal
#@end
___stage_tpm_counter1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm leaf set '$1' loader.trust.tpm.counter.nv"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm workdir ready"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm hierarchy present"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm counter make '$1'"
}

#@help _stage_tpm_counter_make1
# @command stage tpm counter make <stage>
# @summary Act terminal (root): a trial session with tpm2_policycommandcode TPM2_CC_NV_Increment written to <workdir>/nvinc.policy, tpm2_nvdefine of the 8-byte counter under that policy, tpm2_nvreadpublic as the receipt
# @group   provisioning
# @internal
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the contexts live on (default /tmp/ram)
# @see     stage tpm counter
#@end
_stage_tpm_counter_make1() {
        local d="${ELEBAKE_TPM_WORKDIR:-/tmp/ram}" nv="" halt=""
        nv=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.tpm.counter.nv" 2>/dev/null)
        halt=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.halt.nv" 2>/dev/null)
        emit_note "stage tpm counter '$1': NV index $nv (duress)${halt:+, $halt (halt)}, increment-only; an index already defined is kept, one without a value is initialized (a counter reads TPM_RC_NV_UNINITIALIZED until its first increment)"
        cat <<EOF
export TPM2TOOLS_TCTI=device:/dev/tpm0
cd '$d' || exit 1
tpm2_flushcontext --loaded-session
tpm2_startauthsession --session=nv.ctx || exit 1
tpm2_policycommandcode --session=nv.ctx --policy=nvinc.policy TPM2_CC_NV_Increment || exit 1
tpm2_flushcontext nv.ctx
for i in '$nv' ${halt:+'$halt'}; do
        tpm2_nvreadpublic "\$i" >/dev/null 2>&1 || tpm2_nvdefine "\$i" --hierarchy=o --size=8 --policy=nvinc.policy --attributes='nt=counter|policywrite|authread|no_da' --hierarchy-auth="hex:\$(cat '$d/auth-hierarchy.hex')" || exit 1
        tpm2_nvread "\$i" >/dev/null 2>&1 && { printf '# index %s defined and initialized\\n' "\$i"; continue; }
        tpm2_startauthsession --policy-session --session=inc.ctx || exit 1
        tpm2_policycommandcode --session=inc.ctx TPM2_CC_NV_Increment || exit 1
        tpm2_nvincrement "\$i" --auth=session:inc.ctx || exit 1
        tpm2_flushcontext inc.ctx
        rm -P inc.ctx
        tpm2_nvreadpublic "\$i"
done
rm -P nv.ctx nvinc.policy
EOF
}

#@help ___stage_tpm_duress1
# @command stage tpm duress <stage>
# @summary Define the duress index loader.trust.tpm.duress.nv, a TPM_NT_PIN_PASS index whose authValue is the duress passphrase's sha256 (the same form the objects take): the stage exists, the leaf is set, the work directory ready; the passphrase is read hidden twice (stage tpm seal read <stage> duress, auth-duress.hex/.bin on the RAM disk -- stage tpm policy needs it for the trial PolicySecret), then 'stage tpm duress make'. The index reads pinCount || pinLimit; every duress unseal (PolicySecret) counts pinCount up, and pinLimit 0xffffffff never spends it: the decoy opens again and again, the count is the owner's witness (stage tpm status). The seal's death is the second counter's business (duress.count.nv, raised by the loader on the first duress unseal). After a duress event: stage tpm duress reset (the count read, then back to 0), then stage tpm seal again
# @group   provisioning
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the contexts live on (default /tmp/ram)
# @example elebake stage tpm duress daily-v1
# @see     stage tpm duress count
# @see     stage tpm duress reset
# @see     stage tpm policy
#@end
___stage_tpm_duress1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm leaf set '$1' loader.trust.tpm.duress.nv"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm workdir ready"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm seal read '$1' duress"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm hierarchy present"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm duress make '$1'"
}

#@help _stage_tpm_duress_make1
# @command stage tpm duress make <stage>
# @summary Act terminal (root): the old index undefined if there (a new passphrase, a new authValue; the Name does not change, the sealed policies stay valid), tpm2_nvdefine of the 8-byte PIN_PASS index (nt=pinpass|ownerwrite|ownerread|authread|no_da) with the authValue from auth-duress.bin, tpm2_nvwrite pinCount 0 pinLimit 0xffffffff as the owner, tpm2_nvreadpublic as the receipt
# @group   provisioning
# @internal
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the contexts live on (default /tmp/ram)
# @see     stage tpm duress
#@end
_stage_tpm_duress_make1() {
        local d="${ELEBAKE_TPM_WORKDIR:-/tmp/ram}" pin=""
        pin=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.tpm.duress.nv" 2>/dev/null)
        emit_note "stage tpm duress '$1': PIN_PASS index $pin, pinLimit 0xffffffff, authValue = sha256 of the duress passphrase"
        cat <<EOF
export TPM2TOOLS_TCTI=device:/dev/tpm0
cd '$d' || exit 1
tpm2_nvreadpublic '$pin' >/dev/null 2>&1 && tpm2_nvundefine --hierarchy=o '$pin' --auth="hex:\$(cat '$d/auth-hierarchy.hex')"
tpm2_nvdefine '$pin' --hierarchy=o --size=8 --index-auth="hex:\$(cat auth-duress.hex)" --attributes='nt=pinpass|ownerwrite|ownerread|authread|no_da' --hierarchy-auth="hex:\$(cat '$d/auth-hierarchy.hex')" || exit 1
printf '\\000\\000\\000\\000\\377\\377\\377\\377' > pin01.bin
tpm2_nvwrite --hierarchy=o --input=pin01.bin '$pin' --auth="hex:\$(cat '$d/auth-hierarchy.hex')" || exit 1
rm -P pin01.bin
tpm2_nvreadpublic '$pin'
printf '# duress index %s: pinCount/pinLimit %s\\n' '$pin' "\$(tpm2_nvread --hierarchy=o --auth="hex:\$(cat '$d/auth-hierarchy.hex')" --size=8 '$pin' | hexdump -ve '1/1 "%02x"')"
EOF
}

#@help ___stage_tpm_duress_reset1
# @command stage tpm duress reset <stage>
# @summary After a duress event (the owner is back with the recovery slot): write pinCount 0 pinLimit 0xffffffff into loader.trust.tpm.duress.nv as the owner, after the count was read (stage tpm status: how often the decoy opened); the second counter is not touched (a counter never goes back: stage tpm seal reads its new value). The stage exists, the leaf is set; then 'stage tpm duress reset write'. Then, in this order: stage kenv drop <stage> loader.trust.tpm.duress.count.sealed (records are immutable, the old value would refuse the new one), stage tpm duress count (reads the counter's new value), stage tpm duress count record, stage tpm seal read <stage> duress (the trial PolicySecret needs the passphrase), stage tpm policy, stage tpm seal for both roles, the probes; then loaderconf mk, include, push (the leaf rides on the medium)
# @group   provisioning
# @example elebake stage tpm duress reset daily-v1
# @see     stage tpm duress
# @see     stage tpm seal
#@end
___stage_tpm_duress_reset1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm leaf set '$1' loader.trust.tpm.duress.nv"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm hierarchy present"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm duress reset write '$1'"
}

#@help _stage_tpm_duress_reset_write1
# @command stage tpm duress reset write <stage>
# @summary Act terminal (root): tpm2_nvwrite of pinCount 0 pinLimit 0xffffffff into the PIN index with owner auth, the value read back
# @group   provisioning
# @internal
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the contexts live on (default /tmp/ram)
# @see     stage tpm duress reset
#@end
_stage_tpm_duress_reset_write1() {
        local d="${ELEBAKE_TPM_WORKDIR:-/tmp/ram}" pin=""
        pin=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.tpm.duress.nv" 2>/dev/null)
        emit_note "stage tpm duress reset '$1': pinCount 0, pinLimit 0xffffffff in $pin"
        cat <<EOF
export TPM2TOOLS_TCTI=device:/dev/tpm0
t=\$(mktemp) || exit 1
printf '\\000\\000\\000\\000\\377\\377\\377\\377' > "\$t"
tpm2_nvwrite --hierarchy=o --input="\$t" '$pin' --auth="hex:\$(cat '$d/auth-hierarchy.hex')" || { rm -P "\$t"; exit 1; }
rm -P "\$t"
printf '# duress index %s: pinCount/pinLimit %s\\n' '$pin' "\$(tpm2_nvread --hierarchy=o --auth="hex:\$(cat '$d/auth-hierarchy.hex')" --size=8 '$pin' | hexdump -ve '1/1 "%02x"')"
EOF
}

#@help ___stage_tpm_duress_count1
# @command stage tpm duress count <stage>
# @summary Define the second counter loader.trust.tpm.duress.count.nv, the one earlboot raises for a boot answer of the coercion class (duress_count_act, PolicyCommandCode NV_Increment, authread so the loader's PolicyNV reads it through the index itself), incremented once after the define (a fresh counter reads TPM_RC_NV_UNINITIALIZED, and its first value is the TPM-wide maximum + 1, never 0); its value written to <workdir>/count-sealed.hex for 'stage tpm duress count record'. The stage exists, the leaf is set, the work directory ready; then 'stage tpm duress count make'
# @group   provisioning
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the contexts live on (default /tmp/ram)
# @example elebake stage tpm duress count daily-v1
# @see     stage tpm duress count record
# @see     stage tpm counter
#@end
___stage_tpm_duress_count1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm leaf set '$1' loader.trust.tpm.duress.count.nv"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm workdir ready"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm hierarchy present"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm duress count make '$1'"
}

#@help _stage_tpm_duress_count_make1
# @command stage tpm duress count make <stage>
# @summary Act terminal (root): a trial session with tpm2_policycommandcode TPM2_CC_NV_Increment, tpm2_nvdefine of the 8-byte counter under it (nt=counter|ownerread|authread|policywrite|no_da) unless defined, one increment under the policy unless initialized, the value read as the owner and written as 16 hex characters to <workdir>/count-sealed.hex (world-readable: it is no secret, it is in the policy digest)
# @group   provisioning
# @internal
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the contexts live on (default /tmp/ram)
# @see     stage tpm duress count
#@end
_stage_tpm_duress_count_make1() {
        local d="${ELEBAKE_TPM_WORKDIR:-/tmp/ram}" cnt=""
        cnt=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.tpm.duress.count.nv" 2>/dev/null)
        emit_note "stage tpm duress count '$1': counter $cnt, increment-only, readable through the index; its value -> $d/count-sealed.hex"
        cat <<EOF
export TPM2TOOLS_TCTI=device:/dev/tpm0
cd '$d' || exit 1
tpm2_flushcontext --loaded-session
tpm2_startauthsession --session=nv.ctx || exit 1
tpm2_policycommandcode --session=nv.ctx --policy=nvinc.policy TPM2_CC_NV_Increment || exit 1
tpm2_flushcontext nv.ctx
tpm2_nvreadpublic '$cnt' >/dev/null 2>&1 || tpm2_nvdefine '$cnt' --hierarchy=o --size=8 --policy=nvinc.policy --attributes='nt=counter|ownerread|authread|policywrite|no_da' --hierarchy-auth="hex:\$(cat '$d/auth-hierarchy.hex')" || exit 1
if ! tpm2_nvread --hierarchy='$cnt' --size=8 '$cnt' >/dev/null 2>&1; then
        tpm2_startauthsession --policy-session --session=inc.ctx || exit 1
        tpm2_policycommandcode --session=inc.ctx TPM2_CC_NV_Increment || exit 1
        tpm2_nvincrement '$cnt' --auth=session:inc.ctx || exit 1
        tpm2_flushcontext inc.ctx
        rm -P inc.ctx
fi
tpm2_nvread --hierarchy='$cnt' --size=8 '$cnt' | hexdump -ve '1/1 "%02x"' > count-sealed.hex || exit 1
chmod 0644 count-sealed.hex
rm -P nv.ctx nvinc.policy
printf '# counter %s = %s (count-sealed.hex)\\n' '$cnt' "\$(cat count-sealed.hex)"
EOF
}

#@help ___stage_tpm_duress_count_record1
# @command stage tpm duress count record <stage>
# @summary Take the counter's value stage tpm duress count left in <workdir>/count-sealed.hex (16 hex characters) and record it as loader.trust.tpm.duress.count.sealed: the stage exists; then 'stage kenv add' with the value (stage tpm duress count sealed). The loader reads it from loader.trust.conf (stage loaderconf mk, include, sign, push after this); stage tpm policy and stage tpm seal owner take it from the record. Run again after every increment of the counter (a duress event of the fish path) -- after 'stage kenv drop <stage> loader.trust.tpm.duress.count.sealed': the record is immutable, a differing value is refused
# @group   provisioning
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the contexts live on (default /tmp/ram)
# @example elebake stage tpm duress count record daily-v1
# @see     stage tpm duress count
# @see     stage kenv add
#@end
___stage_tpm_duress_count_record1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm duress count sealed '$1'"
}

#@help __stage_tpm_duress_count_sealed1
# @command stage tpm duress count sealed <stage>
# @summary <workdir>/count-sealed.hex holds 16 hex characters: rewrite to 'stage kenv add <stage> loader.trust.tpm.duress.count.sealed <value>', else an error line naming stage tpm duress count
# @group   provisioning
# @internal
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the contexts live on (default /tmp/ram)
# @see     stage tpm duress count record
#@end
__stage_tpm_duress_count_sealed1() {
        local d="${ELEBAKE_TPM_WORKDIR:-/tmp/ram}" v=""
        v=$(sed -n 1p "$d/count-sealed.hex" 2>/dev/null | tr -d ' ')
        if printf '%s\n' "$v" | grep -qx '[0-9a-f]\{16\}'; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage kenv add '$1' loader.trust.tpm.duress.count.sealed '$v'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage tpm duress count record: no 16 hex characters in $d/count-sealed.hex (stage tpm duress count $1 first)'"
        fi
}

#@help ___stage_tpm_anchor1
# @command stage tpm anchor <stage>
# @summary Define the two time-anchor indices: loader.trust.tpm.anchor.nv, which the loader writes at record commit under PolicyPCR over the cap PCR in its BOOT state and then caps (one PCR extend: root at runtime cannot rewrite it), and loader.trust.tpm.shutdown.nv, which elvbootd writes at shutdown under PolicyPCR over the CAPPED state (so only the runtime after the loader's cap can write it; a shutdown without the hook leaves an old index and SmartStep falls): the stage exists, the three leafs are set, the work directory ready; then 'stage tpm anchor make'. Threat model assumed: wall time is the RTC, which anyone with the setup can set; the anchor makes a forged RTC agree with the TPM clock and the NVMe counters, which only grow. No secret is involved: the anchor carries an HMAC under the record material, the shutdown index a plain digest
# @group   provisioning
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the contexts live on (default /tmp/ram)
# @example elebake stage tpm anchor daily-v1
# @see     stage tpm counter
# @see     stage tpm status
#@end
___stage_tpm_anchor1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm leaf set '$1' loader.trust.tpm.anchor.nv"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm leaf set '$1' loader.trust.tpm.shutdown.nv"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm leaf set '$1' loader.trust.tpm.cap.pcr"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm workdir ready"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm hierarchy present"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm anchor make '$1'"
}

#@help _stage_tpm_anchor_make1
# @command stage tpm anchor make <stage>
# @summary Act terminal (root): the two PCR states as files (32 zero bytes = the boot state; sha256(zeros || sha256("elvboot cap")) = the capped state), two trial sessions with tpm2_policypcr against those files (anchor.policy, shutdown.policy), tpm2_nvdefine of two 64-byte indices under them (policywrite|authread|no_da), tpm2_nvreadpublic as the receipt; indices already defined are kept
# @group   provisioning
# @internal
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the contexts live on (default /tmp/ram)
# @see     stage tpm anchor
#@end
_stage_tpm_anchor_make1() {
        local d="${ELEBAKE_TPM_WORKDIR:-/tmp/ram}" anchor="" shut="" cap=""
        anchor=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.tpm.anchor.nv" 2>/dev/null)
        shut=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.tpm.shutdown.nv" 2>/dev/null)
        cap=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.tpm.cap.pcr" 2>/dev/null)
        emit_note "stage tpm anchor '$1': anchor $anchor (boot state of PCR $cap), shutdown $shut (capped state of PCR $cap); an index already defined is kept"
        cat <<EOF
export TPM2TOOLS_TCTI=device:/dev/tpm0
cd '$d' || exit 1
printf 'elvboot cap' | openssl dgst -sha256 -binary > cap.bin
dd if=/dev/zero bs=32 count=1 2>/dev/null > pcr-boot.bin
cat pcr-boot.bin cap.bin | openssl dgst -sha256 -binary > pcr-capped.bin
tpm2_flushcontext --loaded-session
tpm2_startauthsession --session=t.ctx || exit 1
tpm2_policypcr --session=t.ctx --pcr-list='sha256:$cap' --pcr=pcr-boot.bin --policy=anchor.policy || exit 1
tpm2_flushcontext t.ctx
tpm2_startauthsession --session=t.ctx || exit 1
tpm2_policypcr --session=t.ctx --pcr-list='sha256:$cap' --pcr=pcr-capped.bin --policy=shutdown.policy || exit 1
tpm2_flushcontext t.ctx
tpm2_nvreadpublic '$anchor' >/dev/null 2>&1 || tpm2_nvdefine '$anchor' --hierarchy=o --size=64 --policy=anchor.policy --attributes='policywrite|authread|no_da' --hierarchy-auth="hex:\$(cat '$d/auth-hierarchy.hex')" || exit 1
tpm2_nvreadpublic '$shut' >/dev/null 2>&1 || tpm2_nvdefine '$shut' --hierarchy=o --size=64 --policy=shutdown.policy --attributes='policywrite|authread|no_da' --hierarchy-auth="hex:\$(cat '$d/auth-hierarchy.hex')" || exit 1
tpm2_nvreadpublic '$anchor'
tpm2_nvreadpublic '$shut'
rm -P t.ctx cap.bin pcr-boot.bin pcr-capped.bin anchor.policy shutdown.policy
EOF
}

#@help ___stage_tpm_probe3
# @command stage tpm probe <stage> <owner|duress> <secret-file>
# @summary Unseal the role's object the way the loader does -- a session salted to loader.trust.tpm.key.handle, the role's policy replayed -- and compare with the secret file: the stage exists, then the role's probe (stage tpm probe role): its prerequisites (the same as the seal's), the unseal, and for duress the pinCount written back to 0 (the PolicySecret counted)
# @group   provisioning
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the contexts live on (default /tmp/ram)
# @example elebake stage tpm probe daily-v1 duress /tmp/ram/zempty.bin
# @see     stage tpm seal
# @see     stage tpm clean
#@end
___stage_tpm_probe3() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm probe role '$2' '$1' $(sq "$3")"
}

#@help ___stage_tpm_probe_role_owner2
# @command stage tpm probe role owner <stage> <secret-file>
# @summary The owner's probe: the seal's prerequisites, then the unseal under PolicyPCR, PolicyAuthValue (auth-owner.hex), PolicyNV counter == sealed (through the index)
# @group   provisioning
# @internal
# @see     stage tpm probe
#@end
___stage_tpm_probe_role_owner2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm seal check role owner '$1' $(sq "$2")"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm probe unseal role owner '$1' $(sq "$2")"
}

#@help ___stage_tpm_probe_role_duress2
# @command stage tpm probe role duress <stage> <secret-file>
# @summary The duress probe: the seal's prerequisites, the unseal under PolicySecret (auth-duress.hex) and PolicyPCR -- which counts the PIN index --, then pinCount written back to 0
# @group   provisioning
# @internal
# @see     stage tpm probe
#@end
___stage_tpm_probe_role_duress2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm seal check role duress '$1' $(sq "$2")"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm auth present duress"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm probe unseal role duress '$1' $(sq "$2")"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm hierarchy present"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm duress reset write '$1'"
}

#@help __stage_tpm_probe_role3
# @command stage tpm probe role <role> <stage> <secret-file>
# @completion role none
# @summary A role that is not owner or duress: an error line
# @group   provisioning
# @internal
# @see     stage tpm probe
#@end
__stage_tpm_probe_role3() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage tpm: role must be owner or duress: $1'"
}

#@help _stage_tpm_probe_unseal_role_owner2
# @command stage tpm probe unseal role owner <stage> <secret-file>
# @summary Act terminal (root): tpm2_startauthsession --policy-session --tpmkey-context=<key handle>, policypcr, policyauthvalue, policynv zero4.bin over duress.nv, policynv sealed8.bin over duress.count.nv, tpm2_unseal of the first handle with session+hex:<auth-owner.hex> piped into cmp against the secret file -- prints 'unseal-owner-ok' or fails
# @group   provisioning
# @internal
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the contexts live on (default /tmp/ram)
# @see     stage tpm probe
#@end
_stage_tpm_probe_unseal_role_owner2() {
        local d="${ELEBAKE_TPM_WORKDIR:-/tmp/ram}" key="" pcrs="" h="" pin="" cnt=""
        key=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.tpm.key.handle" 2>/dev/null)
        pcrs=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.tpm.keyfile.pcrs" 2>/dev/null)
        pin=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.tpm.duress.nv" 2>/dev/null)
        cnt=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.tpm.duress.count.nv" 2>/dev/null)
        h=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.tpm.keyfile.handles" 2>/dev/null | cut -d' ' -f1)
        emit_note "stage tpm probe '$1' owner: unseal $h under the owner policy (sha256:$pcrs, $cnt), salted to $key"
        cat <<EOF
export TPM2TOOLS_TCTI=device:/dev/tpm0
cd '$d' || exit 1
tpm2_flushcontext --transient-object
tpm2_startauthsession --policy-session --session=u.ctx --tpmkey-context='$key' 2>/dev/null || exit 1
tpm2_policypcr --session=u.ctx --pcr-list='sha256:$pcrs' || exit 1
tpm2_policyauthvalue --session=u.ctx || exit 1
tpm2_policynv --session=u.ctx --hierarchy='$cnt' --input=sealed8.bin --offset=0 '$cnt' eq || exit 1
tpm2_unseal --object-context='$h' --auth="session:u.ctx+hex:\$(cat auth-owner.hex)" | cmp - $(sq "$2") && printf 'unseal-owner-ok\\n'
tpm2_flushcontext u.ctx
rm -P u.ctx
EOF
}

#@help _stage_tpm_probe_unseal_role_duress2
# @command stage tpm probe unseal role duress <stage> <secret-file>
# @summary Act terminal (root): tpm2_startauthsession --policy-session --tpmkey-context=<key handle>, policysecret against duress.nv with hex:<auth-duress.hex>, policypcr, tpm2_unseal of the second handle with the session alone piped into cmp against the secret file -- prints 'unseal-duress-ok' or fails
# @group   provisioning
# @internal
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the contexts live on (default /tmp/ram)
# @see     stage tpm probe
#@end
_stage_tpm_probe_unseal_role_duress2() {
        local d="${ELEBAKE_TPM_WORKDIR:-/tmp/ram}" key="" pcrs="" h="" pin=""
        key=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.tpm.key.handle" 2>/dev/null)
        pcrs=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.tpm.keyfile.pcrs" 2>/dev/null)
        pin=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.tpm.duress.nv" 2>/dev/null)
        h=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.tpm.keyfile.handles" 2>/dev/null | cut -d' ' -f2)
        emit_note "stage tpm probe '$1' duress: unseal $h under PolicySecret($pin) + PolicyPCR sha256:$pcrs, salted to $key"
        cat <<EOF
export TPM2TOOLS_TCTI=device:/dev/tpm0
cd '$d' || exit 1
tpm2_flushcontext --transient-object
tpm2_startauthsession --policy-session --session=u.ctx --tpmkey-context='$key' 2>/dev/null || exit 1
tpm2_policysecret --session=u.ctx --object-context='$pin' "hex:\$(cat auth-duress.hex)" >/dev/null || exit 1
tpm2_policypcr --session=u.ctx --pcr-list='sha256:$pcrs' || exit 1
tpm2_unseal --object-context='$h' --auth=session:u.ctx | cmp - $(sq "$2") && printf 'unseal-duress-ok\\n'
tpm2_flushcontext u.ctx
rm -P u.ctx
EOF
}

#@help ___stage_tpm_clean0
# @command stage tpm clean
# @summary Wipe what the family left on the work directory: the auth hashes, contexts, policies, key files (rm -P, the RAM disk is unmounted by the owner); the work directory ready; then 'stage tpm wipe'
# @group   provisioning
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the contexts live on (default /tmp/ram)
# @example elebake stage tpm clean
# @see     stage tpm probe
#@end
___stage_tpm_clean0() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm workdir ready"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm wipe"
}

#@help _stage_tpm_wipe0
# @command stage tpm wipe
# @summary Act terminal: rm -P of auth-*.hex, auth-*.bin, *.ctx, *.pub, *.priv, *.policy, the anchor's PCR files, srk.* on the work directory (whichever are there); the secret file is the owner's to wipe
# @group   provisioning
# @internal
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the contexts live on (default /tmp/ram)
# @see     stage tpm clean
#@end
_stage_tpm_wipe0() {
        local d="${ELEBAKE_TPM_WORKDIR:-/tmp/ram}"
        emit_note "stage tpm clean: wiping the contexts on $d"
        printf '%s\n' "cd '$d' || exit 1; for f in auth-owner.hex auth-duress.hex auth-owner.bin auth-duress.bin auth-hierarchy.hex primary.ctx session.ctx nv.ctx inc.ctx u.ctx owner.ctx duress.ctx owner.pub owner.priv duress.pub duress.priv pcrauth.policy owner.policy duress.policy nvinc.policy anchor.policy shutdown.policy t.ctx cap.bin pcr-boot.bin pcr-capped.bin sealed8.bin pin01.bin count-sealed.hex srk.name srk.pem; do [ -e \"\$f\" ] && rm -P \"\$f\"; done; :"
}

#@help ___stage_tpm_status1
# @command stage tpm status <stage>
# @summary What the TPM holds against what the stage expects: the persistent handles, the counter's public area, the two anchor indices; the stage exists; then 'stage tpm status show' (no password needed; the PIN index's pinCount shows only while auth-hierarchy.hex is on the RAM disk)
# @group   provisioning
# @example elebake stage tpm status daily-v1
# @see     stage tpm key
#@end
___stage_tpm_status1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm status show '$1'"
}

#@help _stage_tpm_status_show1
# @command stage tpm status show <stage>
# @summary Act terminal (root): tpm2_getcap handles-persistent, tpm2_nvreadpublic of the counter, the anchor and the shutdown index when the stage names them; the stage's leafs printed beside them
# @group   provisioning
# @internal
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the contexts live on (default /tmp/ram)
# @see     stage tpm status
#@end
_stage_tpm_status_show1() {
        local d="${ELEBAKE_TPM_WORKDIR:-/tmp/ram}" nv="" halt="" anchor="" shut="" pin="" cnt="" sealed=""
        nv=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.tpm.counter.nv" 2>/dev/null)
        halt=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.halt.nv" 2>/dev/null)
        anchor=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.tpm.anchor.nv" 2>/dev/null)
        shut=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.tpm.shutdown.nv" 2>/dev/null)
        pin=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.tpm.duress.nv" 2>/dev/null)
        cnt=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.tpm.duress.count.nv" 2>/dev/null)
        sealed=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.tpm.duress.count.sealed" 2>/dev/null)
        emit_note "stage $1 expects: key $(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.tpm.key.handle" 2>/dev/null), objects $(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.tpm.keyfile.handles" 2>/dev/null), pcrs $(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.tpm.keyfile.pcrs" 2>/dev/null), counter ${nv:--}, halt ${halt:--}, duress index ${pin:--}, duress counter ${cnt:--} sealed ${sealed:--}"
        printf '%s\n' "export TPM2TOOLS_TCTI=device:/dev/tpm0"
        printf '%s\n' "tpm2_getcap handles-persistent"
        test -n "$pin" && printf '%s\n' "if [ -s '$d/auth-hierarchy.hex' ]; then tpm2_nvread --hierarchy=o --auth=\"hex:\$(cat '$d/auth-hierarchy.hex')\" --size=8 '$pin' 2>/dev/null | hexdump -ve '1/1 \"%02x\"' | sed 's/^/# duress index $pin pinCount||pinLimit /; s/\$/\\n/' | tr -d '\\n'; echo; else echo '# duress index $pin: pinCount reads only with the owner password ($d/auth-hierarchy.hex, workflow tpm-seal)'; fi; tpm2_nvreadpublic '$pin' >/dev/null 2>&1 || echo '# duress index $pin not defined'"
        test -n "$cnt" && printf '%s\n' "tpm2_nvread --hierarchy='$cnt' --size=8 '$cnt' 2>/dev/null | hexdump -ve '1/1 \"%02x\"' | sed 's/^/# duress counter $cnt /; s/\$/ (sealed ${sealed:--})\\n/' | tr -d '\\n'; echo; tpm2_nvreadpublic '$cnt' >/dev/null 2>&1 || echo '# duress counter $cnt not defined'"
        test -n "$nv" && printf '%s\n' "tpm2_nvreadpublic '$nv' 2>/dev/null || echo '# counter $nv not defined'"
        test -n "$halt" && printf '%s\n' "tpm2_nvread '$halt' 2>/dev/null | hexdump -ve '1/1 \"%02x\"' | sed 's/^/# halt count 0x/; s/\$/\\n/' | tr -d '\\n'; echo; tpm2_nvreadpublic '$halt' >/dev/null 2>&1 || echo '# halt counter $halt not defined'"
        test -n "$anchor" && printf '%s\n' "tpm2_nvreadpublic '$anchor' >/dev/null 2>&1 && echo '# anchor $anchor defined' || echo '# anchor $anchor not defined'"
        test -n "$shut" && printf '%s\n' "tpm2_nvreadpublic '$shut' >/dev/null 2>&1 && echo '# shutdown index $shut defined' || echo '# shutdown index $shut not defined'"
        return 0
}
