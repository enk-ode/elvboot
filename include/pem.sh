#!/bin/sh
#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Dr. Johannes Brügmann
# elebake pem - file-based (PEM) signing-key registry.
#
# Sibling of pkcs11/: the sign-key backend for sites WITHOUT a hardware token.
# pem/<name>/ holds ONLY the *paths* to key and cert -- never the material
# itself. Custody stays wherever the files live (e.g. a root-only directory);
# elebake emits the signing command, the operator decides in which context to
# run it. Signing uses uefisign (FreeBSD-native Authenticode).
#
# ARCHITECTURE: every check is a combinator line (a comment line, else an
# error line) in front of one act terminal; the record holds public
# material and references only.

#@help ___pem_add3
# @command pem add <name> <keyfile> <certfile>
# @summary Register a file-based signing key by its paths (for sites without a token): the name is a record name; then 'pem record'
# @group   keys
# @param   name      record name (referenced by stage sign key)
# @param   keyfile   path to the private key -- custody stays where it lives
# @param   certfile  path to the matching certificate
# @example elebake pem add site-v1 /root/keys/site.key /root/keys/site.crt
# @see     stage sign key
# @see     pem prerequisites
#@end
___pem_add3() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" key name valid '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" pem record '$1' '$2' '$3'"
}

#@help _pem_record3
# @command pem record <name> <keyfile> <certfile>
# @summary Act terminal: write pem/<name>/key and cert (the PATHS; 0700/0600) and say so
# @group   keys
# @internal
# @see     pem add
#@end
_pem_record3() {
        printf '%s\n' "$MODIFY_DIR_CREATE '$ELEBAKE_BASE/pem/$1'"
        printf '%s\n' "$MODIFY_FILE_PERMS 0700 '$ELEBAKE_BASE/pem/$1'"
        printf '%s\n' "echo '$2' > '$ELEBAKE_BASE/pem/$1/key'"
        printf '%s\n' "echo '$3' > '$ELEBAKE_BASE/pem/$1/cert'"
        printf '%s\n' "$MODIFY_FILE_PERMS 0600 '$ELEBAKE_BASE/pem/$1/key' '$ELEBAKE_BASE/pem/$1/cert'"
        printf '%s\n' "printf '# Registered pem key %s (paths only; material stays in place)\\n' '$1' >&2"
}

#@help _pem_prerequisites0
# @command pem prerequisites
# @summary Act terminal: the runtime check of the uefisign file-signing toolchain
# @group   diagnostics
# @see     stage sign pem
#@end
_pem_prerequisites0() {
        emit_note "pem prerequisites (Authenticode via uefisign, file-based key)"
        printf '%s\n' "command -v uefisign >/dev/null 2>&1 || { printf '# Error: uefisign not found (FreeBSD base tool)\\n' >&2; exit 1; }"
        printf '%s\n' "printf '# prerequisites ok: pem\\n' >&2"
}

#@help ___pem_dump0
# @command pem dump
# @summary Emit the pem portion of a database dump: one 'pem add' replay line per registered key (cat-pinned: dump TEXT, replayed by 'restore'), plus one 'pem import' per extra file; none is a comment line
# @group   keys
# @see     dump
#@end
___pem_dump0() {
        local rec="" n=0
        for rec in "$ELEBAKE_BASE"/pem/*/; do
                test -d "$rec" || continue
                n=$((n + 1))
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" pem add '$(basename "$rec")' $(rebase_db_path "$(head -n1 "$rec/key" 2>/dev/null)") $(rebase_db_path "$(head -n1 "$rec/cert" 2>/dev/null)")"
                backend_dump_extra_lines pem "$(basename "$rec")" key cert
        done
        test "${n:-0}" -gt 0 || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'no pem keys to dump'"
}

#@help __pem_import2
# @command pem import <name> <absfile>
# @summary Copy ONE extra file into the key record -- dump/restore base element (the schema files travel as the 'pem add' replay): rewrite to 'key import pem <name> <absfile>'
# @group   keys
# @param   absfile  absolute source path in the OTHER database
# @see     key import
#@end
__pem_import2() {
        if true; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" key import pem '$1' '$2'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" key import pem '$1' '$2'"
        fi
}

#@help ___pem_collect0
# @command pem collect
# @summary List the files of the pem key records that belong into an archive -- public material only; private key material stays a path promise into the world: one 'pem collect <key>' per record, none is a comment line
# @group   keys
# @see     collect
#@end
___pem_collect0() {
        local r="" n=0
        for r in "$ELEBAKE_BASE"/pem/*/; do
                test -d "$r" || continue
                n=$((n + 1))
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" pem collect '$(basename "$r")'"
        done
        test "${n:-0}" -gt 0 || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'no pem keys to collect'"
}

#@help __pem_collect1
# @internal arity-1 sibling of 'pem collect' (pem collect <key>): The key record exists: rewrite to 'key collect files pem <key>', else an error line
#@end
__pem_collect1() {
        if test -d "$ELEBAKE_BASE/pem/$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" key collect files pem '$1'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'pem collect: no such key $1'"
        fi
}

