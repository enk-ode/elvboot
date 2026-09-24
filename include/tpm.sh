#!/bin/sh
#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Dr. Johannes Brügmann
#
# tpm.sh -- the TPM 2.0 of the machine, provisioned from the stage's leafs.
#
# The loader (fork platform-trust-gates-15.1, stand/efi/loader/local/tpm.c)
# unseals a GELI key file from a persistent object under a PCR policy and
# the passphrase's auth value; a second object with the same bytes carries
# the duress passphrase; an increment-only NV counter is the trace of a
# duress boot; every session is salted to a persistent storage key. What
# the loader expects is in the stage's kenv leafs (template/tbl/boot-leafs.tbl):
#
#   loader.trust.tpm.key.handle        the storage key (0x81000001)
#   loader.trust.tpm.keyfile.handles   "<owner> <duress>" (0x81010001 0x81010002)
#   loader.trust.tpm.keyfile.pcrs      the policy (0,2,7)
#   loader.trust.tpm.counter.nv        the counter index (0x01c10e20)
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
# This family renders the tpm2-tools commands that set the TPM up to
# match, in the order the playbook walks them: key, policy, seal (owner,
# duress), counter, probe, clean. Every act runs on the RAM disk
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
tpm2_createprimary --hierarchy=o --hash-algorithm=sha256 --key-algorithm=rsa --key-context=primary.ctx || exit 1
tpm2_getcap handles-persistent | grep -qi '$h' && tpm2_evictcontrol --hierarchy=o --object-context='$h'
tpm2_evictcontrol --hierarchy=o --object-context=primary.ctx '$h' || exit 1
tpm2_readpublic --object-context='$h' --name=srk.name > /dev/null || exit 1
printf '# storage key %s name sha256: ' '$h'; tail -c 32 srk.name | hexdump -ve '1/1 "%02x"'; echo
rm -P primary.ctx srk.name
EOF
}

#@help ___stage_tpm_policy1
# @command stage tpm policy <stage>
# @summary Write the policy the sealed objects are created under -- PolicyPCR over loader.trust.tpm.keyfile.pcrs AND PolicyAuthValue -- as <workdir>/pcrauth.policy: the stage exists, the leaf is set, the work directory ready; then 'stage tpm policy make'
# @group   provisioning
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the contexts live on (default /tmp/ram)
# @example elebake stage tpm policy daily-v1
# @see     stage tpm seal
#@end
___stage_tpm_policy1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm leaf set '$1' loader.trust.tpm.keyfile.pcrs"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm workdir ready"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm policy make '$1'"
}

#@help _stage_tpm_policy_make1
# @command stage tpm policy make <stage>
# @summary Act terminal (root): a trial session, tpm2_policypcr over the stage's PCR list, tpm2_policyauthvalue with the digest written to <workdir>/pcrauth.policy, the session flushed
# @group   provisioning
# @internal
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the contexts live on (default /tmp/ram)
# @see     stage tpm policy
#@end
_stage_tpm_policy_make1() {
        local d="${ELEBAKE_TPM_WORKDIR:-/tmp/ram}" pcrs=""
        pcrs=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.tpm.keyfile.pcrs" 2>/dev/null)
        emit_note "stage tpm policy '$1': PolicyPCR sha256:$pcrs + PolicyAuthValue -> $d/pcrauth.policy"
        cat <<EOF
export TPM2TOOLS_TCTI=device:/dev/tpm0
cd '$d' || exit 1
tpm2_flushcontext --loaded-session
tpm2_startauthsession --session=session.ctx || exit 1
tpm2_policypcr --session=session.ctx --pcr-list='sha256:$pcrs' || exit 1
tpm2_policyauthvalue --session=session.ctx --policy=pcrauth.policy || exit 1
tpm2_flushcontext session.ctx
rm -P session.ctx
EOF
}

#@help ___stage_tpm_seal3
# @command stage tpm seal <stage> <owner|duress> <secret-file>
# @summary Seal the secret into the persistent object of the role -- the first handle of loader.trust.tpm.keyfile.handles for owner, the second for duress -- with the passphrase's sha256 as auth value: the stage exists, the role is owner or duress, the leaf names a handle for it, the secret file holds 32 bytes, the policy file is there (stage tpm policy); then the passphrase is read hidden twice (stage tpm seal read) and the object created, loaded, persisted (stage tpm seal object). The owner's and the duress passphrase must differ; each opens the same key file, only the second counts (loader tpm_keyfile.c)
# @group   provisioning
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the contexts live on (default /tmp/ram)
# @example elebake stage tpm seal daily-v1 owner /tmp/ram/secret.bin
# @example elebake stage tpm seal daily-v1 duress /tmp/ram/secret.bin
# @see     stage tpm policy
# @see     stage tpm probe
#@end
___stage_tpm_seal3() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm role valid '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm role handle '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm secret readable $(sq "$3")"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm policy present"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm seal read '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm seal object '$1' '$2' $(sq "$3")"
}

#@help __stage_tpm_role_valid1
# @command stage tpm role valid <owner|duress>
# @summary The role is owner or duress: a comment line, else an error line
# @group   provisioning
# @internal
# @see     stage tpm seal
#@end
__stage_tpm_role_valid1() {
        case "$1" in
        owner|duress) printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'role $1'" ;;
        *) printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage tpm: role must be owner or duress: $1'" ;;
        esac
}

#@help __stage_tpm_role_handle2
# @command stage tpm role handle <stage> <owner|duress>
# @summary loader.trust.tpm.keyfile.handles of the stage names a handle for the role (first word owner, second duress): a comment line with it, else an error line
# @group   provisioning
# @internal
# @see     stage tpm seal
#@end
__stage_tpm_role_handle2() {
        local h=""
        case "$2" in
        owner)  h=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.tpm.keyfile.handles" 2>/dev/null | cut -d' ' -f1) ;;
        duress) h=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.tpm.keyfile.handles" 2>/dev/null | cut -d' ' -f2) ;;
        esac
        case "$h" in
        0x*) printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'role $2 of $1: object $h'" ;;
        *) printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage tpm: loader.trust.tpm.keyfile.handles of $1 names no handle for $2 (stage kenv add $1 loader.trust.tpm.keyfile.handles <owner> <duress>, e.g. 0x81010001 0x81010002)'" ;;
        esac
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

#@help __stage_tpm_policy_present0
# @command stage tpm policy present
# @summary <workdir>/pcrauth.policy is there (stage tpm policy wrote it): a comment line, else an error line
# @group   provisioning
# @internal
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the contexts live on (default /tmp/ram)
# @see     stage tpm seal
#@end
__stage_tpm_policy_present0() {
        local d="${ELEBAKE_TPM_WORKDIR:-/tmp/ram}"
        if test -s "$d/pcrauth.policy"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'policy $d/pcrauth.policy present'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage tpm: no $d/pcrauth.policy (stage tpm policy <stage> first)'"
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

#@help _stage_tpm_seal_object3
# @command stage tpm seal object <stage> <owner|duress> <secret-file>
# @summary Act terminal (root): tpm2_create under the parent loader.trust.tpm.key.handle with the policy and the auth value from <workdir>/auth-<role>.hex (fixedtpm|fixedparent|adminwithpolicy|noda -- a typo must not lock the TPM), the old object under the role's handle evicted, the new one loaded and persisted; the transient objects flushed after every step (no resource manager in the loader's world), the pub/priv/ctx files wiped
# @group   provisioning
# @internal
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the contexts live on (default /tmp/ram)
# @see     stage tpm seal
#@end
_stage_tpm_seal_object3() {
        local d="${ELEBAKE_TPM_WORKDIR:-/tmp/ram}" parent="" h=""
        parent=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.tpm.key.handle" 2>/dev/null)
        case "$2" in
        owner)  h=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.tpm.keyfile.handles" 2>/dev/null | cut -d' ' -f1) ;;
        duress) h=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.tpm.keyfile.handles" 2>/dev/null | cut -d' ' -f2) ;;
        esac
        emit_note "stage tpm seal '$1' $2: object $h under $parent"
        cat <<EOF
export TPM2TOOLS_TCTI=device:/dev/tpm0
cd '$d' || exit 1
tpm2_flushcontext --transient-object
tpm2_create --parent-context='$parent' --policy=pcrauth.policy --key-auth='file:auth-$2.bin' --sealing-input=$(sq "$3") --public='$2.pub' --private='$2.priv' --attributes='fixedtpm|fixedparent|adminwithpolicy|noda' || exit 1
tpm2_getcap handles-persistent | grep -qi '$h' && tpm2_evictcontrol --hierarchy=o --object-context='$h'
tpm2_flushcontext --transient-object
tpm2_load --parent-context='$parent' --public='$2.pub' --private='$2.priv' --key-context='$2.ctx' || exit 1
tpm2_evictcontrol --hierarchy=o --object-context='$2.ctx' '$h' || exit 1
tpm2_flushcontext --transient-object
rm -P '$2.pub' '$2.priv' '$2.ctx'
printf '# object %s sealed for %s\\n' '$h' '$2'
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
        tpm2_nvreadpublic "\$i" >/dev/null 2>&1 || tpm2_nvdefine "\$i" --hierarchy=o --size=8 --policy=nvinc.policy --attributes='nt=counter|policywrite|authread|no_da' || exit 1
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
tpm2_nvreadpublic '$anchor' >/dev/null 2>&1 || tpm2_nvdefine '$anchor' --hierarchy=o --size=64 --policy=anchor.policy --attributes='policywrite|authread|no_da' || exit 1
tpm2_nvreadpublic '$shut' >/dev/null 2>&1 || tpm2_nvdefine '$shut' --hierarchy=o --size=64 --policy=shutdown.policy --attributes='policywrite|authread|no_da' || exit 1
tpm2_nvreadpublic '$anchor'
tpm2_nvreadpublic '$shut'
rm -P t.ctx cap.bin pcr-boot.bin pcr-capped.bin anchor.policy shutdown.policy
EOF
}

#@help ___stage_tpm_probe3
# @command stage tpm probe <stage> <owner|duress> <secret-file>
# @summary Unseal the role's object the way the loader does -- a session salted to loader.trust.tpm.key.handle, PolicyPCR over the stage's list, PolicyAuthValue with the hash stage tpm seal left in <workdir>/auth-<role>.hex -- and compare with the secret file: the stage exists, the role valid, the leaf names its handle, the secret readable; then 'stage tpm probe unseal'
# @group   provisioning
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the contexts live on (default /tmp/ram)
# @example elebake stage tpm probe daily-v1 duress /tmp/ram/secret.bin
# @see     stage tpm seal
# @see     stage tpm clean
#@end
___stage_tpm_probe3() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm role valid '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm role handle '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm secret readable $(sq "$3")"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tpm probe unseal '$1' '$2' $(sq "$3")"
}

#@help _stage_tpm_probe_unseal3
# @command stage tpm probe unseal <stage> <owner|duress> <secret-file>
# @summary Act terminal (root): tpm2_startauthsession --policy-session --tpmkey-context=<key handle>, policypcr, policyauthvalue, tpm2_unseal with session+hex:<auth> piped into cmp against the secret file -- prints 'unseal-<role>-ok' or fails
# @group   provisioning
# @internal
# @env     ELEBAKE_TPM_WORKDIR  the RAM disk the contexts live on (default /tmp/ram)
# @see     stage tpm probe
#@end
_stage_tpm_probe_unseal3() {
        local d="${ELEBAKE_TPM_WORKDIR:-/tmp/ram}" key="" pcrs="" h=""
        key=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.tpm.key.handle" 2>/dev/null)
        pcrs=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.tpm.keyfile.pcrs" 2>/dev/null)
        case "$2" in
        owner)  h=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.tpm.keyfile.handles" 2>/dev/null | cut -d' ' -f1) ;;
        duress) h=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.tpm.keyfile.handles" 2>/dev/null | cut -d' ' -f2) ;;
        esac
        emit_note "stage tpm probe '$1' $2: unseal $h under sha256:$pcrs, salted to $key"
        cat <<EOF
export TPM2TOOLS_TCTI=device:/dev/tpm0
cd '$d' || exit 1
tpm2_flushcontext --transient-object
tpm2_startauthsession --policy-session --session=u.ctx --tpmkey-context='$key' 2>/dev/null || exit 1
tpm2_policypcr --session=u.ctx --pcr-list='sha256:$pcrs' || exit 1
tpm2_policyauthvalue --session=u.ctx || exit 1
tpm2_unseal --object-context='$h' --auth="session:u.ctx+hex:\$(cat 'auth-$2.hex')" | cmp - $(sq "$3") && printf 'unseal-%s-ok\\n' '$2'
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
        printf '%s\n' "cd '$d' || exit 1; for f in auth-owner.hex auth-duress.hex auth-owner.bin auth-duress.bin primary.ctx session.ctx nv.ctx u.ctx owner.ctx duress.ctx owner.pub owner.priv duress.pub duress.priv pcrauth.policy nvinc.policy anchor.policy shutdown.policy t.ctx cap.bin pcr-boot.bin pcr-capped.bin srk.name srk.pem; do [ -e \"\$f\" ] && rm -P \"\$f\"; done; :"
}

#@help ___stage_tpm_status1
# @command stage tpm status <stage>
# @summary What the TPM holds against what the stage expects: the persistent handles, the counter's public area, the two anchor indices; the stage exists; then 'stage tpm status show'
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
# @see     stage tpm status
#@end
_stage_tpm_status_show1() {
        local nv="" halt="" anchor="" shut=""
        nv=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.tpm.counter.nv" 2>/dev/null)
        halt=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.halt.nv" 2>/dev/null)
        anchor=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.tpm.anchor.nv" 2>/dev/null)
        shut=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.tpm.shutdown.nv" 2>/dev/null)
        emit_note "stage $1 expects: key $(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.tpm.key.handle" 2>/dev/null), objects $(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.tpm.keyfile.handles" 2>/dev/null), pcrs $(sed -n 1p "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.tpm.keyfile.pcrs" 2>/dev/null), counter ${nv:--}, halt ${halt:--}"
        printf '%s\n' "export TPM2TOOLS_TCTI=device:/dev/tpm0"
        printf '%s\n' "tpm2_getcap handles-persistent"
        test -n "$nv" && printf '%s\n' "tpm2_nvreadpublic '$nv' 2>/dev/null || echo '# counter $nv not defined'"
        test -n "$halt" && printf '%s\n' "tpm2_nvread '$halt' 2>/dev/null | hexdump -ve '1/1 \"%02x\"' | sed 's/^/# halt count 0x/; s/\$/\\n/' | tr -d '\\n'; echo; tpm2_nvreadpublic '$halt' >/dev/null 2>&1 || echo '# halt counter $halt not defined'"
        test -n "$anchor" && printf '%s\n' "tpm2_nvreadpublic '$anchor' >/dev/null 2>&1 && echo '# anchor $anchor defined' || echo '# anchor $anchor not defined'"
        test -n "$shut" && printf '%s\n' "tpm2_nvreadpublic '$shut' >/dev/null 2>&1 && echo '# shutdown index $shut defined' || echo '# shutdown index $shut not defined'"
        return 0
}
