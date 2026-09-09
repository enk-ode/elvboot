#!/bin/sh
#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Dr. Johannes Brügmann
# elebake stage - the staging object (named workspaces for a boot tree).
#
# stage/<name> -> ../.staging/<id> ; the hidden record .staging/<id>/ holds the
# boot tree (boot/), metadata, and AT MOST TWO fixed key slots:
#   sign-key   -> ../../pkcs11/<name>    (Authenticode / loader, UEFI SecureBoot db)
#   attest-key -> ../../openpgp/<name>   (detached GPG / manifest, libsecureboot)
#
# Design principle: THE TOOL IS DUMB. The user hands us a name/token; we assume
# they know what they mean. We check only: is the argument present, and does the
# object exist at the expected filesystem location — if yes, we use it. No
# clever re-verification. State is DERIVED from the artifacts (see stage status).
#
# ARCHITECTURE (sharp): TERMINALS (single _) emit ONLY shell, never an elebake
# re-invocation. COMBINATORS (__) rewrite to ONE context line, BATCHES (___)
# emit ONLY context lines, never shell. Every check is a combinator line
# (a comment line, else an error line) in front of the act terminal; the
# batch machinery owns stop-at-first-failure.

# STAGE_LAYOUT — the directory layout of a stage (relpath:mode), fed to the
# generic install_layout by stage mint. Everything a stage contains, at a
# glance; grows as staging does.

STAGE_LAYOUT="boot:0700
destdir:0700
backup:0700"

#@help _stage_list0
# @command stage list
# @summary List all stages with their derived state (one line each): name, id, populated, signed (STALE = loader changed after signing), sign-key/attest-key
# @group   stage
# @example elebake stage list
# @see     stage add
# @see     stage status
#@end
_stage_list0() {
        local l="" name="" id="" d="" pop="" sig="" sk="" ak="" n=0
        printf '%s\n' "# stages (name  id  populated  signed  sign-key/attest-key)"
        for l in "$ELEBAKE_BASE"/stage/*; do
                test -L "$l" || continue
                n=$((n + 1))
                name=${l##*/}; id=$(basename "$(readlink "$l")"); d="$ELEBAKE_BASE/.staging/$id"
                pop=no; sig=no; sk=-; ak=-
                test -f "$d/boot/loader.efi" && pop=yes
                test -f "$d/boot/loader.efi.signed" && sig=STALE
                test -f "$d/boot/loader.efi.signed" && test "$d/boot/loader.efi.signed" -nt "$d/boot/loader.efi" && sig=yes
                test -L "$d/sign-key" && test -e "$d/sign-key" && sk=$(basename "$(readlink "$d/sign-key")")
                test -L "$d/attest-key" && test -e "$d/attest-key" && ak=$(basename "$(readlink "$d/attest-key")")
                printf '#   %-14s %-16s %-9s %-6s %s/%s\n' "$name" "$id" "$pop" "$sig" "$sk" "$ak"
        done
        test "${n:-0}" -gt 0 || printf '#   (no stages -- stage add <name>)\n'
}

#@help ___stage_add1
# @command stage add <stage>
# @summary Create a named stage (workspace for one boot tree): the name is a record name; then 'stage add new' -- IDEMPOTENT, an existing stage is left untouched (a replayed dump must never mint a fresh id and bend the name symlink)
# @group   stage
# @example elebake stage add daily-v1
# @see     stage list
# @see     stage checkout
#@end
___stage_add1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage name valid '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage add new '$1'"
}

#@help __stage_name_valid1
# @command stage name valid <stage>
# @summary The name is a record name ([A-Za-z0-9_.-], not . or ..): a comment line, else an error line
# @group   stage
# @internal
# @see     stage add
#@end
__stage_name_valid1() {
        if stage_name_ok "$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'stage name $1 valid'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage add: invalid stage name $1 ([A-Za-z0-9_.-])'"
        fi
}

#@help __stage_add_new1
# @command stage add new <stage>
# @summary No stage of that name yet: rewrite to 'stage mint <stage>', else a note line (idempotent add)
# @group   stage
# @internal
# @see     stage add
#@end
__stage_add_new1() {
        if test ! -L "$ELEBAKE_BASE/stage/$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage mint '$1'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" note 'stage $1 already exists (idempotent add)'"
        fi
}

#@help _stage_mint1
# @command stage mint <stage>
# @summary Act terminal: a fresh record id, the layout under .staging/<id>/, the metadata (name, created), the name symlink stage/<name>
# @group   stage
# @internal
# @see     stage add
#@end
_stage_mint1() {
        local id="" stamp=""
        id="stage-$(od -An -tx1 -N6 /dev/urandom | tr -d ' \n')"
        stamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
        install_layout "$ELEBAKE_BASE/.staging/$id" "$STAGE_LAYOUT"
        printf '%s\n' "echo 'name=$1' > '$ELEBAKE_BASE/.staging/$id/metadata'"
        printf '%s\n' "echo 'created=$stamp' >> '$ELEBAKE_BASE/.staging/$id/metadata'"
        printf '%s\n' "$MODIFY_FILE_PERMS 0600 '$ELEBAKE_BASE/.staging/$id/metadata'"
        printf '%s\n' "$MODIFY_LINK_FORCE '../.staging/$id' '$ELEBAKE_BASE/stage/$1'"
        printf '%s\n' "printf '# Created stage %s -> %s\\n' '$1' '$id' >&2"
}

#@help ___stage_edit2
# @command stage edit <stage> <relpath>
# @summary Edit a file of the stage's boot tree (the single source of truth; publish with stage push): the stage exists, the file is in boot/, the editor is pinned; then 'stage edit open'
# @group   stage
# @param   relpath  boot/-relative, e.g. loader.conf
# @env     ELEBAKE_EDITOR  the editor to open (profile pin; edit = FreeBSD ee)
# @example elebake stage edit daily-v1 loader.conf
# @see     stage push
# @see     stage adopt
#@end
___stage_edit2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage boot file exists '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage editor set"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage edit open '$1' '$2'"
}

#@help __stage_boot_file_exists2
# @command stage boot file exists <stage> <relpath>
# @summary The file is in the stage's boot/: a comment line, else an error line (stage adopt / stage include first)
# @group   stage
# @internal
# @see     stage edit
#@end
__stage_boot_file_exists2() {
        if test -f "$ELEBAKE_BASE/stage/$1/boot/$2"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'boot/$2 of stage $1 exists'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage $1: no such file in boot/: $2 (stage adopt / stage include first)'"
        fi
}

#@help __stage_editor_set0
# @command stage editor set
# @summary ELEBAKE_EDITOR is set: a comment line, else an error line (environment init <profile>)
# @group   stage
# @internal
# @env     ELEBAKE_EDITOR  the editor
# @see     stage edit
#@end
__stage_editor_set0() {
        if test -n "${ELEBAKE_EDITOR:-}"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'editor ${ELEBAKE_EDITOR:-} pinned'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage edit: ELEBAKE_EDITOR not set (environment init <profile>)'"
        fi
}

#@help _stage_edit_open2
# @command stage edit open <stage> <relpath>
# @summary Act terminal: the pinned editor on the file, stdin/stdout/stderr on /dev/tty (under a pipe the editor would inherit the script as stdin, and its screen must reach the terminal, not the log)
# @group   stage
# @internal
# @env     ELEBAKE_EDITOR  the editor
# @see     stage edit
#@end
_stage_edit_open2() {
        printf '%s\n' "$ELEBAKE_EDITOR '$ELEBAKE_BASE/stage/$1/boot/$2' </dev/tty >/dev/tty 2>&1"
        printf '%s\n' "printf '# edited %s -- publish with: stage push %s <medium>\\n' '$2' '$1' >&2"
}

#@help ___stage_sign_key3
# @command stage sign key <stage> <backend> <key>
# @summary Bind the loader-signing key slot (backend: pem | pkcs11): the stage exists, the key record is registered; then 'stage sign key bind'
# @group   stage
# @example elebake stage sign key daily-v1 pkcs11 nitrokey-9c
# @see     stage attest key
# @see     stage unkey
# @see     stage sign
#@end
___stage_sign_key3() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" key record exists '$2' '$3'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage sign key bind '$1' '$2' '$3'"
}

#@help ___stage_attest_key3
# @command stage attest key <stage> <backend> <key>
# @summary Bind the attest key slot (openpgp) -- required BEFORE build, its anchor is embedded: the stage exists, the key record is registered; then 'stage attest key bind'
# @group   stage
# @example elebake stage attest key daily-v1 openpgp attest-v1
# @see     stage sign key
# @see     stage trust
# @see     stage attest
#@end
___stage_attest_key3() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" key record exists '$2' '$3'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage attest key bind '$1' '$2' '$3'"
}

#@help __key_record_exists2
# @command key record exists <backend> <key>
# @summary The key is registered with its backend (pem, pkcs11, openpgp): a comment line, else an error line
# @group   stage
# @internal
# @see     stage sign key
# @see     stage attest key
#@end
__key_record_exists2() {
        if test -e "$ELEBAKE_BASE/$1/$2"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'key $1/$2 registered'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'unknown key $1/$2 (register it with: $1 add)'"
        fi
}

#@help _stage_sign_key_bind3
# @command stage sign key bind <stage> <backend> <key>
# @summary Act terminal: the relative link sign-key -> ../../<backend>/<key> and the bound line
# @group   stage
# @internal
# @see     stage sign key
#@end
_stage_sign_key_bind3() {
        printf '%s\n' "$MODIFY_LINK_FORCE '../../$2/$3' '$ELEBAKE_BASE/stage/$1/sign-key'"
        printf '%s\n' "printf '# Bound %s key %s to stage %s (sign-key)\\n' '$2' '$3' '$1' >&2"
}

#@help _stage_attest_key_bind3
# @command stage attest key bind <stage> <backend> <key>
# @summary Act terminal: the relative link attest-key -> ../../<backend>/<key> and the bound line
# @group   stage
# @internal
# @see     stage attest key
#@end
_stage_attest_key_bind3() {
        printf '%s\n' "$MODIFY_LINK_FORCE '../../$2/$3' '$ELEBAKE_BASE/stage/$1/attest-key'"
        printf '%s\n' "printf '# Bound %s key %s to stage %s (attest-key)\\n' '$2' '$3' '$1' >&2"
}

#@help ___stage_unkey1
# @command stage unkey <stage>
# @summary Clear both key slots: the stage exists; then 'stage unkey clear'
# @group   stage
# @example elebake stage unkey daily-v1
# @see     stage sign key
# @see     stage attest key
#@end
___stage_unkey1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage unkey clear '$1'"
}

#@help _stage_unkey_clear1
# @command stage unkey clear <stage>
# @summary Act terminal: remove sign-key and attest-key and say so
# @group   stage
# @internal
# @see     stage unkey
#@end
_stage_unkey_clear1() {
        printf '%s\n' "$MODIFY_FILE_REMOVE '$ELEBAKE_BASE/stage/$1/sign-key' '$ELEBAKE_BASE/stage/$1/attest-key'"
        printf '%s\n' "printf '# Cleared key slots of stage %s\\n' '$1' >&2"
}

#@help __stage_sign_key_bound1
# @command stage sign key bound <stage>
# @summary The sign-key slot is bound to an existing record: a comment line, else an error line
# @group   stage
# @internal
# @see     stage sign key
# @see     stage build
# @see     stage sign
#@end
__stage_sign_key_bound1() {
        if test -e "$ELEBAKE_BASE/stage/$1/sign-key"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'stage $1 sign-key bound'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage $1: no sign-key bound (stage sign key $1 <backend> <key>)'"
        fi
}

#@help __stage_attest_key_bound1
# @command stage attest key bound <stage>
# @summary The attest-key slot is bound to an existing record: a comment line, else an error line (its anchor is embedded in the loader at build)
# @group   stage
# @internal
# @see     stage attest key
# @see     stage build
# @see     stage attest
# @see     stage trust
#@end
__stage_attest_key_bound1() {
        if test -e "$ELEBAKE_BASE/stage/$1/attest-key"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'stage $1 attest-key bound'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage $1: no attest-key bound -- its anchor is embedded in the loader at build (stage attest key $1 openpgp <key>)'"
        fi
}

#@help __stage_attest_key_complete1
# @command stage attest key complete <stage>
# @summary The bound attest-key record carries its keyid: a comment line, else an error line
# @group   stage
# @internal
# @see     stage attest
# @see     stage trust anchor
#@end
__stage_attest_key_complete1() {
        if test -f "$ELEBAKE_BASE/stage/$1/attest-key/keyid"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'attest-key of stage $1 complete'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage $1: attest-key record incomplete (keyid missing)'"
        fi
}

#@help ___stage_build_ready1
# @command stage build ready <stage>
# @summary The build-readiness gate of 'stage build': the stage exists, both key slots are bound
# @group   stage
# @internal
# @see     stage build
#@end
___stage_build_ready1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage sign key bound '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage attest key bound '$1'"
}

#@help __stage_prerequisites_add3
# @command stage prerequisites add <stage> <exist|verify> <path|->
# @summary Add one absolute bootfs path to the stage's EXIST or VERIFY prerequisites (idempotent append); '-' reads paths from stdin, one per line, each validated before anything is emitted. '-': rewrite to 'stage prerequisites add stdin <stage> <kind>', else to 'stage prerequisites add entry <stage> <kind> <path>'
# @group   stage
# @param   exist|verify  exist: the loader claims presence; verify: verified read against the manifest (presence AND integrity)
# @example elebake stage prerequisites add daily-v1 verify /boot/loader.conf
# @example printf '/boot/device.hints\n' | elebake stage prerequisites add daily-v1 exist -
# @see     stage prerequisites drop
# @see     stage prerequisites show
# @see     stage require
#@end
__stage_prerequisites_add3() {
        if test "$3" = -; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage prerequisites add stdin '$1' '$2'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage prerequisites add entry '$1' '$2' $(sq "$3")"
        fi
}

#@help ___stage_prerequisites_add_stdin2
# @command stage prerequisites add stdin <stage> <exist|verify>
# @summary The paths from stdin (fd 3, bound by the top-level call), every one checked before the first is appended
# @group   stage
# @internal
# @see     stage prerequisites add
#@end
___stage_prerequisites_add_stdin2() {
        local line="" lines=""
        while IFS= read -r line <&3; do
                test -n "$line" || continue
                lines="$lines$line
"
        done
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage prerequisites kind valid '$2'"
        printf '%s' "$lines" | while IFS= read -r line; do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage prerequisites path valid $(sq "$line")"
        done
        printf '%s' "$lines" | while IFS= read -r line; do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage prerequisites append '$1' '$2' $(sq "$line")"
        done
        test -n "$lines" || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage prerequisites add: nothing on stdin'"
}

#@help ___stage_prerequisites_add_entry3
# @command stage prerequisites add entry <stage> <exist|verify> <path>
# @summary One prerequisite: the stage exists, the list kind and the path are valid; then 'stage prerequisites append'
# @group   stage
# @internal
# @see     stage prerequisites add
#@end
___stage_prerequisites_add_entry3() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage prerequisites kind valid '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage prerequisites path valid $(sq "$3")"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage prerequisites append '$1' '$2' $(sq "$3")"
}

#@help __stage_prerequisites_kind_valid1
# @command stage prerequisites kind valid <exist|verify>
# @summary The list kind is exist or verify: a comment line, else an error line
# @group   stage
# @internal
# @see     stage prerequisites add
#@end
__stage_prerequisites_kind_valid1() {
        if prereq_kind_ok "$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'prerequisites list $1'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage prerequisites: unknown list $1 (exist|verify)'"
        fi
}

#@help __stage_prerequisites_path_valid1
# @command stage prerequisites path valid <path>
# @summary The path is an absolute bootfs path (no .., no quotes): a comment line, else an error line
# @group   stage
# @internal
# @see     stage prerequisites add
#@end
__stage_prerequisites_path_valid1() {
        if prereq_path_ok "$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'prerequisite path $1 valid'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage prerequisites add: invalid path (absolute bootfs path, no .., no quotes): $1'"
        fi
}

#@help _stage_prerequisites_append3
# @command stage prerequisites append <stage> <exist|verify> <path>
# @summary Act terminal: append the path to prereqs/<kind> unless listed (0600) and say so
# @group   stage
# @internal
# @see     stage prerequisites add
#@end
_stage_prerequisites_append3() {
        printf '%s\n' "$MODIFY_DIR_CREATE '$ELEBAKE_BASE/stage/$1/prereqs'"
        printf '%s\n' "grep -qxF '$3' '$ELEBAKE_BASE/stage/$1/prereqs/$2' 2>/dev/null || echo '$3' >> '$ELEBAKE_BASE/stage/$1/prereqs/$2'"
        printf '%s\n' "$MODIFY_FILE_PERMS 0600 '$ELEBAKE_BASE/stage/$1/prereqs/$2'"
        printf '%s\n' "printf '# prerequisites %s of %s: + %s\\n' '$2' '$1' '$3' >&2"
}

#@help ___stage_prerequisites_drop3
# @command stage prerequisites drop <stage> <exist|verify> <path>
# @summary Remove one path from the stage's EXIST or VERIFY prerequisites: the stage exists, the kind is valid, the path is listed; then 'stage prerequisites remove'
# @group   stage
# @example elebake stage prerequisites drop daily-v1 exist /boot/device.hints
# @see     stage prerequisites add
#@end
___stage_prerequisites_drop3() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage prerequisites kind valid '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage prerequisites listed '$1' '$2' $(sq "$3")"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage prerequisites remove '$1' '$2' $(sq "$3")"
}

#@help __stage_prerequisites_listed3
# @command stage prerequisites listed <stage> <exist|verify> <path>
# @summary The path is in the list: a comment line, else an error line
# @group   stage
# @internal
# @see     stage prerequisites drop
#@end
__stage_prerequisites_listed3() {
        if grep -qxF "$3" "$ELEBAKE_BASE/stage/$1/prereqs/$2" 2>/dev/null; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'prerequisite $3 listed'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage prerequisites $2 drop: not listed: $3'"
        fi
}

#@help _stage_prerequisites_remove3
# @command stage prerequisites remove <stage> <exist|verify> <path>
# @summary Act terminal: rewrite the list without the path (.new then mv) and say so
# @group   stage
# @internal
# @see     stage prerequisites drop
#@end
_stage_prerequisites_remove3() {
        printf '%s\n' "grep -vxF '$3' '$ELEBAKE_BASE/stage/$1/prereqs/$2' > '$ELEBAKE_BASE/stage/$1/prereqs/$2.new'; mv '$ELEBAKE_BASE/stage/$1/prereqs/$2.new' '$ELEBAKE_BASE/stage/$1/prereqs/$2'"
        emit_note "prerequisites $2 of $1: - $3"
}

#@help ___stage_prerequisites_show2
# @command stage prerequisites show <stage> <exist|verify>
# @summary Show one of the stage's prerequisites lists: the stage exists, the kind is valid; then 'stage prerequisites table'
# @group   stage
# @example elebake stage prerequisites show daily-v1 verify
# @see     stage prerequisites add
#@end
___stage_prerequisites_show2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage prerequisites kind valid '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage prerequisites table '$1' '$2'"
}

#@help _stage_prerequisites_table2
# @command stage prerequisites table <stage> <exist|verify>
# @summary Text terminal: the list's entries, or the hint that it is empty
# @group   stage
# @internal
# @see     stage prerequisites show
#@end
_stage_prerequisites_table2() {
        printf '# prerequisites %s of %s\n' "$2" "$1"
        if test -s "$ELEBAKE_BASE/stage/$1/prereqs/$2"; then
                sed 's/^/#   /' "$ELEBAKE_BASE/stage/$1/prereqs/$2"
        else
                printf '#   (empty -- stage prerequisites add %s %s <path|->)\n' "$1" "$2"
        fi
}

#@help __stage_prerequisites_exist_add2
# @command stage prerequisites exist add <stage> <path|->
# @summary Add one absolute bootfs path to the stage's EXIST prerequisites; '-' reads paths from stdin -- rewrites to 'stage prerequisites add <stage> exist <path|->'
# @group   stage
# @see     stage prerequisites add
#@end
__stage_prerequisites_exist_add2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage prerequisites add '$1' exist $(sq "$2")"
}

#@help __stage_prereqs_exist_add2
# @internal alias combinator: stage prereqs exist add -> stage prerequisites exist add
#@end
__stage_prereqs_exist_add2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage prerequisites exist add '$1' $(sq "$2")"
}

#@help __stage_prerequisites_exist_drop2
# @command stage prerequisites exist drop <stage> <path>
# @summary Remove one path from the stage's EXIST prerequisites -- rewrites to 'stage prerequisites drop <stage> exist <path>'
# @group   stage
# @see     stage prerequisites drop
#@end
__stage_prerequisites_exist_drop2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage prerequisites drop '$1' exist $(sq "$2")"
}

#@help __stage_prereqs_exist_drop2
# @internal alias combinator: stage prereqs exist drop -> stage prerequisites exist drop
#@end
__stage_prereqs_exist_drop2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage prerequisites exist drop '$1' $(sq "$2")"
}

#@help __stage_prerequisites_exist_show1
# @command stage prerequisites exist show <stage>
# @summary Show the stage's EXIST prerequisites -- rewrites to 'stage prerequisites show <stage> exist'
# @group   stage
# @see     stage prerequisites show
#@end
__stage_prerequisites_exist_show1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage prerequisites show '$1' exist"
}

#@help __stage_prereqs_exist_show1
# @internal alias combinator: stage prereqs exist show -> stage prerequisites exist show
#@end
__stage_prereqs_exist_show1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage prerequisites exist show '$1'"
}

#@help __stage_prerequisites_verify_add2
# @command stage prerequisites verify add <stage> <path|->
# @summary Add one absolute bootfs path to the stage's VERIFY prerequisites; '-' reads paths from stdin -- rewrites to 'stage prerequisites add <stage> verify <path|->'
# @group   stage
# @see     stage prerequisites add
#@end
__stage_prerequisites_verify_add2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage prerequisites add '$1' verify $(sq "$2")"
}

#@help __stage_prereqs_verify_add2
# @internal alias combinator: stage prereqs verify add -> stage prerequisites verify add
#@end
__stage_prereqs_verify_add2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage prerequisites verify add '$1' $(sq "$2")"
}

#@help __stage_prerequisites_verify_drop2
# @command stage prerequisites verify drop <stage> <path>
# @summary Remove one path from the stage's VERIFY prerequisites -- rewrites to 'stage prerequisites drop <stage> verify <path>'
# @group   stage
# @see     stage prerequisites drop
#@end
__stage_prerequisites_verify_drop2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage prerequisites drop '$1' verify $(sq "$2")"
}

#@help __stage_prereqs_verify_drop2
# @internal alias combinator: stage prereqs verify drop -> stage prerequisites verify drop
#@end
__stage_prereqs_verify_drop2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage prerequisites verify drop '$1' $(sq "$2")"
}

#@help __stage_prerequisites_verify_show1
# @command stage prerequisites verify show <stage>
# @summary Show the stage's VERIFY prerequisites -- rewrites to 'stage prerequisites show <stage> verify'
# @group   stage
# @see     stage prerequisites show
#@end
__stage_prerequisites_verify_show1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage prerequisites show '$1' verify"
}

#@help __stage_prereqs_verify_show1
# @internal alias combinator: stage prereqs verify show -> stage prerequisites verify show
#@end
__stage_prereqs_verify_show1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage prerequisites verify show '$1'"
}

#@help ___stage_status1
# @command stage status <stage>
# @summary Show the stage's derived state (nothing cached -- read from the artifacts): the stage exists; then the title and one line per aspect, each its own terminal
# @group   stage
# @example elebake stage status daily-v1
# @see     stage list
#@end
___stage_status1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage status title '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage status populated '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage status signkey '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage status attestkey '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage status signed '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage status filter '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage status media '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage status marker '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage status sitemk '$1'"
}

#@help _stage_status_title1
# @command stage status title <stage>
# @summary Text terminal: the title line with the record id
# @group   stage
# @internal
# @see     stage status
#@end
_stage_status_title1() {
        printf '# stage %s (%s)\n' "$1" "$(basename "$(readlink "$ELEBAKE_BASE/stage/$1")")"
}

#@help _stage_status_populated1
# @command stage status populated <stage>
# @summary Derived state: is boot/loader.efi there? -- one line of 'stage status' (which checks the stage)
# @group   stage
# @internal
# @see     stage status
#@end
_stage_status_populated1() {
        if test -f "$ELEBAKE_BASE/stage/$1/boot/loader.efi"; then
                printf '#   populated : yes\n'
        else
                printf '#   populated : no (boot/loader.efi missing)\n'
        fi
}

#@help _stage_status_signkey1
# @command stage status signkey <stage>
# @summary Derived state: which sign-key is bound (STALE = link target gone) -- one line of 'stage status' (which checks the stage)
# @group   stage
# @internal
# @see     stage status
#@end
_stage_status_signkey1() {
        if test -L "$ELEBAKE_BASE/stage/$1/sign-key" && test -e "$ELEBAKE_BASE/stage/$1/sign-key"; then
                printf '#   sign-key  : %s\n' "$(basename "$(readlink "$ELEBAKE_BASE/stage/$1/sign-key")")"
        elif test -L "$ELEBAKE_BASE/stage/$1/sign-key"; then
                printf '#   sign-key  : STALE\n'
        else
                printf '#   sign-key  : none\n'
        fi
}

#@help _stage_status_attestkey1
# @command stage status attestkey <stage>
# @summary Derived state: which attest-key is bound (STALE = link target gone) -- one line of 'stage status' (which checks the stage)
# @group   stage
# @internal
# @see     stage status
#@end
_stage_status_attestkey1() {
        if test -L "$ELEBAKE_BASE/stage/$1/attest-key" && test -e "$ELEBAKE_BASE/stage/$1/attest-key"; then
                printf '#   attest-key: %s\n' "$(basename "$(readlink "$ELEBAKE_BASE/stage/$1/attest-key")")"
        elif test -L "$ELEBAKE_BASE/stage/$1/attest-key"; then
                printf '#   attest-key: STALE\n'
        else
                printf '#   attest-key: none\n'
        fi
}

#@help _stage_status_signed1
# @command stage status signed <stage>
# @summary Derived state: is the signed loader current (newer than boot/loader.efi)? -- one line of 'stage status' (which checks the stage)
# @group   stage
# @internal
# @see     stage status
#@end
_stage_status_signed1() {
        if test -f "$ELEBAKE_BASE/stage/$1/boot/loader.efi.signed" && test "$ELEBAKE_BASE/stage/$1/boot/loader.efi.signed" -nt "$ELEBAKE_BASE/stage/$1/boot/loader.efi"; then
                printf '#   signed    : yes (current)\n'
        elif test -f "$ELEBAKE_BASE/stage/$1/boot/loader.efi.signed"; then
                printf '#   signed    : STALE (loader changed after signing)\n'
        else
                printf '#   signed    : no\n'
        fi
}

#@help _stage_status_filter1
# @command stage status filter <stage>
# @summary Derived state: how many entries the curation filter holds -- one line of 'stage status' (which checks the stage)
# @group   stage
# @internal
# @see     stage status
#@end
_stage_status_filter1() {
        if test -s "$ELEBAKE_BASE/stage/$1/filter"; then
                printf '#   filter    : %s entries\n' "$(grep -c . "$ELEBAKE_BASE/stage/$1/filter")"
        else
                printf '#   filter    : none (stage filter add <stage> <rel>)\n'
        fi
}

#@help _stage_status_media1
# @command stage status media <stage>
# @summary Derived state: the registered media, each with node, mountpoint and backup count -- one line of 'stage status' (which checks the stage)
# @group   stage
# @internal
# @see     stage status
#@end
_stage_status_media1() {
        local m=""
        test -n "$(ls "$ELEBAKE_BASE/stage/$1/media" 2>/dev/null)" || printf '#   media     : none (stage device <stage> <medium> /dev/<node>)\n'
        for m in "$ELEBAKE_BASE/stage/$1/media"/*; do
                test -d "$m" || continue
                printf '#   medium %-3s: %s on %s (backups: %s)\n' "${m##*/}" "$(head -n1 "$m/node")" "$(head -n1 "$m/mountpoint")" "$(ls "$ELEBAKE_BASE/stage/$1/backup/${m##*/}" 2>/dev/null | wc -l | tr -d ' ')"
        done
}

#@help _stage_status_marker1
# @command stage status marker <stage>
# @summary Derived state: the recorded marker load option and value file -- one line of 'stage status' (which checks the stage)
# @group   stage
# @internal
# @see     stage status
#@end
_stage_status_marker1() {
        if test -f "$ELEBAKE_BASE/stage/$1/marker/bootvar"; then
                printf '#   marker    : %s (%s)\n' "$(head -n1 "$ELEBAKE_BASE/stage/$1/marker/bootvar")" "$(head -n1 "$ELEBAKE_BASE/stage/$1/marker/file")"
        else
                printf '#   marker    : none (stage marker <stage> BootXXXX <file>)\n'
        fi
}

#@help _stage_status_sitemk1
# @command stage status sitemk <stage>
# @summary Derived state: is site.mk present in the worktree? -- one line of 'stage status' (which checks the stage)
# @group   stage
# @internal
# @see     stage status
#@end
_stage_status_sitemk1() {
        if test -f "$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local/site.mk"; then
                printf '#   site.mk   : present (worktree)\n'
        else
                printf '#   site.mk   : none (stage site mk)\n'
        fi
}

#@help ___stage_sign1
# @command stage sign <stage>
# @summary Authenticode-sign boot/loader.efi with the bound sign-key: the stage exists, the slot is bound; then 'stage sign backend' lifts the record's backend into the command (pem: uefisign, pkcs11: osslsigncode)
# @group   stage
# @example elebake stage sign daily-v1
# @see     stage sign key
# @see     stage sign pem
# @see     stage sign pkcs11
#@end
___stage_sign1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage sign key bound '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage sign backend '$1'"
}

#@help __stage_sign_backend1
# @command stage sign backend <stage>
# @summary The bound sign-key's backend (the directory its link points into) is pem or pkcs11: rewrite to 'stage sign <backend> <stage>', else an error line
# @group   stage
# @internal
# @see     stage sign
#@end
__stage_sign_backend1() {
        local backend=""
        backend=$(basename "$(dirname "$(readlink "$ELEBAKE_BASE/stage/$1/sign-key" 2>/dev/null)")")
        if test "$backend" = pem || test "$backend" = pkcs11; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage sign '$backend' '$1'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage sign $1: sign-key record unrecognized (backend $backend; pem or pkcs11)'"
        fi
}

#@help __stage_populated1
# @command stage populated <stage>
# @summary boot/loader.efi is there: a comment line, else an error line (stage not populated)
# @group   stage
# @internal
# @see     stage sign
# @see     stage manifest
#@end
__stage_populated1() {
        if test -f "$ELEBAKE_BASE/stage/$1/boot/loader.efi"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'stage $1 populated'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage $1: boot/loader.efi not present (stage build / stage loader first)'"
        fi
}

#@help ___stage_sign_pem1
# @command stage sign pem <stage>
# @summary Authenticode-sign boot/loader.efi with the bound file-based key: the backend's tools, the stage exists and is populated, the record carries key and cert; then 'stage sign pem run' (uefisign)
# @group   stage
# @see     stage sign
#@end
___stage_sign_pem1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" pem prerequisites"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage populated '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage sign pem complete '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage sign pem run '$1'"
}

#@help __stage_sign_pem_complete1
# @command stage sign pem complete <stage>
# @summary The bound pem record carries key and cert: a comment line, else an error line
# @group   stage
# @internal
# @see     stage sign pem
#@end
__stage_sign_pem_complete1() {
        if test -f "$ELEBAKE_BASE/stage/$1/sign-key/key" && test -f "$ELEBAKE_BASE/stage/$1/sign-key/cert"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'pem sign-key of stage $1 complete'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage sign $1: pem sign-key record incomplete (key or cert missing)'"
        fi
}

#@help _stage_sign_pem_run1
# @command stage sign pem run <stage>
# @summary Act terminal: uefisign with the record's key and cert paths, boot/loader.efi -> boot/loader.efi.signed (a failed run leaves no half file)
# @group   stage
# @internal
# @see     stage sign pem
#@end
_stage_sign_pem_run1() {
        emit_note "elebake stage sign '$1' (Authenticode via file-based key, uefisign)"
        printf '%s\n' "uefisign -c '$(head -n1 "$ELEBAKE_BASE/stage/$1/sign-key/cert" 2>/dev/null)' -k '$(head -n1 "$ELEBAKE_BASE/stage/$1/sign-key/key" 2>/dev/null)' -o '$ELEBAKE_BASE/stage/$1/boot/loader.efi.signed' '$ELEBAKE_BASE/stage/$1/boot/loader.efi' || { rm -f '$ELEBAKE_BASE/stage/$1/boot/loader.efi.signed'; printf '# Error: uefisign failed (input already signed? key unreadable?)\\n' >&2; exit 1; }"
        printf '%s\n' "printf '# signed: loader.efi -> loader.efi.signed\\n' >&2"
}

#@help ___stage_sign_pkcs11_1
# @command stage sign pkcs11 <stage>
# @summary Authenticode-sign boot/loader.efi with the bound pkcs11 key: the backend's tools, the stage exists and is populated, the record carries uri and cert; then 'stage sign pkcs11 run' (osslsigncode through the engine or provider bridge, PIN prompted hidden on the tty and handed over via a transient file -- never argv, never env)
# @group   stage
# @env     ELEBAKE_PKCS11_MODULE  the PKCS#11 module osslsigncode loads
# @env     ELEBAKE_PKCS11_BRIDGE  engine (libp11) or provider
# @env     ELEBAKE_PKCS11_ENGINE  the engine .so (bridge=engine)
# @env     ELEBAKE_PKCS11_PROVIDER  the provider .so (bridge=provider; its directory becomes OPENSSL_MODULES)
# @see     stage sign
#@end
___stage_sign_pkcs11_1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" pkcs11 prerequisites"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage populated '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage sign pkcs11 complete '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage sign pkcs11 run '$1'"
}

#@help __stage_sign_pkcs11_complete1
# @command stage sign pkcs11 complete <stage>
# @summary The bound pkcs11 record carries uri and cert: a comment line, else an error line
# @group   stage
# @internal
# @see     stage sign pkcs11
#@end
__stage_sign_pkcs11_complete1() {
        if test -f "$ELEBAKE_BASE/stage/$1/sign-key/uri" && test -f "$ELEBAKE_BASE/stage/$1/sign-key/cert"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'pkcs11 sign-key of stage $1 complete'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage sign $1: pkcs11 sign-key record incomplete (uri or cert missing)'"
        fi
}

#@help _stage_sign_pkcs11_run1
# @command stage sign pkcs11 run <stage>
# @summary Act terminal: the PIN read hidden on /dev/tty into a transient -readpass file (0600, removed right after), osslsigncode sign through the engine (bridge=engine) or the provider (OPENSSL_MODULES pointed at the port's directory -- this HIDES the base legacy provider), the signed loader removed on failure
# @group   stage
# @internal
# @env     ELEBAKE_PKCS11_MODULE  the PKCS#11 module
# @env     ELEBAKE_PKCS11_BRIDGE  engine or provider
# @env     ELEBAKE_PKCS11_ENGINE  the engine .so
# @env     ELEBAKE_PKCS11_PROVIDER  the provider .so
# @see     stage sign pkcs11
#@end
_stage_sign_pkcs11_run1() {
        local uri="" cert=""
        uri=$(head -n1 "$ELEBAKE_BASE/stage/$1/sign-key/uri" 2>/dev/null); cert=$(head -n1 "$ELEBAKE_BASE/stage/$1/sign-key/cert" 2>/dev/null)
        emit_note "elebake stage sign '$1' (Authenticode via pkcs11 token, bridge ${ELEBAKE_PKCS11_BRIDGE:-})"
        printf '%s\n' "printf 'Token PIN (hidden): ' > /dev/tty"
        printf '%s\n' "stty -echo < /dev/tty; IFS= read -r pin < /dev/tty; stty echo < /dev/tty; printf '\\n' > /dev/tty"
        printf '%s\n' "pf=\$(mktemp) && chmod 600 \"\$pf\" && printf '%s\\n' \"\$pin\" > \"\$pf\" && unset pin || exit 1"
        if test "${ELEBAKE_PKCS11_BRIDGE:-}" = engine; then
                printf '%s\n' "osslsigncode sign \\"
                printf '%s\n' "  -pkcs11engine '${ELEBAKE_PKCS11_ENGINE:-}' \\"
        else
                printf '%s\n' "OPENSSL_MODULES='$(dirname "${ELEBAKE_PKCS11_PROVIDER:-/usr/local/lib/ossl-modules/x}")' osslsigncode sign \\"
        fi
        printf '%s\n' "  -pkcs11module '${ELEBAKE_PKCS11_MODULE:-}' \\"
        printf '%s\n' "  -key '$uri' \\"
        printf '%s\n' "  -certs '$cert' \\"
        printf '%s\n' "  -in '$ELEBAKE_BASE/stage/$1/boot/loader.efi' \\"
        printf '%s\n' "  -readpass \"\$pf\" \\"
        printf '%s\n' "  -out '$ELEBAKE_BASE/stage/$1/boot/loader.efi.signed'"
        printf '%s\n' "rc=\$?; rm -f \"\$pf\""
        printf '%s\n' "[ \"\$rc\" -eq 0 ] || { rm -f '$ELEBAKE_BASE/stage/$1/boot/loader.efi.signed'; printf '# Error: osslsigncode failed (PIN? token?)\\n' >&2; exit 1; }"
}

#@help ___stage_attest1
# @command stage attest <stage>
# @summary Detach-sign the stage manifest with the bound attest key: gpg is there, the stage exists, the attest-key is bound and complete, the manifest is there; then 'stage detachsign' (armored detached signature boot/manifest.asc, exactly what the loader verifies against the anchor)
# @group   stage
# @example elebake stage attest daily-v1
# @see     stage attest key
# @see     stage manifest
# @see     stage trust
#@end
___stage_attest1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" openpgp prerequisites"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage attest key bound '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage attest key complete '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage manifest exists '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage detachsign '$1'"
}

#@help _stage_detachsign1
# @command stage detachsign <stage>
# @summary Act terminal: rm -f of a stale manifest.asc, GPG_TTY pointed at the terminal for the card's pinentry (the isolated environment carries none and stdin is a pipe), gpg --detach-sign with the record's keyid (and GNUPGHOME when recorded); a failed signature leaves no file
# @group   stage
# @internal
# @see     stage attest
#@end
_stage_detachsign1() {
        local gpgenv=""
        test ! -f "$ELEBAKE_BASE/stage/$1/attest-key/gnupghome" || gpgenv="GNUPGHOME='$(head -n1 "$ELEBAKE_BASE/stage/$1/attest-key/gnupghome")' "
        emit_note "elebake stage attest '$1' (armored detached signature -> boot/manifest.asc)"
        printf '%s\n' "rm -f '$ELEBAKE_BASE/stage/$1/boot/manifest.asc'"
        printf '%s\n' "GPG_TTY=\$( { tty </dev/tty; } 2>/dev/null ); export GPG_TTY; ${gpgenv}gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1 || true"
        printf '%s\n' "${gpgenv}gpg --yes --openpgp -a --detach-sign --local-user '$(head -n1 "$ELEBAKE_BASE/stage/$1/attest-key/keyid" 2>/dev/null)' -o '$ELEBAKE_BASE/stage/$1/boot/manifest.asc' '$ELEBAKE_BASE/stage/$1/boot/manifest' || { rm -f '$ELEBAKE_BASE/stage/$1/boot/manifest.asc'; printf '# Error: manifest attestation failed for %s\\n' '$(head -n1 "$ELEBAKE_BASE/stage/$1/attest-key/keyid" 2>/dev/null)' >&2; exit 1; }"
        printf '%s\n' "printf '# manifest attested for stage %s\\n' '$1' >&2"
}

#@help ___stage_checkout2
# @command stage checkout <stage> <ref>
# @summary Add a DETACHED git worktree of ELEBAKE_FREEBSD_SRC at <ref> (a snapshot, never a branch to commit on) and point the stage at it: the toolchain is there, the stage exists, the source repo is set; then 'stage worktree'
# @group   stage
# @env     ELEBAKE_FREEBSD_SRC  the source repo the worktree is added from
# @example elebake stage checkout daily-v1 platform-trust-gates-15.1
# @see     stage build
# @see     stage clean
#@end
___stage_checkout2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" freebsd prerequisites"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" freebsd source set"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage worktree '$1' '$2'"
}

#@help _stage_worktree2
# @command stage worktree <stage> <ref>
# @summary Act terminal: git worktree add --detach under $ELEBAKE_ROOT/worktree/<id> (an attached branch would block every later push of that branch into the source repo), the work link, the checkout record
# @group   stage
# @internal
# @env     ELEBAKE_FREEBSD_SRC  the source repo
# @see     stage checkout
#@end
_stage_worktree2() {
        local wt=""
        wt="$ELEBAKE_ROOT/worktree/$(basename "$(readlink "$ELEBAKE_BASE/stage/$1")")"
        printf '%s\n' "$MODIFY_DIR_CREATE '$ELEBAKE_ROOT/worktree'"
        printf '%s\n' "git -C '${ELEBAKE_FREEBSD_SRC:-}' worktree add --detach '$wt' '$2'"
        printf '%s\n' "$MODIFY_LINK_FORCE '$wt' '$ELEBAKE_BASE/stage/$1/work'"
        printf '%s\n' "echo '$2' > '$ELEBAKE_BASE/stage/$1/checkout'"
        printf '%s\n' "$MODIFY_FILE_PERMS 0600 '$ELEBAKE_BASE/stage/$1/checkout'"
        printf '%s\n' "printf '# Checked out %s at %s (worktree %s)\\n' '$1' '$2' '$wt' >&2"
}

#@help __stage_checked_out1
# @command stage checked out <stage>
# @summary The stage has its worktree (the work link): a comment line, else an error line (stage checkout first)
# @group   stage
# @internal
# @see     stage checkout
# @see     stage build
#@end
__stage_checked_out1() {
        if test -L "$ELEBAKE_BASE/stage/$1/work"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'stage $1 checked out'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage $1: not checked out (stage checkout $1 <ref>)'"
        fi
}

#@help __stage_obj_exists1
# @command stage obj exists <stage>
# @summary The stage's isolated object tree exists: a comment line, else an error line (stage build first)
# @group   stage
# @internal
# @see     stage install
# @see     stage install kernel
#@end
__stage_obj_exists1() {
        if test -d "$ELEBAKE_BASE/stage/$1/obj"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'stage $1 has an obj tree'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage $1: no obj tree (stage build $1 first)'"
        fi
}

#@help ___stage_clean1
# @command stage clean <stage>
# @summary cleandir the worktree's stand/ build and reset the stage's build outputs: the stage exists and is checked out; then 'stage clean dir' and 'stage reset'
# @group   stage
# @example elebake stage clean daily-v1
# @see     stage build
#@end
___stage_clean1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage checked out '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage clean dir '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage reset '$1'"
}

#@help _stage_clean_dir1
# @command stage clean dir <stage>
# @summary Act terminal: make cleandir in the worktree's stand/ with the isolated obj -- stand/ only (a top-level cleandir recurses the ENTIRE tree, takes minutes and probes objdirs it may not create); the make target is ONE word
# @group   stage
# @internal
# @see     stage clean
#@end
_stage_clean_dir1() {
        printf '%s\n' "$MODIFY_DIR_CREATE '$ELEBAKE_BASE/stage/$1/obj'"
        printf '%s\n' "MAKEOBJDIRPREFIX='$ELEBAKE_BASE/stage/$1/obj' make -C '$ELEBAKE_BASE/stage/$1/work/stand' cleandir"
}

#@help _stage_reset1
# @command stage reset <stage>
# @summary Act terminal: clear destdir/ ONLY -- boot/ is the curated truth (adopted config + included artifacts) and survives every rebuild
# @group   stage
# @internal
# @see     stage clean
#@end
_stage_reset1() {
        printf '%s\n' "$MODIFY_FILE_REMOVE -r '$ELEBAKE_BASE/stage/$1/destdir/'*"
        printf '%s\n' "printf '# Reset build outputs of stage %s (destdir/)\\n' '$1' >&2"
}

#@help ___stage_build1
# @command stage build <stage>
# @summary The isolated stand/ build: the toolchain, the build gate (keys bound), clean, then one 'stage build stand <stage> <component>' per curated component
# @group   stage
# @env     ELEBAKE_STAND_BUILD_SUBDIRS  curated components in SUBDIR_DEPEND order (see the template)
# @env     ELEBAKE_MAKEARGS  extra make(1) arguments per component (e.g. -j16); empty = none
# @example elebake stage build daily-v1
# @see     stage make
# @see     stage install
# @see     stage checkout
#@end
___stage_build1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" freebsd prerequisites"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage build ready '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage clean '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage build stand '$1'"
}

#@help ___stage_build_stand1
# @internal arity-1 sibling of 'stage build stand' (stage build stand <stage>): One 'stage build stand <stage> <component>' per component of ELEBAKE_STAND_BUILD_SUBDIRS (curated policy in SUBDIR_DEPEND order); an unset list is an error line
#@end
___stage_build_stand1() {
        local sd=""
        for sd in ${ELEBAKE_STAND_BUILD_SUBDIRS:-}; do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage build stand '$1' '$sd'"
        done
        test -n "${ELEBAKE_STAND_BUILD_SUBDIRS:-}" || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage build stand: ELEBAKE_STAND_BUILD_SUBDIRS not set (environment init <profile>)'"
}

#@help ___stage_build_stand2
# @command stage build stand <stage> <component>
# @summary Build ONE stand/ component in the isolated obj tree: the stage is checked out, the component exists in the checkout; then 'stage build stand run'
# @group   stage
# @internal
# @see     stage build
#@end
___stage_build_stand2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage checked out '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage stand component exists '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage build stand run '$1' '$2'"
}

#@help __stage_stand_component_exists2
# @command stage stand component exists <stage> <component>
# @summary stand/<component> exists in the checkout: a comment line, else an error line
# @group   stage
# @internal
# @see     stage build stand
# @see     stage install
#@end
__stage_stand_component_exists2() {
        if test -d "$ELEBAKE_BASE/stage/$1/work/stand/$2"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'stand/$2 of stage $1 exists'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage $1: no such stand/ component: $2'"
        fi
}

#@help _stage_build_stand_run2
# @command stage build stand run <stage> <component>
# @summary Act terminal: make -C stand/<component> with MAKEOBJDIRPREFIX = the stage's obj (never the shared /usr/obj) and ELEBAKE_MAKEARGS
# @group   stage
# @internal
# @env     ELEBAKE_MAKEARGS  extra make(1) arguments
# @see     stage build stand
#@end
_stage_build_stand_run2() {
        printf '%s\n' "$MODIFY_DIR_CREATE '$ELEBAKE_BASE/stage/$1/obj'"
        printf '%s\n' "MAKEOBJDIRPREFIX='$ELEBAKE_BASE/stage/$1/obj' make -C '$ELEBAKE_BASE/stage/$1/work/stand/$2' ${ELEBAKE_MAKEARGS:-}"
}

#@help ___stage_make1
# @command stage make <stage>
# @summary BUILD the stage: build (gate, clean, stand), install, include, sign -- publishing is stage push. Needs executing interpreter pins on the terminals underneath, otherwise every step only displays (see the environment topic)
# @group   stage
# @example elebake stage make daily-v1
# @see     stage push
# @see     stage build
#@end
___stage_make1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage build '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage install '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage include '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage sign '$1'"
}

#@help ___stage_install1
# @command stage install <stage>
# @summary Unprivileged stand/ DESTDIR install into destdir/: one 'stage install <stage> <component>' per component of ELEBAKE_STAND_INSTALL_SUBDIRS (curated policy); an unset list is an error line
# @group   stage
# @env     ELEBAKE_STAND_INSTALL_SUBDIRS  curated components that land in destdir/ (see the template)
# @example elebake stage install daily-v1
# @see     stage build
# @see     stage include
#@end
___stage_install1() {
        local sd=""
        for sd in ${ELEBAKE_STAND_INSTALL_SUBDIRS:-}; do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage install '$1' '$sd'"
        done
        test -n "${ELEBAKE_STAND_INSTALL_SUBDIRS:-}" || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage install: ELEBAKE_STAND_INSTALL_SUBDIRS not set (environment init <profile>)'"
}

#@help ___stage_install2
# @internal arity-2 sibling of 'stage install' (stage install <stage> <component>): DESTDIR-install ONE stand/ component into destdir/: the stage is checked out, its obj tree exists, the component exists; then 'stage install run'
#@end
___stage_install2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage checked out '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage obj exists '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage stand component exists '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage install run '$1' '$2'"
}

#@help _stage_install_run2
# @command stage install run <stage> <component>
# @summary Act terminal: the /boot skeleton (install(1) creates no directories), then make install with INSTALL='install -U' (unprivileged; media get real ownership at deploy), without man pages and debug files, DESTDIR = the stage's destdir
# @group   stage
# @internal
# @see     stage install
#@end
_stage_install_run2() {
        printf '%s\n' "$MODIFY_DIR_CREATE '$ELEBAKE_BASE/stage/$1/destdir/boot/defaults' '$ELEBAKE_BASE/stage/$1/destdir/boot/fonts' '$ELEBAKE_BASE/stage/$1/destdir/boot/images' '$ELEBAKE_BASE/stage/$1/destdir/boot/lua'"
        printf '%s\n' "MAKEOBJDIRPREFIX='$ELEBAKE_BASE/stage/$1/obj' make -C '$ELEBAKE_BASE/stage/$1/work/stand/$2' install INSTALL=\"install -U\" -DWITHOUT_MAN -DWITHOUT_DEBUG_FILES DESTDIR='$ELEBAKE_BASE/stage/$1/destdir'"
}

#@help ___stage_build_kernel1
# @command stage build kernel <stage>
# @summary Build the kernel from the stage's checkout -- the source delivers EVERYTHING, the filter selects: the stage exists and is checked out, ELEBAKE_KERNCONF is set (no implicit default: the guarding kernel is a decision) and exists in the checkout; then 'stage build kernel run' (isolated per-stage obj)
# @group   stage
# @env     ELEBAKE_KERNCONF  the kernel configuration to build (e.g. GENERIC)
# @env     ELEBAKE_MAKEARGS  extra make(1) arguments (e.g. -j16 -- parallel builds are the owner's decision, the default is serial); empty = none
# @example elebake stage build kernel daily-v1
# @see     stage install kernel
# @see     stage filter add
#@end
___stage_build_kernel1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage checked out '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage kernconf set"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage kernconf exists '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage build kernel run '$1'"
}

#@help __stage_kernconf_set0
# @command stage kernconf set
# @summary ELEBAKE_KERNCONF is set: a comment line, else an error line (the guarding kernel is a decision)
# @group   stage
# @internal
# @env     ELEBAKE_KERNCONF  the kernel configuration
# @see     stage build kernel
# @see     stage install kernel
#@end
__stage_kernconf_set0() {
        if test -n "${ELEBAKE_KERNCONF:-}"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'KERNCONF ${ELEBAKE_KERNCONF:-}'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'ELEBAKE_KERNCONF not set (elebake setenv ELEBAKE_KERNCONF GENERIC)'"
        fi
}

#@help __stage_kernconf_exists1
# @command stage kernconf exists <stage>
# @summary The configuration sys/amd64/conf/<KERNCONF> exists in the checkout: a comment line, else an error line
# @group   stage
# @internal
# @env     ELEBAKE_KERNCONF  the kernel configuration
# @see     stage build kernel
#@end
__stage_kernconf_exists1() {
        if test -f "$ELEBAKE_BASE/stage/$1/work/sys/amd64/conf/${ELEBAKE_KERNCONF:-}"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'KERNCONF ${ELEBAKE_KERNCONF:-} in the checkout of $1'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage build kernel $1: no such KERNCONF in this checkout: ${ELEBAKE_KERNCONF:-}'"
        fi
}

#@help _stage_build_kernel_run1
# @command stage build kernel run <stage>
# @summary Act terminal: make buildkernel in the worktree with the isolated obj, ELEBAKE_MAKEARGS and KERNCONF
# @group   stage
# @internal
# @env     ELEBAKE_KERNCONF  the kernel configuration
# @env     ELEBAKE_MAKEARGS  extra make(1) arguments
# @see     stage build kernel
#@end
_stage_build_kernel_run1() {
        printf '%s\n' "$MODIFY_DIR_CREATE '$ELEBAKE_BASE/stage/$1/obj'"
        printf '%s\n' "MAKEOBJDIRPREFIX='$ELEBAKE_BASE/stage/$1/obj' make -C '$ELEBAKE_BASE/stage/$1/work' ${ELEBAKE_MAKEARGS:-} buildkernel KERNCONF='${ELEBAKE_KERNCONF:-}'"
}

#@help ___stage_install_kernel1
# @command stage install kernel <stage>
# @summary Unprivileged installkernel into the stage's destdir (destdir/boot/kernel becomes selectable by the filter): the stage exists and is checked out, ELEBAKE_KERNCONF is set, the obj tree exists; then 'stage install kernel run'
# @group   stage
# @env     ELEBAKE_KERNCONF  the kernel configuration to install (must match the build)
# @env     ELEBAKE_MAKEARGS  the same extra make(1) arguments as the build (WITH_*/WITHOUT_* decide which modules installkernel copies; -j is harmless here); empty = none
# @example elebake stage install kernel daily-v1
# @see     stage build kernel
# @see     stage filter add
#@end
___stage_install_kernel1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage checked out '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage kernconf set"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage obj exists '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage install kernel run '$1'"
}

#@help _stage_install_kernel_run1
# @command stage install kernel run <stage>
# @summary Act terminal: make installkernel with the SAME make arguments as the build (installkernel evaluates src.opts.mk again: a WITH_/WITHOUT_ option that shaped the module list at build time must shape it at install time too -- WITH_VERIEXEC=yes built five modules an install without it silently left out, 07.09.), INSTALL='install -U', DESTDIR = the stage's destdir
# @group   stage
# @internal
# @env     ELEBAKE_KERNCONF  the kernel configuration
# @env     ELEBAKE_MAKEARGS  extra make(1) arguments
# @see     stage install kernel
#@end
_stage_install_kernel_run1() {
        printf '%s\n' "$MODIFY_DIR_CREATE '$ELEBAKE_BASE/stage/$1/destdir/boot'"
        printf '%s\n' "MAKEOBJDIRPREFIX='$ELEBAKE_BASE/stage/$1/obj' make -C '$ELEBAKE_BASE/stage/$1/work' ${ELEBAKE_MAKEARGS:-} installkernel KERNCONF='${ELEBAKE_KERNCONF:-}' INSTALL=\"install -U\" DESTDIR='$ELEBAKE_BASE/stage/$1/destdir'"
}

#@help ___stage_loader2
# @command stage loader <stage> <loader.efi>
# @summary Ingest an ALREADY-BUILT external loader as boot/loader.efi (sign it without building): the stage exists, the source file exists; then 'stage loader ingest'
# @group   stage
# @param   loader.efi  path to a pre-built EFI loader (e.g. a stock installer's BOOTX64.EFI)
# @example elebake stage loader rescue-v1 /mnt/EFI/BOOT/BOOTX64.EFI
# @see     stage sign
#@end
___stage_loader2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage loader source exists '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage loader ingest '$1' '$2'"
}

#@help __stage_loader_source_exists1
# @command stage loader source exists <loader.efi>
# @summary The external loader file exists: a comment line, else an error line
# @group   stage
# @internal
# @see     stage loader
#@end
__stage_loader_source_exists1() {
        if test -f "$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'loader $1 exists'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage loader: no such file: $1'"
        fi
}

#@help _stage_loader_ingest2
# @command stage loader ingest <stage> <loader.efi>
# @summary Act terminal: rm -f (an adopted or earlier loader may be 0555 and unwritable) and cp of the external loader to boot/loader.efi; 'stage sign' then produces boot/loader.efi.signed
# @group   stage
# @internal
# @see     stage loader
#@end
_stage_loader_ingest2() {
        emit_note "elebake stage loader '$1' ($2 -> boot/loader.efi)"
        printf '%s\n' "$MODIFY_DIR_CREATE '$ELEBAKE_BASE/stage/$1/boot'"
        printf '%s\n' "rm -f '$ELEBAKE_BASE/stage/$1/boot/loader.efi' && cp '$2' '$ELEBAKE_BASE/stage/$1/boot/loader.efi' || { printf '# Error: loader ingest failed\\n' >&2; exit 1; }"
        printf '%s\n' "printf '# ingested %s -> boot/loader.efi of stage %s (now: stage sign %s)\\n' '$2' '$1' '$1' >&2"
}

#@help ___stage_manifest1
# @command stage manifest <stage>
# @summary Generate the REAL veriexec manifest over boot/ (path sha256=hash, LC_ALL=C-sorted, every file except the manifest pair; loader.efi included on purpose -- it is the disaster reserve, and an unverified reserve is not a reserve): the stage exists and is populated; then 'stage manifest write' -- the WHOLE manifest is computed at generation, the emission is one concrete heredoc write
# @group   stage
# @example elebake stage manifest daily-v1
# @see     stage attest
# @see     stage verify
#@end
___stage_manifest1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage populated '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage manifest write '$1'"
}

#@help _stage_manifest_write1
# @command stage manifest write <stage>
# @summary Act terminal: the heredoc that writes boot/manifest.new (entries hashed now), then mv into place (0644) and the count line
# @group   stage
# @internal
# @see     stage manifest
#@end
_stage_manifest_write1() {
        local rel="" n=0
        n=$( { cd "$ELEBAKE_BASE/stage/$1/boot" 2>/dev/null && find . -type f ! -name manifest ! -name manifest.asc; } | wc -l | tr -d ' ')
        emit_note "elebake stage manifest '$1' ($n entries, hashed at generation time)"
        printf '%s\n' "cat > '$ELEBAKE_BASE/stage/$1/boot/manifest.new' <<'ELVEOF'"
        { cd "$ELEBAKE_BASE/stage/$1/boot" 2>/dev/null && find . -type f ! -name manifest ! -name manifest.asc; } | sed 's|^\./||' | LC_ALL=C sort | while IFS= read -r rel; do
                printf '%s sha256=%s\n' "$rel" "$(sha256 -q "$ELEBAKE_BASE/stage/$1/boot/$rel" 2>/dev/null)"
        done
        printf '%s\n' "ELVEOF"
        printf '%s\n' "mv '$ELEBAKE_BASE/stage/$1/boot/manifest.new' '$ELEBAKE_BASE/stage/$1/boot/manifest' && chmod 0644 '$ELEBAKE_BASE/stage/$1/boot/manifest'"
        printf '%s\n' "printf '# manifest written: %s entries\\n' '$n' >&2"
}

#@help ___stage_verify1
# @command stage verify <stage>
# @summary Manifest consistency BOTH ways, checked at generation time: the stage exists, the manifest is there; then 'stage verify listed' (every listed entry exists and hashes identically) and 'stage verify unlisted' (every file in boot/ is listed)
# @group   stage
# @example elebake stage verify daily-v1
# @see     stage manifest
# @see     stage push
#@end
___stage_verify1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage manifest exists '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage verify listed '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage verify unlisted '$1'"
}

#@help __stage_verify_listed1
# @command stage verify listed <stage>
# @summary Direction 1: every manifest entry exists in boot/ and hashes identically: a log line, else an error line carrying the findings (MISSING, MISMATCH)
# @group   stage
# @internal
# @see     stage verify
#@end
__stage_verify_listed1() {
        local findings=""
        findings=$(manifest_findings "$ELEBAKE_BASE/stage/$1/boot" "$ELEBAKE_BASE/stage/$1/boot/manifest" "MISSING|MISMATCH")
        if test -z "$findings"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log 'stage verify $1: $(grep -c sha256= "$ELEBAKE_BASE/stage/$1/boot/manifest" 2>/dev/null) listed entries match'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage verify $1: listed entries differ' $(sq "$(printf '%s' "$findings" | tr '\n' ';')")"
        fi
}

#@help __stage_verify_unlisted1
# @command stage verify unlisted <stage>
# @summary Direction 2: every file in boot/ (except the manifest pair) is listed: a log line, else an error line carrying the findings (UNLISTED)
# @group   stage
# @internal
# @see     stage verify
#@end
__stage_verify_unlisted1() {
        local findings=""
        findings=$(manifest_findings "$ELEBAKE_BASE/stage/$1/boot" "$ELEBAKE_BASE/stage/$1/boot/manifest" "UNLISTED")
        if test -z "$findings"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log 'stage verify $1: nothing unlisted in boot/'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage verify $1: unlisted files in boot/' $(sq "$(printf '%s' "$findings" | tr '\n' ';')")"
        fi
}

#@help ___stage_trust1
# @command stage trust <stage>
# @summary Root of trust into the worktree, in one step: 'stage trust anchor' exports the bound attest key (its public key and a self-test signature) into lib/libsecureboot, 'stage trust mk' writes site.trust.mk -- the veriexec anchor the loader is BUILT with, so this runs after 'stage attest key' and before 'stage build'. Assumes: the attest key is RSA (the loader's BearSSL verifies RSA only) and its keyring is readable: the shipped profiles pin the anchor export to sudo sh (the keyring lives under /root), so the batch asks for the password by itself
# @group   stage
# @example elebake stage trust daily-v1
# @see     stage attest key
# @see     stage build
#@end
___stage_trust1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage trust anchor '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage trust mk '$1'"
}

#@help ___stage_trust_anchor1
# @command stage trust anchor <stage>
# @summary Export the attest key + self-test signature into the worktree's libsecureboot: the stage exists and is checked out, the attest key is bound and complete; then 'stage trust anchor export'
# @group   stage
# @see     stage trust
# @see     stage trust mk
#@end
___stage_trust_anchor1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage checked out '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage attest key bound '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage attest key complete '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage trust anchor export '$1'"
}

#@help _stage_trust_anchor_export1
# @command stage trust anchor export <stage>
# @summary Act terminal: rm -f of earlier artifacts (a failed elevated run may have left root-owned empties), gpg --export of the keyid to ta_openpgp.asc with the emptiness test as the real check (gpg exits 0 on nothing exported), GPG_TTY pointed at the terminal for the card's pinentry, the self-test signature vc_openpgp.asc; every step stops the batch on failure
# @group   stage
# @internal
# @see     stage trust anchor
#@end
_stage_trust_anchor_export1() {
        local gpgenv="" keyid=""
        keyid=$(head -n1 "$ELEBAKE_BASE/stage/$1/attest-key/keyid" 2>/dev/null)
        test ! -f "$ELEBAKE_BASE/stage/$1/attest-key/gnupghome" || gpgenv="GNUPGHOME='$(head -n1 "$ELEBAKE_BASE/stage/$1/attest-key/gnupghome")' "
        emit_note "elebake stage trust anchor '$1' (OpenPGP trust anchor + self-test sig)"
        printf '%s\n' "rm -f '$ELEBAKE_BASE/stage/$1/work/lib/libsecureboot/ta_openpgp.asc' '$ELEBAKE_BASE/stage/$1/work/lib/libsecureboot/vc_openpgp.asc'"
        printf '%s\n' "${gpgenv}gpg --export -a '$keyid' > '$ELEBAKE_BASE/stage/$1/work/lib/libsecureboot/ta_openpgp.asc' || { printf '# Error: trust anchor export failed for %s\\n' '$keyid' >&2; exit 1; }"
        printf '%s\n' "[ -s '$ELEBAKE_BASE/stage/$1/work/lib/libsecureboot/ta_openpgp.asc' ] || { printf '# Error: trust anchor export empty -- key %s not in this keyring? (openpgp add <name> <keyid> <gnupghome> for a keyring living elsewhere)\\n' '$keyid' >&2; exit 1; }"
        printf '%s\n' "GPG_TTY=\$( { tty </dev/tty; } 2>/dev/null ); export GPG_TTY; ${gpgenv}gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1 || true"
        printf '%s\n' "${gpgenv}gpg --yes --openpgp -a --detach-sign --local-user '$keyid' -o '$ELEBAKE_BASE/stage/$1/work/lib/libsecureboot/vc_openpgp.asc' '$ELEBAKE_BASE/stage/$1/work/lib/libsecureboot/ta_openpgp.asc' || { printf '# Error: self-test signature failed for %s\\n' '$keyid' >&2; exit 1; }"
        printf '%s\n' "printf '# trust anchor + self-test sig placed for stage %s\\n' '$1' >&2"
}

#@help ___stage_trust_mk1
# @command stage trust mk <stage>
# @summary Write site.trust.mk (elevated veriexec config) into the worktree: the stage exists and is checked out; then 'stage trust mk write'
# @group   stage
# @see     stage trust
# @see     stage trust anchor
#@end
___stage_trust_mk1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage checked out '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage trust mk write '$1'"
}

#@help _stage_trust_mk_write1
# @command stage trust mk write <stage>
# @summary Act terminal: the heredoc that writes lib/libsecureboot/site.trust.mk -- serverless OpenPGP, SHA256/SHA384, self tests, the anchor and self-test lists, the elevated loader flag
# @group   stage
# @internal
# @see     stage trust mk
#@end
_stage_trust_mk_write1() {
        emit_note "elebake stage trust mk '$1' (site.trust.mk: elevated OpenPGP config)"
        printf '%s\n' "cat > '$ELEBAKE_BASE/stage/$1/work/lib/libsecureboot/site.trust.mk' <<'ELVEOF'"
        printf '%s\n' "# Generated by elebake -- do not edit by hand. Serverless OpenPGP."
        printf '%s\n' "VE_SIGNATURE_LIST= OPENPGP"
        printf '%s\n' "VE_HASH_LIST= SHA256 SHA384"
        printf '%s\n' "VE_SELF_TESTS= yes"
        printf '%s\n' "TRUST_ANCHORS= $ELEBAKE_BASE/stage/$1/work/lib/libsecureboot/ta_openpgp.asc"
        printf '%s\n' "TA_ASC_LIST= $ELEBAKE_BASE/stage/$1/work/lib/libsecureboot/ta_openpgp.asc"
        printf '%s\n' "VC_ASC_LIST= $ELEBAKE_BASE/stage/$1/work/lib/libsecureboot/vc_openpgp.asc"
        printf '%s\n' "ta_asc.h: \${TA_ASC_LIST} \${VC_ASC_LIST}"
        printf '%s\n' "XCFLAGS.opgp_key+= -DHAVE_TA_ASC_H"
        printf '%s\n' "CFLAGS+= -DLOADER_VERIEXEC_ELEVATED"
        printf '%s\n' "ELVEOF"
        printf '%s\n' "printf '# site.trust.mk written for stage %s\\n' '$1' >&2"
}

#@help __stage_check_stage1
# @command stage check stage <stage>
# @summary The stage exists (its name symlink under stage/): a comment line, else an error line -- the first line of every batch that acts on a stage
# @group   stage
# @internal
# @see     stage add
# @see     stage list
#@end
__stage_check_stage1() {
        if test -L "$ELEBAKE_BASE/stage/$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'stage $1 exists'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'unknown stage $1 (stage add $1, or stage list)'"
        fi
}

#@help __stage_source_absolute1
# @command stage source absolute <srcdir>
# @summary The source directory path is absolute: a comment line, else an error line
# @group   stage
# @internal
# @see     stage include
# @see     stage filter show
#@end
__stage_source_absolute1() {
        if test "${1#/}" != "$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'source $1 absolute'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'source must be an absolute directory: $1'"
        fi
}

#@help ___stage_filter_list1
# @command stage filter list <stage>
# @summary The curated list as it stands: the stage exists; then 'stage filter table'
# @group   stage
# @see     stage filter add
# @see     stage filter show
#@end
___stage_filter_list1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage filter table '$1'"
}

#@help _stage_filter_table1
# @command stage filter table <stage>
# @summary Text terminal: the curated entries, or the hint that the filter is empty
# @group   stage
# @internal
# @see     stage filter list
#@end
_stage_filter_table1() {
        printf '# filter of %s (%s)\n' "$1" "$(basename "$(readlink "$ELEBAKE_BASE/stage/$1")")"
        if test -s "$ELEBAKE_BASE/stage/$1/filter"; then
                sed 's/^/#   /' "$ELEBAKE_BASE/stage/$1/filter"
        else
                printf '#   (empty -- stage filter add %s <rel>)\n' "$1"
        fi
}

#@help ___stage_filter_uncurated2
# @command stage filter uncurated <stage> <srcdir>
# @summary What the source directory holds at top level that the filter does not cover: the stage exists, the source is absolute; then 'stage filter uncurated table'
# @group   stage
# @see     stage filter show
# @see     stage include
#@end
___stage_filter_uncurated2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage source absolute '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage filter uncurated table '$1' '$2'"
}

#@help _stage_filter_uncurated_table2
# @command stage filter uncurated table <stage> <srcdir>
# @summary Text terminal: the top-level entries of the source the filter does not cover; an absent source and an empty list are said so
# @group   stage
# @internal
# @see     stage filter uncurated
#@end
_stage_filter_uncurated_table2() {
        local e="" found=0
        printf '#\n# uncurated in %s (top level):\n' "$2"
        test -d "$2" || printf '#   (source not present)\n'
        for e in "$2"/* "$2"/.[!.]*; do
                test -e "$e" || continue
                filter_covers "$ELEBAKE_BASE/stage/$1/filter" "${e##*/}" && continue
                printf '#   %s\n' "${e##*/}"; found=1
        done
        test "$found" -eq 1 || test ! -d "$2" || printf '#   (none)\n'
}

#@help ___stage_filter_orphaned1
# @command stage filter orphaned <stage>
# @summary What lies in boot/ that the filter does not cover and no step generates: the stage exists; then 'stage filter orphaned table'
# @group   stage
# @see     stage filter prune
# @see     stage filter show
#@end
___stage_filter_orphaned1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage filter orphaned table '$1'"
}

#@help _stage_filter_orphaned_table1
# @command stage filter orphaned table <stage>
# @summary Text terminal: the top-level entries of boot/ that are neither curated nor generated (manifest, manifest.asc, loader.trust.conf, *.signed are generated); none is said so
# @group   stage
# @internal
# @see     stage filter orphaned
#@end
_stage_filter_orphaned_table1() {
        local e="" found=0
        printf '#\n# orphaned in boot/ (not covered, not generated):\n'
        test -d "$ELEBAKE_BASE/stage/$1/boot" || printf '#   (boot/ empty)\n'
        for e in "$ELEBAKE_BASE/stage/$1/boot"/* "$ELEBAKE_BASE/stage/$1/boot"/.[!.]*; do
                test -e "$e" || continue
                boot_generated "${e##*/}" && continue
                filter_covers "$ELEBAKE_BASE/stage/$1/filter" "${e##*/}" && continue
                printf '#   %s\n' "${e##*/}"; found=1
        done
        test "$found" -eq 1 || test ! -d "$ELEBAKE_BASE/stage/$1/boot" || printf '#   (none)\n'
}

#@help ___stage_filter_prune1
# @command stage filter prune <stage>
# @summary Emit the removal of every orphaned entry of boot/ (what 'stage filter orphaned' lists: neither curated nor generated) -- one rm per entry, displayed by default so the owner reads the list before piping it to sh. After 'stage adopt' this is how a medium's stale files (BIOS boot blocks, forth, old loader variants) leave the stage: the curation says what belongs, prune removes the rest. Nothing curated or generated is ever touched. The stage exists; then 'stage filter prune rm'
# @group   stage
# @example elebake stage filter prune daily-v1 | sh
# @see     stage filter orphaned
# @see     stage adopt
#@end
___stage_filter_prune1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage filter prune rm '$1'"
}

#@help _stage_filter_prune_rm1
# @command stage filter prune rm <stage>
# @summary Act terminal: one rm -rf per orphaned top-level entry of boot/ and the count; nothing orphaned is a note. Pinned to cat: shown, then piped to sh by the owner
# @group   stage
# @internal
# @see     stage filter prune
#@end
_stage_filter_prune_rm1() {
        local e="" n=0 d=""
        d=$(readlink -f "$ELEBAKE_BASE/stage/$1")
        for e in "$d/boot"/* "$d/boot"/.[!.]*; do
                test -e "$e" || continue
                boot_generated "${e##*/}" && continue
                filter_covers "$ELEBAKE_BASE/stage/$1/filter" "${e##*/}" && continue
                printf '%s\n' "rm -rf '$e'"
                n=$((n + 1))
        done
        test "${n:-0}" -gt 0 || emit_note "stage filter prune '$1': no orphaned entries"
        test "$n" -eq 0 || emit_note "stage filter prune '$1': $n orphaned entries removed from boot/ (stage filter orphaned lists what is left)"
}

#@help __stage_filter_add2
# @command stage filter add <stage> <rel|->
# @summary Curate one destdir/boot-relative path into the boot/ list (idempotent append); '-' reads a FROZEN snapshot from stdin, one path per line -- a directory entry is a LIVING curation (new files under it travel along), the snapshot a frozen one. '-': rewrite to 'stage filter add stdin <stage>', else to 'stage filter add entry <stage> <rel>'
# @group   stage
# @example elebake stage filter add daily-v1 kernel
# @example ls /my-filter | elebake stage filter add daily-v1 -
# @see     stage filter drop
# @see     stage filter list
# @see     stage include
#@end
__stage_filter_add2() {
        if test "$2" = -; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage filter add stdin '$1'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage filter add entry '$1' '$2'"
        fi
}

#@help ___stage_filter_add_stdin1
# @command stage filter add stdin <stage>
# @summary The frozen snapshot: every non-empty line of stdin (fd 3, bound by the top-level call) is checked first, then appended -- so a bad line refuses the whole snapshot before one entry lands
# @group   stage
# @internal
# @see     stage filter add
#@end
___stage_filter_add_stdin1() {
        local line="" lines=""
        while IFS= read -r line <&3; do
                test -n "$line" || continue
                lines="$lines$line
"
        done
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s' "$lines" | while IFS= read -r line; do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage filter rel valid $(sq "$line")"
        done
        printf '%s' "$lines" | while IFS= read -r line; do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage filter append '$1' $(sq "$line")"
        done
        test -n "$lines" || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage filter add: nothing on stdin'"
}

#@help ___stage_filter_add_entry2
# @command stage filter add entry <stage> <rel>
# @summary One curated entry: the stage exists, the path is destdir/boot-relative; then 'stage filter append'
# @group   stage
# @internal
# @see     stage filter add
#@end
___stage_filter_add_entry2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage filter rel valid $(sq "$2")"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage filter append '$1' $(sq "$2")"
}

#@help __stage_filter_rel_valid1
# @command stage filter rel valid <rel>
# @summary The path is destdir/boot-relative (not empty, not absolute, no .., no quote): a comment line, else an error line
# @group   stage
# @internal
# @see     stage filter add
#@end
__stage_filter_rel_valid1() {
        if stage_filter_rel_ok "$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'filter entry $1 valid'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage filter add: invalid path (destdir/boot-relative, no ..): $1'"
        fi
}

#@help _stage_filter_append2
# @command stage filter append <stage> <rel>
# @summary Act terminal: append the entry to the filter unless listed already (0600) and say so
# @group   stage
# @internal
# @see     stage filter add
#@end
_stage_filter_append2() {
        printf '%s\n' "grep -qxF '$2' '$ELEBAKE_BASE/stage/$1/filter' 2>/dev/null || echo '$2' >> '$ELEBAKE_BASE/stage/$1/filter'"
        printf '%s\n' "$MODIFY_FILE_PERMS 0600 '$ELEBAKE_BASE/stage/$1/filter'"
        printf '%s\n' "printf '# filter of %s: + %s\\n' '$1' '$2' >&2"
}

#@help ___stage_filter_drop2
# @command stage filter drop <stage> <rel>
# @summary Remove one entry from the boot/ curation list: the stage exists, the entry is listed; then 'stage filter remove'
# @group   stage
# @example elebake stage filter drop daily-v1 lua
# @see     stage filter add
# @see     stage filter list
#@end
___stage_filter_drop2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage filter listed '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage filter remove '$1' '$2'"
}

#@help __stage_filter_listed2
# @command stage filter listed <stage> <rel>
# @summary The entry is in the filter: a comment line, else an error line (not listed, or no filter yet)
# @group   stage
# @internal
# @see     stage filter drop
#@end
__stage_filter_listed2() {
        if grep -qxF "$2" "$ELEBAKE_BASE/stage/$1/filter" 2>/dev/null; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'filter entry $2 listed'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage filter drop $1: not listed: $2 (stage filter list $1)'"
        fi
}

#@help _stage_filter_remove2
# @command stage filter remove <stage> <rel>
# @summary Act terminal: rewrite the filter without the entry (.new then mv) and say so
# @group   stage
# @internal
# @see     stage filter drop
#@end
_stage_filter_remove2() {
        printf '%s\n' "grep -vxF '$2' '$ELEBAKE_BASE/stage/$1/filter' > '$ELEBAKE_BASE/stage/$1/filter.new'; mv '$ELEBAKE_BASE/stage/$1/filter.new' '$ELEBAKE_BASE/stage/$1/filter'"
        printf '%s\n' "printf '# filter of %s: - %s\\n' '$1' '$2' >&2"
}

#@help __stage_filter_show1
# @internal 1-arg sibling of 'stage filter show': the default source is the stage's own destdir/boot
#@end
__stage_filter_show1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage filter show '$1' '$ELEBAKE_BASE/stage/$1/destdir/boot'"
}

#@help ___stage_filter_show2
# @command stage filter show <stage> [<srcdir>]
# @summary ONE view, the whole truth, as three tables: the curated list, what sits uncurated in the source (default: the stage's own destdir/boot), what lies orphaned in boot/
# @group   stage
# @example elebake stage filter show daily-v1
# @see     stage filter list
# @see     stage filter uncurated
# @see     stage filter orphaned
#@end
___stage_filter_show2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage source absolute '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage filter list '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage filter uncurated '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage filter orphaned '$1'"
}

#@help __stage_include1
# @internal 1-arg sibling of 'stage include': the default source is the stage's own destdir/boot
#@end
__stage_include1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage include '$1' '$ELEBAKE_BASE/stage/$1/destdir/boot'"
}

#@help ___stage_include2
# @command stage include <stage> [<srcdir>]
# @summary Work the curated filter off from a chosen SOURCE directory (default: the stage's own destdir/boot; e.g. /boot takes the same selection from the host's binaries): the stage exists, the source is absolute and present, the filter is not empty, every entry is in the source or already in boot/; then 'stage include copy'. Per entry: present in the source -> copied into boot/ (directories replaced whole); absent from the source but present in boot/ -> kept and noted (an adopted file the build does not deliver, e.g. loader.conf after stage adopt); absent from both -> refused before anything ran
# @group   stage
# @example elebake stage include daily-v1
# @example elebake stage include daily-v1 /boot
# @see     stage filter add
# @see     stage adopt
# @see     stage install
#@end
___stage_include2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage source absolute '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage filter nonempty '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage source present '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage include entries valid '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage include copy '$1' '$2'"
}

#@help __stage_filter_nonempty1
# @command stage filter nonempty <stage>
# @summary The filter has entries: a comment line, else an error line
# @group   stage
# @internal
# @see     stage include
#@end
__stage_filter_nonempty1() {
        if test -s "$ELEBAKE_BASE/stage/$1/filter"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'filter of $1 has entries'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage include $1: filter empty or missing (stage filter add $1 <rel>)'"
        fi
}

#@help __stage_source_present1
# @command stage source present <srcdir>
# @summary The source directory exists: a comment line, else an error line (stage install first?)
# @group   stage
# @internal
# @see     stage include
#@end
__stage_source_present1() {
        if test -d "$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'source $1 present'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'source not present: $1 (stage install first?)'"
        fi
}

#@help __stage_include_entries_valid2
# @command stage include entries valid <stage> <srcdir>
# @summary Every filter entry is in the source or already in boot/: a comment line, else an error line naming the first that is in neither
# @group   stage
# @internal
# @see     stage include
#@end
__stage_include_entries_valid2() {
        local rel="" missing=""
        missing=$(grep . "$ELEBAKE_BASE/stage/$1/filter" 2>/dev/null | while IFS= read -r rel; do test -e "$2/$rel" || test -e "$ELEBAKE_BASE/stage/$1/boot/$rel" || printf '%s\n' "$rel"; done | head -n1)
        if test -z "$missing"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'every filter entry of $1 is in $2 or boot/'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage include $1: listed but neither in $2 nor in boot/: $missing'"
        fi
}

#@help _stage_include_copy2
# @command stage include copy <stage> <srcdir>
# @summary Act terminal: per filter entry present in the source, mkdir of its parent, rm -rf of the old and cp -a of the new (adopted trees carry 0555 files, directory entries must be replaced whole); an entry absent from the source is kept from boot/ and noted; the count line last
# @group   stage
# @internal
# @see     stage include
#@end
_stage_include_copy2() {
        local rel="" k=0 n=0
        n=$(grep -c . "$ELEBAKE_BASE/stage/$1/filter" 2>/dev/null)
        emit_note "elebake stage include '$1' ($n filter entries from $2)"
        grep . "$ELEBAKE_BASE/stage/$1/filter" 2>/dev/null | while IFS= read -r rel; do
                if test -e "$2/$rel"; then
                        printf '%s\n' "$MODIFY_DIR_CREATE '$ELEBAKE_BASE/stage/$1/$(dirname "boot/$rel")'"
                        printf '%s\n' "rm -rf '$ELEBAKE_BASE/stage/$1/boot/$rel' && cp -a '$2/$rel' '$ELEBAKE_BASE/stage/$1/boot/$rel' || { printf '# Error: include failed for %s\\n' '$rel' >&2; exit 1; }"
                else
                        emit_note "stage include '$1': $rel kept from boot/ (not in $2 -- adopted, the build does not deliver it)"
                fi
        done
        k=$(grep . "$ELEBAKE_BASE/stage/$1/filter" 2>/dev/null | while IFS= read -r rel; do test -e "$2/$rel" || printf 'x\n'; done | wc -l | tr -d ' ')
        printf '%s\n' "printf '# Included %s filter entries into boot/ of stage %s (source: %s; %s kept from boot/)\\n' '$((n - k))' '$1' '$2' '$k' >&2"
}

#@help ___stage_import2
# @internal arity-2 sibling of 'stage import' (stage import <stage> <reldir>): Declare ONE directory of the record tree: the stage exists, the path is record-relative; then 'stage import dir'
#@end
___stage_import2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage import dir valid '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage import dir '$1' '$2'"
}

#@help ___stage_import3
# @command stage import <stage> <reldir> [<absfile>]
# @summary Import ONE base element from another database: two args declare a record-tree DIRECTORY, three copy a file/symlink into it -- an unconditional check-then-act sequence; the logic lives in the dump that emits these lines. Three args: the stage exists, the subdir is record-relative and declared, the source an absolute existing file or symlink; then 'stage import file'
# @group   stage
# @param   reldir   record-relative target ('.' for the record root on the file form); a directory must be declared (2-arg form) before files land in it
# @param   absfile  absolute source path in the OTHER database (file form only)
# @example elebake stage import daily-v1 boot/kernel
# @see     stage dump
# @see     restore
#@end
___stage_import3() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage import subdir valid '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage import source exists '$3'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage import target declared '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage import file '$1' '$2' '$3'"
}

#@help __stage_import_dir_valid1
# @command stage import dir valid <reldir>
# @summary The directory path is record-relative (no leading slash, no ..): a comment line, else an error line
# @group   stage
# @internal
# @see     stage import
#@end
__stage_import_dir_valid1() {
        if import_rel "$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'record directory $1 valid'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage import: invalid directory $1 (record-relative, no ..)'"
        fi
}

#@help __stage_import_subdir_valid1
# @command stage import subdir valid <subdir>
# @summary The target subdir is record-relative ('.' is the record root): a comment line, else an error line
# @group   stage
# @internal
# @see     stage import
#@end
__stage_import_subdir_valid1() {
        if import_rel "$1" dot; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'record subdir $1 valid'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage import: invalid subdir $1 (record-relative, no ..)'"
        fi
}

#@help __stage_import_source_exists1
# @command stage import source exists <absfile>
# @summary The source is an absolute path to an existing file or symlink (a directory is declared with the 2-arg form): a comment line, else an error line
# @group   stage
# @internal
# @see     stage import
#@end
__stage_import_source_exists1() {
        if test "${1#/}" != "$1" && { test -L "$1" || test -f "$1"; }; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'base element $1 exists'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage import: no such base element, not absolute, or a directory (use the 2-arg form for one): $1'"
        fi
}

#@help __stage_import_target_declared2
# @command stage import target declared <stage> <subdir>
# @summary The target directory was declared (2-arg form) before -- in a replayed dump the declaring lines ran earlier in the same batch: a comment line, else an error line
# @group   stage
# @internal
# @see     stage import
#@end
__stage_import_target_declared2() {
        if test -d "$ELEBAKE_BASE/stage/$1/$2"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'target stage/$1/$2 declared'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage import: target dir missing: stage/$1/$2 (check stage + declare first)'"
        fi
}

#@help _stage_import_dir2
# @command stage import dir <stage> <reldir>
# @summary Act terminal: mkdir and mode of the record directory through the stage/<name> symlink (the link IS the resolution)
# @group   stage
# @internal
# @see     stage import
#@end
_stage_import_dir2() {
        printf '%s\n' "$MODIFY_DIR_CREATE '$ELEBAKE_BASE/stage/$1/$2'"
        printf '%s\n' "$MODIFY_FILE_PERMS 0700 '$ELEBAKE_BASE/stage/$1/$2'"
}

#@help _stage_import_file3
# @command stage import file <stage> <subdir> <absfile>
# @summary Act terminal: rm -f and cp -Pp of the element into the subdir (idempotent: a bare cp would write THROUGH an existing symlink target; -P keeps a link a link, -p mode and time). The record root is '.', built without that component. Replaying a dump against its OWN database makes source and destination the same file: nothing to do is the honest answer (the rm would eat the element)
# @group   stage
# @internal
# @see     stage import
#@end
_stage_import_file3() {
        local dir="$ELEBAKE_BASE/stage/$1/$2" dst=""
        test "$2" != . && test "$2" != ./ || dir="$ELEBAKE_BASE/stage/$1"
        dst="$dir/${3##*/}"
        if test "$3" = "$dst"; then
                emit_note "stage import '$1' '$2': ${3##*/} is already this element"
        else
                printf '%s\n' "rm -f '$dst' && cp -Pp '$3' '$dir/' || { printf '# Error: import of %s failed\\n' '$3' >&2; exit 1; }"
        fi
}

#@help __stage_collect1
# @internal arity-1 sibling of 'stage collect' (stage collect <stage>): The stage exists: rewrite to 'stage collect files <stage>', else an error line
#@end
__stage_collect1() {
        if test -L "$ELEBAKE_BASE/stage/$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage collect files '$1'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage collect: unknown stage $1'"
        fi
}

#@help _stage_collect_files1
# @command stage collect files <stage>
# @summary Text terminal: the record's own files by their REAL path (an archive is plain file storage; unpacking through the name symlink is impossible), written against "$ELEBAKE_ARCHIVE_BASE": the single records, then every file under marker, backup, boot, phases, prereqs, baselines, conf, hooks, media, the name symlink LAST (its target must exist before the link). work/ is left out on purpose -- it points at a worktree outside the database, which 'stage checkout' re-creates
# @group   stage
# @internal
# @see     stage collect
#@end
_stage_collect_files1() {
        local d="" part="" f=""
        d="$ELEBAKE_BASE/.staging/$(basename "$(readlink "$ELEBAKE_BASE/stage/$1")")"
        printf '# stage %s\n' "$1"
        for part in metadata filter checkout sign-key attest-key disks; do
                test -f "$d/$part" || test -L "$d/$part" || continue
                printf '"$ELEBAKE_ARCHIVE_BASE"/%s\n' "${d#"$ELEBAKE_BASE/"}/$part"
        done
        for part in marker backup boot phases prereqs baselines conf hooks media; do
                test -d "$d/$part" || continue
                find "$d/$part" \( -type f -o -type l \) 2>/dev/null | sort | sed "s|^$ELEBAKE_BASE/|\"\$ELEBAKE_ARCHIVE_BASE\"/|"
        done
        printf '"$ELEBAKE_ARCHIVE_BASE"/%s\n' "stage/$1"
}

#@help ___stage_collect0
# @command stage collect [<stage>]
# @summary Fan out to every stage: one 'stage collect <stage>' per name symlink; none is a comment line
# @group   stage
# @see     collect
#@end
___stage_collect0() {
        local l="" n=0
        for l in "$ELEBAKE_BASE"/stage/*; do
                test -L "$l" || continue
                n=$((n + 1))
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage collect '${l##*/}'"
        done
        test "${n:-0}" -gt 0 || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'no stages to collect'"
}

#@help ___stage_adopt2
# @command stage adopt <stage> <medium>
# @summary One-time adoption of a RUNNING boot tree: copies the medium's WHOLE boot/ (cp -a, existing files in the stage's boot/ are overwritten) into the stage -- boot/ becomes the single source of truth, configuration (loader.conf & Co.) included. A batch: pool import (read-only), adopt copy, pool export -- the export runs even when the copy failed (keep-going wrapper), so the pool never stays imported. Compiled parts the medium brings (kernel, loader, lua, defaults) are replaced by the stage's own build the next time 'stage include' runs, so adopt BEFORE include or run include again after it; 'stage filter orphaned' then lists what the medium brought that nothing curates -- the owner decides about each such file
# @group   stage
# @param   medium  a registered medium with its boot tree bound (stage device, stage boot tree)
# @example elebake stage adopt daily-v1 a
# @see     stage adopt copy
# @see     stage include
# @see     stage filter orphaned
#@end
___stage_adopt2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage pool import '$1' '$2' ro"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage adopt copy '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage pool export '$1' '$2'"
}

#@help ___stage_tree_work2
# @command stage tree work <stage> <medium>
# @summary The fail-fast core of 'stage tree sync': snapshot, copy, verify (its pin forces ELEBAKE_BATCH_KEEP_GOING=0 so a failing step stops HERE, while the enclosing sync keeps going into close and export)
# @group   deploy
# @internal
# @see     stage tree sync
#@end
___stage_tree_work2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tree snapshot '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tree copy '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tree verify '$1' '$2'"
}

#@help ___stage_tree_sync2
# @command stage tree sync <stage> <medium>
# @summary Write the stage's boot/ tree onto the medium's dataset: pool import, then snapshot + copy + verify (fail-fast), then close (rollback if the tree is not the manifest) and pool export -- close and export ALWAYS run (keep-going wrapper), so a failed sync never leaves the pool imported or the medium half-written
# @group   deploy
# @example elebake stage tree sync daily-v1 a
# @see     stage tree work
# @see     stage tree close
# @see     stage deploy
#@end
___stage_tree_sync2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage pool import '$1' '$2' rw"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tree work '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tree close '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage pool export '$1' '$2'"
}

#@help ___stage_medium_ready2
# @command stage medium ready <stage> <medium>
# @summary The preconditions of every act on a medium's boot tree, checked at generation: the stage exists, the medium is registered, its boot tree is bound, the device node is present, the GPT label is there
# @group   deploy
# @internal
# @see     stage pool import
# @see     stage tree sync
# @see     stage adopt
#@end
___stage_medium_ready2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage medium exists '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage boot tree exists '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage medium present '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage medium labeled '$1' '$2'"
}

#@help __stage_medium_exists2
# @command stage medium exists <stage> <medium>
# @summary The medium is registered (media/<medium>/node): a comment line, else an error line
# @group   deploy
# @internal
# @see     stage device
#@end
__stage_medium_exists2() {
        if test -f "$ELEBAKE_BASE/stage/$1/media/$2/node"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'medium $2 of stage $1 registered'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage $1: unknown medium $2 (stage device $1 $2 /dev/<node>)'"
        fi
}

#@help __stage_boot_tree_exists2
# @command stage boot tree exists <stage> <medium>
# @summary The medium's boot tree is bound (media/<medium>/gptlabel and dataset): a comment line, else an error line
# @group   deploy
# @internal
# @see     stage boot tree
#@end
__stage_boot_tree_exists2() {
        if test -f "$ELEBAKE_BASE/stage/$1/media/$2/gptlabel" && test -f "$ELEBAKE_BASE/stage/$1/media/$2/dataset"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'boot tree of medium $2 bound'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage $1: no boot tree registered for medium $2 (stage boot tree $1 $2 <gpt-label> <pool/dataset>)'"
        fi
}

#@help __stage_medium_present2
# @command stage medium present <stage> <medium>
# @summary The medium's device node is a character device right now: a comment line, else an error line (insert the medium)
# @group   deploy
# @internal
# @see     stage medium ready
#@end
__stage_medium_present2() {
        if test -c "$(head -n1 "$ELEBAKE_BASE/stage/$1/media/$2/node" 2>/dev/null)"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'medium $2 present at $(head -n1 "$ELEBAKE_BASE/stage/$1/media/$2/node" 2>/dev/null)'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage $1: device not present: $(head -n1 "$ELEBAKE_BASE/stage/$1/media/$2/node" 2>/dev/null) (insert medium $2 -- checked at generation time)'"
        fi
}

#@help __stage_medium_labeled2
# @command stage medium labeled <stage> <medium>
# @summary The bound GPT label exists as /dev/gpt/<label>: a comment line, else an error line (wrong medium?)
# @group   deploy
# @internal
# @see     stage medium ready
#@end
__stage_medium_labeled2() {
        if test -c "/dev/gpt/$(head -n1 "$ELEBAKE_BASE/stage/$1/media/$2/gptlabel" 2>/dev/null)"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'gpt label $(head -n1 "$ELEBAKE_BASE/stage/$1/media/$2/gptlabel" 2>/dev/null) present'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage $1: no such gpt label: /dev/gpt/$(head -n1 "$ELEBAKE_BASE/stage/$1/media/$2/gptlabel" 2>/dev/null) (wrong medium $2?)'"
        fi
}

#@help ___stage_pool_import3
# @command stage pool import <stage> <medium> <rw|ro>
# @summary Import the medium's pool from its GPT label (confined: no device scan), rooted under $ELEBAKE_ROOT/mnt/<stage>-<medium>, and mount the boot dataset: the medium ready, the mode rw or ro, the pool not imported yet; then 'stage pool mount'
# @group   deploy
# @param   rw|ro  writable (tree sync) or read-only (adopt)
# @example elebake stage pool import daily-v1 a rw
# @see     stage pool export
# @see     stage tree sync
# @see     stage adopt
#@end
___stage_pool_import3() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage pool mode valid '$3'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage medium ready '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage pool exported '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage pool mount '$1' '$2' '$3'"
}

#@help __stage_pool_mode_valid1
# @command stage pool mode valid <mode>
# @summary The mode is rw or ro: a comment line, else an error line
# @group   deploy
# @internal
# @see     stage pool import
#@end
__stage_pool_mode_valid1() {
        if test "$1" = rw || test "$1" = ro; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'pool mode $1'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage pool import: mode must be rw or ro, got $1'"
        fi
}

#@help __stage_pool_exported2
# @command stage pool exported <stage> <medium>
# @summary The medium's pool is not imported right now: a comment line, else an error line
# @group   deploy
# @internal
# @see     stage pool import
#@end
__stage_pool_exported2() {
        if ! pool_imported "$(sed -n 1p "$ELEBAKE_BASE/stage/$1/media/$2/dataset" 2>/dev/null | cut -d/ -f1)"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'pool $(sed -n 1p "$ELEBAKE_BASE/stage/$1/media/$2/dataset" 2>/dev/null | cut -d/ -f1) not imported'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage pool import $1: pool $(sed -n 1p "$ELEBAKE_BASE/stage/$1/media/$2/dataset" 2>/dev/null | cut -d/ -f1) is already imported (stage pool export $1 $2, or zpool export)'"
        fi
}

#@help _stage_pool_mount3
# @command stage pool mount <stage> <medium> <rw|ro>
# @summary Act terminal: the altroot directory, zpool import from /dev/gpt/<label> (readonly for ro) rooted there, zfs mount of pool and boot dataset; run as root
# @group   deploy
# @internal
# @see     stage pool import
#@end
_stage_pool_mount3() {
        local label="" ds="" pool="" alt="" ro=""
        label=$(head -n1 "$ELEBAKE_BASE/stage/$1/media/$2/gptlabel" 2>/dev/null)
        ds=$(head -n1 "$ELEBAKE_BASE/stage/$1/media/$2/dataset" 2>/dev/null)
        pool=${ds%%/*}
        alt="$ELEBAKE_ROOT/mnt/$1-$2"
        test "$3" != ro || ro="-o readonly=on "
        emit_note "elebake stage pool import '$1' medium '$2' ($pool from /dev/gpt/$label, $3, altroot $alt)"
        printf '%s\n' "$MODIFY_DIR_CREATE '$alt'"
        printf '%s\n' "zpool import -d '/dev/gpt/$label' ${ro}-R '$alt' -N '$pool' || { printf '# Error: cannot import pool %s from /dev/gpt/%s\\n' '$pool' '$label' >&2; exit 1; }"
        printf '%s\n' "zfs mount '$pool' 2>/dev/null; zfs mount '$ds' || { zpool export '$pool'; printf '# Error: cannot mount %s\\n' '$ds' >&2; exit 1; }"
        printf '%s\n' "printf '# pool %s imported (%s), %s mounted\\n' '$pool' '$3' '$ds' >&2"
}

#@help ___stage_pool_export2
# @command stage pool export <stage> <medium>
# @summary Unmount and export the medium's pool and remove the altroot: the medium ready, then 'stage pool release' (a pool that is not imported is a note, not an error, so the closing line of a batch is always safe). Its pin forces fail-fast inside, whatever the enclosing batch keeps going
# @group   deploy
# @example elebake stage pool export daily-v1 a
# @see     stage pool import
# @see     stage tree sync
#@end
___stage_pool_export2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage medium ready '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage pool release '$1' '$2'"
}

#@help __stage_pool_release2
# @command stage pool release <stage> <medium>
# @summary The pool is imported: rewrite to 'stage pool unmount', else a note line (nothing to do)
# @group   deploy
# @internal
# @see     stage pool export
#@end
__stage_pool_release2() {
        if pool_imported "$(sed -n 1p "$ELEBAKE_BASE/stage/$1/media/$2/dataset" 2>/dev/null | cut -d/ -f1)"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage pool unmount '$1' '$2'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" note 'stage pool export $1: pool $(sed -n 1p "$ELEBAKE_BASE/stage/$1/media/$2/dataset" 2>/dev/null | cut -d/ -f1) is not imported -- nothing to do'"
        fi
}

#@help _stage_pool_unmount2
# @command stage pool unmount <stage> <medium>
# @summary Act terminal: zfs umount of dataset and pool, zpool export in five bounded attempts (a fresh pool can be transiently busy), the altroot removed; run as root
# @group   deploy
# @internal
# @see     stage pool export
#@end
_stage_pool_unmount2() {
        local ds="" pool="" alt=""
        ds=$(head -n1 "$ELEBAKE_BASE/stage/$1/media/$2/dataset" 2>/dev/null)
        pool=${ds%%/*}
        alt="$ELEBAKE_ROOT/mnt/$1-$2"
        emit_note "elebake stage pool export '$1' medium '$2' ($pool)"
        printf '%s\n' "zfs umount '$ds' 2>/dev/null; zfs umount '$pool' 2>/dev/null"
        printf '%s\n' "zpool export '$pool' 2>/dev/null || { sleep 1; zpool export '$pool' 2>/dev/null; } || { sleep 1; zpool export '$pool' 2>/dev/null; } || { sleep 1; zpool export '$pool' 2>/dev/null; } || { sleep 1; zpool export '$pool'; } || { printf '# Error: pool %s still busy after 5 attempts -- export manually: zpool export %s\\n' '$pool' '$pool' >&2; exit 1; }"
        printf '%s\n' "rmdir '$alt' 2>/dev/null || true"
        printf '%s\n' "printf '# pool %s exported\\n' '$pool' >&2"
}

#@help ___stage_tree_snapshot2
# @command stage tree snapshot <stage> <medium>
# @summary Snapshot the medium's boot dataset (elebake-<stamp>) before it is rewritten: the medium ready, the pool imported; then 'stage tree snap'
# @group   deploy
# @see     stage tree sync
#@end
___stage_tree_snapshot2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage medium ready '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage pool imported '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tree snap '$1' '$2'"
}

#@help __stage_pool_imported2
# @command stage pool imported <stage> <medium>
# @summary The medium's pool is imported: a comment line, else an error line (stage pool import first)
# @group   deploy
# @internal
# @see     stage pool import
#@end
__stage_pool_imported2() {
        if pool_imported "$(sed -n 1p "$ELEBAKE_BASE/stage/$1/media/$2/dataset" 2>/dev/null | cut -d/ -f1)"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'pool $(sed -n 1p "$ELEBAKE_BASE/stage/$1/media/$2/dataset" 2>/dev/null | cut -d/ -f1) imported'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage $1: pool $(sed -n 1p "$ELEBAKE_BASE/stage/$1/media/$2/dataset" 2>/dev/null | cut -d/ -f1) is not imported (stage pool import $1 $2 rw first)'"
        fi
}

#@help _stage_tree_snap2
# @command stage tree snap <stage> <medium>
# @summary Act terminal: zfs snapshot <dataset>@elebake-<UTC stamp>; run as root
# @group   deploy
# @internal
# @see     stage tree snapshot
#@end
_stage_tree_snap2() {
        local snap=""
        snap="$(head -n1 "$ELEBAKE_BASE/stage/$1/media/$2/dataset" 2>/dev/null)@elebake-$(date -u '+%Y%m%dT%H%M%SZ')"
        emit_note "elebake stage tree snapshot '$1' medium '$2' ($snap)"
        printf '%s\n' "zfs snapshot '$snap' || { printf '# Error: cannot snapshot %s\\n' '$snap' >&2; exit 1; }"
}

#@help ___stage_tree_copy2
# @command stage tree copy <stage> <medium>
# @summary Replace the boot/ tree on the MOUNTED dataset with the stage's boot/: the medium ready, the stage's manifest attested, the dataset mounted and a boot dataset; then 'stage tree write'
# @group   deploy
# @see     stage tree sync
# @see     stage manifest
# @see     stage attest
#@end
___stage_tree_copy2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage medium ready '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage manifest attested '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage dataset mounted '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage dataset boots '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tree write '$1' '$2'"
}

#@help __stage_manifest_attested1
# @command stage manifest attested <stage>
# @summary boot/manifest and boot/manifest.asc are there: a comment line, else an error line (stage manifest + stage attest first)
# @group   deploy
# @internal
# @see     stage manifest
# @see     stage attest
#@end
__stage_manifest_attested1() {
        if test -f "$ELEBAKE_BASE/stage/$1/boot/manifest" && test -f "$ELEBAKE_BASE/stage/$1/boot/manifest.asc"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'stage $1 manifest attested'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage $1: boot/manifest(.asc) missing (stage manifest + stage attest first)'"
        fi
}

#@help __stage_manifest_exists1
# @command stage manifest exists <stage>
# @summary boot/manifest is there: a comment line, else an error line (stage manifest first)
# @group   deploy
# @internal
# @see     stage manifest
#@end
__stage_manifest_exists1() {
        if test -f "$ELEBAKE_BASE/stage/$1/boot/manifest"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'stage $1 has a manifest'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage $1: no boot/manifest (stage manifest first)'"
        fi
}

#@help __stage_dataset_mounted2
# @command stage dataset mounted <stage> <medium>
# @summary The medium's boot dataset is mounted right now (a generation-time fact after stage pool import): a comment line, else an error line
# @group   deploy
# @internal
# @see     stage pool import
#@end
__stage_dataset_mounted2() {
        if pool_mountpoint "$(sed -n 1p "$ELEBAKE_BASE/stage/$1/media/$2/dataset" 2>/dev/null)" > /dev/null; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'dataset $(sed -n 1p "$ELEBAKE_BASE/stage/$1/media/$2/dataset" 2>/dev/null) mounted'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage $1: $(sed -n 1p "$ELEBAKE_BASE/stage/$1/media/$2/dataset" 2>/dev/null) is not mounted (stage pool import $1 $2 first)'"
        fi
}

#@help __stage_dataset_boots2
# @command stage dataset boots <stage> <medium>
# @summary The mounted dataset carries a boot/ directory: a comment line, else an error line (not a boot dataset?)
# @group   deploy
# @internal
# @see     stage dataset mounted
#@end
__stage_dataset_boots2() {
        if test -d "$(pool_mountpoint "$(sed -n 1p "$ELEBAKE_BASE/stage/$1/media/$2/dataset" 2>/dev/null)")/boot"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'dataset of medium $2 has boot/'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage $1: no boot/ under $(pool_mountpoint "$(sed -n 1p \"$ELEBAKE_BASE/stage/$1/media/$2/dataset\" 2>/dev/null)") -- not a boot dataset?'"
        fi
}

#@help _stage_tree_write2
# @command stage tree write <stage> <medium>
# @summary Act terminal: rm -rf, mkdir and cp -a of the stage's boot/ onto the mounted dataset's boot/; run as root
# @group   deploy
# @internal
# @see     stage tree copy
#@end
_stage_tree_write2() {
        local mp=""
        mp=$(pool_mountpoint "$(sed -n 1p "$ELEBAKE_BASE/stage/$1/media/$2/dataset" 2>/dev/null)")
        emit_note "elebake stage tree copy '$1' medium '$2' (boot/ -> $mp/boot)"
        printf '%s\n' "rm -rf '$mp/boot' && mkdir '$mp/boot' && cp -a '$ELEBAKE_BASE/stage/$1/boot/.' '$mp/boot/' || { printf '# Error: tree copy failed (stage tree close rolls back to the snapshot)\\n' >&2; exit 1; }"
        printf '%s\n' "printf '# tree copied to %s\\n' '$mp/boot' >&2"
}

#@help ___stage_tree_verify2
# @command stage tree verify <stage> <medium>
# @summary Inspect the boot tree ON the mounted medium against the stage's manifest at generation time, both directions: the medium ready, the manifest there, the dataset mounted; then 'stage tree matches' -- a finding fails the command
# @group   deploy
# @see     stage tree sync
# @see     stage verify
#@end
___stage_tree_verify2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage medium ready '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage manifest exists '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage dataset mounted '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tree matches '$1' '$2'"
}

#@help __stage_tree_matches2
# @command stage tree matches <stage> <medium>
# @summary Every manifest entry is on the medium with its hash and nothing unlisted is there: a log line, else an error line carrying the findings (MISSING, MISMATCH, UNLISTED)
# @group   deploy
# @internal
# @see     stage tree verify
#@end
__stage_tree_matches2() {
        local findings=""
        findings=$(boot_tree_findings "$(pool_mountpoint "$(sed -n 1p "$ELEBAKE_BASE/stage/$1/media/$2/dataset" 2>/dev/null)")/boot" "$ELEBAKE_BASE/stage/$1/boot/manifest")
        if test -z "$findings"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log 'stage tree verify $1: $(grep -c sha256= "$ELEBAKE_BASE/stage/$1/boot/manifest" 2>/dev/null) entries on medium $2 match the manifest, nothing unlisted'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage tree verify $1: the tree on medium $2 is not the manifest' $(sq "$(printf '%s' "$findings" | tr '\n' ';')")"
        fi
}

#@help ___stage_tree_close2
# @command stage tree close <stage> <medium>
# @summary Leave the medium consistent, decided at generation time: the medium ready, then 'stage tree settle' -- a tree that IS the manifest stays (snapshot kept as history), a tree that is not goes back to the newest elebake snapshot; not imported = nothing to do. Its pin forces fail-fast inside, whatever the enclosing batch keeps going
# @group   deploy
# @see     stage tree sync
#@end
___stage_tree_close2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage medium ready '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tree settle '$1' '$2'"
}

#@help __stage_tree_settle2
# @command stage tree settle <stage> <medium>
# @summary The pool is imported and the dataset mounted: rewrite to 'stage tree judge', else a note line (nothing to close)
# @group   deploy
# @internal
# @see     stage tree close
#@end
__stage_tree_settle2() {
        if pool_imported "$(sed -n 1p "$ELEBAKE_BASE/stage/$1/media/$2/dataset" 2>/dev/null | cut -d/ -f1)" && pool_mountpoint "$(sed -n 1p "$ELEBAKE_BASE/stage/$1/media/$2/dataset" 2>/dev/null)" > /dev/null; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tree judge '$1' '$2'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" note 'stage tree close $1: $(sed -n 1p "$ELEBAKE_BASE/stage/$1/media/$2/dataset" 2>/dev/null) is not imported or not mounted -- nothing to close'"
        fi
}

#@help __stage_tree_judge2
# @command stage tree judge <stage> <medium>
# @summary The tree on the medium IS the stage's manifest (no finding, manifest present): a note line (kept; the newest elebake snapshot stays as history), else rewrite to 'stage tree rollback'
# @group   deploy
# @internal
# @see     stage tree close
#@end
__stage_tree_judge2() {
        local findings=""
        findings=$(boot_tree_findings "$(pool_mountpoint "$(sed -n 1p "$ELEBAKE_BASE/stage/$1/media/$2/dataset" 2>/dev/null)")/boot" "$ELEBAKE_BASE/stage/$1/boot/manifest" 2>/dev/null)
        if test -f "$ELEBAKE_BASE/stage/$1/boot/manifest" && test -z "$findings"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" note 'stage tree close $1: tree on medium $2 is the manifest -- kept ($(tree_newest_snapshot "$(sed -n 1p \"$ELEBAKE_BASE/stage/$1/media/$2/dataset\" 2>/dev/null)" | sed "s/^$/no snapshot/") stays as history)'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tree rollback '$1' '$2'"
        fi
}

#@help __stage_tree_rollback2
# @command stage tree rollback <stage> <medium>
# @summary There is an elebake snapshot to go back to: rewrite to 'stage tree revert <stage> <medium> <snapshot>', else an error line (repair by hand)
# @group   deploy
# @internal
# @see     stage tree close
#@end
__stage_tree_rollback2() {
        if test -n "$(tree_newest_snapshot "$(sed -n 1p "$ELEBAKE_BASE/stage/$1/media/$2/dataset" 2>/dev/null)")"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tree revert '$1' '$2' '$(tree_newest_snapshot "$(sed -n 1p \"$ELEBAKE_BASE/stage/$1/media/$2/dataset\" 2>/dev/null)")'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage tree close $1: tree on medium $2 differs and there is no elebake snapshot to go back to' '(repair by hand: stage tree copy $1 $2, or restore the dataset)'"
        fi
}

#@help _stage_tree_revert3
# @command stage tree revert <stage> <medium> <snapshot>
# @summary Act terminal: the findings as comment lines, then zfs rollback to the snapshot; run as root
# @group   deploy
# @internal
# @see     stage tree close
#@end
_stage_tree_revert3() {
        emit_note "stage tree close '$1': tree on medium '$2' is NOT the manifest -- rolling back to $3"
        boot_tree_findings "$(pool_mountpoint "$(sed -n 1p "$ELEBAKE_BASE/stage/$1/media/$2/dataset" 2>/dev/null)")/boot" "$ELEBAKE_BASE/stage/$1/boot/manifest" 2>/dev/null | sed 's/^/# /'
        printf '%s\n' "zfs rollback '$3' || { printf '# Error: rollback to %s failed -- the medium is inconsistent, do not boot it\\n' '$3' >&2; exit 1; }"
        printf '%s\n' "printf '# rolled back %s to %s\\n' '$(sed -n 1p "$ELEBAKE_BASE/stage/$1/media/$2/dataset" 2>/dev/null)' '$3' >&2"
}

#@help ___stage_adopt_copy2
# @command stage adopt copy <stage> <medium>
# @summary The copy step of 'stage adopt': the medium ready, the dataset mounted (stage pool import ro first) and a boot dataset; then 'stage adopt take'
# @group   stage
# @internal
# @see     stage adopt
#@end
___stage_adopt_copy2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage medium ready '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage dataset mounted '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage dataset boots '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage adopt take '$1' '$2'"
}

#@help _stage_adopt_take2
# @command stage adopt take <stage> <medium>
# @summary Act terminal: cp -a of the mounted dataset's boot/ into the stage's boot/, ownership back to the operator, the adoption noted in the stage's metadata; the file count is a generation-time fact
# @group   stage
# @internal
# @see     stage adopt copy
#@end
_stage_adopt_take2() {
        local mp="" ds="" n=""
        ds=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/media/$2/dataset" 2>/dev/null)
        mp=$(pool_mountpoint "$ds")
        n=$(find "$mp/boot" -type f 2>/dev/null | wc -l | tr -d ' ')
        emit_note "elebake stage adopt '$1' (medium '$2': $n files from $ds at $mp/boot -> boot/)"
        printf '%s\n' "cp -a '$mp/boot/.' '$ELEBAKE_BASE/stage/$1/boot/' || { printf '# Error: copy failed\\n' >&2; exit 1; }"
        printf '%s\n' "chown -R '$(id -un)' '$ELEBAKE_BASE/stage/$1/boot' 2>/dev/null || true"
        printf '%s\n' "echo 'adopted=$ds via gpt/$(sed -n 1p "$ELEBAKE_BASE/stage/$1/media/$2/gptlabel" 2>/dev/null) (medium $2)' >> '$ELEBAKE_BASE/stage/$1/metadata'"
        printf '%s\n' "printf '# adopted %s files from %s into boot/ of stage %s\\n' '$n' '$ds' '$1' >&2"
}

#@help __stage_device3
# @internal arity-3 sibling of 'stage device': rewrites to the full command with the /mnt default materialized
#@end
__stage_device3() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage device '$1' '$2' '$3' /mnt"
}

#@help ___stage_device4
# @command stage device <stage> <medium> </dev/node> [<mountpoint>]
# @summary Register a NAMED deploy medium (its backups sort under backup/<medium>): the stage exists, the medium name and the device node are well-formed; then 'stage medium record'
# @group   deploy
# @param   medium  operator's name for the physical card/stick (e.g. a, b)
# @param   node    device node the medium appears as (e.g. /dev/da1p1)
# @example elebake stage device smoke1 a /dev/da1p1
# @see     stage boot tree
# @see     stage deploy
# @see     stage medium record
#@end
___stage_device4() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage medium name valid '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage device node valid '$3'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage medium record '$1' '$2' '$3' '$4'"
}

#@help __stage_medium_name_valid1
# @command stage medium name valid <medium>
# @summary The medium name is a record name ([A-Za-z0-9_.-]): a comment line, else an error line
# @group   deploy
# @internal
# @see     stage device
#@end
__stage_medium_name_valid1() {
        if medium_name_ok "$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'medium name $1 valid'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage device: invalid medium name $1 ([A-Za-z0-9_.-])'"
        fi
}

#@help __stage_device_node_valid1
# @command stage device node valid </dev/node>
# @summary The node lies below /dev: a comment line, else an error line
# @group   deploy
# @internal
# @see     stage device
#@end
__stage_device_node_valid1() {
        if device_node_ok "$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'device node $1 valid'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage device: not a device node: $1 (expected /dev/...)'"
        fi
}

#@help _stage_medium_record4
# @command stage medium record <stage> <medium> </dev/node> <mountpoint>
# @summary Act terminal: write the medium record media/<medium>/ (node, mountpoint, loaderpath = EFI/BOOT/BOOTX64.EFI; 0700/0600) and say so
# @group   deploy
# @internal
# @see     stage device
#@end
_stage_medium_record4() {
        printf '%s\n' "$MODIFY_DIR_CREATE '$ELEBAKE_BASE/stage/$1/media/$2'"
        printf '%s\n' "$MODIFY_FILE_PERMS 0700 '$ELEBAKE_BASE/stage/$1/media/$2'"
        printf '%s\n' "echo '$3' > '$ELEBAKE_BASE/stage/$1/media/$2/node'"
        printf '%s\n' "echo '$4' > '$ELEBAKE_BASE/stage/$1/media/$2/mountpoint'"
        printf '%s\n' "echo 'EFI/BOOT/BOOTX64.EFI' > '$ELEBAKE_BASE/stage/$1/media/$2/loaderpath'"
        printf '%s\n' "$MODIFY_FILE_PERMS 0600 '$ELEBAKE_BASE/stage/$1/media/$2/node' '$ELEBAKE_BASE/stage/$1/media/$2/mountpoint' '$ELEBAKE_BASE/stage/$1/media/$2/loaderpath'"
        printf '%s\n' "printf '# Registered medium %s: %s (mount %s) on stage %s\\n' '$2' '$3' '$4' '$1' >&2"
}

#@help ___stage_boot_tree4
# @command stage boot tree <stage> <medium> <gpt-label> <pool/dataset>
# @summary Register where the medium's boot tree lives (used by stage push/tree sync, adopt, pool import): the stage and the medium exist, the label and the dataset name are well-formed, the label -- when the medium is inserted -- names a freebsd-zfs partition of the medium's disk, never its EFI system partition; then 'stage boot tree record'
# @group   deploy
# @param   gpt-label     GPT label of the pool partition WITHOUT the gpt/ prefix (the tool addresses /dev/gpt/<label>); list the labels of the inserted medium with `ls /dev/gpt` or `gpart show -l daN`
# @param   pool/dataset  ZFS dataset carrying the boot/ tree (e.g. zkey/boot-illyria); the pool name: `zpool import` (as root, lists importable pools without importing), the dataset: `zfs list -r <pool>` after `stage pool import <stage> <medium> ro`
# @example elebake stage boot tree daily-v1 a zcard zcard/boot
# @see     stage device
# @see     stage pool import
# @see     stage tree sync
#@end
___stage_boot_tree4() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage medium exists '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage gpt label valid '$3'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage dataset name valid '$4'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage gpt label fits '$1' '$2' '$3'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage boot tree record '$1' '$2' '$3' '$4'"
}

#@help __stage_gpt_label_valid1
# @command stage gpt label valid <gpt-label>
# @summary The label is a GPT label without the gpt/ prefix ([A-Za-z0-9_.-]): a comment line, else an error line
# @group   deploy
# @internal
# @see     stage boot tree
#@end
__stage_gpt_label_valid1() {
        if gpt_label_ok "$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'gpt label $1 valid'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage boot tree: invalid gpt label $1'"
        fi
}

#@help __stage_dataset_name_valid1
# @command stage dataset name valid <pool/dataset>
# @summary The dataset is named below its pool (<pool>/<dataset>): a comment line, else an error line
# @group   deploy
# @internal
# @see     stage boot tree
#@end
__stage_dataset_name_valid1() {
        if dataset_name_ok "$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'dataset $1 valid'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage boot tree: expected <pool>/<dataset>, got $1'"
        fi
}

#@help __stage_gpt_label_fits3
# @command stage gpt label fits <stage> <medium> <gpt-label>
# @summary The World as it is (generation time): the medium's disk is absent (adopt and pool import check presence when they need it) or the label names one of ITS partitions of type freebsd-zfs: a comment line, else an error line (no such label, or the wrong partition -- the pool lives on a freebsd-zfs partition, never on the EFI system partition)
# @group   deploy
# @internal
# @see     stage boot tree
#@end
__stage_gpt_label_fits3() {
        local disk="" type=""
        disk=$(printf '%s' "$(head -n1 "$ELEBAKE_BASE/stage/$1/media/$2/node" 2>/dev/null)" | sed 's|^/dev/||; s/p[0-9]*$//')
        type=$(gpt_label_type "$disk" "$3")
        if test "$type" = "" && ! gpart list "$disk" > /dev/null 2>&1 || test "$type" = freebsd-zfs; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'gpt/$3 fits medium $2'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage boot tree: gpt/$3 on $disk is $(printf "%s" "${type:-no partition}" | sed "s/^no partition$/no partition labelled so/") -- the pool lives on a freebsd-zfs partition (ls /dev/gpt; gpart show -l $disk)'"
        fi
}

#@help _stage_boot_tree_record4
# @command stage boot tree record <stage> <medium> <gpt-label> <pool/dataset>
# @summary Act terminal: write gptlabel and dataset into the medium record (0600) and say so
# @group   deploy
# @internal
# @see     stage boot tree
#@end
_stage_boot_tree_record4() {
        printf '%s\n' "echo '$3' > '$ELEBAKE_BASE/stage/$1/media/$2/gptlabel'"
        printf '%s\n' "echo '$4' > '$ELEBAKE_BASE/stage/$1/media/$2/dataset'"
        printf '%s\n' "$MODIFY_FILE_PERMS 0600 '$ELEBAKE_BASE/stage/$1/media/$2/gptlabel' '$ELEBAKE_BASE/stage/$1/media/$2/dataset'"
        printf '%s\n' "printf '# Registered boot tree of medium %s: %s on gpt/%s (stage %s)\\n' '$2' '$4' '$3' '$1' >&2"
}

#@help __stage_backup2
# @internal arity-2 of 'stage backup': label and description defaulted -- the label is the UTC stamp; rewrites to the arity-3 form
#@end
__stage_backup2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage backup '$1' '$2' '$(date -u '+%Y%m%dT%H%M%SZ')'"
}

#@help __stage_backup3
# @internal arity-3 of 'stage backup': description defaulted -- names the medium, the stage and who took it; rewrites to the full command
#@end
__stage_backup3() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage backup '$1' '$2' '$3' $(sq "loader found on medium $2 of stage $1, backed up by $(id -un)@$(hostname)")"
}

#@help ___stage_backup4
# @command stage backup <stage> <medium> [<label> [<description>]]
# @summary Save the loader currently ON that medium as a backup RECORD backup/<medium>/<label>/ (loader.efi, description, sha256, created, source, by): the stage and the medium exist, the label is a record name and new (a label is unique per medium and immutable), the description given, the device present; then 'stage backup take'. Label defaults to the UTC stamp, description to medium/stage/user
# @group   deploy
# @param   label        record name, [A-Za-z0-9_.-], unique per medium (e.g. before-kernel-update)
# @param   description  free text a person needs later: WHY this backup exists
# @example elebake stage backup daily-v1 a before-kernel-update 'the loader that booted silently on 25.08.'
# @see     stage backup list
# @see     stage rollback
# @see     stage deploy
#@end
___stage_backup4() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage medium exists '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage backup label valid '$3'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage backup description given $(sq "$4")"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage backup new '$1' '$2' '$3'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage medium present '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage backup take '$1' '$2' '$3' $(sq "$4")"
}

#@help __stage_backup_label_valid1
# @command stage backup label valid <label>
# @summary The label is a record name ([A-Za-z0-9_.-]): a comment line, else an error line
# @group   deploy
# @internal
# @see     stage backup
#@end
__stage_backup_label_valid1() {
        if backup_label_ok "$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'backup label $1 valid'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage backup: invalid label $1 ([A-Za-z0-9_.-])'"
        fi
}

#@help __stage_backup_description_given1
# @command stage backup description given <description>
# @summary The description is not empty: a comment line, else an error line (say why this backup exists)
# @group   deploy
# @internal
# @see     stage backup
#@end
__stage_backup_description_given1() {
        if test -n "$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'backup description given'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage backup: empty description (say why this backup exists)'"
        fi
}

#@help __stage_backup_new3
# @command stage backup new <stage> <medium> <label>
# @summary No backup record of that label exists for the medium: a comment line, else an error line (immutable; choose another label)
# @group   deploy
# @internal
# @see     stage backup
# @see     stage backup list
#@end
__stage_backup_new3() {
        if test ! -e "$ELEBAKE_BASE/stage/$1/backup/$2/$3"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'backup label $3 new for medium $2'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage backup $1: backup $3 of medium $2 exists (immutable; choose another label)' '(stage backup list $1 $2)'"
        fi
}

#@help _stage_backup_take4
# @command stage backup take <stage> <medium> <label> <description>
# @summary Act terminal: mount the ESP read-only, copy the loader found there into the record with its sha256, description, created, source and by (0700/0600, owned by the operator), umount; run as root
# @group   deploy
# @internal
# @see     stage backup
#@end
_stage_backup_take4() {
        local node="" mnt="" rel="" rec=""
        node=$(head -n1 "$ELEBAKE_BASE/stage/$1/media/$2/node" 2>/dev/null); mnt=$(head -n1 "$ELEBAKE_BASE/stage/$1/media/$2/mountpoint" 2>/dev/null); rel=$(head -n1 "$ELEBAKE_BASE/stage/$1/media/$2/loaderpath" 2>/dev/null)
        rec="$ELEBAKE_BASE/stage/$1/backup/$2/$3"
        emit_note "elebake stage backup '$1' medium '$2' label '$3' ($node:$rel -> backup/$2/$3/)"
        printf '%s\n' "$MODIFY_DIR_CREATE '$ELEBAKE_BASE/stage/$1/backup/$2'"
        printf '%s\n' "mount -r -t msdosfs '$node' '$mnt' || { printf '# Error: mount failed -- already mounted or device busy? (mount | grep %s)\\n' '$node' >&2; exit 1; }"
        printf '%s\n' "test -f '$mnt/$rel' || { umount '$mnt'; printf '# Error: no loader on medium %s: %s\\n' '$2' '$rel' >&2; exit 1; }"
        printf '%s\n' "$MODIFY_DIR_CREATE '$rec' && $MODIFY_FILE_PERMS 0700 '$rec'"
        printf '%s\n' "cp -p '$mnt/$rel' '$rec/loader.efi' || { umount '$mnt' 2>/dev/null; printf '# Error: cannot copy %s into %s\\n' '$mnt/$rel' '$rec' >&2; exit 1; }"
        printf '%s\n' "sha256 -q '$rec/loader.efi' > '$rec/sha256'"
        printf '%s\n' "printf '%s\\n' $(sq "$4") > '$rec/description'"
        printf '%s\n' "printf '%s\\n' '$(date -u '+%Y-%m-%dT%H:%M:%SZ')' > '$rec/created'"
        printf '%s\n' "printf '%s\\n' '$node:$rel' > '$rec/source'"
        printf '%s\n' "printf '%s\\n' '$(id -un)@$(hostname)' > '$rec/by'"
        printf '%s\n' "$MODIFY_FILE_PERMS 0600 '$rec'/*"
        printf '%s\n' "chown -R '$(id -un)' '$rec' 2>/dev/null || true"
        printf '%s\n' "umount '$mnt'"
        printf '%s\n' "chown '$(id -un)' '$ELEBAKE_BASE/stage/$1/backup/$2' 2>/dev/null || true"
        printf '%s\n' "printf '# backed up %s (%s) -> backup/%s/%s/ (sha256 %s)\\n' '$rel' '$2' '$2' '$3' \"\$(cat '$rec/sha256')\" >&2"
}

#@help ___stage_backup_list2
# @command stage backup list <stage> <medium>
# @summary Show the backup records of that medium, oldest first (label, created, sha256, description -- the view for a rollback decision): the stage and the medium exist; then 'stage backup table'
# @group   deploy
# @example elebake stage backup list daily-v1 a
# @see     stage backup
# @see     stage rollback
#@end
___stage_backup_list2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage medium exists '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage backup table '$1' '$2'"
}

#@help _stage_backup_table2
# @command stage backup table <stage> <medium>
# @summary Text terminal: the backup records of the medium as a table, oldest first; none is said so
# @group   deploy
# @internal
# @see     stage backup list
#@end
_stage_backup_table2() {
        local r="" created="" label=""
        printf '# backups of medium %s (%s) on stage %s -- oldest first\n' "$2" "$(head -n1 "$ELEBAKE_BASE/stage/$1/media/$2/node" 2>/dev/null)" "$1"
        printf '# %-24s %-20s %-12s %s\n' label created sha256 description
        for r in "$ELEBAKE_BASE/stage/$1/backup/$2"/*/; do
                test -f "$r/loader.efi" || continue
                printf '%s\t%s\n' "$(head -n1 "$r/created" 2>/dev/null)" "$(basename "$r")"
        done | sort | while IFS='	' read -r created label; do
                printf '#   %-24s %-20s %-12s %s\n' "$label" "$created" "$(head -n1 "$ELEBAKE_BASE/stage/$1/backup/$2/$label/sha256" 2>/dev/null | cut -c1-12)" "$(head -n1 "$ELEBAKE_BASE/stage/$1/backup/$2/$label/description" 2>/dev/null)"
        done
        test -n "$(ls "$ELEBAKE_BASE/stage/$1/backup/$2" 2>/dev/null)" || printf '#   (no backups -- stage backup %s %s, or stage deploy)\n' "$1" "$2"
}

#@help ___stage_rollback3
# @command stage rollback <stage> <medium> [<label>]
# @summary Put a backup back onto the medium -- but FIRST save what is on the medium now as record suspect-<stamp> (quietly: the loader about to be overwritten may be the evidence), then write the named (or newest) backup and verify its hash on the medium
# @group   deploy
# @param   label  a backup record of that medium (stage backup list); absent = the newest
# @example elebake stage rollback daily-v1 a known-good
# @see     stage backup list
# @see     stage rollback apply
#@end
___stage_rollback3() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage backup '$1' '$2' 'suspect-$(date -u '+%Y%m%dT%H%M%SZ')' $(sq "loader found on medium $2 before rollback to '$3' -- keep for analysis")"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rollback apply '$1' '$2' '$3'"
}

#@help __stage_rollback2
# @internal arity-2 sibling of 'stage rollback' (stage rollback <stage> <medium>): The newest backup record of the medium (by its created field) exists: rewrite to 'stage rollback <stage> <medium> <newest>', else an error line (no backups, or no such stage)
#@end
__stage_rollback2() {
        local newest=""
        newest=$(backup_newest "$1" "$2")
        if test -n "$newest"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rollback '$1' '$2' '$newest'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage rollback $1: no backups for medium $2 (stage backup / stage deploy first)'"
        fi
}

#@help ___stage_rollback_apply3
# @command stage rollback apply <stage> <medium> <label>
# @summary The write of 'stage rollback': the stage and the medium exist, the label is a record name, the record exists and is intact (its loader.efi matches its recorded sha256 -- a rollback must never put a corrupted reserve on the medium), the device present; then 'stage rollback write'
# @group   deploy
# @internal
# @see     stage rollback
#@end
___stage_rollback_apply3() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage medium exists '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage backup label valid '$3'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage backup record exists '$1' '$2' '$3'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage backup record intact '$1' '$2' '$3'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage medium present '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rollback write '$1' '$2' '$3'"
}

#@help __stage_backup_record_exists3
# @command stage backup record exists <stage> <medium> <label>
# @summary The backup record carries a loader.efi: a comment line, else an error line
# @group   deploy
# @internal
# @see     stage rollback apply
# @see     stage backup list
#@end
__stage_backup_record_exists3() {
        if test -f "$ELEBAKE_BASE/stage/$1/backup/$2/$3/loader.efi"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'backup record $3 of medium $2 exists'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage rollback $1: no such backup record for medium $2: $3' '(stage backup list $1 $2)'"
        fi
}

#@help __stage_backup_record_intact3
# @command stage backup record intact <stage> <medium> <label>
# @summary The record's loader.efi hashes to its recorded sha256: a comment line, else an error line (CORRUPT -- the reserve is not trustworthy)
# @group   deploy
# @internal
# @see     stage rollback apply
#@end
__stage_backup_record_intact3() {
        if test "$(sha256 -q "$ELEBAKE_BASE/stage/$1/backup/$2/$3/loader.efi" 2>/dev/null)" = "$(head -n1 "$ELEBAKE_BASE/stage/$1/backup/$2/$3/sha256" 2>/dev/null)"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'backup record $3 intact'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage rollback $1: backup record $3 is CORRUPT -- its loader.efi does not match its recorded sha256' '(the reserve is not trustworthy; choose another backup)'"
        fi
}

#@help _stage_rollback_write3
# @command stage rollback write <stage> <medium> <label>
# @summary Act terminal: mount the ESP, copy the record's loader.efi onto it, verify its sha256 in place (computed now, baked in), umount, sync; run as root
# @group   deploy
# @internal
# @see     stage rollback apply
#@end
_stage_rollback_write3() {
        local node="" mnt="" rel="" want="" bak="$ELEBAKE_BASE/stage/$1/backup/$2/$3/loader.efi"
        node=$(head -n1 "$ELEBAKE_BASE/stage/$1/media/$2/node" 2>/dev/null); mnt=$(head -n1 "$ELEBAKE_BASE/stage/$1/media/$2/mountpoint" 2>/dev/null); rel=$(head -n1 "$ELEBAKE_BASE/stage/$1/media/$2/loaderpath" 2>/dev/null)
        want=$(sha256 -q "$bak" 2>/dev/null)
        emit_note "elebake stage rollback '$1' medium '$2' ($node:$rel <- backup/$2/$3/loader.efi, sha256 $want)"
        emit_note "  $(head -n1 "$ELEBAKE_BASE/stage/$1/backup/$2/$3/description" 2>/dev/null) (created $(head -n1 "$ELEBAKE_BASE/stage/$1/backup/$2/$3/created" 2>/dev/null))"
        printf '%s\n' "mount -t msdosfs '$node' '$mnt' || { printf '# Error: mount failed -- already mounted or device busy? (mount | grep %s)\\n' '$node' >&2; exit 1; }"
        printf '%s\n' "cp '$bak' '$mnt/$rel'"
        printf '%s\n' "[ \"\$(sha256 -q '$mnt/$rel')\" = '$want' ] || { printf '# Error: hash mismatch after rollback (medium left mounted at %s)\\n' '$mnt' >&2; exit 1; }"
        printf '%s\n' "umount '$mnt'"
        printf '%s\n' "sync"
        printf '%s\n' "printf '# rolled back medium %s (%s:%s) from backup/%s/%s/ (sha256 %s)\\n' '$2' '$node' '$rel' '$2' '$3' '$want' >&2"
}

#@help ___stage_deploy2
# @command stage deploy <stage> <medium>
# @summary The loader swap onto the NAMED medium: the stage and the medium exist, the device is present, the signed loader is there and newer than the built one; then 'stage deploy write' (mount, backup record of what is there, copy, hash check, umount)
# @group   deploy
# @param   medium  which registered medium is inserted -- the operator's claim
# @example elebake stage deploy daily-v1 a
# @see     stage push
# @see     stage backup
# @see     stage rollback
#@end
___stage_deploy2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage medium exists '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage medium present '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage loader signed '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage deploy write '$1' '$2'"
}

#@help __stage_loader_signed1
# @command stage loader signed <stage>
# @summary boot/loader.efi.signed is there and newer than boot/loader.efi: a comment line, else an error line (stage sign first)
# @group   deploy
# @internal
# @see     stage sign
# @see     stage deploy
#@end
__stage_loader_signed1() {
        if test -f "$ELEBAKE_BASE/stage/$1/boot/loader.efi.signed" && test "$ELEBAKE_BASE/stage/$1/boot/loader.efi.signed" -nt "$ELEBAKE_BASE/stage/$1/boot/loader.efi"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'stage $1 loader signed'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage deploy $1: signed loader missing or stale (stage sign $1 first)'"
        fi
}

#@help _stage_deploy_write2
# @command stage deploy write <stage> <medium>
# @summary Act terminal: mount the ESP, save the loader found there as the backup record pre-deploy-<stamp> (the same record 'stage backup' writes, labelled by the act that displaced it), copy the signed loader, verify its sha256 in place (the expected hash is computed now and baked in, so the trace shows which loader is meant to land), umount, sync; run as root
# @group   deploy
# @internal
# @see     stage deploy
#@end
_stage_deploy_write2() {
        local src="$ELEBAKE_BASE/stage/$1/boot/loader.efi.signed" want="" label="" rec="" node="" mnt="" rel=""
        node=$(head -n1 "$ELEBAKE_BASE/stage/$1/media/$2/node" 2>/dev/null); mnt=$(head -n1 "$ELEBAKE_BASE/stage/$1/media/$2/mountpoint" 2>/dev/null); rel=$(head -n1 "$ELEBAKE_BASE/stage/$1/media/$2/loaderpath" 2>/dev/null)
        want=$(sha256 -q "$src" 2>/dev/null)
        label="pre-deploy-$(date -u '+%Y%m%dT%H%M%SZ')"
        rec="$ELEBAKE_BASE/stage/$1/backup/$2/$label"
        emit_note "elebake stage deploy '$1' medium '$2' ($node:$rel <- boot/loader.efi.signed, sha256 $want)"
        printf '%s\n' "$MODIFY_DIR_CREATE '$ELEBAKE_BASE/stage/$1/backup/$2'"
        printf '%s\n' "mount -t msdosfs '$node' '$mnt' || { printf '# Error: mount failed -- already mounted or device busy? (mount | grep %s)\\n' '$node' >&2; exit 1; }"
        printf '%s\n' "if [ -f '$mnt/$rel' ]; then"
        printf '%s\n' "$MODIFY_DIR_CREATE '$rec' && $MODIFY_FILE_PERMS 0700 '$rec'"
        printf '%s\n' "cp -p '$mnt/$rel' '$rec/loader.efi' || { umount '$mnt' 2>/dev/null; printf '# Error: cannot copy %s into %s\\n' '$mnt/$rel' '$rec' >&2; exit 1; }"
        printf '%s\n' "sha256 -q '$rec/loader.efi' > '$rec/sha256'"
        printf '%s\n' "printf '%s\\n' $(sq "loader found on medium $2 before deploy of stage $1 (incoming sha256 $want)") > '$rec/description'"
        printf '%s\n' "printf '%s\\n' '$(date -u '+%Y-%m-%dT%H:%M:%SZ')' > '$rec/created'"
        printf '%s\n' "printf '%s\\n' '$node:$rel' > '$rec/source'"
        printf '%s\n' "printf '%s\\n' '$(id -un)@$(hostname)' > '$rec/by'"
        printf '%s\n' "$MODIFY_FILE_PERMS 0600 '$rec'/*"
        printf '%s\n' "chown -R '$(id -un)' '$rec' 2>/dev/null || true"
        printf '%s\n' "printf '# backed up %s (%s) -> backup/%s/%s/\\n' '$rel' '$2' '$2' '$label' >&2"
        printf '%s\n' "else printf '# note: no existing loader on medium %s to back up\\n' '$2' >&2; fi"
        printf '%s\n' "cp '$src' '$mnt/$rel'"
        printf '%s\n' "[ \"\$(sha256 -q '$mnt/$rel')\" = '$want' ] || { printf '# Error: hash mismatch after deploy (medium left mounted at %s)\\n' '$mnt' >&2; exit 1; }"
        printf '%s\n' "umount '$mnt'"
        printf '%s\n' "sync"
        printf '%s\n' "chown '$(id -un)' '$ELEBAKE_BASE/stage/$1/backup/$2' 2>/dev/null || true"
        printf '%s\n' "printf '# deployed signed loader to medium %s (%s:%s, sha256 %s)\\n' '$2' '$node' '$rel' '$want' >&2"
}

#@help ___stage_push2
# @command stage push <stage> <medium>
# @summary Publish the stage: manifest, attest, verify, tree onto the medium, loader onto the ESP
# @group   stage
# @example elebake stage push daily-v1 a
# @see     stage tree sync
# @see     stage deploy
#@end
___stage_push2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage manifest '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage attest '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage verify '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tree sync '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage deploy '$1' '$2'"
}

# pool_mountpoint <dataset> -- prints the mountpoint when the dataset is mounted right now

pool_mountpoint() {
        local mp=""
        test "$(zfs get -H -o value mounted "$1" 2>/dev/null)" = yes || return 1
        mp=$(zfs get -H -o value mountpoint "$1" 2>/dev/null)
        test -n "$mp" && test "$mp" != - && test "$mp" != legacy && printf '%s\n' "$mp"
}

#@help ___stage_marker_record3
# @command stage marker record <stage> <BootXXXX> <filepath>
# @summary Record which load option carries the marker and where its value file lives (bookkeeping only -- no NVRAM): the stage exists, the load option and the absolute path are well-formed; then 'stage marker store'
# @group   provisioning
# @example elebake stage marker record daily-v1 Boot0003 /root/marker-daily-v1
# @see     stage marker
# @see     stage marker write
#@end
___stage_marker_record3() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage marker bootvar valid '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage marker file absolute '$3'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage marker store '$1' '$2' '$3'"
}

#@help __stage_marker_bootvar_valid1
# @command stage marker bootvar valid <BootXXXX>
# @summary The name is an EFI load option (Boot + four hex digits): a comment line, else an error line
# @group   provisioning
# @internal
# @see     stage marker record
#@end
__stage_marker_bootvar_valid1() {
        if bootvar_ok "$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'load option $1 valid'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage marker: not a load option: $1 (BootXXXX; rotation is stage marker rotate)'"
        fi
}

#@help __stage_marker_file_absolute1
# @command stage marker file absolute <filepath>
# @summary The value file path is absolute: a comment line, else an error line
# @group   provisioning
# @internal
# @see     stage marker record
#@end
__stage_marker_file_absolute1() {
        if test "${1#/}" != "$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'marker file $1 absolute'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage marker record: markerfile must be absolute: $1'"
        fi
}

#@help _stage_marker_store3
# @command stage marker store <stage> <BootXXXX> <filepath>
# @summary Act terminal: write marker/bootvar and marker/file (0700/0600, owned by the operator) and make sure backup/ exists
# @group   provisioning
# @internal
# @see     stage marker record
#@end
_stage_marker_store3() {
        emit_note "elebake stage marker record '$1' ($2, value file $3)"
        printf '%s\n' "$MODIFY_DIR_CREATE '$ELEBAKE_BASE/stage/$1/marker' '$ELEBAKE_BASE/stage/$1/backup'"
        printf '%s\n' "echo '$2' > '$ELEBAKE_BASE/stage/$1/marker/bootvar'"
        printf '%s\n' "echo '$3' > '$ELEBAKE_BASE/stage/$1/marker/file'"
        printf '%s\n' "$MODIFY_FILE_PERMS 0700 '$ELEBAKE_BASE/stage/$1/marker'; $MODIFY_FILE_PERMS 0600 '$ELEBAKE_BASE/stage/$1/marker/bootvar' '$ELEBAKE_BASE/stage/$1/marker/file'; chown '$(id -un)' '$ELEBAKE_BASE/stage/$1/marker' '$ELEBAKE_BASE/stage/$1/marker/bootvar' '$ELEBAKE_BASE/stage/$1/marker/file' 2>/dev/null || true"
}

#@help __stage_marker_write2
# @command stage marker write <stage> <restore|new>
# @summary Write the marker into the recorded load option: 'restore' puts the value from the recorded file back (or generates one when the file is empty -- decided at generation time), 'new' always generates. The marker is recorded: rewrite to 'stage marker value <restore|new> <stage>', else an error line
# @group   provisioning
# @example elebake stage marker write daily-v1 restore | sudo sh
# @see     stage marker value restore
# @see     stage marker value new
# @see     stage marker rotate
#@end
__stage_marker_write2() {
        if test -f "$ELEBAKE_BASE/stage/$1/marker/bootvar" && test -f "$ELEBAKE_BASE/stage/$1/marker/file"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage marker value '$2' '$1'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage marker write $1: nothing recorded (stage marker record $1 BootXXXX <filepath> first)'"
        fi
}

#@help __stage_marker_value_restore1
# @command stage marker value restore <stage>
# @summary The recorded value file holds a value: rewrite to 'stage marker nvram <stage> keep', else to 'stage marker nvram <stage> empty' (a new value is generated into the empty file)
# @group   provisioning
# @internal
# @see     stage marker write
#@end
__stage_marker_value_restore1() {
        if test -s "$(head -n1 "$ELEBAKE_BASE/stage/$1/marker/file" 2>/dev/null)"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage marker nvram '$1' keep"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage marker nvram '$1' empty"
        fi
}

#@help __stage_marker_value_new1
# @command stage marker value new <stage>
# @summary A new value, always: rewrite to 'stage marker nvram <stage> new'
# @group   provisioning
# @internal
# @see     stage marker write
#@end
__stage_marker_value_new1() {
        if true; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage marker nvram '$1' new"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage marker nvram '$1' new"
        fi
}

#@help __stage_marker_value2
# @internal fallback of 'stage marker value': an unknown mode word is an error line
#@end
__stage_marker_value2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage marker write: expected restore or new, got $1'"
}

#@help _stage_marker_nvram2
# @command stage marker nvram <stage> <keep|empty|new>
# @summary Act terminal: the NVRAM byte surgery -- read the load option, parse the EFI_LOAD_OPTION offset at RUNTIME (the entry is read and rewritten in the same privileged execution; the marker VALUE never appears in a trace), keep the original once under backup/, take the value from the file (keep) or generate one into it (empty: the file was empty; new: a rotation), append 'RC <value>' NUL and write the option back. Pinned to cat -- inspect, then pipe to sudo sh
# @group   provisioning
# @internal
# @see     stage marker write
#@end
_stage_marker_nvram2() {
        local bootvar="" mfile=""
        bootvar=$(head -n1 "$ELEBAKE_BASE/stage/$1/marker/bootvar" 2>/dev/null)
        mfile=$(head -n1 "$ELEBAKE_BASE/stage/$1/marker/file" 2>/dev/null)
        emit_note "elebake stage marker write '$1' ($bootvar$(test "$2" = keep || printf ', NEW value: %s' "$2"))"
        printf '%s\n' "g=8be4df61-93ca-11d2-aa0d-00e098032b8c; v='$bootvar'"
        printf '%s\n' "t=\$(mktemp) || exit 1"
        printf '%s\n' "efivar --no-name --name \"\$g-\$v\" --binary > \"\$t\" 2>/dev/null || { printf '# Error: cannot read %s (root? entry present?)\\n' \"\$v\" >&2; exit 1; }"
        printf '%s\n' "size=\$(wc -c < \"\$t\" | tr -d ' ')"
        printf '%s\n' "[ \"\$size\" -gt 8 ] || { printf '# Error: %s too short for an EFI_LOAD_OPTION\\n' \"\$v\" >&2; exit 1; }"
        printf '%s\n' "fplen=\$(od -An -tu1 -j4 -N2 \"\$t\" | awk '{print \$1 + \$2*256}')"
        printf '%s\n' "desclen=\$(od -An -tu1 -j6 \"\$t\" | awk '{for (i = 1; i <= NF; i++) v[n++] = \$i} END {for (k = 0; k + 1 < n; k += 2) if (v[k] == 0 && v[k+1] == 0) {print k + 2; exit}}')"
        printf '%s\n' "off=\$((6 + desclen + fplen))"
        printf '%s\n' "{ [ -n \"\$fplen\" ] && [ -n \"\$desclen\" ] && [ \"\$off\" -gt 0 ] && [ \"\$off\" -le \"\$size\" ]; } || { printf '# Error: %s does not parse as an EFI_LOAD_OPTION\\n' \"\$v\" >&2; exit 1; }"
        printf '%s\n' "[ -f '$ELEBAKE_BASE/stage/$1/backup/$bootvar.orig' ] || cp \"\$t\" '$ELEBAKE_BASE/stage/$1/backup/$bootvar.orig'"
        if test "$2" != keep; then
                printf '%s\n' "m=\$(openssl rand -hex 16) || { printf '# Error: openssl rand failed\\n' >&2; exit 1; }"
                printf '%s\n' "( umask 077; printf '%s\\n' \"\$m\" > '$mfile' ) || { printf '# Error: cannot write %s\\n' '$mfile' >&2; exit 1; }"
                printf '%s\n' "printf '# new marker generated and saved to %s\\n' '$mfile' >&2"
        else
                printf '%s\n' "m=\$(cat '$mfile')"
                printf '%s\n' "printf '# restoring the known marker from %s\\n' '$mfile' >&2"
        fi
        printf '%s\n' "new=\$(mktemp) || exit 1"
        printf '%s\n' "dd if=\"\$t\" of=\"\$new\" bs=1 count=\"\$off\" 2>/dev/null"
        printf '%s\n' "printf 'RC %s' \"\$m\" >> \"\$new\""
        printf '%s\n' "dd if=/dev/zero bs=1 count=1 2>/dev/null >> \"\$new\""
        printf '%s\n' "efivar --write --name \"\$g-\$v\" < \"\$new\" || { printf '# Error: writing %s failed -- restore with: efivar --write --name %s < %s\\n' \"\$v\" \"\$g-\$v\" '$ELEBAKE_BASE/stage/$1/backup/$bootvar.orig' >&2; exit 1; }"
        printf '%s\n' "rm -f \"\$t\" \"\$new\""
        printf '%s\n' "printf '# marker written to %s; sha256 %s\\n' \"\$v\" \"\$(printf '%s' \"\$m\" | sha256 -q)\" >&2"
        printf '%s\n' "printf '# %s is %s bytes now (header, path, RC, token, NUL)\\n' \"\$v\" \"\$(efivar --no-name --name \"\$g-\$v\" --binary 2>/dev/null | wc -c | tr -d ' ')\" >&2"
        printf '%s\n' "printf '# NOTE: the firmware rewrites this entry when another medium boots; restore with: stage marker $1 $bootvar\\n' >&2"
}

#@help __stage_marker2
# @internal arity-2 sibling of 'stage marker' (stage marker <stage> <BootXXXX>): The value file is recorded: rewrite to the full command with the RECORDED value file, else an error line
#@end
__stage_marker2() {
        if test -f "$ELEBAKE_BASE/stage/$1/marker/file"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage marker '$1' '$2' '$(head -n1 "$ELEBAKE_BASE/stage/$1/marker/file" 2>/dev/null)'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage marker $1: no value file recorded (stage marker $1 BootXXXX <filepath>)'"
        fi
}

#@help ___stage_marker3
# @command stage marker <stage> <BootXXXX> [<filepath>]
# @summary Write the boot-entry marker into that load option: a batch of two -- the RECORD (bootvar + value-file path, bookkeeping, acts) and the WRITE (NVRAM byte surgery, inspect-by-default -- pipe the output to sudo sh). The value comes from the file, or is generated when the file is empty
# @group   provisioning
# @param   BootXXXX  the load option the marker lives in
# @param   filepath  root-only file holding the marker value; optional once recorded
# @example elebake stage marker daily-v1 Boot0003 /root/marker-daily-v1
# @see     stage marker record
# @see     stage marker write
# @see     stage marker rotate
#@end
___stage_marker3() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage marker record '$1' '$2' '$3'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage marker write '$1' restore"
}

#@help __stage_marker_rotate1
# @command stage marker rotate <stage>
# @summary Rotate the marker: a NEW value into the recorded load option and value file. The marker is recorded: rewrite to 'stage marker write <stage> new' (inspect-by-default, pipe to sudo sh), else an error line
# @group   provisioning
# @example elebake stage marker rotate daily-v1 | sudo sh
# @see     stage marker write
#@end
__stage_marker_rotate1() {
        if test -f "$ELEBAKE_BASE/stage/$1/marker/bootvar"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage marker write '$1' new"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage marker rotate $1: nothing recorded (stage marker $1 BootXXXX <filepath> first)'"
        fi
}

#@help ___stage_site_mk1
# @command stage site mk <stage>
# @summary Write local/site.mk of the stage's checkout: the stage and its checkout exist; the header, then the measured parts (board, keys, marker, origin, disks) and the baselines appended in file order to site.mk.new; the install (rendered, clean, placed) and the report. Run under sudo: the key store, the marker and the origin are EFI variables
# @group   provisioning
# @example sudo sh elebake.sh stage site mk daily-v1
# @see     stage site mk report
# @see     stage baseline add
# @see     stage disks add
#@end
___stage_site_mk1() {
        local f="$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local/site.mk"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage checkout exists '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage site mk header '$1' > '$f.new'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage site mk board '$1' >> '$f.new'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage site mk keys '$1' >> '$f.new'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage site mk marker '$1' >> '$f.new'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage site mk origin '$1' >> '$f.new'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage site mk disks '$1' >> '$f.new'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage site mk baselines '$1' >> '$f.new'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage site mk install '$1' '$f'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage site mk report '$1' '$f'"
}

#@help _stage_site_mk_header1
# @command stage site mk header <stage>
# @summary Print the header of site.mk: what it is, that it is not source, how the Makefile pulls it in
# @group   provisioning
# @internal
# @see     stage site mk
#@end
_stage_site_mk_header1() {
        printf '%s\n' "# Generated by elebake -- this machine trust expectations."
        printf '%s\n' "# Not tracked in git: the values are site fingerprints, not source."
        printf '%s\n' "# Pulled in by stand/efi/loader/Makefile via .-include local/site.mk."
}

#@help _stage_site_mk_board1
# @command stage site mk board <stage>
# @summary Act terminal: the script that takes the board identity from the smbios kenv (system uuid, planar serial, system serial -- the first that is no vendor placeholder per template/tbl/board-placeholders.tbl), hashes it, compares it with what the loader published (loader.trust.bootlock.board.sha256) and prints the LOADER_TRUST_BOARD_DIGEST line; no identity or a disagreement fails
# @group   provisioning
# @internal
# @env     ELEBAKE_TEMPLATE_DIR  the template directory (the placeholder table)
# @see     stage site mk
#@end
_stage_site_mk_board1() {
        cat <<EOF
id=''; for k in smbios.system.uuid smbios.planar.serial smbios.system.serial; do v=\$(kenv "\$k" 2>/dev/null) || continue; printf '%s\\n' "\$v" | grep -qxF -f '$ELEBAKE_TEMPLATE_DIR/tbl/board-placeholders.tbl' && continue; id=\$v; break; done
test -n "\$id" || { printf '# Error: %s\\n' "stage site mk $1: no usable board identity in smbios (can this context read kenv?)" >&2; exit 1; }
hb=\$(printf '%s' "\$id" | sha256 -q); meas=\$(kenv loader.trust.bootlock.board.sha256 2>/dev/null)
test -z "\$meas" || test "\$meas" = "\$hb" || { printf '# Error: %s\\n' "stage site mk $1: board hash disagrees: loader \$meas vs here \$hb" >&2; exit 1; }
printf "CFLAGS.foundation.c += -DLOADER_TRUST_BOARD_DIGEST='%s'\\n" "\$(printf '%s' "\$hb" | sed 's/\\(..\\)/0x\\1,/g; s/,\$//')"
EOF
}

#@help _stage_site_mk_keys1
# @command stage site mk keys <stage>
# @summary Act terminal: the script that reads PK, KEK and db (efivar, needs root), hashes them in that order, compares with what the loader published (loader.trust.bootlock.keys.sha256) and prints the LOADER_TRUST_KEYS_DIGEST line; unreadable variables or a disagreement fail
# @group   provisioning
# @internal
# @see     stage site mk
#@end
_stage_site_mk_keys1() {
        cat <<EOF
kt=\$(mktemp -d) || exit 1
efivar --no-name --name '8be4df61-93ca-11d2-aa0d-00e098032b8c-PK' --binary > "\$kt/1" 2>/dev/null && efivar --no-name --name '8be4df61-93ca-11d2-aa0d-00e098032b8c-KEK' --binary > "\$kt/2" 2>/dev/null && efivar --no-name --name 'd719b2cb-3d3a-4596-a3bc-dad00e67656f-db' --binary > "\$kt/3" 2>/dev/null && test -s "\$kt/1" && test -s "\$kt/2" && test -s "\$kt/3" || { rm -rf "\$kt"; printf '# Error: %s\\n' "stage site mk $1: cannot read PK/KEK/db (run the batch in a context that can, e.g. sudo)" >&2; exit 1; }
hk=\$(cat "\$kt/1" "\$kt/2" "\$kt/3" | sha256 -q); rm -rf "\$kt"; meas=\$(kenv loader.trust.bootlock.keys.sha256 2>/dev/null)
test -z "\$meas" || test "\$meas" = "\$hk" || { printf '# Error: %s\\n' "stage site mk $1: key store hash disagrees: loader \$meas vs here \$hk" >&2; exit 1; }
printf "CFLAGS.foundation.c += -DLOADER_TRUST_KEYS_DIGEST='%s'\\n" "\$(printf '%s' "\$hk" | sed 's/\\(..\\)/0x\\1,/g; s/,\$//')"
EOF
}

#@help __stage_site_mk_marker1
# @command stage site mk marker <stage>
# @summary A boot marker is bound (marker/bootvar): rewrite to 'stage site mk marker measure <stage> <bootvar>', else a note -- BootMarker stays asleep (stage marker, then re-run site mk)
# @group   provisioning
# @internal
# @see     stage site mk
#@end
__stage_site_mk_marker1() {
        if test -f "$ELEBAKE_BASE/stage/$1/marker/bootvar"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage site mk marker measure '$1' '$(sed -n 1p "$ELEBAKE_BASE/stage/$1/marker/bootvar")'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" note 'site mk $1: no boot marker bound -- BootMarker stays asleep (stage marker, then re-run site mk)'"
        fi
}

#@help _stage_site_mk_marker_measure2
# @command stage site mk marker measure <stage> <bootvar>
# @summary Act terminal: the script that reads the Boot#### variable (efivar, needs root), finds its optional data (template/awk/optdata-offset.awk over the header), takes the marker as the last word, hashes it (only the hash ever reaches the trace) and prints the two LOADER_TRUST_MARKER_DIGEST lines; an unreadable or empty marker is a note on stderr, nothing on stdout
# @group   provisioning
# @internal
# @env     ELEBAKE_TEMPLATE_DIR  the template directory (the awk program)
# @see     stage site mk marker
#@end
_stage_site_mk_marker_measure2() {
        cat <<EOF
kt=\$(mktemp -d) || exit 1; hm=''
if efivar --no-name --name '8be4df61-93ca-11d2-aa0d-00e098032b8c-$2' --binary > "\$kt/opt" 2>/dev/null && off=\$(od -An -tu1 "\$kt/opt" | awk -f '$ELEBAKE_TEMPLATE_DIR/awk/optdata-offset.awk'); then opt=\$(dd if="\$kt/opt" bs=1 skip="\$off" 2>/dev/null | tr -d '\\000'); m=\${opt##* }; test -n "\$m" && test "\$m" != RC && hm=\$(printf '%s' "\$m" | sha256 -q); fi
rm -rf "\$kt"
test -n "\$hm" || { printf '%s\\n' "# site mk $1: boot marker $2 not readable -- BootMarker stays asleep" >&2; exit 0; }
printf "CFLAGS.foundation.c += -DLOADER_TRUST_MARKER_DIGEST='%s'\\n" "\$(printf '%s' "\$hm" | sed 's/\\(..\\)/0x\\1,/g; s/,\$//')"
printf "CFLAGS.measurement.c += -DLOADER_TRUST_MARKER_DIGEST='%s'\\n" "\$(printf '%s' "\$hm" | sed 's/\\(..\\)/0x\\1,/g; s/,\$//')"
EOF
}

#@help _stage_site_mk_origin1
# @command stage site mk origin <stage>
# @summary Act terminal: the script that reads the current boot entry (efibootmgr -v, needs root), takes the GPT partition it loads from, hashes it and prints the LOADER_TRUST_ORIGIN_DIGEST line; an unreadable origin is a note on stderr, nothing on stdout -- LoadOrigin stays asleep
# @group   provisioning
# @internal
# @see     stage site mk
#@end
_stage_site_mk_origin1() {
        cat <<EOF
ho=''; bootcur=\$(efibootmgr -v 2>/dev/null | sed -n 's/^ *BootCurrent: *//p' | head -1)
test -z "\$bootcur" || oline=\$(efibootmgr -v 2>/dev/null | grep -A3 "^[ +*]*Boot\${bootcur}[^0-9]" | grep -o 'GPT,[0-9a-fA-F-]*' | head -1)
test -z "\${oline:-}" || ho=\$(printf '%s' "\${oline#GPT,}" | tr 'A-F' 'a-f' | sha256 -q)
test -n "\$ho" || { printf '%s\\n' "# site mk $1: boot origin not readable (efibootmgr) -- LoadOrigin stays asleep" >&2; exit 0; }
printf "CFLAGS.foundation.c += -DLOADER_TRUST_ORIGIN_DIGEST='%s'\\n" "\$(printf '%s' "\$ho" | sed 's/\\(..\\)/0x\\1,/g; s/,\$//')"
EOF
}

#@help ___stage_site_mk_install2
# @command stage site mk install <stage> <file>
# @summary Install the rendered <file>.new as <file>, the last render line of the site mk batch: the render is complete (the key store line is there), it carries only comment and CFLAGS lines (a part that printed a command would poison make), then it is placed
# @group   provisioning
# @internal
# @see     stage site mk
#@end
___stage_site_mk_install2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage site mk rendered '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage site mk clean '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage site mk place '$1' '$2'"
}

#@help __stage_site_mk_rendered1
# @command stage site mk rendered <file>
# @summary The rendered <file>.new is there and carries the key store line: a comment line, else an error line
# @group   provisioning
# @internal
# @see     stage site mk install
#@end
__stage_site_mk_rendered1() {
        if test -s "$1.new" && grep -q "LOADER_TRUST_KEYS_DIGEST" "$1.new"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'site.mk render $1.new complete'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage site mk install: $1.new missing or incomplete (the site mk batch renders it)'"
        fi
}

#@help __stage_site_mk_clean1
# @command stage site mk clean <file>
# @summary Every line of <file>.new is a comment, a CFLAGS line or empty: a comment line, else an error line naming the first foreign line (a part printed a command, not data -- see its stderr)
# @group   provisioning
# @internal
# @see     stage site mk install
#@end
__stage_site_mk_clean1() {
        local bad=""
        bad=$(grep -v "^#" "$1.new" 2>/dev/null | grep -v "^CFLAGS" | grep -v "^$" | head -1)
        if test -z "$bad"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'site.mk render $1.new clean'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error $(sq "stage site mk install: $1.new carries a line that is neither comment nor CFLAGS (a part printed a command, not data -- see its stderr): $bad")"
        fi
}

#@help _stage_site_mk_place2
# @command stage site mk place <stage> <file>
# @summary Act terminal: move <file>.new to <file>, give it to the stage's owner (a sudo run must not leave root's file behind) and say so
# @group   provisioning
# @internal
# @see     stage site mk install
#@end
_stage_site_mk_place2() {
        local owner=""
        owner=$(stat -f %Su "$ELEBAKE_BASE/stage/$1/" 2>/dev/null)
        printf '%s\n' "mv '$2.new' '$2' && chown '${owner:-$(id -un)}' '$2' 2>/dev/null || true"
        printf '%s\n' "printf '# site.mk written for stage %s -- rebuild + sign + deploy to arm it\\n' '$1' >&2"
}

#@help ___stage_site_mk_report1
# @command stage site mk report <stage> [<file>]
# @summary Show the written site.mk of the stage (default: local/site.mk of its checkout) as comment lines
# @group   provisioning
# @example elebake stage site mk report daily-v1
# @see     stage site mk
#@end
___stage_site_mk_report1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage site mk report '$1' '$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local/site.mk'"
}

#@help ___stage_site_mk_report2
# @internal 2-arg sibling of 'stage site mk report': the file is there, then its lines
#@end
___stage_site_mk_report2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage site mk written '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage site mk print '$1' '$2'"
}

#@help __stage_site_mk_written2
# @command stage site mk written <stage> <file>
# @summary The site.mk is there: a comment line, else an error line
# @group   provisioning
# @internal
# @see     stage site mk report
#@end
__stage_site_mk_written2() {
        if test -f "$2"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'site.mk of $1 at $2'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage site mk report $1: no site.mk at $2 (stage site mk first)'"
        fi
}

#@help _stage_site_mk_print2
# @command stage site mk print <stage> <file>
# @summary Print the site.mk as comment lines under a heading
# @group   provisioning
# @internal
# @see     stage site mk report
#@end
_stage_site_mk_print2() {
        printf '# site.mk of stage %s (%s):\n' "$1" "$2"
        sed 's/^/# /' "$2"
}

#@help __stage_dump0
# @command stage dump [<strategy>] [<stage>|all]
# @summary The stage part of a dump: every stage in the complete vocabulary. The strategy selects the anchor that knows its blocks (dispatch): 'stage dump complete <stage>' is the full description, 'stage dump minimized <stage>' the rescue subset
# @group   stage
# @example elebake stage dump complete daily-v1
# @see     dump
# @see     stage dump complete
# @see     stage dump minimized
#@end
__stage_dump0() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage dump complete all"
}

#@help __stage_dump1
# @internal 1-arg sibling of 'stage dump': one stage (or all), complete
#@end
__stage_dump1() {
                    printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage dump complete '$1'"
}

#@help __stage_dump_complete0
# @internal 'stage dump complete' without a scope is every stage
#@end
__stage_dump_complete0() {
                    printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage dump complete all"
}

#@help __stage_dump_minimized0
# @internal 'stage dump minimized' without a scope is every stage
#@end
__stage_dump_minimized0() {
                    printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage dump minimized all"
}

#@help ___stage_dump_complete_all0
# @command stage dump complete all
# @summary One 'stage dump complete <stage>' per stage of the database; none is a dump comment (this batch runs, so its neutral element is text)
# @group   stage
# @internal
# @see     stage dump complete
#@end
___stage_dump_complete_all0() {
        local l="" n=0
        for l in "$ELEBAKE_BASE"/stage/*; do
                [ -L "$l" ] || continue
                n=$((n + 1))
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage dump complete '${l##*/}'"
        done
        test "${n:-0}" -gt 0 || printf '%s\n' "# (no stages to dump)"
}

#@help ___stage_dump_complete1
# @command stage dump complete <stage>
# @summary The complete dump of one stage, the full description: record (stage add + metadata), filter, keys, media, checkout, work, the bindings, prerequisites, baselines, disks, conf, hooks, marker, backups, every file of boot/, the idempotent rebuild lines
# @group   stage
# @internal
# @see     stage dump
#@end
___stage_dump_complete1() {
        printf '%s\n' "# stage '$1' (complete)"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage dump add '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage dump filter '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage dump keys '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage dump media '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage dump checkout '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage dump work '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage dump phases '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage dump prereqs '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage dump baselines '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage dump disks '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage dump conf '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage dump hooks '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage dump marker '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage dump backup '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage dump boot complete '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage dump rebuild '$1'"
}

#@help ___stage_dump_minimized_all0
# @command stage dump minimized all
# @summary One 'stage dump minimized <stage>' per stage of the database; none is a dump comment (this batch runs, so its neutral element is text)
# @group   stage
# @internal
# @see     stage dump minimized
#@end
___stage_dump_minimized_all0() {
        local l="" n=0
        for l in "$ELEBAKE_BASE"/stage/*; do
                [ -L "$l" ] || continue
                n=$((n + 1))
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage dump minimized '${l##*/}'"
        done
        test "${n:-0}" -gt 0 || printf '%s\n' "# (no stages to dump)"
}

#@help ___stage_dump_minimized1
# @command stage dump minimized <stage>
# @summary The minimized dump of one stage, the rescue subset: record, filter, keys, media, checkout, backups and the loader/kernel/loader.conf subset of boot/ -- no foundation, no worktree, no bindings, no rebuild
# @group   stage
# @internal
# @see     stage dump
#@end
___stage_dump_minimized1() {
        printf '%s\n' "# stage '$1' (minimized)"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage dump add '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage dump filter '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage dump keys '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage dump media '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage dump checkout '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage dump backup '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage dump boot minimized '$1'"
}

#@help __stage_dump2
# @internal arity-2 sibling of 'stage dump' (stage dump <strategy> <stage>|all): The total fallback behind the strategies (dispatch binds the longer name): an unknown strategy is an error line
#@end
__stage_dump2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage dump: unknown strategy $1 (complete | minimized)'"
}

#@help ___stage_dump_add1
# @command stage dump add <stage>
# @summary The record of the stage as replay: 'stage add' and the import of its metadata
# @group   stage
# @internal
# @see     stage dump
# @env     ELEBAKE_ARCHIVE_BASE  the prefix the emitted paths are written against
#@end
___stage_dump_add1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage add '$1'"
        test -e "$ELEBAKE_BASE/stage/$1/metadata" && printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage import '$1' '.' \"\$ELEBAKE_ARCHIVE_BASE/stage/$1/metadata\""
        test -e "$ELEBAKE_BASE/stage/$1/metadata" || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'stage $1 has no metadata yet'"
}

#@help ___stage_dump_boot_complete1
# @command stage dump boot complete <stage>
# @summary Every directory and every file of the stage's boot/ as import lines (directories first)
# @group   stage
# @internal
# @see     stage dump complete
# @env     ELEBAKE_ARCHIVE_BASE  the prefix the emitted paths are written against
#@end
___stage_dump_boot_complete1() {
        local f=""
        find "$ELEBAKE_BASE/stage/$1/boot" -type d 2>/dev/null | while IFS= read -r f; do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage import '$1' '${f#"$ELEBAKE_BASE/stage/$1/"}'"
        done
        find "$ELEBAKE_BASE/stage/$1/boot" \( -type f -o -type l \) 2>/dev/null | while IFS= read -r f; do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage import '$1' '$(dirname "${f#"$ELEBAKE_BASE/stage/$1/"}")' \"\$ELEBAKE_ARCHIVE_BASE/${f#"$ELEBAKE_BASE/"}\""
        done
}

#@help ___stage_dump_boot_minimized1
# @command stage dump boot minimized <stage>
# @summary The rescue subset of the stage's boot/: the directories boot and boot/kernel, then every file minimized_keep admits (loader, signed loader, loader.conf, manifest pair, the kernel modules), sorted
# @group   stage
# @internal
# @see     stage dump minimized
# @env     ELEBAKE_ARCHIVE_BASE  the prefix the emitted paths are written against
#@end
___stage_dump_boot_minimized1() {
        local dir="" f="" rel=""
        for dir in boot boot/kernel; do
                test -d "$ELEBAKE_BASE/stage/$1/$dir" && printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage import '$1' '$dir'"
        done
        find "$ELEBAKE_BASE/stage/$1/boot" \( -type f -o -type l \) 2>/dev/null | LC_ALL=C sort | while IFS= read -r f; do
                rel=${f#"$ELEBAKE_BASE/stage/$1/"}
                minimized_keep "$rel" || continue
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage import '$1' '$(dirname "$rel")' \"\$ELEBAKE_ARCHIVE_BASE/${f#"$ELEBAKE_BASE/"}\""
        done
}

#@help ___stage_dump_filter1
# @internal dump block (cat-pinned): one 'stage filter add' replay per curated entry; no filter is a comment line
#@end
___stage_dump_filter1() {
        local f="" n=0
        grep . "$ELEBAKE_BASE/stage/$1/filter" 2>/dev/null | while IFS= read -r f; do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage filter add '$1' $(sq "$f")"
        done
        n=$(grep -c . "$ELEBAKE_BASE/stage/$1/filter" 2>/dev/null)
        test "${n:-0}" -gt 0 || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'stage $1 has no filter'"
}

#@help ___stage_dump_keys1
# @internal dump block (cat-pinned): the sign-/attest-key bindings as replays (the link target is ../../<backend>/<key>); no binding is a comment line
#@end
___stage_dump_keys1() {
        local slot="" target="" n=0
        for slot in sign-key attest-key; do
                test -L "$ELEBAKE_BASE/stage/$1/$slot" || continue
                n=$((n + 1))
                target=$(readlink "$ELEBAKE_BASE/stage/$1/$slot")
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage $(printf '%s' "$slot" | tr '-' ' ') '$1' '$(basename "$(dirname "$target")")' '$(basename "$target")'"
        done
        test "${n:-0}" -gt 0 || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'stage $1 binds no key'"
}

#@help ___stage_dump_checkout1
# @internal dump block (cat-pinned): the checkout ref as base element; none is a comment line
#@end
___stage_dump_checkout1() {
        if test -f "$ELEBAKE_BASE/stage/$1/checkout" || test -L "$ELEBAKE_BASE/stage/$1/checkout"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage import '$1' '.' \"\$ELEBAKE_ARCHIVE_BASE/stage/$1/checkout\""
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'stage $1 has no checkout'"
        fi
}

#@help ___stage_dump_work1
# @internal dump block (cat-pinned): the work symlink as base element, with the re-anchor note as dump comments; none is a comment line
#@end
___stage_dump_work1() {
        if test -L "$ELEBAKE_BASE/stage/$1/work"; then
                printf '%s\n' "# work symlink still points into THIS source tree; re-anchor"
                printf '%s\n' "# later with: stage checkout $1 \$(cat checkout) (new worktree)"
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage import '$1' '.' \"\$ELEBAKE_ARCHIVE_BASE/stage/$1/work\""
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'stage $1 has no worktree'"
        fi
}

#@help ___stage_dump_phases1
# @internal dump block (cat-pinned): one check-free append replay per phase binding (the checks ran at the original binding; foundation check re-verifies before emission -- a dump must restore even when the worktree is gone); no binding is a comment line
#@end
___stage_dump_phases1() {
        local f="" p="" n=0
        for f in "$ELEBAKE_BASE/stage/$1"/phases/*; do
                test -f "$f" || continue
                grep . "$f" | while IFS= read -r p; do
                        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage phase policy append '$1' '${f##*/}' '$p'"
                done
        done
        n=$(cat "$ELEBAKE_BASE/stage/$1"/phases/* 2>/dev/null | grep -c .)
        test "${n:-0}" -gt 0 || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'stage $1 binds no policy'"
}

#@help ___stage_dump_prereqs1
# @internal dump block (cat-pinned): the per-stage prerequisites lists as idempotent adds; none is a comment line
#@end
___stage_dump_prereqs1() {
        local kind="" p="" n=0
        for kind in exist verify; do
                grep . "$ELEBAKE_BASE/stage/$1/prereqs/$kind" 2>/dev/null | while IFS= read -r p; do
                        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage prerequisites add '$1' '$kind' $(sq "$p")"
                done
        done
        n=$(cat "$ELEBAKE_BASE/stage/$1"/prereqs/* 2>/dev/null | grep -c .)
        test "${n:-0}" -gt 0 || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'stage $1 lists no prerequisites'"
}

#@help ___stage_dump_marker1
# @internal dump block (cat-pinned): the marker records as base elements (never a 'stage marker' replay -- that would write NVRAM); none is a comment line
#@end
___stage_dump_marker1() {
        local f="" n=0
        for f in "$ELEBAKE_BASE/stage/$1"/marker/*; do
                test -f "$f" || test -L "$f" || continue
                n=$((n + 1))
                test "$n" -gt 1 || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage import '$1' 'marker'"
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage import '$1' 'marker' \"\$ELEBAKE_ARCHIVE_BASE/${f#"$ELEBAKE_BASE/"}\""
        done
        test "${n:-0}" -gt 0 || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'stage $1 records no marker'"
}

#@help ___stage_dump_backup1
# @internal dump block (cat-pinned): the backup/ tree, STRUCTURE FIRST (every directory, find walks top-down so parents precede children), then one base element per file; none is a comment line
#@end
___stage_dump_backup1() {
        local f="" n=0
        find "$ELEBAKE_BASE/stage/$1/backup" -type d 2>/dev/null | while IFS= read -r f; do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage import '$1' '${f#"$ELEBAKE_BASE/stage/$1/"}'"
        done
        find "$ELEBAKE_BASE/stage/$1/backup" \( -type f -o -type l \) 2>/dev/null | while IFS= read -r f; do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage import '$1' '$(dirname "${f#"$ELEBAKE_BASE/stage/$1/"}")' \"\$ELEBAKE_ARCHIVE_BASE/${f#"$ELEBAKE_BASE/"}\""
        done
        n=$(find "$ELEBAKE_BASE/stage/$1/backup" -type d 2>/dev/null | wc -l | tr -d ' ')
        test "${n:-0}" -gt 0 || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'stage $1 has no backups'"
}

#@help ___stage_dump_rebuild1
# @internal dump block (cat-pinned): close the stage: idempotent regeneration of what the dump does not move (obj/ via build, destdir/ via install); pins and STAND_*_SUBDIRS arrive with the prologue; nothing built is a comment line
#@end
___stage_dump_rebuild1() {
        local n=0
        test -z "$(ls -A "$ELEBAKE_BASE/stage/$1/obj" 2>/dev/null)" || n=1
        test -z "$(ls -A "$ELEBAKE_BASE/stage/$1/destdir" 2>/dev/null)" || n=1
        test "$n" -eq 0 || printf '%s\n' "# rebuild of stage '$1' (artifacts are not moved)"
        test -z "$(ls -A "$ELEBAKE_BASE/stage/$1/obj" 2>/dev/null)" || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage build '$1'"
        test -z "$(ls -A "$ELEBAKE_BASE/stage/$1/destdir" 2>/dev/null)" || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage install '$1'"
        test "$n" -eq 1 || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'stage $1 has nothing built'"
}

#@help ___stage_dump_media1
# @internal dump block (cat-pinned): device and boot-tree replays per medium record
#@end
___stage_dump_media1() {
        local m="" d="$ELEBAKE_BASE/stage/$1"
        for m in "$d"/media/*/; do
                test -f "$m/node" || continue
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage device '$1' '$(basename "$m")' '$(head -n1 "$m/node")' '$(head -n1 "$m/mountpoint")'"
                test -f "$m/gptlabel" || continue
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage boot tree '$1' '$(basename "$m")' '$(head -n1 "$m/gptlabel")' '$(head -n1 "$m/dataset")'"
        done
}

