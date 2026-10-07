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

# kenv_key_ok <key> -- a loader.trust.* kenv name
kenv_key_ok() {
        case "$1" in
                loader.trust.[a-z]*) ;;
                *) return 1 ;;
        esac
        case "$1" in *[!a-z0-9._]*) return 1 ;; esac
        return 0
}

# kenv_value_ok <value> -- fits one loader.conf line, key="value"
kenv_value_ok() {
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


# minimized_keep <record-relative path> -- does a stage element belong to
# BINARY MANAGEMENT? The definition is template/filter/minimized.keep,
# matched by template/awk/filter.awk exactly as 'filter minimized' matches
# the collection; here the element is offered as .staging/_/<path>.
minimized_keep() {
        printf '%s\n' "\"\$ELEBAKE_ARCHIVE_BASE\"/.staging/_/$1" | awk -v strategy=minimized -v drop=/dev/null -v keep="$ELEBAKE_TEMPLATE_DIR/filter/minimized.keep" -f "$ELEBAKE_TEMPLATE_DIR/awk/filter.awk" | grep -qv '^#'
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
        printf '#!/bin/sh\nexit 0\n' > "$probe" && chmod 0700 "$probe" && "$probe" >/dev/null 2>&1
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

# boot_generated <entry> -- a top-level entry of boot/ that a step of the
# stage generates (never curated, never pruned): the manifest pair, the
# loader's trust configuration, signed artifacts.
boot_generated() {
        test "$1" = manifest || test "$1" = manifest.asc || test "$1" = loader.trust.conf || test "${1%.signed}" != "$1"
}

# key_name_ok <name> -- a key record name (one rule with the other record names)
key_name_ok() { record_name_ok "$1"; }

# keyid_ok <keyid> -- an OpenPGP key id or fingerprint: 8, 16 or 40 hex digits
keyid_ok() {
        printf '%s\n' "$1" | grep -qxE '[0-9A-Fa-f]{8}|[0-9A-Fa-f]{16}|[0-9A-Fa-f]{40}'
}

# trace_verdict <trace> -- the outcome of an invocation from its trace: the
# last 'final EXIT_BITS' line (emitted error BRANCHES inside command text are
# code, not failures)
trace_verdict() {
        local bits=""
        bits=$(grep -o 'final EXIT_BITS: [0-9.]*' "$1" 2>/dev/null | tail -n1 | sed 's/.*: //')
        case "$bits" in ''|0|0.0|0.0.0) printf 'ok\n' ;; *) printf 'FAIL(%s)\n' "$bits" ;; esac
}

# pin_listed <ELEBAKE_INTERPRETER_x> <profile> -- does the profile list the pin?
pin_listed() {
        head -1 "$ELEBAKE_TEMPLATE_DIR/environment/ELEBAKE_PROFILE_$(printf '%s' "$2" | tr '[:lower:]' '[:upper:]')" 2>/dev/null | tr ' ' '\n' | grep -qx "$1"
}

# pin_names_terminal <ELEBAKE_INTERPRETER_x> -- does a terminal of that name (any
# arity) exist? A local pin left behind by a rename names none -- and may bind
# a batch or combinator of the new vocabulary instead
pin_names_terminal() {
        local stem="${1#ELEBAKE_INTERPRETER_}"
        printf '%s\n' $ANCHOR_FUNCTIONS | grep -qE "^_${stem}[0-9]*$"
}

# gate_has_string_claim <gate> -- does any claim of the gate compare a string
# expectation? Such a gate has no C form (the loader knows BYTE and SHA256)
gate_has_string_claim() {
        local c="" m="" d="" p="" e="" ty="" l="" v=""
        for c in $(grep . "$ELEBAKE_BASE/foundation/gates/$1/claims" 2>/dev/null); do
                read -r m d p e 2>/dev/null < "$ELEBAKE_BASE/foundation/claims/$c"
                read -r ty l v 2>/dev/null < "$ELEBAKE_BASE/foundation/expectations/$e"
                test "$ty" != string || return 0
        done
        return 1
}

# fnd_expr_ok <when|action> <expression> -- the trigger expression parses
# (template/awk/when-expr.awk): a catalog name, or and(a,b)/or(a,b)/not(a)
# for a when, compose(a,b) for an action; no whitespace
fnd_expr_ok() {
        awk -v e="$2" -v kind="$1" -v mode=check -f "$ELEBAKE_TEMPLATE_DIR/awk/when-expr.awk" > /dev/null 2>&1
}

