#!/bin/sh
#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Dr. Johannes Brügmann
# elebake prerequisites - discover the present signing backends and fan out to
# each backend's own prerequisites check: ls of the database, the pseudo
# backends filtered (is_pseudo_backend: hidden directories and
# ELEBAKE_PSEUDO_BACKEND), one '<backend> prerequisites' per real backend.
# The checks live in each backend's module -- no central knowledge; add a
# backend directory and its module and it is discovered automatically.

#@help ___prerequisites_verify0
# @command prerequisites verify
# @summary Fan out to every present backend's own prerequisites check; none is a comment line
# @group   diagnostics
# @env     ELEBAKE_PSEUDO_BACKEND  base-dir names that are NOT signing backends (e.g. stage)
# @example elebake prerequisites verify
# @see     pkcs11 prerequisites
# @see     openpgp prerequisites
# @see     pem prerequisites
#@end
___prerequisites_verify0() {
        local d="" n=0
        for d in "$ELEBAKE_BASE"/*; do
                test -d "$d" || continue
                is_pseudo_backend "${d##*/}" && continue
                n=$((n + 1))
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" ${d##*/} prerequisites"
        done
        test "${n:-0}" -gt 0 || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'no signing backend registered'"
}
