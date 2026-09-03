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
  local coll="$1" out="$2" base="$ELEBAKE_BASE" line rel abs hash body="" n
  [ -f "$coll" ] || { generate_error "manifest: no such collection '$coll'"; return 0; }
  case "$out" in
    */MANIFEST) ;;
    *) generate_error "manifest: the manifest must be named MANIFEST: '$out'" \
         "(import looks for it by name, next to the collection)"; return 0 ;;
  esac
  # one manifest line per collection entry, against $ELEBAKE_BASE; a path
  # with whitespace could not be read back as `path key=value` (the boot
  # manifest has the same grammar), an unreadable entry ends the command
  # instead of shortening the manifest
  while IFS= read -r line; do
    case "$line" in \#*|"") continue ;; esac
    rel=${line#\"\$ELEBAKE_ARCHIVE_BASE\"/}
    case "$rel" in
      *" "*|*"	"*) generate_error "manifest: whitespace in path: $rel"; return 0 ;;
    esac
    abs="$base/$rel"
    if [ -L "$abs" ]; then
      body="$body$rel symlink=$(readlink "$abs")
"
    elif [ -f "$abs" ]; then
      hash=$(sha256 -q "$abs" 2>>"$LOG_FILE") || {
        generate_error "manifest: cannot hash $rel"; return 0; }
      body="$body$rel sha256=$hash
"
    else
      generate_error "manifest: collection entry is neither file nor symlink: $rel" \
        "(collect and bundle must see the same database)"; return 0
    fi
  done < "$coll"
  [ -n "$body" ] || {
    generate_error "manifest: collection '$coll' lists nothing to hash"; return 0; }
  n=$(printf '%s\n' "$body" | wc -l | tr -d ' ')
  emit_note "elebake manifest '$out' ($n entries, hashed at generation time)"
  printf '%s\n' "cat > '$out.new' <<'ELVEOF'"
  printf '%s' "$body"
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
#@help ___manifest_verify3
# @command manifest verify <manifest> <base> <key>
# @summary Verify a manifest, both judgments at generation time: the signature (attest verify: signed by the PINNED key, key neither expired nor revoked) and the tree (manifest match: every listed entry present and identical) -- a finding fails the batch before restore replays anything
# @group   database
# @param   manifest  the MANIFEST to check
# @param   base      the directory its paths are relative to (an extraction directory)
# @param   key       the openpgp record naming the signer you expect
# @example elebake manifest verify ~/.elebake/incoming/a1b2c3d/export/MANIFEST ~/.elebake/incoming/a1b2c3d manifest-attest
# @see     attest verify
# @see     manifest match
#@end
___manifest_verify3() {
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" attest verify '$1' '$3'"
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" manifest match '$1' '$2'"
}

#@help _manifest_match2
# @command manifest match <manifest> <base>
# @summary Does the tree under <base> match the manifest? Checked at generation time: every listed file hashes identically, every listed symlink points where recorded; findings (MISSING/CHANGED/RETARGETED) fail the command. Files present but unlisted are not findings -- the base is an extraction directory
# @group   database
# @param   manifest  the MANIFEST to check
# @param   base      the directory its paths are relative to
# @see     manifest verify
#@end
_manifest_match2() {
  local man="$1" base="$2" rel val have findings="" n=0
  [ -f "$man" ] || { generate_error "manifest match: no such manifest '$man'"; return 0; }
  [ -d "$base" ] || { generate_error "manifest match: no such directory '$base'"; return 0; }
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
  [ "$n" -gt 0 ] || { generate_error "manifest match: '$man' lists no entries"; return 0; }
  if [ -n "$findings" ]; then
    printf '%s' "$findings"
    generate_error "manifest match: $man does not describe $base" \
      "(the TREE differs from what the sender listed)"
    return 0
  fi
  emit_note "manifest match: $n entries, tree matches"
}
