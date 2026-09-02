#!/bin/sh
#
# Copyright (c) 2026 Dr. Johannes Brügmann
#
# SPDX-License-Identifier: BSD-2-Clause
#
# manifest — the archive's own tamper detection, built the same way the boot
# manifest is built.
#
# An archive that carries no manifest is a claim without evidence: the receiver
# can tell that the tarball unpacked, not that it unpacked what the sender
# packed. So a bundle carries the same pair /boot carries — MANIFEST plus a
# detached OpenPGP signature MANIFEST.asc — produced by the same recipe as
# `stage manifest` / `stage attest`: LC_ALL=C-sorted `path key=value` lines,
# hashed at generation time, signed with `attest`.
#
# Two line kinds, because a database tree holds more than regular files:
#
#   stage/smoke1/metadata          sha256=3fa7…
#   stage/smoke1                   symlink=../.staging/stage-12778bf2c6b7
#
# The manifest never lists itself or its signature — the same exclusion
# `stage manifest` makes for boot/manifest and boot/manifest.asc.

#-----------------------------------------------------------------------------
# manifest_entries <collection> — the manifest body, computed at generation time
#-----------------------------------------------------------------------------
# Reads a collection (comment lines and "$ELEBAKE_ARCHIVE_BASE"/-prefixed
# paths), prints one manifest line per entry against $ELEBAKE_BASE. Returns 1
# and names the offender on stderr when an entry cannot be read, so the caller
# can turn that into a generation error instead of a short manifest.
manifest_entries() {
  local coll="$1" base="$ELEBAKE_BASE" line rel abs hash
  while IFS= read -r line; do
    case "$line" in \#*|"") continue ;; esac
    rel=${line#\"\$ELEBAKE_ARCHIVE_BASE\"/}
    # A manifest line is read back as `path key=value`, so a path with a space
    # would verify as a different, shorter path. Refuse to write a line that
    # cannot be read back -- the boot manifest has the same grammar.
    case "$rel" in
      *" "*|*"	"*) printf '%s (whitespace in path)\n' "$rel" >&2; return 1 ;;
    esac
    abs="$base/$rel"
    if [ -L "$abs" ]; then
      printf '%s symlink=%s\n' "$rel" "$(readlink "$abs")"
    elif [ -f "$abs" ]; then
      hash=$(sha256 -q "$abs" 2>>"$LOG_FILE") || { printf '%s\n' "$rel" >&2; return 1; }
      printf '%s sha256=%s\n' "$rel" "$hash"
    else
      printf '%s\n' "$rel" >&2
      return 1
    fi
  done < "$coll"
  return 0
}

#-----------------------------------------------------------------------------
# _manifest2 <collection> <manifest> — write the manifest for a collection
#-----------------------------------------------------------------------------
# The collection is the authority on what travels, so it is also the authority
# on what the manifest covers: exactly its entries, in its order (collect
# already sorts). Everything is hashed HERE — the emission is one concrete
# heredoc write, so the trace shows the file that will land and nothing is
# hashed at execution time.
#@help _manifest2
# @command manifest <collection> <manifest>
# @summary Hash every entry of a collection into a manifest, same format as the boot manifest: LC_ALL=C-sorted 'path sha256=hash' (symlinks as 'path symlink=target')
# @group   database
# @param   collection  a collection file, as written by 'filter'
# @param   manifest    where to write it; the signature goes next to it as <manifest>.asc
# @env     ELEBAKE_ARCHIVE_BASE  the prefix collection lines are written against
# @returns the shell that writes the manifest
# @example elebake manifest export/collection export/MANIFEST
# @see     manifest attest
# @see     manifest verify
#@end
_manifest2() {
  local coll="$1" out="$2" body missing n errf
  [ -f "$coll" ] || { generate_error "manifest: no such collection '$coll'"; return 0; }
  case "$out" in
    */MANIFEST) ;;
    *) generate_error "manifest: the manifest must be named MANIFEST: '$out'" \
         "(import looks for it by name, next to the collection)"; return 0 ;;
  esac
  errf=$(mktemp "$ELEBAKE_BASE/.tmp/manifest.XXXXXX") || {
    generate_error "manifest: cannot create a scratch file under $ELEBAKE_BASE/.tmp"; return 0; }
  body=$(manifest_entries "$coll" 2>"$errf") || {
    missing=$(head -n1 "$errf"); rm -f "$errf"
    generate_error "manifest: collection entry is neither file nor symlink: $missing" \
      "(collect and bundle must see the same database)"; return 0; }
  rm -f "$errf"
  [ -n "$body" ] || {
    generate_error "manifest: collection '$coll' lists nothing to hash"; return 0; }
  n=$(printf '%s\n' "$body" | wc -l | tr -d ' ')
  emit_note "elebake manifest '$out' ($n entries, hashed at generation time)"
  printf '%s\n' "cat > '$out.new' <<'ELVEOF'"
  printf '%s\n' "$body"
  printf '%s\n' "ELVEOF"
  printf '%s\n' "mv '$out.new' '$out' && $MODIFY_FILE_PERMS 0644 '$out'"
  printf '%s\n' "printf '# MANIFEST written: $n entries\\n' >&2"
}

#-----------------------------------------------------------------------------
# ___manifest_attest2 <collection> <key> — write and sign, in that order
#-----------------------------------------------------------------------------
#@help ___manifest_attest2
# @command manifest attest <collection> <key>
# @summary Write the manifest for a collection and sign it, side by side with the collection: manifest + attest
# @group   database
# @param   collection  the filtered collection the bundle will pack
# @param   key         the openpgp record that signs (ELEBAKE_ARCHIVE_ATTEST_KEY in export)
# @example elebake manifest attest export/collection manifest-attest
# @see     export
# @see     attest
#@end
___manifest_attest2() {
  local coll="$1" key="$2" man
  man="$(dirname "$coll")/MANIFEST"
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" manifest '$coll' '$man'"
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" attest '$man' '$key'"
}

#-----------------------------------------------------------------------------
# _manifest_verify3 <manifest> <base> <key> — signer, signature, hashes
#-----------------------------------------------------------------------------
# Everything checked here is World the generator sees as-is, so ALL checks run
# at generation time and a finding becomes a generation error. That is what
# makes the check load-bearing inside `import`: the batch stops before restore
# replays anything.
#
# The key is the RECEIVER's openpgp record naming the signer it expects (see
# attest.sh for why the pin, not the keyring's trust level, is the decision).
#
# Direction 2 (files present but unlisted) is deliberately absent: the base is
# an extraction directory, and the receiver's own scratch files there are not
# evidence of tampering. What the manifest lists must be there and must hash;
# that is the claim being made.
#@help _manifest_verify3
# @command manifest verify <manifest> <base> <key>
# @summary Verify a manifest at generation time: signed by the PINNED key, signature good, tree matches -- any finding fails the command
# @group   database
# @param   manifest  the MANIFEST to check
# @param   base      the directory its paths are relative to (an extraction directory)
# @param   key       the openpgp record naming the signer you expect (keyid = fingerprint or long id, 16+ hex digits)
# @returns the findings, or the ok line
# @example elebake manifest verify ~/.elebake/incoming/a1b2c3d/export/MANIFEST ~/.elebake/incoming/a1b2c3d manifest-attest
# @see     import
# @see     attest verify
#@end
_manifest_verify3() {
  local man="$1" base="$2" key="$3" rel val have findings="" n=0 keyid gh attest_why fpr
  [ -f "$man" ] || { generate_error "manifest verify: no such manifest '$man'"; return 0; }
  [ -d "$base" ] || { generate_error "manifest verify: no such directory '$base'"; return 0; }
  attest_key_read "$key" || { generate_error "manifest verify: $attest_why"; return 0; }
  fpr=$(attest_signer "$man" "$keyid" "$gh") || {
    generate_error "manifest verify: $fpr" \
      "(manifest $man, expected signer: openpgp record '$key')"
    return 0
  }
  while read -r rel val; do
    case "$val" in sha256=*|symlink=*) ;; *) continue ;; esac
    n=$((n + 1))
    case "$val" in
      symlink=*)
        if [ ! -L "$base/$rel" ]; then
          findings="${findings}printf '%s\n' '# MISSING SYMLINK  $rel' >&2
"
        else
          have=$(readlink "$base/$rel")
          [ "$have" = "${val#symlink=}" ] || findings="${findings}printf '%s\n' '# RETARGETED  $rel' >&2
"
        fi
        ;;
      sha256=*)
        if [ ! -f "$base/$rel" ]; then
          findings="${findings}printf '%s\n' '# MISSING  $rel' >&2
"
        else
          have=$(sha256 -q "$base/$rel" 2>>"$LOG_FILE")
          [ "$have" = "${val#sha256=}" ] || findings="${findings}printf '%s\n' '# CHANGED  $rel' >&2
"
        fi
        ;;
    esac
  done < "$man"
  [ "$n" -gt 0 ] || { generate_error "manifest verify: '$man' lists no entries"; return 0; }
  if [ -n "$findings" ]; then
    printf '%s' "$findings"
    generate_error "manifest verify: $man does not describe $base" \
      "(signature is good and pinned, so the manifest is the sender's -- the TREE differs)"
    return 0
  fi
  emit_note "manifest verify: $n entries, signed by $fpr, tree matches"
}
