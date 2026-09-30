#!/bin/sh
#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Dr. Johannes Brügmann
# elebake-compile.sh -- elebake-binary.sh by its other name: writes the script instead of running it.
# A file rather than a symlink: GitHub Pages refuses to deploy a repository
# that contains one, and the manual page lives there.
ELV_MODE=compile exec /bin/sh "$(dirname "$0")/elebake-binary.sh" "$@"
