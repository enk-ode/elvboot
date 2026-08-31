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
  eb "$srcbase" dump > "$dumpfile" 2>/dev/null
  ELEBAKE_ROOT="$dstroot" ELEBAKE_BASE="$dstbase" "$TEST_SCRIPT" bootstrap current minimal > "$dstroot/bootstrap.log" 2>&1 || return 1
  eb "$dstbase" setenv ELEBAKE_TERMINAL_INTERPRETER sh > /dev/null
  eb "$dstbase" restore "$dumpfile" > "$dstroot/restore.log" 2>&1
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

user_story_1_migration_roundtrip() {
  story_header 1 "database migration: dump | bootstrap | restore -> identical"
  local src="$TEST_BASE_DIR/s1-src" dst="$TEST_BASE_DIR/s1-dst" dstbase
  mkdir -p "$src" "$dst"
  make_source_db "$src" || { fail "source fixture failed (see $src/bootstrap.log)"; story_close 1; return 0; }
  dstbase=$(migrate "$src/db" "$dst" "$TEST_BASE_DIR/s1-dump.sh") || { fail "migration failed"; story_close 1; return 0; }
  if grep -q "^# Version: 1\$" "$TEST_BASE_DIR/s1-dump.sh"; then
    pass "dump carries the format version"
  else
    fail "dump version line missing"
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
  eb "$dstbase" restore "$TEST_BASE_DIR/s2-dump.sh" > "$dst/restore2.log" 2>&1
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
  story_close 2
}

user_story_3_unknown_stage_negative() {
  story_header 3 "check stage stops a bad sequence, keep-going saves the rest"
  local root="$TEST_BASE_DIR/s3" base="$TEST_BASE_DIR/s3/db"
  mkdir -p "$root"
  ELEBAKE_ROOT="$root" ELEBAKE_BASE="$base" "$TEST_SCRIPT" bootstrap current minimal > "$root/bootstrap.log" 2>&1 || { fail "bootstrap failed"; story_close 3; return 0; }
  eb "$base" setenv ELEBAKE_TERMINAL_INTERPRETER sh > /dev/null
  cat > "$root/bad-dump.sh" <<'EOF'
"$ELEBAKE_CONTEXT_SCRIPT" setenv ELEBAKE_INT_BEFORE yes
"$ELEBAKE_CONTEXT_SCRIPT" stage import ghost boot/sub
"$ELEBAKE_CONTEXT_SCRIPT" setenv ELEBAKE_INT_AFTER yes
EOF
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
  should_run_story 2 && user_story_2_replay_idempotence
  should_run_story 3 && user_story_3_unknown_stage_negative
  summary
}

main
exit $?
