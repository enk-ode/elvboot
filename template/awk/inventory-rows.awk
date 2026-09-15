# inventory-rows.awk -- the imported inventory records side by side, one row per item.
#
#   ls <stage>/inventory/records | sort | sed 's|^|<dir>/|' \
#     | awk -v kind=<acpi|efivars|images> -v set=" <id> <id> ... " -f $ELEBAKE_TEMPLATE_DIR/awk/inventory-rows.awk
#
# Input: the record files, oldest first, one path per line. Every record
# publishes loader.trust.list.<kind>.<n>="<id>:[<attrs>:]<size>:<digest>,..."
# chunks. Per identity one row: identity, size, the efivars attributes in
# words (NV BS RT HW AW TA AP), boots seen / records, same or MOVES over
# the digests, + when the identity is in the set, the digests oldest ..
# newest (........ where a record lacks the item). Caller sorts the rows.
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
}
