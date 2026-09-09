#!/bin/sh
#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Dr. Johannes Brügmann
# elebake predicate - the predicates of the generators, one file.
#
# A predicate answers one yes/no question about a NAME or VALUE at
# generation time and never prints; the combinator that asks it rewrites to
# the act terminal or to an error line. Nothing else is a helper: readers
# are lines in the anchor that reads, renderers are text terminals.

# fnd_name_ok <name> -- a record name of the arsenal
fnd_name_ok() {
        case "$1" in
                ""|.|..|*[!A-Za-z0-9_.-]*) return 1 ;;
        esac
        return 0
}

# fnd_c_ident_ok <name> -- names that land in the C output (gates) are C identifiers
fnd_c_ident_ok() {
        case "$1" in
                ""|[0-9]*|*[!A-Za-z0-9_]*) return 1 ;;
        esac
        return 0
}

# fnd_fields_ok <field>... -- fields land single-quoted in emitted shell and
# space-joined in record files: no single quotes
fnd_fields_ok() {
        case "$*" in
                *"'"*) return 1 ;;
        esac
        return 0
}

# fnd_macro_name_ok <NAME> -- a C macro stem
fnd_macro_name_ok() {
        case "$1" in
                ""|*[!A-Z0-9_]*|[0-9]*) return 1 ;;
        esac
        return 0
}

# baseline_macro_ok <MACRO> -- a C macro name in the loader's namespace
baseline_macro_ok() {
        case "$1" in
                LOADER_TRUST_[A-Z0-9_]*) return 0 ;;
        esac
        return 1
}

# baseline_type_ok <type> -- one of BASELINE_TYPES
baseline_type_ok() {
        case " ${BASELINE_TYPES:-digest string int} " in *" $1 "*) return 0 ;; esac
        return 1
}

# baseline_value_ok <type> <value> -- the value fits the type and survives
# both the record line and the make/-D rendering
baseline_value_ok() {
        case "$2" in *"'"*|*'"'*|*'\'*|*' '*|"") return 1 ;; esac
        case "$1" in
                digest) case "$2" in *[!0-9a-f]*) return 1 ;; esac
                        [ "${#2}" -eq 64 ] ;;
                int)    case "$2" in ""|*[!0-9]*) return 1 ;; esac ;;
                string) return 0 ;;
                *)      return 1 ;;
        esac
}

# disk_name_ok <device> -- a GPT partition of an internal disk (nda0p1)
disk_name_ok() {
        case "$1" in
                [a-z]*[0-9]p[1-9]|[a-z]*[0-9]p[1-9][0-9]) ;;
                *) return 1 ;;
        esac
        case "$1" in *[!a-z0-9]*) return 1 ;; esac
        return 0
}

# conf_key_ok <key> -- a loader.trust.* kenv name
conf_key_ok() {
        case "$1" in
                loader.trust.[a-z]*) ;;
                *) return 1 ;;
        esac
        case "$1" in *[!a-z0-9._]*) return 1 ;; esac
        return 0
}

# conf_value_ok <value> -- fits one loader.conf line, key="value"
conf_value_ok() {
        local nl
        nl=$(printf '\nx'); nl=${nl%x}
        case "$1" in *'"'*|*'\'*|*"$nl"*) return 1 ;; esac
        return 0
}

# container_ok <name> -- a container of ELEBAKE_CONTAINERS
container_ok() {
        case " ${ELEBAKE_CONTAINERS:-} " in *" $1 "*) return 0 ;; esac
        return 1
}

# prereq_kind_ok <kind> — exist | verify
prereq_kind_ok() { [ "$1" = "exist" ] || [ "$1" = "verify" ]; }

# prereq_path_ok <path> — absolute, no .., no quotes
prereq_path_ok() {
        case "$1" in
                /*) ;;
                *) return 1 ;;
        esac
        case "$1" in
                *..*|*"'"*) return 1 ;;
        esac
        return 0
}

stage_filter_rel_ok() {
        case "$1" in
                ""|/*|*..*|*"'"*) return 1 ;;
        esac
        return 0
}

# backup_label_ok <label> — a record name
backup_label_ok() {
        case "$1" in ""|*/*|.|..|*[!A-Za-z0-9_.-]*) return 1 ;; esac
        return 0
}


# filter_covers <flt> <entry> — is <entry> covered by the curation
# (listed itself, or living under a listed directory entry)?
filter_covers() {
        local flt="$1" e="$2" line
        [ -f "$flt" ] || return 1   # no curation yet: nothing is covered
        grep -qxF "$e" "$flt" 2>/dev/null && return 0
        while IFS= read -r line; do
                case "$e" in "$line"/*) return 0 ;; esac
        done < "$flt"
        return 1
}

# import_rel <path> [dot] — is <path> a valid record-relative path?
# ('.' only accepted with the dot flag: file targets may hit the record
# root, a directory declaration may not)
import_rel() {
        case "$1" in
                .) [ "${2:-}" = "dot" ] ;;
                ""|/*|*..*|*[!A-Za-z0-9_./-]*) return 1 ;;
                *) return 0 ;;
        esac
}

# pool_imported <pool> — is the pool imported right now?
pool_imported() {
        zpool list -H -o name "$1" >/dev/null 2>>"$LOG_FILE"
}

# minimized_keep <record-relative path> -- does a stage element belong to
# BINARY MANAGEMENT? The definition is template/filter/minimized.keep,
# matched by template/awk/filter.awk exactly as 'filter minimized' matches
# the collection; here the element is offered as .staging/_/<path>.
minimized_keep() {
        printf '%s\n' "\"\$ELEBAKE_ARCHIVE_BASE\"/.staging/_/$1" \
        | awk -v strategy=minimized -v drop=/dev/null -v keep="$ELEBAKE_TEMPLATE_DIR/filter/minimized.keep" -f "$ELEBAKE_TEMPLATE_DIR/awk/filter.awk" \
        | grep -qv '^#'
}

# dir_content_ok <path> <policy> -- may the directory hold what it holds?
# 'operational' allows content; anything else demands an empty directory
# (the exclusive hierarchy the database owns).
dir_content_ok() {
        test "$2" = operational || test -z "$(ls -A "$1" 2>/dev/null)"
}

# dir_exec_ok <path> <exec-flag> -- 'exec' demands a mount that runs scripts
# (a test script is written, run and removed here); 'noexec' asks nothing.
dir_exec_ok() {
        local probe="$1/.init_exec_test_$$"
        test "$2" != exec && return 0
        printf '#!/bin/sh\nexit 0\n' > "$probe" && chmod 0700 "$probe" && "$probe" 2>/dev/null
        local rc=$?
        rm -f "$probe"
        return $rc
}

# database_name_ok <name> -- a plain database name below ELEBAKE_ROOT: not
# empty, no slash, not the reserved 'db' (the active-DB symlink).
database_name_ok() {
        test -n "$1" && test "${1#*/}" = "$1" && test "$1" != db
}

# profile_ok <profile> -- the profile is shipped as
# template/environment/ELEBAKE_PROFILE_<PROFILE>.
profile_ok() {
        test -f "$ELEBAKE_TEMPLATE_DIR/environment/ELEBAKE_PROFILE_$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')"
}

# record_name_ok <name> -- a record name (stage, medium, backup label):
# [A-Za-z0-9_.-], not . or .. -- one rule for every name that becomes a path
record_name_ok() {
        test -n "$1" && test "$1" != . && test "$1" != .. && printf '%s\n' "$1" | grep -qx '[A-Za-z0-9_.-]*'
}
medium_name_ok() { record_name_ok "$1"; }
stage_name_ok() { record_name_ok "$1"; }

# device_node_ok <path> -- a device node path below /dev
device_node_ok() {
        test "${1#/dev/}" != "$1"
}

# gpt_label_ok <label> -- a GPT label without the gpt/ prefix: [A-Za-z0-9_.-]
gpt_label_ok() {
        test -n "$1" && printf '%s\n' "$1" | grep -qx '[A-Za-z0-9_.-]*'
}

# dataset_name_ok <pool/dataset> -- a ZFS dataset below a pool
dataset_name_ok() {
        test "${1#*/}" != "$1"
}

# bootvar_ok <BootXXXX> -- an EFI load option name
bootvar_ok() {
        printf '%s\n' "$1" | grep -qx 'Boot[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]'
}

# gpt_label_type <disk> <label> -- the partition type gpart reports for the
# labelled partition of the disk (empty: no such label, or the disk is absent)
gpt_label_type() {
        gpart list "$1" 2>/dev/null | awk -v l="$2" '
                /^[0-9]+\. Name:/ { lb = "" }
                /^ *label:/ { lb = $2 }
                /^ *type:/ { if (lb == l) print $2 }'
}

# backup_newest <stage> <medium> -- the label of the newest backup record of
# the medium (by its created field); empty when there is none
backup_newest() {
        local r=""
        for r in "$ELEBAKE_BASE/stage/$1/backup/$2"/*/; do
                test -f "$r/loader.efi" || continue
                printf '%s\t%s\n' "$(head -n1 "$r/created" 2>/dev/null)" "$(basename "$r")"
        done | sort | tail -n1 | cut -f2
}

# boot_generated <entry> -- a top-level entry of boot/ that a step of the
# stage generates (never curated, never pruned): the manifest pair, the
# loader's trust configuration, signed artifacts.
boot_generated() {
        test "$1" = manifest || test "$1" = manifest.asc || test "$1" = loader.trust.conf || test "${1%.signed}" != "$1"
}

# manifest_findings <bootdir> <manifest> [<kinds>] -- the findings of a boot
# tree against its manifest (MISSING, MISMATCH, UNLISTED), one per line,
# restricted to the space-separated kinds when given
manifest_findings() {
        test -f "$2" || return 0
        boot_tree_findings "$1" "$2" | grep -E "^(${3:-MISSING|MISMATCH|UNLISTED})" | sed 's/  */ /g' | tr ' ' '\t' | sed 's/\t/ /'
}

# tree_newest_snapshot -- inspection (moved from stage.sh; used by the tree and verify families)
tree_newest_snapshot() {
        zfs list -H -t snapshot -o name -s creation -r "$1" 2>/dev/null | grep '@elebake-' | tail -n1
}


# boot_tree_findings -- inspection (moved from stage.sh; used by the tree and verify families)
boot_tree_findings() {
        test -f "$2" || return 0
        local bootdir="$1" man="$2" rel hash have
        while read -r rel hash; do
                case "$hash" in sha256=*) ;; *) continue ;; esac
                if [ ! -f "$bootdir/$rel" ]; then printf 'MISSING  %s\n' "$rel"
                else
                        have="sha256=$(sha256 -q "$bootdir/$rel" 2>/dev/null)"
                        [ "$have" = "$hash" ] || printf 'MISMATCH %s\n' "$rel"
                fi
        done 2>/dev/null < "$man"
        { cd "$bootdir" 2>/dev/null && find . -type f ! -name manifest ! -name manifest.asc; } | sed 's|^\./||' | LC_ALL=C sort | while IFS= read -r rel; do
                cut -d' ' -f1 "$man" | grep -qxF -- "$rel" || printf 'UNLISTED %s\n' "$rel"
        done
}


# key_name_ok <name> -- a key record name (one rule with the other record names)
key_name_ok() { record_name_ok "$1"; }

# keyid_ok <keyid> -- an OpenPGP key id or fingerprint: 8, 16 or 40 hex digits
keyid_ok() {
        printf '%s\n' "$1" | grep -qxE '[0-9A-Fa-f]{8}|[0-9A-Fa-f]{16}|[0-9A-Fa-f]{40}'
}

# pkcs11_token_label -- the label of the first token the PKCS#11 module
# reports right now (empty when none answers)
pkcs11_token_label() {
        pkcs11-tool --module "${ELEBAKE_PKCS11_MODULE:-}" -L 2>/dev/null | sed -n 's/^.*token label[ :]*//p' | head -n1
}

# pkcs11_token_hint -- the staged diagnosis when no token answers: the
# PC/SC layer is asked layer by layer, configuration lore is mentioned only
# where the diagnosis points at it (check first, complain second)
pkcs11_token_hint() {
        if ! command -v pcscd > /dev/null 2>&1; then
                printf '%s\n' "pcsc-lite not installed (pkg install pcsc-lite libccid)"
        elif ! pgrep -q pcscd 2>/dev/null; then
                printf '%s\n' "pcscd not running (sysrc pcscd_enable=YES; service pcscd start)"
        elif usbconfig 2>/dev/null | grep -qi nitrokey; then
                printf '%s\n' "token visible on USB but not via PC/SC -- check pcscd_flags=--disable-polkit (sysrc -n pcscd_flags) and that libccid (not ccid) is installed"
        else
                printf '%s\n' "no token on USB (usbconfig) -- insert it"
        fi
}

# attest_signer <file> <keyid> [<gnupghome>] -- WHO signed, pinned. gpg
# --verify exits 0 for a mathematically good signature by ANY key in the
# keyring, expired and revoked ones included; the question is "did the key
# I expect sign this?", answered from gpg's status lines:
#   [GNUPG:] GOODSIG <longid> <uid>              good, key usable
#   [GNUPG:] EXPKEYSIG / REVKEYSIG / EXPSIG ...  good, but NOT acceptable
#   [GNUPG:] VALIDSIG <fpr> ... <primary-fpr>    the fingerprints
# Prints the signing fingerprint and returns 0 when a GOODSIG exists and one
# of the two VALIDSIG fingerprints ends in the pinned keyid; otherwise prints
# ONE reason line and returns 1. The pin is at least 16 hex digits -- a short
# id can be forged in minutes and is refused as a pin.
attest_signer() {
        local file="$1" pin="$2" gh="${3:-}" status fpr pfpr
        pin=$(printf '%s' "$pin" | sed 's/^0[xX]//' | tr 'a-f' 'A-F')
        case "$pin" in
                *[!0-9A-F]*|"") printf 'pinned keyid is not hexadecimal: %s\n' "$pin"; return 1 ;;
        esac
        [ ${#pin} -ge 16 ] || { printf 'pinned keyid too short (%s digits, need 16+): %s\n' "${#pin}" "$pin"; return 1; }
        [ -f "$file.asc" ] || { printf 'unsigned: no %s.asc\n' "$file"; return 1; }
        if [ -n "$gh" ]; then
                status=$(GNUPGHOME="$gh" gpg --batch --status-fd 1 --verify "$file.asc" "$file" 2>>"${LOG_FILE:-/dev/null}")
        else
                status=$(gpg --batch --status-fd 1 --verify "$file.asc" "$file" 2>>"${LOG_FILE:-/dev/null}")
        fi
        printf '%s\n' "$status" >>"${LOG_FILE:-/dev/null}"
        case "$status" in
                *"[GNUPG:] NO_PUBKEY"*) printf 'signer public key not in the keyring%s\n' "${gh:+ $gh}"; return 1 ;;
                *"[GNUPG:] BADSIG"*)    printf 'BAD SIGNATURE -- file or signature altered\n'; return 1 ;;
                *"[GNUPG:] REVKEYSIG"*) printf 'signed by a REVOKED key\n'; return 1 ;;
                *"[GNUPG:] EXPKEYSIG"*) printf 'signed by an EXPIRED key\n'; return 1 ;;
                *"[GNUPG:] EXPSIG"*)    printf 'signature itself has expired\n'; return 1 ;;
                *"[GNUPG:] GOODSIG"*)   ;;
                *) printf 'no good signature (see the log for gpg status)\n'; return 1 ;;
        esac
        fpr=$(printf '%s\n' "$status" | awk '/^\[GNUPG:\] VALIDSIG /{print $3; exit}')
        pfpr=$(printf '%s\n' "$status" | awk '/^\[GNUPG:\] VALIDSIG /{print $NF; exit}')
        case "$fpr" in *"$pin") printf '%s\n' "$fpr"; return 0 ;; esac
        case "$pfpr" in *"$pin") printf '%s\n' "$fpr"; return 0 ;; esac
        printf 'signed by a DIFFERENT key: %s (expected ...%s)\n' "$fpr" "$pin"
        return 1
}

# manifest_tree_findings <manifest> <base> -- the tree under <base> against
# the manifest, one finding per line (MISSING SYMLINK, RETARGETED, MISSING,
# CHANGED); nothing when every listed entry is present and identical. Files
# present but unlisted are not findings -- the base is an extraction directory
manifest_tree_findings() {
        local rel="" val="" have=""
        test -f "$1" || return 0
        while read -r rel val; do
                case "$val" in
                symlink=*)
                        test -L "$2/$rel" || printf 'MISSING SYMLINK %s\n' "$rel"
                        test ! -L "$2/$rel" || test "$(readlink "$2/$rel")" = "${val#symlink=}" || printf 'RETARGETED %s\n' "$rel"
                        ;;
                sha256=*)
                        test -f "$2/$rel" || printf 'MISSING %s\n' "$rel"
                        test ! -f "$2/$rel" || test "$(sha256 -q "$2/$rel" 2>/dev/null)" = "${val#sha256=}" || printf 'CHANGED %s\n' "$rel"
                        ;;
                esac
        done < "$1"
}

# collection_entry_bad <collection> -- the first entry of a collection that
# cannot be hashed (whitespace in the path, or neither file nor symlink under
# the database), with its reason; empty when every entry is hashable
collection_entry_bad() {
        local line="" rel=""
        grep -v '^#' "$1" 2>/dev/null | grep . | while IFS= read -r line; do
                rel=${line#\"\$ELEBAKE_ARCHIVE_BASE\"/}
                case "$rel" in *" "*|*"	"*) printf 'whitespace in path: %s\n' "$rel"; break ;; esac
                test -L "$ELEBAKE_BASE/$rel" || test -f "$ELEBAKE_BASE/$rel" || { printf 'neither file nor symlink: %s\n' "$rel"; break; }
        done | head -n1
}

serial_current() {
        local f="$ELEBAKE_BASE/export/serial" n
        [ -f "$f" ] && n=$(head -n1 "$f") || n=0
        case "$n" in ''|*[!0-9]*) n=0 ;; esac
        printf '%s\n' "$n"
}

serial_floor() {
        local fpr="$1" r s floor=0
        for r in "$ELEBAKE_BASE"/provenance/*/; do
                [ -f "$r/serial" ] && [ -f "$r/signer" ] || continue
                [ "$(head -n1 "$r/signer")" = "$fpr" ] || continue
                s=$(head -n1 "$r/serial")
                case "$s" in ''|*[!0-9]*) continue ;; esac
                [ "$s" -gt "$floor" ] && floor=$s
        done
        printf '%s\n' "$floor"
}

dump_header_field() {
        sed -n "s/^# $2: //p" "$1" | head -n1
}


# intp_var <token> -- the interpreter variable a setintp/getintp token names:
# a class default from template/tbl/intp.tbl, else the per-function pin
intp_var() {
        local var=""
        var=$(awk -v t="$(printf '%s' "$1" | tr 'A-Z' 'a-z')" '$1 == t { print $2 }' "$ELEBAKE_TEMPLATE_DIR/tbl/intp.tbl" 2>/dev/null)
        printf '%s\n' "${var:-ELEBAKE_INTERPRETER_$1}"
}

# env_var_resolve <name> -- the documented variable a 'help env' argument
# names, by the cascade literal -> ELEBAKE_<name> -> ELEBAKE_INTERPRETER_<name>;
# empty when none resolves
env_var_resolve() {
        local cand=""
        for cand in "$1" "ELEBAKE_$1" "ELEBAKE_INTERPRETER_$1"; do
                env_resolve_file "$cand" > /dev/null 2>&1 && printf '%s\n' "$cand" && return 0
        done
        return 1
}

# env_doc_path <var> <layer> -- the file whose lines 2+ document the
# variable: the shown layer when it documents anything, else the first
# deeper layer (default, then template) that does; a local override written
# by setenv carries only the value and must not LOSE the documentation
env_doc_path() {
        local layer="" path=""
        for layer in "$2" default template; do
                path=$(env_resolve_file "$1" "$layer" 2>/dev/null | sed -n 2p)
                test -n "$path" && tail -n +2 "$path" | grep -q '[^[:space:]]' && printf '%s\n' "$path" && return 0
        done
        env_resolve_file "$1" "$2" 2>/dev/null | sed -n 2p
}

# trace_verdict <trace> -- the outcome of an invocation from its trace: the
# last 'final EXIT_BITS' line (emitted error BRANCHES inside command text are
# code, not failures)
trace_verdict() {
        local bits=""
        bits=$(grep -o 'final EXIT_BITS: [0-9.]*' "$1" 2>/dev/null | tail -n1 | sed 's/.*: //')
        case "$bits" in ''|0|0.0|0.0.0) printf 'ok\n' ;; *) printf 'FAIL(%s)\n' "$bits" ;; esac
}
