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

TEST_PROFILE="${1:-minimal}"
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
}

run_elebake() { ELEBAKE_BASE="$TEST_DIR" "$TEST_SCRIPT" "$@" 2>&1; }

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
  if [ -f "$TEST_DIR/.env/default/ELEBAKE_INTERPRETER_stage_dump_record" ]; then
    pass "profile installed the dump building-block pins"
  else
    fail "profile did not install ELEBAKE_INTERPRETER_stage_dump_record"
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
  if printf '%s\n' "$out" | grep -q "^# Version: 1\$"; then
    pass "dump header has '# Version: 1'"
  else
    fail "version line missing"
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
  cat > "$TEST_BASE_DIR/unit-restore.sh" <<'EOF'
"$ELEBAKE_CONTEXT_SCRIPT" setenv ELEBAKE_UNIT_A one
"$ELEBAKE_CONTEXT_SCRIPT" stage filter add ghost x
"$ELEBAKE_CONTEXT_SCRIPT" setenv ELEBAKE_UNIT_B two
EOF
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
  test_header "marker: record + guarded NVRAM emission, value stays runtime"
  test_setup
  run_elebake stage add unitn > /dev/null 2>&1
  run_elebake setenv ELEBAKE_INTERPRETER_stage_marker3 cat > /dev/null
  local out; out=$(run_elebake stage marker unitn Boot00AB /nonexistent/markerfile 2>&1)
  if printf '%s\n' "$out" | grep -q "echo 'Boot00AB' >"; then
    pass "emission records the boot variable"
  else
    fail "bootvar record line missing"
  fi
  if printf '%s\n' "$out" | grep -q "efivar"; then
    pass "NVRAM access stays a runtime emission (inspected, not executed)"
  else
    fail "no efivar emission found"
  fi
  if printf '%s\n' "$out" | grep -q "openssl rand"; then
    pass "marker VALUE is generated at runtime only"
  else
    fail "runtime value generation missing"
  fi
  if run_elebake stage marker unitn BadName /abs 2>&1 | grep -q "neither a load option"; then
    pass "malformed load option rejected"
  else
    fail "malformed load option not rejected"
  fi
  if run_elebake stage marker unitn Boot00AB relative/path 2>&1 | grep -q "must be absolute"; then
    pass "relative marker file rejected"
  else
    fail "relative marker file not rejected"
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
  printf 'struct measurement\tmeasure_alpha(int argc, CHAR16 *argv[]);\nvoid\tdiagnose_alpha(int argc, CHAR16 *argv[], struct diagnosis *);\n' > "$fix/measurement.h"
  printf 'bool\twhen_always(const struct appraisal *);\nenum phase {\n\tPHASE_ONE,\n\tPHASE_TWO,\n};\n' > "$fix/policy.h"
  printf 'extern const struct action\ttest_act;\n' > "$fix/action.h"
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
  if run_elebake gate add g1 OTHER_SLOT 2>&1 | grep -q "different secret slot"; then
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
  run_elebake claim add c1 measure_x - - ghost-exp > /dev/null
  if run_elebake claim show c1 | grep -q "undefined expectation: ghost-exp"; then
    pass "claim over a missing expectation shows the undefined marker"
  else
    fail "dangling expectation not marked"
  fi
  run_elebake gate add g1 > /dev/null
  run_elebake gate claim add g1 ghost-claim > /dev/null
  if run_elebake gate show g1 | grep -q "undefined claim: ghost-claim"; then
    pass "gate over a missing claim shows the undefined marker"
  else
    fail "dangling claim not marked"
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
  if run_elebake stage phase policy add unitb PHASE_ONE pbad 2>&1 | grep -q "not in this checkout's catalog"; then
    pass "unknown measurement fails the transitive check"
  else
    fail "bogus measurement accepted"
  fi
  run_elebake policy add pghost ghost-gate > /dev/null
  if run_elebake stage phase policy add unitb PHASE_ONE pghost 2>&1 | grep -q "undefined gate"; then
    pass "dangling gate fails at the binding"
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
gate add 'g1' 'SLOT_X'
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
  run_elebake macro drop ALPHA_DIGEST > /dev/null
  if run_elebake stage foundation check unite 2>&1 | grep -q "no macro record defines 'ALPHA_EXPECTED'"; then
    pass "check catches a dropped macro record (world drifted)"
  else
    fail "macro drift not caught: $(run_elebake stage foundation check unite 2>&1)"
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
  run_elebake setintp stage_build_kernel cat > /dev/null
  local out; out=$(run_elebake stage build kernel unitk)
  if printf '%s\n' "$out" | grep -q "buildkernel KERNCONF='GENERIC'" \
     && printf '%s\n' "$out" | grep -q "MAKEOBJDIRPREFIX="; then
    pass "buildkernel emission: isolated obj + KERNCONF"
  else
    fail "buildkernel emission wrong: $out"
  fi
  run_elebake setenv ELEBAKE_KERNCONF BOGUS > /dev/null
  if run_elebake stage build kernel unitk 2>&1 | grep -q "no such KERNCONF in this checkout: BOGUS"; then
    pass "unknown KERNCONF fails against the checkout"
  else
    fail "bogus KERNCONF accepted"
  fi
  run_elebake setenv ELEBAKE_KERNCONF GENERIC > /dev/null
  mkdir -p "$TEST_DIR/stage/unitk/obj"
  run_elebake setintp stage_install_kernel cat > /dev/null
  out=$(run_elebake stage install kernel unitk)
  if printf '%s\n' "$out" | grep -q "installkernel KERNCONF='GENERIC'" \
     && printf '%s\n' "$out" | grep -q 'install -U' \
     && printf '%s\n' "$out" | grep -q "DESTDIR="; then
    pass "installkernel emission: unprivileged into the stage destdir"
  else
    fail "installkernel emission wrong: $out"
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
  if run_elebake stage dump unitq | grep -q "stage prerequisites verify add 'unitq' '/boot/loader.efi.signed'"; then
    pass "stage dump replays the lists"
  else
    fail "dump replay missing"
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
}

test_foundation_prereqs_arrays() {
  test_header "foundation.c emits the prerequisites arrays exactly when the checkout expects them"
  test_setup
  run_elebake stage add unita > /dev/null 2>&1
  fixture_worktree unita
  run_elebake setintp stage_foundation_make cat > /dev/null
  if run_elebake stage foundation make unita | grep -q "prerequisites_exist"; then
    fail "arrays emitted although the checkout has no extern declarations"
  else
    pass "old checkout (no extern): no arrays — backwards compatible"
  fi
  printf 'extern const char *const	prerequisites_exist[];\nextern const char *const	prerequisites_verify[];\nextern const unsigned int	prerequisites_exist_n;\nextern const unsigned int	prerequisites_verify_n;\n' >> "$TEST_BASE_DIR/fix-work-$TESTS_RUN-unita/stand/efi/loader/local/measurement.h"
  run_elebake stage prerequisites verify add unita /boot/loader.conf > /dev/null
  run_elebake stage prerequisites verify add unita /boot/loader.efi.signed > /dev/null
  local out; out=$(run_elebake stage foundation make unita)
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
  should_run_test test_stage_loader_ingest
  should_run_test test_stage_unkey_and_attest
  should_run_test test_batch_fail_fast_default
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
  should_run_test test_stage_prerequisites_lists
  should_run_test test_filter_stdin_and_include_source
  should_run_test test_foundation_prereqs_arrays

  test_summary
}

main
exit $?
