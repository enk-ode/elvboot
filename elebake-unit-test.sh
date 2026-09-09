#!/bin/sh
#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Dr. Johannes Brügmann
# elebake-unit-test.sh - unit tests for the elebake commands
#
# Same framework as elebake-architecture-test.sh (ported from vpn-switch):
# every test gets its own bootstrapped sandbox database; assertions inspect
# EMISSIONS and sandbox files only — no real devices, no NVRAM, invented
# node names (test-interface doctrine).
#
# Usage:
#   ./elebake-unit-test.sh [--maxprocs N] [profile] [keep] [test names...]
#
set -u

# Test base directory
TEST_BASE_DIR="${TMPDIR:-/tmp}/elebake-unit-test.$$"
TEST_SCRIPT="./elebake.sh"

# Options: --maxprocs N runs the test functions in parallel (xargs -P N).
MAXPROCS=1
while [ $# -gt 0 ]; do
  case "$1" in
    --maxprocs)   MAXPROCS="${2:?--maxprocs needs a value}"; shift 2 ;;
    --maxprocs=*) MAXPROCS="${1#--maxprocs=}"; shift ;;
    *) break ;;
  esac
done

# After the option loop the first positional is the PROFILE. Naming a test
# function there instead used to bootstrap every sandbox with a profile that
# does not exist -- an empty .env, and a run drowning in failures that have
# nothing to do with the tests named. Rejected here, by name.
case "${1:-}" in
  -*) echo "unknown option: $1" >&2
      echo "usage: $0 [--maxprocs N] [<profile>] [keep] [<test names...>]" >&2
      exit 2 ;;
esac
TEST_PROFILE="${1:-minimal}"
if [ ! -f "$(dirname "$0")/template/environment/ELEBAKE_PROFILE_$(echo "$TEST_PROFILE" | tr '[:lower:]' '[:upper:]')" ]; then
  echo "unknown profile: $TEST_PROFILE" >&2
  echo "available: $(ls "$(dirname "$0")"/template/environment/ELEBAKE_PROFILE_* | sed 's|.*PROFILE_||' | tr '[:upper:]' '[:lower:]' | tr '\n' ' ')" >&2
  exit 2
fi
KEEP_DATABASES="${2:-false}"
[ $# -ge 1 ] && shift
[ $# -ge 1 ] && shift
ALL_TESTS=$(grep -o '^test_[a-z_0-9]*()' "$0" | sed 's/()$//' | tr '\n' ' ')
TEST_FILTER="$*"
[ -z "$TEST_FILTER" ] && TEST_FILTER="$ALL_TESTS"

should_run_test() {
  local test_name="$1"
  for filter_test in $TEST_FILTER; do
    [ "$filter_test" = "$test_name" ] && { "$test_name"; return 0; }
  done
  return 0
}

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

if [ -t 1 ] && command -v tput >/dev/null 2>&1 && tput colors >/dev/null 2>&1; then
  COLOR_GREEN=$(tput setaf 2); COLOR_RED=$(tput setaf 1)
  COLOR_BLUE=$(tput setaf 4); COLOR_RESET=$(tput sgr0)
else
  COLOR_GREEN=""; COLOR_RED=""; COLOR_BLUE=""; COLOR_RESET=""
fi

TEST_DIR=""

pass() { TESTS_PASSED=$((TESTS_PASSED + 1)); echo "${COLOR_GREEN}✓${COLOR_RESET} $*"; }
fail() { TESTS_FAILED=$((TESTS_FAILED + 1)); echo "${COLOR_RED}✗${COLOR_RESET} $*"; }

test_header() {
  TESTS_RUN=$((TESTS_RUN + 1))
  echo ""
  echo "${COLOR_BLUE}TEST ${TESTS_RUN}:${COLOR_RESET} $* [db: ${TEST_DIR:-}]"
}

# test_setup - fresh sandbox DB per test. Terminal interpreter pinned to sh
# (experienced-user model: emissions ACT); the cat-pinned display blocks keep
# their profile pins. NOTE: no 'environment cache on' here — unit tests
# setenv/unsetenv on purpose, which invalidates the cache anyway (JB).
test_setup() {
  TEST_DIR="$TEST_BASE_DIR/test-$TESTS_RUN"
  mkdir -p "$TEST_DIR"
  local bootstrap_log="$TEST_DIR/bootstrap.log"
  if ! ELEBAKE_ROOT="$TEST_BASE_DIR" ELEBAKE_BASE="$TEST_DIR" "$TEST_SCRIPT" bootstrap "test-$TESTS_RUN" "$TEST_PROFILE" > "$bootstrap_log" 2>&1; then
    echo "${COLOR_RED}ERROR:${COLOR_RESET} Database bootstrap failed"
    sed 's/^/  /' "$bootstrap_log"
    exit 1
  fi
  ELEBAKE_BASE="$TEST_DIR" "$TEST_SCRIPT" setenv ELEBAKE_TERMINAL_INTERPRETER sh > /dev/null 2>&1
  ELEBAKE_BASE="$TEST_DIR" "$TEST_SCRIPT" setenv ELEBAKE_PATH "/bin:/usr/bin:/usr/local/bin" > /dev/null 2>&1
  # A test never changes the system: every act terminal the profile pins to
  # sudo is pinned to cat here -- its output is analysed, never run (JB 09.09.).
  local pin
  for pin in "$(dirname "$TEST_SCRIPT")"/template/environment/ELEBAKE_INTERPRETER_*; do
    case "$(sed -n 1p "$pin")" in sudo*)
      ELEBAKE_BASE="$TEST_DIR" "$TEST_SCRIPT" setenv "${pin##*/}" cat > /dev/null 2>&1 ;;
    esac
  done
}

# The output is captured before it is printed: a consumer that closes early
# (grep -q) must never reach the running batch -- its exit channel would see
# the broken pipe, not the failing line (engine finding 09.09.).
run_elebake() { local out rc; out=$(ELEBAKE_BASE="$TEST_DIR" "$TEST_SCRIPT" "$@" 2>&1); rc=$?; printf '%s\n' "$out"; return $rc; }
# unit_attest_key <record> -- generate a throwaway OpenPGP key in a home
# short enough for gpg-agent's socket, register it in the test database and
# pin it as the archive attest key. Sets UNIT_GNUPGHOME and UNIT_FPR.
# Returns 1 (and passes with a note) when gpg is absent.
unit_attest_key() {
  command -v gpg > /dev/null 2>&1 || { pass "gpg absent -- signing checks skipped"; return 1; }
  UNIT_GNUPGHOME="$TEST_BASE_DIR/gh-$TESTS_RUN"
  mkdir -p "$UNIT_GNUPGHOME" && chmod 700 "$UNIT_GNUPGHOME"
  GNUPGHOME="$UNIT_GNUPGHOME" gpg --batch --passphrase '' --pinentry-mode loopback \
    --quick-generate-key "Unit $TESTS_RUN <unit@example.invalid>" rsa2048 sign never > /dev/null 2>&1
  UNIT_FPR=$(GNUPGHOME="$UNIT_GNUPGHOME" gpg --list-secret-keys --with-colons 2>/dev/null | awk -F: '/^fpr:/{print $10; exit}')
  [ -n "$UNIT_FPR" ] || { fail "could not create a test key (gpg-agent socket path too long? TMPDIR=$TEST_BASE_DIR)"; return 1; }
  run_elebake openpgp add "$1" "$UNIT_FPR" "$UNIT_GNUPGHOME" > /dev/null 2>&1
  run_elebake setenv ELEBAKE_ARCHIVE_ATTEST_KEY "$1" > /dev/null
  return 0
}
# unit_signed_dump <file> <body...> -- write a Version-2 dump with the given
# body lines and attest it with the pinned key (unit_attest_key first)
unit_signed_dump() {
  local f="$1"; shift
  { printf '# elebake database dump\n# Version: 2\n# Serial: %s\n# Strategy: complete\n' "${UNIT_SERIAL:-1}"
    for l; do printf '%s\n' "$l"; done; } > "$f"
  run_elebake attest "$f" "$(head -1 "$TEST_DIR/.env/local/ELEBAKE_ARCHIVE_ATTEST_KEY")" > /dev/null 2>&1
}

test_summary() {
  local total=$((TESTS_PASSED + TESTS_FAILED))
  echo ""
  echo "========================================"
  echo "Unit Test Summary"
  echo "========================================"
  echo "Test Functions:     $TESTS_RUN"
  echo "Total Assertions:   $total"
  echo "${COLOR_GREEN}Passed Assertions:  $TESTS_PASSED${COLOR_RESET}"
  if [ "$TESTS_FAILED" -gt 0 ]; then
    echo "${COLOR_RED}Failed Assertions:  $TESTS_FAILED${COLOR_RESET}"
    echo ""
    echo "${COLOR_RED}SOME TESTS FAILED${COLOR_RESET}"
    echo "Test artifacts preserved in: $TEST_BASE_DIR"
    return 1
  fi
  echo "Failed Assertions:  $TESTS_FAILED"
  echo ""
  echo "${COLOR_GREEN}ALL TESTS PASSED${COLOR_RESET}"
  if [ "$KEEP_DATABASES" = "true" ] || [ "$KEEP_DATABASES" = "keep" ]; then
    echo "Test databases preserved in: $TEST_BASE_DIR"
  else
    rm -rf "$TEST_BASE_DIR"
  fi
  return 0
}

#-----------------------------------------------------------------------------
# Tests
#-----------------------------------------------------------------------------

test_bootstrap_layout() {
  test_header "bootstrap creates layout and installs the profile"
  test_setup
  local d ok=1
  for d in .env/default .env/local .tmp .log pem openpgp pkcs11 stage .staging; do
    [ -d "$TEST_DIR/$d" ] || { ok=0; fail "missing directory: $d"; }
  done
  [ "$ok" -eq 1 ] && pass "database layout complete"
  if [ -f "$TEST_DIR/.env/default/ELEBAKE_INTERPRETER_stage_dump_marker" ]; then
    pass "profile installed the dump building-block pins"
  else
    fail "profile did not install ELEBAKE_INTERPRETER_stage_dump_marker"
  fi
}

test_setenv_getenv_roundtrip() {
  test_header "setenv/getenv/unsetenv round trip"
  test_setup
  run_elebake setenv ELEBAKE_UNIT_PROBE hello > /dev/null
  if run_elebake getenv ELEBAKE_UNIT_PROBE | grep -q "hello"; then
    pass "setenv value visible via getenv"
  else
    fail "setenv value not visible via getenv"
  fi
  run_elebake unsetenv ELEBAKE_UNIT_PROBE > /dev/null
  if [ ! -f "$TEST_DIR/.env/local/ELEBAKE_UNIT_PROBE" ]; then
    pass "unsetenv removed the local override"
  else
    fail "unsetenv left the local override behind"
  fi
}

test_pem_add_and_dump() {
  test_header "pem add writes the record; pem dump replays it"
  test_setup
  run_elebake pem add unitkey /nonexistent/unit.key /nonexistent/unit.crt > /dev/null
  if [ "$(head -1 "$TEST_DIR/pem/unitkey/key" 2>/dev/null)" = "/nonexistent/unit.key" ]; then
    pass "pem record holds the key path"
  else
    fail "pem record missing or wrong: $(head -1 "$TEST_DIR/pem/unitkey/key" 2>/dev/null)"
  fi
  if run_elebake pem dump | grep -q "pem add 'unitkey' '/nonexistent/unit.key' '/nonexistent/unit.crt'"; then
    pass "pem dump emits the add replay line"
  else
    fail "pem dump replay line missing"
  fi
}

test_pem_dump_rebases_and_extras() {
  test_header "backend dump: DB-internal paths rebased, extra files imported"
  test_setup
  printf 'MATERIAL\n' > "$TEST_DIR/pem/.tmpmat" 2>/dev/null || true
  run_elebake pem add spikey /nonexistent/spike.key "$TEST_DIR/pem/spikey/cert.pem" > /dev/null
  printf 'CERT\n' > "$TEST_DIR/pem/spikey/cert.pem"
  local out; out=$(run_elebake pem dump)
  if printf '%s\n' "$out" | grep -q '"\$ELEBAKE_BASE/pem/spikey/cert.pem"'; then
    pass "DB-internal cert path rebased onto \$ELEBAKE_BASE"
  else
    fail "cert path not rebased: $out"
  fi
  if printf '%s\n' "$out" | grep -q "pem import 'spikey'"; then
    pass "extra record file emitted as pem import base element"
  else
    fail "extra record file not emitted"
  fi
}

test_openpgp_add_variants() {
  test_header "openpgp add: default home vs explicit gnupghome"
  test_setup
  run_elebake openpgp add plain 0123456789ABCDEF > /dev/null
  run_elebake openpgp add homed FEDCBA9876543210 /nonexistent/gnupg > /dev/null
  if [ ! -f "$TEST_DIR/openpgp/plain/gnupghome" ] && [ -f "$TEST_DIR/openpgp/homed/gnupghome" ]; then
    pass "gnupghome recorded only for the 3-arg form"
  else
    fail "gnupghome record shape wrong"
  fi
  local out; out=$(run_elebake openpgp dump)
  if printf '%s\n' "$out" | grep -q "openpgp add 'plain' '0123456789ABCDEF'\$" \
     && printf '%s\n' "$out" | grep -q "openpgp add 'homed' 'FEDCBA9876543210' '/nonexistent/gnupg'"; then
    pass "openpgp dump replays both arities correctly"
  else
    fail "openpgp dump replay lines wrong: $out"
  fi
}

test_backend_import_copies_file() {
  test_header "pkcs11 import copies one extra file into the record"
  test_setup
  run_elebake pkcs11 add tok 'pkcs11:token=unit;object=x' /nonexistent/tok.crt > /dev/null
  printf 'PEMDATA\n' > "$TEST_BASE_DIR/unit-extra.pem"
  run_elebake pkcs11 import tok "$TEST_BASE_DIR/unit-extra.pem" > /dev/null
  if [ "$(cat "$TEST_DIR/pkcs11/tok/unit-extra.pem" 2>/dev/null)" = "PEMDATA" ]; then
    pass "extra file landed in the record"
  else
    fail "extra file missing in record"
  fi
  if run_elebake pkcs11 import tok /nonexistent/nofile 2>&1 | grep -q "no such file"; then
    pass "missing source fails early"
  else
    fail "missing source not rejected"
  fi
}

test_stage_add_idempotent() {
  test_header "stage add is idempotent (no re-mint, no orphans)"
  test_setup
  run_elebake stage add unita > /dev/null 2>&1
  local id1 n1 id2 n2
  id1=$(readlink "$TEST_DIR/stage/unita"); n1=$(ls "$TEST_DIR/.staging" | wc -l | tr -d ' ')
  local out; out=$(run_elebake stage add unita 2>&1)
  id2=$(readlink "$TEST_DIR/stage/unita"); n2=$(ls "$TEST_DIR/.staging" | wc -l | tr -d ' ')
  if [ "$id1" = "$id2" ] && [ "$n1" = "$n2" ]; then
    pass "second add left id and .staging count untouched ($n1)"
  else
    fail "second add re-minted: id $id1 -> $id2, count $n1 -> $n2"
  fi
  if printf '%s\n' "$out" | grep -q "already exists"; then
    pass "second add says so"
  else
    fail "second add silent: $out"
  fi
}

test_stage_filter_roundtrip() {
  test_header "stage filter: add is idempotent, remove validates"
  test_setup
  run_elebake stage add unitf > /dev/null 2>&1
  run_elebake stage filter add unitf loader.efi > /dev/null 2>&1
  run_elebake stage filter add unitf loader.efi > /dev/null 2>&1
  if [ "$(grep -cx 'loader.efi' "$TEST_DIR/stage/unitf/filter")" = "1" ]; then
    pass "duplicate +entry not doubled"
  else
    fail "filter file wrong: $(cat "$TEST_DIR/stage/unitf/filter")"
  fi
  run_elebake stage filter drop unitf loader.efi > /dev/null 2>&1
  if ! grep -qx 'loader.efi' "$TEST_DIR/stage/unitf/filter" 2>/dev/null; then
    pass "-entry removed"
  else
    fail "-entry not removed"
  fi
  if run_elebake stage filter drop unitf missing 2>&1 | grep -q "not listed"; then
    pass "removing an unlisted entry fails early"
  else
    fail "unlisted removal not rejected"
  fi
}

test_stage_keybindings() {
  test_header "sign-key/attest-key bind relative, unkey removes"
  test_setup
  run_elebake stage add unitk > /dev/null 2>&1
  run_elebake pem add bindkey /nonexistent/k /nonexistent/c > /dev/null
  run_elebake stage sign key unitk pem bindkey > /dev/null 2>&1
  if [ "$(readlink "$TEST_DIR/stage/unitk/sign-key")" = "../../pem/bindkey" ]; then
    pass "sign-key is the relative backend link"
  else
    fail "sign-key link wrong: $(readlink "$TEST_DIR/stage/unitk/sign-key")"
  fi
  run_elebake stage unkey unitk > /dev/null 2>&1
  if [ ! -L "$TEST_DIR/stage/unitk/sign-key" ]; then
    pass "unkey removed the slot"
  else
    fail "unkey left the slot"
  fi
}

test_stage_import_cascade() {
  test_header "import cascade: check stage guards, declare-then-copy"
  test_setup
  local out
  out=$(run_elebake stage import ghost boot 2>&1)
  if printf '%s\n' "$out" | grep -q "unknown stage"; then
    pass "unknown stage stopped by check stage"
  else
    fail "unknown stage not stopped: $out"
  fi
  run_elebake stage add uniti > /dev/null 2>&1
  run_elebake stage import uniti boot/sub > /dev/null 2>&1
  if [ -d "$TEST_DIR/stage/uniti/boot/sub" ]; then
    pass "directory declaration created boot/sub"
  else
    fail "boot/sub not created"
  fi
  printf 'X\n' > "$TEST_BASE_DIR/unit-file"
  out=$(run_elebake stage import uniti boot/nodecl "$TEST_BASE_DIR/unit-file" 2>&1)
  if printf '%s\n' "$out" | grep -q "target dir missing"; then
    pass "file into undeclared dir fails early"
  else
    fail "undeclared target not rejected: $out"
  fi
  run_elebake stage import uniti boot/sub "$TEST_BASE_DIR/unit-file" > /dev/null 2>&1
  if [ "$(cat "$TEST_DIR/stage/uniti/boot/sub/unit-file" 2>/dev/null)" = "X" ]; then
    pass "file base element copied into declared dir"
  else
    fail "file base element missing"
  fi
}

test_stage_dump_structure_first() {
  test_header "stage dump: replays records, structure before content"
  test_setup
  run_elebake stage add unitd > /dev/null 2>&1
  run_elebake pem add dumpkey /nonexistent/k /nonexistent/c > /dev/null
  run_elebake stage sign key unitd pem dumpkey > /dev/null 2>&1
  run_elebake stage filter add unitd loader.efi > /dev/null 2>&1
  run_elebake stage device unitd t /dev/testda99 /mnt > /dev/null 2>&1
  mkdir -p "$TEST_DIR/stage/unitd/boot/lua"
  printf 'L\n' > "$TEST_DIR/stage/unitd/boot/lua/loader.lua"
  local out; out=$(run_elebake stage dump unitd)
  for want in "stage add 'unitd'" "stage filter add 'unitd' 'loader.efi'" \
              "stage sign key 'unitd' 'pem' 'dumpkey'" \
              "stage device 'unitd' 't' '/dev/testda99' '/mnt'"; do
    if printf '%s\n' "$out" | grep -qF "$want"; then
      pass "dump contains: $want"
    else
      fail "dump missing: $want"
    fi
  done
  local dline fline
  dline=$(printf '%s\n' "$out" | grep -n "stage import 'unitd' 'boot/lua'\$" | head -1 | cut -d: -f1)
  fline=$(printf '%s\n' "$out" | grep -n "stage import 'unitd' 'boot/lua' " | head -1 | cut -d: -f1)
  if [ -n "$dline" ] && [ -n "$fline" ] && [ "$dline" -lt "$fline" ]; then
    pass "structure declared before content ($dline < $fline)"
  else
    fail "structure/content order wrong (dir line: $dline, file line: $fline)"
  fi
}

test_dump_version_header() {
  test_header "database dump carries the format version"
  test_setup
  local out; out=$(run_elebake dump)
  if printf '%s\n' "$out" | grep -q "^# Version: 2\$"; then
    pass "dump header has '# Version: 2'"
  else
    fail "version line missing"
  fi
  if printf '%s\n' "$out" | grep -q "^# Serial: 0\$" && printf '%s\n' "$out" | grep -q "^# Strategy: complete\$"; then
    pass "a never-exported database dumps serial 0, strategy complete"
  else
    fail "serial/strategy header missing"
  fi
  if printf '%s\n' "$out" | grep -q "no receipts to dump"; then
    pass "the receipts are part of the description"
  else
    fail "provenance section missing"
  fi
  if printf '%s\n' "$out" | grep -q "(no stages to dump)"; then
    pass "empty database dumps an empty stage section"
  else
    fail "empty-stage marker missing"
  fi
}

test_restore_keep_going() {
  test_header "restore survives a failing line (keep-going pin)"
  test_setup
  unit_attest_key unit-attest || return 0
  unit_signed_dump "$TEST_BASE_DIR/unit-restore.sh" \
    '"$ELEBAKE_CONTEXT_SCRIPT" setenv ELEBAKE_UNIT_A one' \
    '"$ELEBAKE_CONTEXT_SCRIPT" stage filter add ghost x' \
    '"$ELEBAKE_CONTEXT_SCRIPT" setenv ELEBAKE_UNIT_B two'
  run_elebake restore "$TEST_BASE_DIR/unit-restore.sh" > /dev/null 2>&1
  if [ "$(head -1 "$TEST_DIR/.env/local/ELEBAKE_UNIT_A" 2>/dev/null)" = "one" ] \
     && [ "$(head -1 "$TEST_DIR/.env/local/ELEBAKE_UNIT_B" 2>/dev/null)" = "two" ]; then
    pass "lines after the failing one still replayed"
  else
    fail "restore stopped at the failing line (A=$(head -1 "$TEST_DIR/.env/local/ELEBAKE_UNIT_A" 2>/dev/null) B=$(head -1 "$TEST_DIR/.env/local/ELEBAKE_UNIT_B" 2>/dev/null))"
  fi
}

test_help_env_cascade() {
  test_header "help env resolves default -> local override"
  test_setup
  # after 'environment init' the variable lives in .env/default -- the
  # cascade must report that layer, not the shipped template
  if run_elebake help env ELEBAKE_STAND_BUILD_SUBDIRS | grep -q "(default)"; then
    pass "default layer reported before override"
  else
    fail "default layer not reported"
  fi
  run_elebake setenv ELEBAKE_STAND_BUILD_SUBDIRS "libsa" > /dev/null
  if run_elebake help env ELEBAKE_STAND_BUILD_SUBDIRS | grep -q "override"
  then
    pass "local override wins after setenv"
  else
    fail "local override not reported"
  fi
}



test_error_and_log() {
  test_header "error emits to stderr and exits non-zero; log writes"
  test_setup
  local out rc
  out=$(run_elebake error "unit boom" 2>&1); rc=$?
  if [ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -q "unit boom"; then
    pass "error surfaces message and non-zero exit"
  else
    fail "error rc=$rc out=$out"
  fi
  run_elebake log "unit log line" > /dev/null 2>&1
  if grep -rq "unit log line" "$TEST_DIR/.log" 2>/dev/null; then
    pass "log line persisted under .log/"
  else
    fail "log line not found under .log/"
  fi
}

test_stage_add_validation() {
  test_header "stage add rejects invalid names"
  test_setup
  for bad in "a/b" ".." "sp ace"; do
    if run_elebake stage add "$bad" 2>&1 | grep -q "invalid stage name"; then
      pass "rejected: '$bad'"
    else
      fail "not rejected: '$bad'"
    fi
  done
  if [ "$(ls "$TEST_DIR/.staging" 2>/dev/null | wc -l | tr -d ' ')" = "0" ]; then
    pass "no record minted for any invalid name"
  else
    fail "invalid add left records behind"
  fi
}

test_stage_device_and_boot_tree() {
  test_header "device/boot tree: validation and record shape"
  test_setup
  run_elebake stage add unitm > /dev/null 2>&1
  if run_elebake stage device unitm "bad name" /dev/testda9 2>&1 | grep -q "invalid medium"; then
    pass "invalid medium rejected"
  else
    fail "invalid medium not rejected"
  fi
  if run_elebake stage device unitm t not-a-node 2>&1 | grep -q "not a device node"; then
    pass "non-/dev node rejected"
  else
    fail "non-/dev node not rejected"
  fi
  if run_elebake stage boot tree unitm t lbl pool/ds 2>&1 | grep -q "unknown medium"; then
    pass "boot tree before device fails early"
  else
    fail "boot tree without device not rejected"
  fi
  run_elebake stage device unitm t /dev/testda9 > /dev/null 2>&1
  run_elebake stage boot tree unitm t test-lbl pool/ds > /dev/null 2>&1
  local rec="$TEST_DIR/stage/unitm/media/t"
  if [ "$(head -1 "$rec/node" 2>/dev/null)" = "/dev/testda9" ] \
     && [ "$(head -1 "$rec/mountpoint" 2>/dev/null)" = "/mnt" ] \
     && [ "$(head -1 "$rec/loaderpath" 2>/dev/null)" = "EFI/BOOT/BOOTX64.EFI" ] \
     && [ "$(head -1 "$rec/gptlabel" 2>/dev/null)" = "test-lbl" ] \
     && [ "$(head -1 "$rec/dataset" 2>/dev/null)" = "pool/ds" ]; then
    pass "medium record complete"
  else
    fail "medium record incomplete: $(ls "$rec" 2>/dev/null | tr '\n' ' ')"
  fi
  if run_elebake stage boot tree unitm t 'bad lbl' pool/ds 2>&1 | grep -q "invalid gpt label"; then
    pass "invalid gpt label rejected"
  else
    fail "invalid gpt label not rejected"
  fi
}

test_stage_marker_emission_inspects_only() {
  test_header "marker: record acts, write stays an inspected NVRAM emission, value stays runtime"
  test_setup
  run_elebake stage add unitn > /dev/null 2>&1
  # the NVRAM act terminal is pinned to cat by its template (inspect, then
  # pipe to sudo sh); the test database pins the terminal default to sh, so
  # the pin is set again HERE as the belt to the braces -- tests never touch NVRAM
  run_elebake setenv ELEBAKE_INTERPRETER_stage_marker_nvram cat > /dev/null
  run_elebake setenv ELEBAKE_INTERPRETER_stage_marker3 cat > /dev/null
  local out; out=$(run_elebake stage marker unitn Boot00AB /nonexistent/markerfile 2>&1)
  if printf '%s\n' "$out" | grep -q "stage marker record 'unitn' 'Boot00AB' '/nonexistent/markerfile'" \
     && printf '%s\n' "$out" | grep -q "stage marker write 'unitn' restore"; then
    pass "stage marker is a batch: record, then write"
  else
    fail "marker batch wrong: $out"
  fi
  run_elebake unsetenv ELEBAKE_INTERPRETER_stage_marker3 > /dev/null
  out=$(run_elebake stage marker unitn Boot00AB /nonexistent/markerfile 2>&1)
  if [ "$(cat "$TEST_DIR/stage/unitn/marker/bootvar" 2>/dev/null)" = "Boot00AB" ]; then
    pass "the record acted (bootvar stored)"
  else
    fail "bootvar record missing"
  fi
  if printf '%s\n' "$out" | grep -q "efivar"; then
    pass "NVRAM access stays a runtime emission (inspected, not executed)"
  else
    fail "no efivar emission found: $out"
  fi
  if printf '%s\n' "$out" | grep -q "openssl rand" && printf '%s\n' "$out" | grep -q "NEW value: empty"; then
    pass "value file absent -> generate, decided at generation time; the VALUE itself is runtime"
  else
    fail "generation decision wrong: $out"
  fi
  printf 'cafe\n' > "$TEST_DIR/markerfile"
  run_elebake stage marker record unitn Boot00AB "$TEST_DIR/markerfile" > /dev/null 2>&1
  out=$(run_elebake stage marker write unitn restore 2>&1)
  if printf '%s\n' "$out" | grep -q "restoring the known marker" && ! printf '%s\n' "$out" | grep -q "openssl rand"; then
    pass "value file present -> restore branch only, no runtime if"
  else
    fail "restore decision wrong: $out"
  fi
  if ! printf '%s\n' "$out" | grep -q "cafe"; then
    pass "the marker value never appears in the emission"
  else
    fail "marker value leaked into the emission"
  fi
  if run_elebake stage marker unitn BadName /abs 2>&1 | grep -q "not a load option"; then
    pass "malformed load option rejected"
  else
    fail "malformed load option not rejected"
  fi
  if run_elebake stage marker record unitn Boot00AB relative/path 2>&1 | grep -q "must be absolute"; then
    pass "relative marker file rejected"
  else
    fail "relative marker file not rejected"
  fi
}

test_stage_tree_sync_is_a_batch_with_close() {
  test_header "tree sync/adopt: batches of small terminals, guards at generation time"
  test_setup
  run_elebake stage add unitt > /dev/null 2>&1
  run_elebake stage device unitt a /dev/nonexistent99 /mnt > /dev/null 2>&1
  run_elebake stage boot tree unitt a testlabel zpool99/testds > /dev/null 2>&1
  run_elebake setenv ELEBAKE_INTERPRETER_stage_tree_sync cat > /dev/null
  run_elebake setenv ELEBAKE_INTERPRETER_stage_adopt cat > /dev/null
  local out; out=$(run_elebake stage tree sync unitt a 2>&1)
  if printf '%s\n' "$out" | grep -q "stage pool import 'unitt' 'a' rw" \
     && printf '%s\n' "$out" | grep -q "stage tree work 'unitt' 'a'" \
     && printf '%s\n' "$out" | grep -q "stage tree close 'unitt' 'a'" \
     && printf '%s\n' "$out" | grep -q "stage pool export 'unitt' 'a'"; then
    pass "tree sync = pool import, tree work, tree close, pool export"
  else
    fail "tree sync batch wrong: $out"
  fi
  out=$(run_elebake stage adopt unitt a 2>&1)
  if printf '%s\n' "$out" | grep -q "stage pool import 'unitt' 'a' ro" && printf '%s\n' "$out" | grep -q "stage adopt copy 'unitt' 'a'" \
     && printf '%s\n' "$out" | grep -q "stage pool export 'unitt' 'a'"; then
    pass "adopt = pool import (ro), adopt copy, pool export"
  else
    fail "adopt batch wrong: $out"
  fi
  if head -1 "$TEST_DIR/.env/default/ELEBAKE_INTERPRETER_stage_tree_sync" | grep -q "KEEP_GOING=1" \
     && head -1 "$TEST_DIR/.env/default/ELEBAKE_INTERPRETER_stage_tree_work" | grep -q "KEEP_GOING=0"; then
    pass "the sync keeps going (close + export always run), the work core is fail-fast"
  else
    fail "keep-going wrappers missing from the installed pins"
  fi
  for cmd in "stage pool import unitt a rw" "stage tree snapshot unitt a" "stage tree copy unitt a" "stage tree verify unitt a" "stage adopt copy unitt a"; do
    out=$(run_elebake $cmd 2>&1)
    if printf '%s\n' "$out" | grep -q "device not present.*checked at generation time" && ! printf '%s\n' "$out" | grep -q "zpool\|zfs \|cp -a"; then
      pass "$cmd: absent device is refused at generation time, nothing emitted"
    else
      fail "$cmd: guard not at generation time: $out"
    fi
  done
  out=$(run_elebake stage backup unitt a lbl 'why' 2>&1)
  if printf '%s\n' "$out" | grep -q "device not present.*checked at generation time" && ! printf '%s\n' "$out" | grep -q "mount"; then
    pass "stage backup: device guard at generation time too"
  else
    fail "backup guard: $out"
  fi
  if run_elebake stage pool import unitt a bogus 2>&1 | grep -q "rw or ro"; then
    pass "pool import mode is validated"
  else
    fail "bogus pool mode accepted"
  fi
}

test_stage_loader_ingest() {
  test_header "stage loader: validation + sign-only ingest"
  test_setup
  run_elebake stage add unitl > /dev/null 2>&1
  if run_elebake stage loader ghost /tmp/x 2>&1 | grep -q "unknown stage"; then
    pass "unknown stage rejected"
  else
    fail "unknown stage not rejected"
  fi
  if run_elebake stage loader unitl /nonexistent/loader.efi 2>&1 | grep -q "no such file"; then
    pass "missing source rejected"
  else
    fail "missing source not rejected"
  fi
  printf 'FAKEEFI\n' > "$TEST_BASE_DIR/fake-loader.efi"
  run_elebake stage loader unitl "$TEST_BASE_DIR/fake-loader.efi" > /dev/null 2>&1
  if [ "$(cat "$TEST_DIR/stage/unitl/boot/loader.efi" 2>/dev/null)" = "FAKEEFI" ]; then
    pass "external loader ingested as boot/loader.efi"
  else
    fail "loader not ingested"
  fi
}

test_stage_unkey_and_attest() {
  test_header "attest key binds; unkey clears BOTH slots"
  test_setup
  run_elebake stage add unitu > /dev/null 2>&1
  run_elebake pem add uks /nonexistent/k /nonexistent/c > /dev/null
  run_elebake openpgp add uka 0011223344556677 > /dev/null
  run_elebake stage sign key unitu pem uks > /dev/null 2>&1
  run_elebake stage attest key unitu openpgp uka > /dev/null 2>&1
  if [ "$(readlink "$TEST_DIR/stage/unitu/attest-key")" = "../../openpgp/uka" ]; then
    pass "attest-key is the relative backend link"
  else
    fail "attest-key link wrong: $(readlink "$TEST_DIR/stage/unitu/attest-key")"
  fi
  run_elebake stage unkey unitu > /dev/null 2>&1
  if [ ! -L "$TEST_DIR/stage/unitu/sign-key" ] && [ ! -L "$TEST_DIR/stage/unitu/attest-key" ]; then
    pass "unkey removed both slots"
  else
    fail "unkey left a slot"
  fi
}

test_batch_fail_fast_default() {
  test_header "batch default stops at the first failing line"
  test_setup
  cat > "$TEST_BASE_DIR/unit-batch.sh" <<'EOF'
"$ELEBAKE_CONTEXT_SCRIPT" setenv ELEBAKE_UNIT_FF one
"$ELEBAKE_CONTEXT_SCRIPT" stage filter add ghost x
"$ELEBAKE_CONTEXT_SCRIPT" setenv ELEBAKE_UNIT_FF2 two
EOF
  run_elebake batch "$TEST_BASE_DIR/unit-batch.sh" > /dev/null 2>&1
  if [ "$(head -1 "$TEST_DIR/.env/local/ELEBAKE_UNIT_FF" 2>/dev/null)" = "one" ] \
     && [ ! -f "$TEST_DIR/.env/local/ELEBAKE_UNIT_FF2" ]; then
    pass "line after the failure did NOT replay (fail-fast)"
  else
    fail "fail-fast violated"
  fi
}

test_batch_exit_survives_a_closed_pipe() {
  test_header "batch exit: a consumer that closes the pipe (2>&1 | grep -q) is a write error, never a swallowed failure"
  test_setup
  cat > "$TEST_BASE_DIR/unit-pipe.sh" <<'EOF'
"$ELEBAKE_CONTEXT_SCRIPT" setenv ELEBAKE_UNIT_A one
"$ELEBAKE_CONTEXT_SCRIPT" error boom
"$ELEBAKE_CONTEXT_SCRIPT" setenv ELEBAKE_UNIT_B two
EOF
  local a="$TEST_DIR/.env/local/ELEBAKE_UNIT_A" b="$TEST_DIR/.env/local/ELEBAKE_UNIT_B" rc
  ELEBAKE_BASE="$TEST_DIR" "$TEST_SCRIPT" batch "$TEST_BASE_DIR/unit-pipe.sh" > /dev/null 2>&1; rc=$?
  if [ "$rc" -ne 0 ] && [ -f "$a" ] && [ ! -f "$b" ]; then
    pass "fail-fast, output consumed: B not set, exit $rc"
  else
    fail "fail-fast consumed: rc=$rc a=$(cat "$a" 2>/dev/null) b=$(cat "$b" 2>/dev/null)"
  fi
  rm -f "$a" "$b"
  ELEBAKE_BATCH_KEEP_GOING=1 ELEBAKE_BASE="$TEST_DIR" "$TEST_SCRIPT" batch "$TEST_BASE_DIR/unit-pipe.sh" > /dev/null 2>&1; rc=$?
  if [ "$rc" -ne 0 ] && [ -f "$a" ] && [ -f "$b" ]; then
    pass "keep-going, output consumed: B set, exit $rc still reports the failure"
  else
    fail "keep-going consumed: rc=$rc a=$(cat "$a" 2>/dev/null) b=$(cat "$b" 2>/dev/null)"
  fi
  rm -f "$a" "$b"
  ELEBAKE_BASE="$TEST_DIR" "$TEST_SCRIPT" batch "$TEST_BASE_DIR/unit-pipe.sh" 2>/dev/null | grep -q "Set ELEBAKE_UNIT_A"
  if [ -f "$a" ] && [ ! -f "$b" ]; then
    pass "fail-fast, stdout in a pipe grep closes early: B not set"
  else
    fail "stdout pipe: a=$(cat "$a" 2>/dev/null) b=$(cat "$b" 2>/dev/null)"
  fi
  rm -f "$a" "$b"
  ELEBAKE_BASE="$TEST_DIR" "$TEST_SCRIPT" batch "$TEST_BASE_DIR/unit-pipe.sh" 2>&1 | grep -q "Set ELEBAKE_UNIT_A"
  if [ -f "$a" ] && [ ! -f "$b" ]; then
    pass "fail-fast, stderr in the pipe too (2>&1): the error step is not killed, B not set"
  else
    fail "2>&1 pipe: a=$(cat "$a" 2>/dev/null) b=$(cat "$b" 2>/dev/null)"
  fi
  rm -f "$a" "$b"
  # a signal death of an interpreter is named, never read as a batch id
  ELEBAKE_BASE="$TEST_DIR" "$TEST_SCRIPT" setintp error 'sh -c "kill -TERM \$\$"' > /dev/null 2>&1
  local out; out=$(ELEBAKE_BASE="$TEST_DIR" "$TEST_SCRIPT" batch "$TEST_BASE_DIR/unit-pipe.sh" 2>&1); rc=$?
  if [ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -q "killed by signal 15" && [ ! -f "$b" ]; then
    pass "an interpreter killed by SIGTERM is reported as a signal death and stops the batch"
  else
    fail "signal death: rc=$rc b=$(cat "$b" 2>/dev/null) $(printf '%s\n' "$out" | grep -i "signal\|failed" | head -3)"
  fi
}

test_getenv_layer_reporting() {
  test_header "getenv reports the winning layer"
  test_setup
  if run_elebake getenv ELEBAKE_DISPLAY_ANSI | grep -q "default"; then
    pass "installed profile value reports default layer"
  else
    fail "default layer not reported"
  fi
  run_elebake setenv ELEBAKE_DISPLAY_ANSI 1 > /dev/null
  if run_elebake getenv ELEBAKE_DISPLAY_ANSI | grep -q "override"; then
    pass "local override wins after setenv"
  else
    fail "override not reported"
  fi
}

test_filter_and_import_path_validation() {
  test_header "record-relative path validation (filter, import dir)"
  test_setup
  run_elebake stage add unitp > /dev/null 2>&1
  if run_elebake stage filter add unitp /abs/path 2>&1 | grep -q "invalid path"; then
    pass "filter rejects absolute paths"
  else
    fail "filter accepted absolute path"
  fi
  if run_elebake stage filter add unitp a/../b 2>&1 | grep -q "invalid path"; then
    pass "filter rejects .."
  else
    fail "filter accepted .."
  fi
  if run_elebake stage import unitp ../escape 2>&1 | grep -q "invalid directory"; then
    pass "import dir rejects .."
  else
    fail "import dir accepted .."
  fi
  if run_elebake stage import unitp /abs 2>&1 | grep -q "invalid directory"; then
    pass "import dir rejects absolute"
  else
    fail "import dir accepted absolute"
  fi
}

test_dump_marker_and_backup_blocks() {
  test_header "stage dump: marker/backup blocks declare before copying"
  test_setup
  run_elebake stage add unitq > /dev/null 2>&1
  mkdir -p "$TEST_DIR/stage/unitq/marker" "$TEST_DIR/stage/unitq/backup/m"
  printf 'Boot0001\n' > "$TEST_DIR/stage/unitq/marker/bootvar"
  printf 'ORIG\n' > "$TEST_DIR/stage/unitq/backup/m/Boot0001.orig"
  local out; out=$(run_elebake stage dump unitq)
  local d1 f1
  d1=$(printf '%s\n' "$out" | grep -n "stage import 'unitq' 'marker'$" | head -1 | cut -d: -f1)
  f1=$(printf '%s\n' "$out" | grep -n "stage import 'unitq' 'marker' " | head -1 | cut -d: -f1)
  if [ -n "$d1" ] && [ -n "$f1" ] && [ "$d1" -lt "$f1" ]; then
    pass "marker: directory declared before file"
  else
    fail "marker order wrong (d=$d1 f=$f1)"
  fi
  if printf '%s\n' "$out" | grep -q "stage import 'unitq' 'backup/m' " \
     && printf '%s\n' "$out" | grep -q "stage import 'unitq' 'backup/m'$"; then
    pass "backup: declaration and base element emitted"
  else
    fail "backup block incomplete"
  fi
}

test_stage_list_derived_state() {
  test_header "stage list derives populated/signed from artifacts"
  test_setup
  run_elebake stage add unitr > /dev/null 2>&1
  if run_elebake stage list | grep "unitr" | grep -q "no"; then
    pass "fresh stage lists as unpopulated"
  else
    fail "fresh stage state wrong"
  fi
  printf 'E\n' > "$TEST_DIR/stage/unitr/boot/loader.efi"
  printf 'S\n' > "$TEST_DIR/stage/unitr/boot/loader.efi.signed"
  if run_elebake stage list | grep "unitr" | grep -q "yes"; then
    pass "populated+signed derived from files"
  else
    fail "derived state not updated"
  fi
}

test_freebsd_prerequisites_inspect() {
  test_header "freebsd prerequisites inspects the toolchain at generation time"
  test_setup
  if run_elebake freebsd prerequisites 2>&1 | grep -q "ELEBAKE_FREEBSD_SRC not set"; then
    pass "fails early without ELEBAKE_FREEBSD_SRC (no implicit default)"
  else
    fail "missing SRC not reported"
  fi
  mkdir -p "$TEST_BASE_DIR/fake-src"
  run_elebake setenv ELEBAKE_FREEBSD_SRC "$TEST_BASE_DIR/fake-src" > /dev/null
  local out; out=$(run_elebake freebsd prerequisites 2>&1)
  if printf '%s\n' "$out" | grep -qi "git"; then
    pass "with SRC set the toolchain report appears"
  else
    fail "prerequisites report empty: $out"
  fi
}


test_foundation_catalogs() {
  test_header "foundation catalogs read the worktree headers (fixture)"
  test_setup
  run_elebake stage add unitc > /dev/null 2>&1
  if run_elebake stage measure unitc 2>&1 | grep -q "no worktree"; then
    pass "catalog without checkout fails early"
  else
    fail "missing worktree not reported"
  fi
  fixture_worktree unitc
  local out
  out=$(run_elebake stage measure unitc)
  if printf '%s\n' "$out" | grep -q "measure_alpha" && printf '%s\n' "$out" | grep -q "diagnose_alpha" \
     && printf '%s\n' "$out" | grep -q "checkout: fixture-ref"; then
    pass "measure catalog lists functions with provenance"
  else
    fail "measure catalog wrong: $out"
  fi
  if run_elebake stage action unitc | grep -q "test_act"; then
    pass "action catalog lists *_act"
  else
    fail "action catalog wrong"
  fi
  if run_elebake stage when unitc | grep -q "when_always"; then
    pass "when catalog lists predicates"
  else
    fail "when catalog wrong"
  fi
  out=$(run_elebake stage phase show unitc)
  if printf '%s\n' "$out" | grep -q "PHASE_ONE" && printf '%s\n' "$out" | grep -q "no policies bound"; then
    pass "phase catalog lists phases with binding placeholder"
  else
    fail "phase catalog wrong: $out"
  fi
  mkdir -p "$TEST_DIR/stage/unitc/phases"
  printf 'watch-x\n' > "$TEST_DIR/stage/unitc/phases/PHASE_TWO"
  if run_elebake stage phase show unitc PHASE_TWO | grep -q "policy: watch-x"; then
    pass "bound policies render per phase"
  else
    fail "bound policies not rendered"
  fi
  if run_elebake stage phase show unitc PHASE_NINE 2>&1 | grep -q "unknown phase"; then
    pass "unknown phase fails early"
  else
    fail "unknown phase not rejected"
  fi
}

# fixture_worktree <stage> - shared helper: minimal local/ headers + work
# symlink + checkout ref for the catalog/binding tests
fixture_worktree() {
  local fix="$TEST_BASE_DIR/fix-work-$TESTS_RUN-$1/stand/efi/loader/local"
  mkdir -p "$fix"
  printf 'loader.measure measurement.h struct[[:space:]]measurement[[:space:]]*%%s( not in the loader catalog of this checkout\nloader.diagnose measurement.h void[[:space:]]*%%s( not in the loader catalog of this checkout\nloader.when policy.h ^bool[[:space:]]*%%s( not in the loader catalog of this checkout\nloader.action action.h extern[[:space:]]const[[:space:]]struct[[:space:]]action[[:space:]]*%%s; not in the loader catalog of this checkout\n' > "$fix/catalog.tbl"
  printf 'struct measurement\tmeasure_alpha(int argc, CHAR16 *argv[]);\nstruct measurement\tmeasure_record(int argc, CHAR16 *argv[]);\nvoid\tdiagnose_alpha(int argc, CHAR16 *argv[], struct diagnosis *);\n' > "$fix/measurement.h"
  printf 'bool\twhen_always(const struct appraisal *);\nenum phase {\n\tPHASE_ONE,\n\tPHASE_TWO,\n};\n' > "$fix/policy.h"
  printf 'extern const struct action\ttest_act;\nextern const struct action\thandover_act;\n' > "$fix/action.h"
  ln -sfn "$TEST_BASE_DIR/fix-work-$TESTS_RUN-$1" "$TEST_DIR/stage/$1/work"
  printf 'fixture-ref\n' > "$TEST_DIR/stage/$1/checkout"
}

test_foundation_expectation_crud() {
  test_header "expectation CRUD: add renders, drop removes, errors are precise"
  test_setup
  run_elebake expectation add strict-active byte StrictActive 1 > /dev/null
  if run_elebake expectation show | grep -q 'strict-active: MEASUREMENT_BYTE("StrictActive", 1)'; then
    pass "add stores, show renders the C form"
  else
    fail "expectation show wrong: $(run_elebake expectation show)"
  fi
  run_elebake macro add BOARD_DIGEST sha256 BoardIdentity > /dev/null
  run_elebake expectation add board-expected macro - BOARD_EXPECTED > /dev/null
  if run_elebake expectation show board-expected | grep -q "board-expected: BOARD_EXPECTED"; then
    pass "macro type renders the value verbatim"
  else
    fail "macro rendering wrong"
  fi
  if run_elebake expectation add "bad/name" byte X 1 2>&1 | grep -q "invalid name"; then
    pass "invalid name fails early"
  else
    fail "invalid name accepted"
  fi
  if run_elebake expectation add quoted byte X "it's" 2>&1 | grep -q "single quotes"; then
    pass "quote in a field fails early"
  else
    fail "quoted field accepted"
  fi
  run_elebake expectation drop strict-active > /dev/null
  if [ ! -f "$TEST_DIR/foundation/expectations/strict-active" ]; then
    pass "drop removes the record"
  else
    fail "drop left the record"
  fi
  if run_elebake expectation drop strict-active 2>&1 | grep -q "no such expectation"; then
    pass "drop of a missing record fails early"
  else
    fail "missing drop not reported"
  fi
}

test_foundation_claim_trigger_crud() {
  test_header "claim and trigger CRUD: rendering expands the expectation"
  test_setup
  run_elebake expectation add strict-active byte StrictActive 1 > /dev/null
  run_elebake claim add strict-active measure_strict - strict.active strict-active > /dev/null
  if run_elebake claim show strict-active | grep -q 'CLAIM(measure_strict, NULL, "strict.active", MEASUREMENT_BYTE("StrictActive", 1))'; then
    pass "claim show expands diagnose/publish/expectation into the C form"
  else
    fail "claim show wrong: $(run_elebake claim show strict-active)"
  fi
  run_elebake claim add plain measure_x diagnose_x - strict-active > /dev/null
  if run_elebake claim show plain | grep -q 'CLAIM(measure_x, diagnose_x, NULL,'; then
    pass "dash fields render as NULL / bare diagnose"
  else
    fail "dash-field rendering wrong"
  fi
  run_elebake trigger add publish-always when_always publish_act > /dev/null
  if run_elebake trigger show publish-always | grep -q 'FIRE(when_always, &publish_act)'; then
    pass "trigger show renders the FIRE form"
  else
    fail "trigger show wrong"
  fi
  run_elebake claim drop plain > /dev/null
  if run_elebake claim show 2>&1 | grep -q "plain"; then
    fail "dropped claim still shown"
  else
    pass "claim drop removes the record"
  fi
}

test_foundation_gate_policy_crud() {
  test_header "gate and policy CRUD: ordered lists, unlink keeps the referee"
  test_setup
  run_elebake expectation add e1 byte A 1 > /dev/null
  run_elebake claim add c1 measure_a - - e1 > /dev/null
  run_elebake claim add c2 measure_b - - e1 > /dev/null
  run_elebake gate add strictwatch > /dev/null
  run_elebake gate add bootlock LOADER_TRUST_BOOTLOCK_SECRET > /dev/null
  run_elebake gate claim add strictwatch c1 > /dev/null
  run_elebake gate claim add strictwatch c2 > /dev/null
  local out; out=$(run_elebake gate show strictwatch)
  if printf '%s\n' "$out" | grep -q 'GATE_DEFINE(strictwatch, NULL' \
     && [ "$(printf '%s\n' "$out" | grep -c 'CLAIM(')" = "2" ]; then
    pass "gate show renders GATE_DEFINE with both claims"
  else
    fail "gate show wrong: $out"
  fi
  if run_elebake gate show bootlock | grep -q 'GATE_DEFINE(bootlock, BOOTLOCK_SECRET'; then
    pass "the secret renders as the LOCAL macro (same as the emission)"
  else
    fail "secret slot missing"
  fi
  run_elebake gate claim drop strictwatch c1 > /dev/null
  if ! grep -qx c1 "$TEST_DIR/foundation/gates/strictwatch/claims" \
     && [ -f "$TEST_DIR/foundation/claims/c1" ]; then
    pass "gate claim drop unlinks only, the claim survives"
  else
    fail "unlink semantics wrong"
  fi
  run_elebake trigger add t1 when_always publish_act > /dev/null
  run_elebake trigger add t2 when_fail unlock_act > /dev/null
  run_elebake policy add watch strictwatch > /dev/null
  run_elebake policy trigger add watch t1 > /dev/null
  run_elebake policy trigger add watch t2 > /dev/null
  out=$(run_elebake policy show watch)
  if printf '%s\n' "$out" | grep -q 'POLICY(strictwatch' \
     && [ "$(printf '%s\n' "$out" | grep -c 'FIRE(')" = "2" ]; then
    pass "policy show renders POLICY with both FIREs"
  else
    fail "policy show wrong: $out"
  fi
  run_elebake policy trigger drop watch t1 > /dev/null
  if [ "$(grep -c '^trigger ' "$TEST_DIR/foundation/policies/watch")" = "1" ] \
     && [ -f "$TEST_DIR/foundation/triggers/t1" ]; then
    pass "policy trigger drop removes the reference, the trigger survives"
  else
    fail "trigger drop semantics wrong"
  fi
}

test_foundation_immutability_idempotence() {
  test_header "add is idempotent-immutable: identical no-op, differing refused"
  test_setup
  run_elebake expectation add e1 byte A 1 > /dev/null
  if run_elebake expectation add e1 byte A 1 2>&1 | grep -q "already stored"; then
    pass "identical re-add is a silent no-op (dump replays)"
  else
    fail "identical re-add not idempotent"
  fi
  if run_elebake expectation add e1 byte A 2 2>&1 | grep -q "different content"; then
    pass "differing re-add is refused (immutable)"
  else
    fail "differing re-add accepted"
  fi
  if grep -q "byte A 1" "$TEST_DIR/foundation/expectations/e1"; then
    pass "the stored record is untouched"
  else
    fail "record was modified"
  fi
  run_elebake gate add g1 SLOT_X > /dev/null
  run_elebake claim add c1 m - - e1 > /dev/null
  run_elebake gate claim add g1 c1 > /dev/null
  run_elebake gate add g1 SLOT_X > /dev/null 2>&1
  if grep -qx c1 "$TEST_DIR/foundation/gates/g1/claims"; then
    pass "gate re-add leaves the claims list untouched"
  else
    fail "gate re-add clobbered the claims list"
  fi
  if run_elebake gate add g1 OTHER_SLOT 2>&1 | grep -q "different slots"; then
    pass "gate re-add with another slot is refused"
  else
    fail "slot change accepted"
  fi
  run_elebake gate claim add g1 c1 > /dev/null
  if [ "$(grep -c '' "$TEST_DIR/foundation/gates/g1/claims")" = "1" ]; then
    pass "gate claim re-add appends nothing (idempotent)"
  else
    fail "duplicate claim line appended"
  fi
}

test_foundation_position() {
  test_header "<position> is the one ordering tool (1-based, validated early)"
  test_setup
  run_elebake expectation add e1 byte A 1 > /dev/null
  run_elebake claim add ca m - - e1 > /dev/null
  run_elebake claim add cb m - - e1 > /dev/null
  run_elebake claim add cc m - - e1 > /dev/null
  run_elebake gate add g1 > /dev/null
  run_elebake gate claim add g1 ca > /dev/null
  run_elebake gate claim add g1 cc > /dev/null
  run_elebake gate claim add g1 cb 2 > /dev/null
  if [ "$(tr '\n' ' ' < "$TEST_DIR/foundation/gates/g1/claims")" = "ca cb cc " ]; then
    pass "insert-at-position places between existing references"
  else
    fail "order wrong: $(cat "$TEST_DIR/foundation/gates/g1/claims")"
  fi
  if run_elebake gate claim add g1 ca 1 2>&1 | grep -q "already referenced"; then
    pass "position on an existing reference is refused (not a move)"
  else
    fail "duplicate position accepted"
  fi
  if run_elebake claim add cd m - - e1 > /dev/null && run_elebake gate claim add g1 cd 9 2>&1 | grep -q "out of range"; then
    pass "out-of-range position fails early"
  else
    fail "out-of-range accepted"
  fi
  run_elebake trigger add t1 w a > /dev/null
  run_elebake trigger add t2 w a > /dev/null
  run_elebake policy add p1 g1 > /dev/null
  run_elebake policy trigger add p1 t2 > /dev/null
  run_elebake policy trigger add p1 t1 1 > /dev/null
  if [ "$(head -1 "$TEST_DIR/foundation/policies/p1")" = "gate g1" ] \
     && [ "$(sed -n '2p' "$TEST_DIR/foundation/policies/p1")" = "trigger t1" ]; then
    pass "trigger position counts among trigger lines, the gate line stays first"
  else
    fail "policy file order wrong: $(cat "$TEST_DIR/foundation/policies/p1")"
  fi
}

test_foundation_dangling_show() {
  test_header "dangling references render visibly, never fatally"
  test_setup
  if run_elebake claim add c1 measure_x - - ghost-exp | grep -q "no such expectation" && [ ! -f "$TEST_DIR/foundation/claims/c1" ]; then
    pass "claim add refuses a missing expectation (the reference never dangles)"
  else
    fail "dangling expectation accepted"
  fi
  run_elebake gate add g1 > /dev/null
  if run_elebake gate claim add g1 ghost-claim | grep -q "no such claim" && ! grep -qs ghost-claim "$TEST_DIR/foundation/gates/g1/claims"; then
    pass "gate claim add refuses a missing claim (the reference never dangles)"
  else
    fail "dangling claim accepted"
  fi
}

test_stage_phase_policy_binding() {
  test_header "the BINDING is the contract: transitive check against the catalog"
  test_setup
  run_elebake stage add unitb > /dev/null 2>&1
  fixture_worktree unitb
  run_elebake expectation add e1 byte A 1 > /dev/null
  run_elebake claim add c1 measure_alpha diagnose_alpha - e1 > /dev/null
  run_elebake gate add g1 > /dev/null
  run_elebake gate claim add g1 c1 > /dev/null
  run_elebake trigger add t1 when_always test_act > /dev/null
  run_elebake policy add p1 g1 > /dev/null
  run_elebake policy trigger add p1 t1 > /dev/null
  run_elebake stage phase policy add unitb PHASE_ONE p1 > /dev/null 2>&1
  if grep -qx p1 "$TEST_DIR/stage/unitb/phases/PHASE_ONE"; then
    pass "valid chain binds (phases/PHASE_ONE holds the policy name)"
  else
    fail "binding did not land: $(ls -R "$TEST_DIR/stage/unitb" 2>&1)"
  fi
  local shout; shout=$(run_elebake stage phase show unitb PHASE_ONE)
  if printf '%s\n' "$shout" | grep -q "policy: p1" \
     && printf '%s\n' "$shout" | grep -q 'static const struct policy one_policies\[\] = {' \
     && printf '%s\n' "$shout" | grep -q 'POLICY_END,'; then
    pass "stage phase show renders binding AND the emitted table form"
  else
    fail "phase show wrong: $shout"
  fi
  run_elebake stage phase policy add unitb PHASE_ONE p1 > /dev/null 2>&1
  if [ "$(grep -c '' "$TEST_DIR/stage/unitb/phases/PHASE_ONE")" = "1" ]; then
    pass "re-binding appends nothing (idempotent append)"
  else
    fail "duplicate binding line"
  fi
  if run_elebake stage phase policy add unitb PHASE_NINE p1 2>&1 | grep -q "unknown phase"; then
    pass "unknown phase fails at check policy"
  else
    fail "unknown phase accepted"
  fi
  run_elebake claim add cbad measure_bogus - - e1 > /dev/null
  run_elebake gate add gbad > /dev/null
  run_elebake gate claim add gbad cbad > /dev/null
  run_elebake policy add pbad gbad > /dev/null
  if run_elebake stage phase policy add unitb PHASE_ONE pbad 2>&1 | grep -q "not in the loader catalog of this checkout"; then
    pass "unknown measurement fails the transitive check"
  else
    fail "bogus measurement accepted"
  fi
  if run_elebake policy add pghost ghost-gate | grep -q "no such gate" && [ ! -f "$TEST_DIR/foundation/policies/pghost" ]; then
    pass "policy add refuses a missing gate (the reference never dangles)"
  else
    fail "dangling gate accepted"
  fi
  run_elebake stage phase policy drop unitb PHASE_ONE p1 > /dev/null
  if ! grep -qx p1 "$TEST_DIR/stage/unitb/phases/PHASE_ONE" 2>/dev/null; then
    pass "drop unbinds (the policy itself survives)"
  else
    fail "unbind failed"
  fi
}

test_foundation_dump_replays() {
  test_header "the dump replays the arsenal in dependency order + the bindings"
  test_setup
  run_elebake stage add unitd > /dev/null 2>&1
  fixture_worktree unitd
  run_elebake macro add ALPHA_DIGEST sha256 AlphaIdent > /dev/null
  run_elebake expectation add e1 byte A 1 > /dev/null
  run_elebake claim add c1 measure_alpha - - e1 > /dev/null
  run_elebake trigger add t1 when_always test_act > /dev/null
  run_elebake gate add g1 SLOT_X > /dev/null
  run_elebake gate claim add g1 c1 > /dev/null
  run_elebake policy add p1 g1 > /dev/null
  run_elebake policy trigger add p1 t1 > /dev/null
  run_elebake stage phase policy add unitd PHASE_TWO p1 > /dev/null 2>&1
  local out; out=$(run_elebake foundation dump)
  local want="macro add 'ALPHA_DIGEST' 'sha256' 'AlphaIdent' '-' '-'
expectation add 'e1' 'byte' 'A' '1'
claim add 'c1' 'measure_alpha' '-' '-' 'e1'
trigger add 't1' 'when_always' 'test_act'
gate add 'g1' 'SLOT_X' '-'
gate claim add 'g1' 'c1'
policy add 'p1' 'g1'
policy trigger add 'p1' 't1'"
  if [ "$(printf '%s\n' "$out" | grep 'CONTEXT_SCRIPT' | sed 's/^"[^"]*" //')" = "$want" ]; then
    pass "foundation dump replays every family in dependency order"
  else
    fail "dump replays wrong: $out"
  fi
  if run_elebake stage dump unitd | grep -q "stage phase policy append 'unitd' 'PHASE_TWO' 'p1'"; then
    pass "stage dump replays the phase binding (check-free append)"
  else
    fail "phase binding missing from stage dump"
  fi
  if run_elebake dump | grep -q "expectation add 'e1'"; then
    pass "the database dump carries the foundation replays"
  else
    fail "foundation replays missing from the database dump"
  fi
}

test_foundation_macro_crud() {
  test_header "macro CRUD: derivations, explicit else/defined, immutability"
  test_setup
  run_elebake macro add BOARD_DIGEST sha256 BoardIdentity > /dev/null
  local out; out=$(run_elebake macro show BOARD_DIGEST)
  if printf '%s\n' "$out" | grep -q '#ifdef LOADER_TRUST_BOARD_DIGEST' \
     && printf '%s\n' "$out" | grep -q 'BOARD_EXPECTED.*MEASUREMENT_SHA256("BoardIdentity", LOADER_TRUST_BOARD_DIGEST)' \
     && printf '%s\n' "$out" | grep -q 'MEASUREMENT_NONE("BoardIdentity", MEAS_SHA256)'; then
    pass "3-arg form derives guard, defined name and the NONE alternative"
  else
    fail "macro show wrong: $out"
  fi
  run_elebake macro add SB_STATE byte SecureBoot 'MEASUREMENT_BYTE("SecureBoot", 1)' > /dev/null
  if run_elebake macro show SB_STATE | grep -q 'SB_STATE_EXPECTED.MEASUREMENT_BYTE("SecureBoot", 1)$'; then
    pass "4-arg form takes a verbatim C alternative"
  else
    fail "explicit else wrong: $(run_elebake macro show SB_STATE)"
  fi
  run_elebake macro add RAW_DIGEST sha256 RawThing - RAW_BASELINE > /dev/null
  if run_elebake macro show RAW_DIGEST | grep -q 'RAW_BASELINE.MEASUREMENT_SHA256'; then
    pass "5-arg form takes an explicit defined name"
  else
    fail "explicit defined wrong: $(run_elebake macro show RAW_DIGEST)"
  fi
  if run_elebake macro add board_digest sha256 X 2>&1 | grep -q "invalid macro name"; then
    pass "lowercase macro name fails early (C macro stem)"
  else
    fail "lowercase name accepted"
  fi
  if run_elebake macro add BOARD_DIGEST sha256 BoardIdentity 2>&1 | grep -q "already stored"; then
    pass "identical re-add is a no-op"
  else
    fail "identical re-add not idempotent"
  fi
  if run_elebake macro add BOARD_DIGEST byte Other 2>&1 | grep -q "different content"; then
    pass "differing re-add is refused"
  else
    fail "differing re-add accepted"
  fi
  run_elebake macro drop RAW_DIGEST > /dev/null
  if [ ! -f "$TEST_DIR/foundation/macros/RAW_DIGEST" ]; then
    pass "drop removes the record"
  else
    fail "drop left the record"
  fi
}

test_stage_foundation_emitter() {
  test_header "stage foundation: check re-verifies, make emits the generated-only C"
  test_setup
  run_elebake stage add unite > /dev/null 2>&1
  fixture_worktree unite
  run_elebake macro add ALPHA_DIGEST sha256 AlphaIdent > /dev/null
  run_elebake expectation add alpha-macro macro - ALPHA_EXPECTED > /dev/null
  run_elebake expectation add alpha-byte byte AlphaFlag 1 > /dev/null
  run_elebake claim add cm measure_alpha - - alpha-macro > /dev/null
  run_elebake claim add cb measure_alpha diagnose_alpha alpha.pub alpha-byte > /dev/null
  run_elebake gate add gsec LOADER_TRUST_GSEC_SECRET > /dev/null
  run_elebake gate claim add gsec cm > /dev/null
  run_elebake gate claim add gsec cb > /dev/null
  run_elebake trigger add ta when_always test_act > /dev/null
  run_elebake policy add pa gsec > /dev/null
  run_elebake policy trigger add pa ta > /dev/null
  run_elebake stage phase policy add unite PHASE_ONE pa > /dev/null 2>&1
  if run_elebake stage foundation check unite 2>&1 | grep -q "foundation check ok: 1 binding"; then
    pass "foundation check answers its caller with the verified count"
  else
    fail "check answer wrong: $(run_elebake stage foundation check unite 2>&1)"
  fi
  local chk; chk=$(run_elebake stage foundation check unite 2>&1)
  if printf '%s\n' "$chk" | grep -q "gate gsec: secret slot LOADER_TRUST_GSEC_SECRET has no baseline" \
     && printf '%s\n' "$chk" | grep -q "macro ALPHA_DIGEST: LOADER_TRUST_ALPHA_DIGEST has no value yet" \
     && printf '%s\n' "$chk" | grep -q "foundation check ok: 1 binding"; then
    pass "the check names the empty lock slot and the macro without value"
  else
    fail "unprovisioned notes: $chk"
  fi
  run_elebake stage baseline add unite LOADER_TRUST_GSEC_SECRET string 00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff > /dev/null 2>&1
  printf 'CFLAGS+= -DLOADER_TRUST_ALPHA_DIGEST=0x00\n' > "$TEST_BASE_DIR/fix-work-$TESTS_RUN-unite/stand/efi/loader/local/site.mk"
  if run_elebake stage foundation check unite 2>&1 | grep -q "LOADER_TRUST_GSEC_SECRET provisioned" && run_elebake stage foundation check unite 2>&1 | grep -q "LOADER_TRUST_ALPHA_DIGEST provisioned"; then
    pass "a baseline record or a site.mk line counts as provided: the check reports everything provisioned"
  else
    fail "after baselines: $(run_elebake stage foundation check unite 2>&1)"
  fi
  run_elebake expectation add rec-valid byte RecordValid 1 > /dev/null
  run_elebake claim add rec measure_record - - rec-valid > /dev/null
  run_elebake gate claim add gsec rec > /dev/null
  run_elebake trigger add th when_always handover_act > /dev/null
  run_elebake policy trigger add pa th > /dev/null
  local chk2; chk2=$(run_elebake stage foundation check unite 2>&1)
  if printf '%s\n' "$chk2" | grep -q "measure_record needs LOADER_TRUST_RECORD_SALT" \
     && printf '%s\n' "$chk2" | grep -q "handover_act needs LOADER_TRUST_WORD_SECRET" \
     && run_elebake stage require unite | grep -q "measure_record needs LOADER_TRUST_RECORD_SALT"; then
    pass "record claim and handover demand their baselines: the check and stage require name them"
  else
    fail "baseline demands: $chk2 $(run_elebake stage require unite 2>&1)"
  fi
  run_elebake stage baseline add unite LOADER_TRUST_RECORD_SALT string 0123456789abcdef > /dev/null 2>&1
  run_elebake stage baseline add unite LOADER_TRUST_WORD_SECRET string fedcba9876543210 > /dev/null 2>&1
  if run_elebake stage foundation check unite 2>&1 | grep -q "handover_act: LOADER_TRUST_WORD_SECRET provisioned" \
     && run_elebake stage require unite | grep -q "handover_act: LOADER_TRUST_WORD_SECRET provisioned"; then
    pass "with the baselines both demands are satisfied"
  else
    fail "after demand baselines: $(run_elebake stage foundation check unite 2>&1; run_elebake stage require unite)"
  fi
  if run_elebake gate add "bad-gate" 2>&1 | grep -q "C identifier"; then
    pass "gate names must be C identifiers (they land in the C output)"
  else
    fail "hyphenated gate name accepted"
  fi
  run_elebake stage foundation make unite > /dev/null 2>&1
  local c="$TEST_BASE_DIR/fix-work-$TESTS_RUN-unite/stand/efi/loader/local/foundation/foundation.c"
  if [ -f "$c" ] && grep -q '#ifdef LOADER_TRUST_ALPHA_DIGEST' "$c" \
     && grep -q 'GSEC_SECRET.LOADER_TRUST_GSEC_SECRET' "$c" \
     && grep -q 'GATE_DEFINE(gsec, GSEC_SECRET,' "$c" \
     && grep -q 'CLAIM(measure_alpha, NULL, NULL, ALPHA_EXPECTED)' "$c" \
     && grep -q 'CLAIM(measure_alpha, diagnose_alpha, "alpha.pub", MEASUREMENT_BYTE("AlphaFlag", 1))' "$c"; then
    pass "make renders macros, secret mapping and the gate"
  else
    fail "generated C wrong: $(cat "$c" 2>&1)"
  fi
  if grep -q 'static const struct policy two_policies\[\] = {' "$c" \
     && grep -q 'case PHASE_TWO:' "$c" \
     && grep -q 'return (two_policies);' "$c"; then
    pass "unbound phases get an empty table, the switch covers the enum"
  else
    fail "phase tables/switch wrong"
  fi
  if run_elebake stage foundation report unite | grep -q "target: .*foundation/foundation.c"; then
    pass "report names the emission target"
  else
    fail "report wrong"
  fi
  if run_elebake macro drop ALPHA_DIGEST | grep -q "referenced" && [ -f "$TEST_DIR/foundation/macros/ALPHA_DIGEST" ]; then
    pass "a macro record an expectation names cannot be dropped (the world cannot drift under the bindings)"
  else
    fail "referenced macro dropped: $(run_elebake macro drop ALPHA_DIGEST 2>&1)"
  fi
}

test_stage_kernel_build_emissions() {
  test_header "stage build/install kernel: the source delivers, the filter selects"
  test_setup
  run_elebake stage add unitk > /dev/null 2>&1
  if run_elebake stage build kernel unitk 2>&1 | grep -q "not checked out"; then
    pass "build kernel fails early without a worktree"
  else
    fail "missing worktree not reported"
  fi
  mkdir -p "$TEST_BASE_DIR/kfix-$TESTS_RUN/sys/amd64/conf"
  printf 'ident GENERIC\n' > "$TEST_BASE_DIR/kfix-$TESTS_RUN/sys/amd64/conf/GENERIC"
  ln -sfn "$TEST_BASE_DIR/kfix-$TESTS_RUN" "$TEST_DIR/stage/unitk/work"
  if run_elebake stage build kernel unitk 2>&1 | grep -q "ELEBAKE_KERNCONF not set"; then
    pass "no implicit KERNCONF — the guarding kernel is a decision"
  else
    fail "missing KERNCONF not reported"
  fi
  run_elebake setenv ELEBAKE_KERNCONF GENERIC > /dev/null
  if run_elebake stage build kernel unitk 2>&1 | grep -q "no such KERNCONF"; then
    fail "existing KERNCONF rejected"
  fi
  run_elebake setintp stage_build_kernel_run cat > /dev/null
  local out; out=$(run_elebake stage build kernel unitk)
  if printf '%s\n' "$out" | grep -q "buildkernel KERNCONF='GENERIC'" \
     && printf '%s\n' "$out" | grep -q "MAKEOBJDIRPREFIX="; then
    pass "buildkernel emission: isolated obj + KERNCONF"
  else
    fail "buildkernel emission wrong: $out"
  fi
  run_elebake setenv ELEBAKE_MAKEARGS "WITH_VERIEXEC=yes" > /dev/null
  run_elebake setintp stage_install_kernel_run cat > /dev/null
  if run_elebake stage build kernel unitk | grep -q "make -C '[^']*' WITH_VERIEXEC=yes buildkernel" \
     && run_elebake stage install kernel unitk | grep -q "make -C '[^']*' WITH_VERIEXEC=yes installkernel"; then
    pass "ELEBAKE_MAKEARGS reaches buildkernel AND installkernel alike"
  else
    fail "make args not carried into both: $(run_elebake stage build kernel unitk; run_elebake stage install kernel unitk)"
  fi
  run_elebake setenv ELEBAKE_MAKEARGS "" > /dev/null
  run_elebake setenv ELEBAKE_KERNCONF BOGUS > /dev/null
  if run_elebake stage build kernel unitk 2>&1 | grep -q "no such KERNCONF in this checkout: BOGUS"; then
    pass "unknown KERNCONF fails against the checkout"
  else
    fail "bogus KERNCONF accepted"
  fi
  run_elebake setenv ELEBAKE_KERNCONF GENERIC > /dev/null
  mkdir -p "$TEST_DIR/stage/unitk/obj"
  run_elebake setintp stage_install_kernel_run cat > /dev/null
  out=$(run_elebake stage install kernel unitk)
  if printf '%s\n' "$out" | grep -q "installkernel KERNCONF='GENERIC'" \
     && printf '%s\n' "$out" | grep -q 'install -U' \
     && printf '%s\n' "$out" | grep -q "DESTDIR="; then
    pass "installkernel emission: unprivileged into the stage destdir"
  else
    fail "installkernel emission wrong: $out"
  fi
}

test_collect_speaks_archive_base() {
  test_header "collect: real record paths, name symlink last, base as a variable"
  test_setup
  run_elebake stage add c1 > /dev/null 2>&1
  mkdir -p "$TEST_DIR/stage/c1/boot" "$TEST_DIR/stage/c1/marker"
  printf 'E\n' > "$TEST_DIR/stage/c1/boot/loader.efi"
  printf 'B\n' > "$TEST_DIR/stage/c1/marker/bootvar"
  local out; out=$(run_elebake stage collect c1)
  if printf '%s\n' "$out" | grep -q '"\$ELEBAKE_ARCHIVE_BASE"/\.staging/.*/boot/loader\.efi'; then
    pass "records are listed by their REAL path, against the base variable"
  else
    fail "collect path wrong: $out"
  fi
  if printf '%s\n' "$out" | grep -q 'stage/c1$' \
     && [ "$(printf '%s\n' "$out" | grep -c 'ELEBAKE_ARCHIVE_BASE')" -ge 3 ]; then
    pass "the name symlink is listed"
  else
    fail "symlink entry missing"
  fi
  if [ "$(printf '%s\n' "$out" | tail -1)" = '"$ELEBAKE_ARCHIVE_BASE"/stage/c1' ]; then
    pass "the symlink comes LAST -- a link target must exist before the link"
  else
    fail "symlink not last: $(printf '%s\n' "$out" | tail -1)"
  fi
  if run_elebake collect | grep -q "# foundation" && run_elebake collect | grep -q "# stage c1"; then
    pass "the top-level collect fans out to every class"
  else
    fail "fan-out missing"
  fi
}

test_filter_strategies() {
  test_header "filter: redacted drops machine secrets, full keeps them, both audit"
  test_setup
  local coll="$TEST_BASE_DIR/coll-$TESTS_RUN"
  cat > "$coll" <<'FEOF'
# stage x
"$ELEBAKE_ARCHIVE_BASE"/.staging/stage-x/boot/loader.efi
"$ELEBAKE_ARCHIVE_BASE"/.staging/stage-x/marker/bootvar
"$ELEBAKE_ARCHIVE_BASE"/.staging/stage-x/backup/a/old.efi
"$ELEBAKE_ARCHIVE_BASE"/.staging/stage-x/work/stand/efi/loader/local/site.mk
FEOF
  run_elebake filter redacted "$coll" "$coll.red" > /dev/null 2>&1
  if grep -q 'boot/loader.efi' "$coll.red" \
     && grep -q '# dropped (redacted).*marker/bootvar' "$coll.red" \
     && grep -q '# dropped (redacted).*backup' "$coll.red" \
     && grep -q '# dropped (redacted).*site.mk' "$coll.red"; then
    pass "redacted drops marker, backup and site.mk -- as auditable comments"
  else
    fail "redaction wrong: $(cat "$coll.red" 2>&1)"
  fi
  run_elebake filter full "$coll" "$coll.full" > /dev/null 2>&1
  if grep -q 'marker/bootvar' "$coll.full" && ! grep -q 'dropped (redacted)' "$coll.full"; then
    pass "full keeps what redacted drops"
  else
    fail "full strategy wrong"
  fi
  run_elebake filter "$coll" "$coll.def" > /dev/null 2>&1
  if [ -f "$coll.def" ] && cmp -s "$coll.def" "$coll.red"; then
    pass "the bare form delegates through default to redacted"
  else
    fail "default delegation wrong: $(cat "$coll.def" 2>&1 | head -3)"
  fi
  cat > "$coll.m" <<'FEOF'
"$ELEBAKE_ARCHIVE_BASE"/.staging/stage-x/boot/loader.efi
"$ELEBAKE_ARCHIVE_BASE"/.staging/stage-x/boot/loader.efi.signed
"$ELEBAKE_ARCHIVE_BASE"/.staging/stage-x/boot/loader.conf
"$ELEBAKE_ARCHIVE_BASE"/.staging/stage-x/boot/kernel/kernel
"$ELEBAKE_ARCHIVE_BASE"/.staging/stage-x/boot/kernel/if_x.ko
"$ELEBAKE_ARCHIVE_BASE"/.staging/stage-x/boot/lua/loader.lua
"$ELEBAKE_ARCHIVE_BASE"/.staging/stage-x/boot/defaults/loader.conf
"$ELEBAKE_ARCHIVE_BASE"/.staging/stage-x/marker/bootvar
"$ELEBAKE_ARCHIVE_BASE"/.staging/stage-x/backup/a/known-good/loader.efi
"$ELEBAKE_ARCHIVE_BASE"/.staging/stage-x/media/a/node
"$ELEBAKE_ARCHIVE_BASE"/.staging/stage-x/metadata
"$ELEBAKE_ARCHIVE_BASE"/.staging/stage-x/phases/loaderconf
"$ELEBAKE_ARCHIVE_BASE"/stage/x
"$ELEBAKE_ARCHIVE_BASE"/foundation/gates/g1
"$ELEBAKE_ARCHIVE_BASE"/openpgp/att/keyid
"$ELEBAKE_ARCHIVE_BASE"/provenance/000001-abc/serial
FEOF
  run_elebake filter minimized "$coll.m" "$coll.min" > /dev/null 2>&1
  local keep drop ok=1
  for keep in boot/loader.efi boot/loader.efi.signed boot/loader.conf boot/kernel/kernel boot/kernel/if_x.ko backup/a/known-good media/a/node stage-x/metadata '^"$ELEBAKE_ARCHIVE_BASE"/stage/x' openpgp/att provenance/000001; do
    grep -q "$keep" "$coll.min" && ! grep -q "dropped.*$keep" "$coll.min" || { ok=0; fail "minimized dropped: $keep"; }
  done
  for drop in lua/loader.lua defaults/loader.conf marker/bootvar phases/loaderconf foundation/gates; do
    grep -q "# dropped (minimized).*$drop" "$coll.min" || { ok=0; fail "minimized kept: $drop"; }
  done
  [ "$ok" -eq 1 ] && pass "minimized keeps binary management (loader, loader.conf, kernel/, backups, media, keys, receipts) and drops the rest, audited"
}

test_manifest_covers_what_travels() {
  test_header "manifest: hashes files, records symlink targets, refuses a short list"
  test_setup
  run_elebake stage add m1 > /dev/null 2>&1
  mkdir -p "$TEST_DIR/stage/m1/boot"
  printf 'E\n' > "$TEST_DIR/stage/m1/boot/loader.efi"
  local coll="$TEST_BASE_DIR/mcoll-$TESTS_RUN"
  run_elebake stage collect m1 > "$coll"
  local man="$TEST_BASE_DIR/mdir-$TESTS_RUN/MANIFEST"
  mkdir -p "$(dirname "$man")"
  run_elebake manifest "$coll" "$man" > /dev/null 2>&1
  if grep -q 'boot/loader.efi sha256=[0-9a-f][0-9a-f]*$' "$man"; then
    pass "regular files carry their sha256, boot-manifest format"
  else
    fail "hash line missing: $(cat "$man" 2>&1)"
  fi
  if grep -q '^stage/m1 symlink=\.\./\.staging/' "$man"; then
    pass "a name symlink travels as its TARGET -- retargeting a stage is detectable"
  else
    fail "symlink line missing: $(cat "$man" 2>&1)"
  fi
  if ! grep -q 'MANIFEST' "$man"; then
    pass "the manifest never lists itself or its signature"
  else
    fail "manifest lists itself"
  fi
  if run_elebake manifest "$coll" "$TEST_BASE_DIR/wrongname" 2>&1 | grep -q "must be named MANIFEST"; then
    pass "the name is fixed -- import looks for it by name"
  else
    fail "wrong name accepted"
  fi
  printf '"$ELEBAKE_ARCHIVE_BASE"/ghost/file\n' >> "$coll"
  if run_elebake manifest "$coll" "$man" 2>&1 | grep -q "neither file nor symlink"; then
    pass "an unreadable entry fails the manifest instead of shortening it"
  else
    fail "short manifest accepted"
  fi
}

test_manifest_verify_and_bundle_pairing() {
  test_header "manifest verify: signature and tree, both at generation time"
  test_setup
  command -v gpg > /dev/null 2>&1 || { pass "gpg absent -- signing checks skipped"; return 0; }
  run_elebake stage add m2 > /dev/null 2>&1
  mkdir -p "$TEST_DIR/stage/m2/boot"
  printf 'E\n' > "$TEST_DIR/stage/m2/boot/loader.efi"
  local coll="$TEST_DIR/export/collection"
  mkdir -p "$TEST_DIR/export"
  run_elebake stage collect m2 > "$coll"
  local man="$TEST_DIR/export/MANIFEST"
  run_elebake manifest "$coll" "$man" > /dev/null 2>&1

  unit_attest_key unit-attest || return 0
  local out; out=$(run_elebake manifest verify "$man" "$TEST_DIR" unit-attest 2>&1)
  if printf '%s\n' "$out" | grep -q "unsigned"; then
    pass "an unsigned manifest is refused -- it proves nothing about its origin"
  else
    fail "unsigned manifest accepted: $out"
  fi

  run_elebake manifest attest "$coll" unit-attest > /dev/null 2>&1
  if [ -f "$man.asc" ]; then
    pass "manifest attest writes the manifest and its detached signature beside the collection"
  else
    fail "no signature produced"
  fi

  if run_elebake manifest verify "$man" "$TEST_DIR" unit-attest 2>&1 | grep -q "tree matches"; then
    pass "a good pair verifies against the PINNED signer"
  else
    fail "good pair rejected: $(run_elebake manifest verify "$man" "$TEST_DIR" unit-attest 2>&1)"
  fi

  run_elebake openpgp add stranger 0123456789ABCDEF0123456789ABCDEF01234567 "$UNIT_GNUPGHOME" > /dev/null 2>&1
  out=$(run_elebake manifest verify "$man" "$TEST_DIR" stranger 2>&1)
  if printf '%s\n' "$out" | grep -q "DIFFERENT key"; then
    pass "a good signature by a key other than the pinned one is refused"
  else
    fail "foreign signer accepted: $out"
  fi
  run_elebake openpgp add shortpin DEADBEEF "$UNIT_GNUPGHOME" > /dev/null 2>&1
  if run_elebake manifest verify "$man" "$TEST_DIR" shortpin 2>&1 | grep -q "too short"; then
    pass "a short key id is refused as a pin"
  else
    fail "short pin accepted"
  fi

  printf 'EVIL\n' > "$TEST_DIR/stage/m2/boot/loader.efi"
  out=$(run_elebake manifest verify "$man" "$TEST_DIR" unit-attest 2>&1)
  local vrc; ELEBAKE_BASE="$TEST_DIR" "$TEST_SCRIPT" manifest verify "$man" "$TEST_DIR" unit-attest > /dev/null 2>&1; vrc=$?
  if printf '%s\n' "$out" | grep -q "CHANGED.*loader.efi" && [ "$vrc" -ne 0 ]; then
    pass "a changed payload file is named AND ends the command -- that is what stops import"
  else
    fail "tampering not detected (rc=$vrc): $out"
  fi
  printf 'E\n' > "$TEST_DIR/stage/m2/boot/loader.efi"

  run_elebake setenv ELEBAKE_INTERPRETER_bundle_pack cat > /dev/null
  out=$(run_elebake bundle "$coll" "$TEST_BASE_DIR/bundle/m2.tar.gz" 2>&1)
  if printf '%s\n' "$out" | grep -q '^export/MANIFEST$' \
     && printf '%s\n' "$out" | grep -q '^export/MANIFEST.asc$'; then
    pass "bundle packs the pair alongside the payload"
  else
    fail "manifest pair not bundled: $out"
  fi
  rm -f "$man.asc"
  if run_elebake bundle "$coll" "$TEST_BASE_DIR/bundle/m2.tar.gz" 2>&1 | grep -q "no MANIFEST + MANIFEST.asc"; then
    pass "a bundle without tamper detection is not produced"
  else
    fail "unsigned bundle produced"
  fi
}

test_seal_attest_restore_admissibility() {
  test_header "seal/attest/restore: pinned signer, sealed pair, serial floor"
  test_setup
  unit_attest_key unit-attest || return 0
  local d="$TEST_BASE_DIR/adm-$TESTS_RUN.sh" b="$TEST_BASE_DIR/adm-$TESTS_RUN.tar.gz"
  printf 'PAYLOAD\n' > "$b"
  { printf '# elebake database dump\n# Version: 2\n# Serial: 3\n# Strategy: complete\n'
    printf '%s\n' '"$ELEBAKE_CONTEXT_SCRIPT" setenv ELEBAKE_UNIT_ADM yes'; } > "$d"
  local out
  out=$(run_elebake restore "$d" 2>&1)
  if printf '%s\n' "$out" | grep -q "unsigned"; then
    pass "restore refuses an unsigned dump"
  else
    fail "unsigned dump replayed: $out"
  fi
  run_elebake seal "$d" "$b" > /dev/null 2>&1
  if grep -q "^# Bundle: sha256=$(sha256 -q "$b") bytes=8$" "$d"; then
    pass "seal appends the bundle's sha256 and size to the dump"
  else
    fail "seal line wrong: $(grep Bundle "$d")"
  fi
  if run_elebake seal "$d" "$b" 2>&1 | grep -q "already sealed"; then
    pass "a dump names ONE bundle"
  else
    fail "double seal accepted"
  fi
  run_elebake attest "$d" unit-attest > /dev/null 2>&1
  [ -f "$d.asc" ] && pass "attest signs the dump" || fail "no dump signature"
  local late="$TEST_BASE_DIR/late-$TESTS_RUN.sh"
  printf '# elebake database dump\n# Version: 2\n# Serial: 1\n' > "$late"
  run_elebake attest "$late" unit-attest > /dev/null 2>&1
  if run_elebake seal "$late" "$b" 2>&1 | grep -q "already attested"; then
    pass "sealing after signing is refused (it would invalidate the signature)"
  else
    fail "seal after attest accepted"
  fi
  if run_elebake attest verify "$d" unit-attest 2>&1 | grep -q "signed by $UNIT_FPR"; then
    pass "attest verify names the pinned signer"
  else
    fail "attest verify failed: $(run_elebake attest verify "$d" unit-attest 2>&1)"
  fi
  if run_elebake seal verify "$d" "$b" 2>&1 | grep -q "is the bundle"; then
    pass "seal verify accepts the sealed bundle"
  else
    fail "seal verify rejected the right bundle"
  fi
  printf 'x' >> "$b"
  if run_elebake seal verify "$d" "$b" 2>&1 | grep -q "MISMATCHED PAIR"; then
    pass "seal verify refuses a bundle the dump does not name"
  else
    fail "foreign bundle accepted"
  fi
  run_elebake restore "$d" > /dev/null 2>&1
  if [ "$(head -1 "$TEST_DIR/.env/local/ELEBAKE_UNIT_ADM" 2>/dev/null)" = "yes" ]; then
    pass "a signed, pinned dump replays"
  else
    fail "signed dump did not replay"
  fi
  run_elebake provenance add "$d" - > /dev/null 2>&1
  local rec; rec=$(ls "$TEST_DIR/provenance" 2>/dev/null | head -1)
  if [ -n "$rec" ] && [ "$(cat "$TEST_DIR/provenance/$rec/serial")" = 3 ] \
     && [ "$(cat "$TEST_DIR/provenance/$rec/signer")" = "$UNIT_FPR" ] \
     && [ "$(cat "$TEST_DIR/provenance/$rec/bundle")" = "-" ]; then
    pass "provenance add files the receipt (serial, pinned signer, no bundle)"
  else
    fail "receipt wrong: $rec $(cat "$TEST_DIR/provenance/$rec"/* 2>/dev/null | tr '\n' ' ')"
  fi
  if [ "$(cat "$TEST_DIR/export/serial" 2>/dev/null)" = 3 ]; then
    pass "the import raised the export serial to the imported one (lineage continues)"
  else
    fail "export serial not raised: $(cat "$TEST_DIR/export/serial" 2>/dev/null)"
  fi
  if run_elebake provenance list 2>&1 | grep -q "^#  *3  .*$(printf '%s' "$UNIT_FPR" | cut -c25-)"; then
    pass "provenance list shows the receipt"
  else
    fail "provenance list wrong: $(run_elebake provenance list 2>&1)"
  fi
  local old="$TEST_BASE_DIR/old-$TESTS_RUN.sh"
  UNIT_SERIAL=2 unit_signed_dump "$old" '"$ELEBAKE_CONTEXT_SCRIPT" setenv ELEBAKE_UNIT_OLD yes'
  out=$(run_elebake restore "$old" 2>&1)
  if printf '%s\n' "$out" | grep -q "DOWNGRADE" && [ ! -f "$TEST_DIR/.env/local/ELEBAKE_UNIT_OLD" ]; then
    pass "a validly signed OLDER dump is refused (serial below the signer's floor)"
  else
    fail "downgrade replayed: $out"
  fi
  UNIT_SERIAL=3 unit_signed_dump "$old" '"$ELEBAKE_CONTEXT_SCRIPT" setenv ELEBAKE_UNIT_SAME yes'
  run_elebake restore "$old" > /dev/null 2>&1
  if [ -f "$TEST_DIR/.env/local/ELEBAKE_UNIT_SAME" ]; then
    pass "the same serial replays again (idempotent re-restore)"
  else
    fail "equal serial refused"
  fi
  local v1="$TEST_BASE_DIR/v1-$TESTS_RUN.sh"
  printf '# elebake database dump\n# Version: 1\n' > "$v1"
  run_elebake attest "$v1" unit-attest > /dev/null 2>&1
  if run_elebake restore "$v1" 2>&1 | grep -q "format 1 not admissible"; then
    pass "a Version-1 dump is refused (no serial, no seal -- re-export)"
  else
    fail "legacy dump accepted"
  fi
}

test_backup_records_and_rollback() {
  test_header "stage backup: records with label/description; rollback saves the suspect first"
  test_setup
  run_elebake stage add unitb > /dev/null 2>&1
  run_elebake stage device unitb a /dev/null /mnt > /dev/null 2>&1
  local d="$TEST_DIR/stage/unitb"
  mkdir -p "$d/backup/a/known-good" "$d/backup/a/older"
  printf 'GOOD\n' > "$d/backup/a/known-good/loader.efi"; sha256 -q "$d/backup/a/known-good/loader.efi" > "$d/backup/a/known-good/sha256"
  printf '2026-08-25T10:00:00Z\n' > "$d/backup/a/known-good/created"; printf 'booted silently\n' > "$d/backup/a/known-good/description"
  printf 'OLD\n' > "$d/backup/a/older/loader.efi"; sha256 -q "$d/backup/a/older/loader.efi" > "$d/backup/a/older/sha256"
  printf '2026-01-01T00:00:00Z\n' > "$d/backup/a/older/created"; printf 'first deploy\n' > "$d/backup/a/older/description"
  local out; out=$(run_elebake stage backup list unitb a)
  if printf '%s\n' "$out" | grep -n "older\|known-good" | grep -q "^[0-9]*:.*older" \
     && printf '%s\n' "$out" | grep "known-good" | grep -q "booted silently"; then
    pass "backup list shows label, created, hash and description, oldest first"
  else
    fail "backup list wrong: $out"
  fi
  run_elebake setenv ELEBAKE_INTERPRETER_stage_backup2 cat > /dev/null
  run_elebake setenv ELEBAKE_INTERPRETER_stage_backup3 cat > /dev/null
  out=$(run_elebake stage backup unitb a)
  if printf '%s\n' "$out" | grep -q "stage backup 'unitb' 'a' '[0-9]*T[0-9]*Z'$"; then
    pass "the 2-arg form delegates with the UTC stamp as label"
  else
    fail "2-arg delegation wrong: $out"
  fi
  out=$(run_elebake stage backup unitb a mylabel)
  if printf '%s\n' "$out" | grep -q "stage backup 'unitb' 'a' 'mylabel' 'loader found on medium a of stage unitb"; then
    pass "the 3-arg form delegates with a speaking default description"
  else
    fail "3-arg delegation wrong: $out"
  fi
  out=$(run_elebake stage backup unitb a mylabel "it's the one before the p3 kernel")
  if printf '%s\n' "$out" | grep -q "backup/a/mylabel/description" \
     && printf '%s\n' "$out" | grep -q "backup/a/mylabel/sha256" \
     && printf '%s\n' "$out" | grep -q "s the one before the p3 kernel"; then
    pass "the full form emits the record write (loader.efi, description with quote, sha256, created, source, by)"
  else
    fail "record emission wrong: $out"
  fi
  if run_elebake stage backup unitb a known-good 'again' 2>&1 | grep -q "exists (immutable"; then
    pass "a label is unique per medium -- immutable"
  else
    fail "duplicate label accepted"
  fi
  if run_elebake stage backup unitb a 'bad label' 'x' 2>&1 | grep -q "invalid label"; then
    pass "a label is a record name"
  else
    fail "bad label accepted"
  fi
  run_elebake setenv ELEBAKE_INTERPRETER_stage_rollback3 cat > /dev/null
  out=$(run_elebake stage rollback unitb a)
  if printf '%s\n' "$out" | grep -q "stage backup 'unitb' 'a' 'suspect-[0-9T]*Z' 'loader found on medium a before rollback to " \
     && printf '%s\n' "$out" | grep -q "stage rollback apply 'unitb' 'a' 'known-good'"; then
    pass "rollback resolves the NEWEST record and saves the suspect BEFORE applying"
  else
    fail "rollback batch wrong: $out"
  fi
  out=$(run_elebake stage rollback apply unitb a older)
  if printf '%s\n' "$out" | grep -q "backup/a/older/loader.efi" && printf '%s\n' "$out" | grep -q "first deploy"; then
    pass "rollback apply writes the named record's loader and shows its description"
  else
    fail "rollback apply wrong: $out"
  fi
  printf 'TAMPERED\n' > "$d/backup/a/older/loader.efi"
  if run_elebake stage rollback apply unitb a older 2>&1 | grep -q "CORRUPT"; then
    pass "a record whose loader no longer matches its sha256 is never put on a medium"
  else
    fail "corrupt record accepted"
  fi
}

test_stage_dump_minimized() {
  test_header "stage dump minimized: binary management only"
  test_setup
  run_elebake stage add unitm > /dev/null 2>&1
  local d="$TEST_DIR/stage/unitm"
  mkdir -p "$d/boot/kernel" "$d/boot/lua" "$d/marker" "$d/backup/a/x" "$d/phases"
  printf 'L' > "$d/boot/loader.efi"; printf 'K' > "$d/boot/kernel/kernel"; printf 'M' > "$d/boot/kernel/if_x.ko"
  printf 'lua' > "$d/boot/lua/loader.lua"; printf 'c' > "$d/boot/loader.conf"; printf 'Boot0001' > "$d/marker/bootvar"
  printf 'B' > "$d/backup/a/x/loader.efi"; printf 'p1' > "$d/phases/loaderconf"
  local out; out=$(run_elebake stage dump minimized unitm)
  if printf '%s\n' "$out" | grep -q "boot/kernel/if_x.ko" && printf '%s\n' "$out" | grep -q "boot/loader.conf" \
     && printf '%s\n' "$out" | grep -q "'backup/a/x' " && ! printf '%s\n' "$out" | grep -q "lua" \
     && ! printf '%s\n' "$out" | grep -q "marker" && ! printf '%s\n' "$out" | grep -q "phase policy" \
     && ! printf '%s\n' "$out" | grep -q "stage build"; then
    pass "minimized: loader, loader.conf, kernel/, backups -- no lua, marker, phases, rebuild"
  else
    fail "minimized dump wrong: $out"
  fi
  local dl fl
  dl=$(printf '%s\n' "$out" | grep -n "stage import 'unitm' 'boot/kernel'$" | head -1 | cut -d: -f1)
  fl=$(printf '%s\n' "$out" | grep -n "stage import 'unitm' 'boot/kernel' " | head -1 | cut -d: -f1)
  if [ -n "$dl" ] && [ -n "$fl" ] && [ "$dl" -lt "$fl" ]; then
    pass "minimized declares boot/kernel before its files"
  else
    fail "minimized structure order wrong (d=$dl f=$fl)"
  fi
  out=$(run_elebake dump minimized)
  if printf '%s\n' "$out" | grep -q "^# Strategy: minimized$" && printf '%s\n' "$out" | grep -q "stage 'unitm' (minimized)" \
     && ! printf '%s\n' "$out" | grep -q "foundation arsenal"; then
    pass "dump minimized: strategy in the header, no foundation"
  else
    fail "dump minimized wrong"
  fi
  if run_elebake dump bogus 2>&1 | grep -q "unknown strategy"; then
    pass "an unknown dump strategy fails early"
  else
    fail "bogus strategy accepted"
  fi
}

test_destroy_removes_everything() {
  test_header "destroy: named confirmation, worktree deregistration, nothing left"
  test_setup
  if run_elebake destroy wrongname 2>&1 | grep -q "does not match this database"; then
    pass "a wrong name is refused -- naming the database IS the confirmation"
  else
    fail "wrong name accepted"
  fi
  local src="$TEST_BASE_DIR/destroy-src-$TESTS_RUN"
  mkdir -p "$src"
  (cd "$src" && git init -q . && git config user.email t@t && git config user.name t \
     && echo x > f && git add f && git commit -qm init) > /dev/null 2>&1
  run_elebake setenv ELEBAKE_FREEBSD_SRC "$src" > /dev/null
  run_elebake stage add dstage > /dev/null 2>&1
  run_elebake stage checkout dstage HEAD 2>/dev/null | sh > /dev/null 2>&1
  local wt; wt=$(readlink "$TEST_DIR/.staging"/*/work 2>/dev/null)
  if [ -n "$wt" ] && [ -d "$wt" ] && git -C "$src" worktree list | grep -q "$wt"; then
    pass "fixture has a registered worktree"
  else
    fail "worktree fixture failed: $wt"
  fi
  mkdir -p "$TEST_BASE_DIR/bundle" && : > "$TEST_BASE_DIR/bundle/handover.tar.gz"
  local out; out=$(run_elebake destroy "test-$TESTS_RUN" 2>&1)
  if printf '%s\n' "$out" | grep -q "gone for good" \
     && printf '%s\n' "$out" | grep -q "worktree remove --force" \
     && printf '%s\n' "$out" | grep -q "rm -rf '$TEST_BASE_DIR/bundle'"; then
    pass "emission warns and covers records, worktrees and the bundle handover area"
  else
    fail "destroy emission incomplete: $out"
  fi
  printf '%s\n' "$out" | sh > /dev/null 2>&1
  if [ ! -d "$TEST_DIR" ] && [ ! -d "$TEST_BASE_DIR/bundle" ] && [ ! -d "$wt" ]; then
    pass "database, bundle area and worktree are gone"
  else
    fail "leftovers: $(ls -A "$TEST_BASE_DIR" 2>&1 | tr '\n' ' ')"
  fi
  if ! git -C "$src" worktree list | grep -q "$wt"; then
    pass "the source repo no longer registers the worktree"
  else
    fail "stale worktree registration survives"
  fi
}

test_stage_prerequisites_lists() {
  test_header "per-stage prerequisites lists: add/drop/show, stdin, alias, dump"
  test_setup
  run_elebake stage add unitq > /dev/null 2>&1
  run_elebake stage prerequisites verify add unitq /boot/loader.conf > /dev/null
  run_elebake stage prerequisites verify add unitq /boot/loader.efi.signed > /dev/null
  if run_elebake stage prerequisites verify show unitq | grep -q "/boot/loader.efi.signed"; then
    pass "verify list stores and shows absolute paths"
  else
    fail "verify list wrong: $(run_elebake stage prerequisites verify show unitq)"
  fi
  if run_elebake stage prerequisites exist add unitq relative/path 2>&1 | grep -q "invalid path"; then
    pass "relative path fails early (absolute bootfs paths only)"
  else
    fail "relative path accepted"
  fi
  printf '/boot/device.hints\n/boot/lua/loader.lua\n' | run_elebake stage prerequisites exist add unitq - > /dev/null
  if [ "$(grep -c . "$TEST_DIR/.staging/$(basename "$(readlink "$TEST_DIR/stage/unitq")")/prereqs/exist" 2>/dev/null)" = "2" ]; then
    pass "add - reads paths from stdin at generation time"
  else
    fail "stdin add wrong"
  fi
  if run_elebake stage prereqs exist show unitq | grep -q "device.hints"; then
    pass "prereqs alias combinator re-invokes the long form"
  else
    fail "alias broken: $(run_elebake stage prereqs exist show unitq 2>&1)"
  fi
  run_elebake stage prerequisites exist drop unitq /boot/device.hints > /dev/null
  if run_elebake stage prerequisites exist show unitq | grep -q "device.hints"; then
    fail "drop left the entry"
  else
    pass "drop removes the entry"
  fi
  if run_elebake stage dump unitq | grep -q "stage prerequisites add 'unitq' 'verify' '/boot/loader.efi.signed'"; then
    pass "stage dump replays the lists"
  else
    fail "dump replay missing"
  fi
}

test_stage_baseline_records() {
  test_header "stage baseline: add/show/drop/learn, immutability, site mk rendering, dump"
  test_setup
  run_elebake stage add unitbl > /dev/null 2>&1
  run_elebake stage baseline add unitbl LOADER_TRUST_TIME_BOOT_MAX_MS int 90000 > /dev/null
  run_elebake stage baseline add unitbl LOADER_TRUST_BOOTLOCK_SECRET string 9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08 > /dev/null
  run_elebake stage baseline add unitbl LOADER_TRUST_IMAGES_DIGEST digest 9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08 > /dev/null
  local sid; sid=$(basename "$(readlink "$TEST_DIR/stage/unitbl")")
  if [ "$(cat "$TEST_DIR/.staging/$sid/baselines/LOADER_TRUST_TIME_BOOT_MAX_MS")" = "int 90000" ]; then
    pass "baseline add stores '<type> <value>'"
  else
    fail "baseline record wrong: $(ls -R "$TEST_DIR/.staging/$sid" 2>&1)"
  fi
  if run_elebake stage baseline add unitbl LOADER_TRUST_TIME_BOOT_MAX_MS int 90000 | grep -q "unchanged"; then
    pass "identical re-add is a no-op"
  else
    fail "identical re-add not idempotent"
  fi
  if run_elebake stage baseline add unitbl LOADER_TRUST_TIME_BOOT_MAX_MS int 1 | grep -q "immutable"; then
    pass "differing re-add is refused"
  else
    fail "differing re-add accepted"
  fi
  if run_elebake stage baseline add unitbl FOO int 1 | grep -q "LOADER_TRUST_<NAME>" \
     && run_elebake stage baseline add unitbl LOADER_TRUST_X digest abc | grep -q "does not fit" \
     && run_elebake stage baseline add unitbl LOADER_TRUST_Y int 1x | grep -q "does not fit"; then
    pass "macro name and typed values are validated"
  else
    fail "validation gap"
  fi
  local mk; mk=$(run_elebake stage site mk baselines unitbl)
  if printf '%s\n' "$mk" | grep -q '^CFLAGS+= -DLOADER_TRUST_TIME_BOOT_MAX_MS=90000$' \
     && printf '%s\n' "$mk" | grep -q '^CFLAGS+= -DLOADER_TRUST_BOOTLOCK_SECRET=\\"9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08\\"$' \
     && printf '%s\n' "$mk" | grep -q "^CFLAGS+= -DLOADER_TRUST_IMAGES_DIGEST='0x9f,0x86,"; then
    pass "site mk baselines renders int bare, string as C string, digest as byte list"
  else
    fail "site mk baselines rendering: $mk"
  fi
  if run_elebake stage baseline show unitbl | grep -q "LOADER_TRUST_IMAGES_DIGEST (digest)"; then
    pass "baseline show lists the records"
  else
    fail "baseline show: $(run_elebake stage baseline show unitbl)"
  fi
  if run_elebake stage dump unitbl | grep -q "stage baseline add 'unitbl' 'LOADER_TRUST_BOOTLOCK_SECRET' 'string' '9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08'"; then
    pass "stage dump replays the baselines"
  else
    fail "dump replay missing"
  fi
  if run_elebake stage baseline learn unitbl LOADER_TRUST_ACPI_DIGEST loader.trust.platform.acpi.sha256 | grep -q "not a published 64-hex digest"; then
    pass "baseline learn fails early when this machine published no such digest"
  else
    fail "learn accepted an unpublished value"
  fi
  run_elebake stage baseline drop unitbl LOADER_TRUST_TIME_BOOT_MAX_MS > /dev/null
  if [ ! -f "$TEST_DIR/.staging/$sid/baselines/LOADER_TRUST_TIME_BOOT_MAX_MS" ]; then
    pass "baseline drop removes the record"
  else
    fail "drop left the record"
  fi
}

test_stage_disks_records() {
  test_header "stage disks: add/show/drop, validation, dump; site mk disks silent without records"
  test_setup
  run_elebake stage add unitdk > /dev/null 2>&1
  if [ -z "$(run_elebake stage site mk disks unitdk)" ]; then
    pass "site mk disks prints nothing without a disks record"
  else
    fail "site mk disks printed without records: $(run_elebake stage site mk disks unitdk)"
  fi
  run_elebake stage disks add unitdk nda0p1 > /dev/null
  run_elebake stage disks add unitdk nda2p1 > /dev/null
  run_elebake stage disks add unitdk nda0p1 > /dev/null
  local sid; sid=$(basename "$(readlink "$TEST_DIR/stage/unitdk")")
  if [ "$(grep -c . "$TEST_DIR/.staging/$sid/disks")" = "2" ]; then
    pass "disks add is an idempotent append in order"
  else
    fail "disks record wrong: $(cat "$TEST_DIR/.staging/$sid/disks" 2>&1)"
  fi
  if run_elebake stage disks add unitdk bogus | grep -q "not a GPT partition name"; then
    pass "partition names are validated"
  else
    fail "bogus device accepted"
  fi
  if run_elebake stage disks show unitdk | grep -q "#   nda2p1"; then
    pass "disks show lists the partitions"
  else
    fail "disks show wrong"
  fi
  if run_elebake stage dump unitdk | grep -q "stage disks add 'unitdk' 'nda2p1'"; then
    pass "stage dump replays the disks"
  else
    fail "dump replay missing"
  fi
  run_elebake stage disks drop unitdk nda0p1 > /dev/null
  if run_elebake stage disks show unitdk | grep -q nda0p1; then
    fail "drop left the entry"
  else
    pass "disks drop removes the entry"
  fi
  # render hygiene: a part that cannot measure says so on stderr, never on stdout
  # run_elebake merges the streams; here the two streams ARE the assertion
  run_elebake setintp stage_site_mk_origin sh > /dev/null
  local oo oe; oo=$(ELEBAKE_BASE="$TEST_DIR" "$TEST_SCRIPT" stage site mk origin unitdk 2>/dev/null); oe=$(ELEBAKE_BASE="$TEST_DIR" "$TEST_SCRIPT" stage site mk origin unitdk 2>&1 >/dev/null)
  if [ -z "$oo" ] && printf '%s\n' "$oe" | grep -q "LoadOrigin stays asleep"; then
    pass "site mk origin: unreadable origin is a stderr note, stdout stays empty (site.mk data only)"
  else
    fail "site mk origin hygiene: stdout='$oo' stderr='$oe'"
  fi
  local smk="$TEST_DIR/.staging/$sid/site.mk"
  run_elebake setintp stage_site_mk_place cat > /dev/null
  printf '# header\nCFLAGS.foundation.c += -DLOADER_TRUST_KEYS_DIGEST=1\nprintf %s bogus >&2\n' > "$smk.new"
  if run_elebake stage site mk install unitdk "$smk" 2>&1 | grep -q "neither comment nor CFLAGS"; then
    pass "site mk install refuses a render carrying a command line"
  else
    fail "site mk install accepted a poisoned render: $(run_elebake stage site mk install unitdk "$smk" 2>&1)"
  fi
  printf '# header\nCFLAGS.foundation.c += -DLOADER_TRUST_KEYS_DIGEST=1\n' > "$smk.new"
  if run_elebake stage site mk install unitdk "$smk" | grep -q "mv '$smk.new' '$smk'"; then
    pass "site mk install accepts a clean render"
  else
    fail "site mk install refused a clean render: $(run_elebake stage site mk install unitdk "$smk" 2>&1)"
  fi
}

test_stage_conf_require_loaderconf() {
  test_header "stage conf / require / loaderconf: bound actions demand keys, mk refuses, writes, check detects drift"
  test_setup
  run_elebake stage add unitcf > /dev/null 2>&1
  fixture_worktree unitcf
  local fix="$TEST_BASE_DIR/fix-work-$TESTS_RUN-unitcf/stand/efi/loader/local"
  printf 'extern const struct action\ttest_act;\nextern const struct action\task_act;\n' > "$fix/action.h"
  printf 'static void\naction_ask(const struct appraisal *a)\n{\n\tconst char *q = kenv(a, "question");\n\tconst char *r = kenv(a, "rescue");\n}\nstatic void\naction_test(const struct appraisal *a)\n{\n}\n' > "$fix/action.c"
  run_elebake expectation add e1 byte A 1 > /dev/null
  run_elebake claim add c1 measure_alpha - - e1 > /dev/null
  run_elebake gate add kernellock > /dev/null
  run_elebake gate claim add kernellock c1 > /dev/null
  run_elebake trigger add t-ask when_always ask_act > /dev/null
  run_elebake policy add p-ask kernellock > /dev/null
  run_elebake policy trigger add p-ask t-ask > /dev/null
  run_elebake stage phase policy add unitcf PHASE_TWO p-ask > /dev/null 2>&1
  local req; req=$(run_elebake stage require unitcf)
  if printf '%s\n' "$req" | grep -q "loader.trust.kernellock.question  (ask_act)  MISSING" \
     && printf '%s\n' "$req" | grep -q "loader.trust.kernellock.rescue  (ask_act)  MISSING"; then
    pass "require attributes the action's kenv leafs to the bound gate"
  else
    fail "require wrong: $req"
  fi
  local sid; sid=$(basename "$(readlink "$TEST_DIR/stage/unitcf")")
  mkdir -p "$TEST_DIR/.staging/$sid/boot"
  printf 'loader_conf_files="loader.conf.local loader.trust.conf"\n' > "$TEST_DIR/.staging/$sid/boot/loader.conf"
  if run_elebake stage loaderconf mk unitcf | grep -q "no value for loader.trust.kernellock.question"; then
    pass "loaderconf mk refuses while a required key has no value"
  else
    fail "mk did not refuse: $(run_elebake stage loaderconf mk unitcf)"
  fi
  run_elebake stage conf add unitcf loader.trust.kernellock.question "Lieblingsspielzeug:" > /dev/null
  run_elebake stage conf add unitcf loader.trust.kernellock.rescue zfs:zcard/ROOT/rescue > /dev/null
  if run_elebake stage conf add unitcf loader.trust.kernellock.question "anders" | grep -q "immutable" \
     && run_elebake stage conf add unitcf bad.key x | grep -q "loader.trust" \
     && run_elebake stage conf add unitcf loader.trust.k.v 'a"b' | grep -q "one loader.conf line"; then
    pass "conf add: immutable, key and value validated"
  else
    fail "conf validation gap: $(run_elebake stage conf add unitcf loader.trust.k.v 'a"b'; run_elebake stage conf add unitcf bad.key x)"
  fi
  run_elebake stage loaderconf mk unitcf > /dev/null
  if grep -q '^loader.trust.kernellock.question="Lieblingsspielzeug:"$' "$TEST_DIR/.staging/$sid/boot/loader.trust.conf" \
     && grep -q '^loader.trust.kernellock.rescue="zfs:zcard/ROOT/rescue"$' "$TEST_DIR/.staging/$sid/boot/loader.trust.conf"; then
    pass "loaderconf mk writes boot/loader.trust.conf from the records"
  else
    fail "loader.trust.conf wrong: $(cat "$TEST_DIR/.staging/$sid/boot/loader.trust.conf" 2>&1)"
  fi
  if run_elebake stage loaderconf check unitcf | grep -q "agrees with the records"; then
    pass "loaderconf check agrees right after mk"
  else
    fail "check disagrees: $(run_elebake stage loaderconf check unitcf)"
  fi
  printf 'loader.trust.kernellock.rescue="zfs:evil/ROOT"\n' >> "$TEST_DIR/.staging/$sid/boot/loader.trust.conf"
  if run_elebake stage loaderconf check unitcf | grep -q "DRIFT"; then
    pass "loaderconf check reports drift on the medium copy"
  else
    fail "drift not detected"
  fi
  if run_elebake stage dump unitcf | grep -q "stage conf add 'unitcf' 'loader.trust.kernellock.question' 'Lieblingsspielzeug:'"; then
    pass "stage dump replays the conf records"
  else
    fail "dump replay missing"
  fi
  printf 'x\n' > "$TEST_DIR/.staging/$sid/boot/loader.conf"
  if run_elebake stage loaderconf mk unitcf | grep -q "loader_conf_files"; then
    pass "loaderconf mk refuses while loader.conf does not name the file"
  else
    fail "mk accepted a loader.conf without loader_conf_files"
  fi
}

test_gate_duress_slot() {
  test_header "gate add: the duress slot renders, dumps, and is immutable"
  test_setup
  run_elebake gate add kl LOADER_TRUST_KL_SECRET LOADER_TRUST_KL_DURESS > /dev/null
  run_elebake gate add plain > /dev/null
  run_elebake gate add sec LOADER_TRUST_SEC_SECRET > /dev/null
  if run_elebake gate show kl | grep -q 'GATE_DEFINE(kl, KL_SECRET, KL_DURESS)' \
     && run_elebake gate show plain | grep -q 'GATE_DEFINE(plain, NULL, NULL)' \
     && run_elebake gate show sec | grep -q 'GATE_DEFINE(sec, SEC_SECRET, NULL)'; then
    pass "GATE_DEFINE renders secret and duress slots (NULL when absent)"
  else
    fail "gate show: $(run_elebake gate show kl; run_elebake gate show plain; run_elebake gate show sec)"
  fi
  if run_elebake gate add kl LOADER_TRUST_KL_SECRET LOADER_TRUST_KL_DURESS | grep -q "unchanged" \
     && run_elebake gate add kl LOADER_TRUST_KL_SECRET | grep -q "immutable"; then
    pass "identical re-add is a no-op, a changed slot set is refused"
  else
    fail "gate immutability gap"
  fi
  local d; d=$(run_elebake dump)
  if printf '%s\n' "$d" | grep -q "gate add 'kl' 'LOADER_TRUST_KL_SECRET' 'LOADER_TRUST_KL_DURESS'" \
     && printf '%s\n' "$d" | grep -q "gate add 'sec' 'LOADER_TRUST_SEC_SECRET' '-'$" \
     && printf '%s\n' "$d" | grep -q "gate add 'plain' '-' '-'$"; then
    pass "dump replays the slots exactly as recorded"
  else
    fail "dump: $(printf '%s\n' "$d" | grep 'gate add')"
  fi
}

# fixture_containers <stage> - shared helper: the loader headers of
# fixture_worktree plus minimal earlboot/elvbootd catalog sources
fixture_containers() {
  fixture_worktree "$1"
  local fix="$TEST_BASE_DIR/fix-work-$TESTS_RUN-$1/stand/efi/loader/local"
  printf 'extern const struct action\ttest_act;\nextern const struct action\thandover_act;\n' > "$fix/action.h"
  mkdir -p "$fix/earlboot" "$fix/elvbootd"
  printf 'earlboot.measure earlboot/measure.sh ^%%s() not in the earlboot catalog of this checkout\nearlboot.diagnose earlboot/measure.sh ^%%s() not in the earlboot catalog of this checkout\nearlboot.when earlboot/policy.sh ^%%s() not in the earlboot catalog of this checkout\nearlboot.action earlboot/action.sh ^%%s() not in the earlboot catalog of this checkout\nelvbootd.measure elvbootd/measure.sh ^%%s() not in the elvbootd catalog of this checkout\nelvbootd.measure earlboot/measure.sh ^%%s() not in the elvbootd catalog of this checkout\nelvbootd.diagnose elvbootd/measure.sh ^%%s() not in the elvbootd catalog of this checkout\nelvbootd.diagnose earlboot/measure.sh ^%%s() not in the elvbootd catalog of this checkout\nelvbootd.when elvbootd/policy.sh ^%%s() not in the elvbootd catalog of this checkout\nelvbootd.action elvbootd/action.sh ^%%s() not in the elvbootd catalog of this checkout\nelvbootd.action earlboot/action.sh ^%%s() not in the elvbootd catalog of this checkout\n' >> "$fix/catalog.tbl"
  printf '#!/bin/sh\nKENV=/bin/kenv # test:kenv\nMKDIR=/bin/mkdir\nSHUTDOWN=/sbin/shutdown # test:note\n' > "$fix/earlboot/tools.sh"
  printf '#!/bin/sh\nPHASES="SYSINIT MOUNTED"\nelv_word_check() { ELV_WORD_OK=1; ELV_TAINT=0; ELV_DURESS=0; ELV_PROMPTED=0; }\nelv_prologue() { elv_word_check; }\nwhen_always() { return 0; }\nwhen_fail() { [ "$GATE_VERDICT" = fail ]; }\n' > "$fix/earlboot/policy.sh"
  printf '#!/bin/sh\nmeasure_kenv() { $KENV -q "$1" 2>/dev/null; }\ndiagnose_kenv() { :; }\n# measure_word <gate> -- 1 iff the handover word verifies\nmeasure_word() { printf "%%s\\n" "$ELV_WORD_OK"; }\nmeasure_bootlock() { :; }\n' > "$fix/earlboot/measure.sh"
  printf '#!/bin/sh\nlog_act() { :; }\npersist_act() { $MKDIR -p "$ELV_STATE"; printf "gate=%%s verdict=%%s\\npassed=%%s\\nfailed=%%s\\n" "$1" "$GATE_VERDICT" "$PASSED" "$FAILED" > "$ELV_STATE/appraisal-$1"; }\n' > "$fix/earlboot/action.sh"
  printf '#!/bin/sh\nPHASES="STARTUP PERIODIC RESUME MEDIA"\nelv_flags_load() { :; }\nelv_prologue() { elv_flags_load; }\nwhen_always() { return 0; }\nwhen_fail() { [ "$GATE_VERDICT" = fail ]; }\n' > "$fix/elvbootd/policy.sh"
  printf '#!/bin/sh\nmeasure_media_serial() { :; }\n' > "$fix/elvbootd/measure.sh"
  printf '#!/bin/sh\nheartbeat_act() { :; }\nquarantine_act() { :; }\n' > "$fix/elvbootd/action.sh"
}

test_container_catalogs_and_binding() {
  test_header "containers: phases per container, catalogs, binding checks per container"
  test_setup
  run_elebake stage add unitco > /dev/null 2>&1
  fixture_containers unitco
  local ps; ps=$(run_elebake stage phase show unitco)
  if printf '%s\n' "$ps" | grep -q '\[loader\]' && printf '%s\n' "$ps" | grep -q '\[earlboot\]' \
     && printf '%s\n' "$ps" | grep -q '^#   SYSINIT' && printf '%s\n' "$ps" | grep -q '^#   MEDIA'; then
    pass "stage phase show lists every container with its phases"
  else
    fail "phase show: $ps"
  fi
  if run_elebake stage measure unitco earlboot | grep -q "measure_word" \
     && run_elebake stage measure unitco earlboot | grep -q "1 iff the handover word verifies" \
     && run_elebake stage measure unitco earlboot | grep -q "no description in the catalog source" \
     && run_elebake stage action unitco elvbootd | grep -q "container elvbootd: earlboot/action.sh" \
     && run_elebake stage when unitco elvbootd | grep -q "when_fail"; then
    pass "container catalogs are parsed from the sh sources (elvbootd inherits earlboot)"
  else
    fail "catalogs: $(run_elebake stage measure unitco earlboot; run_elebake stage action unitco elvbootd)"
  fi
  run_elebake expectation add clean string loader.trust.bootlock.failed "" > /dev/null
  run_elebake claim add clean measure_kenv diagnose_kenv - clean > /dev/null
  run_elebake gate add custody > /dev/null
  run_elebake gate claim add custody clean > /dev/null
  run_elebake trigger add log-always when_always log_act > /dev/null
  run_elebake policy add custody-watch custody > /dev/null
  run_elebake policy trigger add custody-watch log-always > /dev/null
  if run_elebake stage phase policy add unitco SYSINIT custody-watch 2>&1 | grep -q "bound to SYSINIT"; then
    pass "an earlboot chain binds to an earlboot phase"
  else
    fail "earlboot binding refused: $(run_elebake stage phase policy add unitco SYSINIT custody-watch 2>&1)"
  fi
  if run_elebake stage phase policy add unitco PHASE_ONE custody-watch 2>&1 | grep -q "not in the loader catalog"; then
    pass "the same chain is refused for a loader phase (measure_kenv is not C)"
  else
    fail "loader accepted an sh chain: $(run_elebake stage phase policy add unitco PHASE_ONE custody-watch 2>&1)"
  fi
  run_elebake expectation add e1 byte A 1 > /dev/null
  run_elebake claim add c1 measure_alpha - - e1 > /dev/null
  run_elebake gate add g1 > /dev/null
  run_elebake gate claim add g1 c1 > /dev/null
  run_elebake trigger add t1 when_always test_act > /dev/null
  run_elebake policy add p1 g1 > /dev/null
  run_elebake policy trigger add p1 t1 > /dev/null
  if run_elebake stage phase policy add unitco MOUNTED p1 2>&1 | grep -q "not in the earlboot catalog"; then
    pass "a loader chain is refused for an earlboot phase"
  else
    fail "earlboot accepted a C chain"
  fi
  run_elebake macro add BOARD_DIGEST sha256 BoardIdentity > /dev/null
  run_elebake expectation add bexp macro - BOARD_EXPECTED > /dev/null
  run_elebake claim add bclaim measure_kenv - - bexp > /dev/null
  run_elebake gate add bg > /dev/null
  run_elebake gate claim add bg bclaim > /dev/null
  run_elebake policy add bp bg > /dev/null
  if run_elebake stage phase policy add unitco SYSINIT bp 2>&1 | grep -q "macro expectations exist only in the loader"; then
    pass "macro expectations are refused outside the loader"
  else
    fail "macro expectation accepted in earlboot"
  fi
  if run_elebake stage foundation check unitco | grep -q "1 binding(s) across 1 phase(s)"; then
    pass "foundation check covers container phases"
  else
    fail "foundation check: $(run_elebake stage foundation check unitco)"
  fi
}

test_answer_family() {
  test_header "answer hash add / drop / show: one sentinel answer class as one batch"
  test_setup
  run_elebake stage add unitan > /dev/null 2>&1
  fixture_containers unitan
  local fix="$TEST_BASE_DIR/fix-work-$TESTS_RUN-unitan/stand/efi/loader/local"
  printf 'measure_answer() { /bin/kenv -q "loader.trust.$1.answer" 2>/dev/null; }\n' >> "$fix/earlboot/measure.sh"
  printf 'spool_act() { :; }\n' >> "$fix/earlboot/action.sh"
  printf 'when_pass() { [ "$GATE_VERDICT" = pass ]; }\n' >> "$fix/earlboot/policy.sh"
  run_elebake gate add tg > /dev/null
  run_elebake trigger add note-pass when_pass spool_act > /dev/null
  run_elebake trigger add log-pass when_pass log_act > /dev/null
  run_elebake policy add react-note tg > /dev/null
  run_elebake policy trigger add react-note log-pass > /dev/null
  run_elebake policy trigger add react-note note-pass > /dev/null
  local sid h; sid=$(basename "$(readlink "$TEST_DIR/stage/unitan")")
  h=$(printf '%s' saltword | sha256 -q)
  run_elebake answer hash add unitan SYSINIT kl fish-1 "$h" react-note > /dev/null 2>&1
  if [ "$(cat "$TEST_DIR/foundation/expectations/fish-1")" = "string kl $h" ] \
     && grep -q "^measure_answer " "$TEST_DIR/foundation/claims/fish-1" \
     && [ "$(cat "$TEST_DIR/foundation/gates/fish_1/claims")" = "fish-1" ] \
     && grep -q "^gate fish_1$" "$TEST_DIR/foundation/policies/fish-1" \
     && [ "$(sed -n 's/^trigger //p' "$TEST_DIR/foundation/policies/fish-1" | tr '\n' ' ')" = "log-pass note-pass " ] \
     && grep -qx "fish-1" "$TEST_DIR/.staging/$sid/phases/SYSINIT"; then
    pass "answer hash add rolls out expectation, claim, gate (fish_1), policy with the template's triggers, binding"
  else
    fail "answer hash add: $(ls -R "$TEST_DIR/foundation" 2>&1 | head -30)"
  fi
  if run_elebake answer show unitan | grep -q "fish-1 *SYSINIT *log-pass note-pass"; then
    pass "answer show lists the class with its phase and triggers"
  else
    fail "answer show: $(run_elebake answer show unitan 2>&1)"
  fi
  if run_elebake answer hash add unitan SYSINIT kl fish-2 deadbeef react-note 2>&1 | grep -q "64 lower-case hex"; then
    pass "a malformed hash is refused"
  else
    fail "malformed hash accepted"
  fi
  if run_elebake answer hash add unitan SYSINIT kl fish-2 "$h" no-such 2>&1 | grep -q "no such policy"; then
    pass "a missing template policy is refused"
  else
    fail "missing template accepted"
  fi
  if run_elebake stage earlboot mk unitan > /dev/null 2>&1 \
     && grep -q "^GATE='fish_1'" "$TEST_DIR/.staging/$sid/hooks/earlboot" \
     && grep -q "_m=\$(measure_answer 'kl' 2>/dev/null); _want='$h'" "$TEST_DIR/.staging/$sid/hooks/earlboot"; then
    pass "the class renders into the earlboot script with its salted hash as the want"
  else
    fail "earlboot render of the class: $(grep -n "fish_1\|measure_answer" "$TEST_DIR/.staging/$sid/hooks/earlboot" 2>&1 | head -4)"
  fi
  run_elebake answer drop unitan SYSINIT fish-1 > /dev/null 2>&1
  if [ ! -f "$TEST_DIR/foundation/expectations/fish-1" ] && [ ! -f "$TEST_DIR/foundation/claims/fish-1" ] \
     && [ ! -d "$TEST_DIR/foundation/gates/fish_1" ] && [ ! -f "$TEST_DIR/foundation/policies/fish-1" ] \
     && ! grep -qx "fish-1" "$TEST_DIR/.staging/$sid/phases/SYSINIT" 2>/dev/null; then
    pass "answer drop removes binding, policy, gate, claim and expectation"
  else
    fail "answer drop left: $(ls -R "$TEST_DIR/foundation" 2>&1 | grep fish; cat "$TEST_DIR/.staging/$sid/phases/SYSINIT" 2>&1)"
  fi
  printf 'measure_answer_matched() { printf "%%s\\n" "${ELV_ANSWER_MATCHED:-0}"; }\n' >> "$fix/earlboot/measure.sh"
  printf 'answer_matched_act() { ELV_ANSWER_MATCHED=1; }\nspool_act() { :; }\n' >> "$fix/earlboot/action.sh"
  run_elebake trigger add note-fail when_fail spool_act > /dev/null
  run_elebake policy add react-miss tg > /dev/null
  run_elebake policy trigger add react-miss note-fail > /dev/null
  run_elebake answer hash add unitan SYSINIT kl fish-1 "$h" react-note > /dev/null 2>&1
  run_elebake answer catchall add unitan SYSINIT kl fish-any react-miss > /dev/null 2>&1
  if [ "$(cat "$TEST_DIR/foundation/expectations/fish-any")" = "byte kl 1" ] \
     && grep -q "^measure_answer_matched " "$TEST_DIR/foundation/claims/fish-any" \
     && [ "$(sed -n 's/^trigger //p' "$TEST_DIR/foundation/policies/fish-any")" = "note-fail" ] \
     && [ "$(tail -1 "$TEST_DIR/.staging/$sid/phases/SYSINIT")" = "fish-any" ] \
     && run_elebake answer show unitan | grep -q "fish-any *SYSINIT *note-fail (catch-all)"; then
    pass "answer catchall add: byte 1 over measure_answer_matched, when_fail template, bound last, shown as catch-all"
  else
    fail "catchall: $(cat "$TEST_DIR/foundation/expectations/fish-any" "$TEST_DIR/foundation/claims/fish-any" 2>&1; run_elebake answer show unitan 2>&1)"
  fi
  run_elebake answer drop unitan SYSINIT fish-any > /dev/null 2>&1
  run_elebake answer drop unitan SYSINIT fish-1 > /dev/null 2>&1
  if run_elebake answer add unitan SYSINIT kl fish-3 react-note 2>&1 | grep -q "no salt"; then
    pass "answer add refuses without the stage's salt before touching the terminal"
  else
    fail "answer add without salt: $(run_elebake answer add unitan SYSINIT kl fish-3 react-note 2>&1 | head -2)"
  fi
  run_elebake stage conf add unitan loader.trust.kl.salt abc > /dev/null 2>&1
  local tf="$TEST_BASE_DIR/answers-$TESTS_RUN.txt"
  printf '# name template word\nfish-7  react-note  tuesday only\nfish-8  react-note\n' > "$tf"
  chmod 0644 "$tf"
  if run_elebake answer file add unitan SYSINIT kl "$tf" 2>&1 | grep -q "owner only"; then
    pass "answer file add refuses a table readable by others"
  else
    fail "world-readable table accepted"
  fi
  chmod 0600 "$tf"
  run_elebake answer file add unitan SYSINIT kl "$tf" > /dev/null 2>&1
  local h7 h8; h7=$(printf '%s' "abctuesday only" | sha256 -q); h8=$(printf '%s' abc | sha256 -q)
  if [ "$(cat "$TEST_DIR/foundation/expectations/fish-7")" = "string kl $h7" ] \
     && [ "$(cat "$TEST_DIR/foundation/expectations/fish-8")" = "string kl $h8" ] \
     && grep -qx "fish-7" "$TEST_DIR/.staging/$sid/phases/SYSINIT" && grep -qx "fish-8" "$TEST_DIR/.staging/$sid/phases/SYSINIT"; then
    pass "answer file add: the word is the rest of the line with its spaces, an absent word is the empty answer, salt from stage conf"
  else
    fail "answer file add: $(cat "$TEST_DIR/foundation/expectations/fish-7" "$TEST_DIR/foundation/expectations/fish-8" 2>&1)"
  fi
  run_elebake answer file drop unitan SYSINIT "$tf" > /dev/null 2>&1
  if [ ! -f "$TEST_DIR/foundation/expectations/fish-7" ] && [ ! -f "$TEST_DIR/foundation/policies/fish-8" ] \
     && ! grep -q "fish-" "$TEST_DIR/.staging/$sid/phases/SYSINIT" 2>/dev/null; then
    pass "answer file drop removes every class of the table"
  else
    fail "answer file drop left: $(ls "$TEST_DIR/foundation/expectations" "$TEST_DIR/foundation/policies" 2>&1 | grep fish)"
  fi
  rm -f "$tf"
}

test_container_test_run() {
  test_header "stage earlboot test: replay a captured kenv through the generated script with mocks"
  test_setup
  run_elebake stage add unitrt > /dev/null 2>&1
  fixture_containers unitrt
  run_elebake expectation add clean string loader.trust.bootlock.failed "" > /dev/null
  run_elebake claim add clean measure_kenv diagnose_kenv - clean > /dev/null
  run_elebake expectation add wordok byte kl 1 > /dev/null
  run_elebake claim add wordok measure_word - - wordok > /dev/null
  run_elebake expectation add ex string loader.trust.kl.x 42 > /dev/null
  run_elebake claim add cx measure_kenv - - ex > /dev/null
  run_elebake gate add custody > /dev/null
  for c in clean wordok cx; do run_elebake gate claim add custody $c > /dev/null; done
  run_elebake trigger add persist-always when_always persist_act > /dev/null
  run_elebake policy add custody-watch custody > /dev/null
  run_elebake policy trigger add custody-watch persist-always > /dev/null
  run_elebake stage phase policy add unitrt SYSINIT custody-watch > /dev/null 2>&1
  local dump="$TEST_BASE_DIR/dump-$TESTS_RUN.kenv"
  printf 'loader.trust.kl.x="42"\nloader.trust.bootlock.failed=""\n' > "$dump"
  local out sid; sid=$(basename "$(readlink "$TEST_DIR/stage/unitrt")")
  out=$(run_elebake stage earlboot test unitrt "$dump" 2>&1)
  if printf '%s\n' "$out" | grep -q "^== appraisal-custody" \
     && printf '%s\n' "$out" | grep -q "^gate=custody verdict=fail" \
     && printf '%s\n' "$out" | grep -q "^passed= wordok cx" \
     && printf '%s\n' "$out" | grep -q "^failed= clean" \
     && printf '%s\n' "$out" | grep -q "earlboot test run of unitrt: exit 0"; then
    pass "the replay measures from the dump (kenv mock), an empty publication fails, the appraisal is printed"
  else
    fail "earlboot test run: $out"
  fi
  if [ ! -d "$TEST_DIR/.staging/$sid/hooks/earlboot.test.state" ] && [ ! -f "$TEST_DIR/.staging/$sid/hooks/earlboot.test" ]; then
    pass "the run leaves nothing behind: no test state, no test script"
  else
    fail "leftovers: $(ls "$TEST_DIR/.staging/$sid/hooks/" 2>&1)"
  fi
  run_elebake stage earlboot mk unitrt > /dev/null 2>&1
  if grep -q "^readonly KENV='/bin/kenv'$" "$TEST_DIR/.staging/$sid/hooks/earlboot" \
     && grep -q "^readonly ELV_STATE='/var/db/elvboot'$" "$TEST_DIR/.staging/$sid/hooks/earlboot" \
     && ! grep -q "elv_mock" "$TEST_DIR/.staging/$sid/hooks/earlboot"; then
    pass "the real script carries the tools table as readonly absolute paths and no mock"
  else
    fail "real script constants: $(grep -n "readonly" "$TEST_DIR/.staging/$sid/hooks/earlboot" | head -12)"
  fi
  rm -f "$dump"
}

test_container_emitters() {
  test_header "earlboot mk / elvbootd mk: hardened scripts from the bindings, constants from the records, glue"
  test_setup
  run_elebake stage add unitem > /dev/null 2>&1
  fixture_containers unitem
  run_elebake expectation add clean string loader.trust.bootlock.failed "" > /dev/null
  run_elebake claim add clean measure_kenv diagnose_kenv - clean > /dev/null
  run_elebake expectation add wordok byte kl 1 > /dev/null
  run_elebake claim add wordok measure_word - - wordok > /dev/null
  run_elebake gate add custody > /dev/null
  run_elebake gate claim add custody clean > /dev/null
  run_elebake gate claim add custody wordok > /dev/null
  run_elebake trigger add log-always when_always log_act > /dev/null
  run_elebake trigger add persist-fail when_fail persist_act > /dev/null
  run_elebake policy add custody-watch custody > /dev/null
  run_elebake policy trigger add custody-watch log-always > /dev/null
  run_elebake policy trigger add custody-watch persist-fail > /dev/null
  run_elebake stage phase policy add unitem SYSINIT custody-watch > /dev/null 2>&1
  run_elebake expectation add e1 byte A 1 > /dev/null
  run_elebake claim add c1 measure_alpha - - e1 > /dev/null
  run_elebake gate add kl > /dev/null
  run_elebake gate claim add kl c1 > /dev/null
  run_elebake trigger add hand when_always handover_act > /dev/null
  run_elebake policy add kp kl > /dev/null
  run_elebake policy trigger add kp hand > /dev/null
  run_elebake stage phase policy add unitem PHASE_TWO kp > /dev/null 2>&1
  run_elebake stage baseline add unitem LOADER_TRUST_WORD_SECRET string 00112233445566778899aabbccddeeff > /dev/null
  run_elebake stage device unitem t /dev/testda9p1 /mnt > /dev/null 2>&1
  run_elebake stage earlboot mk unitem > /dev/null 2>&1
  local hk; hk="$TEST_DIR/.staging/$(basename "$(readlink "$TEST_DIR/stage/unitem")")/hooks"
  if grep -q "^readonly ELV_ESP='testda9p1'$" "$hk/earlboot"; then
    pass "ELV_ESP is the medium's node without /dev/ (the ESP partition, never node+p1)"
  else
    fail "ELV_ESP rendering: $(grep ELV_ESP "$hk/earlboot" 2>&1)"
  fi
  local sid; sid=$(basename "$(readlink "$TEST_DIR/stage/unitem")")
  local f="$TEST_DIR/.staging/$sid/hooks/earlboot"
  if [ -f "$f" ] && sh -n "$f" && grep -q '^# PROVIDE: earlboot' "$f" && grep -q '^PATH=.*readonly PATH' "$f" \
     && grep -q "^readonly ELV_WORD_SECRET='00112233445566778899aabbccddeeff'" "$f" \
     && grep -q "^readonly ELV_GATE_LOADER='kl'" "$f" \
     && grep -q '^# ===== phase SYSINIT' "$f" && grep -q "^_m=\$(measure_kenv 'loader.trust.bootlock.failed'" "$f" \
     && grep -q '^if when_fail; then persist_act "\$GATE"; fi' "$f" && grep -q '^exit 0' "$f"; then
    pass "earlboot mk writes a parsing, hardened rc.d script with constants, gate appraisal and bindings"
  else
    fail "earlboot script wrong: $(sed -n 1,30p "$f" 2>&1)"
  fi
  if [ "$(stat -f %Lp "$f")" = "500" ]; then
    pass "the generated script is 0500"
  else
    fail "mode: $(stat -f %Lp "$f")"
  fi
  run_elebake expectation add locked string mac_bootlock 1 > /dev/null
  run_elebake claim add locked measure_bootlock - - locked > /dev/null
  run_elebake gate add lockg > /dev/null
  run_elebake gate claim add lockg locked > /dev/null
  run_elebake policy add lock-watch lockg > /dev/null
  run_elebake policy trigger add lock-watch log-always > /dev/null
  run_elebake stage phase policy add unitem MOUNTED lock-watch > /dev/null 2>&1
  if run_elebake stage earlboot mk unitem 2>&1 | grep -q "demand.*mac_bootlock" \
     && run_elebake stage require unitem earlboot | grep -q "boot/kernel/mac_bootlock.ko  MISSING"; then
    pass "earlboot mk refuses while a bound measurement's demand on the boot tree is unmet (measure_bootlock)"
  else
    fail "require: $(run_elebake stage require unitem earlboot 2>&1; run_elebake stage earlboot mk unitem 2>&1 | tail -2)"
  fi
  mkdir -p "$TEST_DIR/.staging/$sid/boot/kernel"
  printf 'mac_bootlock_load="YES"\n' >> "$TEST_DIR/.staging/$sid/boot/loader.conf"
  : > "$TEST_DIR/.staging/$sid/boot/kernel/mac_bootlock.ko"
  run_elebake stage earlboot mk unitem > /dev/null 2>&1
  if [ "$(run_elebake stage require unitem earlboot | grep -c '  ok$')" = "2" ] \
     && grep -q '^# ===== phase MOUNTED' "$f" && grep -q "^_m=\$(measure_bootlock 'mac_bootlock'" "$f"; then
    pass "with loader.conf and the module in the boot tree, earlboot mk proceeds and MOUNTED appraises the lock"
  else
    fail "require after fix: $(run_elebake stage require unitem earlboot 2>&1; grep -c measure_bootlock "$f")"
  fi
  if run_elebake stage elvbootd mk unitem 2>&1 | grep -q "no runtime phase bound"; then
    pass "elvbootd mk refuses without a bound runtime phase"
  else
    fail "elvbootd mk did not refuse"
  fi
  run_elebake expectation add serial string da1 ABC > /dev/null
  run_elebake claim add serial measure_media_serial - - serial > /dev/null
  run_elebake gate add medium > /dev/null
  run_elebake gate claim add medium serial > /dev/null
  run_elebake trigger add q-fail when_fail quarantine_act > /dev/null
  run_elebake trigger add hb when_always heartbeat_act > /dev/null
  run_elebake policy add media-watch medium > /dev/null
  run_elebake policy trigger add media-watch q-fail > /dev/null
  run_elebake policy trigger add media-watch hb > /dev/null
  run_elebake stage phase policy add unitem MEDIA media-watch > /dev/null 2>&1
  run_elebake stage phase policy add unitem PERIODIC custody-watch > /dev/null 2>&1
  run_elebake stage phase policy add unitem STARTUP custody-watch > /dev/null 2>&1
  run_elebake stage elvbootd mk unitem > /dev/null 2>&1
  local h="$TEST_DIR/.staging/$sid/hooks"
  if [ -f "$h/hook.media.sh" ] && [ -f "$h/hook.periodic.sh" ] && [ -f "$h/hook.startup.sh" ] && [ ! -f "$h/hook.resume.sh" ] \
     && sh -n "$h/hook.media.sh" && grep -q '^# ===== phase MEDIA' "$h/hook.media.sh" \
     && grep -q "^_m=\$(measure_media_serial 'da1'" "$h/hook.media.sh" \
     && grep -q '^elv_prologue$' "$h/hook.media.sh" && grep -q '^log_act()' "$h/hook.periodic.sh"; then
    pass "elvbootd mk writes one hook per BOUND runtime phase, inheriting the earlboot palette"
  else
    fail "hooks wrong: $(ls "$h" 2>&1)"
  fi
  if grep -q 'match "cdev" "da\[0-9\]+"' "$h/elvboot.devd.conf" && grep -q 'hook.media.sh \$cdev' "$h/elvboot.devd.conf"; then
    pass "the devd glue for MEDIA is written"
  else
    fail "devd glue: $(cat "$h/elvboot.devd.conf" 2>&1)"
  fi
  if [ -f "$h/elvbootd" ] && sh -n "$h/elvbootd" && grep -q "^# PROVIDE: elvbootd$" "$h/elvbootd" \
     && grep -q "^start_cmd=\"/usr/local/etc/elvboot/hook.startup.sh\"$" "$h/elvbootd"; then
    pass "the rc.d glue for STARTUP is written"
  else
    fail "rc.d glue: $(cat "$h/elvbootd" 2>&1)"
  fi
  if [ "$(stat -f %Lp "$h/elvbootd")" = 500 ]; then
    pass "the rc.d glue lands in hooks/ with 0500 like the hooks"
  else
    fail "rc.d glue mode: $(stat -f %Lp "$h/elvbootd")"
  fi
  if run_elebake stage elvbootd mk unitem 2>&1 | grep -q "Permission denied"; then
    fail "a second elvbootd mk cannot overwrite the 0500 glue"
  elif [ -f "$h/elvbootd" ] && [ "$(stat -f %Lp "$h/elvbootd")" = 500 ] && [ ! -f "$h/elvbootd.new" ]; then
    pass "a second elvbootd mk replaces the glue via .new + mv"
  else
    fail "second mk left: $(ls -la "$h" 2>&1)"
  fi
  if run_elebake stage dump unitem | grep -q "hooks of unitem are generated"; then
    pass "the dump notes that hooks are regenerated, never replayed"
  else
    fail "dump hooks note missing"
  fi
  for pin in stage_earlboot_place stage_state_dir_mk stage_elvbootd_startup_place stage_elvbootd_periodic_place stage_elvbootd_resume_place stage_elvbootd_media_place; do
    run_elebake setenv ELEBAKE_INTERPRETER_$pin cat > /dev/null 2>&1
  done
  if run_elebake stage earlboot install unitem | grep -q "install -o root -g wheel -m 0500 '.*/hooks/earlboot' /etc/rc.d/earlboot" \
     && run_elebake stage elvbootd install unitem | grep -q "devd/elvboot.conf" \
     && run_elebake stage elvbootd install unitem | grep -q "install -o root -g wheel -m 0500 '.*/hooks/elvbootd' /usr/local/etc/rc.d/elvbootd"; then
    pass "install emits the root-side copies and glue (displayed here, sudo sh in the profile)"
  else
    fail "install emission: $(run_elebake stage earlboot install unitem)"
  fi
}

test_dispatch_wrong_arity() {
  test_header "dispatch: a known command path with the wrong argument count says so (not 'unknown', not swallowed)"
  test_setup
  if run_elebake stage build kernel 2>&1 | grep -q "wrong number of arguments for 'stage build kernel'" \
     && run_elebake stage build kernel 2>&1 | grep -q "elebake stage build kernel <stage>"; then
    pass "'stage build kernel' without the stage is a usage error, not a stage named kernel"
  else
    fail "stage build kernel: $(run_elebake stage build kernel 2>&1 | head -3)"
  fi
  if run_elebake stage filter uncurated unitem 2>&1 | grep -q "wrong number of arguments for 'stage filter uncurated'"; then
    pass "'stage filter uncurated <stage>' without the source dir names the command, not 'stage'"
  else
    fail "stage filter uncurated: $(run_elebake stage filter uncurated unitem 2>&1 | head -2)"
  fi
  if run_elebake stage nosuch 2>&1 | grep -q "unknown command: stage nosuch"; then
    pass "an unknown path is still unknown"
  else
    fail "unknown: $(run_elebake stage nosuch 2>&1 | head -2)"
  fi
  run_elebake stage add unitem > /dev/null 2>&1
  if run_elebake stage add unitem 2>&1 | grep -q "already"; then
    pass "a correct call still resolves (stage add)"
  else
    fail "stage add: $(run_elebake stage add unitem 2>&1 | head -2)"
  fi
}

test_filter_prune_orphans_only() {
  test_header "stage filter prune: removes what is neither curated nor generated, displays first"
  test_setup
  run_elebake stage add unitp > /dev/null 2>&1
  local sid; sid=$(basename "$(readlink "$TEST_DIR/stage/unitp")")
  local b="$TEST_DIR/.staging/$sid/boot"
  mkdir -p "$b/kernel" "$b/lua"
  : > "$b/kernel/kernel"; : > "$b/lua/loader.lua"; : > "$b/boot0"; : > "$b/loader.conf"
  : > "$b/loader.trust.conf"; : > "$b/manifest"; : > "$b/loader.efi.signed"
  run_elebake stage filter add unitp kernel > /dev/null
  run_elebake stage filter add unitp loader.conf > /dev/null
  run_elebake setenv ELEBAKE_INTERPRETER_stage_filter_prune_rm cat > /dev/null 2>&1   # the suite executes terminals; production displays
  local out; out=$(run_elebake stage filter prune unitp 2>&1)
  if printf '%s\n' "$out" | grep -q "rm -rf '$b/boot0'" && printf '%s\n' "$out" | grep -q "rm -rf '$b/lua'" \
     && ! printf '%s\n' "$out" | grep -q "rm -rf '$b/kernel'" && ! printf '%s\n' "$out" | grep -q "loader.conf'" \
     && ! printf '%s\n' "$out" | grep -q "loader.trust.conf\|manifest\|signed" \
     && [ -e "$b/boot0" ]; then
    pass "prune emits rm for the orphans only (curated, generated and manifest untouched) and does not act by itself"
  else
    fail "prune emission: $out"
  fi
  run_elebake stage filter prune unitp | sh 2>/dev/null
  if [ ! -e "$b/boot0" ] && [ ! -e "$b/lua" ] && [ -e "$b/kernel/kernel" ] && [ -e "$b/loader.conf" ] && [ -e "$b/loader.trust.conf" ]; then
    pass "piped to sh, the orphans are gone and the rest stays"
  else
    fail "after prune: $(ls "$b")"
  fi
  if run_elebake stage filter orphaned unitp | grep -q "(none)"; then
    pass "stage filter orphaned reports none afterwards"
  else
    fail "orphaned after prune: $(run_elebake stage filter orphaned unitp)"
  fi
}

test_filter_stdin_and_include_source() {
  test_header "filter add - (frozen snapshot) and include from a chosen source"
  test_setup
  run_elebake stage add units > /dev/null 2>&1
  local sid; sid=$(basename "$(readlink "$TEST_DIR/stage/units")")
  mkdir -p "$TEST_BASE_DIR/binsrc-$TESTS_RUN/lua"
  printf 'K\n' > "$TEST_BASE_DIR/binsrc-$TESTS_RUN/kernel.bin"
  printf 'L\n' > "$TEST_BASE_DIR/binsrc-$TESTS_RUN/lua/loader.lua"
  printf 'kernel.bin\nlua\n' | run_elebake stage filter add units - > /dev/null
  if [ "$(grep -c . "$TEST_DIR/.staging/$sid/filter")" = "2" ]; then
    pass "filter add - freezes an explicit snapshot from stdin"
  else
    fail "filter stdin wrong: $(cat "$TEST_DIR/.staging/$sid/filter" 2>&1)"
  fi
  run_elebake stage include units "$TEST_BASE_DIR/binsrc-$TESTS_RUN" > /dev/null 2>&1
  if [ -f "$TEST_DIR/.staging/$sid/boot/kernel.bin" ] && [ -f "$TEST_DIR/.staging/$sid/boot/lua/loader.lua" ]; then
    pass "include <srcdir> takes the SAME curation from a binary directory (variant b)"
  else
    fail "include from source failed: $(ls -R "$TEST_DIR/.staging/$sid/boot" 2>&1)"
  fi
  run_elebake stage include units "$TEST_BASE_DIR/binsrc-$TESTS_RUN" > /dev/null 2>&1
  if [ -f "$TEST_DIR/.staging/$sid/boot/lua/loader.lua" ]; then
    pass "re-include replaces directory entries (rm -rf, idempotent)"
  else
    fail "re-include broke the tree"
  fi
  printf 'X\n' > "$TEST_BASE_DIR/binsrc-$TESTS_RUN/uncurated.bin"
  printf 'O\n' > "$TEST_DIR/.staging/$sid/boot/orphan.bin"
  local out; out=$(run_elebake stage filter show units "$TEST_BASE_DIR/binsrc-$TESTS_RUN")
  if printf '%s\n' "$out" | grep -q "uncurated.bin" \
     && printf '%s\n' "$out" | grep -q "orphan.bin" \
     && printf '%s\n' "$out" | grep -q "kernel.bin"; then
    pass "filter show is ONE view: curated + uncurated-in-source + orphaned-in-boot"
  else
    fail "filter show delta wrong: $out"
  fi
  # the adopt rule: an entry the source does not deliver survives from boot/
  printf 'adopted\n' > "$TEST_DIR/.staging/$sid/boot/adopted.conf"
  run_elebake stage filter add units adopted.conf > /dev/null
  local inc; inc=$(run_elebake stage include units "$TEST_BASE_DIR/binsrc-$TESTS_RUN" 2>&1)
  if [ "$(cat "$TEST_DIR/.staging/$sid/boot/adopted.conf")" = "adopted" ] \
     && printf '%s\n' "$inc" | grep -q "adopted.conf kept from boot/" \
     && [ -f "$TEST_DIR/.staging/$sid/boot/kernel.bin" ]; then
    pass "include keeps an adopted entry from boot/ when the source lacks it, and still copies the rest"
  else
    fail "adopted entry not kept: $inc $(ls "$TEST_DIR/.staging/$sid/boot" 2>&1)"
  fi
  run_elebake stage filter add units ghost.bin > /dev/null
  if run_elebake stage include units "$TEST_BASE_DIR/binsrc-$TESTS_RUN" 2>&1 | grep -q "neither in .* nor in boot/: ghost.bin"; then
    pass "include refuses an entry absent from both source and boot/"
  else
    fail "ghost entry not refused: $(run_elebake stage include units "$TEST_BASE_DIR/binsrc-$TESTS_RUN" 2>&1)"
  fi
  run_elebake stage filter drop units ghost.bin > /dev/null
}

test_foundation_prereqs_arrays() {
  test_header "foundation.c emits the prerequisites arrays exactly when the checkout expects them"
  test_setup
  run_elebake stage add unita > /dev/null 2>&1
  fixture_worktree unita
  if run_elebake stage foundation render prerequisites unita | grep -q "prerequisites_exist"; then
    fail "arrays emitted although the checkout has no extern declarations"
  else
    pass "old checkout (no extern): no arrays — backwards compatible"
  fi
  printf 'extern const char *const	prerequisites_exist[];\nextern const char *const	prerequisites_verify[];\nextern const unsigned int	prerequisites_exist_n;\nextern const unsigned int	prerequisites_verify_n;\n' >> "$TEST_BASE_DIR/fix-work-$TESTS_RUN-unita/stand/efi/loader/local/measurement.h"
  run_elebake stage prerequisites verify add unita /boot/loader.conf > /dev/null
  run_elebake stage prerequisites verify add unita /boot/loader.efi.signed > /dev/null
  local out; out=$(run_elebake stage foundation render prerequisites unita)
  if printf '%s\n' "$out" | grep -q "#define	LOADER_PREREQUISITES_VERIFY_N	2" \
     && printf '%s\n' "$out" | grep -q '"/boot/loader.efi.signed",' \
     && printf '%s\n' "$out" | grep -q "#define	LOADER_PREREQUISITES_EXIST_N	0" \
     && printf '%s\n' "$out" | grep -q "prerequisites_exist_n = LOADER_PREREQUISITES_EXIST_N"; then
    pass "new checkout: N defines + arrays + _n variables from the stage lists (empty list legal, N=0)"
  else
    fail "array emission wrong: $out"
  fi
}

# parallel_main - as in the architecture suite
parallel_main() {
  local outdir rc=0 t
  outdir=$(mktemp -d "${TMPDIR:-/tmp}/elebake-unit-par.XXXXXX") || exit 1
  echo "${COLOR_BLUE}elebake Unit Test Suite (parallel, -P $MAXPROCS)${COLOR_RESET}"
  echo ""
  local tests
  if [ "$TEST_FILTER" = "$ALL_TESTS" ]; then
    # default run: the REAL test list are the should_run_test lines in main
    # (ALL_TESTS is the grep-derived filter BASE and also catches the
    # framework functions test_header/test_summary/test_setup)
    tests=$(grep -E '^[[:space:]]*should_run_test ' "$0" | awk '{print $2}')
  else
    tests="$TEST_FILTER"
  fi
  printf '%s\n' $tests | xargs -n1 -P "$MAXPROCS" -I{} \
    sh -c 'sh "$0" "$1" "$2" {} > "$3/{}.out" 2>&1; echo $? > "$3/{}.rc"' \
    "$0" "$TEST_PROFILE" "$KEEP_DATABASES" "$outdir"
  for t in $tests; do
    cat "$outdir/$t.out" 2>/dev/null
    [ "$(cat "$outdir/$t.rc" 2>/dev/null)" = "0" ] || rc=1
  done
  echo ""
  echo "========================================"
  echo "Aggregated Summary (parallel run)"
  echo "========================================"
  awk '
    /^Test Functions:/    { tf += $3 }
    /^Total Assertions:/  { ta += $3 }
    /^Passed Assertions:/ { pa += $3 }
    /^Failed Assertions:/ { fa += $3 }
    END {
      printf "Test Functions:     %d\n", tf
      printf "Total Assertions:   %d\n", ta
      printf "Passed Assertions:  %d\n", pa
      printf "Failed Assertions:  %d\n", fa
    }' "$outdir"/*.out
  if [ "$rc" -eq 0 ]; then
    echo ""; echo "ALL TESTS PASSED"; rm -rf "$outdir"
  else
    echo ""; echo "SOME TESTS FAILED"; echo "Per-test outputs preserved in: $outdir"
  fi
  return $rc
}

main() {
  if [ "$MAXPROCS" -gt 1 ]; then
    parallel_main
    return $?
  fi
  echo "${COLOR_BLUE}========================================${COLOR_RESET}"
  echo "${COLOR_BLUE}elebake Unit Test Suite${COLOR_RESET}"
  echo "${COLOR_BLUE}========================================${COLOR_RESET}"
  [ -f "$TEST_SCRIPT" ] || { echo "ERROR: $TEST_SCRIPT not found (run from the repository root)"; exit 1; }

  should_run_test test_bootstrap_layout
  should_run_test test_setenv_getenv_roundtrip
  should_run_test test_pem_add_and_dump
  should_run_test test_pem_dump_rebases_and_extras
  should_run_test test_openpgp_add_variants
  should_run_test test_backend_import_copies_file
  should_run_test test_stage_add_idempotent
  should_run_test test_stage_filter_roundtrip
  should_run_test test_stage_keybindings
  should_run_test test_stage_import_cascade
  should_run_test test_stage_dump_structure_first
  should_run_test test_dump_version_header
  should_run_test test_restore_keep_going
  should_run_test test_help_env_cascade
  should_run_test test_error_and_log
  should_run_test test_stage_add_validation
  should_run_test test_stage_device_and_boot_tree
  should_run_test test_stage_marker_emission_inspects_only
  should_run_test test_stage_tree_sync_is_a_batch_with_close
  should_run_test test_stage_loader_ingest
  should_run_test test_stage_unkey_and_attest
  should_run_test test_batch_fail_fast_default
  should_run_test test_batch_exit_survives_a_closed_pipe
  should_run_test test_getenv_layer_reporting
  should_run_test test_filter_and_import_path_validation
  should_run_test test_dump_marker_and_backup_blocks
  should_run_test test_stage_list_derived_state
  should_run_test test_freebsd_prerequisites_inspect
  should_run_test test_foundation_catalogs
  should_run_test test_foundation_expectation_crud
  should_run_test test_foundation_claim_trigger_crud
  should_run_test test_foundation_gate_policy_crud
  should_run_test test_foundation_immutability_idempotence
  should_run_test test_foundation_position
  should_run_test test_foundation_dangling_show
  should_run_test test_stage_phase_policy_binding
  should_run_test test_foundation_dump_replays
  should_run_test test_foundation_macro_crud
  should_run_test test_stage_foundation_emitter
  should_run_test test_stage_kernel_build_emissions
  should_run_test test_destroy_removes_everything
  should_run_test test_collect_speaks_archive_base
  should_run_test test_filter_strategies
  should_run_test test_manifest_covers_what_travels
  should_run_test test_manifest_verify_and_bundle_pairing
  should_run_test test_seal_attest_restore_admissibility
  should_run_test test_backup_records_and_rollback
  should_run_test test_stage_dump_minimized
  should_run_test test_stage_prerequisites_lists
  should_run_test test_filter_stdin_and_include_source
  should_run_test test_foundation_prereqs_arrays
  should_run_test test_stage_baseline_records
  should_run_test test_stage_disks_records
  should_run_test test_stage_conf_require_loaderconf
  should_run_test test_gate_duress_slot
  should_run_test test_container_catalogs_and_binding
  should_run_test test_container_emitters
  should_run_test test_container_test_run
  should_run_test test_answer_family
  should_run_test test_dispatch_wrong_arity
  should_run_test test_filter_prune_orphans_only

  test_summary
}

main
exit $?
