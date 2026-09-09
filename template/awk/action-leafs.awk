# action-leafs.awk -- the kenv leafs one loader action reads.
#
#   awk -v action=<name> -f $ELEBAKE_TEMPLATE_DIR/awk/action-leafs.awk <checkout>/local/action.c
#
# Inside the body of action_<name>() every kenv(a, "<leaf>") call names a
# loader.trust.<gate>.<leaf> key the action reads at boot; the leafs are
# printed one per line, each once. Nothing changes.
/^action_[a-z_]*\(/ { cur = $0; sub(/^action_/, "", cur); sub(/\(.*/, "", cur) }
cur == action && /kenv\(a, "[a-z._]*"\)/ {
	line = $0
	while (match(line, /kenv\(a, "[a-z._]*"\)/)) {
		leaf = substr(line, RSTART + 9, RLENGTH - 11)
		if (!(leaf in seen)) { seen[leaf] = 1; print leaf }
		line = substr(line, RSTART + RLENGTH)
	}
}
