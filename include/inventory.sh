#!/bin/sh
#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Dr. Johannes Brügmann
# elebake inventory - the SETS the loader's platform claims measure.
#
# AcpiTables, EfiVariables and LoadedImages claim a set the stage names -- add semantics,
# never an exclusion (JB 12.09.): what is not added is listed, not claimed.
# The loader publishes every item it saw, one entry with an 8-hex digest,
# as loader.trust.list.<kind>.<n>; elvbootd's inventory_record_act files
# them per boot under /var/db/elvboot/inventory/<boot time>. From there:
#
#   inventory/records/<boot time>   the lists of one boot, root's copy
#                                   fetched by stage inventory import
#   inventory/<kind>                the set: one entry per line, added by
#                                   stage inventory add; <kind> is acpi
#                                   (<signature>/<OEM table id>), efivars
#                                   (<guid's first word>/<name>) or images
#                                   (fv/<guid word>, file/<name>, dp/<8 hex>)
#
# stage inventory show lays the records side by side -- an item's digest per
# boot, how many boots agree, whether it is in the set -- so the owner sees
# what the firmware rewrites before deciding. stage inventory make renders
# the sets as LOADER_TRUST_<KIND>_SET into site.mk (a part of stage site mk),
# sorted, so the digest the loader computes over the members does not depend
# on the order of adding. That digest is then learned like any other (stage
# baseline learn LOADER_TRUST_<KIND>_DIGEST ...). The dump replays the
# entries, never the records: observations are imported again, not restored.

#@help ___stage_inventory_import1
# @command stage inventory import <stage>
# @summary Fetch the per-boot lists elvbootd filed under /var/db/elvboot/inventory (root's, written by inventory_record_act in STARTUP) into the stage's inventory/records/, owned by the database's owner: the stage exists, then the copy (pinned sudo sh). Run it after every boot whose lists you want to compare
# @group   provisioning
# @example elebake stage inventory import daily-v1
# @see     stage inventory show
#@end
___stage_inventory_import1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage inventory import fetch '$1'"
}

#@help _stage_inventory_import_fetch1
# @command stage inventory import fetch <stage>
# @summary Act terminal: the script that copies /var/db/elvboot/inventory/* into inventory/records/ of the stage, hands the directory to the database's owner (0700, files 0600) and reports the count. Pinned sudo sh: the source is root's
# @group   provisioning
# @internal
# @see     stage inventory import
#@end
_stage_inventory_import_fetch1() {
        cat <<EOF
d='$ELEBAKE_BASE/stage/$1/inventory/records'; n=0; mkdir -p "\$d" || exit 1
for f in /var/db/elvboot/inventory/*; do test -f "\$f" || continue; cp "\$f" "\$d/" || exit 1; n=\$((n + 1)); done
chown -R "\$(stat -f %u:%g '$ELEBAKE_BASE')" '$ELEBAKE_BASE/stage/$1/inventory'; chmod 0700 "\$d"; chmod 0600 "\$d"/* 2>/dev/null
printf '# inventory import $1: %s record(s) under inventory/records/\\n' "\$n"
EOF
}

#@help ___stage_inventory_show2
# @command stage inventory show <stage> <kind>
# @summary Lay the imported records side by side for one kind (acpi | efivars | images): per item its identity, size, for efivars the attributes in words, in how many boots it appeared, whether every boot saw the same digest (same) or not (MOVES), whether it is in the set (+), and the digest of each boot, oldest first. What moves is what the firmware rewrites: leave it out of the set
# @group   provisioning
# @example elebake stage inventory show daily-v1 efivars
# @see     stage inventory import
# @see     stage inventory add
#@end
___stage_inventory_show2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage inventory kind valid '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage inventory show head '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage inventory show rows '$1' '$2'"
}

#@help __stage_inventory_kind_valid1
# @command stage inventory kind valid <kind>
# @summary The kind is acpi, efivars or images, the three lists the loader publishes: a comment line, else an error line
# @group   provisioning
# @internal
# @see     stage inventory show
#@end
__stage_inventory_kind_valid1() {
        if test "$1" = acpi || test "$1" = efivars || test "$1" = images; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'inventory kind $1'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage inventory: the kind is acpi, efivars or images, not $1'"
        fi
}

#@help _stage_inventory_show_head2
# @command stage inventory show head <stage> <kind>
# @summary Text terminal: the two header lines of the table -- the records imported (count, oldest .. newest) and the size of the set, then the column names; without a record the one line naming the remedy (stage inventory import after a boot)
# @group   provisioning
# @internal
# @see     stage inventory show
#@end
_stage_inventory_show_head2() {
        local dir="$ELEBAKE_BASE/stage/$1/inventory" n=0 first="" last=""
        n=$(ls "$dir/records" 2>/dev/null | grep -c .)
        first=$(ls "$dir/records" 2>/dev/null | sort | sed -n 1p); last=$(ls "$dir/records" 2>/dev/null | sort | sed -n '$p')
        test "$n" -eq 0 && printf '# inventory %s of %s: no record imported (stage inventory import after a boot)\n' "$2" "$1"
        test "$n" -gt 0 && printf '# inventory %s of %s: %s record(s), %s .. %s; set: %s entries\n' "$2" "$1" "$n" "$first" "$last" "$(grep -c . "$dir/$2" 2>/dev/null || echo 0)"
        test "$n" -gt 0 && printf '# %-42s %7s %-14s %5s %-5s %s %s\n' identity size attrs boots agree set 'digests (oldest .. newest)'
}

#@help _stage_inventory_show_rows2
# @command stage inventory show rows <stage> <kind>
# @summary Text terminal: one row per item over inventory/records/* of the stage for one kind, sorted by identity (identity, size, attributes for efivars in words, boots seen/records, same or MOVES, + when in the set, the digests oldest .. newest) -- template/awk/inventory-rows.awk
# @env     ELEBAKE_TEMPLATE_DIR  the template directory (awk programs, tables)
# @group   provisioning
# @internal
# @see     stage inventory show head
#@end
_stage_inventory_show_rows2() {
        local dir="$ELEBAKE_BASE/stage/$1/inventory" set=""
        set=$(cat "$dir/$2" 2>/dev/null | tr '\n' ' ')
        ls "$dir/records" 2>/dev/null | sort | sed "s|^|$dir/records/|" | awk -v kind="$2" -v set=" $set " -f "$ELEBAKE_TEMPLATE_DIR/awk/inventory-rows.awk" | sort
}

#@help ___stage_inventory_add3
# @command stage inventory add <stage> <kind> <entry>
# @summary Take one item into the set of a kind: the stage exists, the kind is acpi, efivars or images, the entry has the identity form (<a>/<b>, letters, digits, _ . -), the newest imported record lists it (the loader saw it -- stage inventory import first), then it is appended to inventory/<kind> unless already there. The set is what AcpiTables / EfiVariables measure; after a change: stage site mk, build, boot, then learn the digest
# @group   provisioning
# @example elebake stage inventory add daily-v1 efivars 8be4df61/BootOrder
# @see     stage inventory show
# @see     stage inventory make
#@end
___stage_inventory_add3() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage inventory kind valid '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage inventory entry valid '$3'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage inventory entry listed '$1' '$2' '$3'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage inventory entry write '$1' '$2' '$3'"
}

#@help __stage_inventory_entry_valid1
# @command stage inventory entry valid <entry>
# @summary The entry is an identity as the loader lists them, <a>/<b> of letters, digits, _ . and - (no comma, no blank, no colon): a comment line, else an error line
# @group   provisioning
# @internal
# @see     stage inventory add
#@end
__stage_inventory_entry_valid1() {
        if printf '%s\n' "$1" | grep -qx '[A-Za-z0-9_.-][A-Za-z0-9_.-]*/[A-Za-z0-9_.-][A-Za-z0-9_.-]*'; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'inventory entry $1 has the identity form'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage inventory add: an entry is <a>/<b> of letters, digits, _ . and - (as stage inventory show lists them), not: $1'"
        fi
}

#@help __stage_inventory_entry_listed3
# @command stage inventory entry listed <stage> <kind> <entry>
# @summary The newest imported record of the stage lists the entry for that kind (the loader saw the item on the last imported boot): a comment line, else an error line naming stage inventory import and show
# @group   provisioning
# @internal
# @see     stage inventory add
#@end
__stage_inventory_entry_listed3() {
        local newest=""
        newest=$(ls "$ELEBAKE_BASE/stage/$1/inventory/records" 2>/dev/null | sort | sed -n '$p')
        if test -n "$newest" && grep "^loader\.trust\.list\.$2\." "$ELEBAKE_BASE/stage/$1/inventory/records/$newest" 2>/dev/null | grep -q "[\",]$3:"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'the record $newest lists $3 ($2)'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage inventory add: no imported record lists $3 under $2 (stage inventory import after a boot, stage inventory show $1 $2 for the identities)'"
        fi
}

#@help __stage_inventory_entry_write3
# @command stage inventory entry write <stage> <kind> <entry>
# @summary The entry is in the set already: a note (unchanged), else rewrite to 'stage inventory entry append'
# @group   provisioning
# @internal
# @see     stage inventory add
#@end
__stage_inventory_entry_write3() {
        if grep -qxsF "$3" "$ELEBAKE_BASE/stage/$1/inventory/$2"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" note '$3 is in the $2 set of $1 already (unchanged)'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage inventory entry append '$1' '$2' '$3'"
        fi
}

#@help _stage_inventory_entry_append3
# @command stage inventory entry append <stage> <kind> <entry>
# @summary Act terminal: append the entry as a line to inventory/<kind> of the stage (directory 0700, file 0600)
# @group   provisioning
# @internal
# @see     stage inventory add
#@end
_stage_inventory_entry_append3() {
        printf '%s\n' "$MODIFY_DIR_CREATE '$ELEBAKE_BASE/stage/$1/inventory'"
        printf '%s\n' "$MODIFY_FILE_PERMS 0700 '$ELEBAKE_BASE/stage/$1/inventory'"
        printf '%s\n' "printf '%s\\n' $(sq "$3") >> '$ELEBAKE_BASE/stage/$1/inventory/$2'"
        printf '%s\n' "$MODIFY_FILE_PERMS 0600 '$ELEBAKE_BASE/stage/$1/inventory/$2'"
        emit_note "$3 added to the $2 set of $1 (stage site mk renders LOADER_TRUST_$(printf '%s' "$2" | tr '[:lower:]' '[:upper:]')_SET)"
}

#@help ___stage_inventory_adopt2
# @command stage inventory adopt <stage> <kind>
# @summary Take into the set every item that every imported record lists with the same digest -- what held across all boots -- one 'stage inventory add' per item: the stage exists, the kind is valid, at least two records are imported (one boot proves nothing), then the stable entries (stage inventory stable). What moved stays out; the loader itself (file/BOOTX64.EFI) is stable too and is dropped by hand when the set must not include it
# @group   provisioning
# @example elebake stage inventory adopt daily-v1 efivars
# @see     stage inventory show
# @see     stage inventory add
# @see     stage inventory drop
#@end
___stage_inventory_adopt2() {
        local e=""
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage inventory kind valid '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage inventory records enough '$1' '$2'"
        _stage_inventory_stable2 "$1" "$2" | while read -r e; do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage inventory add '$1' '$2' $(sq "$e")"
        done
}

#@help __stage_inventory_records_enough2
# @command stage inventory records enough <stage> <kind>
# @summary At least two imported records (inventory/records/*) carry lists of the kind (a record from a loader that did not list the kind yet says nothing about it): a comment line, else an error line -- one boot cannot tell what moves
# @group   provisioning
# @internal
# @see     stage inventory adopt
#@end
__stage_inventory_records_enough2() {
        if test "$(grep -ls "^loader\.trust\.list\.$2\." "$ELEBAKE_BASE/stage/$1"/inventory/records/* 2>/dev/null | wc -l | tr -d ' ')" -ge 2; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'stage $1: at least two inventory records list $2'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage inventory adopt: fewer than two imported records list $2 for $1 (stage inventory import after a second boot) -- one boot cannot tell what moves'"
        fi
}

#@help _stage_inventory_stable2
# @command stage inventory stable <stage> <kind>
# @summary Text terminal: the identities of a kind that EVERY imported record carrying that kind lists with the same digest, one per line, sorted -- the candidates for the set (template/awk/inventory-stable.awk)
# @env     ELEBAKE_TEMPLATE_DIR  the template directory (awk programs, tables)
# @group   provisioning
# @internal
# @see     stage inventory adopt
#@end
_stage_inventory_stable2() {
        local dir="$ELEBAKE_BASE/stage/$1/inventory"
        ls "$dir/records" 2>/dev/null | sort | sed "s|^|$dir/records/|" | awk -v kind="$2" -f "$ELEBAKE_TEMPLATE_DIR/awk/inventory-stable.awk" | sort
}

#@help ___stage_inventory_drop3
# @command stage inventory drop <stage> <kind> <entry>
# @summary Take one item out of the set of a kind: the stage exists, the kind is valid, the entry is in the set, then its line is removed from inventory/<kind> -- the set's digest changes with it: after site mk, make and one boot, drop and learn LOADER_TRUST_<KIND>_DIGEST from loader.trust.inventory.<kind>.sha256 (stage baseline learn), or the kind's claim keeps failing against the old baseline
# @group   provisioning
# @example elebake stage inventory drop daily-v1 acpi PHAT/-
# @see     stage inventory add
#@end
___stage_inventory_drop3() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage inventory kind valid '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage inventory entry exists '$1' '$2' '$3'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage inventory entry unlink '$1' '$2' '$3'"
}

#@help __stage_inventory_entry_exists3
# @command stage inventory entry exists <stage> <kind> <entry>
# @summary The entry is a line of inventory/<kind> of the stage: a comment line, else an error line
# @group   provisioning
# @internal
# @see     stage inventory drop
#@end
__stage_inventory_entry_exists3() {
        if grep -qxsF "$3" "$ELEBAKE_BASE/stage/$1/inventory/$2"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment '$3 is in the $2 set of $1'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage inventory drop: $3 is not in the $2 set of $1 (stage inventory list $1 $2)'"
        fi
}

#@help _stage_inventory_entry_unlink3
# @command stage inventory entry unlink <stage> <kind> <entry>
# @summary Act terminal: remove the entry's line from inventory/<kind> of the stage
# @group   provisioning
# @internal
# @see     stage inventory drop
#@end
_stage_inventory_entry_unlink3() {
        printf '%s\n' "grep -vxF $(sq "$3") '$ELEBAKE_BASE/stage/$1/inventory/$2' > '$ELEBAKE_BASE/stage/$1/inventory/$2.new'; mv -f '$ELEBAKE_BASE/stage/$1/inventory/$2.new' '$ELEBAKE_BASE/stage/$1/inventory/$2'"
        emit_note "$3 removed from the $2 set of $1"
}

#@help ___stage_inventory_list2
# @command stage inventory list <stage> <kind>
# @summary The set of a kind as the stage has it, one entry per line: the stage exists, the kind is valid, then the lines of inventory/<kind> (a note when empty)
# @group   provisioning
# @example elebake stage inventory list daily-v1 acpi
# @see     stage inventory add
#@end
___stage_inventory_list2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage inventory kind valid '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage inventory entries '$1' '$2'"
}

#@help _stage_inventory_entries2
# @command stage inventory entries <stage> <kind>
# @summary Text terminal: the lines of inventory/<kind> of the stage, sorted as stage inventory make orders them; a note when there are none
# @group   provisioning
# @internal
# @see     stage inventory list
#@end
_stage_inventory_entries2() {
        if grep -qs . "$ELEBAKE_BASE/stage/$1/inventory/$2"; then
                sort "$ELEBAKE_BASE/stage/$1/inventory/$2"
        else
                printf '# %s set of %s: empty -- the claim measures nothing (skipped); stage inventory add\n' "$2" "$1"
        fi
}

#@help ___stage_inventory_make1
# @command stage inventory make <stage>
# @summary Render the sets of the stage as site.mk lines, one 'stage inventory make set <stage> <kind>' per kind: LOADER_TRUST_ACPI_SET, LOADER_TRUST_EFIVARS_SET and LOADER_TRUST_IMAGES_SET, the entries sorted and comma-joined -- the order the loader hashes the members in. A part of stage site mk; an empty set renders nothing, the claim is then skipped
# @group   provisioning
# @example elebake stage inventory make daily-v1
# @see     stage site mk
# @see     stage inventory add
#@end
___stage_inventory_make1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage inventory make set '$1' acpi"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage inventory make set '$1' efivars"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage inventory make set '$1' images"
}

#@help __stage_inventory_make_set2
# @command stage inventory make set <stage> <kind>
# @summary The set of the kind has entries: rewrite to 'stage inventory set line <stage> <kind>', else a comment line (nothing rendered, the claim stays skipped)
# @group   provisioning
# @internal
# @see     stage inventory make
#@end
__stage_inventory_make_set2() {
        if grep -qs . "$ELEBAKE_BASE/stage/$1/inventory/$2"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage inventory set line '$1' '$2'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'no $2 set in $1: LOADER_TRUST_$(printf '%s' "$2" | tr '[:lower:]' '[:upper:]')_SET not rendered, the claim is skipped'"
        fi
}

#@help _stage_inventory_set_line2
# @command stage inventory set line <stage> <kind>
# @summary Text terminal: the site.mk line CFLAGS+= -DLOADER_TRUST_<KIND>_SET=\"a,b,c\" from the sorted entries of inventory/<kind>
# @group   provisioning
# @internal
# @see     stage inventory make
#@end
_stage_inventory_set_line2() {
        printf 'CFLAGS+= -DLOADER_TRUST_%s_SET=\\"%s\\"\n' "$(printf '%s' "$2" | tr '[:lower:]' '[:upper:]')" "$(sort "$ELEBAKE_BASE/stage/$1/inventory/$2" | grep . | tr '\n' ',' | sed 's/,$//')"
}

#@help ___stage_dump_inventory1
# @command stage dump inventory <stage>
# @summary Dump block of the stage's inventory: first the records (stage dump inventory records), then the sets (stage dump inventory sets) -- both travel as files in the bundle
# @group   provisioning
# @internal
# @see     stage dump
# @see     stage dump inventory records
# @see     stage dump inventory sets
#@end
___stage_dump_inventory1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage dump inventory records '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage dump inventory sets '$1'"
}

#@help ___stage_dump_inventory_records1
# @command stage dump inventory records <stage>
# @summary Dump block: the record directory declared, then one 'stage import <stage> inventory/records <file>' per imported record (inventory/records/*) -- the observations the sets were adopted from; none is a comment line (stage inventory import after a boot)
# @env     ELEBAKE_ARCHIVE_BASE  the prefix the emitted paths are written against
# @group   provisioning
# @internal
# @see     stage dump inventory
# @see     stage import
#@end
___stage_dump_inventory_records1() {
        local f="" n=0
        for f in "$ELEBAKE_BASE/stage/$1"/inventory/records/*; do
                test -f "$f" || continue
                n=$((n + 1))
                test "$n" -gt 1 || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage import '$1' 'inventory/records'"
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage import '$1' 'inventory/records' \"\$ELEBAKE_ARCHIVE_BASE/${f#"$ELEBAKE_BASE/"}\""
        done
        test "${n:-0}" -gt 0 || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'stage $1 has no inventory record (stage inventory import after a boot)'"
}

#@help ___stage_dump_inventory_sets1
# @command stage dump inventory sets <stage>
# @summary The inventory directory declared (stage dump inventory dir), then one 'stage dump inventory set <stage> <kind>' per kind the loader publishes (acpi, efivars, images)
# @group   provisioning
# @internal
# @see     stage dump inventory
# @see     stage dump inventory dir
# @see     stage dump inventory set
#@end
___stage_dump_inventory_sets1() {
        local kind=""
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage dump inventory dir '$1'"
        for kind in acpi efivars images; do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage dump inventory set '$1' '$kind'"
        done
}

#@help ___stage_dump_inventory_dir1
# @command stage dump inventory dir <stage>
# @summary Dump block: the one line that declares the inventory directory of the record ('stage import <stage> inventory') before the set files land in it
# @group   provisioning
# @internal
# @see     stage dump inventory sets
# @see     stage import
#@end
___stage_dump_inventory_dir1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage import '$1' 'inventory'"
}

#@help ___stage_dump_inventory_set2
# @command stage dump inventory set <stage> <kind>
# @summary Dump block: the set is a record file (inventory/<kind>, one identity per line) and travels in the bundle -- one 'stage import <stage> inventory <file>' brings it back whole (240 'stage inventory add' replays cost 240 batches, the probe of 13.09.); an empty set is a comment line
# @group   provisioning
# @internal
# @env     ELEBAKE_ARCHIVE_BASE  the prefix the emitted paths are written against
# @see     stage dump inventory sets
# @see     stage import
#@end
___stage_dump_inventory_set2() {
        if grep -qs . "$ELEBAKE_BASE/stage/$1/inventory/$2" 2>/dev/null; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage import '$1' 'inventory' \"\$ELEBAKE_ARCHIVE_BASE/stage/$1/inventory/$2\""
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'stage $1: the $2 set is empty'"
        fi
}
