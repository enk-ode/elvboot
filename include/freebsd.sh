#!/bin/sh
#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Dr. Johannes Brügmann
# elebake freebsd - the FreeBSD source-build backend (general build environment).
#
# Sibling of the signing backends, but for BUILDING: the GENERAL build
# environment (the toolchain and the repo at ELEBAKE_FREEBSD_SRC), not the
# stage-specific gate (stage build ready).

#@help ___freebsd_prerequisites0
# @command freebsd prerequisites
# @summary Check the FreeBSD source-build environment at generation time: the source repo is set and a git repo, the curated tool list is set and every tool installed; then the ok line
# @group   diagnostics
# @env     ELEBAKE_FREEBSD_PREREQUISITES  curated tool list the generator probes (see the template)
# @env     ELEBAKE_FREEBSD_SRC            path to the FreeBSD source repo (set per machine: elebake setenv)
# @example elebake freebsd prerequisites
# @see     stage checkout
# @see     stage build
#@end
___freebsd_prerequisites0() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" freebsd source set"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" freebsd source repo"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" freebsd tools set"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" freebsd tools installed"
}

#@help __freebsd_source_set0
# @command freebsd source set
# @summary ELEBAKE_FREEBSD_SRC is set: a comment line, else an error line
# @group   diagnostics
# @internal
# @env     ELEBAKE_FREEBSD_SRC  the source repo
# @see     freebsd prerequisites
# @see     stage checkout
#@end
__freebsd_source_set0() {
        if test -n "${ELEBAKE_FREEBSD_SRC:-}"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'source repo ${ELEBAKE_FREEBSD_SRC:-} set'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'freebsd prerequisites: ELEBAKE_FREEBSD_SRC not set -- elebake setenv ELEBAKE_FREEBSD_SRC <path-to-freebsd-src>'"
        fi
}

#@help __freebsd_source_repo0
# @command freebsd source repo
# @summary ELEBAKE_FREEBSD_SRC is a git repository: a comment line, else an error line
# @group   diagnostics
# @internal
# @env     ELEBAKE_FREEBSD_SRC  the source repo
# @see     freebsd prerequisites
#@end
__freebsd_source_repo0() {
        if test -d "${ELEBAKE_FREEBSD_SRC:-}/.git"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'source repo ${ELEBAKE_FREEBSD_SRC:-} is a git repository'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'freebsd prerequisites: not a git repo: ${ELEBAKE_FREEBSD_SRC:-} (ELEBAKE_FREEBSD_SRC)'"
        fi
}

#@help __freebsd_tools_set0
# @command freebsd tools set
# @summary ELEBAKE_FREEBSD_PREREQUISITES lists the tools to probe: a comment line, else an error line
# @group   diagnostics
# @internal
# @env     ELEBAKE_FREEBSD_PREREQUISITES  the tool list
# @see     freebsd prerequisites
#@end
__freebsd_tools_set0() {
        if test -n "${ELEBAKE_FREEBSD_PREREQUISITES:-}"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'tool list: ${ELEBAKE_FREEBSD_PREREQUISITES:-}'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'freebsd prerequisites: ELEBAKE_FREEBSD_PREREQUISITES not set (environment init <profile>)'"
        fi
}

#@help __freebsd_tools_installed0
# @command freebsd tools installed
# @summary Every tool of ELEBAKE_FREEBSD_PREREQUISITES is installed: a log line (the ok line of the check), else an error line naming the first missing
# @group   diagnostics
# @internal
# @env     ELEBAKE_FREEBSD_PREREQUISITES  the tool list
# @see     freebsd prerequisites
# @env     ELEBAKE_FREEBSD_SRC  named in the ok line
#@end
__freebsd_tools_installed0() {
        local t="" missing=""
        for t in ${ELEBAKE_FREEBSD_PREREQUISITES:-}; do
                test -n "$missing" || command -v "$t" > /dev/null 2>&1 || missing="$t"
        done
        if test -z "$missing"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log 'freebsd prerequisites ok (checked at generation time): ${ELEBAKE_FREEBSD_PREREQUISITES:-}; src: ${ELEBAKE_FREEBSD_SRC:-}'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'freebsd prerequisites: $missing not found (pkg install $missing?)'"
        fi
}
