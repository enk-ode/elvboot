#!/bin/sh
#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Dr. Johannes Brügmann
# elebake - emit-and-inspect tooling for verified-boot / tamper-detection
# Combinator-based architecture (engine extracted from vpn-switch).
#
# POSIX shell compliant (tested on FreeBSD sh).
#
# === METADATA (hand-maintained during the extraction; regenerate later) ===
# Terminal functions      (single underscore _):   emit shell commands
# Combinator functions     (double underscore __):  emit ONE re-invocation
# Batch-combinator functions (triple underscore ___): emit SEVERAL re-invocations
TERMINAL_FUNCTIONS="_attest2 _attest_verify2 _database_init0 _environment_init1 _environment_cache_on0 _environment_cache_off0 _environment_cache_status0 _setenv2 _getenv1 _unsetenv1 _destroy_worktrees1 _destroy_records1 _destroy_scaffold1 _cat1 _batch2 _printenv0 _filter_redacted2 _filter_full2 _filter_minimized2 _bundle2 _seal2 _seal_verify2 _incoming_clear1 _extract2 _unknown_command1 _error1 _error2 _error3 _fail2 _log1 _log2 _log3 _macro_add3 _macro_add4 _macro_add5 _macro_drop1 _macro_show1 _expectation_add4 _expectation_drop1 _expectation_show1 _claim_add5 _claim_drop1 _claim_show1 _trigger_add3 _trigger_drop1 _trigger_show1 _gate_add2 _gate_add1 _gate_drop1 _gate_claim_add2 _gate_claim_add3 _gate_claim_drop2 _gate_show1 _policy_add2 _policy_trigger_add2 _policy_trigger_add3 _policy_trigger_drop2 _policy_drop1 _policy_show1 _foundation_collect0 _freebsd_prerequisites0 _help0 _help1 _help2 _help_manual_title0 _help_manual_part1 _help_manual_commands0 _help_manual_environment0 _help_env0 _help_env2 _last0 _last1 _manifest2 _manifest_match2 _openpgp_add2 _openpgp_add3 _openpgp_prerequisites0 _openpgp_import2 _openpgp_collect1 _pem_add3 _pem_prerequisites0 _pem_import2 _pem_collect1 _pkcs11_add3 _pkcs11_prerequisites0 _pkcs11_import2 _pkcs11_collect1 _provenance_serial0 _provenance_add2 _provenance_import2 _provenance_collect0 _provenance_list0 _stage_list0 _stage_add1 _stage_sign_key3 _stage_attest_key3 _stage_unkey1 _stage_prerequisites1 _stage_status_populated1 _stage_status_signkey1 _stage_status_attestkey1 _stage_status_signed1 _stage_status_filter1 _stage_status_media1 _stage_status_marker1 _stage_status_sitemk1 _stage_sign_pkcs11_1 _stage_sign_pem1 _stage_detachsign1 _stage_worktree2 _stage_clean_dir1 _stage_reset1 _stage_build_stand2 _stage_install2 _stage_prerequisites_add3 _stage_prerequisites_drop3 _stage_prerequisites_show2 _stage_build_kernel1 _stage_install_kernel1 _stage_filter_list1 _stage_filter_uncurated2 _stage_filter_orphaned1 _stage_filter_add2 _stage_filter_drop2 _stage_include2 _stage_adopt_copy2 _stage_loader2 _stage_manifest1 _stage_verify_listed1 _stage_verify_unlisted1 _stage_device4 _stage_backup4 _stage_backup_list2 _stage_deploy2 _stage_rollback_apply3 _stage_trust_anchor1 _stage_trust_mk1 _stage_boot_tree4 _stage_pool_import3 _stage_pool_export2 _stage_tree_snapshot2 _stage_tree_copy2 _stage_tree_verify2 _stage_tree_close2 _stage_edit2 _stage_marker_record3 _stage_marker_write2 _stage_site_mk_header1 _stage_site_mk_board1 _stage_site_mk_keys1 _stage_site_mk_marker1 _stage_site_mk_origin1 _stage_site_mk_install2 _stage_site_mk_report2 _stage_check_stage1 _stage_check_dir2 _stage_import_dir2 _stage_check_file3 _stage_import_file3 _stage_measure1 _stage_action1 _stage_when1 _stage_phase_show1 _stage_phase_show2 _stage_check_policy3 _stage_phase_policy_append3 _stage_phase_policy_append4 _stage_phase_policy_drop3 _stage_foundation_prepare1 _stage_foundation_render_header1 _stage_foundation_render_macros1 _stage_foundation_render_secrets1 _stage_foundation_render_prerequisites1 _stage_foundation_render_gates1 _stage_foundation_render_phases1 _stage_foundation_render_dispatch1 _stage_foundation_install1 _stage_foundation_check1 _stage_foundation_report1 _stage_collect1"
COMBINATOR_FUNCTIONS="__bootstrap1 __environment_cache0 __init0 __dump0 __dump1 __batch1 __restore1 __restore2 __filter2 __filter_default2 __export3 __help_env1 __setintp2 __getintp1 __help_intp1 __help_intp2 __stage_authenticode1 __stage_prerequisites_exist_add2 __stage_prerequisites_verify_add2 __stage_prerequisites_exist_drop2 __stage_prerequisites_verify_drop2 __stage_prerequisites_exist_show1 __stage_prerequisites_verify_show1 __stage_prereqs_exist_add2 __stage_prereqs_verify_add2 __stage_prereqs_exist_drop2 __stage_prereqs_verify_drop2 __stage_prereqs_exist_show1 __stage_prereqs_verify_show1 __stage_filter_show1 __stage_include1 __stage_device3 __stage_backup2 __stage_backup3 __stage_rollback2 __stage_marker_rotate1 __stage_marker2 __stage_site_mk_report1 __stage_dump0 __stage_dump1 __stage_dump_record1 __stage_dump_boot1"
BATCH_COMBINATOR_FUNCTIONS="___bootstrap2 ___init1 ___dump_env_prologue0 ___dump_env_epilogue0 ___destroy1 ___dump2 ___batch0 ___collect0 ___collect1 ___export4 ___import2 ___macro_show0 ___expectation_show0 ___claim_show0 ___trigger_show0 ___gate_show0 ___policy_show0 ___foundation_dump0 ___macro_dump0 ___expectation_dump0 ___claim_dump0 ___trigger_dump0 ___gate_dump0 ___policy_dump0 ___help_manual0 ___manifest_attest2 ___manifest_verify3 ___openpgp_dump0 ___openpgp_collect0 ___pem_dump0 ___pem_collect0 ___pkcs11_dump0 ___pkcs11_collect0 ___prerequisites_verify0 ___provenance_dump0 ___stage_status1 ___stage_sign1 ___stage_attest1 ___stage_checkout2 ___stage_clean1 ___stage_build_stand1 ___stage_make1 ___stage_build1 ___stage_install1 ___stage_filter_show2 ___stage_adopt2 ___stage_verify1 ___stage_rollback3 ___stage_source1 ___stage_tree_work2 ___stage_tree_sync2 ___stage_push2 ___stage_marker3 ___stage_site_mk1 ___stage_dump_all1 ___stage_dump2 ___stage_dump_record2 ___stage_dump_add2 ___stage_dump_filter1 ___stage_dump_keys1 ___stage_dump_media1 ___stage_dump_checkout1 ___stage_dump_work1 ___stage_dump_phases1 ___stage_dump_prereqs1 ___stage_dump_marker1 ___stage_dump_backup1 ___stage_dump_boot2 ___stage_dump_rebuild1 ___stage_import2 ___stage_import3 ___stage_phase_policy_add3 ___stage_phase_policy_add4 ___stage_foundation_make1 ___stage_foundation1 ___stage_collect0"
ANCHOR_FUNCTIONS="$TERMINAL_FUNCTIONS $COMBINATOR_FUNCTIONS $BATCH_COMBINATOR_FUNCTIONS"
# Function-to-module mapping (format: "func:module.sh ...").
# Used by main()/process_arguments() for deterministic module loading. All
# domain functions currently live in database.sh (sourced unconditionally
# below, so this table is belt-and-suspenders for the bootstrap path).
FUNCTION_MODULES="_attest2:attest.sh _attest_verify2:attest.sh __bootstrap1:database.sh ___bootstrap2:database.sh _database_init0:database.sh _environment_init1:database.sh __environment_cache0:database.sh _environment_cache_on0:database.sh _environment_cache_off0:database.sh _environment_cache_status0:database.sh ___init1:database.sh __init0:database.sh _setenv2:database.sh _getenv1:database.sh _unsetenv1:database.sh ___dump_env_prologue0:database.sh ___dump_env_epilogue0:database.sh ___destroy1:database.sh _destroy_worktrees1:database.sh _destroy_records1:database.sh _destroy_scaffold1:database.sh __dump0:database.sh __dump1:database.sh ___dump2:database.sh _cat1:database.sh ___batch0:database.sh __batch1:database.sh _batch2:database.sh __restore1:database.sh __restore2:database.sh _printenv0:database.sh ___collect0:database.sh ___collect1:database.sh __filter2:database.sh __filter_default2:database.sh _filter_redacted2:database.sh _filter_full2:database.sh _filter_minimized2:database.sh _bundle2:database.sh _seal2:database.sh _seal_verify2:database.sh _incoming_clear1:database.sh _extract2:database.sh __export3:database.sh ___export4:database.sh ___import2:database.sh _macro_add3:foundation.sh _macro_add4:foundation.sh _macro_add5:foundation.sh _macro_drop1:foundation.sh ___macro_show0:foundation.sh _macro_show1:foundation.sh _expectation_add4:foundation.sh _expectation_drop1:foundation.sh ___expectation_show0:foundation.sh _expectation_show1:foundation.sh _claim_add5:foundation.sh _claim_drop1:foundation.sh ___claim_show0:foundation.sh _claim_show1:foundation.sh _trigger_add3:foundation.sh _trigger_drop1:foundation.sh ___trigger_show0:foundation.sh _trigger_show1:foundation.sh _gate_add2:foundation.sh _gate_add1:foundation.sh _gate_drop1:foundation.sh _gate_claim_add2:foundation.sh _gate_claim_add3:foundation.sh _gate_claim_drop2:foundation.sh ___gate_show0:foundation.sh _gate_show1:foundation.sh _policy_add2:foundation.sh _policy_trigger_add2:foundation.sh _policy_trigger_add3:foundation.sh _policy_trigger_drop2:foundation.sh _policy_drop1:foundation.sh ___policy_show0:foundation.sh _policy_show1:foundation.sh ___foundation_dump0:foundation.sh ___macro_dump0:foundation.sh ___expectation_dump0:foundation.sh ___claim_dump0:foundation.sh ___trigger_dump0:foundation.sh ___gate_dump0:foundation.sh ___policy_dump0:foundation.sh _foundation_collect0:foundation.sh _freebsd_prerequisites0:freebsd.sh _help0:help.sh _help1:help.sh _help2:help.sh ___help_manual0:help.sh _help_manual_title0:help.sh _help_manual_part1:help.sh _help_manual_commands0:help.sh _help_manual_environment0:help.sh _help_env0:helpenv.sh __help_env1:helpenv.sh _help_env2:helpenv.sh _last0:inspect.sh _last1:inspect.sh __setintp2:intp.sh __getintp1:intp.sh __help_intp1:intp.sh __help_intp2:intp.sh _manifest2:manifest.sh ___manifest_attest2:manifest.sh ___manifest_verify3:manifest.sh _manifest_match2:manifest.sh _openpgp_add2:openpgp.sh _openpgp_add3:openpgp.sh _openpgp_prerequisites0:openpgp.sh ___openpgp_dump0:openpgp.sh _openpgp_import2:openpgp.sh ___openpgp_collect0:openpgp.sh _openpgp_collect1:openpgp.sh _pem_add3:pem.sh _pem_prerequisites0:pem.sh ___pem_dump0:pem.sh _pem_import2:pem.sh ___pem_collect0:pem.sh _pem_collect1:pem.sh _pkcs11_add3:pkcs11.sh _pkcs11_prerequisites0:pkcs11.sh ___pkcs11_dump0:pkcs11.sh _pkcs11_import2:pkcs11.sh ___pkcs11_collect0:pkcs11.sh _pkcs11_collect1:pkcs11.sh ___prerequisites_verify0:prerequisites.sh _provenance_serial0:provenance.sh _provenance_add2:provenance.sh _provenance_import2:provenance.sh ___provenance_dump0:provenance.sh _provenance_collect0:provenance.sh _provenance_list0:provenance.sh _stage_list0:stage.sh _stage_add1:stage.sh _stage_sign_key3:stage.sh _stage_attest_key3:stage.sh _stage_unkey1:stage.sh _stage_prerequisites1:stage.sh ___stage_status1:stage.sh _stage_status_populated1:stage.sh _stage_status_signkey1:stage.sh _stage_status_attestkey1:stage.sh _stage_status_signed1:stage.sh _stage_status_filter1:stage.sh _stage_status_media1:stage.sh _stage_status_marker1:stage.sh _stage_status_sitemk1:stage.sh __stage_authenticode1:stage.sh _stage_sign_pkcs11_1:stage.sh _stage_sign_pem1:stage.sh _stage_detachsign1:stage.sh ___stage_sign1:stage.sh ___stage_attest1:stage.sh _stage_worktree2:stage.sh ___stage_checkout2:stage.sh _stage_clean_dir1:stage.sh _stage_reset1:stage.sh ___stage_clean1:stage.sh ___stage_build_stand1:stage.sh _stage_build_stand2:stage.sh ___stage_make1:stage.sh ___stage_build1:stage.sh ___stage_install1:stage.sh _stage_install2:stage.sh _stage_prerequisites_add3:stage.sh _stage_prerequisites_drop3:stage.sh _stage_prerequisites_show2:stage.sh __stage_prerequisites_exist_add2:stage.sh __stage_prerequisites_verify_add2:stage.sh __stage_prerequisites_exist_drop2:stage.sh __stage_prerequisites_verify_drop2:stage.sh __stage_prerequisites_exist_show1:stage.sh __stage_prerequisites_verify_show1:stage.sh __stage_prereqs_exist_add2:stage.sh __stage_prereqs_verify_add2:stage.sh __stage_prereqs_exist_drop2:stage.sh __stage_prereqs_verify_drop2:stage.sh __stage_prereqs_exist_show1:stage.sh __stage_prereqs_verify_show1:stage.sh _stage_build_kernel1:stage.sh _stage_install_kernel1:stage.sh __stage_filter_show1:stage.sh ___stage_filter_show2:stage.sh _stage_filter_list1:stage.sh _stage_filter_uncurated2:stage.sh _stage_filter_orphaned1:stage.sh _stage_filter_add2:stage.sh _stage_filter_drop2:stage.sh __stage_include1:stage.sh _stage_include2:stage.sh ___stage_adopt2:stage.sh _stage_adopt_copy2:stage.sh _stage_loader2:stage.sh _stage_manifest1:stage.sh ___stage_verify1:stage.sh _stage_verify_listed1:stage.sh _stage_verify_unlisted1:stage.sh __stage_device3:stage.sh _stage_device4:stage.sh __stage_backup2:stage.sh __stage_backup3:stage.sh _stage_backup4:stage.sh _stage_backup_list2:stage.sh _stage_deploy2:stage.sh __stage_rollback2:stage.sh ___stage_rollback3:stage.sh _stage_rollback_apply3:stage.sh _stage_trust_anchor1:stage.sh _stage_trust_mk1:stage.sh ___stage_source1:stage.sh _stage_boot_tree4:stage.sh _stage_pool_import3:stage.sh _stage_pool_export2:stage.sh _stage_tree_snapshot2:stage.sh _stage_tree_copy2:stage.sh _stage_tree_verify2:stage.sh _stage_tree_close2:stage.sh ___stage_tree_work2:stage.sh ___stage_tree_sync2:stage.sh ___stage_push2:stage.sh _stage_edit2:stage.sh ___stage_marker3:stage.sh __stage_marker_rotate1:stage.sh _stage_marker_record3:stage.sh _stage_marker_write2:stage.sh __stage_marker2:stage.sh ___stage_site_mk1:stage.sh _stage_site_mk_header1:stage.sh _stage_site_mk_board1:stage.sh _stage_site_mk_keys1:stage.sh _stage_site_mk_marker1:stage.sh _stage_site_mk_origin1:stage.sh _stage_site_mk_install2:stage.sh __stage_site_mk_report1:stage.sh _stage_site_mk_report2:stage.sh __stage_dump0:stage.sh ___stage_dump_all1:stage.sh __stage_dump1:stage.sh ___stage_dump2:stage.sh __stage_dump_record1:stage.sh ___stage_dump_record2:stage.sh ___stage_dump_add2:stage.sh ___stage_dump_filter1:stage.sh ___stage_dump_keys1:stage.sh ___stage_dump_media1:stage.sh ___stage_dump_checkout1:stage.sh ___stage_dump_work1:stage.sh ___stage_dump_phases1:stage.sh ___stage_dump_prereqs1:stage.sh ___stage_dump_marker1:stage.sh ___stage_dump_backup1:stage.sh __stage_dump_boot1:stage.sh ___stage_dump_boot2:stage.sh ___stage_dump_rebuild1:stage.sh ___stage_import2:stage.sh ___stage_import3:stage.sh _stage_check_stage1:stage.sh _stage_check_dir2:stage.sh _stage_import_dir2:stage.sh _stage_check_file3:stage.sh _stage_import_file3:stage.sh _stage_measure1:stage.sh _stage_action1:stage.sh _stage_when1:stage.sh _stage_phase_show1:stage.sh _stage_phase_show2:stage.sh ___stage_phase_policy_add3:stage.sh ___stage_phase_policy_add4:stage.sh _stage_check_policy3:stage.sh _stage_phase_policy_append3:stage.sh _stage_phase_policy_append4:stage.sh _stage_phase_policy_drop3:stage.sh _stage_foundation_prepare1:stage.sh _stage_foundation_render_header1:stage.sh _stage_foundation_render_macros1:stage.sh _stage_foundation_render_secrets1:stage.sh _stage_foundation_render_prerequisites1:stage.sh _stage_foundation_render_gates1:stage.sh _stage_foundation_render_phases1:stage.sh _stage_foundation_render_dispatch1:stage.sh _stage_foundation_install1:stage.sh _stage_foundation_check1:stage.sh ___stage_foundation_make1:stage.sh _stage_foundation_report1:stage.sh ___stage_foundation1:stage.sh ___stage_collect0:stage.sh _stage_collect1:stage.sh"
# === END METADATA ===

set -e  # Exit on error
set -u  # Exit on undefined variable

# Default LOG_FILE (overridden by process_arguments if retention > 0)
: "${LOG_FILE:=/dev/null}"

# Commands that can run without an initialized database.
COMMANDS_WITHOUT_DATABASE="help bootstrap init log error fail"

#-----------------------------------------------------------------------------
# Environment Configuration
#-----------------------------------------------------------------------------

# Script path (for sourcing/re-exec in isolated environments).
: "${ELEBAKE_CONTEXT_SCRIPT:=$(readlink -f "$0" 2>>"$LOG_FILE" || realpath "$0" 2>>"$LOG_FILE" || echo "$0")}"

# Exit-code bits (propagated through the call tree).
: "${ELEBAKE_CONTEXT_EXIT_BITS:=0}"

# Was ELEBAKE_BASE explicitly set (before applying the default)?
ELEBAKE_BASE_EXPLICIT="${ELEBAKE_BASE:-}"

# Base directory for the ACTIVE database (the `db` symlink by default).
: "${ELEBAKE_BASE:=$HOME/.elebake/db}"

# Root holding all databases; `db` is a symlink here to the active DB (e.g.
# db -> current), so multiple DBs live side by side. Derived from ELEBAKE_BASE
# — which is passed through the env- re-exec, where $HOME is unset.
: "${ELEBAKE_ROOT:=$(dirname "$ELEBAKE_BASE")}"

# Environment directory (layered .env store lives here).
: "${ELEBAKE_ENV_DIR:=${ELEBAKE_BASE}/.env}"

# Library directory: contains include/ and template/. Default: script location.
: "${ELEBAKE_LIBDIR:=$(dirname "$ELEBAKE_CONTEXT_SCRIPT")}"

# Template directory: environment/ (and, later, image/upstream/snapshot helpers).
: "${ELEBAKE_TEMPLATE_DIR:=$ELEBAKE_LIBDIR/template}"

# Directory configuration for database init/validation.
# Format: path:mode:exec_flag:content_policy (newline separated), relative to
# $ELEBAKE_BASE.
#   exec_flag:      "exec" (scripts must run) | "noexec" (safe for noexec mount)
#   content_policy: "exclusive" (must be empty) | "operational" (idempotent)
ELEBAKE_INIT_DIR_CONFIG=".tmp:0750:noexec:operational
.tmp/batch-exits:0750:noexec:operational
.log:0750:noexec:operational
.env:0700:noexec:operational
.env/default:0700:noexec:operational
.env/local:0700:noexec:operational
pkcs11:0700:noexec:operational
openpgp:0700:noexec:operational
pem:0700:noexec:operational
export:0700:noexec:operational
incoming:0700:noexec:operational
provenance:0700:noexec:operational
.staging:0700:noexec:operational
stage:0700:noexec:operational
foundation:0700:noexec:operational
foundation/macros:0700:noexec:operational
foundation/expectations:0700:noexec:operational
foundation/claims:0700:noexec:operational
foundation/triggers:0700:noexec:operational
foundation/gates:0700:noexec:operational
foundation/policies:0700:noexec:operational"

# Pseudo-backends: top-level dirs that are NOT real signing backends (hidden .*
# dirs are excluded automatically). is_pseudo_backend() uses this to enumerate
# the real backends (pkcs11, openpgp) from `ls $ELEBAKE_BASE`. Mirrors
# vpn-switch's PSEUDO_PROTOCOL. Hardcoded global so it is always defined.
ELEBAKE_PSEUDO_BACKEND="stage foundation provenance export incoming"

#-----------------------------------------------------------------------------
# Platform commands (FreeBSD, inlined)
#-----------------------------------------------------------------------------
# vpn-switch loaded these from template/platform/<os>.sh. elebake targets
# FreeBSD only, so the handful the engine/database actually use are inlined
# here. EXAMINE_* = read-only inspection; MODIFY_* = state-changing.
CMD_STAT_PERMS='stat -f %Lp'       # file permissions (octal, e.g. 0400)
EXAMINE_FILE_OWNER='stat -f %u:%g' # file owner (uid:gid)
MODIFY_DIR_CREATE='mkdir -p'   # create directory (with parents)
MODIFY_FILE_PERMS='chmod'      # change file permissions
MODIFY_FILE_OWNER='chown'      # change file owner (uid:gid)
MODIFY_FILE_REMOVE='rm -f'     # remove file
MODIFY_FILE_COPY_FORCE='cp -f' # copy file (force overwrite)
MODIFY_LINK_FORCE='ln -sfn'    # force create/overwrite symlink

# Preserve the caller's ORIGINAL stdin as fd 3: the generator deliberately
# runs with stdin closed (dispatch </dev/null — nested batch pipelines must
# not eat each other's emissions), so the stdin-consuming argument forms
# ('add -') read from fd 3 instead. Dumps never replay the '-' form (they
# emit the expanded adds), so replays stay unaffected. Only the TOP-LEVEL
# call binds it: a re-invoked child (combinator interpreter) has the
# emission pipe as stdin and inherits fd 3 from its parent, so 'add -'
# works through a combinator too.
[ -n "${ELEBAKE_CONTEXT_BOOTSTRAPPED:-}" ] || exec 3<&0 || true

#-----------------------------------------------------------------------------
# Load the engine and the domain modules
#-----------------------------------------------------------------------------
. "$ELEBAKE_LIBDIR/include/engine.sh"
# Module preload is DATA (ELEBAKE_INCLUDES). Built-in minimal default: only
# the no-DB commands (bootstrap -> database.sh, help -> help.sh); every other
# module is lazy-loaded per dispatch via FUNCTION_MODULES. A bootstrapped DB
# preloads the full list from the ELEBAKE_INCLUDES template instead.
: "${ELEBAKE_INCLUDES:=database.sh help.sh}"
for _m in $ELEBAKE_INCLUDES; do
  . "$ELEBAKE_LIBDIR/include/$_m"
done
unset _m

#-----------------------------------------------------------------------------
# Entry point
#-----------------------------------------------------------------------------
# Run main only when executed directly (not when sourced by a test harness).
if [ "${0##*/}" = "elebake.sh" ] || [ "${0##*/}" = "elebake" ]; then
  # Bootstrap: load environment from .env files exactly once, then re-exec.
  if [ -z "${ELEBAKE_CONTEXT_BOOTSTRAPPED:-}" ]; then
    env_args=$(build_env_args)

    # Provide interpreter defaults if .env files don't exist yet (first init).
    ensure_interpreter_var "ELEBAKE_TERMINAL_INTERPRETER"
    ensure_interpreter_var "ELEBAKE_COMBINATOR_INTERPRETER"
    ensure_interpreter_var "ELEBAKE_BATCH_COMBINATOR_INTERPRETER"

    passthrough=""
    passthrough="$passthrough ELEBAKE_CONTEXT_BOOTSTRAPPED=1"

    if [ -z "${ELEBAKE_CACHE_ENV_ARGS:-}" ]; then
      ELEBAKE_CACHE_ENV_ARGS="$env_args"
    fi
    passthrough="$passthrough ELEBAKE_CACHE_ENV_ARGS=\"\$ELEBAKE_CACHE_ENV_ARGS\""

    if [ -n "${ELEBAKE_TRACE_FILE:-}" ]; then
      case "$ELEBAKE_TRACE_FILE" in
        /*)
          passthrough="$passthrough ELEBAKE_TRACE_FILE=\"\$ELEBAKE_TRACE_FILE\""
          ;;
        *)
          ELEBAKE_TRACE_FILE="${ELEBAKE_BASE}/.trace/${ELEBAKE_TRACE_FILE}"
          passthrough="$passthrough ELEBAKE_TRACE_FILE=\"\$ELEBAKE_TRACE_FILE\""
          ;;
      esac
    fi

    if [ -n "${ELEBAKE_TRACE_DEPTH:-}" ]; then
      passthrough="$passthrough ELEBAKE_TRACE_DEPTH=\"\$ELEBAKE_TRACE_DEPTH\""
    fi

    if [ -n "${ELEBAKE_BATCH_KEEP_GOING:-}" ]; then
      passthrough="$passthrough ELEBAKE_BATCH_KEEP_GOING=\"$ELEBAKE_BATCH_KEEP_GOING\""
    fi

    # Re-exec with the loaded environment.
    # ELEBAKE_BASE must come AFTER $env_args to override any .env value.
    eval "exec env - $env_args $passthrough ELEBAKE_CONTEXT_SCRIPT=\"\$ELEBAKE_CONTEXT_SCRIPT\" ELEBAKE_BASE=\"\$ELEBAKE_BASE\" \"\$ELEBAKE_CONTEXT_SCRIPT\" \"\$@\""
  fi

  # Bootstrapped: environment is loaded.
  main "$@"
fi
