# report.awk -- the report over the kept boots (elvboot report render): one
# snapshot per file, in stamp order. Line 1 of a snapshot is its header
# ('# counter=<n> at=<UTC> prev=<sha256 of the predecessor>'), then the
# loader's kenv (loader.trust.* leaves), then -- after '# elvbootd at=' --
# the session's appraisals ('gate=<g> verdict=<v>' lines under
# '# appraisal-<g>') and the spool lines since the boot. Variables from
# the act: stage, now, host, mode, arg, dir, stamps (the modification
# times of the snapshots in the old counter-only naming, '<file>=<UTC>'
# words, space-separated: those carry no header, their counter is the
# file's name and their first line is a leaf already).
# Output: Markdown, flat -- one section per boot with a summary (failed,
# skipped, passed), the three categories in detail, the session; values
# as code spans, verdicts as pandoc spans with the classes pass, fail,
# skip (template/report/report.lua colours them).
function strip(v) { sub(/^"/, "", v); sub(/"$/, "", v); return v }
function first_word(c,    w) { w = c; sub(/^[A-Z][a-z0-9]*/, "", w); return tolower(substr(c, 1, length(c) - length(w))) }
function numeric(s) { return s ~ /^[0-9]+$/ }
function code(v) { if (v == "") return "none"; gsub(/`/, "'", v); return "`" v "`" }
function listed(s, cls,    out, i, m, a) {
	if (s == "") return "none"
	m = split(s, a, ","); out = ""
	for (i = 1; i <= m; i++) { if (a[i] == "") continue; out = out (out == "" ? "" : ", ") "[" a[i] "]{." cls "}" }
	return out
}
BEGIN { m = split(stamps, sl, " "); for (i = 1; i <= m; i++) { k = sl[i]; sub(/=.*/, "", k); v = sl[i]; sub(/^[^=]*=/, "", v); mtime[k] = v } }
FNR == 1 {
	n++; file[n] = FILENAME; sub(/.*\//, "", file[n]); section = "loader"
	medium[n] = "-"; chain[n] = "-"; appr[n] = ""; failed[n] = ""; nf[n] = 0; unlocks[n] = 0; ng[n] = 0; spool[n] = ""
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
	if (rest == "failed" || rest == "passed" || rest == "skipped") {
		if (!((n, gate) in seen)) { seen[n, gate] = 1; ng[n]++; gates[n, ng[n]] = gate }
		verdict[n, gate, rest] = val
	}
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
	appr[n] = appr[n] (appr[n] == "" ? "" : "\n") "- " g ": [" v "]{." (v == "pass" ? "pass" : "fail") "}"
	next
}
section == "elvbootd" && / unlock-ack / { unlocks[n]++; unlocks_total++ }
section == "elvbootd" && /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T/ { spool[n] = spool[n] (spool[n] == "" ? "" : "\n") "- " code($0); next }
END {
	printf "# elvboot report -- %s\n\n", stage
	printf "%s on %s, snapshots under %s, selection: %s %s, boots: %d", now, host, code(dir), mode, arg, n
	if (old > 0) printf " (%d of them in the old counter-only naming: before the chain, their time the file's)", old
	printf "\n\n## Boots\n\n"
	printf "One section per kept boot: what the loader published (the gates with their claims failed, skipped and passed, the leaves behind every fallen claim), then the session elvbootd appraised and spooled.\n"
	for (i = 1; i <= n; i++) {
		printf "\n### Boot %s (%s)\n\n", counter[i], at[i]
		printf "- snapshot: %s\n", code(file[i])
		printf "- medium: **%s**\n", medium[i]
		printf "- chain: **%s**\n", chain[i]
		printf "- unlocks acknowledged: **%d**\n", unlocks[i]
		printf "- session: **%s**\n", (closed[i] ? "closed (shutdown run kept)" : "open: no shutdown run")
		printf "\n#### Summary\n\n"
		s = ""; for (j = 1; j <= ng[i]; j++) { g = gates[i, j]; if (verdict[i, g, "failed"] != "") s = s (s == "" ? "" : "; ") g ": " listed(verdict[i, g, "failed"], "fail") }
		printf "- failed: %s\n", (s == "" ? "[none]{.pass}" : s)
		s = ""; for (j = 1; j <= ng[i]; j++) { g = gates[i, j]; if (verdict[i, g, "skipped"] != "") s = s (s == "" ? "" : "; ") g ": " listed(verdict[i, g, "skipped"], "skip") }
		printf "- skipped: %s\n", (s == "" ? "none" : s)
		s = ""; for (j = 1; j <= ng[i]; j++) { g = gates[i, j]; if (verdict[i, g, "passed"] != "") s = s (s == "" ? "" : "; ") g ": " listed(verdict[i, g, "passed"], "pass") }
		printf "- passed: %s\n", (s == "" ? "none" : s)
		printf "\n#### Failed\n\n"
		if (nf[i] == 0) printf "none\n"
		for (j = 1; j <= nf[i]; j++) {
			printf "- %s/%s\n", fgate[i, j], fclaim[i, j]
			w = first_word(fclaim[i, j]); shown = 0
			for (k = 1; k <= nk[i]; k++) {
				if (gateof[i, k] != fgate[i, j]) continue
				if (restof[i, k] ~ /^(failed|passed|skipped|ledger)$/) continue
				if (index(tolower(restof[i, k]), w) == 0) continue
				printf "    - %s = %s\n", code(keys[i, k]), code(valof[i, k]); shown++
			}
			if (shown) continue
			printf "    - no leaf of the gate carries '%s'; the gate's leaves:\n", w
			for (k = 1; k <= nk[i] && shown < 12; k++) {
				if (gateof[i, k] != fgate[i, j]) continue
				if (restof[i, k] ~ /^(failed|passed|skipped|ledger)$/) continue
				printf "    - %s = %s\n", code(keys[i, k]), code(valof[i, k]); shown++
			}
		}
		printf "\n#### Skipped\n\n"
		any = 0
		for (j = 1; j <= ng[i]; j++) { g = gates[i, j]; if (verdict[i, g, "skipped"] != "") { any = 1; printf "- %s: %s\n", g, listed(verdict[i, g, "skipped"], "skip") } }
		if (!any) printf "none\n"
		printf "\n#### Passed\n\n"
		any = 0
		for (j = 1; j <= ng[i]; j++) { g = gates[i, j]; if (verdict[i, g, "passed"] != "") { any = 1; printf "- %s: %s\n", g, listed(verdict[i, g, "passed"], "pass") } }
		if (!any) printf "none\n"
		printf "\n#### Session\n\n"
		if (!closed[i]) printf "open: the shutdown run did not append the session (the machine was not shut down cleanly, or the snapshot is the current boot's)\n"
		else {
			if (appr[i] != "") printf "%s\n", appr[i]; else printf "- no appraisal persisted\n"
			if (spool[i] != "") printf "\nSpool since the boot:\n\n%s\n", spool[i]
		}
		media[medium[i]]++
		if (i > 1 && numeric(counter[i]) && numeric(counter[i-1])) {
			if (counter[i] + 0 < counter[i-1] + 0) restarts++
			else if (counter[i] - counter[i-1] > 1) gaps++
		}
	}
	printf "\n## Aggregates\n\n"
	s = ""; for (m in media) s = s (s == "" ? "" : ", ") m "=" media[m]
	printf "- boots per medium: %s\n", s
	s = ""; for (c in fails) s = s (s == "" ? "" : ", ") c "=" fails[c]
	printf "- failures per claim: %s\n", (s == "" ? "none" : s)
	printf "- PcrBank rounds: %d\n", fails["PcrBank"] + 0
	printf "- unlocks acknowledged: %d\n", unlocks_total + 0
	printf "- chain restarts (counter fell): %d, gaps (counter stepped by more than one): %d\n", restarts + 0, gaps + 0
	if (bootms_n > 0) printf "- boot time (loader, previous boot's record): %d ms average over %d\n", bootms_sum / bootms_n, bootms_n
	printf "- last witness state: %s\n", (wstate == "" ? "none published" : code(wstate))
}
