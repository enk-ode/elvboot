#!/bin/sh
#
# Copyright (c) 2026 Dr. Johannes Brügmann
#
# SPDX-License-Identifier: BSD-2-Clause
#
# provenance — where a database came from, and how far its lineage has got.
#
# Two things live here, both plain records under provenance/:
#
#   1. The RECEIPT. Every ADMITTED import files one record naming the
#      dump (sha256), the bundle (sha256), the signer (fingerprint), the
#      serial and when/where it was admitted. Admitted means: signatures
#      good and pinned, seal good, MANIFEST good, serial at or above the
#      lineage's floor -- the receipt is filed right before the replay,
#      because the replay itself runs keep-going (a redacted pair
#      legitimately reports withheld elements) and must not decide whether
#      the pair was genuine. Receipts are collected like any other record,
#      so the NEXT export carries them: a database can be asked where it
#      came from instead of being taken at its word.
#
#   2. The SERIAL. export/serial holds the number the last export carried;
#      `dump` writes the next one (current+1) into the header, `provenance
#      serial` advances it once the export succeeded,
#      and `restore` refuses a serial below the highest receipt of the SAME
#      signer -- a validly signed old dump cannot reinstate a retired key
#      or a weakened expectation. A fresh database has no floor: the serial
#      protects a lineage, not a first import. An import raises the counter
#      to the imported serial, so a database that continues someone's
#      lineage (the rescue case) exports the next number, not 1.
#
# Everything read here is World the generator sees as-is -- serial,
# receipts, hashes -- read at generation time, ONCE, at the entry of a
# command, and handed down as arguments: 'provenance add <dump> <bundle>'
# reads the dump's serial, the pinned key, the signer, the signer's floor
# and this database's serial, stage by stage, and the batch at the end
# reads nothing any more.

#-----------------------------------------------------------------------------
# provenance serial — advance the export serial
#-----------------------------------------------------------------------------

#@help __provenance_serial0
# @command provenance serial
# @summary Advance the export serial by one: the number read here, then 'provenance serial <current>' -- export does this LAST, once the pair is attested: the dump header already carries current+1, so a failed export leaves the number to the next attempt (serials were once lost to a pinentry that could not open)
# @group   database
# @example elebake provenance serial
# @see     provenance list
# @see     export
#@end
__provenance_serial0() {
        local cur=""
        cur=$(head -n1 "$ELEBAKE_BASE/export/serial" 2>/dev/null)
        case "$cur" in ''|*[!0-9]*) cur=0 ;; esac
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" provenance serial '$cur'"
}

#@help _provenance_serial1
# @internal 'provenance serial <current>': Act terminal: write <current>+1 into export/serial (0600)
#@end
_provenance_serial1() {
        emit_note "provenance serial: $1 -> $(($1 + 1))"
        printf '%s\n' "printf '%s\\n' '$(($1 + 1))' > '$ELEBAKE_BASE/export/serial' && $MODIFY_FILE_PERMS 0600 '$ELEBAKE_BASE/export/serial'"
}

#@help __provenance_add2
# @command provenance add <dump> <bundle>
# @summary File the receipt of an admitted import. Every detail read ONCE on the way in and handed down -- the dump's serial, the pinned key, the signer (gpg once), the signer's floor, this database's serial -- then 'provenance add <dump> <bundle> <serial> <key> <fpr> <floor> <cur>': the bundle readable or '-', the serial not a downgrade, 'provenance receipt' (files it, or says it is filed, or refuses a differing one) and the export serial raised to the imported one
# @group   database
# @param   dump    the dump that was replayed
# @param   bundle  the bundle it came with ('-' for a dump replayed without one)
# @env     ELEBAKE_ARCHIVE_ATTEST_KEY  the openpgp record naming the signer the dump must carry
# @example elebake provenance add ~/git/config/dump.sh ~/.elebake/bundle/a1b2c3d.tar.gz
# @see     provenance list
# @see     import
#@end
__provenance_add2() {
        local serial=""
        serial=$(sed -n 's/^# Serial: //p' "$1" 2>/dev/null | head -n1)
        if ! test -r "$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'provenance add: dump file not found or not readable: $1'"
        elif printf '%s\n' "$serial" | grep -qx '[0-9][0-9]*'; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" provenance add '$1' '$2' '$serial'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'provenance add: dump carries no numeric # Serial: header: $1'"
        fi
}

#@help __provenance_add3
# @internal 'provenance add <dump> <bundle> <serial>': the pinned attest key -> 'provenance add ... <key>', else an error line
# @env     ELEBAKE_ARCHIVE_ATTEST_KEY  the openpgp record naming the pinned signer
#@end
__provenance_add3() {
        local key="${ELEBAKE_ARCHIVE_ATTEST_KEY:-}" keyid=""
        keyid=$(head -n1 "$ELEBAKE_BASE/openpgp/${key:-.}/keyid" 2>/dev/null | sed 's/^0[xX]//' | tr 'a-f' 'A-F')
        case "$keyid" in
                ????????????????*) case "$keyid" in *[!0-9A-F]*) keyid="" ;; esac ;;
                *) keyid="" ;;
        esac
        if test -n "$key" && test -n "$keyid"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" provenance add '$1' '$2' '$3' '$key'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'ELEBAKE_ARCHIVE_ATTEST_KEY not set or its openpgp record incomplete (a keyid of 16+ hex digits; openpgp add <name> <fingerprint>; setenv ELEBAKE_ARCHIVE_ATTEST_KEY <name>)'"
        fi
}

#@help __provenance_add4
# @internal 'provenance add <dump> <bundle> <serial> <key>': the signer of <dump>.asc, gpg once -> 'provenance add ... <fpr>', else an error line with the reason
#@end
__provenance_add4() {
        local keyid="" gh="" status="" fpr="" pfpr="" why=""
        keyid=$(head -n1 "$ELEBAKE_BASE/openpgp/$4/keyid" 2>/dev/null | sed 's/^0[xX]//' | tr 'a-f' 'A-F')
        gh=$(head -n1 "$ELEBAKE_BASE/openpgp/$4/gnupghome" 2>/dev/null)
        if ! test -f "$1.asc"; then
                why="unsigned: no $1.asc"
        elif test -n "$gh"; then
                status=$(GNUPGHOME="$gh" gpg --batch --status-fd 1 --verify "$1.asc" "$1" 2>>"${LOG_FILE:-/dev/null}")
        else
                status=$(gpg --batch --status-fd 1 --verify "$1.asc" "$1" 2>>"${LOG_FILE:-/dev/null}")
        fi
        printf '%s\n' "$status" >>"${LOG_FILE:-/dev/null}"
        fpr=$(printf '%s\n' "$status" | awk '/^\[GNUPG:\] VALIDSIG /{print $3; exit}')
        pfpr=$(printf '%s\n' "$status" | awk '/^\[GNUPG:\] VALIDSIG /{print $NF; exit}')
        test -n "$why" || case "$status" in
                *"[GNUPG:] NO_PUBKEY"*) why="signer public key not in the keyring${gh:+ $gh}" ;;
                *"[GNUPG:] BADSIG"*)    why="BAD SIGNATURE -- file or signature altered" ;;
                *"[GNUPG:] REVKEYSIG"*) why="signed by a REVOKED key" ;;
                *"[GNUPG:] EXPKEYSIG"*) why="signed by an EXPIRED key" ;;
                *"[GNUPG:] EXPSIG"*)    why="signature itself has expired" ;;
                *"[GNUPG:] GOODSIG"*)   case "$fpr|$pfpr|" in *"$keyid|"*) ;; *) why="signed by a DIFFERENT key: $fpr (expected ...$keyid)" ;; esac ;;
                *) why="no good signature (see the log for gpg status)" ;;
        esac
        if test -z "$why"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" provenance add '$1' '$2' '$3' '$4' '$fpr'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error $(sq "provenance add: $why") '(file $1, expected signer: openpgp record $4)'"
        fi
}

#@help __provenance_add5
# @internal 'provenance add <dump> <bundle> <serial> <key> <fpr>': the signer's highest receipt here -> 'provenance add ... <floor>'
#@end
__provenance_add5() {
        local r="" s="" floor=0
        for r in "$ELEBAKE_BASE"/provenance/*/; do
                test "$(head -n1 "$r/signer" 2>/dev/null)" = "$5" || continue
                s=$(head -n1 "$r/serial" 2>/dev/null)
                case "$s" in ''|*[!0-9]*) continue ;; esac
                test "$s" -le "$floor" || floor=$s
        done
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" provenance add '$1' '$2' '$3' '$4' '$5' '$floor'"
}

#@help __provenance_add6
# @internal 'provenance add <dump> <bundle> <serial> <key> <fpr> <floor>': this database's export serial -> 'provenance add ... <cur>'
#@end
__provenance_add6() {
        local cur=""
        cur=$(head -n1 "$ELEBAKE_BASE/export/serial" 2>/dev/null)
        case "$cur" in ''|*[!0-9]*) cur=0 ;; esac
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" provenance add '$1' '$2' '$3' '$4' '$5' '$6' '$cur'"
}

#@help ___provenance_add7
# @internal the receipt with every detail read: bundle readable, serial admissible, provenance receipt
#@end
___provenance_add7() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" provenance bundle readable '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" restore serial admissible '$3' '$6' '$5'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" provenance receipt '$1' '$2' '$3' '$5' '$7'"
}

#@help __provenance_bundle_readable1
# @command provenance bundle readable <bundle>
# @summary The bundle is '-' (a dump replayed without one) or a readable file: a comment line, else an error line
# @group   database
# @internal
# @see     provenance add
#@end
__provenance_bundle_readable1() {
        if test "$1" = - || test -r "$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'bundle $1 readable'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'provenance add: no such bundle $1'"
        fi
}

#@help __provenance_receipt5
# @internal 'provenance receipt <dump> <bundle> <serial> <fpr> <cur>': The receipt id is <serial>-<12 hex of the dump hash>. No receipt of that id yet: rewrite to 'provenance file ...', else to 'provenance receipt same ...' (filed already, or a differing one under the same id)
#@end
__provenance_receipt5() {
        local id=""
        id="$(printf '%06d' "$3")-$(sha256 -q "$1" 2>/dev/null | cut -c1-12)"
        if test ! -d "$ELEBAKE_BASE/provenance/$id"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" provenance file '$1' '$2' '$3' '$4' '$5'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" provenance receipt same '$1' '$2' '$3'"
        fi
}

#@help __provenance_receipt_same3
# @internal 'provenance receipt same <dump> <bundle> <serial>': The filed receipt carries the same dump and bundle hashes: a note line (already filed, unchanged), else an error line (a receipt is immutable)
#@end
__provenance_receipt_same3() {
        local id="" dsum="" bsum=-
        dsum=$(sha256 -q "$1" 2>/dev/null)
        test "$2" = - || bsum=$(sha256 -q "$2" 2>/dev/null)
        id="$(printf '%06d' "$3")-$(printf '%s' "$dsum" | cut -c1-12)"
        if test "$(head -n1 "$ELEBAKE_BASE/provenance/$id/dump" 2>/dev/null)" = "$dsum" && test "$(head -n1 "$ELEBAKE_BASE/provenance/$id/bundle" 2>/dev/null)" = "$bsum"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" note 'provenance: receipt $id already filed (unchanged)'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'provenance add: receipt $id exists with different content (immutable)'"
        fi
}

#@help _provenance_file5
# @internal 'provenance file <dump> <bundle> <serial> <fpr> <cur>': Act terminal: the script that writes the receipt record provenance/<serial>-<hash12>/ (serial, signer, dump and bundle hashes, when, into which database, by whom; 0700/0600) and, when the imported serial is above this database's export serial <cur>, raises it (the lineage continues)
#@end
_provenance_file5() {
        local dsum="" bsum=- id="" rec=""
        dsum=$(sha256 -q "$1" 2>/dev/null)
        test "$2" = - || bsum=$(sha256 -q "$2" 2>/dev/null)
        id="$(printf '%06d' "$3")-$(printf '%s' "$dsum" | cut -c1-12)"
        rec="$ELEBAKE_BASE/provenance/$id"
        emit_note "provenance: filing receipt $id (serial $3, signer $4)"
        printf '%s\n' "$MODIFY_DIR_CREATE '$rec' && $MODIFY_FILE_PERMS 0700 '$rec'"
        printf '%s\n' "printf '%s\\n' '$3' > '$rec/serial'"
        printf '%s\n' "printf '%s\\n' '$4' > '$rec/signer'"
        printf '%s\n' "printf '%s\\n' '$dsum' > '$rec/dump'"
        printf '%s\n' "printf '%s\\n' '$bsum' > '$rec/bundle'"
        printf '%s\n' "printf '%s\\n' '$(date -u '+%Y-%m-%dT%H:%M:%SZ')' > '$rec/restored'"
        printf '%s\n' "printf '%s\\n' '$(basename "$(readlink -f "$ELEBAKE_BASE")")' > '$rec/into'"
        printf '%s\n' "printf '%s\\n' '$(id -un)@$(hostname)' > '$rec/by'"
        printf '%s\n' "$MODIFY_FILE_PERMS 0600 '$rec'/*"
        if test "$3" -gt "$5"; then
                printf '%s\n' "printf '%s\\n' '$3' > '$ELEBAKE_BASE/export/serial' && $MODIFY_FILE_PERMS 0600 '$ELEBAKE_BASE/export/serial'"
                emit_note "provenance: export serial raised $5 -> $3"
        fi
        emit_note "receipt filed: provenance/$id"
}

#@help ___provenance_import2
# @command provenance import <id> <absfile>
# @summary Copy ONE file of a receipt record from another database (dump/restore base element; the record directory is created on first file): the id is a record name, the source exists; then 'provenance import place'
# @group   database
# @param   id       the receipt record name (<serial>-<dump hash prefix>)
# @param   absfile  absolute source path in the OTHER database
# @see     provenance dump
# @see     restore
#@end
___provenance_import2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" provenance id valid '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" base element exists '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" provenance import place '$1' '$2'"
}

#@help __provenance_id_valid1
# @command provenance id valid <id>
# @summary The receipt id is a record name: a comment line, else an error line
# @group   database
# @internal
# @see     provenance import
#@end
__provenance_id_valid1() {
        if record_name_ok "$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'receipt id $1 valid'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'provenance import: invalid receipt id $1'"
        fi
}

#@help __provenance_import_place2
# @command provenance import place <id> <absfile>
# @summary The source is not already this element (a dump replayed against its OWN database): rewrite to 'provenance import copy', else a note line
# @group   database
# @internal
# @see     provenance import
#@end
__provenance_import_place2() {
        if test "$2" != "$ELEBAKE_BASE/provenance/$1/${2##*/}"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" provenance import copy '$1' '$2'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" note 'provenance import $1: ${2##*/} is already this element'"
        fi
}

#@help _provenance_import_copy2
# @command provenance import copy <id> <absfile>
# @summary Act terminal: the record directory (0700), rm -f and cp -Pp of the file
# @group   database
# @internal
# @see     provenance import
#@end
_provenance_import_copy2() {
        printf '%s\n' "$MODIFY_DIR_CREATE '$ELEBAKE_BASE/provenance/$1' && $MODIFY_FILE_PERMS 0700 '$ELEBAKE_BASE/provenance/$1'"
        printf '%s\n' "rm -f '$ELEBAKE_BASE/provenance/$1/${2##*/}' && cp -Pp '$2' '$ELEBAKE_BASE/provenance/$1/' || { printf '# Error: provenance import failed\\n' >&2; exit 1; }"
}

#@help ___provenance_dump0
# @command provenance dump
# @summary Emit the provenance portion of a database dump: one 'provenance import' line per receipt file (cat-pinned: dump TEXT, replayed by restore); none is a comment line
# @group   database
# @env     ELEBAKE_ARCHIVE_BASE  the prefix the emitted paths are written against
# @see     dump
#@end
___provenance_dump0() {
        local r="" f="" n=0
        for r in "$ELEBAKE_BASE"/provenance/*/; do
                test -d "$r" || continue
                n=$((n + 1))
                for f in "$r"*; do
                        test -f "$f" || continue
                        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" provenance import '$(basename "$r")' \"\$ELEBAKE_ARCHIVE_BASE/${f#"$ELEBAKE_BASE/"}\""
                done
        done
        test "${n:-0}" -gt 0 || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'no receipts to dump'"
}

#@help _provenance_collect0
# @command provenance collect
# @summary Text terminal: the receipt record files that belong into an archive, by their real path against "$ELEBAKE_ARCHIVE_BASE"
# @group   database
# @env     ELEBAKE_ARCHIVE_BASE  the prefix the emitted paths are written against
# @see     collect
#@end
_provenance_collect0() {
        printf '# provenance\n'
        find "$ELEBAKE_BASE/provenance" \( -type f -o -type l \) 2>/dev/null | sort | sed "s|^$ELEBAKE_BASE/|\"\$ELEBAKE_ARCHIVE_BASE\"/|"
}

#@help __provenance_list0
# @command provenance list
# @summary The export serial and every receipt: the serial read here, then 'provenance list <serial>' renders
# @group   database
# @example elebake provenance list
# @see     provenance add
# @see     import
#@end
__provenance_list0() {
        local cur=""
        cur=$(head -n1 "$ELEBAKE_BASE/export/serial" 2>/dev/null)
        case "$cur" in ''|*[!0-9]*) cur=0 ;; esac
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" provenance list '$cur'"
}

#@help _provenance_list1
# @internal 'provenance list <serial>': Text terminal: the export serial handed down and every receipt -- serial, when, signer, dump and bundle hashes, into which database, by whom; none is said so
#@end
_provenance_list1() {
        local r="" n=0
        printf '# export serial: %s\n' "$1"
        printf '# receipts (serial  restored  signer  dump  bundle  into  by)\n'
        for r in "$ELEBAKE_BASE"/provenance/*/; do
                test -d "$r" || continue
                n=$((n + 1))
                printf '#   %6s  %s  %s  %s  %s  %s  %s\n' "$(head -n1 "$r/serial" 2>/dev/null)" "$(head -n1 "$r/restored" 2>/dev/null)" "$(head -n1 "$r/signer" 2>/dev/null | cut -c25-)" "$(head -n1 "$r/dump" 2>/dev/null | cut -c1-12)" "$(head -n1 "$r/bundle" 2>/dev/null | cut -c1-12)" "$(head -n1 "$r/into" 2>/dev/null)" "$(head -n1 "$r/by" 2>/dev/null)"
        done
        test "${n:-0}" -gt 0 || printf '#   (no receipts -- this database was never the target of an import)\n'
}
