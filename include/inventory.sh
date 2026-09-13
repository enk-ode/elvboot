#!/bin/sh
#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Dr. Johannes Brügmann
# elebake inventory - the SETS the loader's platform claims measure.
#
# AcpiTables and EfiVariables claim a set the stage names -- add semantics,
# never an exclusion (JB 12.09.): what is not added is listed, not claimed.
# The loader publishes every item it saw, one entry with an 8-hex digest,
# as loader.trust.list.<kind>.<n>; elvbootd's inventory_record_act files
# them per boot under /var/db/elvboot/inventory/<boot time>. From there:
#
#   inventory/records/<boot time>   the lists of one boot, root's copy
#                                   fetched by stage inventory import
#   inventory/<kind>                the set: one entry per line, added by
#                                   stage inventory add; <kind> is acpi
#                                   (<signature>/<OEM table id>) or efivars
#                                   (<guid's first word>/<name>)
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
# @summary Lay the imported records side by side for one kind (acpi | efivars): per item its identity, size, for efivars the attributes in words, in how many boots it appeared, whether every boot saw the same digest (same) or not (MOVES), whether it is in the set (+), and the digest of each boot, oldest first. What moves is what the firmware rewrites: leave it out of the set
# @group   provisioning
# @example elebake stage inventory show daily-v1 efivars
# @see     stage inventory import
# @see     stage inventory add
#@end
___stage_inventory_show2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage inventory kind valid '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage inventory show rows '$1' '$2'"
}

#@help __stage_inventory_kind_valid1
# @command stage inventory kind valid <kind>
# @summary The kind is acpi or efivars, the two lists the loader publishes: a comment line, else an error line
# @group   provisioning
# @internal
# @see     stage inventory show
#@end
__stage_inventory_kind_valid1() {
        if test "$1" = acpi || test "$1" = efivars; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'inventory kind $1'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage inventory: the kind is acpi or efivars, not $1'"
        fi
}

#@help _stage_inventory_show_rows2
# @command stage inventory show rows <stage> <kind>
# @summary Text terminal: the table over inventory/records/* of the stage for one kind -- a header naming the records, then one row per item sorted by identity (identity, size, attributes for efivars, boots seen, same|MOVES, + if in the set, the digests oldest first, ........ where a boot did not list the item or listed it without a digest); a note when no record was imported
# @group   provisioning
# @internal
# @see     stage inventory show
#@end
_stage_inventory_show_rows2() {
        local dir="$ELEBAKE_BASE/stage/$1/inventory" f="" set="" n=0 first="" last=""
        set=$(cat "$dir/$2" 2>/dev/null | tr '\n' ' ')
        for f in "$dir"/records/*; do test -f "$f" || continue; n=$((n + 1)); done
        if test "$n" -eq 0; then
                printf '# inventory %s of %s: no record imported (stage inventory import after a boot)\n' "$2" "$1"
                return 0
        fi
        first=$(ls "$dir/records" | sort | sed -n 1p); last=$(ls "$dir/records" | sort | sed -n '$p')
        printf '# inventory %s of %s: %s record(s), %s .. %s; set: %s entries\n' "$2" "$1" "$n" "$first" "$last" "$(grep -c . "$dir/$2" 2>/dev/null || echo 0)"
        printf '# %-42s %7s %-14s %5s %-5s %s %s\n' identity size attrs boots agree set 'digests (oldest .. newest)'
        ls "$dir/records" | sort | sed "s|^|$dir/records/|" | awk -v kind="$2" -v set=" $set " '
        function hex(s,    i, v, c) { v = 0; for (i = 1; i <= length(s); i++) { c = index("0123456789abcdef", tolower(substr(s, i, 1))) - 1; if (c < 0) return -1; v = v * 16 + c } return v }
        function words(a,    v, w) { if (a == "") return "-"; v = hex(a); if (v < 0) return a; w = ""
                if (v % 2 >= 1) w = w "NV,"; if (int(v / 2) % 2 >= 1) w = w "BS,"; if (int(v / 4) % 2 >= 1) w = w "RT,"
                if (int(v / 8) % 2 >= 1) w = w "HW,"; if (int(v / 16) % 2 >= 1) w = w "AW,"; if (int(v / 32) % 2 >= 1) w = w "TA,"; if (int(v / 64) % 2 >= 1) w = w "AP,"
                sub(/,$/, "", w); return w }
        { files[++nf] = $0 }
        END {
                for (r = 1; r <= nf; r++) {
                        while ((getline line < files[r]) > 0) {
                                if (line !~ ("^loader\\.trust\\.list\\." kind "\\.[0-9]+=")) continue
                                sub(/^[^=]*="/, "", line); sub(/"$/, "", line)
                                n = split(line, ent, ",")
                                for (i = 1; i <= n; i++) {
                                        m = split(ent[i], fld, ":")
                                        if (m < 3) continue
                                        id = fld[1]
                                        if (!(id in seen)) { seen[id] = 1; ids[++ni] = id }
                                        dig[id, r] = fld[m]; size[id] = fld[m - 1]; attrs[id] = (m >= 4) ? fld[2] : ""
                                }
                        }
                        close(files[r])
                }
                for (k = 1; k <= ni; k++) {
                        id = ids[k]; boots = 0; distinct = 0; row = ""; split("", had)
                        for (r = 1; r <= nf; r++) {
                                d = dig[id, r]
                                if (d == "" || d == "-") { row = row " ........"; continue }
                                boots++; if (!(d in had)) { had[d] = 1; distinct++ }
                                row = row " " d
                        }
                        printf "%-44s %7s %-14s %2d/%-2d %-5s %s %s\n", id, size[id], words(attrs[id]), boots, nf, (distinct <= 1 ? "same" : "MOVES"), (index(set, " " id " ") > 0 ? "+" : "-"), row
                }
        }' | sort
}

#@help ___stage_inventory_add3
# @command stage inventory add <stage> <kind> <entry>
# @summary Take one item into the set of a kind: the stage exists, the kind is acpi or efivars, the entry has the identity form (<a>/<b>, letters, digits, _ . -), the newest imported record lists it (the loader saw it -- stage inventory import first), then it is appended to inventory/<kind> unless already there. The set is what AcpiTables / EfiVariables measure; after a change: stage site mk, build, boot, then learn the digest
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

#@help ___stage_inventory_drop3
# @command stage inventory drop <stage> <kind> <entry>
# @summary Take one item out of the set of a kind: the stage exists, the kind is valid, the entry is in the set, then its line is removed from inventory/<kind>
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
        printf '%s\n' "grep -vxF $(sq "$3") '$ELEBAKE_BASE/stage/$1/inventory/$2' > '$ELEBAKE_BASE/stage/$1/inventory/$2.new'; mv '$ELEBAKE_BASE/stage/$1/inventory/$2.new' '$ELEBAKE_BASE/stage/$1/inventory/$2'"
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
# @summary Render the sets of the stage as site.mk lines, one 'stage inventory make set <stage> <kind>' per kind: LOADER_TRUST_ACPI_SET and LOADER_TRUST_EFIVARS_SET, the entries sorted and comma-joined -- the order the loader hashes the members in. A part of stage site mk; an empty set renders nothing, the claim is then skipped
# @group   provisioning
# @example elebake stage inventory make daily-v1
# @see     stage site mk
# @see     stage inventory add
#@end
___stage_inventory_make1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage inventory make set '$1' acpi"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage inventory make set '$1' efivars"
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
# @summary Dump block: one 'stage inventory add' replay per entry of each set (records are observations, imported again rather than restored)
# @group   provisioning
# @internal
# @see     stage dump
#@end
___stage_dump_inventory1() {
        local kind="" e=""
        for kind in acpi efivars; do
                grep -s . "$ELEBAKE_BASE/stage/$1/inventory/$kind" 2>/dev/null | while read -r e; do
                        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage inventory add '$1' '$kind' $(sq "$e")"
                done
        done
}
