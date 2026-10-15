#!/bin/sh
#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Dr. Johannes Brügmann
#
# view.sh -- an interpreter for the pin of a report act, an EXAMPLE and
# never the default: it runs the emitted act as the default pin would
# (sudo sh for report render, sh for report forensic render), renders the
# Markdown the act prints through pandoc with report.lua, report.css or
# report.tex, and opens the result -- the browser for html, the PDF
# viewer for pdf (ELEBAKE_REPORT_VIEWER, default xdg-open).
#
#   elebake setenv ELEBAKE_INTERPRETER_report_render "sh <templates>/report/view.sh html sudo"
#   elvboot report daily-v1              # the browser opens with the report
#   elebake setenv ELEBAKE_INTERPRETER_report_render "sh <templates>/report/view.sh pdf sudo"
#   elvboot report last daily-v1 10      # the PDF viewer opens
#
# The forensic report is two acts (the owner's part, root's part), so a
# pin would render two documents: pipe the whole report instead --
#
#   elvboot report forensic daily-v1 | sh <templates>/report/view.sh pdf -
#
# Arguments: the form (html | pdf), then 'sudo' (run the act as root,
# the pin's case), 'sh' (run it as the owner) or '-' (stdin is Markdown
# already, the pipe's case). pandoc for html, pandoc with a LaTeX engine
# for pdf; the Markdown itself stays the signed document.
form=${1:-html}; how=${2:-sudo}
dir=$(cd "$(dirname "$0")" && pwd)
out=$(mktemp -t elvboot-report)
mv "$out" "$out.$form"; out="$out.$form"
case "$how" in
-)    md="cat" ;;
sh)   md="sh" ;;
*)    md="sudo sh" ;;
esac
case "$form" in
html) $md | pandoc -f markdown -s --lua-filter "$dir/report.lua" -c "$dir/report.css" --embed-resources -o "$out" || exit 1 ;;
pdf)  $md | pandoc -f markdown --lua-filter "$dir/report.lua" -H "$dir/report.tex" -o "$out" || exit 1 ;;
*)    printf '# view.sh: the form is html or pdf, not %s\n' "$form" >&2; exit 1 ;;
esac
printf '# report rendered: %s\n' "$out" >&2
"${ELEBAKE_REPORT_VIEWER:-xdg-open}" "$out"
