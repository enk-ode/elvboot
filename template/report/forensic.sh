#!/bin/sh
#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Dr. Johannes Brügmann
#
# forensic.sh -- the act of 'elvboot report forensic render <stage>': the
# first part of the forensic report, rendered by the owner from the
# database alone -- what was required, from which code, by which keys,
# with which witnesses. The second part (the boots, the chain, the
# explanations on file) is report/render.sh, root's. Arguments: database,
# stage, template directory, the elebake version line, the state
# directory. Every table names the files it was read from; nothing here
# is computed from anything but those files.
base=$1; stage=$2; tdir=$3; version=$4; state=$5
S="$base/stage/$stage"
now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
dbname=$(basename "$(readlink -f "$base" 2>/dev/null || printf '%s' "$base")")
one() { sed -n 1p "$1" 2>/dev/null; }
digest() { test -f "$1" && sha256 -q "$1" 2>/dev/null || printf 'absent'; }
mtime() { test -e "$1" && date -u -r "$(stat -f %m "$1")" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || printf '-'; }
redact() {
	case "$1" in
	LOADER_TRUST_WORD_SECRET|LOADER_TRUST_RECORD_SALT|LOADER_TRUST_UNLOCK_SECRET) printf '<redacted: %s, %s characters>' "$2" "$(printf '%s' "$3" | wc -c | tr -d ' ')" ;;
	*) printf '%s' "$3" ;;
	esac
}
printf '# elvboot report -- forensic\n\n'
printf 'Generated %s on %s by %s with %s. This document renders three sources and invents nothing: the database (what was required), the state directory of the hooks (what every boot measured), the media and their receipts (what the witnesses saw). Every table names the files it was read from; the last section lists them with their digests. The signature over this file (report sign) is the attest key of the stage, named below.\n\n' "$now" "$(hostname)" "$(id -un)" "$version"

printf '## 1. Subject\n\n'
printf '| item | value | source |\n|---|---|---|\n'
printf '| machine | %s | hostname |\n' "$(hostname)"
printf '| database | %s (%s) | the directory the database path resolves to |\n' "$dbname" "$base"
printf '| stage | %s, created %s | stage/%s/metadata |\n' "$stage" "$(sed -n 's/^created=//p' "$S/metadata" 2>/dev/null)" "$stage"
printf '| elebake | %s | elebake version: the tool that wrote the database and rendered this report |\n' "$version"
printf '| loader source | %s | stage/%s/checkout: the commit of the fork the loader, earlboot and elvbootd were built from -- every measurement named below is a function in that tree |\n' "$(one "$S/checkout")" "$stage"
printf '| export serial | %s | export/serial: the database as last exported and attested |\n' "$(one "$base/export/serial")"
printf '| state directory | %s | the hooks keep every boot there (part two of this report) |\n' "$state"
printf '\n'

printf '## 2. Trust anchors\n\n'
printf '| anchor | value | source |\n|---|---|---|\n'
sk=$(readlink "$S/sign-key" 2>/dev/null); ak=$(readlink "$S/attest-key" 2>/dev/null)
printf '| signing key | %s (%s) | stage/%s/sign-key -> %s |\n' "${sk##*/}" "$(one "$S/sign-key/keyid")" "$stage" "${sk:-none}"
printf '| attest key | %s (%s) | stage/%s/attest-key -> %s; this key signs the manifests, the baselines and this report |\n' "${ak##*/}" "$(one "$S/attest-key/keyid")" "$stage" "${ak:-none}"
printf '| loader | sha256 %s | stage/%s/boot/loader.efi.signed: the signed loader the media carry |\n' "$(digest "$S/boot/loader.efi.signed")" "$stage"
printf '| manifest | %s entries, signature %s | stage/%s/boot/manifest(.asc): every file of the boot tree with its digest, what the loader verifies |\n' "$(grep -c . "$S/boot/manifest" 2>/dev/null || echo 0)" "$(test -s "$S/boot/manifest.asc" && echo present || echo absent)" "$stage"
conf=$(find "$S/boot" -name loader.trust.conf 2>/dev/null | head -n 1)
printf '| loader configuration | sha256 %s | %s: the leaves the loader reads (section 5) |\n' "$(digest "$conf")" "${conf#"$base/"}"
for h in "$S"/hooks/earlboot "$S"/hooks/hook.*.sh; do
	test -f "$h" || continue
	printf '| hook %s | sha256 %s | stage/%s/hooks/%s: what runs in userland (earlboot in SYSINIT, elvbootd in its phases) |\n' "${h##*/}" "$(digest "$h")" "$stage" "${h##*/}"
done
printf '\n'

printf '## 3. Requirements\n\n'
printf 'Per phase the gates bound to it; per gate its claims; per claim the expectation (kind, label, value) and the measurement that produced the value at boot; per policy the reactions (condition -> act). Read from stage/%s/phases/*, foundation/policies/*, foundation/gates/*/claims, foundation/claims/*, foundation/expectations/*, foundation/triggers/*.\n\n' "$stage"
printf '| phase | gate (policy) | claim | expectation | measurement | reactions |\n|---|---|---|---|---|---|\n'
order="PHASE_BOOT PHASE_BOOT_POST PHASE_LOADER PHASE_LOADER_POST PHASE_KERNEL PHASE_KERNEL_POST SYSINIT MOUNTED STARTUP PERIODIC RESUME MEDIA SHUTDOWN"
phases=$(for p in $order; do test -f "$S/phases/$p" && printf '%s\n' "$p"; done; ls "$S/phases" 2>/dev/null | while read -r p; do case " $order " in *" $p "*) ;; *) printf '%s\n' "$p" ;; esac; done)
test -n "$phases" || printf '| (no phase bound) | | | | | |\n'
for p in $phases; do
	grep . "$S/phases/$p" 2>/dev/null | while read -r pol; do
		gate=$(sed -n 's/^gate //p' "$base/foundation/policies/$pol" 2>/dev/null)
		reacts=$(sed -n 's/^trigger //p' "$base/foundation/policies/$pol" 2>/dev/null | while read -r t; do printf '%s -> %s; ' "$(one "$base/foundation/triggers/$t" | cut -d' ' -f1)" "$(one "$base/foundation/triggers/$t" | cut -d' ' -f2)"; done)
		n=0
		grep . "$base/foundation/gates/$gate/claims" 2>/dev/null | while read -r c; do
			set -- $(one "$base/foundation/claims/$c")
			ex=$(one "$base/foundation/expectations/${4:-}")
			printf '| %s | %s (%s) | %s | %s | %s |%s|\n' "$p" "$gate" "$pol" "$c" "${ex:-none}" "${1:-?}" " ${reacts:-none}"
		done
		test -s "$base/foundation/gates/$gate/claims" || printf '| %s | %s (%s) | (no claim: the gate reacts only) | | | %s |\n' "$p" "$gate" "$pol" "${reacts:-none}"
	done
done
printf '\nExpectation kinds: byte <claim> <0|1> (the measurement is a flag), key <claim> <leaf> (the measurement is compared with the leaf the stage carries), digest/string <MACRO> (compared with a baseline of section 4).\n\n'

printf '## 4. Baselines\n\n'
printf 'The constants compiled into the loader (site.mk) from stage/%s/baselines/*: digests the loader compares with, secrets whose value this report withholds.\n\n' "$stage"
printf '| macro | kind | value | recorded (UTC) |\n|---|---|---|---|\n'
for f in "$S"/baselines/*; do
	test -f "$f" || continue
	kind=$(cut -d' ' -f1 "$f"); val=$(cut -d' ' -f2- "$f")
	printf '| %s | %s | %s | %s |\n' "${f##*/}" "$kind" "$(redact "${f##*/}" "$kind" "$val")" "$(mtime "$f")"
done
test -n "$(ls "$S/baselines" 2>/dev/null)" || printf '| (none) | | | |\n'
printf '\n'

printf '## 5. Loader leaves\n\n'
printf 'The loader.trust.* leaves of the stage (stage/%s/kenv/*), rendered into loader.trust.conf and verified by the manifest: what the loader expects, where the TPM indices are, which disks and witnesses it knows. The time is the record'"'"'s last write: a learned expectation (pcr.expected, halt.expected) shows when the owner accepted a new state.\n\n' "$stage"
printf '| leaf | value | recorded (UTC) |\n|---|---|---|\n'
for f in "$S"/kenv/*; do
	test -f "$f" || continue
	printf '| %s | %s | %s |\n' "${f##*/}" "$(one "$f")" "$(mtime "$f")"
done
printf '\n'

printf '## 6. Inventory sets\n\n'
for k in acpi efivars images; do
	n=$(grep -c . "$S/inventory/$k" 2>/dev/null || echo 0)
	r=$(ls "$S/inventory/records" 2>/dev/null | grep -c .)
	printf '### %s: %s identities in the set, %s boot records imported' "$k" "$n" "$r"
	test "$r" -gt 0 && printf ' (%s .. %s)' "$(ls "$S/inventory/records" | sort | sed -n 1p)" "$(ls "$S/inventory/records" | sort | sed -n '$p')"
	printf '\n\n'
	if test "$n" -gt 0; then
		printf 'The set (stage/%s/inventory/%s): the identities the loader must see, with the digest every imported record agreed on (MOVES marks a digest that changed between boots).\n\n' "$stage" "$k"
		printf '```\n'
		if test "$r" -gt 0; then
			ls "$S/inventory/records" | sort | sed "s|^|$S/inventory/records/|" | awk -v kind="$k" -v set=" $(cat "$S/inventory/$k" | tr '\n' ' ') " -f "$tdir/awk/inventory-rows.awk" | sort | grep ' + ' || sort "$S/inventory/$k"
		else
			sort "$S/inventory/$k"
		fi
		printf '```\n\n'
	fi
done

printf '## 7. Disks\n\n'
printf 'The internal disks whose GELI headers and partition tables the loader measures (stage/%s/disks), compiled as LOADER_TRUST_GELI_DIGEST and LOADER_TRUST_GPT_DIGEST (section 4).\n\n' "$stage"
if grep -qs . "$S/disks"; then
	printf '| device |\n|---|\n'
	grep . "$S/disks" | while read -r d; do printf '| %s |\n' "$d"; done
else
	printf '(no disk bound)\n'
fi
printf '\n'

printf '## 8. Witnesses\n\n'
printf 'A witness is a GELI container the loader reads but never opens: the hash over its four ZFS vdev labels and its GELI metadata sector moves with every write into it. Per witness: the partition (stage/%s/witness/<name>), the configuration the loader carries (kenv loader.trust.inventory.witness.<name>.*: the expected digest, the medium identity, the partition table digest, the GPT uuid), and every receipt taken (stage/%s/witness-receipts/<name>*: labels "UTC uuid medium digest", table "UTC medium digest", whole "UTC medium digest" -- the container and the free tail of its disk, the ESP and the other partitions excluded --, anchor "UTC digest" -- the table of all witnesses as written into the TPM index). The verdict compares the configuration with the newest receipt.\n\n' "$stage" "$stage"
for w in "$S"/witness/*; do
	test -f "$w" || continue
	n=${w##*/}; r="$S/witness-receipts/$n"
	printf '### %s on %s\n\n' "$n" "$(one "$w")"
	printf '| configured | value |\n|---|---|\n'
	for leaf in medium digest gpt guid; do
		printf '| %s | %s |\n' "$leaf" "$(one "$S/kenv/loader.trust.inventory.witness.$n.$leaf")"
	done
	printf '\n| receipt | lines |\n|---|---|\n'
	printf '| labels | %s |\n' "$(grep -c . "$r" 2>/dev/null || echo 0)"
	printf '| table | %s |\n' "$(grep -c . "$r.gpt" 2>/dev/null || echo 0)"
	printf '| whole | %s |\n' "$(grep -c . "$r.full" 2>/dev/null || echo 0)"
	printf '\n```\n'
	for x in "$r" "$r.gpt" "$r.full"; do
		test -s "$x" || continue
		printf '%s:\n' "${x##*/}"; sed 's/^/  /' "$x"
	done
	printf '```\n\n'
	last=$(tail -n 1 "$r" 2>/dev/null | awk '{ print $NF }')
	cd=$(one "$S/kenv/loader.trust.inventory.witness.$n.digest")
	if test -n "$last" && test "$last" = "$cd"; then printf 'Verdict: the configured digest equals the newest labels receipt (%s).\n\n' "$(tail -n 1 "$r" | cut -d' ' -f1)"
	elif test -n "$last"; then printf 'Verdict: the configured digest DIFFERS from the newest labels receipt of %s -- the configuration was not refreshed after that measurement, or the container was written since the configuration.\n\n' "$(tail -n 1 "$r" | cut -d' ' -f1)"
	else printf 'Verdict: no labels receipt yet.\n\n'; fi
done
test -n "$(ls "$S/witness" 2>/dev/null)" || printf '(no witness recorded)\n\n'
if test -s "$S/witness-receipts/anchor"; then
	printf '### anchor in the TPM (index %s)\n\n```\n' "$(one "$S/kenv/loader.trust.tpm.witness.nv")"
	sed 's/^/  /' "$S/witness-receipts/anchor"
	printf '```\n\nThe anchor is sha256 over "name:medium:digest" of every witness in the order of loader.trust.inventory.witnesses (%s), written under PolicyPCR and the owner hierarchy; the loader'"'"'s claim WitnessAnchor compares the configuration with it.\n\n' "$(one "$S/kenv/loader.trust.inventory.witnesses")"
fi

printf '## 9. Rescue\n\n'
if test -d "$S/rescue"; then
	printf '| item | value | source |\n|---|---|---|\n'
	for f in dataset pool package keyfile snapshot; do printf '| %s | %s | stage/%s/rescue/%s |\n' "$f" "$(one "$S/rescue/$f")" "$stage" "$f"; done
	for c in "$S"/rescue/cards/*; do test -f "$c" || continue; printf '| card %s | partition %s, received %s | stage/%s/rescue/cards, media |\n' "${c##*/}" "$(one "$c")" "$(one "$S/rescue/media/${c##*/}")" "$stage"; done
	printf '| baseline | %s entries, signature %s | stage/%s/rescue/baseline/MANIFEST(.asc): every file of the rescue root with its digest, signed with the attest key; stage rescue verify checks a card against it |\n' "$(grep -c . "$S/rescue/baseline/MANIFEST" 2>/dev/null || echo 0)" "$(test -s "$S/rescue/baseline/MANIFEST.asc" && echo present || echo absent)" "$stage"
	printf '| tools | %s | stage/%s/rescue/tools |\n' "$(grep . "$S/rescue/tools" 2>/dev/null | tr '\n' ' ')" "$stage"
else
	printf '(no rescue described)\n'
fi
printf '\n'

printf '## 10. Quarantine\n\n'
if test -d "$S/quarantine"; then
	printf '| item | value | source |\n|---|---|---|\n'
	for f in dataset pool partition keyfile swap snapshot received; do printf '| %s | %s | stage/%s/quarantine/%s |\n' "$f" "$(one "$S/quarantine/$f")" "$stage" "$f"; done
	printf '| baseline | %s entries, signature %s | stage/%s/quarantine/baseline/MANIFEST(.asc) |\n' "$(grep -c . "$S/quarantine/baseline/MANIFEST" 2>/dev/null || echo 0)" "$(test -s "$S/quarantine/baseline/MANIFEST.asc" && echo present || echo absent)" "$stage"
	printf '\nrc.conf of the quarantine (stage/%s/quarantine/rc):\n\n```\n' "$stage"
	grep . "$S/quarantine/rc" 2>/dev/null
	printf '```\n'
else
	printf '(no quarantine described)\n'
fi
printf '\n'
exit 0
