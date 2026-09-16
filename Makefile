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
	stems=$$(printf '%s\n' $$terms $$combs $$batches | awk '{ s = $$0; sub(/^_+/, "", s); sub(/[0-9]$$/, "", s); \
	    if (!(s in t)) { order[++n] = s; t[s] = $$0 } else t[s] = t[s] " " $$0 } \
	    END { for (i = 1; i <= n; i++) printf "ANCHOR_STEM_%s=\047%s\047 ", order[i], t[order[i]] }' | sed 's/ $$//'); \
	sed -i.mkbak \
	    -e "s|^TERMINAL_FUNCTIONS=.*|TERMINAL_FUNCTIONS=\"$$terms\"|" \
	    -e "s|^COMBINATOR_FUNCTIONS=.*|COMBINATOR_FUNCTIONS=\"$$combs\"|" \
	    -e "s|^BATCH_COMBINATOR_FUNCTIONS=.*|BATCH_COMBINATOR_FUNCTIONS=\"$$batches\"|" \
	    -e "s|^ANCHOR_STEM_TABLE=.*|ANCHOR_STEM_TABLE=\"$$stems\"|" \
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

# The manual: docs/elebake.8 is GENERATED from `help manual` against an EMPTY
# base (no database's pins colour it; prose from
# template/manual/, commands from the help corpus, environment from the
# variable templates) -- pandoc is a contributor-only dependency, the
# generated page is committed. GitHub Pages serves the HTML rendering
# (docs/ is the Pages source on the public repo). Regenerate after
# changing help blocks, templates or prose; commit the result.
.PHONY: man man-html
man:
	@env ELEBAKE_BASE="$$PWD/.man-root/db" ./elebake.sh help manual > docs/elebake.md.tmp
	@test $$(grep -c ^\*\* docs/elebake.md.tmp) -gt 100 || { echo "man: help manual produced no command sections -- not overwriting docs/elebake.8" >&2; rm -f docs/elebake.md.tmp; exit 1; }
	@! grep -q 'CONTEXT_SCRIPT\|^# manual part' docs/elebake.md.tmp || { echo "man: help manual leaked batch or comment lines (a pin of the base coloured it) -- not overwriting docs/elebake.8" >&2; rm -f docs/elebake.md.tmp; exit 1; }
	pandoc -s -f markdown -t man -o docs/elebake.8 docs/elebake.md.tmp && rm -f docs/elebake.md.tmp
	@echo "man: docs/elebake.8 ($$(grep -c '^\.SS\|^\.SH' docs/elebake.8) sections)"

man-html: man
	mandoc -T html -O style=man.css docs/elebake.8 > docs/elebake.html
	cp docs/elebake.html docs/index.html

# --- install ------------------------------------------------------------------
# FreeBSD conventions (bsd.own.mk): PREFIX is the install prefix (default
# /usr/local, needs root), DESTDIR a staging root prepended to every path,
# BINDIR and MANDIR the targets. A per-user install:
#
#   make PREFIX=${HOME} install        -> ~/bin/elebake, ~/share/man/man8/elebake.8
#   make PREFIX=${HOME} RUNNER=binary install   -> the same, elebake runs in one process
#
# Both land on FreeBSD's defaults: ~/bin is on the login PATH and man(1)
# derives ~/share/man from it. The wrapper execs THIS checkout's
# elebake.sh -- a development install: include/ and template/ are read
# from here, `git pull` is the update. make uninstall removes both files.
PREFIX?=	/usr/local
DESTDIR?=
BINDIR?=	${PREFIX}/bin
MANDIR?=	${PREFIX}/share/man/man
WRAPPER=	${DESTDIR}${BINDIR}/elebake
MANPAGE=	${DESTDIR}${MANDIR}8/elebake.8
# bash-completion loads <command> from here on the first Tab. A user
# install (PREFIX under $HOME) is not ${PREFIX}/share: bash-completion reads
# the user's completions from ~/.local/share/bash-completion/completions --
# and there the file is a symlink into this checkout, like the wrapper.
.if ${PREFIX:M${HOME}*} != ""
COMPLETIONDIR?=	${HOME}/.local/share/bash-completion/completions
.else
COMPLETIONDIR?=	${PREFIX}/share/bash-completion/completions
.endif
COMPLETION=	${DESTDIR}${COMPLETIONDIR}/elebake

.PHONY: install uninstall

# RUNNER selects what the installed 'elebake' runs:
#   process (default)  elebake.sh -- a process per emitted line, the batch
#                      ring, trace and log: the runner the test suites inspect
#   binary             elebake-binary.sh -- one process, the anchors as
#                      functions; it needs the database's environment cache,
#                      so before one exists (bootstrap, help without a
#                      database) the wrapper runs elebake.sh
RUNNER?=	process

install: docs/elebake.8
	@mkdir -p ${DESTDIR}${BINDIR} ${DESTDIR}${MANDIR}8
.if ${RUNNER} == binary
	@printf '#!/bin/sh\n# elebake wrapper (make install RUNNER=binary from %s)\n# one process for every command; before the database has its\n# environment cache (bootstrap, help without a database) the process runner\nbase=$${ELEBAKE_BASE:-$$HOME/.elebake/db}\nif [ -s "$$base/.env/local/ELEBAKE_CACHE_ENV_ARGS" ]; then\n\texec /bin/sh %s/elebake-binary.sh "$$base" "$$@"\nfi\nexec /bin/sh %s/elebake.sh "$$@"\n' \
	    '${.CURDIR}' '${.CURDIR}' '${.CURDIR}' > ${WRAPPER}.tmp
.else
	@printf '#!/bin/sh\n# elebake wrapper (make install from %s)\nexec /bin/sh %s/elebake.sh "$$@"\n' \
	    '${.CURDIR}' '${.CURDIR}' > ${WRAPPER}.tmp
.endif
	@install -m 0755 ${WRAPPER}.tmp ${WRAPPER} && rm -f ${WRAPPER}.tmp
	@install -m 0444 docs/elebake.8 ${MANPAGE}
	@mkdir -p ${DESTDIR}${COMPLETIONDIR}
	@rm -f ${COMPLETION} && ln -s ${.CURDIR}/completion/elebake.bash ${COMPLETION}
	@echo "install: ${WRAPPER} -> ${.CURDIR} (RUNNER=${RUNNER})"
	@echo "install: ${MANPAGE}"
	@echo "install: ${COMPLETION} (bash completion)"

uninstall:
	@rm -f ${WRAPPER} ${MANPAGE} ${COMPLETION}
	@echo "uninstall: ${WRAPPER}, ${MANPAGE} and ${COMPLETION} removed"
