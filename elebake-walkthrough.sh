#!/bin/sh
#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Dr. Johannes Brügmann
# elebake-walkthrough.sh -- elebake-binary.sh by its other name: shows the tree of a command as text, acts on nothing.
# A file rather than a symlink: GitHub Pages refuses to deploy a repository
# that contains one, and the manual page lives there.
ELV_MODE=walk exec /bin/sh "$(dirname "$0")/elebake-binary.sh" "$@"
