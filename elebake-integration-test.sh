#!/bin/sh
#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Dr. Johannes Brügmann
# elebake-integration-test.sh - end-to-end user stories for elebake
#
# Story 1: full database migration — build a source DB (keys, stage with
#          records/tree/skeleton), dump, bootstrap a target, restore, and
#          prove the stage trees IDENTICAL (the 2026-08-29 migration flow).
# Story 2: replay idempotence — restore the same dump AGAIN and prove the
#          stage id stable, no .staging orphans, tree still identical.
# Story 3: negative — a dump line for an unknown stage stops that sequence
#          (check stage) while keep-going lets the rest of the replay run.
#
# Doctrine: no real devices, no NVRAM, invented node names; everything acts
# inside the sandbox databases only.
#
# Usage: ./elebake-integration-test.sh [--maxprocs N] [story numbers...]
set -u

TEST_BASE_DIR="${TMPDIR:-/tmp}/elebake-int-test.$$"
TEST_SCRIPT="./elebake.sh"

MAXPROCS=1
while [ $# -gt 0 ]; do
  case "$1" in
    --maxprocs)   MAXPROCS="${2:?--maxprocs needs a value}"; shift 2 ;;
    --maxprocs=*) MAXPROCS="${1#--maxprocs=}"; shift ;;
    *) break ;;
  esac
done
STORY_FILTER="$*"

STORIES_PASSED=0
STORIES_FAILED=0
ASSERTIONS_PASSED=0
ASSERTIONS_FAILED=0
STORY_FAILED=0

pass() { ASSERTIONS_PASSED=$((ASSERTIONS_PASSED + 1)); echo "  ✓ $*"; }
fail() { ASSERTIONS_FAILED=$((ASSERTIONS_FAILED + 1)); STORY_FAILED=1; echo "  ✗ $*"; }

story_header() { STORY_FAILED=0; echo ""; echo "STORY $1: $2"; }
story_close() {
  if [ "$STORY_FAILED" -eq 0 ]; then
    STORIES_PASSED=$((STORIES_PASSED + 1)); echo "  STORY $1 PASSED"
  else
    STORIES_FAILED=$((STORIES_FAILED + 1)); echo "  STORY $1 FAILED"
  fi
}

should_run_story() {
  [ -z "$STORY_FILTER" ] && return 0
  case " $STORY_FILTER " in *" $1 "*) return 0 ;; esac
  return 1
}

# eb <base> <args...> — run elebake against one of the story databases
eb() { local base="$1"; shift; ELEBAKE_BASE="$base" "$TEST_SCRIPT" "$@" 2>&1; }

# story_key <root> -- one throwaway OpenPGP key per story, in a home short
# enough for gpg-agent's socket. Sets STORY_GNUPGHOME and STORY_FPR.
story_key() {
  STORY_GNUPGHOME="$1/gh"
  mkdir -p "$STORY_GNUPGHOME" && chmod 700 "$STORY_GNUPGHOME"
  GNUPGHOME="$STORY_GNUPGHOME" gpg --batch --passphrase '' --pinentry-mode loopback \
    --quick-generate-key "Story <story@example.invalid>" rsa2048 sign never > /dev/null 2>&1
  STORY_FPR=$(GNUPGHOME="$STORY_GNUPGHOME" gpg --list-secret-keys --with-colons 2>/dev/null | awk -F: '/^fpr:/{print $10; exit}')
  [ -n "$STORY_FPR" ]
}
# story_pin <db> <record> -- register the story key in a database and name
# it as the archive attest key: the sender signs with it, the receiver
# pins it (one identity, one setting)
story_pin() {
  eb "$1" openpgp add "$2" "$STORY_FPR" "$STORY_GNUPGHOME" > /dev/null 2>&1
  eb "$1" setenv ELEBAKE_ARCHIVE_ATTEST_KEY "$2" > /dev/null
}

# make_source_db <root> — bootstrap a source DB and populate it with the
# canonical COMFORTABLE fixture: three key records (one with an extra file
# and a DB-internal path), one stage with filter/binding/device/boot tree
# records, a boot tree WITH an empty skeleton dir, a marker record (files
# only!), a backup file, the full foundation arsenal and a phase binding.
# THE FIXTURE IS THE COVERAGE CONTRACT (design §11, erosion detector): a
# new command family that stores state MUST be exercised here, or the
# roundtrip diff can no longer prove that dump & restore carry it.
make_source_db() {
  local root="$1" base="$1/db"
  ELEBAKE_ROOT="$root" ELEBAKE_BASE="$base" "$TEST_SCRIPT" bootstrap current minimal > "$root/bootstrap.log" 2>&1 || return 1
  eb "$base" setenv ELEBAKE_TERMINAL_INTERPRETER sh > /dev/null
  eb "$base" setenv ELEBAKE_FREEBSD_PREREQUISITES "git make clang" > /dev/null
  eb "$base" pem add filekey /nonexistent/db.key /nonexistent/db.crt > /dev/null
  eb "$base" openpgp add attest 0123456789ABCDEF /nonexistent/gnupg > /dev/null
  eb "$base" pkcs11 add tok 'pkcs11:token=int;object=db' "$base/pkcs11/tok/cert.pem" > /dev/null
  printf 'CERTMATERIAL\n' > "$base/pkcs11/tok/cert.pem"
  eb "$base" stage add story > /dev/null 2>&1
  eb "$base" stage filter add story loader.efi.signed > /dev/null 2>&1
  eb "$base" stage sign key story pkcs11 tok > /dev/null 2>&1
  eb "$base" stage attest key story openpgp attest > /dev/null 2>&1
  eb "$base" stage device story t /dev/testda99 /mnt > /dev/null 2>&1
  eb "$base" stage boot tree story t test-label pool/test > /dev/null 2>&1
  mkdir -p "$base/stage/story/boot/lua" "$base/stage/story/boot/dtb/overlays"
  printf 'EFI\n'  > "$base/stage/story/boot/loader.efi"
  printf 'LUA\n'  > "$base/stage/story/boot/lua/loader.lua"
  mkdir -p "$base/stage/story/marker"
  printf 'Boot0004\n' > "$base/stage/story/marker/bootvar"
  printf '/nonexistent/marker\n' > "$base/stage/story/marker/file"
  mkdir -p "$base/stage/story/backup/t"
  printf 'ORIG\n' > "$base/stage/story/backup/t/Boot0004.orig"
  eb "$base" macro add STORY_DIGEST sha256 StoryIdent > /dev/null
  eb "$base" expectation add story-exp byte StoryFlag 1 > /dev/null
  eb "$base" expectation add story-macro macro - STORY_EXPECTED > /dev/null
  eb "$base" claim add story-claim measure_story - story.flag story-exp > /dev/null
  eb "$base" trigger add story-fire when_always publish_act > /dev/null
  eb "$base" gate add story-gate STORY_SECRET_SLOT > /dev/null
  eb "$base" gate claim add story-gate story-claim > /dev/null
  eb "$base" policy add story-policy story-gate > /dev/null
  eb "$base" policy trigger add story-policy story-fire > /dev/null
  # binding via the check-free append (the stage has no worktree here --
  # exactly the situation a restore is in; the dump replays this line)
  eb "$base" stage phase policy append story PHASE_STORY story-policy > /dev/null 2>&1
  return 0
}

# migrate <srcbase> <dstroot> <dumpfile> — dump source, bootstrap target,
# restore; echoes the target base path.
migrate() {
  local srcbase="$1" dstroot="$2" dumpfile="$3" dstbase="$2/db"
  # A migration is an export/import pair like any other transfer: the dump
  # is sealed to its bundle and signed, the receiver pins the signer. 'full'
  # so the machine secrets (marker, backups) travel to one's own new home.
  story_key "$dstroot" || return 1
  story_pin "$srcbase" attest-story
  eb "$srcbase" export "$dumpfile" "$dstroot/bundle.tar.gz" full > "$dstroot/export.log" 2>&1
  ELEBAKE_ROOT="$dstroot" ELEBAKE_BASE="$dstbase" "$TEST_SCRIPT" bootstrap current minimal > "$dstroot/bootstrap.log" 2>&1 || return 1
  eb "$dstbase" setenv ELEBAKE_TERMINAL_INTERPRETER sh > /dev/null
  story_pin "$dstbase" attest-story
  ELEBAKE_ROOT="$dstroot" eb "$dstbase" import "$dumpfile" "$dstroot/bundle.tar.gz" > "$dstroot/restore.log" 2>&1
  printf '%s\n' "$dstbase"
}


# acc_fixture_worktree <root> <base> — a worktree fixture carrying the REAL
# loader catalog names (subset), so today's foundation arsenal validates
acc_fixture_worktree() {
  local fix="$1/work/stand/efi/loader/local"
  mkdir -p "$fix"
  cat > "$fix/measurement.h" <<'ACC_M'
struct measurement	measure_prerequisites_exist(int argc, CHAR16 *argv[]);
struct measurement	measure_prerequisites_verify(int argc, CHAR16 *argv[]);
struct measurement	measure_secureboot(int argc, CHAR16 *argv[]);
struct measurement	measure_setupmode(int argc, CHAR16 *argv[]);
struct measurement	measure_board(int argc, CHAR16 *argv[]);
struct measurement	measure_keys(int argc, CHAR16 *argv[]);
struct measurement	measure_marker(int argc, CHAR16 *argv[]);
struct measurement	measure_strict(int argc, CHAR16 *argv[]);
struct measurement	measure_ve_strict(int argc, CHAR16 *argv[]);
void	diagnose_prerequisites_exist(int argc, CHAR16 *argv[], struct diagnosis *);
void	diagnose_prerequisites_verify(int argc, CHAR16 *argv[], struct diagnosis *);
void	diagnose_keys(int argc, CHAR16 *argv[], struct diagnosis *);
void	diagnose_marker(int argc, CHAR16 *argv[], struct diagnosis *);
ACC_M
  cat > "$fix/policy.h" <<'ACC_P'
enum phase {
	PHASE_BOOT,
	PHASE_LOADER,
};
bool	when_always(const struct appraisal *);
bool	when_fail(const struct appraisal *);
bool	when_pass(const struct appraisal *);
ACC_P
  cat > "$fix/action.h" <<'ACC_A'
extern const struct action	publish_act;
extern const struct action	unlock_act;
ACC_A
  ln -sfn "$1/work" "$2/stage/acc/work"
  printf 'acc-ref
' > "$2/stage/acc/checkout"
}

# acc_arsenal <base> — today's hand-written foundation.c as a command block
acc_arsenal() {
  local base="$1"
  eb "$base" macro add BOARD_DIGEST sha256 BoardIdentity > /dev/null
  eb "$base" macro add KEYS_DIGEST sha256 SecureBootKeys > /dev/null
  eb "$base" macro add MARKER_DIGEST sha256 BootMarker > /dev/null
  eb "$base" expectation add secureboot-on   byte SecureBoot 1 > /dev/null
  eb "$base" expectation add setupmode-off   byte SetupMode 0 > /dev/null
  eb "$base" expectation add marker-expected macro - MARKER_EXPECTED > /dev/null
  eb "$base" expectation add board-expected  macro - BOARD_EXPECTED > /dev/null
  eb "$base" expectation add keys-expected   macro - KEYS_EXPECTED > /dev/null
  eb "$base" expectation add prereqs-exist   byte PrereqsExist LOADER_PREREQUISITES_EXIST_N > /dev/null
  eb "$base" expectation add prereqs-verify  byte PrereqsVerify LOADER_PREREQUISITES_VERIFY_N > /dev/null
  eb "$base" expectation add strict-active   byte StrictActive 1 > /dev/null
  eb "$base" expectation add strict-marker   byte VeStrictPresent 1 > /dev/null
  eb "$base" claim add secureboot     measure_secureboot - - secureboot-on > /dev/null
  eb "$base" claim add setupmode      measure_setupmode - - setupmode-off > /dev/null
  eb "$base" claim add marker         measure_marker diagnose_marker - marker-expected > /dev/null
  eb "$base" claim add board          measure_board - board.sha256 board-expected > /dev/null
  eb "$base" claim add keys           measure_keys diagnose_keys keys.sha256 keys-expected > /dev/null
  eb "$base" claim add prereqs-exist  measure_prerequisites_exist diagnose_prerequisites_exist exist.count prereqs-exist > /dev/null
  eb "$base" claim add prereqs-verify measure_prerequisites_verify diagnose_prerequisites_verify verify.count prereqs-verify > /dev/null
  eb "$base" claim add strict-active  measure_strict - strict.active strict-active > /dev/null
  eb "$base" claim add strict-marker  measure_ve_strict - strict.marker strict-marker > /dev/null
  eb "$base" gate add bootlock LOADER_TRUST_BOOTLOCK_SECRET > /dev/null
  eb "$base" gate claim add bootlock secureboot > /dev/null
  eb "$base" gate claim add bootlock setupmode > /dev/null
  eb "$base" gate claim add bootlock marker > /dev/null
  eb "$base" gate claim add bootlock board > /dev/null
  eb "$base" gate claim add bootlock keys > /dev/null
  eb "$base" gate add loaderlock LOADER_TRUST_LOADERLOCK_SECRET > /dev/null
  eb "$base" gate claim add loaderlock prereqs-exist > /dev/null
  eb "$base" gate claim add loaderlock prereqs-verify > /dev/null
  eb "$base" gate add strictwatch > /dev/null
  eb "$base" gate claim add strictwatch strict-active > /dev/null
  eb "$base" gate claim add strictwatch strict-marker > /dev/null
  eb "$base" trigger add publish-always when_always publish_act > /dev/null
  eb "$base" trigger add unlock-fail    when_fail unlock_act > /dev/null
  eb "$base" policy add publish-bootlock bootlock > /dev/null
  eb "$base" policy trigger add publish-bootlock publish-always > /dev/null
  eb "$base" policy add backstop-loaderlock loaderlock > /dev/null
  eb "$base" policy trigger add backstop-loaderlock publish-always > /dev/null
  eb "$base" policy trigger add backstop-loaderlock unlock-fail > /dev/null
  eb "$base" policy add watch-strict strictwatch > /dev/null
  eb "$base" policy trigger add watch-strict publish-always > /dev/null
  eb "$base" stage phase policy add acc PHASE_BOOT publish-bootlock > /dev/null 2>&1
  eb "$base" stage phase policy add acc PHASE_LOADER backstop-loaderlock > /dev/null 2>&1
  eb "$base" stage phase policy add acc PHASE_LOADER watch-strict > /dev/null 2>&1
}

# Story 4: foundation acceptance — the command block reproduces TODAY's
# hand-written foundation.c. The embedded expectation below IS the verified
# generate: its token stream was proven identical to the hand-written file
# (includes identical, all five #ifdef blocks identical as a set, the
# active part — gates, tables, switch — identical IN ORDER after comment
# stripping). Migration must preserve the emission bit for bit.
user_story_4_foundation_acceptance() {
  story_header 4 "foundation acceptance: today's foundation.c from records, migration keeps it"
  local root="$TEST_BASE_DIR/s4" base="$TEST_BASE_DIR/s4/db" dst="$TEST_BASE_DIR/s4-dst" out
  mkdir -p "$root"
  ELEBAKE_ROOT="$root" ELEBAKE_BASE="$base" "$TEST_SCRIPT" bootstrap current minimal > "$root/bootstrap.log" 2>&1 || { fail "bootstrap failed"; story_close 4; return 0; }
  eb "$base" setenv ELEBAKE_TERMINAL_INTERPRETER sh > /dev/null
  eb "$base" stage add acc > /dev/null 2>&1
  acc_fixture_worktree "$root" "$base"
  acc_arsenal "$base"
  out=$(eb "$base" stage foundation check acc 2>&1)
  if printf '%s\n' "$out" | grep -q "foundation check ok: 3 binding(s) across 2 phase(s)"; then
    pass "foundation check verifies the full arsenal and says so"
  else
    fail "foundation check answer wrong: $out"
  fi
  eb "$base" stage foundation make acc > /dev/null 2>&1
  cat > "$root/expected.c" <<'ACC_EXPECTED'
/* generated by elebake stage foundation make -- do not edit
 * stage: acc  checkout: acc-ref (unknown) */

#include "measurement.h"
#include "claim.h"
#include "policy.h"

#ifdef LOADER_TRUST_BOARD_DIGEST
#define	BOARD_EXPECTED	MEASUREMENT_SHA256("BoardIdentity", LOADER_TRUST_BOARD_DIGEST)
#else
#define	BOARD_EXPECTED	MEASUREMENT_NONE("BoardIdentity", MEAS_SHA256)
#endif

#ifdef LOADER_TRUST_KEYS_DIGEST
#define	KEYS_EXPECTED	MEASUREMENT_SHA256("SecureBootKeys", LOADER_TRUST_KEYS_DIGEST)
#else
#define	KEYS_EXPECTED	MEASUREMENT_NONE("SecureBootKeys", MEAS_SHA256)
#endif

#ifdef LOADER_TRUST_MARKER_DIGEST
#define	MARKER_EXPECTED	MEASUREMENT_SHA256("BootMarker", LOADER_TRUST_MARKER_DIGEST)
#else
#define	MARKER_EXPECTED	MEASUREMENT_NONE("BootMarker", MEAS_SHA256)
#endif

#ifdef LOADER_TRUST_BOOTLOCK_SECRET
#define	BOOTLOCK_SECRET	LOADER_TRUST_BOOTLOCK_SECRET
#else
#define	BOOTLOCK_SECRET	NULL
#endif

#ifdef LOADER_TRUST_LOADERLOCK_SECRET
#define	LOADERLOCK_SECRET	LOADER_TRUST_LOADERLOCK_SECRET
#else
#define	LOADERLOCK_SECRET	NULL
#endif

GATE_DEFINE(bootlock, BOOTLOCK_SECRET,
    CLAIM(measure_secureboot, NULL, NULL, MEASUREMENT_BYTE("SecureBoot", 1)),
    CLAIM(measure_setupmode, NULL, NULL, MEASUREMENT_BYTE("SetupMode", 0)),
    CLAIM(measure_marker, diagnose_marker, NULL, MARKER_EXPECTED),
    CLAIM(measure_board, NULL, "board.sha256", BOARD_EXPECTED),
    CLAIM(measure_keys, diagnose_keys, "keys.sha256", KEYS_EXPECTED));

GATE_DEFINE(loaderlock, LOADERLOCK_SECRET,
    CLAIM(measure_prerequisites_exist, diagnose_prerequisites_exist, "exist.count", MEASUREMENT_BYTE("PrereqsExist", LOADER_PREREQUISITES_EXIST_N)),
    CLAIM(measure_prerequisites_verify, diagnose_prerequisites_verify, "verify.count", MEASUREMENT_BYTE("PrereqsVerify", LOADER_PREREQUISITES_VERIFY_N)));

GATE_DEFINE(strictwatch, NULL,
    CLAIM(measure_strict, NULL, "strict.active", MEASUREMENT_BYTE("StrictActive", 1)),
    CLAIM(measure_ve_strict, NULL, "strict.marker", MEASUREMENT_BYTE("VeStrictPresent", 1)));

static const struct policy boot_policies[] = {
	POLICY(bootlock,
	    FIRE(when_always, &publish_act)),
	POLICY_END,
};

static const struct policy loader_policies[] = {
	POLICY(loaderlock,
	    FIRE(when_always, &publish_act),
	    FIRE(when_fail, &unlock_act)),
	POLICY(strictwatch,
	    FIRE(when_always, &publish_act)),
	POLICY_END,
};

const struct policy *
phase_policies(enum phase ph)
{
	switch (ph) {
	case PHASE_BOOT:
		return (boot_policies);
	case PHASE_LOADER:
		return (loader_policies);
	}
	return (loader_policies);
}
ACC_EXPECTED
  if diff -u "$root/expected.c" "$root/work/stand/efi/loader/local/foundation/foundation.c" > "$root/acc.diff" 2>&1; then
    pass "generated foundation.c matches the verified acceptance expectation exactly"
  else
    fail "acceptance diff: $(head -20 "$root/acc.diff")"
  fi
  cp "$root/work/stand/efi/loader/local/foundation/foundation.c" "$root/src-generated.c"
  mkdir -p "$dst"
  local dstbase
  dstbase=$(migrate "$base" "$dst" "$TEST_BASE_DIR/s4-dump.sh") || { fail "migration failed"; story_close 4; return 0; }
  eb "$dstbase" stage foundation make acc > /dev/null 2>&1
  if diff -q "$root/src-generated.c" "$root/work/stand/efi/loader/local/foundation/foundation.c" > /dev/null 2>&1; then
    pass "after dump/restore the target regenerates the identical foundation.c"
  else
    fail "regeneration differs after migration"
  fi
  story_close 4
}

# Story 5: the archive pipeline -- two artifacts in two places. The dump
# goes where git would take it, the bundle where a backup would; neither
# contains the other, and an import into a FRESH database reproduces the
# stage while the redaction strategy keeps machine secrets at home.
user_story_5_export_import() {
  story_header 5 "export/import: dump and bundle travel apart, import rebuilds"
  local root="$TEST_BASE_DIR/s5" src="$TEST_BASE_DIR/s5/src" fresh="$TEST_BASE_DIR/s5/fresh"
  mkdir -p "$root"
  ELEBAKE_ROOT="$root" ELEBAKE_BASE="$src" "$TEST_SCRIPT" bootstrap src minimal > "$root/b.log" 2>&1 \
    || { fail "bootstrap failed"; story_close 5; return 0; }
  ELEBAKE_ROOT="$root" eb "$src" setenv ELEBAKE_TERMINAL_INTERPRETER sh > /dev/null
  ELEBAKE_ROOT="$root" eb "$src" stage add s5stage > /dev/null 2>&1
  mkdir -p "$src/stage/s5stage/boot" "$src/stage/s5stage/marker"
  printf 'LOADER\n' > "$src/stage/s5stage/boot/loader.efi"
  printf 'Boot0007\n' > "$src/stage/s5stage/marker/bootvar"
  ELEBAKE_ROOT="$root" eb "$src" expectation add s5exp byte S 1 > /dev/null 2>&1

  if ELEBAKE_ROOT="$root" eb "$src" export "$root/nokey.sh" "$root/bundle/nokey.tar.gz" redacted 2>&1 \
     | grep -q "ELEBAKE_ARCHIVE_ATTEST_KEY not set"; then
    pass "an export without an attest key is refused -- an unsigned archive is not evidence"
  else
    fail "unsigned export allowed"
  fi

  story_key "$root" || { fail "could not create a story key"; story_close 5; return 0; }
  story_pin "$src" s5attest

  ELEBAKE_ROOT="$root" eb "$src" export "$root/dump-for-git.sh" "$root/bundle/s5.tar.gz" redacted > /dev/null 2>&1
  if [ -f "$root/bundle/s5.tar.gz" ] && [ -f "$root/dump-for-git.sh" ]; then
    pass "export produced both artifacts: a dump to version, a bundle to store"
  else
    fail "export produced nothing"; story_close 5; return 0
  fi

  if grep -q 'ELEBAKE_ARCHIVE_BASE' "$root/dump-for-git.sh" \
     && ! grep -q "$src/stage" "$root/dump-for-git.sh"; then
    pass "the dump is portable: paths against the base variable, no machine paths"
  else
    fail "dump is not portable"
  fi
  if grep -q "^# Bundle: sha256=$(sha256 -q "$root/bundle/s5.tar.gz") " "$root/dump-for-git.sh" \
     && [ -f "$root/dump-for-git.sh.asc" ]; then
    pass "the dump is sealed to THIS bundle and signed after sealing"
  else
    fail "seal/signature missing"
  fi

  if tar -tzf "$root/bundle/s5.tar.gz" | grep -q 'export/MANIFEST.asc'; then
    pass "the bundle carries its own tamper detection: MANIFEST and its signature"
  else
    fail "manifest pair missing from the bundle"
  fi

  if tar -tzf "$root/bundle/s5.tar.gz" | grep -q 'boot/loader.efi' \
     && ! tar -tzf "$root/bundle/s5.tar.gz" | grep -q 'marker/bootvar'; then
    pass "the bundle carries the payload and leaves the marker value at home"
  else
    fail "bundle content wrong: $(tar -tzf "$root/bundle/s5.tar.gz" | tr '\n' ' ')"
  fi

  ELEBAKE_ROOT="$root" ELEBAKE_BASE="$fresh" "$TEST_SCRIPT" bootstrap fresh minimal > "$root/f.log" 2>&1 \
    || { fail "second bootstrap failed"; story_close 5; return 0; }
  ELEBAKE_ROOT="$root" eb "$fresh" setenv ELEBAKE_TERMINAL_INTERPRETER sh > /dev/null
  local out
  out=$(ELEBAKE_ROOT="$root" eb "$fresh" import "$root/dump-for-git.sh" "$root/bundle/s5.tar.gz" 2>&1)
  if printf '%s\n' "$out" | grep -q "ATTEST_KEY not set" && [ ! -e "$fresh/stage/s5stage" ]; then
    pass "a fresh database imports nothing until its owner has pinned the sender's key"
  else
    fail "import without a pin: $out"
  fi
  ELEBAKE_ROOT="$root" eb "$fresh" openpgp add stranger 0123456789ABCDEF0123456789ABCDEF01234567 "$STORY_GNUPGHOME" > /dev/null 2>&1
  ELEBAKE_ROOT="$root" eb "$fresh" setenv ELEBAKE_ARCHIVE_ATTEST_KEY stranger > /dev/null
  out=$(ELEBAKE_ROOT="$root" eb "$fresh" import "$root/dump-for-git.sh" "$root/bundle/s5.tar.gz" 2>&1)
  if printf '%s\n' "$out" | grep -q "DIFFERENT key" && [ ! -e "$fresh/stage/s5stage" ]; then
    pass "a good signature by a key other than the pinned one is refused"
  else
    fail "foreign signer accepted: $out"
  fi
  story_pin "$fresh" s5attest

  # Tamper detection, end to end. Three shapes, each refused before restore
  # replays a line: an edited dump (its signature breaks), a foreign bundle
  # (the seal does not name it), a changed payload file (the MANIFEST names
  # it) -- the last one after extraction, the first two before.
  cp "$root/dump-for-git.sh" "$root/edited.sh"; cp "$root/dump-for-git.sh.asc" "$root/edited.sh.asc"
  printf '%s\n' '"$ELEBAKE_CONTEXT_SCRIPT" setenv ELEBAKE_EVIL yes' >> "$root/edited.sh"
  out=$(ELEBAKE_ROOT="$root" eb "$fresh" import "$root/edited.sh" "$root/bundle/s5.tar.gz" 2>&1)
  if printf '%s\n' "$out" | grep -q "BAD SIGNATURE" && [ ! -e "$fresh/stage/s5stage" ] && [ ! -d "$root/incoming/s5" ]; then
    pass "an edited dump is refused before anything is extracted"
  else
    fail "edited dump: $out"
  fi
  cp "$root/bundle/s5.tar.gz" "$root/bundle/foreign.tar.gz"; printf 'x' >> "$root/bundle/foreign.tar.gz"
  out=$(ELEBAKE_ROOT="$root" eb "$fresh" import "$root/dump-for-git.sh" "$root/bundle/foreign.tar.gz" 2>&1)
  if printf '%s\n' "$out" | grep -q "MISMATCHED PAIR" && [ ! -e "$fresh/stage/s5stage" ]; then
    pass "a genuine dump with a bundle it does not name is refused"
  else
    fail "foreign bundle: $out"
  fi
  local evil="$root/evil"
  mkdir -p "$evil" && (cd "$evil" && tar -xzf "$root/bundle/s5.tar.gz")
  local victim; victim=$(find "$evil/.staging" -name loader.efi -type f | head -1)
  [ -n "$victim" ] || { fail "no payload file to tamper with"; story_close 5; return 0; }
  printf 'TROJAN\n' > "$victim"
  (cd "$evil" && tar -czf "$root/bundle/s5-tampered.tar.gz" .)
  cp "$root/dump-for-git.sh" "$root/resealed.sh"
  sed -i '' '/^# Bundle: sha256=/d' "$root/resealed.sh"
  ELEBAKE_ROOT="$root" eb "$src" seal "$root/resealed.sh" "$root/bundle/s5-tampered.tar.gz" > /dev/null 2>&1
  ELEBAKE_ROOT="$root" eb "$src" attest "$root/resealed.sh" s5attest > /dev/null 2>&1
  out=$(ELEBAKE_ROOT="$root" eb "$fresh" import "$root/resealed.sh" "$root/bundle/s5-tampered.tar.gz" 2>&1)
  if printf '%s\n' "$out" | grep -q "CHANGED" && [ ! -e "$fresh/stage/s5stage" ]; then
    pass "a tampered payload file is named by the MANIFEST and refused BEFORE restore replays anything"
  else
    fail "tampering not caught: $out"
  fi

  ELEBAKE_ROOT="$root" eb "$fresh" import "$root/dump-for-git.sh" "$root/bundle/s5.tar.gz" > "$root/import.log" 2>&1

  if [ "$(cat "$fresh/stage/s5stage/boot/loader.efi" 2>/dev/null)" = "LOADER" ]; then
    pass "import rebuilt the stage in a FRESH database from the two artifacts"
  else
    fail "import did not restore the boot tree"
  fi
  if [ -f "$fresh/foundation/expectations/s5exp" ]; then
    pass "the arsenal travelled too"
  else
    fail "arsenal missing after import"
  fi
  if [ -d "$fresh/stage/s5stage/marker" ] && [ ! -f "$fresh/stage/s5stage/marker/bootvar" ]; then
    pass "the redacted marker is absent, its record directory intact"
  else
    fail "redaction not reflected in the restored database"
  fi
  if [ "$(cat "$fresh"/provenance/*/serial 2>/dev/null)" = 1 ] && [ "$(cat "$fresh"/provenance/*/signer 2>/dev/null)" = "$STORY_FPR" ] \
     && [ "$(cat "$fresh/export/serial")" = 1 ]; then
    pass "the import filed its receipt and continued the lineage (export serial 1)"
  else
    fail "receipt/serial wrong: $(ls "$fresh/provenance" 2>/dev/null) $(cat "$fresh/export/serial" 2>/dev/null)"
  fi
  ELEBAKE_ROOT="$root" eb "$src" export "$root/dump2.sh" "$root/bundle/s5-2.tar.gz" redacted > /dev/null 2>&1
  ELEBAKE_ROOT="$root" eb "$fresh" import "$root/dump2.sh" "$root/bundle/s5-2.tar.gz" > /dev/null 2>&1
  out=$(ELEBAKE_ROOT="$root" eb "$fresh" import "$root/dump-for-git.sh" "$root/bundle/s5.tar.gz" 2>&1)
  if printf '%s\n' "$out" | grep -q "DOWNGRADE" && [ "$(cat "$fresh/export/serial")" = 2 ]; then
    pass "after serial 2 the validly signed serial-1 pair is refused as a downgrade"
  else
    fail "downgrade accepted: $out"
  fi
  story_close 5
}

# Story 6: the rescue round trip. A minimized pair -- binary management
# only -- goes to a rescue system; there the suspect loader is filed as a
# backup record and loader.conf repaired; the rescue's export continues the
# lineage and merges back into the big database without touching what
# stayed home (lua/, markers, the arsenal).
user_story_6_rescue_roundtrip() {
  story_header 6 "rescue: minimized pair out, suspect record and repair back, merged"
  local root="$TEST_BASE_DIR/s6" big="$TEST_BASE_DIR/s6/big" rescue="$TEST_BASE_DIR/s6/rescue"
  mkdir -p "$root"
  ELEBAKE_ROOT="$root" ELEBAKE_BASE="$big" "$TEST_SCRIPT" bootstrap big minimal > "$root/b.log" 2>&1 \
    || { fail "bootstrap failed"; story_close 6; return 0; }
  ELEBAKE_ROOT="$root" eb "$big" setenv ELEBAKE_TERMINAL_INTERPRETER sh > /dev/null
  ELEBAKE_ROOT="$root" eb "$big" stage add card > /dev/null 2>&1
  local d="$big/stage/card"
  mkdir -p "$d/boot/kernel" "$d/boot/lua" "$d/marker" "$d/backup/a/known-good"
  printf 'LOADER\n' > "$d/boot/loader.efi"; printf 'SIGNED\n' > "$d/boot/loader.efi.signed"; printf 'conf\n' > "$d/boot/loader.conf"
  printf 'KERNEL\n' > "$d/boot/kernel/kernel"; printf 'KO\n' > "$d/boot/kernel/if_x.ko"; printf 'LUA\n' > "$d/boot/lua/loader.lua"
  printf 'Boot0007\n' > "$d/marker/bootvar"
  ELEBAKE_ROOT="$root" eb "$big" stage device card a /dev/nonexistent99 /mnt > /dev/null 2>&1
  printf 'OLDLOADER\n' > "$d/backup/a/known-good/loader.efi"; sha256 -q "$d/backup/a/known-good/loader.efi" > "$d/backup/a/known-good/sha256"
  printf '2026-08-25T10:00:00Z\n' > "$d/backup/a/known-good/created"; printf 'booted silently 25.08.\n' > "$d/backup/a/known-good/description"
  ELEBAKE_ROOT="$root" eb "$big" expectation add s6exp byte S 1 > /dev/null 2>&1
  story_key "$root" || { fail "story key"; story_close 6; return 0; }
  story_pin "$big" attest-story

  ELEBAKE_ROOT="$root" eb "$big" export "$root/out.sh" "$root/bundle/out.tar.gz" minimized > "$root/export.log" 2>&1
  if tar -tzf "$root/bundle/out.tar.gz" | grep -q "boot/kernel/if_x.ko" && tar -tzf "$root/bundle/out.tar.gz" | grep -q "backup/a/known-good/loader.efi" \
     && ! tar -tzf "$root/bundle/out.tar.gz" | grep -q "lua" && ! tar -tzf "$root/bundle/out.tar.gz" | grep -q "marker" \
     && grep -q "^# Strategy: minimized$" "$root/out.sh" && ! grep -q "lua" "$root/out.sh"; then
    pass "the minimized pair carries loaders, modules, loader.conf and backups -- no lua, no marker, and the dump says so"
  else
    fail "minimized pair wrong: $(tar -tzf "$root/bundle/out.tar.gz" | tr '\n' ' ')"
  fi

  ELEBAKE_ROOT="$root" ELEBAKE_BASE="$rescue" "$TEST_SCRIPT" bootstrap rescue minimal > "$root/r.log" 2>&1 \
    || { fail "rescue bootstrap failed"; story_close 6; return 0; }
  ELEBAKE_ROOT="$root" eb "$rescue" setenv ELEBAKE_TERMINAL_INTERPRETER sh > /dev/null
  story_pin "$rescue" attest-story
  ELEBAKE_ROOT="$root" eb "$rescue" import "$root/out.sh" "$root/bundle/out.tar.gz" > "$root/import.log" 2>&1
  if [ "$(cat "$rescue/stage/card/boot/loader.efi" 2>/dev/null)" = LOADER ] && [ -f "$rescue/stage/card/boot/kernel/if_x.ko" ] \
     && [ -f "$rescue/stage/card/backup/a/known-good/description" ] && [ ! -e "$rescue/stage/card/boot/lua" ] \
     && [ ! -f "$rescue/foundation/expectations/s6exp" ]; then
    pass "the rescue database holds exactly binary management: loaders, modules, backups with their context"
  else
    fail "rescue import incomplete: $(grep -i error "$root/import.log" | head -3)"
  fi
  if ELEBAKE_ROOT="$root" eb "$rescue" stage backup list card a | grep "known-good" | grep -q "booted silently"; then
    pass "on the road, 'stage backup list' shows the labelled backups with their descriptions"
  else
    fail "backup list on the rescue wrong"
  fi
  ELEBAKE_ROOT="$root" eb "$rescue" setenv ELEBAKE_INTERPRETER_stage_rollback3 cat > /dev/null
  if ELEBAKE_ROOT="$root" eb "$rescue" stage rollback card a | grep -q "stage backup 'card' 'a' 'suspect-"; then
    pass "a rollback on the rescue saves the suspect loader first"
  else
    fail "rollback does not save the suspect"
  fi

  local r="$rescue/stage/card"
  mkdir -p "$r/backup/a/suspect-20260902T160000Z"
  printf 'EVILLOADER\n' > "$r/backup/a/suspect-20260902T160000Z/loader.efi"; sha256 -q "$r/backup/a/suspect-20260902T160000Z/loader.efi" > "$r/backup/a/suspect-20260902T160000Z/sha256"
  printf '2026-09-02T16:00:00Z\n' > "$r/backup/a/suspect-20260902T160000Z/created"; printf 'loader found on medium a before rollback -- keep for analysis\n' > "$r/backup/a/suspect-20260902T160000Z/description"
  printf 'repaired\n' > "$r/boot/loader.conf"
  ELEBAKE_ROOT="$root" eb "$rescue" export "$root/back.sh" "$root/bundle/back.tar.gz" minimized > "$root/export2.log" 2>&1
  if grep -q "^# Serial: 2$" "$root/back.sh"; then
    pass "the rescue's export continues the lineage (serial 2, not 1)"
  else
    fail "rescue serial wrong: $(grep Serial "$root/back.sh")"
  fi
  ELEBAKE_ROOT="$root" eb "$big" import "$root/back.sh" "$root/bundle/back.tar.gz" > "$root/import2.log" 2>&1
  if [ -f "$d/backup/a/suspect-20260902T160000Z/description" ] && [ "$(cat "$d/boot/loader.conf")" = repaired ]; then
    pass "the suspect record and the repaired loader.conf merged into the big database"
  else
    fail "merge incomplete: $(grep -i error "$root/import2.log" | head -3)"
  fi
  if [ -f "$d/boot/lua/loader.lua" ] && [ -f "$d/marker/bootvar" ] && [ -f "$big/foundation/expectations/s6exp" ]; then
    pass "what stayed home is untouched: lua/, marker, arsenal"
  else
    fail "merge damaged the big database"
  fi
  if [ "$(ls "$big/provenance" | wc -l | tr -d ' ')" = 2 ] && [ "$(cat "$big/export/serial")" = 2 ]; then
    pass "the big database now carries both receipts (the rescue's and its own) and exports 3 next"
  else
    fail "receipt chain wrong: $(ls "$big/provenance" 2>/dev/null | tr '\n' ' ') serial $(cat "$big/export/serial")"
  fi
  story_close 6
}

user_story_1_migration_roundtrip() {
  story_header 1 "database migration: dump | bootstrap | restore -> identical"
  local src="$TEST_BASE_DIR/s1-src" dst="$TEST_BASE_DIR/s1-dst" dstbase
  mkdir -p "$src" "$dst"
  make_source_db "$src" || { fail "source fixture failed (see $src/bootstrap.log)"; story_close 1; return 0; }
  dstbase=$(migrate "$src/db" "$dst" "$TEST_BASE_DIR/s1-dump.sh") || { fail "migration failed"; story_close 1; return 0; }
  if grep -q "^# Version: 2\$" "$TEST_BASE_DIR/s1-dump.sh" && grep -q "^# Serial: 1\$" "$TEST_BASE_DIR/s1-dump.sh" \
     && grep -q "^# Bundle: sha256=" "$TEST_BASE_DIR/s1-dump.sh" && [ -f "$TEST_BASE_DIR/s1-dump.sh.asc" ]; then
    pass "dump carries the format version, the serial, the seal and its signature"
  else
    fail "dump header/seal/signature incomplete: $(grep '^# ' "$TEST_BASE_DIR/s1-dump.sh" | head -6 | tr '\n' ' ')"
  fi
  if [ -d "$dstbase/provenance" ] && [ "$(ls "$dstbase/provenance" | wc -l | tr -d ' ')" = 1 ] \
     && [ "$(cat "$dstbase"/provenance/*/serial)" = 1 ]; then
    pass "the migration left a receipt (serial 1) in the new database"
  else
    fail "no receipt after migration"
  fi
  if diff -r --no-dereference --exclude=obj --exclude=destdir "$src/db/stage/story/" "$dstbase/stage/story/" > "$dst/diff.out" 2>&1; then
    pass "stage tree identical after migration (incl. empty skeleton dirs)"
  else
    fail "stage tree differs: $(head -3 "$dst/diff.out")"
  fi
  if [ "$(cat "$dstbase/pkcs11/tok/cert.pem" 2>/dev/null)" = "CERTMATERIAL" ]; then
    pass "backend extra file travelled with the dump"
  else
    fail "backend extra file missing in target"
  fi
  case "$(head -1 "$dstbase/pkcs11/tok/cert" 2>/dev/null)" in
    "$dstbase"/*) pass "DB-internal cert path rebased onto the TARGET" ;;
    *) fail "cert path not rebased: $(head -1 "$dstbase/pkcs11/tok/cert" 2>/dev/null)" ;;
  esac
  if [ "$(head -1 "$dstbase/.env/local/ELEBAKE_FREEBSD_PREREQUISITES" 2>/dev/null)" = "git make clang" ]; then
    pass "environment override restored via prologue/epilogue"
  else
    fail "environment override missing in target"
  fi
  story_close 1
}

user_story_2_replay_idempotence() {
  story_header 2 "replaying the same dump again changes NOTHING"
  local src="$TEST_BASE_DIR/s2-src" dst="$TEST_BASE_DIR/s2-dst" dstbase
  mkdir -p "$src" "$dst"
  make_source_db "$src" || { fail "source fixture failed"; story_close 2; return 0; }
  dstbase=$(migrate "$src/db" "$dst" "$TEST_BASE_DIR/s2-dump.sh") || { fail "migration failed"; story_close 2; return 0; }
  local id1 n1 id2 n2
  id1=$(readlink "$dstbase/stage/story"); n1=$(ls "$dstbase/.staging" | wc -l | tr -d ' ')
  ELEBAKE_ROOT="$dst" eb "$dstbase" import "$TEST_BASE_DIR/s2-dump.sh" "$dst/bundle.tar.gz" > "$dst/restore2.log" 2>&1
  id2=$(readlink "$dstbase/stage/story"); n2=$(ls "$dstbase/.staging" | wc -l | tr -d ' ')
  if [ "$id1" = "$id2" ]; then
    pass "stage id stable across re-restore"
  else
    fail "stage id changed: $id1 -> $id2"
  fi
  if [ "$n1" = "$n2" ]; then
    pass "no .staging orphans minted ($n1)"
  else
    fail ".staging grew: $n1 -> $n2"
  fi
  if diff -r --no-dereference --exclude=obj --exclude=destdir "$src/db/stage/story/" "$dstbase/stage/story/" > /dev/null 2>&1; then
    pass "tree still identical after re-restore"
  else
    fail "tree drifted after re-restore"
  fi
  if grep -q "already filed" "$dst/restore2.log" && [ "$(ls "$dstbase/provenance" | wc -l | tr -d ' ')" = 1 ]; then
    pass "the same pair files no second receipt"
  else
    fail "receipt duplicated or missing: $(ls "$dstbase/provenance" 2>/dev/null | tr '\n' ' ')"
  fi
  story_close 2
}

user_story_3_unknown_stage_negative() {
  story_header 3 "check stage stops a bad sequence, keep-going saves the rest"
  local root="$TEST_BASE_DIR/s3" base="$TEST_BASE_DIR/s3/db"
  mkdir -p "$root"
  ELEBAKE_ROOT="$root" ELEBAKE_BASE="$base" "$TEST_SCRIPT" bootstrap current minimal > "$root/bootstrap.log" 2>&1 || { fail "bootstrap failed"; story_close 3; return 0; }
  eb "$base" setenv ELEBAKE_TERMINAL_INTERPRETER sh > /dev/null
  story_key "$root" || { fail "story key"; story_close 3; return 0; }
  story_pin "$base" attest-story
  cat > "$root/bad-dump.sh" <<'EOF'
# elebake database dump
# Version: 2
# Serial: 1
# Strategy: complete
"$ELEBAKE_CONTEXT_SCRIPT" setenv ELEBAKE_INT_BEFORE yes
"$ELEBAKE_CONTEXT_SCRIPT" stage import ghost boot/sub
"$ELEBAKE_CONTEXT_SCRIPT" setenv ELEBAKE_INT_AFTER yes
EOF
  eb "$base" restore "$root/bad-dump.sh" > "$root/unsigned.log" 2>&1
  if grep -q "unsigned" "$root/unsigned.log" && [ ! -f "$base/.env/local/ELEBAKE_INT_BEFORE" ]; then
    pass "an unsigned dump is not replayed at all"
  else
    fail "unsigned dump replayed: $(cat "$root/unsigned.log")"
  fi
  eb "$base" attest "$root/bad-dump.sh" attest-story > /dev/null 2>&1
  eb "$base" restore "$root/bad-dump.sh" > "$root/restore.log" 2>&1
  if grep -q "unknown stage" "$root/restore.log"; then
    pass "check stage reported the unknown stage"
  else
    fail "no check stage report in replay log"
  fi
  if [ ! -d "$base/.staging" ] || ! ls "$base"/.staging/*/boot/sub > /dev/null 2>&1; then
    pass "nothing was imported for the ghost stage"
  else
    fail "ghost import acted despite failing check"
  fi
  if [ "$(head -1 "$base/.env/local/ELEBAKE_INT_BEFORE" 2>/dev/null)" = "yes" ] \
     && [ "$(head -1 "$base/.env/local/ELEBAKE_INT_AFTER" 2>/dev/null)" = "yes" ]; then
    pass "keep-going replayed the lines around the failure"
  else
    fail "keep-going did not survive the failing sequence"
  fi
  story_close 3
}

summary() {
  echo ""
  echo "========================================"
  echo "Integration Test Summary"
  echo "========================================"
  echo "Stories:"
  echo "  Passed:      $STORIES_PASSED"
  echo "  Failed:      $STORIES_FAILED"
  echo "Assertions:"
  echo "  Passed:      $ASSERTIONS_PASSED"
  echo "  Failed:      $ASSERTIONS_FAILED"
  echo ""
  if [ "$STORIES_FAILED" -eq 0 ] && [ "$ASSERTIONS_FAILED" -eq 0 ]; then
    echo "ALL STORIES PASSED"
    rm -rf "$TEST_BASE_DIR"
    return 0
  fi
  echo "SOME STORIES FAILED"
  echo "Artifacts preserved in: $TEST_BASE_DIR"
  return 1
}

parallel_main() {
  local outdir rc=0 stories n
  outdir=$(mktemp -d "${TMPDIR:-/tmp}/elebake-int-par.XXXXXX") || exit 1
  stories=$(grep -o "should_run_story [0-9]*" "$0" | awk '{print $2}' | sort -un)
  echo "elebake Integration Tests (parallel, -P $MAXPROCS)"
  printf '%s\n' $stories | xargs -n1 -P "$MAXPROCS" -I{} \
    sh -c 'sh "$0" {} > "$1/{}.out" 2>&1; echo $? > "$1/{}.rc"' "$0" "$outdir"
  for n in $stories; do
    cat "$outdir/$n.out" 2>/dev/null
    [ "$(cat "$outdir/$n.rc" 2>/dev/null)" = "0" ] || rc=1
  done
  echo ""
  echo "========================================"
  echo "Aggregated Summary (parallel run)"
  echo "========================================"
  awk '
    /Stories:$/    { sect = "s" }
    /Assertions:$/ { sect = "a" }
    /^  Passed:/   { if (sect == "s") sp += $2; else ap += $2 }
    /^  Failed:/   { if (sect == "s") sf += $2; else af += $2 }
    END {
      printf "Stories:            %d passed, %d failed\n", sp, sf
      printf "Assertions:         %d passed, %d failed\n", ap, af
    }' "$outdir"/*.out
  if [ "$rc" -eq 0 ]; then
    echo ""; echo "ALL STORIES PASSED"; rm -rf "$outdir"
  else
    echo ""; echo "SOME STORIES FAILED"; echo "Per-story outputs preserved in: $outdir"
  fi
  return $rc
}

main() {
  if [ "$MAXPROCS" -gt 1 ]; then
    parallel_main
    return $?
  fi
  echo "=== elebake Integration Tests ==="
  [ -f "$TEST_SCRIPT" ] || { echo "ERROR: $TEST_SCRIPT not found (run from the repository root)"; exit 1; }
  mkdir -p "$TEST_BASE_DIR"
  should_run_story 1 && user_story_1_migration_roundtrip
  should_run_story 4 && user_story_4_foundation_acceptance
  should_run_story 5 && user_story_5_export_import
  should_run_story 2 && user_story_2_replay_idempotence
  should_run_story 3 && user_story_3_unknown_stage_negative
  should_run_story 6 && user_story_6_rescue_roundtrip
  summary
}

main
exit $?
