#!/bin/sh
#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Dr. Johannes Brügmann
#
# render.sh -- the act of 'elvboot report render <stage> <mode> <value>':
# the Markdown report over the selected snapshots of the hooks' state
# directory (root's), run by the pinned interpreter. Arguments: state
# directory, stage, mode (all|last|since|boot), value, template directory,
# database. The program over the snapshots is awk/report.awk; the chain,
# the witnesses' receipts and the sources are rendered here. Snapshots in
# the old counter-only naming (<counter>.kenv, no header) come first,
# ordered by modification time, which stands in for their header's time.
state=$1; stage=$2; mode=$3; arg=$4; tdir=$5; base=$6
d="$state/boots"
test -d "$d" || { printf '# no snapshots under %s (workflow boot-snapshots)\n' "$d" >&2; exit 1; }
old=$(find "$d" -type f -name '*.kenv' ! -name '[0-9]*T[0-9]*Z-*.kenv' -exec stat -f '%m %N' {} + | sort -n | sed 's/^[0-9]* //')
all=$(printf '%s\n%s\n' "$old" "$(find "$d" -type f -name '[0-9]*T[0-9]*Z-*.kenv' | sort)" | sed '/^$/d')
stamps=$(for f in $old; do printf '%s=%s\n' "${f##*/}" "$(date -u -r "$(stat -f %m "$f")" +%Y-%m-%dT%H:%M:%SZ)"; done)
case "$mode" in
all) files=$all ;;
last) files=$(printf '%s\n' "$all" | tail -n "$arg") ;;
since) files=$(for f in $all; do at=$(head -n 1 "$f" | sed -n 's/^# counter=.* at=\([^ ]*\).*/\1/p'); [ -n "$at" ] || at=$(printf '%s\n' "$stamps" | sed -n "s/^${f##*/}=//p"); [ "$at" \< "$arg" ] || printf '%s\n' "$f"; done) ;;
boot) case "$arg" in
      *[!0-9]*) files=$(printf '%s\n' "$all" | grep -- "/$arg") ;;
      *) files=$(printf '%s\n' "$all" | grep -- "[-/]$arg\.kenv$") ;;
      esac ;;
*) printf '# report render: unknown mode %s\n' "$mode" >&2; exit 1 ;;
esac
[ -n "$all" ] || { printf '# no snapshot under %s yet: the first shutdown run of elvbootd writes one (workflow boot-snapshots)\n' "$d" >&2; exit 1; }
[ -n "$files" ] || { printf '# no snapshot matches %s %s under %s (%s kept; report all lists them)\n' "$mode" "$arg" "$d" "$(printf '%s\n' "$all" | wc -l | tr -d ' ')" >&2; exit 1; }
awk -v stage="$stage" -v now="$(date -u +%Y-%m-%dT%H:%M:%SZ)" -v host="$(hostname)" -v mode="$mode" -v arg="$arg" -v dir="$d" -v stamps="$stamps" -f "$tdir/awk/report.awk" $files
printf '\n## Chain\n\n'
p=""; breaks=0
for f in $files; do
	h=$(head -n 1 "$f" | sed -n 's/^# counter=.* prev=//p')
	if ! head -n 1 "$f" | grep -q '^# counter='; then printf -- '- %s: before the chain (counter-only naming, no header)\n' "${f##*/}"; continue
	elif [ -z "$p" ]; then printf -- '- %s: first of the selection (header prev=%s)\n' "${f##*/}" "${h:-none}"
	elif [ "$h" = "$(sha256 -q "$p")" ]; then printf -- '- %s: chained to %s\n' "${f##*/}" "${p##*/}"
	else printf -- '- %s: NOT chained to %s (header prev=%s)\n' "${f##*/}" "${p##*/}" "${h:-none}"; breaks=$((breaks + 1)); fi
	p=$f
done
printf -- '- breaks: %s\n' "$breaks"
printf '\n## Witnesses\n\n'
rdir="$base/stage/$stage/witness-receipts"
n=0
for r in "$rdir"/*; do
	[ -f "$r" ] || continue
	case "$r" in *.full|*.gpt) continue ;; esac
	n=$((n + 1))
	printf -- '- %s: %s\n' "${r##*/}" "$(tail -n 1 "$r")"
	[ -f "$r.gpt" ] && printf -- '  table: %s\n' "$(tail -n 1 "$r.gpt")"
	[ -f "$r.full" ] && printf -- '  whole: %s\n' "$(tail -n 1 "$r.full")"
done
[ "$n" -gt 0 ] || printf -- '- no witness receipts under %s (stage witness measure)\n' "$rdir"
printf '\n## Sources\n\n| file | sha256 |\n|---|---|\n'
for f in $files; do printf '| %s | %s |\n' "${f##*/}" "$(sha256 -q "$f")"; done
for r in "$rdir"/*; do [ -f "$r" ] && printf '| witness-receipts/%s | %s |\n' "${r##*/}" "$(sha256 -q "$r")"; done
exit 0
