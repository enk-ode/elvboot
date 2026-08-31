#!/bin/sh
#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Dr. Johannes Brügmann
# elebake freebsd - the FreeBSD source-build backend (general build environment).
#
# Sibling of the signing backends, but for BUILDING. `freebsd prerequisites`
# checks the GENERAL build environment (not stage-specific — that is `stage
# prerequisites`): the toolchain and the repo at ELEBAKE_FREEBSD_SRC
# (`elebake setenv ELEBAKE_FREEBSD_SRC <path>`).
#
# ARCHITECTURE: TERMINAL — emits ONLY shell (checks fail inline, no elebake call).

#-----------------------------------------------------------------------------
# _freebsd_prerequisites0 — general FreeBSD source-build environment
#-----------------------------------------------------------------------------
#@help _freebsd_prerequisites0
# @command freebsd prerequisites
# @summary Check the FreeBSD source-build environment (toolchain + source repo), at generation time
# @group   diagnostics
# @env ELEBAKE_FREEBSD_PREREQUISITES  curated tool list the generator probes (see the template)
# @env ELEBAKE_FREEBSD_SRC            path to the FreeBSD source repo (set per machine: elebake setenv)
#@end
_freebsd_prerequisites0() {
  # Non-modifying inspection: World (toolchain, repo) is probed by the
  # GENERATOR as-is; the emission is comment lines only. A missing piece
  # fails the generation with the way out.
  local src="${ELEBAKE_FREEBSD_SRC:-}" tools="${ELEBAKE_FREEBSD_PREREQUISITES:-}" t
  [ -n "$tools" ] || {
    generate_error "freebsd prerequisites: ELEBAKE_FREEBSD_PREREQUISITES not set (environment init <profile>)"; return 0; }
  for t in $tools; do
    command -v "$t" >/dev/null 2>&1 || {
      generate_error "freebsd prerequisites: $t not found (pkg install $t?)"; return 0; }
  done
  [ -n "$src" ] || {
    generate_error "freebsd prerequisites: ELEBAKE_FREEBSD_SRC not set -- elebake setenv ELEBAKE_FREEBSD_SRC <path-to-freebsd-src>"; return 0; }
  [ -d "$src/.git" ] || {
    generate_error "freebsd prerequisites: not a git repo: $src (ELEBAKE_FREEBSD_SRC)"; return 0; }
  emit_note "freebsd prerequisites ok (checked at generation time): $tools; src: $src"
}
