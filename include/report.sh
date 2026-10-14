#!/bin/sh
#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Dr. Johannes Brügmann
#
# report.sh -- the vocabulary of elvboot, the report over the kept boots
# of a stage: what elvbootd kept under ELEBAKE_STATE_DB/boots (the loader's
# kenv of every boot with the session's verdicts, workflow boot-snapshots),
# the witnesses' receipts of the stage, and the chain the snapshots form.
# Read-only; the act that reads the state directory runs as root (its pin),
# everything else as the owner. elvboot.sh binds this module and nothing
# of elebake's stage vocabulary; the database is the same.

#@help
# @defgroup report  Report
# @order   70
#   The owner's reading of the kept boots: one line per boot, the fallen
#   claims with the leaves behind them, the aggregates, the witnesses'
#   receipts, the chain of snapshots and the sources with their digests
#   -- Markdown, to sign with 'elebake attest <file> <key>'.
#@end

#@help ___report1
# @command report <stage>
# @summary The report over every kept boot of the stage (Markdown on stdout): the stage exists, then 'report render <stage> all -'
# @group   report
# @example elvboot report daily-v1 > report.md
# @see     report last
# @see     report since
# @see     boot
# @see     witness
#@end
___report1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" report stage exists '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" report render '$1' all -"
}

#@help ___report_last2
# @command report last <stage> <n>
# @summary The report over the <n> newest kept boots: the stage exists, then 'report render <stage> last <n>'
# @group   report
# @example elvboot report last daily-v1 10
# @see     report
#@end
___report_last2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" report stage exists '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" report render '$1' last '$2'"
}

#@help ___report_since2
# @command report since <stage> <when>
# @summary The report over the kept boots since a time (UTC, 2026-10-12T00:00:00Z or any prefix of it): the stage exists, then 'report render <stage> since <when>'
# @group   report
# @example elvboot report since daily-v1 2026-10-01
# @see     report
#@end
___report_since2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" report stage exists '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" report render '$1' since '$2'"
}

#@help ___boot2
# @command boot <stage> <id>
# @summary One boot in full: <id> a counter (every kept boot with it -- the counter starts at 1 again when the record chain starts anew) or the stamp a snapshot's name begins with; the stage exists, then 'report render <stage> boot <id>'
# @group   report
# @example elvboot boot daily-v1 42
# @see     report
#@end
___boot2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" report stage exists '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" report render '$1' boot '$2'"
}

#@help ___witness1
# @command witness <stage>
# @summary The witnesses' receipts of the stage, the lines for paper and the public commit: the stage exists, then 'witness lines <stage>'
# @group   report
# @example elvboot witness daily-v1
# @see     report
#@end
___witness1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" report stage exists '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" witness lines '$1'"
}

#@help __report_stage_exists1
# @command report stage exists <stage>
# @summary The stage is in the database: a comment line, else an error line
# @group   report
# @internal
# @see     report
#@end
__report_stage_exists1() {
        if test -d "$ELEBAKE_BASE/stage/$1/"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'stage $1'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'no stage $1 in $ELEBAKE_BASE'"
        fi
}

#@help _report_render3
# @command report render <stage> <mode> <value>
# @summary Act terminal (root: the state directory is root's): one line, template/report/render.sh with the state directory, the stage, <mode> (all, last <n>, since <utc>, boot <id>), the value, the template directory and the database -- the Markdown report over the selected snapshots of ELEBAKE_STATE_DB/boots: title and selection, one table line per boot (counter, time, medium, chain, fallen gates, elvbootd verdicts, unlocks), per boot the fallen claims with the leaves of the gate that carry the claim's first word, the aggregates (boots per medium, failures per claim, PcrBank rounds, unlocks, chain restarts and gaps, boot time, the last witness state), the chain of snapshots (each header's sha256 of its predecessor against the file), the witnesses' receipts of the stage (labels, table, whole card), the sources with their digests. Snapshots in the old counter-only naming (<counter>.kenv, no header) come first, ordered by modification time, which stands in for their time; they stand before the chain. The program over the snapshots is template/awk/report.awk
# @group   report
# @internal
# @env     ELEBAKE_STATE_DB      the state directory of the hooks (boots/ below it)
# @env     ELEBAKE_TEMPLATE_DIR  the template directory (report/render.sh, awk/report.awk)
# @see     report
#@end
_report_render3() {
        printf 'sh %s %s %s %s %s %s %s\n' "$(sq "$ELEBAKE_TEMPLATE_DIR/report/render.sh")" "$(sq "${ELEBAKE_STATE_DB:-/var/db/elvboot}")" "$(sq "$1")" "$(sq "$2")" "$(sq "$3")" "$(sq "$ELEBAKE_TEMPLATE_DIR")" "$(sq "$ELEBAKE_BASE")"
}

#@help ___report_forensic1
# @command report forensic <stage>
# @summary The forensic report (Markdown on stdout, English): the stage exists, then 'report forensic render <stage>' -- part one from the database as the owner: subject (machine, database, stage, the elebake version and commit, the loader source commit, the export serial), trust anchors (keys, loader, manifest, conf, hooks with digests), requirements (phase, gate, claim, expectation, measurement, reactions), baselines, loader leaves with their record times, inventory sets, disks, witnesses (configuration against every receipt), rescue, quarantine -- then 'report render <stage> all -' as root: every kept boot, the chain, the explanations on file (acknowledged findings, learned expectations), the sources with their digests. Sign the file with 'report sign'
# @group   report
# @example elvboot report forensic daily-v1 > report-20261014.md
# @see     report sign
# @see     report
#@end
___report_forensic1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" report stage exists '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" report forensic render '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" report render '$1' all -"
}

#@help _report_forensic_render1
# @command report forensic render <stage>
# @summary Act terminal (the owner): one line, template/report/forensic.sh with the database, the stage, the template directory, the elebake version line and the state directory -- part one of the forensic report, read from the database's records alone
# @group   report
# @internal
# @env     ELEBAKE_STATE_DB      the state directory of the hooks (named in the subject)
# @env     ELEBAKE_TEMPLATE_DIR  the template directory (report/forensic.sh, awk/inventory-rows.awk)
# @env     ELEBAKE_FORMAT        the dump format major version (the version line of the subject)
# @env     ELEBAKE_LIBDIR        the library directory whose checkout names the commit of the version line
# @see     report forensic
#@end
_report_forensic_render1() {
        local commit=""
        commit=$(git -C "$ELEBAKE_LIBDIR" rev-parse --short HEAD 2>/dev/null)
        test -n "$commit" || commit=$(head -n1 "$ELEBAKE_LIBDIR/VERSION" 2>/dev/null)
        printf 'sh %s %s %s %s %s %s\n' "$(sq "$ELEBAKE_TEMPLATE_DIR/report/forensic.sh")" "$(sq "$ELEBAKE_BASE")" "$(sq "$1")" "$(sq "$ELEBAKE_TEMPLATE_DIR")" "$(sq "elebake $ELEBAKE_FORMAT ${commit:-unknown}")" "$(sq "${ELEBAKE_STATE_DB:-/var/db/elvboot}")"
}

#@help ___report_sign2
# @command report sign <stage> <file>
# @completion file none
# @summary Sign a report file with the attest key of the stage (the key that signs the manifests and the baselines, in root's keyring): the stage exists, the file exists, the attest key is bound and carries its keyid; then 'report detachsign <stage> <file>' -- the armored detached signature <file>.asc, the owner's afterwards. Verify with gpg --verify <file>.asc <file> against the key's public part
# @group   report
# @example elvboot report sign daily-v1 report-20261014.md
# @see     report forensic
#@end
___report_sign2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" report stage exists '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" report file exists $(sq "$2")"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" report attest key complete '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" report detachsign '$1' $(sq "$2")"
}

#@help __report_file_exists1
# @command report file exists <file>
# @completion file none
# @summary The file to sign is there and not empty: a comment line, else an error line
# @group   report
# @internal
# @see     report sign
#@end
__report_file_exists1() {
        if test -s "$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'report file $1'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'report sign: no such file or empty: $1'"
        fi
}

#@help __report_attest_key_complete1
# @command report attest key complete <stage>
# @summary The stage's attest-key record is bound and carries its keyid: a comment line naming the keyid, else an error line (elebake stage attest key)
# @group   report
# @internal
# @see     report sign
#@end
__report_attest_key_complete1() {
        if test -s "$ELEBAKE_BASE/stage/$1/attest-key/keyid"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'attest key of $1: $(sed -n 1p "$ELEBAKE_BASE/stage/$1/attest-key/keyid")'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'report sign: stage $1 has no attest key with a keyid (elebake stage attest key $1 openpgp <key>)'"
        fi
}

#@help _report_detachsign2
# @command report detachsign <stage> <file>
# @completion file none
# @summary Act terminal (root: the attest key lives in root's keyring): rm -f of a stale <file>.asc, GPG_TTY for the card's pinentry, gpg --detach-sign with the record's keyid (and GNUPGHOME when recorded), the signature handed to the owner (0644)
# @group   report
# @internal
# @see     report sign
#@end
_report_detachsign2() {
        local gpgenv=""
        test ! -f "$ELEBAKE_BASE/stage/$1/attest-key/gnupghome" || gpgenv="GNUPGHOME='$(head -n1 "$ELEBAKE_BASE/stage/$1/attest-key/gnupghome")' "
        emit_note "elvboot report sign '$1': armored detached signature -> $2.asc with $(head -n1 "$ELEBAKE_BASE/stage/$1/attest-key/keyid" 2>/dev/null)"
        printf '%s\n' "rm -f $(sq "$2.asc")"
        printf '%s\n' "GPG_TTY=\$( { tty </dev/tty; } 2>/dev/null ); export GPG_TTY; ${gpgenv}gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1 || true"
        printf '%s\n' "${gpgenv}gpg --yes --openpgp -a --detach-sign --local-user '$(head -n1 "$ELEBAKE_BASE/stage/$1/attest-key/keyid" 2>/dev/null)' -o $(sq "$2.asc") $(sq "$2") || { rm -f $(sq "$2.asc"); printf '# Error: report sign failed for %s\\n' $(sq "$2") >&2; exit 1; }"
        printf '%s\n' "chown '$(id -un)' $(sq "$2.asc") && $MODIFY_FILE_PERMS 0644 $(sq "$2.asc")"
        printf '%s\n' "printf '# report %s signed: %s.asc\\n' $(sq "$2") $(sq "$2") >&2"
}

#@help ___freeze1
# @command freeze <stage>
# @summary The freeze mark of the hooks' state directory: the stage exists, then 'freeze lines <stage>' prints the findings that set it -- earlboot's freeze_act keeps one line per fallen narrow gate (UTC, gate, verdict, the fallen tells) -- or says that none stands. While the mark stands, elebake stage push and stage tpm seal refuse (stage freeze check); the owner reads the lines and, once the findings are explained (a rebuild moved PcrBank, a card changed twice), acknowledges with freeze ack
# @group   report
# @example elvboot freeze daily-v1
# @see     freeze ack
# @see     report
#@end
___freeze1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" report stage exists '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" freeze lines '$1'"
}

#@help ___freeze_ack1
# @command freeze ack <stage>
# @summary Acknowledge the freeze mark: the stage exists, the findings are printed once more (freeze lines), then 'freeze clear <stage>' removes the mark. The owner's decision, after reading, that the findings are explained; the next boot's claim freeze-clear passes again and elebake's push and seal are open
# @group   report
# @example elvboot freeze ack daily-v1
# @see     freeze
#@end
___freeze_ack1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" report stage exists '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" freeze lines '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" freeze clear '$1'"
}

#@help _freeze_lines1
# @command freeze lines <stage>
# @summary Act terminal (root: the state directory is root's): the lines of ELEBAKE_STATE_DB/freeze, each a finding earlboot's freeze_act kept, or the comment that no mark stands
# @group   report
# @internal
# @env     ELEBAKE_STATE_DB  the state directory of the hooks (freeze below it)
# @see     freeze
#@end
_freeze_lines1() {
        local f; f=$(sq "${ELEBAKE_STATE_DB:-/var/db/elvboot}/freeze")
        printf 'if test -s %s; then cat %s; else printf %s; fi\n' "$f" "$f" "$(sq "# no freeze mark under ${ELEBAKE_STATE_DB:-/var/db/elvboot} (freeze_act writes it)\n")"
}

#@help _freeze_clear1
# @command freeze clear <stage>
# @summary Act terminal (root): the lines of ELEBAKE_STATE_DB/freeze move, each prefixed with the UTC of the acknowledgement, into ELEBAKE_STATE_DB/acknowledged (the journal the report lists under the explanations on file), then the mark is removed and said so
# @group   report
# @internal
# @env     ELEBAKE_STATE_DB  the state directory of the hooks (freeze below it)
# @see     freeze ack
#@end
_freeze_clear1() {
        local f="" j=""
        f=$(sq "${ELEBAKE_STATE_DB:-/var/db/elvboot}/freeze")
        j=$(sq "${ELEBAKE_STATE_DB:-/var/db/elvboot}/acknowledged")
        printf 'if test -s %s; then sed "s/^/$(date -u +%%Y-%%m-%%dT%%H:%%M:%%SZ) acknowledged: /" %s >> %s && chmod 0600 %s; fi\n' "$f" "$f" "$j" "$j"
        printf 'rm -f %s && printf %s\n' "$f" "$(sq '# freeze mark acknowledged and removed (journal: acknowledged)\n')"
}

#@help _witness_lines1
# @command witness lines <stage>
# @summary Print the witnesses' receipts of the stage: per witness the last labels receipt (UTC, GPT uuid, medium identity, digest) and the last whole-card receipt (UTC, medium identity, digest)
# @group   report
# @internal
# @see     witness
#@end
_witness_lines1() {
        local r
        printf '# witnesses of %s\n' "$1"
        test -n "$(find "$ELEBAKE_BASE/stage/$1/witness-receipts" -type f ! -name '*.full' 2>/dev/null)" || printf '#   none (stage witness add, stage witness measure)\n'
        find "$ELEBAKE_BASE/stage/$1/witness-receipts" -type f ! -name '*.full' 2>/dev/null | sort | while IFS= read -r r; do
                printf '#   %s: %s\n' "${r##*/}" "$(tail -n 1 "$r")"
                test -f "$r.full" && printf '#     whole: %s\n' "$(tail -n 1 "$r.full")"
        done
}
