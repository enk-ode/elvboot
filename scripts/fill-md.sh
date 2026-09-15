#!/bin/sh
#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Dr. Johannes Brügmann
# fill-md.sh -- fill the paragraphs of a Markdown file at 80 columns,
# justified, the way the tutorial is kept: emacs in batch mode, markdown-mode
# (code blocks and tables stay untouched), fill-region with full
# justification (the interactive C-u M-q). Run after every edit of
# docs/TUTORIAL.md; blockquotes are filled too -- unfill one by hand if it
# reads better as typed.
#
# usage: scripts/fill-md.sh <file.md> [...]
set -eu
for f in "$@"; do
	emacs --batch "$f" --eval '(progn (package-initialize) (markdown-mode) (setq fill-column 80) (fill-region (point-min) (point-max) (quote full)) (save-buffer))' 2>&1 | grep -v '^Loading\|^Wrote\|^Package' || true
done
