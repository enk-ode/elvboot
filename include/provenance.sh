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
# ARCHITECTURE: TERMINALS emit ONLY shell. Everything read here is World the
# generator sees as-is -- serial, receipts, hashes -- and is read at
# generation time.

# serial_current — the number the last export carried (0 = never exported)
serial_current() {
  local f="$ELEBAKE_BASE/export/serial" n
  [ -f "$f" ] && n=$(head -n1 "$f") || n=0
  case "$n" in ''|*[!0-9]*) n=0 ;; esac
  printf '%s\n' "$n"
}

# serial_floor <fingerprint> — highest serial among the receipts of ONE signer
serial_floor() {
  local fpr="$1" r s floor=0
  for r in "$ELEBAKE_BASE"/provenance/*/; do
    [ -f "$r/serial" ] && [ -f "$r/signer" ] || continue
    [ "$(head -n1 "$r/signer")" = "$fpr" ] || continue
    s=$(head -n1 "$r/serial")
    case "$s" in ''|*[!0-9]*) continue ;; esac
    [ "$s" -gt "$floor" ] && floor=$s
  done
  printf '%s\n' "$floor"
}

# dump_header_field <dump> <Name> — the value of a '# Name: value' header line
dump_header_field() {
  sed -n "s/^# $2: //p" "$1" | head -n1
}

#-----------------------------------------------------------------------------
# _provenance_serial0 — advance the export serial
#-----------------------------------------------------------------------------
#@help _provenance_serial0
# @command provenance serial
# @summary Advance the export serial by one (export does this before writing the dump); the number lands in the dump header
# @group   database
# @returns the shell that writes export/serial
# @example elebake provenance serial | sh
# @see     provenance list
#@end
_provenance_serial0() {
  local cur next
  cur=$(serial_current)
  next=$((cur + 1))
  emit_note "provenance serial: $cur -> $next"
  printf '%s\n' "printf '%s\\n' '$next' > '$ELEBAKE_BASE/export/serial' && $MODIFY_FILE_PERMS 0600 '$ELEBAKE_BASE/export/serial'"
}

#-----------------------------------------------------------------------------
# _provenance_add2 <dump> <bundle> — the receipt of an import
#-----------------------------------------------------------------------------
# Called by `import` after every check and right BEFORE restore: the batch
# machinery guarantees it never runs for a pair that failed a check, and the
# admissibility it applies is restore's own (restore_admissible: format,
# pinned signer, serial floor) -- a downgrade leaves no receipt. The facts
# are read now and written as one record. Re-filing the same receipt is a
# silent no-op; a differing receipt under the same id is refused.
#@help _provenance_add2
# @command provenance add <dump> <bundle>
# @summary File the receipt of an admitted import: dump and bundle hashes, pinned signer, serial, when and where -- same admissibility as restore -- and raise the export serial to the imported one
# @group   database
# @param   dump    the dump that was replayed
# @param   bundle  the bundle it came with ('-' for a dump replayed without one)
# @env     ELEBAKE_ARCHIVE_ATTEST_KEY  the openpgp record naming the signer the dump must carry
# @returns the shell that writes the receipt record
# @example elebake provenance add ~/git/config/dump.sh ~/.elebake/bundle/a1b2c3d.tar.gz
# @see     import
# @see     provenance list
#@end
_provenance_add2() {
  local dump="$1" bundle="$2" key="${ELEBAKE_ARCHIVE_ATTEST_KEY:-}" base="$ELEBAKE_BASE"
  local fpr serial dsum bsum id rec stamp by cur into line
  fpr=$(restore_admissible "$dump") || { generate_error "provenance add: $fpr"; return 0; }
  serial=$(dump_header_field "$dump" Serial)
  dsum=$(sha256 -q "$dump" 2>>"$LOG_FILE") || { generate_error "provenance add: cannot hash $dump"; return 0; }
  if [ "$bundle" = "-" ]; then
    bsum="-"
  else
    [ -f "$bundle" ] || { generate_error "provenance add: no such bundle '$bundle'"; return 0; }
    bsum=$(sha256 -q "$bundle" 2>>"$LOG_FILE") || { generate_error "provenance add: cannot hash $bundle"; return 0; }
  fi
  id="$(printf '%06d' "$serial")-$(printf '%s' "$dsum" | cut -c1-12)"
  rec="$base/provenance/$id"
  stamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>>"$LOG_FILE")
  by="$(id -un 2>>"$LOG_FILE")@$(hostname 2>>"$LOG_FILE")"
  into=$(db_real_name)
  if [ -d "$rec" ]; then
    if [ "$(head -n1 "$rec/dump" 2>/dev/null)" = "$dsum" ] && [ "$(head -n1 "$rec/bundle" 2>/dev/null)" = "$bsum" ]; then
      emit_note "provenance: receipt $id already filed (unchanged)"; return 0
    fi
    generate_error "provenance add: receipt '$id' exists with different content (immutable)"; return 0
  fi
  emit_note "provenance: filing receipt $id (serial $serial, signer $fpr)"
  printf '%s\n' "$MODIFY_DIR_CREATE '$rec' && $MODIFY_FILE_PERMS 0700 '$rec'"
  for line in "serial:$serial" "signer:$fpr" "dump:$dsum" "bundle:$bsum" "restored:$stamp" "into:$into" "by:$by"; do
    printf '%s\n' "printf '%s\\n' '${line#*:}' > '$rec/${line%%:*}'"
  done
  printf '%s\n' "$MODIFY_FILE_PERMS 0600 '$rec'/*"
  # continue the lineage: the next export of THIS database numbers above
  # what it just absorbed
  cur=$(serial_current)
  if [ "$serial" -gt "$cur" ]; then
    printf '%s\n' "printf '%s\\n' '$serial' > '$base/export/serial' && $MODIFY_FILE_PERMS 0600 '$base/export/serial'"
    emit_note "provenance: export serial raised $cur -> $serial"
  fi
  printf '%s\n' "printf '# receipt filed: provenance/%s\\n' '$id' >&2"
}

#-----------------------------------------------------------------------------
# _provenance_import2 <id> <absfile> — base element of a dump
#-----------------------------------------------------------------------------
#@help _provenance_import2
# @command provenance import <id> <absfile>
# @summary Copy ONE file of a receipt record from another database -- dump/restore base element; the record directory is created on first file
# @group   database
# @param   id       the receipt record name (<serial>-<dump hash prefix>)
# @param   absfile  absolute source path in the OTHER database
# @see     provenance dump
#@end
_provenance_import2() {
  local id="$1" src="$2" base="$ELEBAKE_BASE" dst
  case "$id" in
    ""|*/*|.|..|*[!A-Za-z0-9_.-]*)
      generate_error "provenance import: invalid receipt id '$id'"; return 0 ;;
  esac
  { [ -f "$src" ] || [ -L "$src" ]; } || {
    generate_error "provenance import: no such file: $src"; return 0; }
  dst="$base/provenance/$id/$(basename "$src")"
  if [ "$src" = "$dst" ]; then
    emit_note "provenance import '$id': $(basename "$src") is already this element"; return 0
  fi
  printf '%s\n' "$MODIFY_DIR_CREATE '$base/provenance/$id' && $MODIFY_FILE_PERMS 0700 '$base/provenance/$id'"
  printf '%s\n' "rm -f '$dst' && cp -Pp '$src' '$base/provenance/$id/' || { printf '# Error: provenance import failed\\n' >&2; exit 1; }"
}

#-----------------------------------------------------------------------------
# ___provenance_dump0 — the receipts as base elements (cat-pinned)
#-----------------------------------------------------------------------------
#@help ___provenance_dump0
# @command provenance dump
# @summary Emit the provenance portion of a database dump: one 'provenance import' line per receipt file (cat-pinned: dump TEXT, replayed by restore)
# @env     ELEBAKE_ARCHIVE_BASE  the prefix the emitted paths are written against
# @group   database
# @see     dump
#@end
___provenance_dump0() {
  local base="$ELEBAKE_BASE" r f n=0
  for r in "$base"/provenance/*/; do
    [ -d "$r" ] || continue
    n=$((n+1))
    for f in "$r"*; do
      [ -f "$f" ] || continue
      printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" provenance import '$(basename "$r")' \"\$ELEBAKE_ARCHIVE_BASE/${f#"$base/"}\""
    done
  done
  [ "$n" -gt 0 ] || printf '%s\n' "# (no receipts to dump)"
}

#-----------------------------------------------------------------------------
# _provenance_collect0 — the receipt files that belong into an archive
#-----------------------------------------------------------------------------
#@help _provenance_collect0
# @command provenance collect
# @summary List the receipt record files that belong into an archive
# @env     ELEBAKE_ARCHIVE_BASE  the prefix the emitted paths are written against
# @group   database
# @see     collect
#@end
_provenance_collect0() {
  local base="$ELEBAKE_BASE" f
  printf '# provenance\n'
  [ -d "$base/provenance" ] || return 0
  find "$base/provenance" \( -type f -o -type l \) 2>/dev/null | sort | while IFS= read -r f; do
    printf '"$ELEBAKE_ARCHIVE_BASE"/%s\n' "${f#"$base/"}"
  done
}

#-----------------------------------------------------------------------------
# _provenance_list0 — the lineage, readable
#-----------------------------------------------------------------------------
#@help _provenance_list0
# @command provenance list
# @summary Show the export serial and every receipt: serial, when, signer, dump and bundle hashes, into which database
# @group   database
# @example elebake provenance list
# @see     provenance add
#@end
_provenance_list0() {
  local base="$ELEBAKE_BASE" r n=0
  printf '# export serial: %s\n' "$(serial_current)"
  printf '# receipts (serial  restored  signer  dump  bundle  into  by)\n'
  for r in "$base"/provenance/*/; do
    [ -d "$r" ] || continue
    n=$((n+1))
    printf '#   %6s  %s  %s  %s  %s  %s  %s\n' \
      "$(head -n1 "$r/serial" 2>/dev/null)" "$(head -n1 "$r/restored" 2>/dev/null)" \
      "$(head -n1 "$r/signer" 2>/dev/null | cut -c25-)" "$(head -n1 "$r/dump" 2>/dev/null | cut -c1-12)" \
      "$(head -n1 "$r/bundle" 2>/dev/null | cut -c1-12)" "$(head -n1 "$r/into" 2>/dev/null)" "$(head -n1 "$r/by" 2>/dev/null)"
  done
  [ "$n" -gt 0 ] || printf '#   (no receipts -- this database was never the target of an import)\n'
}
