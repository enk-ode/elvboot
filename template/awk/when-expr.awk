# when-expr.awk -- one trigger expression: checked, its leaves, its C form,
# its sh form.
#
#   awk -v e='<expr>' -v kind=when|action -v mode=check|leaves|c|sh \
#       -f $ELEBAKE_TEMPLATE_DIR/awk/when-expr.awk
#
# A trigger record holds two expressions, the when and the action. Each is
# a catalog name or a composition, written without whitespace:
#
#   when    and(a,b[,c...])   or(a,b[,c...])   not(a)      leaves: when_*
#   action  compose(a[,b...])                              leaves: *_act
#
# The forms:
#   c      the loader's policy table: AND(a, b), OR(a, b), NOT(a) nested
#          pairwise from the left; an action as a, or COMPOSE(a, b)
#   sh     the containers' binding line: { a && b; }, { a || b; }, ! a;
#          actions as a "$GATE"; b "$GATE"
#   leaves one catalog name per line (the bind-time catalog check)
#   check  nothing: exit 0 iff the expression parses (else a message on
#          stderr, exit 1)
#
# Grammar:  expr := name | op '(' expr { ',' expr } ')'

function fail(msg) {
	printf "when-expr: %s: %s\n", msg, e > "/dev/stderr"
	exit 1
}
function peek() { return substr(e, pos, 1) }
function name(   s) {
	s = ""
	while (peek() ~ /[a-z0-9_]/) { s = s peek(); pos++ }
	if (s == "") fail("name expected at " pos)
	return s
}
# parse returns a node index: op[i] is "leaf" or the operator, leaf[i] the
# name, kids[i] the child indices comma-joined
function parse(   n, i, k, s) {
	n = name()
	if (peek() != "(") { i = ++nn; op[i] = "leaf"; leaf[i] = n; return i }
	pos++
	i = ++nn; op[i] = n; kids[i] = ""; k = 0
	for (;;) {
		s = parse()
		kids[i] = (k > 0 ? kids[i] "," : "") s; k++
		if (peek() == ",") { pos++; continue }
		if (peek() == ")") { pos++; break }
		fail("',' or ')' expected at " pos)
	}
	if (kind == "when") {
		if (n != "and" && n != "or" && n != "not") fail("unknown when operator " n)
		if (n == "not" && k != 1) fail("not takes one argument")
		if (n != "not" && k < 2) fail(n " takes at least two arguments")
	} else {
		if (n != "compose") fail("unknown action operator " n)
	}
	return i
}
function leaves(i,   a, m, j) {
	if (op[i] == "leaf") { print leaf[i]; return }
	m = split(kids[i], a, ",")
	for (j = 1; j <= m; j++) leaves(a[j])
}
function c_form(i,   a, m, j, s) {
	if (op[i] == "leaf") return leaf[i]
	m = split(kids[i], a, ",")
	if (op[i] == "not") return "NOT(" c_form(a[1]) ")"
	if (op[i] == "compose") {
		s = ""
		for (j = 1; j <= m; j++) s = s (j > 1 ? ", " : "") c_form(a[j])
		return (m > 1 ? "COMPOSE(" s ")" : s)
	}
	s = c_form(a[1])
	for (j = 2; j <= m; j++) s = toupper(op[i]) "(" s ", " c_form(a[j]) ")"
	return s
}
function sh_form(i,   a, m, j, s) {
	if (op[i] == "leaf") return (kind == "action" ? leaf[i] " \"$GATE\"" : leaf[i])
	m = split(kids[i], a, ",")
	if (op[i] == "not") return "! " sh_form(a[1])
	if (op[i] == "compose") {
		s = ""
		for (j = 1; j <= m; j++) s = s (j > 1 ? "; " : "") sh_form(a[j])
		return s
	}
	s = "{ " sh_form(a[1])
	for (j = 2; j <= m; j++) s = s (op[i] == "and" ? " && " : " || ") sh_form(a[j])
	return s "; }"
}

BEGIN {
	if (kind != "when" && kind != "action") fail("kind must be when or action")
	if (e == "") fail("empty expression")
	if (e ~ /[^a-z0-9_(),]/) fail("only names, ( ) and , are allowed")
	pos = 1; nn = 0
	root = parse()
	if (pos <= length(e)) fail("trailing input at " pos)
	if (mode == "leaves") leaves(root)
	else if (mode == "c") print c_form(root)
	else if (mode == "sh") print sh_form(root)
	else if (mode != "check") fail("mode must be check, leaves, c or sh")
	exit 0
}
