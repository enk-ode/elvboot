#!/bin/sh
#
# Copyright (c) 2026 Dr. Johannes Brügmann
#
# SPDX-License-Identifier: BSD-2-Clause
#
# attest — a detached OpenPGP signature beside a file, and the pinned check
# of one. The same recipe signs the boot manifest, the archive MANIFEST and
# the dump: `gpg --detach-sign -a` with a registered openpgp record.
#
# One attest identity per database (ELEBAKE_ARCHIVE_ATTEST_KEY): the sender
# signs with it, the receiver pins it. Pinning is the trust decision -- made
# once, explicitly, as an openpgp record -- so the keyring's web-of-trust
# levels are never consulted.

#-----------------------------------------------------------------------------
# attest_key_read <key> — resolve an openpgp record into keyid (+ gnupghome)
#-----------------------------------------------------------------------------
# Sets keyid and gh (empty = default home) IN THE CALLER's shell -- so it is
# called directly, never inside $(...). Returns 1 with the reason in
# attest_why when the record is unusable; callers turn that into
# generate_error.
attest_key_read() {
  local slot="$ELEBAKE_BASE/openpgp/$1"
  keyid=""; gh=""; attest_why=""
  [ -d "$slot" ] || { attest_why="unknown openpgp key '$1' (openpgp add $1 <fingerprint> [<gnupghome>])"; return 1; }
  [ -f "$slot/keyid" ] || { attest_why="openpgp record '$1' incomplete (keyid missing)"; return 1; }
  keyid=$(head -n1 "$slot/keyid")
  [ -f "$slot/gnupghome" ] && gh=$(head -n1 "$slot/gnupghome")
  return 0
}

#-----------------------------------------------------------------------------
# attest_signer <file> <keyid> [<gnupghome>] — WHO signed, pinned
#-----------------------------------------------------------------------------
# `gpg --verify` exits 0 for a mathematically good signature by ANY key in the
# keyring, expired and revoked ones included. That is not the question. The
# question is "did the key I expect sign this?", so the answer is read from
# gpg's status lines, not its exit code:
#
#   [GNUPG:] GOODSIG <longid> <uid>              good, key usable
#   [GNUPG:] EXPKEYSIG / REVKEYSIG / EXPSIG ...  good, but NOT acceptable
#   [GNUPG:] VALIDSIG <fpr> ... <primary-fpr>    the fingerprints
#
# Prints the signing fingerprint and returns 0 when a GOODSIG exists and one
# of the two VALIDSIG fingerprints ends in the pinned keyid; otherwise prints
# ONE reason line and returns 1. The pin is the openpgp record's keyid, at
# least 16 hex digits -- a short id can be forged in minutes and is refused
# as a pin.
attest_signer() {
  local file="$1" pin="$2" gh="${3:-}" status fpr pfpr
  pin=$(printf '%s' "$pin" | sed 's/^0[xX]//' | tr 'a-f' 'A-F')
  case "$pin" in
    *[!0-9A-F]*|"") printf 'pinned keyid is not hexadecimal: %s\n' "$pin"; return 1 ;;
  esac
  [ ${#pin} -ge 16 ] || { printf 'pinned keyid too short (%s digits, need 16+): %s\n' "${#pin}" "$pin"; return 1; }
  [ -f "$file.asc" ] || { printf 'unsigned: no %s.asc\n' "$file"; return 1; }
  if [ -n "$gh" ]; then
    status=$(GNUPGHOME="$gh" gpg --batch --status-fd 1 --verify "$file.asc" "$file" 2>>"$LOG_FILE")
  else
    status=$(gpg --batch --status-fd 1 --verify "$file.asc" "$file" 2>>"$LOG_FILE")
  fi
  printf '%s\n' "$status" >>"$LOG_FILE"
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

#-----------------------------------------------------------------------------
# _attest2 <file> <key> — the detached signature
#-----------------------------------------------------------------------------
# The key is an openpgp RECORD name, not a keyid — the record carries the
# keyid and, where the keyring lives outside the default home, the
# GNUPGHOME to reach it. Same call as `stage attest`; only the subject
# differs.
#
# libsecureboot verifies RSA OpenPGP signatures only ("We only support RSA"
# in openpgp/opgp_sig.c). That constraint belongs to the boot manifest, not
# to an archive or a dump -- those are verified by gpg on a running system --
# but using the same key for all keeps one attest identity instead of two.
#@help _attest2
# @command attest <file> <key>
# @summary Sign a file with a registered openpgp key: armored detached signature -> <file>.asc
# @group   database
# @param   file  the file to sign (a MANIFEST, a dump)
# @param   key   an 'openpgp add' record name
# @returns the shell that produces the signature
# @example elebake attest ~/git/config/dump.sh manifest-attest | sh
# @see     openpgp add
# @see     attest verify
#@end
_attest2() {
  local file="$1" key="$2" keyid gh attest_why gpgenv=""
  [ -f "$file" ] || { generate_error "attest: no such file '$file'"; return 0; }
  attest_key_read "$key" || { generate_error "attest: $attest_why"; return 0; }
  [ -n "$gh" ] && gpgenv="GNUPGHOME='$gh' "
  emit_note "elebake attest '$file' with openpgp key '$key' ($keyid)"
  # The isolated environment carries no GPG_TTY and the interpreter's stdin is
  # the emission, so a card pinentry has nowhere to ask: the emission finds its
  # own terminal and points the agent at it. rm -f first — a stale signature
  # from a failed run must never be mistaken for a fresh one.
  printf '%s\n' "rm -f '$file.asc'"
  printf '%s\n' "GPG_TTY=\$( { tty </dev/tty; } 2>/dev/null ); export GPG_TTY; ${gpgenv}gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1 || true"
  printf '%s\n' "${gpgenv}gpg --yes --openpgp -a --detach-sign --local-user '$keyid' -o '$file.asc' '$file' || { rm -f '$file.asc'; printf '# Error: attestation failed for %s\\n' '$keyid' >&2; exit 1; }"
  printf '%s\n' "printf '# attested %s by %s\\n' '$file' '$keyid' >&2"
}

#-----------------------------------------------------------------------------
# _attest_verify2 <file> <key> — signer pinned, checked at generation time
#-----------------------------------------------------------------------------
# The file and its signature are World the generator sees as-is, so the check
# runs HERE and a finding becomes a generation error (`exit 1` in the
# emission). That is what makes it load-bearing inside a batch: the sequence
# stops at the finding.
#@help _attest_verify2
# @command attest verify <file> <key>
# @summary Check a detached signature at generation time: signed by the PINNED key, key neither expired nor revoked -- a finding fails the command
# @group   database
# @param   file  the signed file; its signature is <file>.asc
# @param   key   the openpgp record naming the signer you expect (keyid = fingerprint or long id, 16+ hex digits)
# @returns the ok line naming the signer, or the finding
# @example elebake attest verify ~/git/config/dump.sh manifest-attest
# @see     attest
#@end
_attest_verify2() {
  local file="$1" key="$2" keyid gh attest_why fpr
  [ -f "$file" ] || { generate_error "attest verify: no such file '$file'"; return 0; }
  attest_key_read "$key" || { generate_error "attest verify: $attest_why"; return 0; }
  fpr=$(attest_signer "$file" "$keyid" "$gh") || {
    generate_error "attest verify: $fpr" "(file $file, expected signer: openpgp record '$key')"; return 0; }
  emit_note "attest verify: $file signed by $fpr (record '$key')"
}
