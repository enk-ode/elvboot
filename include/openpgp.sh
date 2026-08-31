#!/bin/sh
#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Dr. Johannes Brügmann
# elebake openpgp - OpenPGP (GnuPG) attest-key registry.
#
# Second key backend kind, sibling of pkcs11/. Used to ATTEST a stage's manifest
# (detached GPG signature). openpgp/<name>/ holds only the key reference (keyid).
#
# ARCHITECTURE: TERMINALS — emit ONLY shell, never an elebake re-invocation.
# Errors via generate_error (error shell), not an `elebake error` command.

#-----------------------------------------------------------------------------
# _openpgp_add2 <name> <keyid>
#-----------------------------------------------------------------------------
#@help _openpgp_add2
# @internal arity-2 sibling of 'openpgp add' (default GnuPG home)
#@end
_openpgp_add2() {
  local name="$1" keyid="$2" base="$ELEBAKE_BASE"
  case "$name" in
    ""|*/*|.|..|*[!A-Za-z0-9_.-]*)
      generate_error "openpgp add: invalid key name '$name'"
      return 0
      ;;
  esac
  printf '%s\n' "$MODIFY_DIR_CREATE '$base/openpgp/$name'"
  printf '%s\n' "$MODIFY_FILE_PERMS 0700 '$base/openpgp/$name'"
  printf '%s\n' "echo '$keyid' > '$base/openpgp/$name/keyid'"
  printf '%s\n' "$MODIFY_FILE_PERMS 0600 '$base/openpgp/$name/keyid'"
  printf '%s\n' "printf '# Registered openpgp key %s\\n' '$name' >&2"
}

#-----------------------------------------------------------------------------
# _openpgp_add3 <name> <keyid> <gnupghome> — key in a NON-default GnuPG home
#-----------------------------------------------------------------------------
# Same record as _openpgp_add2 plus the gnupghome path; every consumer of the
# key (trust anchor, attest) derives a GNUPGHOME= prefix from it. secboot.sh
# keeps the manifest key in /root/secureboot/manifest/.gnupg — this is how
# such a keyring is registered without touching any default keyring.
#@help _openpgp_add3
# @command openpgp add <name> <keyid> [<gnupghome>]
# @summary Register a GnuPG attest key; gnupghome for a keyring living elsewhere
# @group   keys
# @param   name       record name (referenced by stage attest key)
# @param   keyid      long key id (16 hex digits)
# @param   gnupghome  GnuPG home holding the key (e.g. /root/secureboot/manifest/.gnupg)
# @example elebake openpgp add manifest 77B2C2E8F5A4C6C7 /root/secureboot/manifest/.gnupg
# @see     stage attest key
#@end
_openpgp_add3() {
  local name="$1" keyid="$2" home="$3" base="$ELEBAKE_BASE"
  case "$name" in
    ""|*/*|.|..|*[!A-Za-z0-9_.-]*)
      generate_error "openpgp add: invalid key name '$name'"
      return 0
      ;;
  esac
  printf '%s\n' "$MODIFY_DIR_CREATE '$base/openpgp/$name'"
  printf '%s\n' "$MODIFY_FILE_PERMS 0700 '$base/openpgp/$name'"
  printf '%s\n' "echo '$keyid' > '$base/openpgp/$name/keyid'"
  printf '%s\n' "echo '$home' > '$base/openpgp/$name/gnupghome'"
  printf '%s\n' "$MODIFY_FILE_PERMS 0600 '$base/openpgp/$name/keyid' '$base/openpgp/$name/gnupghome'"
  printf '%s\n' "printf '# Registered openpgp key %s (gnupghome %s)\\n' '$name' '$home' >&2"
}

#-----------------------------------------------------------------------------
# _openpgp_prerequisites0 — emit the toolchain checks for openpgp attesting
#-----------------------------------------------------------------------------
#@help _openpgp_prerequisites0
# @command openpgp prerequisites
# @summary Check the GnuPG attest toolchain
# @group   diagnostics
#@end
_openpgp_prerequisites0() {
  emit_note "openpgp prerequisites (detached GPG signature)"
  printf '%s\n' "command -v gpg >/dev/null 2>&1 || { printf '# Error: gpg not installed (pkg install gnupg)\\n' >&2; exit 1; }"
  # No card requirement here: gpg is card-agnostic (a keyring stub routes to the
  # card transparently), and a pure-keyring key needs no card at all. A card
  # readiness check belongs to a card-marked key record (Nitrokey slice, TBD).
  printf '%s\n' "printf '# prerequisites ok: openpgp\\n' >&2"
}

#@help ___openpgp_dump0
# @command openpgp dump
# @summary Emit the openpgp portion of a database dump: one 'openpgp add' replay line per registered key
# @group   keys
# @returns elebake commands describing the current openpgp records (cat-pinned:
# @returns they become dump TEXT, replayed against the target by 'restore')
# @example elebake openpgp dump
# @see     dump
# @see     openpgp add
#@end
___openpgp_dump0() {
  local base="$ELEBAKE_BASE" rec name keyid home n=0
  for rec in "$base"/openpgp/*/; do
    [ -d "$rec" ] || continue
    n=$((n+1))
    name=$(basename "$rec")
    keyid=$(head -n 1 "$rec/keyid" 2>/dev/null)
    if [ -f "$rec/gnupghome" ]; then
      home=$(head -n 1 "$rec/gnupghome")
      printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" openpgp add '$name' '$keyid' $(rebase_db_path "$home")"
    else
      printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" openpgp add '$name' '$keyid'"
    fi
    backend_dump_extra_lines openpgp "$name" keyid gnupghome
  done
  [ "$n" -gt 0 ] || printf '%s\n' "# (no openpgp keys to dump)"
}

#@help _openpgp_import2
# @command openpgp import <name> <absfile>
# @summary Copy ONE extra file into the key record — dump/restore base element (the schema files keyid/gnupghome travel as the 'openpgp add' replay)
# @group   keys
# @param   absfile  absolute source path in the OTHER database
# @see     openpgp dump
#@end
_openpgp_import2() {
  local name="$1" src="$2" base="$ELEBAKE_BASE"
  { [ -f "$src" ] || [ -L "$src" ]; } || {
    generate_error "openpgp import: no such file: $src"; return 0; }
  [ -d "$base/openpgp/$name" ] || {
    generate_error "openpgp import: unknown key '$name' (openpgp add first)"; return 0; }
  printf '%s\n' "rm -f '$base/openpgp/$name/$(basename "$src")' && cp -Pp '$src' '$base/openpgp/$name/' || { printf '# Error: openpgp import failed\\n' >&2; exit 1; }"
}
