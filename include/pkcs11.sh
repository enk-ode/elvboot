#!/bin/sh
#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Dr. Johannes Brügmann
# elebake pkcs11 - PKCS#11 (HSM/token) signing-key registry.
#
# A key "backend kind" = a top-level object (like vpn-switch's wireguard/openvpn).
# Keys are DB objects: pkcs11/<name>/ holds ONLY public material + references
# (uri, cert) -- never the private key, which lives on the token.
#
# ARCHITECTURE: every check is a combinator line (a comment line, else an
# error line) in front of one act terminal; the record holds public
# material and references only.

#@help ___pkcs11_add3
# @command pkcs11 add <name> <uri> <certfile>
# @summary Register a PKCS#11 token key, its URI and certificate path: the name is a record name; then 'pkcs11 record'
# @group   keys
# @param   name      record name (referenced by stage sign key)
# @param   uri       PKCS#11 URI of the private key on the token
# @param   certfile  path to the matching certificate (PEM)
# @example elebake pkcs11 add nitrokey-9c 'pkcs11:token=OpenPGP;object=SIGN' /root/keys/db.crt
# @see     stage sign key
# @see     pkcs11 prerequisites
#@end
___pkcs11_add3() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" key name valid '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" pkcs11 record '$1' '$2' '$3'"
}

#@help _pkcs11_record3
# @command pkcs11 record <name> <uri> <certfile>
# @summary Act terminal: write pkcs11/<name>/uri and cert (0700/0600) and say so
# @group   keys
# @internal
# @see     pkcs11 add
#@end
_pkcs11_record3() {
        printf '%s\n' "$MODIFY_DIR_CREATE '$ELEBAKE_BASE/pkcs11/$1'"
        printf '%s\n' "$MODIFY_FILE_PERMS 0700 '$ELEBAKE_BASE/pkcs11/$1'"
        printf '%s\n' "echo '$2' > '$ELEBAKE_BASE/pkcs11/$1/uri'"
        printf '%s\n' "echo '$3' > '$ELEBAKE_BASE/pkcs11/$1/cert'"
        printf '%s\n' "$MODIFY_FILE_PERMS 0600 '$ELEBAKE_BASE/pkcs11/$1/uri' '$ELEBAKE_BASE/pkcs11/$1/cert'"
        printf '%s\n' "printf '# Registered pkcs11 key %s\\n' '$1' >&2"
}

#@help ___pkcs11_prerequisites0
# @command pkcs11 prerequisites
# @summary Can we sign with a token RIGHT NOW? Checked at generation: the module and bridge are configured, the bridge's library is set, osslsigncode and pkcs11-tool are installed, the module and the bridge library exist; then the functional probe -- a token answers via PC/SC (only its failure triggers the staged diagnosis: check first, complain second)
# @group   diagnostics
# @env     ELEBAKE_PKCS11_BRIDGE    engine | provider (OpenSSL bridge; engine is the FreeBSD default)
# @env     ELEBAKE_PKCS11_ENGINE    path to the libp11 pkcs11 engine .so
# @env     ELEBAKE_PKCS11_PROVIDER  path to the OpenSSL 3 pkcs11 provider (bridge=provider only)
# @env     ELEBAKE_PKCS11_MODULE    path to the PKCS#11 module (e.g. opensc-pkcs11.so)
# @example elebake pkcs11 prerequisites
# @see     stage sign pkcs11
# @see     pkcs11 add
#@end
___pkcs11_prerequisites0() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" pkcs11 module set"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" pkcs11 bridge set"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" pkcs11 tools installed"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" pkcs11 module present"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" pkcs11 bridge present"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" pkcs11 token answers"
}

#@help __pkcs11_module_set0
# @command pkcs11 module set
# @summary ELEBAKE_PKCS11_MODULE and ELEBAKE_PKCS11_BRIDGE are set: a comment line, else an error line
# @group   diagnostics
# @internal
# @env     ELEBAKE_PKCS11_MODULE  the module
# @env     ELEBAKE_PKCS11_BRIDGE  engine | provider
# @see     pkcs11 prerequisites
#@end
__pkcs11_module_set0() {
        if test -n "${ELEBAKE_PKCS11_MODULE:-}" && test -n "${ELEBAKE_PKCS11_BRIDGE:-}"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'pkcs11 module ${ELEBAKE_PKCS11_MODULE:-}, bridge ${ELEBAKE_PKCS11_BRIDGE:-}'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'pkcs11 prerequisites: ELEBAKE_PKCS11_MODULE/BRIDGE not set (environment init minimal)'"
        fi
}

#@help __pkcs11_bridge_set0
# @command pkcs11 bridge set
# @summary The bridge's library is configured (ELEBAKE_PKCS11_PROVIDER for provider, ELEBAKE_PKCS11_ENGINE otherwise): a comment line, else an error line
# @group   diagnostics
# @internal
# @env     ELEBAKE_PKCS11_ENGINE  the engine .so
# @env     ELEBAKE_PKCS11_PROVIDER  the provider .so
# @see     pkcs11 prerequisites
# @env     ELEBAKE_PKCS11_BRIDGE  engine | provider
#@end
__pkcs11_bridge_set0() {
        local lib=""
        test "${ELEBAKE_PKCS11_BRIDGE:-}" = provider && lib="${ELEBAKE_PKCS11_PROVIDER:-}" || lib="${ELEBAKE_PKCS11_ENGINE:-}"
        if test -n "$lib"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'pkcs11 bridge library $lib'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'pkcs11 prerequisites: ELEBAKE_PKCS11_${ELEBAKE_PKCS11_BRIDGE:-engine} library not set (environment init minimal)'"
        fi
}

#@help __pkcs11_tools_installed0
# @command pkcs11 tools installed
# @summary osslsigncode and pkcs11-tool are installed: a comment line, else an error line
# @group   diagnostics
# @internal
# @see     pkcs11 prerequisites
#@end
__pkcs11_tools_installed0() {
        if command -v osslsigncode > /dev/null 2>&1 && command -v pkcs11-tool > /dev/null 2>&1; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'osslsigncode and pkcs11-tool installed'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'pkcs11 prerequisites: osslsigncode or pkcs11-tool not installed (pkg install osslsigncode opensc)'"
        fi
}

#@help __pkcs11_module_present0
# @command pkcs11 module present
# @summary The PKCS#11 module file exists: a comment line, else an error line
# @group   diagnostics
# @internal
# @env     ELEBAKE_PKCS11_MODULE  the module
# @see     pkcs11 prerequisites
#@end
__pkcs11_module_present0() {
        if test -f "${ELEBAKE_PKCS11_MODULE:-}"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'module ${ELEBAKE_PKCS11_MODULE:-} present'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'pkcs11 prerequisites: PKCS#11 module not found: ${ELEBAKE_PKCS11_MODULE:-} (pkg install opensc)'"
        fi
}

#@help __pkcs11_bridge_present0
# @command pkcs11 bridge present
# @summary The bridge library file exists (libp11 engine, or the OpenSSL 3 provider): a comment line, else an error line
# @group   diagnostics
# @internal
# @env     ELEBAKE_PKCS11_ENGINE  the engine .so
# @env     ELEBAKE_PKCS11_PROVIDER  the provider .so
# @see     pkcs11 prerequisites
# @env     ELEBAKE_PKCS11_BRIDGE  engine | provider
#@end
__pkcs11_bridge_present0() {
        local lib=""
        test "${ELEBAKE_PKCS11_BRIDGE:-}" = provider && lib="${ELEBAKE_PKCS11_PROVIDER:-}" || lib="${ELEBAKE_PKCS11_ENGINE:-}"
        if test -f "$lib"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'bridge library $lib present'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'pkcs11 prerequisites: bridge library not found: $lib (pkg install libp11, or openssl-pkcs11provider)'"
        fi
}

#@help __pkcs11_token_answers0
# @command pkcs11 token answers
# @summary The functional probe: a token answers via PC/SC (pkcs11-tool -L): a log line with its label, else an error line carrying the staged diagnosis (pcsc-lite, pcscd, --disable-polkit and libccid, or no token on USB)
# @group   diagnostics
# @internal
# @see     pkcs11 prerequisites
# @env     ELEBAKE_PKCS11_BRIDGE  engine | provider (named in the ok line)
# @env     ELEBAKE_PKCS11_MODULE  the module pkcs11-tool asks
#@end
__pkcs11_token_answers0() {
        local tok=""
        tok=$(pkcs11_token_label)
        if test -n "$tok"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log 'pkcs11 prerequisites ok (checked at generation time): token $tok via ${ELEBAKE_PKCS11_BRIDGE:-} bridge'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'pkcs11 prerequisites: no PKCS#11 token reachable' $(sq "$(pkcs11_token_hint)")"
        fi
}

#@help ___pkcs11_dump0
# @command pkcs11 dump
# @summary Emit the pkcs11 portion of a database dump: one 'pkcs11 add' replay line per registered key (cat-pinned: dump TEXT, replayed by 'restore'), plus one 'pkcs11 import' per extra file; none is a comment line
# @group   keys
# @see     dump
#@end
___pkcs11_dump0() {
        local rec="" n=0
        for rec in "$ELEBAKE_BASE"/pkcs11/*/; do
                test -d "$rec" || continue
                n=$((n + 1))
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" pkcs11 add '$(basename "$rec")' '$(head -n1 "$rec/uri" 2>/dev/null)' $(rebase_db_path "$(head -n1 "$rec/cert" 2>/dev/null)")"
                backend_dump_extra_lines pkcs11 "$(basename "$rec")" uri cert
        done
        test "${n:-0}" -gt 0 || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'no pkcs11 keys to dump'"
}

#@help __pkcs11_import2
# @command pkcs11 import <name> <absfile>
# @summary Copy ONE extra file into the key record -- dump/restore base element (the schema files travel as the 'pkcs11 add' replay): rewrite to 'key import pkcs11 <name> <absfile>'
# @group   keys
# @param   absfile  absolute source path in the OTHER database
# @see     key import
#@end
__pkcs11_import2() {
        if true; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" key import pkcs11 '$1' '$2'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" key import pkcs11 '$1' '$2'"
        fi
}

#@help ___pkcs11_collect0
# @command pkcs11 collect
# @summary List the files of the pkcs11 key records that belong into an archive -- public material only; private key material stays a path promise into the world: one 'pkcs11 collect <key>' per record, none is a comment line
# @group   keys
# @see     collect
#@end
___pkcs11_collect0() {
        local r="" n=0
        for r in "$ELEBAKE_BASE"/pkcs11/*/; do
                test -d "$r" || continue
                n=$((n + 1))
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" pkcs11 collect '$(basename "$r")'"
        done
        test "${n:-0}" -gt 0 || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'no pkcs11 keys to collect'"
}

#@help __pkcs11_collect1
# @internal arity-1 sibling of 'pkcs11 collect' (pkcs11 collect <key>): The key record exists: rewrite to 'key collect files pkcs11 <key>', else an error line
#@end
__pkcs11_collect1() {
        if test -d "$ELEBAKE_BASE/pkcs11/$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" key collect files pkcs11 '$1'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'pkcs11 collect: no such key $1'"
        fi
}

