#!/bin/sh
#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Dr. Johannes Brügmann
# elebake manifest - the archive's own tamper detection, built the same way
# the boot manifest is built.
#
# An archive that carries no manifest is a claim without evidence: the receiver
# can tell that the tarball unpacked, not that it unpacked what the sender
# packed. So a bundle carries the same pair /boot carries -- MANIFEST plus a
# detached OpenPGP signature MANIFEST.asc -- produced by the same recipe as
# stage manifest / stage attest: LC_ALL=C-sorted 'path key=value' lines,
# hashed at generation time, signed with attest. Two line kinds, because a
# database tree holds more than regular files:
#
#   stage/smoke1/metadata          sha256=3fa7...
#   stage/smoke1                   symlink=../.staging/stage-12778bf2c6b7
#
# The manifest never lists itself or its signature.

#@help ___manifest2
# @command manifest <collection> <manifest>
# @summary Hash every entry of a collection into a manifest, same format as the boot manifest (LC_ALL=C-sorted 'path sha256=hash', symlinks as 'path symlink=target'): the collection is readable, the manifest is named MANIFEST (import looks for it by name, next to the collection), every entry is hashable; then 'manifest write' -- everything hashed at generation, the emission is one concrete heredoc write
# @group   database
# @param   collection  a collection file, as written by 'filter'
# @param   manifest    where to write it; the signature goes next to it as <manifest>.asc
# @env     ELEBAKE_ARCHIVE_BASE  the prefix collection lines are written against
# @example elebake manifest export/collection export/MANIFEST
# @see     manifest attest
# @see     manifest verify
# @see     bundle
#@end
___manifest2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" collection readable '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" manifest named '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" manifest entries hashable '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" manifest write '$1' '$2'"
}

#@help __manifest_named1
# @command manifest named <manifest>
# @summary The manifest path ends in /MANIFEST: a comment line, else an error line
# @group   database
# @internal
# @see     manifest
#@end
__manifest_named1() {
        if test "${1##*/}" = MANIFEST; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'manifest $1 named'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'manifest: the manifest must be named MANIFEST: $1' '(import looks for it by name, next to the collection)'"
        fi
}

#@help __manifest_entries_hashable1
# @command manifest entries hashable <collection>
# @summary Every entry of the collection is a file or symlink under the database with no whitespace in its path, and there is at least one: a comment line, else an error line naming the first that is not (an unreadable entry ends the command instead of shortening the manifest)
# @group   database
# @internal
# @see     manifest
#@end
__manifest_entries_hashable1() {
        local bad=""
        bad=$(collection_entry_bad "$1")
        if test -z "$bad" && test "$(grep -v "^#" "$1" 2>/dev/null | grep -c .)" -gt 0; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'every entry of $1 hashable'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error $(sq "manifest: ${bad:-collection $1 lists nothing to hash}") '(collect and bundle must see the same database)'"
        fi
}

#@help _manifest_write2
# @command manifest write <collection> <manifest>
# @summary Act terminal: the heredoc that writes <manifest>.new with one line per collection entry (hashed now), then mv into place (0644) and the count line
# @group   database
# @internal
# @see     manifest
# @env     ELEBAKE_ARCHIVE_BASE  the prefix collection lines are written against
#@end
_manifest_write2() {
        local line="" rel="" n=0
        n=$(grep -v '^#' "$1" 2>/dev/null | grep -c .)
        emit_note "elebake manifest '$2' ($n entries, hashed at generation time)"
        printf '%s\n' "cat > '$2.new' <<'ELVEOF'"
        grep -v '^#' "$1" 2>/dev/null | grep . | while IFS= read -r line; do
                rel=${line#\"\$ELEBAKE_ARCHIVE_BASE\"/}
                if test -L "$ELEBAKE_BASE/$rel"; then
                        printf '%s symlink=%s\n' "$rel" "$(readlink "$ELEBAKE_BASE/$rel")"
                else
                        printf '%s sha256=%s\n' "$rel" "$(sha256 -q "$ELEBAKE_BASE/$rel" 2>/dev/null)"
                fi
        done
        printf '%s\n' "ELVEOF"
        printf '%s\n' "mv '$2.new' '$2' && $MODIFY_FILE_PERMS 0644 '$2'"
        printf '%s\n' "printf '# MANIFEST written: %s entries\\n' '$n' >&2"
}

#@help ___manifest_attest2
# @command manifest attest <collection> <key>
# @summary Write the manifest for a collection and sign it, side by side with the collection: manifest + attest
# @group   database
# @param   collection  the filtered collection the bundle will pack
# @param   key         the openpgp record that signs (ELEBAKE_ARCHIVE_ATTEST_KEY in export)
# @example elebake manifest attest export/collection attest-v1
# @see     manifest
# @see     attest
# @see     export
#@end
___manifest_attest2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" manifest '$1' '$(dirname "$1")/MANIFEST'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" attest '$(dirname "$1")/MANIFEST' '$2'"
}

#@help ___manifest_verify3
# @command manifest verify <manifest> <base> <key>
# @summary Verify a manifest, both judgments at generation time: the signature (attest verify: signed by the PINNED key, key neither expired nor revoked) and the tree (manifest match: every listed entry present and identical) -- a finding fails the batch before restore replays anything. The key is the RECEIVER's openpgp record naming the signer it expects
# @group   database
# @param   manifest  the MANIFEST to check
# @param   base      the directory its paths are relative to (an extraction directory)
# @param   key       the openpgp record naming the signer you expect
# @example elebake manifest verify ~/.elebake/incoming/a1b2c3d/export/MANIFEST ~/.elebake/incoming/a1b2c3d attest-v1
# @see     attest verify
# @see     manifest match
# @see     import
#@end
___manifest_verify3() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" attest verify '$1' '$3'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" manifest match '$1' '$2'"
}

#@help ___manifest_match2
# @command manifest match <manifest> <base>
# @summary Does the tree under <base> match the manifest? The manifest is readable and lists entries, the base exists; then 'manifest tree matches' -- every listed file hashes identically, every listed symlink points where recorded (MISSING, CHANGED, RETARGETED fail). Files present but unlisted are not findings: the base is an extraction directory
# @group   database
# @param   manifest  the MANIFEST to check
# @param   base      the directory its paths are relative to
# @see     manifest verify
#@end
___manifest_match2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" manifest readable '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" manifest base exists '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" manifest tree matches '$1' '$2'"
}

#@help __manifest_readable1
# @command manifest readable <manifest>
# @summary The manifest is readable and lists at least one entry: a comment line, else an error line
# @group   database
# @internal
# @see     manifest match
#@end
__manifest_readable1() {
        local n=""
        n=$(grep -cE "^[^ ]+ (sha256|symlink)=" "$1" 2>/dev/null)
        if test "${n:-0}" -gt 0; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'manifest $1 lists entries'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'manifest match: no such manifest, or it lists no entries: $1'"
        fi
}

#@help __manifest_base_exists1
# @command manifest base exists <base>
# @summary The base directory exists: a comment line, else an error line
# @group   database
# @internal
# @see     manifest match
#@end
__manifest_base_exists1() {
        if test -d "$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'base $1 exists'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'manifest match: no such directory $1'"
        fi
}

#@help __manifest_tree_matches2
# @command manifest tree matches <manifest> <base>
# @summary No finding against the manifest: a log line with the entry count, else an error line carrying the findings
# @group   database
# @internal
# @see     manifest match
#@end
__manifest_tree_matches2() {
        local findings=""
        findings=$(manifest_tree_findings "$1" "$2")
        if test -z "$findings"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log 'manifest match: $(grep -cE "^[^ ]+ (sha256|symlink)=" "$1" 2>/dev/null) entries, tree matches'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'manifest match: $1 does not describe $2 (the TREE differs from what the sender listed)' $(sq "$(printf '%s' "$findings" | tr '\n' ';')")"
        fi
}
