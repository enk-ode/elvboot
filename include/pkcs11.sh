#!/bin/sh
#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Dr. Johannes Brügmann
# elebake pkcs11 - PKCS#11 (HSM/token) signing-key registry.
#
# A key "backend kind" = a top-level object (like vpn-switch's wireguard/openvpn).
# Keys are DB objects: pkcs11/<name>/ holds ONLY public material + references
# (uri, cert) — never the private key, which lives on the token.
#
# ARCHITECTURE: these are TERMINALS — they emit ONLY shell, never an elebake
# re-invocation (that is a Combinator's job). Errors use generate_error (which
# emits error shell), NOT an `elebake error` command.

#-----------------------------------------------------------------------------
# _pkcs11_add3 <name> <uri> <cert>
#-----------------------------------------------------------------------------
#@help _pkcs11_add3
# @command pkcs11 add <name> <uri> <certfile>
# @summary Register a PKCS#11 token key: its URI and certificate path
# @group   keys
# @param   name      record name (referenced by stage sign key)
# @param   uri       PKCS#11 URI of the private key on the token
# @param   certfile  path to the matching certificate (PEM)
# @example elebake pkcs11 add db 'pkcs11:token=Nitrokey;object=db' /root/secureboot/db.crt
# @see     stage sign key
#@end
_pkcs11_add3() {
  local name="$1" uri="$2" cert="$3" base="$ELEBAKE_BASE"
  case "$name" in
    ""|*/*|.|..|*[!A-Za-z0-9_.-]*)
      generate_error "pkcs11 add: invalid key name '$name'"
      return 0
      ;;
  esac
  printf '%s\n' "$MODIFY_DIR_CREATE '$base/pkcs11/$name'"
  printf '%s\n' "$MODIFY_FILE_PERMS 0700 '$base/pkcs11/$name'"
  printf '%s\n' "echo '$uri' > '$base/pkcs11/$name/uri'"
  printf '%s\n' "echo '$cert' > '$base/pkcs11/$name/cert'"
  printf '%s\n' "$MODIFY_FILE_PERMS 0600 '$base/pkcs11/$name/uri' '$base/pkcs11/$name/cert'"
  printf '%s\n' "printf '# Registered pkcs11 key %s\\n' '$name' >&2"
}

#-----------------------------------------------------------------------------
# _pkcs11_prerequisites0 — FUNCTIONAL check first, diagnosis only on failure
#-----------------------------------------------------------------------------
# The question is "can we sign with a token RIGHT NOW?", answered by asking
# the token itself (pkcs11-tool -L). Configuration lore (--disable-polkit,
# libccid vs ccid) is mentioned ONLY when the functional test fails and the
# layer diagnosis points at it -- check first, complain second (JB).
# Exit 0 = token reachable; callers can branch file-based vs token on this.
#@help _pkcs11_prerequisites0
# @command pkcs11 prerequisites
# @summary Check the PKCS#11 signing toolchain at generation time (a token must answer via PC/SC)
# @group   diagnostics
# @env     ELEBAKE_PKCS11_BRIDGE    engine | provider (OpenSSL bridge; engine is the FreeBSD default)
# @env     ELEBAKE_PKCS11_ENGINE    path to the libp11 pkcs11 engine .so
# @env     ELEBAKE_PKCS11_PROVIDER  path to the OpenSSL 3 pkcs11 provider (bridge=provider only)
# @env     ELEBAKE_PKCS11_MODULE    path to the PKCS#11 module (e.g. opensc-pkcs11.so)
#@end
_pkcs11_prerequisites0() {
  # Non-modifying inspection, entirely at generation time: the generator
  # probes World as-is (binaries, module files, the token via PC/SC) and
  # emits comment lines; a failure aborts the generation WITH the way out
  # (functional first: only a missing token triggers the staged diagnosis).
  local mod="${ELEBAKE_PKCS11_MODULE:-}" bridge="${ELEBAKE_PKCS11_BRIDGE:-}"
  local provider="${ELEBAKE_PKCS11_PROVIDER:-}" engine="${ELEBAKE_PKCS11_ENGINE:-}"
  { [ -n "$mod" ] && [ -n "$bridge" ]; } || {
    generate_error "pkcs11 prerequisites: ELEBAKE_PKCS11_MODULE/BRIDGE not set (environment init minimal | sh)"; return 0; }
  if [ "$bridge" = provider ] && [ -z "$provider" ]; then
    generate_error "pkcs11 prerequisites: ELEBAKE_PKCS11_PROVIDER not set (environment init minimal | sh)"; return 0; fi
  if [ "$bridge" != provider ] && [ -z "$engine" ]; then
    generate_error "pkcs11 prerequisites: ELEBAKE_PKCS11_ENGINE not set (environment init minimal | sh)"; return 0; fi
  command -v osslsigncode >/dev/null 2>&1 || {
    generate_error "pkcs11 prerequisites: osslsigncode not installed (pkg install osslsigncode)"; return 0; }
  command -v pkcs11-tool >/dev/null 2>&1 || {
    generate_error "pkcs11 prerequisites: pkcs11-tool not installed (pkg install opensc)"; return 0; }
  [ -f "$mod" ] || {
    generate_error "pkcs11 prerequisites: PKCS#11 module not found: $mod (pkg install opensc)"; return 0; }
  if [ "$bridge" = provider ]; then
    [ -f "$provider" ] || {
      generate_error "pkcs11 prerequisites: openssl pkcs11 provider missing: $provider (pkg install openssl-pkcs11provider)"; return 0; }
  else
    [ -f "$engine" ] || {
      generate_error "pkcs11 prerequisites: libp11 engine not found: $engine (pkg install libp11)"; return 0; }
  fi
  # the functional probe: does a token answer?
  local tok hint
  tok=$(pkcs11-tool --module "$mod" -L 2>>"$LOG_FILE" | sed -n 's/^.*token label[ :]*//p' | head -n1)
  if [ -z "$tok" ]; then
    if ! command -v pcscd >/dev/null 2>&1; then
      hint="pcsc-lite not installed (pkg install pcsc-lite libccid)"
    elif ! pgrep -q pcscd 2>>"$LOG_FILE"; then
      hint="pcscd not running (sysrc pcscd_enable=YES; service pcscd start)"
    elif usbconfig 2>>"$LOG_FILE" | grep -qi 'nitrokey'; then
      hint="token visible on USB but not via PC/SC -- check pcscd_flags=--disable-polkit (sysrc -n pcscd_flags) and that libccid (not ccid) is installed"
    else
      hint="no token on USB (usbconfig) -- insert it"
    fi
    generate_error "pkcs11 prerequisites: no PKCS#11 token reachable" "$hint"
    return 0
  fi
  emit_note "pkcs11 prerequisites ok (checked at generation time): token '$tok' via $bridge bridge"
}

#@help ___pkcs11_dump0
# @command pkcs11 dump
# @summary Emit the pkcs11 portion of a database dump: one 'pkcs11 add' replay line per registered key
# @group   keys
# @returns elebake commands describing the current pkcs11 records (cat-pinned:
# @returns they become dump TEXT, replayed against the target by 'restore')
# @example elebake pkcs11 dump
# @see     dump
# @see     pkcs11 add
#@end
___pkcs11_dump0() {
  local base="$ELEBAKE_BASE" rec name uri cert n=0
  for rec in "$base"/pkcs11/*/; do
    [ -d "$rec" ] || continue
    n=$((n+1))
    name=$(basename "$rec")
    uri=$(head -n 1 "$rec/uri" 2>/dev/null)
    cert=$(head -n 1 "$rec/cert" 2>/dev/null)
    printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" pkcs11 add '$name' '$uri' $(rebase_db_path "$cert")"
    backend_dump_extra_lines pkcs11 "$name" uri cert
  done
  [ "$n" -gt 0 ] || printf '%s\n' "# (no pkcs11 keys to dump)"
}

#@help _pkcs11_import2
# @command pkcs11 import <name> <absfile>
# @summary Copy ONE extra file into the key record — dump/restore base element (the schema files uri/cert travel as the 'pkcs11 add' replay)
# @group   keys
# @param   absfile  absolute source path in the OTHER database
# @see     pkcs11 dump
#@end
_pkcs11_import2() {
  local name="$1" src="$2" base="$ELEBAKE_BASE"
  { [ -f "$src" ] || [ -L "$src" ]; } || {
    generate_error "pkcs11 import: no such file: $src"; return 0; }
  [ -d "$base/pkcs11/$name" ] || {
    generate_error "pkcs11 import: unknown key '$name' (pkcs11 add first)"; return 0; }
  printf '%s\n' "rm -f '$base/pkcs11/$name/$(basename "$src")' && cp -Pp '$src' '$base/pkcs11/$name/' || { printf '# Error: pkcs11 import failed\\n' >&2; exit 1; }"
}

#@help ___pkcs11_collect0
# @command pkcs11 collect [<key>]
# @summary List the files of the pkcs11 key records that belong into an archive -- public material only; private key material stays a path promise into the world
# @group   keys
# @see     collect
#@end
___pkcs11_collect0() {
  local base="$ELEBAKE_BASE" r n=0
  for r in "$base"/pkcs11/*/; do
    [ -d "$r" ] || continue
    n=$((n+1))
    printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" pkcs11 collect '$(basename "$r")'"
  done
  [ "$n" -gt 0 ] || printf '%s\n' "# (no pkcs11 keys to collect)"
}

#@help _pkcs11_collect1
# @internal 1-arg sibling: one key record
#@end
_pkcs11_collect1() {
  local base="$ELEBAKE_BASE"
  [ -d "$base/pkcs11/$1" ] || {
    generate_error "pkcs11 collect: no such key '$1'"; return 0; }
  printf '# pkcs11 %s\n' "$1"
  find "$base/pkcs11/$1" \( -type f -o -type l \) 2>/dev/null | sort | while IFS= read -r f; do
    printf '"$ELEBAKE_ARCHIVE_BASE"/%s\n' "${f#"$base/"}"
  done
}
