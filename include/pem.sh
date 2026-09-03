#!/bin/sh
#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Dr. Johannes Brügmann
# elebake pem - file-based (PEM) signing-key registry.
#
# Sibling of pkcs11/: the sign-key backend for sites WITHOUT a hardware token.
# pem/<name>/ holds ONLY the *paths* to key and cert — never the material
# itself. Custody stays wherever the files live (e.g. a root-only directory);
# elebake emits the signing command, the operator decides in which context to
# run it. Signing uses uefisign (FreeBSD-native Authenticode).
#
# ARCHITECTURE: TERMINALS — emit ONLY shell, never an elebake re-invocation.
# Errors via generate_error (error shell), not an `elebake error` command.

#-----------------------------------------------------------------------------
# _pem_add3 <name> <keyfile> <certfile>
#-----------------------------------------------------------------------------
#@help _pem_add3
# @command pem add <name> <keyfile> <certfile>
# @summary Register a file-based signing key by its paths (for sites without a token)
# @group   keys
# @param   name      record name (referenced by stage sign key)
# @param   keyfile   path to the private key -- custody stays where it lives
# @param   certfile  path to the matching certificate
# @example elebake pem add db /root/secureboot/db.key /root/secureboot/db.crt
# @see     stage sign key
#@end
_pem_add3() {
  local name="$1" key="$2" cert="$3" base="$ELEBAKE_BASE"
  case "$name" in
    ""|*/*|.|..|*[!A-Za-z0-9_.-]*)
      generate_error "pem add: invalid key name '$name'"
      return 0
      ;;
  esac
  printf '%s\n' "$MODIFY_DIR_CREATE '$base/pem/$name'"
  printf '%s\n' "$MODIFY_FILE_PERMS 0700 '$base/pem/$name'"
  printf '%s\n' "echo '$key' > '$base/pem/$name/key'"
  printf '%s\n' "echo '$cert' > '$base/pem/$name/cert'"
  printf '%s\n' "$MODIFY_FILE_PERMS 0600 '$base/pem/$name/key' '$base/pem/$name/cert'"
  printf '%s\n' "printf '# Registered pem key %s (paths only; material stays in place)\\n' '$name' >&2"
}

#-----------------------------------------------------------------------------
# _pem_prerequisites0 — emit the toolchain checks for file-based signing
#-----------------------------------------------------------------------------
#@help _pem_prerequisites0
# @command pem prerequisites
# @summary Check the uefisign file-signing toolchain
# @group   diagnostics
#@end
_pem_prerequisites0() {
  emit_note "pem prerequisites (Authenticode via uefisign, file-based key)"
  printf '%s\n' "command -v uefisign >/dev/null 2>&1 || { printf '# Error: uefisign not found (FreeBSD base tool)\\n' >&2; exit 1; }"
  printf '%s\n' "printf '# prerequisites ok: pem\\n' >&2"
}

#@help ___pem_dump0
# @command pem dump
# @summary Emit the pem portion of a database dump: one 'pem add' replay line per registered key
# @group   keys
# @returns elebake commands describing the current pem records (cat-pinned:
# @returns they become dump TEXT, replayed against the target by 'restore')
# @example elebake pem dump
# @see     dump
# @see     pem add
#@end
___pem_dump0() {
  local base="$ELEBAKE_BASE" rec name key cert n=0
  for rec in "$base"/pem/*/; do
    [ -d "$rec" ] || continue
    n=$((n+1))
    name=$(basename "$rec")
    key=$(head -n 1 "$rec/key" 2>/dev/null)
    cert=$(head -n 1 "$rec/cert" 2>/dev/null)
    printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" pem add '$name' $(rebase_db_path "$key") $(rebase_db_path "$cert")"
    backend_dump_extra_lines pem "$name" key cert
  done
  [ "$n" -gt 0 ] || printf '%s\n' "# (no pem keys to dump)"
}

#@help _pem_import2
# @command pem import <name> <absfile>
# @summary Copy ONE extra file into the key record — dump/restore base element (the schema files key/cert travel as the 'pem add' replay)
# @group   keys
# @param   absfile  absolute source path in the OTHER database
# @see     pem dump
#@end
_pem_import2() {
  local name="$1" src="$2" base="$ELEBAKE_BASE"
  { [ -f "$src" ] || [ -L "$src" ]; } || {
    generate_error "pem import: no such file: $src"; return 0; }
  [ -d "$base/pem/$name" ] || {
    generate_error "pem import: unknown key '$name' (pem add first)"; return 0; }
  printf '%s\n' "rm -f '$base/pem/$name/$(basename "$src")' && cp -Pp '$src' '$base/pem/$name/' || { printf '# Error: pem import failed\\n' >&2; exit 1; }"
}

#@help ___pem_collect0
# @command pem collect [<key>]
# @summary List the files of the pem key records that belong into an archive -- public material only; private key material stays a path promise into the world
# @group   keys
# @see     collect
#@end
___pem_collect0() {
  local base="$ELEBAKE_BASE" r n=0
  for r in "$base"/pem/*/; do
    [ -d "$r" ] || continue
    n=$((n+1))
    printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" pem collect '$(basename "$r")'"
  done
  [ "$n" -gt 0 ] || printf '%s\n' "# (no pem keys to collect)"
}

#@help _pem_collect1
# @internal 1-arg sibling: one key record
#@end
_pem_collect1() {
  local base="$ELEBAKE_BASE"
  [ -d "$base/pem/$1" ] || {
    generate_error "pem collect: no such key '$1'"; return 0; }
  printf '# pem %s\n' "$1"
  find "$base/pem/$1" \( -type f -o -type l \) 2>/dev/null | sort | while IFS= read -r f; do
    printf '"$ELEBAKE_ARCHIVE_BASE"/%s\n' "${f#"$base/"}"
  done
}
