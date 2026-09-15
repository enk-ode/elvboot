# catalog-doc.awk -- the description of ONE catalog entry, read from its source.
#
#   awk -v n=<name> -f $ELEBAKE_TEMPLATE_DIR/awk/catalog-doc.awk <catalog file>
#
# The catalogs document themselves, elebake only reads: a C header carries
#   " * <name>  <text>"  followed by continuation lines " *    <text>",
# a sh catalog carries
#   "# <name> [args] -- <text>"  followed by continuation lines "# <text>".
# The block ends at a blank comment line, at the next name-keyed line, at a
# "---" rule or at the end of the comment. An action may be documented under
# its short name (<name> without the _act suffix).
#
# Output, ready for a listing: the name on its own line, then the text
# folded at 66 columns, every line prefixed with "#       "; an entry without
# a description says so instead of staying silent.

function strip(t)        { sub(/^[ \t]*(\*|#)[ \t]*/, "", t); return t }
function firstword(t, w) { w = strip(t); sub(/[ \t].*/, "", w); return w }
function iscatname(w)    { return (w ~ /^(measure|diagnose|when)_[a-z0-9_]+$/ || w ~ /^[a-z0-9_]+_act$/) }

BEGIN { found = 0; out = ""; s = n; sub(/_act$/, "", s) }

/^[ \t]*(\*|#)/ {
	w = firstword($0)
	if (found) {
		# inside the block: stop at its end, else collect the line
		if ($0 ~ /^[ \t]*\*\/[ \t]*$/ || strip($0) == "" || iscatname(w) || strip($0) ~ /^---/)
			exit
		out = out " " strip($0)
		next
	}
	if (w == n || w == s) {
		# the keyed line: the text after "name args --" (sh) or after "name" (C)
		t = strip($0)
		if ($0 ~ /^[ \t]*#/ && t ~ / -- /) sub(/^.* -- /, "", t)
		else sub(/^[^ \t]+[ \t]*/, "", t)
		out = t; found = 1
	}
	next
}
{ if (found) exit }

END {
	printf "#   %s\n", n
	if (!found || out == "") { print "#       (no description in the catalog source)"; exit }
	# fold at 66 columns on word boundaries
	nw = split(out, words, /[ \t]+/); line = ""
	for (i = 1; i <= nw; i++) {
		if (words[i] == "") continue
		if (line != "" && length(line) + 1 + length(words[i]) > 66) { printf "#       %s\n", line; line = "" }
		line = (line == "" ? words[i] : line " " words[i])
	}
	if (line != "") printf "#       %s\n", line
}
