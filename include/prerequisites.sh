#!/bin/sh
#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Dr. Johannes Brügmann
# elebake prerequisites - discover the present signing backends and fan out to
# each backend's own prerequisites check.
#
# `prerequisites verify` -> ___prerequisites_verify0: `ls $ELEBAKE_BASE`, filter
# out pseudo-backends (is_pseudo_backend = hidden dirs + ELEBAKE_PSEUDO_BACKEND,
# e.g. stage), and emit `elebake <backend> prerequisites` for each REAL backend.
# The actual checks live in each backend's own module (_pkcs11_prerequisites0 in
# pkcs11.sh, _openpgp_prerequisites0 in openpgp.sh) — no central knowledge; add a
# backend dir + its module and it is discovered automatically.

#-----------------------------------------------------------------------------
# ___prerequisites_verify0 — fan out to every present backend's check
#-----------------------------------------------------------------------------
#@help ___prerequisites_verify0
# @command prerequisites verify
# @summary Fan out to every present backend's own prerequisites check
# @group   diagnostics
# @env ELEBAKE_PSEUDO_BACKEND  base-dir names that are NOT signing backends (e.g. stage)
#@end
___prerequisites_verify0() {
  local base="$ELEBAKE_BASE" d name
  for d in "$base"/*; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    is_pseudo_backend "$name" && continue
    printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" $name prerequisites"
  done
}
