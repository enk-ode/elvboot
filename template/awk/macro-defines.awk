# macro-defines.awk -- does any macro record of the arsenal define <want>?
#
#   awk -v want=<NAME> -f $ELEBAKE_TEMPLATE_DIR/awk/macro-defines.awk <database>/foundation/macros/*
#   awk -v want=<NAME> -v stem=1 ...   prints the defining record's stem as well
#
# A macro record reads "type label [defined [else]]"; its file name is the
# macro stem. The record defines its third field when one is given and is
# not '-', otherwise the derived name: the stem without a _DIGEST suffix,
# plus _EXPECTED (BOARD_DIGEST -> BOARD_EXPECTED, KENV_GUARD ->
# KENV_GUARD_EXPECTED). Exit 0 when a record defines want, 1 otherwise.
# Nothing changes.
FNR == 1 {
	stem_ = FILENAME; sub(/.*\//, "", stem_)
	if ($3 == "" || $3 == "-") { defined = stem_; sub(/_DIGEST$/, "", defined); defined = defined "_EXPECTED" }
	else defined = $3
	if (defined == want) { found = 1; if (stem) print stem_; exit }
}
END { exit !found }
