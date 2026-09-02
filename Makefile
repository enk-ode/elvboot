# elebake Makefile (BSD make).
#
#   make metadata   regenerate TERMINAL_FUNCTIONS / FUNCTION_MODULES in
#                   elebake.sh from the anchor functions in include/*.sh.
#                   Helpers carry no leading underscore by convention, so
#                   they never enter the metadata.
#   make check      syntax-check every shell source (sh -n).
#
# Extend here later: install, test, ...

SCRIPT=		elebake.sh
TESTS=		elebake-architecture-test.sh
INCLUDE_DIR=	include
INCLUDES!=	echo ${INCLUDE_DIR}/*.sh
# engine.sh is the always-loaded core: its anchors join TERMINAL_FUNCTIONS,
# but never FUNCTION_MODULES (module mapping is for lazily sourced modules).
MODULE_SRCS!=	echo ${INCLUDE_DIR}/*.sh | tr ' ' '\n' | grep -v engine.sh | tr '\n' ' ' 

.PHONY: metadata check

# Terminals: exactly ONE leading underscore. Modules: every anchor (_, __,
# ___) mapped to its basename. Both lists replace the maintained lines in
# ${SCRIPT} in place; run `make metadata` after adding or renaming anchors.
metadata:
	@terms=$$(grep -hE '^_[a-z][a-z0-9_]*\(\)' ${INCLUDES} \
	    | sed 's/().*//' | tr '\n' ' ' | sed 's/ $$//'); \
	mods=$$(awk 'FNR == 1 { f = FILENAME; sub(".*/", "", f) } \
	    /^_+[a-z][a-z0-9_]*\(\)/ { n = $$0; sub(/\(\).*/, "", n); printf "%s:%s ", n, f }' \
	    ${MODULE_SRCS} | sed 's/ $$//'); \
	combs=$$(grep -hE '^__[a-z][a-z0-9_]*\(\)' ${INCLUDES} \
	    | sed 's/().*//' | tr '\n' ' ' | sed 's/ $$//'); \
	batches=$$(grep -hE '^___[a-z][a-z0-9_]*\(\)' ${INCLUDES} \
	    | sed 's/().*//' | tr '\n' ' ' | sed 's/ $$//'); \
	sed -i.mkbak \
	    -e "s|^TERMINAL_FUNCTIONS=.*|TERMINAL_FUNCTIONS=\"$$terms\"|" \
	    -e "s|^COMBINATOR_FUNCTIONS=.*|COMBINATOR_FUNCTIONS=\"$$combs\"|" \
	    -e "s|^BATCH_COMBINATOR_FUNCTIONS=.*|BATCH_COMBINATOR_FUNCTIONS=\"$$batches\"|" \
	    -e "s|^FUNCTION_MODULES=.*|FUNCTION_MODULES=\"$$mods\"|" ${SCRIPT}; \
	rm -f ${SCRIPT}.mkbak; \
	for t in ${TESTS}; do \
	    sed -i.mkbak \
	        -e "s|^TERMINAL_FUNCTIONS=.*|TERMINAL_FUNCTIONS=\"$$terms\"|" \
	        -e "s|^COMBINATOR_FUNCTIONS=.*|COMBINATOR_FUNCTIONS=\"$$combs\"|" \
	        -e "s|^BATCH_COMBINATOR_FUNCTIONS=.*|BATCH_COMBINATOR_FUNCTIONS=\"$$batches\"|" \
	        -e "s|^ANCHOR_FUNCTIONS=.*|ANCHOR_FUNCTIONS=\"$$terms $$combs $$batches\"|" \
	        -e "s|^FUNCTION_MODULES=.*|FUNCTION_MODULES=\"$$mods\"|" "$$t"; \
	    rm -f "$$t.mkbak"; \
	done; \
	echo "metadata: $$(echo $$terms | wc -w | tr -d ' ') terminals," \
	    "$$(echo $$mods | wc -w | tr -d ' ') anchors -> ${SCRIPT} ${TESTS}"

check:
	@for f in ${SCRIPT} ${INCLUDES}; do sh -n "$$f" || exit 1; done; \
	echo "check: sh -n ok"

# --- tests -------------------------------------------------------------------
# make test          run all three suites (parallel, JOBS workers)
# make archtest / unittest / inttest   one suite
JOBS!=		sysctl -n hw.ncpu

.PHONY: test archtest unittest inttest

archtest:
	sh elebake-architecture-test.sh --maxprocs ${JOBS}

unittest:
	sh elebake-unit-test.sh --maxprocs ${JOBS}

inttest:
	sh elebake-integration-test.sh --maxprocs 3

test: archtest unittest inttest

# The manual: docs/elebake.8 is GENERATED from `help manual` (prose from
# template/manual/, commands from the help corpus, environment from the
# variable templates) -- pandoc is a contributor-only dependency, the
# generated page is committed. GitHub Pages serves the HTML rendering
# (docs/ is the Pages source on the public repo). Regenerate after
# changing help blocks, templates or prose; commit the result.
.PHONY: man man-html
man:
	./elebake.sh help manual | pandoc -s -f markdown -t man -o docs/elebake.8
	@echo "man: docs/elebake.8 ($$(grep -c '^\.SS\|^\.SH' docs/elebake.8) sections)"

man-html: man
	mandoc -T html -O style=man.css docs/elebake.8 > docs/elebake.html
	cp docs/elebake.html docs/index.html
