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
#      `provenance serial` advances it, `dump` writes it into the header,
#      and `restore` refuses a serial below the highest receipt of the SAME
#      signer -- a validly signed old dump cannot reinstate a retired key
#      or a weakened expectation. A fresh database has no floor: the serial
#      protects a lineage, not a first import. An import raises the counter
#      to the imported serial, so a database that continues someone's
#      lineage (the rescue case) exports the next number, not 1.
#
# Everything read here is World the generator sees as-is -- serial,
# receipts, hashes -- and is read at generation time (the inspections
# serial_current, serial_floor, dump_header_field live in predicate.sh).

#-----------------------------------------------------------------------------
# _provenance_serial0 — advance the export serial
#-----------------------------------------------------------------------------

#@help _provenance_serial0
# @command provenance serial
# @summary Act terminal: advance the export serial by one (export does this before writing the dump); the number lands in the dump header
# @group   database
# @example elebake provenance serial
# @see     provenance list
# @see     export
#@end
_provenance_serial0() {
        emit_note "provenance serial: $(serial_current) -> $(($(serial_current) + 1))"
        printf '%s\n' "printf '%s\\n' '$(($(serial_current) + 1))' > '$ELEBAKE_BASE/export/serial' && $MODIFY_FILE_PERMS 0600 '$ELEBAKE_BASE/export/serial'"
}

#@help ___provenance_add2
# @command provenance add <dump> <bundle>
# @summary File the receipt of an admitted import: the dump readable, numbered, signed by the pinned signer and not a downgrade (restore's own checks), the bundle readable or '-'; then 'provenance receipt' (files it, or says it is filed, or refuses a differing one) and the export serial raised to the imported one
# @group   database
# @param   dump    the dump that was replayed
# @param   bundle  the bundle it came with ('-' for a dump replayed without one)
# @env     ELEBAKE_ARCHIVE_ATTEST_KEY  the openpgp record naming the signer the dump must carry
# @example elebake provenance add ~/git/config/dump.sh ~/.elebake/bundle/a1b2c3d.tar.gz
# @see     import
# @see     provenance list
# @see     restore v2
#@end
___provenance_add2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" dump readable '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" dump serial numbered '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" archive key pinned"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" restore signer admissible '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" restore serial admissible '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" provenance bundle readable '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" provenance receipt '$1' '$2'"
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

#@help __provenance_receipt2
# @command provenance receipt <dump> <bundle>
# @summary The receipt id is <serial>-<12 hex of the dump hash>. No receipt of that id yet: rewrite to 'provenance file ...', else to 'provenance receipt same ...' (filed already, or a differing one under the same id)
# @group   database
# @internal
# @see     provenance add
#@end
__provenance_receipt2() {
        local id=""
        id="$(printf '%06d' "$(dump_header_field "$1" Serial 2>/dev/null || echo 0)" 2>/dev/null)-$(sha256 -q "$1" 2>/dev/null | cut -c1-12)"
        if test ! -d "$ELEBAKE_BASE/provenance/$id"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" provenance file '$1' '$2'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" provenance receipt same '$1' '$2'"
        fi
}

#@help __provenance_receipt_same2
# @command provenance receipt same <dump> <bundle>
# @summary The filed receipt carries the same dump and bundle hashes: a note line (already filed, unchanged), else an error line (a receipt is immutable)
# @group   database
# @internal
# @see     provenance receipt
#@end
__provenance_receipt_same2() {
        local id="" dsum="" bsum=-
        dsum=$(sha256 -q "$1" 2>/dev/null)
        test "$2" = - || bsum=$(sha256 -q "$2" 2>/dev/null)
        id="$(printf '%06d' "$(dump_header_field "$1" Serial 2>/dev/null || echo 0)" 2>/dev/null)-$(printf '%s' "$dsum" | cut -c1-12)"
        if test "$(head -n1 "$ELEBAKE_BASE/provenance/$id/dump" 2>/dev/null)" = "$dsum" && test "$(head -n1 "$ELEBAKE_BASE/provenance/$id/bundle" 2>/dev/null)" = "$bsum"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" note 'provenance: receipt $id already filed (unchanged)'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'provenance add: receipt $id exists with different content (immutable)'"
        fi
}

#@help _provenance_file2
# @command provenance file <dump> <bundle>
# @summary Act terminal: the script that writes the receipt record provenance/<serial>-<hash12>/ (serial, signer, dump and bundle hashes, when, into which database, by whom; 0700/0600) and, when the imported serial is above this database's export serial, raises it (the lineage continues)
# @group   database
# @internal
# @see     provenance add
# @env     ELEBAKE_ARCHIVE_ATTEST_KEY  the openpgp record naming the signer the receipt records
#@end
_provenance_file2() {
        local serial="" fpr="" dsum="" bsum=- id="" rec="" cur=""
        serial=$(dump_header_field "$1" Serial 2>/dev/null)
        fpr=$(attest_signer "$1" "$(sed -n 1p "$ELEBAKE_BASE/openpgp/${ELEBAKE_ARCHIVE_ATTEST_KEY:-}/keyid" 2>/dev/null)" "$(sed -n 1p "$ELEBAKE_BASE/openpgp/${ELEBAKE_ARCHIVE_ATTEST_KEY:-}/gnupghome" 2>/dev/null)" 2>/dev/null)
        dsum=$(sha256 -q "$1" 2>/dev/null)
        test "$2" = - || bsum=$(sha256 -q "$2" 2>/dev/null)
        id="$(printf '%06d' "${serial:-0}" 2>/dev/null)-$(printf '%s' "$dsum" | cut -c1-12)"
        rec="$ELEBAKE_BASE/provenance/$id"
        cur=$(serial_current)
        emit_note "provenance: filing receipt $id (serial $serial, signer $fpr)"
        printf '%s\n' "$MODIFY_DIR_CREATE '$rec' && $MODIFY_FILE_PERMS 0700 '$rec'"
        printf '%s\n' "printf '%s\\n' '$serial' > '$rec/serial'"
        printf '%s\n' "printf '%s\\n' '$fpr' > '$rec/signer'"
        printf '%s\n' "printf '%s\\n' '$dsum' > '$rec/dump'"
        printf '%s\n' "printf '%s\\n' '$bsum' > '$rec/bundle'"
        printf '%s\n' "printf '%s\\n' '$(date -u '+%Y-%m-%dT%H:%M:%SZ')' > '$rec/restored'"
        printf '%s\n' "printf '%s\\n' '$(basename "$(readlink -f "$ELEBAKE_BASE")")' > '$rec/into'"
        printf '%s\n' "printf '%s\\n' '$(id -un)@$(hostname)' > '$rec/by'"
        printf '%s\n' "$MODIFY_FILE_PERMS 0600 '$rec'/*"
        if test "${serial:-0}" -gt "$cur"; then
                printf '%s\n' "printf '%s\\n' '$serial' > '$ELEBAKE_BASE/export/serial' && $MODIFY_FILE_PERMS 0600 '$ELEBAKE_BASE/export/serial'"
                emit_note "provenance: export serial raised $cur -> $serial"
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

#@help _provenance_list0
# @command provenance list
# @summary Text terminal: the export serial and every receipt -- serial, when, signer, dump and bundle hashes, into which database, by whom; none is said so
# @group   database
# @example elebake provenance list
# @see     provenance add
# @see     import
#@end
_provenance_list0() {
        local r="" n=0
        printf '# export serial: %s\n' "$(serial_current)"
        printf '# receipts (serial  restored  signer  dump  bundle  into  by)\n'
        for r in "$ELEBAKE_BASE"/provenance/*/; do
                test -d "$r" || continue
                n=$((n + 1))
                printf '#   %6s  %s  %s  %s  %s  %s  %s\n' "$(head -n1 "$r/serial" 2>/dev/null)" "$(head -n1 "$r/restored" 2>/dev/null)" "$(head -n1 "$r/signer" 2>/dev/null | cut -c25-)" "$(head -n1 "$r/dump" 2>/dev/null | cut -c1-12)" "$(head -n1 "$r/bundle" 2>/dev/null | cut -c1-12)" "$(head -n1 "$r/into" 2>/dev/null)" "$(head -n1 "$r/by" 2>/dev/null)"
        done
        test "${n:-0}" -gt 0 || printf '#   (no receipts -- this database was never the target of an import)\n'
}
