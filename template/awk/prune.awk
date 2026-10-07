# prune.awk -- the replay of a dump against a bundle: a line that names a base element
# ("$X_ARCHIVE_BASE/<path>", the dump's quoting) the bundle's collection marks as dropped
# ('# dropped (<reason>): "$X_ARCHIVE_BASE"/<path>', the collection's quoting) becomes
# '# dropped (<reason>): <line>' -- the description stays complete and auditable, the replay
# asks for nothing the bundle does not carry. Everything else passes through as it is.
# The collection names a file by its real path, the dump by the name a link gives it
# (stage/<name> -> .staging/<id>): links lists those aliases, 'stage/<name>=.staging/<id>;...'.
#   awk -v collection=<the bundle's export/collection> -v links=<aliases> -f prune.awk <dump> > <replay>
BEGIN {
        while ((getline l < collection) > 0) {
                if (l !~ /^# dropped \(/) continue
                reason = l; sub(/^# dropped \(/, "", reason); sub(/\).*$/, "", reason)
                p = l; sub(/^# dropped \([^)]*\): /, "", p)
                sub(/^"\$[A-Z_]*ARCHIVE_BASE"\//, "", p)
                dropped[p] = reason
        }
        na = split(links, A, ";")
        for (i = 1; i <= na; i++) {
                if (A[i] == "") continue
                k = index(A[i], "=")
                if (k > 0) alias[substr(A[i], 1, k - 1)] = substr(A[i], k + 1)
        }
}
/^#/ || /^$/ { print; next }
{
        if (match($0, /"\$[A-Z_]*ARCHIVE_BASE\/[^"]*"/)) {
                p = substr($0, RSTART, RLENGTH)
                sub(/^"\$[A-Z_]*ARCHIVE_BASE\//, "", p); sub(/"$/, "", p)
                q = p
                for (a in alias) if (index(p, a "/") == 1) { q = alias[a] substr(p, length(a) + 1); break }
                if (p in dropped) { print "# dropped (" dropped[p] "): " $0; next }
                if (q in dropped) { print "# dropped (" dropped[q] "): " $0; next }
        }
        print
}
