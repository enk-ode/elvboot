# filter.awk -- apply one filter strategy to a collection (one file path per line, written
# against "$ELEBAKE_ARCHIVE_BASE"). Comment and blank lines pass through. A line (as written,
# prefix included) matching a glob of the drop table becomes '# dropped (<reason>): <line>';
# a line whose database-relative path no glob of the keep table admits becomes '# dropped (<strategy>): <line>'; the rest is
# printed as it is. Globs: * matches any run of characters (slashes included), ? one character.
#   awk -v strategy=<name> -v drop=<drop table> -v keep=<keep table> -f filter.awk <collection>
function glob2re(g,    r) {
        r = g
        gsub(/[][\\^$.|+(){}]/, "\\\\&", r)
        gsub(/\*/, ".*", r)
        gsub(/\?/, ".", r)
        return "^" r "$"
}
BEGIN {
        while ((getline l < drop) > 0) {
                if (l ~ /^#/ || l == "") continue
                split(l, a, " ")
                dre[++nd] = glob2re(a[1]); dreason[nd] = a[2]
        }
        while ((getline l < keep) > 0) {
                if (l ~ /^#/ || l == "") continue
                kre[++nk] = glob2re(l)
        }
}
/^#/ || /^$/ { print; next }
{
        rel = $0
        sub(/^"\$ELEBAKE_ARCHIVE_BASE"\//, "", rel)
        for (i = 1; i <= nd; i++) if ($0 ~ dre[i]) { print "# dropped (" dreason[i] "): " $0; next }
        for (i = 1; i <= nk; i++) if (rel ~ kre[i]) { print; next }
        print "# dropped (" strategy "): " $0
}
