# report.awk -- the report over the kept boots (elvboot report render): one
# snapshot per file, in stamp order. Line 1 of a snapshot is its header
# ('# counter=<n> at=<UTC> prev=<sha256 of the predecessor>'), then the
# loader's kenv (loader.trust.* leaves), then -- after '# elvbootd at=' --
# the session's appraisals ('gate=<g> verdict=<v>' lines under
# '# appraisal-<g>') and the spool lines since the boot. Variables from
# the act: stage, now, host, mode, arg, dir, stamps (the modification
# times of the snapshots in the old counter-only naming, '<file>=<UTC>'
# per line: those carry no header, their counter is the file's name and
# their first line is a leaf already).
function strip(v) { sub(/^"/, "", v); sub(/"$/, "", v); return v }
function first_word(c,    w) { w = c; sub(/^[A-Z][a-z0-9]*/, "", w); return tolower(substr(c, 1, length(c) - length(w))) }
function numeric(s) { return s ~ /^[0-9]+$/ }
BEGIN { m = split(stamps, sl, "\n"); for (i = 1; i <= m; i++) { k = sl[i]; sub(/=.*/, "", k); v = sl[i]; sub(/^[^=]*=/, "", v); mtime[k] = v } }
FNR == 1 {
	n++; file[n] = FILENAME; sub(/.*\//, "", file[n]); section = "loader"
	medium[n] = "-"; chain[n] = "-"; appr[n] = "-"; failed[n] = ""; nf[n] = 0; unlocks[n] = 0
	if ($0 ~ /^# counter=/) {
		counter[n] = $0; sub(/.* counter=/, "", counter[n]); sub(/ .*/, "", counter[n])
		at[n] = $0; sub(/.* at=/, "", at[n]); sub(/ .*/, "", at[n])
		next
	}
	old++; counter[n] = file[n]; sub(/\.kenv$/, "", counter[n]); at[n] = (file[n] in mtime ? mtime[file[n]] : "-")
}
/^# elvbootd at=/ { section = "elvbootd"; closed[n] = 1; next }
section == "loader" && /^loader\.trust\./ {
	key = $0; sub(/=.*/, "", key); val = $0; sub(/^[^=]*=/, "", val); val = strip(val)
	k2 = substr(key, 14); gate = k2; sub(/\..*/, "", gate); rest = substr(k2, length(gate) + 2)
	nk[n]++; keys[n, nk[n]] = key; gateof[n, nk[n]] = gate; restof[n, nk[n]] = rest; valof[n, nk[n]] = val
	if (rest == "failed" && val != "") {
		failed[n] = failed[n] (failed[n] == "" ? "" : "; ") gate ": " val
		m = split(val, cl, ",")
		for (i = 1; i <= m; i++) { fails[cl[i]]++; nf[n]++; fgate[n, nf[n]] = gate; fclaim[n, nf[n]] = cl[i] }
	}
	if (rest ~ /(^|\.)medium$/ && val ~ /^now=/) { medium[n] = val; sub(/^now=/, "", medium[n]); sub(/,.*/, "", medium[n]) }
	if (rest == "record") {
		chain[n] = val; sub(/.*chain=/, "", chain[n]); sub(/,.*/, "", chain[n])
		b = val; if (sub(/.*bootms=/, "", b)) { sub(/,.*/, "", b); if (numeric(b)) { bootms_sum += b; bootms_n++ } }
	}
	if (rest ~ /witness\.state$/) wstate = val
	next
}
section == "elvbootd" && /^gate=/ {
	g = $1; sub(/^gate=/, "", g); v = $2; sub(/^verdict=/, "", v)
	appr[n] = (appr[n] == "-" ? "" : appr[n] ", ") g ":" v
	next
}
section == "elvbootd" && / unlock-ack / { unlocks[n]++; unlocks_total++; next }
END {
	printf "# elvboot report -- %s\n\n", stage
	printf "%s on %s, snapshots under %s, selection: %s %s, boots: %d", now, host, dir, mode, arg, n
	if (old > 0) printf " (%d of them in the old counter-only naming: before the chain, their time the file's)", old
	printf "\n\n## Boots\n\n| counter | at (UTC) | medium | chain | gates failed | elvbootd | unlocks |\n|---|---|---|---|---|---|---|\n"
	for (i = 1; i <= n; i++) {
		printf "| %s | %s | %s | %s | %s | %s | %d |\n", counter[i], at[i], medium[i], chain[i], (failed[i] == "" ? "-" : failed[i]), (closed[i] ? appr[i] : "(open: no shutdown run)"), unlocks[i]
		media[medium[i]]++
		if (i > 1 && numeric(counter[i]) && numeric(counter[i-1])) {
			if (counter[i] + 0 < counter[i-1] + 0) restarts++
			else if (counter[i] - counter[i-1] > 1) gaps++
		}
	}
	printf "\n## Fallen claims\n\n"
	any = 0
	for (i = 1; i <= n; i++) {
		if (nf[i] == 0) continue
		any = 1
		printf "### boot %s (%s)\n\n", counter[i], at[i]
		for (j = 1; j <= nf[i]; j++) {
			printf "- %s/%s\n", fgate[i, j], fclaim[i, j]
			w = first_word(fclaim[i, j]); shown = 0
			for (k = 1; k <= nk[i]; k++) {
				if (gateof[i, k] != fgate[i, j]) continue
				if (restof[i, k] ~ /^(failed|passed|skipped|ledger)$/) continue
				if (index(tolower(restof[i, k]), w) == 0) continue
				printf "    %s=%s\n", keys[i, k], valof[i, k]; shown++
			}
			if (shown) continue
			printf "    (no leaf of the gate carries '%s'; the gate's leaves:)\n", w
			for (k = 1; k <= nk[i] && shown < 12; k++) {
				if (gateof[i, k] != fgate[i, j]) continue
				if (restof[i, k] ~ /^(failed|passed|skipped|ledger)$/) continue
				printf "    %s=%s\n", keys[i, k], valof[i, k]; shown++
			}
		}
		printf "\n"
	}
	if (!any) printf "none in the selection\n\n"
	printf "## Aggregates\n\n"
	s = ""; for (m in media) s = s (s == "" ? "" : ", ") m "=" media[m]
	printf "- boots per medium: %s\n", s
	s = ""; for (c in fails) s = s (s == "" ? "" : ", ") c "=" fails[c]
	printf "- failures per claim: %s\n", (s == "" ? "none" : s)
	printf "- PcrBank rounds: %d\n", fails["PcrBank"] + 0
	printf "- unlocks acknowledged: %d\n", unlocks_total + 0
	printf "- chain restarts (counter fell): %d, gaps (counter stepped by more than one): %d\n", restarts + 0, gaps + 0
	if (bootms_n > 0) printf "- boot time (loader, previous boot's record): %d ms average over %d\n", bootms_sum / bootms_n, bootms_n
	printf "- last witness state: %s\n", (wstate == "" ? "none published" : wstate)
}
