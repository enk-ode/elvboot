# inventory-stable.awk -- the identities every record carrying the kind agrees on.
#
#   ls <stage>/inventory/records | sort | sed 's|^|<dir>/|' \
#     | awk -v kind=<acpi|efivars|images> -f $ELEBAKE_TEMPLATE_DIR/awk/inventory-stable.awk
#
# Input: the record files, one path per line. Only records that publish a
# loader.trust.list.<kind>.<n> chunk count; an identity qualifies when
# every such record lists it with one and the same digest (an item listed
# twice with differing digests inside one record, or a digest '-', does
# not). Output: the identities, one per line, unsorted -- the candidates
# for stage inventory adopt.
{ files[++nf] = $0 }
END {
        for (r = 1; r <= nf; r++) {
                has[r] = 0
                while ((getline line < files[r]) > 0) {
                        if (line !~ ("^loader\\.trust\\.list\\." kind "\\.[0-9]+=")) continue
                        has[r] = 1
                        sub(/^[^=]*="/, "", line); sub(/"$/, "", line)
                        n = split(line, ent, ",")
                        for (i = 1; i <= n; i++) {
                                m = split(ent[i], fld, ":")
                                if (m < 3 || fld[m] == "-") continue
                                id = fld[1]
                                if (!(id in seen)) { seen[id] = 1; ids[++ni] = id }
                                if (!((id, r) in dig)) { dig[id, r] = fld[m]; boots[id]++ }
                                else if (dig[id, r] != fld[m]) dig[id, r] = "?"
                        }
                }
                close(files[r])
                if (has[r]) nk++
        }
        for (k = 1; k <= ni; k++) {
                id = ids[k]
                if (boots[id] != nk) continue
                ok = 1; first = ""
                for (r = 1; r <= nf; r++) {
                        if (!has[r]) continue
                        if (dig[id, r] == "?") ok = 0
                        if (first == "") first = dig[id, r]
                        else if (dig[id, r] != first) ok = 0
                }
                if (ok) print id
        }
}
