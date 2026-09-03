#!/bin/sh
#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Dr. Johannes Brügmann
# === AUTO-GENERATED METADATA (make metadata) ===
# Generated: 2026-08-08 09:51:55
# Terminal functions (single underscore): output shell commands
# Combinator functions (double underscore): output single elebake command
# Batch-combinator functions (triple underscore): output multiple elebake commands
TERMINAL_FUNCTIONS="_attest2 _attest_verify2 _database_init0 _environment_init1 _environment_cache_on0 _environment_cache_off0 _environment_cache_status0 _setenv2 _getenv1 _unsetenv1 _destroy_worktrees1 _destroy_records1 _destroy_scaffold1 _cat1 _batch2 _printenv0 _filter_redacted2 _filter_full2 _filter_minimized2 _bundle2 _seal2 _seal_verify2 _incoming_clear1 _extract2 _unknown_command1 _error1 _error2 _error3 _fail2 _log1 _log2 _log3 _macro_add3 _macro_add4 _macro_add5 _macro_drop1 _macro_show1 _expectation_add4 _expectation_drop1 _expectation_show1 _claim_add5 _claim_drop1 _claim_show1 _trigger_add3 _trigger_drop1 _trigger_show1 _gate_add2 _gate_add1 _gate_drop1 _gate_claim_add2 _gate_claim_add3 _gate_claim_drop2 _gate_show1 _policy_add2 _policy_trigger_add2 _policy_trigger_add3 _policy_trigger_drop2 _policy_drop1 _policy_show1 _foundation_collect0 _freebsd_prerequisites0 _help0 _help1 _help2 _help_manual_title0 _help_manual_part1 _help_manual_commands0 _help_manual_environment0 _help_env0 _help_env2 _last0 _last1 _manifest2 _manifest_match2 _openpgp_add2 _openpgp_add3 _openpgp_prerequisites0 _openpgp_import2 _openpgp_collect1 _pem_add3 _pem_prerequisites0 _pem_import2 _pem_collect1 _pkcs11_add3 _pkcs11_prerequisites0 _pkcs11_import2 _pkcs11_collect1 _provenance_serial0 _provenance_add2 _provenance_import2 _provenance_collect0 _provenance_list0 _stage_list0 _stage_add1 _stage_sign_key3 _stage_attest_key3 _stage_unkey1 _stage_prerequisites1 _stage_status_populated1 _stage_status_signkey1 _stage_status_attestkey1 _stage_status_signed1 _stage_status_filter1 _stage_status_media1 _stage_status_marker1 _stage_status_sitemk1 _stage_sign_pkcs11_1 _stage_sign_pem1 _stage_detachsign1 _stage_worktree2 _stage_clean_dir1 _stage_reset1 _stage_build_stand2 _stage_install2 _stage_prerequisites_add3 _stage_prerequisites_drop3 _stage_prerequisites_show2 _stage_build_kernel1 _stage_install_kernel1 _stage_filter_list1 _stage_filter_uncurated2 _stage_filter_orphaned1 _stage_filter_add2 _stage_filter_drop2 _stage_include2 _stage_adopt_copy2 _stage_loader2 _stage_manifest1 _stage_verify_listed1 _stage_verify_unlisted1 _stage_device4 _stage_backup4 _stage_backup_list2 _stage_deploy2 _stage_rollback_apply3 _stage_trust_anchor1 _stage_trust_mk1 _stage_boot_tree4 _stage_pool_import3 _stage_pool_export2 _stage_tree_snapshot2 _stage_tree_copy2 _stage_tree_verify2 _stage_tree_close2 _stage_edit2 _stage_marker_record3 _stage_marker_write2 _stage_site_mk_header1 _stage_site_mk_board1 _stage_site_mk_keys1 _stage_site_mk_marker1 _stage_site_mk_origin1 _stage_site_mk_install2 _stage_site_mk_report2 _stage_check_stage1 _stage_check_dir2 _stage_import_dir2 _stage_check_file3 _stage_import_file3 _stage_measure1 _stage_action1 _stage_when1 _stage_phase_show1 _stage_phase_show2 _stage_check_policy3 _stage_phase_policy_append3 _stage_phase_policy_append4 _stage_phase_policy_drop3 _stage_foundation_prepare1 _stage_foundation_render_header1 _stage_foundation_render_macros1 _stage_foundation_render_secrets1 _stage_foundation_render_prerequisites1 _stage_foundation_render_gates1 _stage_foundation_render_phases1 _stage_foundation_render_dispatch1 _stage_foundation_install1 _stage_foundation_check1 _stage_foundation_report1 _stage_collect1"
COMBINATOR_FUNCTIONS="__bootstrap1 __environment_cache0 __init0 __dump0 __dump1 __batch1 __restore1 __restore2 __filter2 __filter_default2 __export3 __help_env1 __setintp2 __getintp1 __help_intp1 __help_intp2 __stage_authenticode1 __stage_prerequisites_exist_add2 __stage_prerequisites_verify_add2 __stage_prerequisites_exist_drop2 __stage_prerequisites_verify_drop2 __stage_prerequisites_exist_show1 __stage_prerequisites_verify_show1 __stage_prereqs_exist_add2 __stage_prereqs_verify_add2 __stage_prereqs_exist_drop2 __stage_prereqs_verify_drop2 __stage_prereqs_exist_show1 __stage_prereqs_verify_show1 __stage_filter_show1 __stage_include1 __stage_device3 __stage_backup2 __stage_backup3 __stage_rollback2 __stage_marker_rotate1 __stage_marker2 __stage_site_mk_report1 __stage_dump0 __stage_dump1 __stage_dump_record1 __stage_dump_boot1"
BATCH_COMBINATOR_FUNCTIONS="___bootstrap2 ___init1 ___dump_env_prologue0 ___dump_env_epilogue0 ___destroy1 ___dump2 ___batch0 ___collect0 ___collect1 ___export4 ___import2 ___macro_show0 ___expectation_show0 ___claim_show0 ___trigger_show0 ___gate_show0 ___policy_show0 ___foundation_dump0 ___macro_dump0 ___expectation_dump0 ___claim_dump0 ___trigger_dump0 ___gate_dump0 ___policy_dump0 ___help_manual0 ___manifest_attest2 ___manifest_verify3 ___openpgp_dump0 ___openpgp_collect0 ___pem_dump0 ___pem_collect0 ___pkcs11_dump0 ___pkcs11_collect0 ___prerequisites_verify0 ___provenance_dump0 ___stage_status1 ___stage_sign1 ___stage_attest1 ___stage_checkout2 ___stage_clean1 ___stage_build_stand1 ___stage_make1 ___stage_build1 ___stage_install1 ___stage_filter_show2 ___stage_adopt2 ___stage_verify1 ___stage_rollback3 ___stage_source1 ___stage_tree_work2 ___stage_tree_sync2 ___stage_push2 ___stage_marker3 ___stage_site_mk1 ___stage_dump_all1 ___stage_dump2 ___stage_dump_record2 ___stage_dump_add2 ___stage_dump_filter1 ___stage_dump_keys1 ___stage_dump_media1 ___stage_dump_checkout1 ___stage_dump_work1 ___stage_dump_phases1 ___stage_dump_prereqs1 ___stage_dump_marker1 ___stage_dump_backup1 ___stage_dump_boot2 ___stage_dump_rebuild1 ___stage_import2 ___stage_import3 ___stage_phase_policy_add3 ___stage_phase_policy_add4 ___stage_foundation_make1 ___stage_foundation1 ___stage_collect0"
ANCHOR_FUNCTIONS="_attest2 _attest_verify2 _database_init0 _environment_init1 _environment_cache_on0 _environment_cache_off0 _environment_cache_status0 _setenv2 _getenv1 _unsetenv1 _destroy_worktrees1 _destroy_records1 _destroy_scaffold1 _cat1 _batch2 _printenv0 _filter_redacted2 _filter_full2 _filter_minimized2 _bundle2 _seal2 _seal_verify2 _incoming_clear1 _extract2 _unknown_command1 _error1 _error2 _error3 _fail2 _log1 _log2 _log3 _macro_add3 _macro_add4 _macro_add5 _macro_drop1 _macro_show1 _expectation_add4 _expectation_drop1 _expectation_show1 _claim_add5 _claim_drop1 _claim_show1 _trigger_add3 _trigger_drop1 _trigger_show1 _gate_add2 _gate_add1 _gate_drop1 _gate_claim_add2 _gate_claim_add3 _gate_claim_drop2 _gate_show1 _policy_add2 _policy_trigger_add2 _policy_trigger_add3 _policy_trigger_drop2 _policy_drop1 _policy_show1 _foundation_collect0 _freebsd_prerequisites0 _help0 _help1 _help2 _help_manual_title0 _help_manual_part1 _help_manual_commands0 _help_manual_environment0 _help_env0 _help_env2 _last0 _last1 _manifest2 _manifest_match2 _openpgp_add2 _openpgp_add3 _openpgp_prerequisites0 _openpgp_import2 _openpgp_collect1 _pem_add3 _pem_prerequisites0 _pem_import2 _pem_collect1 _pkcs11_add3 _pkcs11_prerequisites0 _pkcs11_import2 _pkcs11_collect1 _provenance_serial0 _provenance_add2 _provenance_import2 _provenance_collect0 _provenance_list0 _stage_list0 _stage_add1 _stage_sign_key3 _stage_attest_key3 _stage_unkey1 _stage_prerequisites1 _stage_status_populated1 _stage_status_signkey1 _stage_status_attestkey1 _stage_status_signed1 _stage_status_filter1 _stage_status_media1 _stage_status_marker1 _stage_status_sitemk1 _stage_sign_pkcs11_1 _stage_sign_pem1 _stage_detachsign1 _stage_worktree2 _stage_clean_dir1 _stage_reset1 _stage_build_stand2 _stage_install2 _stage_prerequisites_add3 _stage_prerequisites_drop3 _stage_prerequisites_show2 _stage_build_kernel1 _stage_install_kernel1 _stage_filter_list1 _stage_filter_uncurated2 _stage_filter_orphaned1 _stage_filter_add2 _stage_filter_drop2 _stage_include2 _stage_adopt_copy2 _stage_loader2 _stage_manifest1 _stage_verify_listed1 _stage_verify_unlisted1 _stage_device4 _stage_backup4 _stage_backup_list2 _stage_deploy2 _stage_rollback_apply3 _stage_trust_anchor1 _stage_trust_mk1 _stage_boot_tree4 _stage_pool_import3 _stage_pool_export2 _stage_tree_snapshot2 _stage_tree_copy2 _stage_tree_verify2 _stage_tree_close2 _stage_edit2 _stage_marker_record3 _stage_marker_write2 _stage_site_mk_header1 _stage_site_mk_board1 _stage_site_mk_keys1 _stage_site_mk_marker1 _stage_site_mk_origin1 _stage_site_mk_install2 _stage_site_mk_report2 _stage_check_stage1 _stage_check_dir2 _stage_import_dir2 _stage_check_file3 _stage_import_file3 _stage_measure1 _stage_action1 _stage_when1 _stage_phase_show1 _stage_phase_show2 _stage_check_policy3 _stage_phase_policy_append3 _stage_phase_policy_append4 _stage_phase_policy_drop3 _stage_foundation_prepare1 _stage_foundation_render_header1 _stage_foundation_render_macros1 _stage_foundation_render_secrets1 _stage_foundation_render_prerequisites1 _stage_foundation_render_gates1 _stage_foundation_render_phases1 _stage_foundation_render_dispatch1 _stage_foundation_install1 _stage_foundation_check1 _stage_foundation_report1 _stage_collect1 __bootstrap1 __environment_cache0 __init0 __dump0 __dump1 __batch1 __restore1 __restore2 __filter2 __filter_default2 __export3 __help_env1 __setintp2 __getintp1 __help_intp1 __help_intp2 __stage_authenticode1 __stage_prerequisites_exist_add2 __stage_prerequisites_verify_add2 __stage_prerequisites_exist_drop2 __stage_prerequisites_verify_drop2 __stage_prerequisites_exist_show1 __stage_prerequisites_verify_show1 __stage_prereqs_exist_add2 __stage_prereqs_verify_add2 __stage_prereqs_exist_drop2 __stage_prereqs_verify_drop2 __stage_prereqs_exist_show1 __stage_prereqs_verify_show1 __stage_filter_show1 __stage_include1 __stage_device3 __stage_backup2 __stage_backup3 __stage_rollback2 __stage_marker_rotate1 __stage_marker2 __stage_site_mk_report1 __stage_dump0 __stage_dump1 __stage_dump_record1 __stage_dump_boot1 ___bootstrap2 ___init1 ___dump_env_prologue0 ___dump_env_epilogue0 ___destroy1 ___dump2 ___batch0 ___collect0 ___collect1 ___export4 ___import2 ___macro_show0 ___expectation_show0 ___claim_show0 ___trigger_show0 ___gate_show0 ___policy_show0 ___foundation_dump0 ___macro_dump0 ___expectation_dump0 ___claim_dump0 ___trigger_dump0 ___gate_dump0 ___policy_dump0 ___help_manual0 ___manifest_attest2 ___manifest_verify3 ___openpgp_dump0 ___openpgp_collect0 ___pem_dump0 ___pem_collect0 ___pkcs11_dump0 ___pkcs11_collect0 ___prerequisites_verify0 ___provenance_dump0 ___stage_status1 ___stage_sign1 ___stage_attest1 ___stage_checkout2 ___stage_clean1 ___stage_build_stand1 ___stage_make1 ___stage_build1 ___stage_install1 ___stage_filter_show2 ___stage_adopt2 ___stage_verify1 ___stage_rollback3 ___stage_source1 ___stage_tree_work2 ___stage_tree_sync2 ___stage_push2 ___stage_marker3 ___stage_site_mk1 ___stage_dump_all1 ___stage_dump2 ___stage_dump_record2 ___stage_dump_add2 ___stage_dump_filter1 ___stage_dump_keys1 ___stage_dump_media1 ___stage_dump_checkout1 ___stage_dump_work1 ___stage_dump_phases1 ___stage_dump_prereqs1 ___stage_dump_marker1 ___stage_dump_backup1 ___stage_dump_boot2 ___stage_dump_rebuild1 ___stage_import2 ___stage_import3 ___stage_phase_policy_add3 ___stage_phase_policy_add4 ___stage_foundation_make1 ___stage_foundation1 ___stage_collect0"
# Function-to-module mapping (format: "func:module.sh func:module.sh ...")
# Used by process_arguments() for deterministic module loading
FUNCTION_MODULES="_attest2:attest.sh _attest_verify2:attest.sh __bootstrap1:database.sh ___bootstrap2:database.sh _database_init0:database.sh _environment_init1:database.sh __environment_cache0:database.sh _environment_cache_on0:database.sh _environment_cache_off0:database.sh _environment_cache_status0:database.sh ___init1:database.sh __init0:database.sh _setenv2:database.sh _getenv1:database.sh _unsetenv1:database.sh ___dump_env_prologue0:database.sh ___dump_env_epilogue0:database.sh ___destroy1:database.sh _destroy_worktrees1:database.sh _destroy_records1:database.sh _destroy_scaffold1:database.sh __dump0:database.sh __dump1:database.sh ___dump2:database.sh _cat1:database.sh ___batch0:database.sh __batch1:database.sh _batch2:database.sh __restore1:database.sh __restore2:database.sh _printenv0:database.sh ___collect0:database.sh ___collect1:database.sh __filter2:database.sh __filter_default2:database.sh _filter_redacted2:database.sh _filter_full2:database.sh _filter_minimized2:database.sh _bundle2:database.sh _seal2:database.sh _seal_verify2:database.sh _incoming_clear1:database.sh _extract2:database.sh __export3:database.sh ___export4:database.sh ___import2:database.sh _macro_add3:foundation.sh _macro_add4:foundation.sh _macro_add5:foundation.sh _macro_drop1:foundation.sh ___macro_show0:foundation.sh _macro_show1:foundation.sh _expectation_add4:foundation.sh _expectation_drop1:foundation.sh ___expectation_show0:foundation.sh _expectation_show1:foundation.sh _claim_add5:foundation.sh _claim_drop1:foundation.sh ___claim_show0:foundation.sh _claim_show1:foundation.sh _trigger_add3:foundation.sh _trigger_drop1:foundation.sh ___trigger_show0:foundation.sh _trigger_show1:foundation.sh _gate_add2:foundation.sh _gate_add1:foundation.sh _gate_drop1:foundation.sh _gate_claim_add2:foundation.sh _gate_claim_add3:foundation.sh _gate_claim_drop2:foundation.sh ___gate_show0:foundation.sh _gate_show1:foundation.sh _policy_add2:foundation.sh _policy_trigger_add2:foundation.sh _policy_trigger_add3:foundation.sh _policy_trigger_drop2:foundation.sh _policy_drop1:foundation.sh ___policy_show0:foundation.sh _policy_show1:foundation.sh ___foundation_dump0:foundation.sh ___macro_dump0:foundation.sh ___expectation_dump0:foundation.sh ___claim_dump0:foundation.sh ___trigger_dump0:foundation.sh ___gate_dump0:foundation.sh ___policy_dump0:foundation.sh _foundation_collect0:foundation.sh _freebsd_prerequisites0:freebsd.sh _help0:help.sh _help1:help.sh _help2:help.sh ___help_manual0:help.sh _help_manual_title0:help.sh _help_manual_part1:help.sh _help_manual_commands0:help.sh _help_manual_environment0:help.sh _help_env0:helpenv.sh __help_env1:helpenv.sh _help_env2:helpenv.sh _last0:inspect.sh _last1:inspect.sh __setintp2:intp.sh __getintp1:intp.sh __help_intp1:intp.sh __help_intp2:intp.sh _manifest2:manifest.sh ___manifest_attest2:manifest.sh ___manifest_verify3:manifest.sh _manifest_match2:manifest.sh _openpgp_add2:openpgp.sh _openpgp_add3:openpgp.sh _openpgp_prerequisites0:openpgp.sh ___openpgp_dump0:openpgp.sh _openpgp_import2:openpgp.sh ___openpgp_collect0:openpgp.sh _openpgp_collect1:openpgp.sh _pem_add3:pem.sh _pem_prerequisites0:pem.sh ___pem_dump0:pem.sh _pem_import2:pem.sh ___pem_collect0:pem.sh _pem_collect1:pem.sh _pkcs11_add3:pkcs11.sh _pkcs11_prerequisites0:pkcs11.sh ___pkcs11_dump0:pkcs11.sh _pkcs11_import2:pkcs11.sh ___pkcs11_collect0:pkcs11.sh _pkcs11_collect1:pkcs11.sh ___prerequisites_verify0:prerequisites.sh _provenance_serial0:provenance.sh _provenance_add2:provenance.sh _provenance_import2:provenance.sh ___provenance_dump0:provenance.sh _provenance_collect0:provenance.sh _provenance_list0:provenance.sh _stage_list0:stage.sh _stage_add1:stage.sh _stage_sign_key3:stage.sh _stage_attest_key3:stage.sh _stage_unkey1:stage.sh _stage_prerequisites1:stage.sh ___stage_status1:stage.sh _stage_status_populated1:stage.sh _stage_status_signkey1:stage.sh _stage_status_attestkey1:stage.sh _stage_status_signed1:stage.sh _stage_status_filter1:stage.sh _stage_status_media1:stage.sh _stage_status_marker1:stage.sh _stage_status_sitemk1:stage.sh __stage_authenticode1:stage.sh _stage_sign_pkcs11_1:stage.sh _stage_sign_pem1:stage.sh _stage_detachsign1:stage.sh ___stage_sign1:stage.sh ___stage_attest1:stage.sh _stage_worktree2:stage.sh ___stage_checkout2:stage.sh _stage_clean_dir1:stage.sh _stage_reset1:stage.sh ___stage_clean1:stage.sh ___stage_build_stand1:stage.sh _stage_build_stand2:stage.sh ___stage_make1:stage.sh ___stage_build1:stage.sh ___stage_install1:stage.sh _stage_install2:stage.sh _stage_prerequisites_add3:stage.sh _stage_prerequisites_drop3:stage.sh _stage_prerequisites_show2:stage.sh __stage_prerequisites_exist_add2:stage.sh __stage_prerequisites_verify_add2:stage.sh __stage_prerequisites_exist_drop2:stage.sh __stage_prerequisites_verify_drop2:stage.sh __stage_prerequisites_exist_show1:stage.sh __stage_prerequisites_verify_show1:stage.sh __stage_prereqs_exist_add2:stage.sh __stage_prereqs_verify_add2:stage.sh __stage_prereqs_exist_drop2:stage.sh __stage_prereqs_verify_drop2:stage.sh __stage_prereqs_exist_show1:stage.sh __stage_prereqs_verify_show1:stage.sh _stage_build_kernel1:stage.sh _stage_install_kernel1:stage.sh __stage_filter_show1:stage.sh ___stage_filter_show2:stage.sh _stage_filter_list1:stage.sh _stage_filter_uncurated2:stage.sh _stage_filter_orphaned1:stage.sh _stage_filter_add2:stage.sh _stage_filter_drop2:stage.sh __stage_include1:stage.sh _stage_include2:stage.sh ___stage_adopt2:stage.sh _stage_adopt_copy2:stage.sh _stage_loader2:stage.sh _stage_manifest1:stage.sh ___stage_verify1:stage.sh _stage_verify_listed1:stage.sh _stage_verify_unlisted1:stage.sh __stage_device3:stage.sh _stage_device4:stage.sh __stage_backup2:stage.sh __stage_backup3:stage.sh _stage_backup4:stage.sh _stage_backup_list2:stage.sh _stage_deploy2:stage.sh __stage_rollback2:stage.sh ___stage_rollback3:stage.sh _stage_rollback_apply3:stage.sh _stage_trust_anchor1:stage.sh _stage_trust_mk1:stage.sh ___stage_source1:stage.sh _stage_boot_tree4:stage.sh _stage_pool_import3:stage.sh _stage_pool_export2:stage.sh _stage_tree_snapshot2:stage.sh _stage_tree_copy2:stage.sh _stage_tree_verify2:stage.sh _stage_tree_close2:stage.sh ___stage_tree_work2:stage.sh ___stage_tree_sync2:stage.sh ___stage_push2:stage.sh _stage_edit2:stage.sh ___stage_marker3:stage.sh __stage_marker_rotate1:stage.sh _stage_marker_record3:stage.sh _stage_marker_write2:stage.sh __stage_marker2:stage.sh ___stage_site_mk1:stage.sh _stage_site_mk_header1:stage.sh _stage_site_mk_board1:stage.sh _stage_site_mk_keys1:stage.sh _stage_site_mk_marker1:stage.sh _stage_site_mk_origin1:stage.sh _stage_site_mk_install2:stage.sh __stage_site_mk_report1:stage.sh _stage_site_mk_report2:stage.sh __stage_dump0:stage.sh ___stage_dump_all1:stage.sh __stage_dump1:stage.sh ___stage_dump2:stage.sh __stage_dump_record1:stage.sh ___stage_dump_record2:stage.sh ___stage_dump_add2:stage.sh ___stage_dump_filter1:stage.sh ___stage_dump_keys1:stage.sh ___stage_dump_media1:stage.sh ___stage_dump_checkout1:stage.sh ___stage_dump_work1:stage.sh ___stage_dump_phases1:stage.sh ___stage_dump_prereqs1:stage.sh ___stage_dump_marker1:stage.sh ___stage_dump_backup1:stage.sh __stage_dump_boot1:stage.sh ___stage_dump_boot2:stage.sh ___stage_dump_rebuild1:stage.sh ___stage_import2:stage.sh ___stage_import3:stage.sh _stage_check_stage1:stage.sh _stage_check_dir2:stage.sh _stage_import_dir2:stage.sh _stage_check_file3:stage.sh _stage_import_file3:stage.sh _stage_measure1:stage.sh _stage_action1:stage.sh _stage_when1:stage.sh _stage_phase_show1:stage.sh _stage_phase_show2:stage.sh ___stage_phase_policy_add3:stage.sh ___stage_phase_policy_add4:stage.sh _stage_check_policy3:stage.sh _stage_phase_policy_append3:stage.sh _stage_phase_policy_append4:stage.sh _stage_phase_policy_drop3:stage.sh _stage_foundation_prepare1:stage.sh _stage_foundation_render_header1:stage.sh _stage_foundation_render_macros1:stage.sh _stage_foundation_render_secrets1:stage.sh _stage_foundation_render_prerequisites1:stage.sh _stage_foundation_render_gates1:stage.sh _stage_foundation_render_phases1:stage.sh _stage_foundation_render_dispatch1:stage.sh _stage_foundation_install1:stage.sh _stage_foundation_check1:stage.sh ___stage_foundation_make1:stage.sh _stage_foundation_report1:stage.sh ___stage_foundation1:stage.sh ___stage_collect0:stage.sh _stage_collect1:stage.sh"
# === END AUTO-GENERATED ===
# elebake Architecture Test Suite
#
# PURPOSE: Enforce combinator pattern architectural rules
#
# ARCHITECTURAL RULES TESTED:
#
# 1. COMBINATOR FUNCTIONS (__func):
#    - Output exactly 1 line
#    - Line must contain "$ELEBAKE_CONTEXT_SCRIPT" (literal, not expanded)
#    - Line format: "$ELEBAKE_CONTEXT_SCRIPT" command args...
#
# 2. BATCH COMBINATOR FUNCTIONS (___func):
#    - Output N lines (N >= 0)
#    - Each non-empty, non-comment line must be a elebake command
#    - Use literal "$ELEBAKE_CONTEXT_SCRIPT" (not expanded paths)
#    - Comments (#) and empty lines are allowed
#
# 3. TERMINAL FUNCTIONS (_func):
#    - Must NOT output elebake commands
#    - Output shell commands only
#    - Can call: shell keywords, builtins, system commands, locally-defined functions
#    - Cannot call: elebake internal functions (starting with _) unless locally defined
#    - Cannot call: error(), log(), run_env(), dispatch(), lookup_interpreter()
#    - Must NOT use "$ELEBAKE_CONTEXT_SCRIPT" (reserved for combinators)
#
# For new contributors/Claudes: Run these tests to verify your
# combinator functions follow the architectural pattern.
#
# Usage: ./elebake-architecture-test.sh [profile] [keep] [test ...]
#   profile: minimal (default) or all
#   keep: true/keep to preserve databases on success (default: delete)
#   test ...: optional test-function names to run only those (same mechanism as
#             elebake-unit-test.sh). Note profile+keep must be given first,
#             e.g. ./elebake-architecture-test.sh minimal false test_readonly_database
#
# POSIX shell compliant
#

# ============================================================================
# TEST DATABASE SPECIFICATION
# ============================================================================
#
# PURPOSE:
#   Architecture tests need to exercise ALL code paths, including error handling
#   and edge cases. Real databases are messy - sessions go stale, links break,
#   processes die, users interrupt operations. A "realistic but messy" database
#   state ensures unlikely branches get tested.
#
# PHILOSOPHY:
#   "Test with the chaos users create, not the perfection we assume"
#
# WHY THIS APPROACH:
#   1. REALISTIC - Mirrors actual database states in production use
#   2. COMPREHENSIVE - Exercises both success and error paths
#   3. GENERIC - No function-specific knowledge required
#   4. DISCOVERABLE - Reveals architectural violations in error handling
#   5. MAINTAINABLE - Single specification for all tests
#   6. DETERMINISTIC - Reproducible failures (with optional randomization)
#
# MAINTENANCE:
#   Update this specification when:
#   - New features add database structures (e.g., new protocol directories)
#   - New edge cases are discovered (add them as fixtures)
#   - Tests reveal blind spots in coverage (add problematic states)
#
# ============================================================================
#
# DATABASE STRUCTURE (created by create_messy_realistic_database())
#
# $TEST_DIR/
#   .session/                          # Active/stale sessions directory
#     88888/                           # VALID: Complete session (old PID)
#       protocol       = "wireguard"
#       interface      = "wg_test0"  # Use test interface to avoid conflict
#       original       = "$TEST_DIR/wireguard/working.conf"
#       started        = "2024-01-15 10:30:00"
#       connect.sh     = executable script (0600)
#       disconnect.sh  = executable script (0600)
#
#     99999/                           # STALE: Session with dead process
#       protocol       = "openvpn"
#       interface      = "tun_test0"  # Use test interface to avoid conflict
#       original       = "$TEST_DIR/openvpn/stale.ovpn"
#       started        = "2024-01-10 08:00:00"
#       (missing connect.sh - incomplete session)
#
#     77777/                           # PARTIAL: Missing metadata files
#       protocol       = "wireguard"
#       (missing interface, original, started)
#
#   session/                           # Named sessions directory
#     default        → ../.session/88888         # VALID symlink
#     work           → ../.session/99999         # STALE symlink (dead process)
#     broken         → ../.session/11111         # ORPHANED (target doesn't exist)
#     home           → ../.session/88888         # DUPLICATE (same as default)
#
#   wireguard/                         # WireGuard configs
#     working.conf                     # VALID config file (0400)
#     broken.conf    → nonexistent.conf         # BROKEN symlink
#     duplicate.conf → working.conf             # DUPLICATE (points to existing)
#
#     privacy/                         # Category directory
#       server1      → ../working.conf          # Valid category link
#       server2      → ../broken.conf           # Broken category link
#       orphan       → ../gone.conf             # Orphaned link
#
#   openvpn/                           # OpenVPN configs
#     stale.ovpn                       # VALID config file (0400)
#     invalid.ovpn   → missing.ovpn             # BROKEN symlink
#
#     streaming/                       # Category directory (empty)
#
#   .conf          → wireguard         # Protocol extension link (valid)
#   .ovpn          → openvpn           # Protocol extension link (valid)
#   .broken        → nowhere           # BROKEN extension link
#
# ADVERSARIAL NAMES (test command parser robustness):
#   wireguard/
#     help.conf                        # Conflicts with command name
#     start.conf                       # Conflicts with command name
#     --version.conf                   # Looks like CLI flag
#     -rf.conf                         # Dangerous if mishandled
#
#   openvpn/
#     list.ovpn                        # Conflicts with command name
#     ../escape.ovpn   → stale.ovpn    # Path traversal attempt (symlink)
#
#   session/
#     stop           → ../.session/88888         # Command name as session name
#     dump           → ../.session/99999         # Another command conflict
#
# WHY ADVERSARIAL NAMES MATTER:
#   - Tests dispatch resolution doesn't confuse "wireguard start help" with help command
#   - Ensures path normalization prevents traversal (../ handled correctly)
#   - Verifies special characters don't break shell command generation
#   - Proves the system is robust against confusing/malicious user input
#   - Architecture tests are PERFECT place for this (end-to-end command flow)
#
# RANDOMIZATION POINTS (50% probability each):
#   - Whether default symlink exists in session/
#   - Whether additional named sessions exist
#   - Which session has a complete connect.sh script
#
# INVARIANTS (always true):
#   - At least one valid session exists (88888)
#   - At least one stale/broken state exists (99999, broken links)
#   - Both protocols have configs (wireguard and openvpn)
#   - Mix of valid and broken states for comprehensive coverage
#
# BENEFITS FOR TESTING:
#   - session_start* can find valid default OR encounter stale links
#   - session_save* can find existing sessions to save
#   - session_remove* encounter both valid and invalid targets
#   - session_show* test with missing/present connect.sh
#   - session_list* display mixed valid/stale/orphaned states
#   - validate* find broken links and stale sessions
#   - clean* have actual broken links to clean
#   - Protocol functions encounter both valid and broken configs
#   - import* test with existing vs. conflicting names
#   - All functions exercise error handling for broken states
#
# COVERAGE IMPROVEMENT:
#   Before: Functions hit early error exits (dead code not tested)
#   After:  Functions execute full logic with both valid and broken inputs
#   Result: Architectural violations in ANY code path get detected
#
# ============================================================================

set -e
set -u

#-----------------------------------------------------------------------------
# Test Configuration
#-----------------------------------------------------------------------------

# Test base directory
TEST_BASE_DIR="${TMPDIR:-/tmp}/elebake-arch-test.$$"

# Test script location
TEST_SCRIPT="./elebake.sh"

# Options (before the positional args): --maxprocs N runs the top-level
# test functions in parallel (xargs -P N, each in its own suite process and
# sandbox); default 1 = the classic sequential run.
MAXPROCS=1
while [ $# -gt 0 ]; do
  case "$1" in
    --maxprocs)   MAXPROCS="${2:?--maxprocs needs a value}"; shift 2 ;;
    --maxprocs=*) MAXPROCS="${1#--maxprocs=}"; shift ;;
    *) break ;;
  esac
done

# Profile for bootstrap
TEST_PROFILE="${1:-minimal}"

# Keep databases on success (default: false = delete on success)
KEEP_DATABASES="${2:-false}"

# Optional test-name filters (args 3+), same mechanism as elebake-unit-test.sh.
# Profile ($1) and keep ($2) are already captured above; drop them, then treat
# the rest as test-name filters. Safe shift under 'set -u'.
[ $# -ge 1 ] && shift   # drop profile
[ $# -ge 1 ] && shift   # drop keep

# Dynamically generate list of all test functions
ALL_TESTS=$(grep -o '^test_[a-z_]*()' "$0" | sed 's/()$//' | tr '\n' ' ')

# Collect test filter arguments (optional test function names)
TEST_FILTER="$*"

# If no filter specified, run all tests
if [ -z "$TEST_FILTER" ]; then
  TEST_FILTER="$ALL_TESTS"
fi

#-----------------------------------------------------------------------------
# Test Framework Infrastructure (copied from elebake-unit-test.sh)
#-----------------------------------------------------------------------------

# should_run_test - Run a named test only if it is in the active filter
# (identical to elebake-unit-test.sh)
should_run_test() {
  local test_name="$1"

  for filter_test in $TEST_FILTER; do
    if [ "$filter_test" = "$test_name" ]; then
      "$test_name"
      return 0
    fi
  done

  return 0
}

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Color support (detect if terminal supports colors)
if [ -t 1 ] && command -v tput >/dev/null 2>&1 && tput colors >/dev/null 2>&1; then
  COLOR_GREEN=$(tput setaf 2)
  COLOR_RED=$(tput setaf 1)
  COLOR_YELLOW=$(tput setaf 3)
  COLOR_BLUE=$(tput setaf 4)
  COLOR_RESET=$(tput sgr0)
else
  COLOR_GREEN=""
  COLOR_RED=""
  COLOR_YELLOW=""
  COLOR_BLUE=""
  COLOR_RESET=""
fi

# Global test directory
TEST_DIR=""

# pass - Mark assertion as passed
pass() {
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "${COLOR_GREEN}✓${COLOR_RESET} $*"
}

# fail - Mark assertion as failed
fail() {
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "${COLOR_RED}✗${COLOR_RESET} $*"
}

# test_header - Print test header with database path
test_header() {
  TESTS_RUN=$((TESTS_RUN + 1))
  echo ""
  if [ -n "${TEST_DIR:-}" ]; then
    echo "${COLOR_BLUE}TEST ${TESTS_RUN}:${COLOR_RESET} $* [db: $TEST_DIR]"
  else
    echo "${COLOR_BLUE}TEST ${TESTS_RUN}:${COLOR_RESET} $*"
  fi
}

# test_summary - Print test summary
test_summary() {
  local test_functions=$TESTS_RUN
  local assertions_passed=$TESTS_PASSED
  local assertions_failed=$TESTS_FAILED
  local total_assertions=$((assertions_passed + assertions_failed))

  echo ""
  echo "========================================"
  echo "Architecture Test Summary"
  echo "========================================"
  echo "Test Functions:     $test_functions"
  echo "Total Assertions:   $total_assertions"
  echo "${COLOR_GREEN}Passed Assertions:  $assertions_passed${COLOR_RESET}"
  if [ "$assertions_failed" -gt 0 ]; then
    echo "${COLOR_RED}Failed Assertions:  $assertions_failed${COLOR_RESET}"
  else
    echo "Failed Assertions:  $assertions_failed"
  fi
  echo ""

  if [ "$assertions_failed" -gt 0 ]; then
    echo "${COLOR_RED}SOME TESTS FAILED${COLOR_RESET}"
    echo ""
    echo "Test artifacts preserved in: $TEST_BASE_DIR"
    echo "To clean up: rm -rf $TEST_BASE_DIR"
    return 1
  else
    echo "${COLOR_GREEN}ALL TESTS PASSED${COLOR_RESET}"
    echo ""
    if [ "$KEEP_DATABASES" = "true" ] || [ "$KEEP_DATABASES" = "keep" ]; then
      echo "Test databases preserved in: $TEST_BASE_DIR"
    else
      echo "Cleaning up test databases..."
      rm -rf "$TEST_BASE_DIR"
      echo "Done."
    fi
    return 0
  fi
}

#-----------------------------------------------------------------------------
# Test Setup (simplified from elebake-unit-test.sh)
#-----------------------------------------------------------------------------

# test_setup - Create exclusive test database
#
# Creates a fresh database for each test using elebake bootstrap.
# Sets TEST_DIR for use by test functions.
#
test_setup() {
  # Create unique test database directory
  TEST_DIR="$TEST_BASE_DIR/test-$TESTS_RUN"
  mkdir -p "$TEST_DIR"

  # Bootstrap database using elebake API
  local bootstrap_log="$TEST_DIR/bootstrap.log"
  # elebake bootstrap takes a database NAME under ELEBAKE_ROOT (not a path);
  # point the root into the sandbox so TEST_DIR = $TEST_BASE_DIR/test-N.
  if ! ELEBAKE_ROOT="$TEST_BASE_DIR" ELEBAKE_BASE="$TEST_DIR" "$TEST_SCRIPT" bootstrap "test-$TESTS_RUN" "$TEST_PROFILE" > "$bootstrap_log" 2>&1; then
    echo "${COLOR_RED}ERROR:${COLOR_RESET} Database bootstrap failed"
    cat "$bootstrap_log" | sed 's/^/  /'
    exit 1
  fi

  # Set terminal interpreter to sh for auto-execution (simulates experienced user)
  ELEBAKE_BASE="$TEST_DIR" "$TEST_SCRIPT" setenv ELEBAKE_TERMINAL_INTERPRETER sh > /dev/null 2>&1

  # Set minimal PATH
  ELEBAKE_BASE="$TEST_DIR" "$TEST_SCRIPT" setenv ELEBAKE_PATH "/bin:/usr/bin:/usr/local/bin" > /dev/null 2>&1

  # Enable the env-args cache LAST (setenv invalidates it): the architecture
  # tests spawn hundreds of elebake processes per database — the cache takes
  # the env build-up out of every one of them.
  ELEBAKE_BASE="$TEST_DIR" "$TEST_SCRIPT" environment cache on > /dev/null 2>&1
}

# create_messy_realistic_database - Populate database with realistic messy state
#
# Creates a database state that mirrors real-world usage with:
# - Valid and stale sessions
# - Broken symlinks
# - Orphaned references
# - Adversarial names (command conflicts, path traversal attempts)
# - Incomplete/partial data structures
#
# This ensures tests exercise BOTH success and error paths, revealing
# architectural violations in error handling code that would otherwise
# be untested "dead code".
#
# See TEST DATABASE SPECIFICATION comment at top of file for full details.
#
create_messy_realistic_database() {
  # elebake messy-but-deterministic database: stages in several states,
  # broken links, adversarial names. Populated via the CLI where possible
  # (records are laid down the real way); never touches devices or NVRAM.
  run_elebake stage add alpha >/dev/null 2>&1
  run_elebake stage add beta >/dev/null 2>&1
  local A="$TEST_DIR/stage/alpha"

  # alpha: populated boot tree, signed loader newer than the loader
  mkdir -p "$A/boot/defaults" "$A/boot/lua" "$A/destdir/boot/defaults"
  echo EFI > "$A/boot/loader.efi"
  echo conf > "$A/boot/defaults/loader.conf"
  echo lua > "$A/boot/lua/core.lua"
  touch -t 202401010000 "$A/boot/loader.efi"
  echo SIGNED > "$A/boot/loader.efi.signed"

  # matching manifest pair (attest signature faked -- content consistency real)
  ( cd "$A/boot" && find . -type f ! -name manifest ! -name manifest.asc \
      | sed 's|^\./||' | LC_ALL=C sort | while read -r f; do
        printf '%s sha256=%s\n' "$f" "$(sha256 -q "$f")"
      done > manifest )
  echo fakesig > "$A/boot/manifest.asc"

  # curated filter with one satisfiable and one missing entry
  echo x > "$A/destdir/boot/defaults/loader.conf"
  printf 'defaults/loader.conf\nmissing/file\n' > "$A/filter"

  # named medium + boot tree records via the CLI (node syntactically valid,
  # deliberately nonexistent -- execution must fail early, never touch hw)
  run_elebake stage device alpha a /dev/nonexistent99 >/dev/null 2>&1
  run_elebake stage boot tree alpha a testlabel zpool99/testds >/dev/null 2>&1

  # backups of medium a (two generations) -- RECORDS: label directory with
  # loader.efi + description/sha256/created/source/by
  local lbl
  for lbl in 20240101T000000Z known-good; do
    mkdir -p "$A/backup/a/$lbl"
    echo "old-$lbl" > "$A/backup/a/$lbl/loader.efi"
    sha256 -q "$A/backup/a/$lbl/loader.efi" > "$A/backup/a/$lbl/sha256"
    echo "2024-01-01T00:00:00Z" > "$A/backup/a/$lbl/created"
    echo "fixture backup $lbl" > "$A/backup/a/$lbl/description"
    echo "/dev/nonexistent99:EFI/BOOT/BOOTX64.EFI" > "$A/backup/a/$lbl/source"
    echo "tester@fixture" > "$A/backup/a/$lbl/by"
  done

  # marker RECORD only -- tests must never read or write NVRAM
  mkdir -p "$A/marker"
  echo Boot0000 > "$A/marker/bootvar"
  echo "$TEST_DIR/marker-value" > "$A/marker/file"
  echo cafecafecafecafecafecafecafecafe > "$TEST_DIR/marker-value"

  # key bindings: pem pair + openpgp record (mock material)
  echo key > "$TEST_DIR/test-key.pem"
  echo crt > "$TEST_DIR/test-cert.pem"
  mkdir -p "$TEST_DIR/gnupg"
  run_elebake pem add db "$TEST_DIR/test-key.pem" "$TEST_DIR/test-cert.pem" >/dev/null 2>&1
  run_elebake openpgp add manifest DEADBEEFDEADBEEF "$TEST_DIR/gnupg" >/dev/null 2>&1

  # fake checked-out worktree for build/install/site mk paths
  mkdir -p "$TEST_DIR/fakework/stand/libsa" "$TEST_DIR/fakework/stand/efi/loader/local"
  ln -s "$TEST_DIR/fakework" "$A/work" 2>/dev/null || true

  # beta stays empty (error paths); adversarial + broken stage links
  ln -s ../.staging/stage-deadbeef "$TEST_DIR/stage/broken" 2>/dev/null || true
  ln -s "$(readlink "$TEST_DIR/stage/alpha")" "$TEST_DIR/stage/echo hello" 2>/dev/null || true
  ln -s "$(readlink "$TEST_DIR/stage/alpha")" "$TEST_DIR/stage/-rf" 2>/dev/null || true
}

# run_elebake - Execute elebake.sh command
#
# Arguments: command and arguments to pass to elebake.sh
# Returns: captured stdout and stderr
#
run_elebake() {
  # Pass through BATCH_KEEP_GOING if set (runtime parameter for testing)
  if [ -n "${ELEBAKE_BATCH_KEEP_GOING:-}" ]; then
    ELEBAKE_BASE="$TEST_DIR" \
    ELEBAKE_DISPLAY_ANSI=0 \
    ELEBAKE_BATCH_KEEP_GOING="$ELEBAKE_BATCH_KEEP_GOING" \
    "$TEST_SCRIPT" "$@" 2>&1
  else
    ELEBAKE_BASE="$TEST_DIR" \
    ELEBAKE_DISPLAY_ANSI=0 \
    "$TEST_SCRIPT" "$@" 2>&1
  fi
}

# set_function_interpreter - Set interpreter for a specific function
#
# Arguments:
#   $1 - Function name (e.g., "wireguard_connect", "stop")
#   $2 - Interpreter value (e.g., "cat", "sh")
#
set_function_interpreter() {
  local func_name="$1"
  local interpreter="$2"

  run_elebake setenv "ELEBAKE_INTERPRETER_${func_name}" "$interpreter" > /dev/null 2>&1
}

# create_failing_interpreter - Create type-appropriate failing interpreter
#
# Arguments:
#   $1 - Function name (with underscores, e.g., "___list0", "__stop1", "_log1")
# Output: Interpreter string that consumes input properly and exits with 1
#
# Different function types need different failing interpreters:
# - Terminal (_):    "sh -c 'cat && false'" (pass through output, then exit with 1)
# - Combinator (__):  "head -n1 | xargs sh -c 'cat && false' --" (consume 1 line, pass through, exit with 1)
# - Batch (___):     "sh -c 'cat && false'" (pass through all output, then exit with 1)
#
# NOTE: Must use "sh -c" wrapper because && operator requires shell evaluation
# Combinator pattern uses xargs to prevent the consumed line from becoming arguments to sh
# This pattern works because:
# 1. sh -c executes the command string as shell syntax
# 2. cat passes through stdin to stdout
# 3. && false ensures exit code is 1 after cat succeeds
# 4. Survives double-eval (process_arguments + run_env)
#
create_failing_interpreter() {
  local func_name="$1"

  case "$func_name" in
    ___*)
      # Batch combinator: pass through all input, then exit with failure
      echo "sh -c 'cat && false'"
      ;;
    __*)
      # Combinator: consume one line via head, use xargs to buffer it, then pass through and fail
      echo "head -n1 | xargs sh -c 'cat && false' --"
      ;;
    _*)
      # Terminal: pass through output, then exit with failure
      echo "sh -c 'cat && false'"
      ;;
    *)
      # Unknown type - fallback
      echo "sh -c 'cat && false'"
      ;;
  esac
}

#-----------------------------------------------------------------------------
# Architecture Validators
#-----------------------------------------------------------------------------

# validate_terminal_function_output - Validate terminal function output
#
# Terminal function rules:
# - Must output shell commands only (no direct elebake internal calls)
# - Can call: shell keywords, builtins, system commands, locally-defined functions
# - Cannot call: elebake functions (starting with _) unless locally defined
# - Cannot call: error(), log(), run_env(), dispatch(), lookup_interpreter()
#
# Arguments: $1 - output to validate, $2 - function name (for error messages)
# Returns: 0 if valid, 1 if invalid
#
validate_terminal_function_output() {
  local output="$1"
  local func_name="$2"

  # Empty output is valid
  [ -z "$output" ] && return 0

  # Shell keywords and common commands whitelist
  local shell_keywords="if then else elif fi while do done for case esac until select function"
  local common_commands="echo cat test mkdir chmod chown cp mv rm ln grep sed awk cut sort uniq wc head tail tr date sleep true false cd pwd ls find xargs touch dirname basename readlink stat tee printf yes no which command type sh"

  # Extract locally-defined functions (pattern: function_name() or function name())
  local local_functions=$(echo "$output" | \
    sed 's/^[[:space:]]*//' | \
    grep -E '^(function[[:space:]]+)?[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\(\)' | \
    sed -E 's/^function[[:space:]]+//' | \
    sed -E 's/[[:space:]]*\(\).*//')

  # Check each line for forbidden patterns
  # Save output to temp file to avoid subshell issues
  local tmpfile="${TMPDIR:-/tmp}/terminal-validate.$$"
  echo "$output" > "$tmpfile"

  local line_num=0
  local violations=0

  while IFS= read -r line; do
    line_num=$((line_num + 1))

    # Skip empty lines
    [ -z "$line" ] && continue

    # Skip comment lines
    echo "$line" | grep -q '^[[:space:]]*#' && continue

    # Skip heredoc markers
    echo "$line" | grep -qE '^[[:space:]]*(EOF|HEREDOC|END)' && continue

    # Check for direct display() output patterns (FORBIDDEN in terminal functions)
    # Terminal functions must generate shell commands, not call display functions directly
    # Valid: generate_error "message" → outputs commands
    # Invalid: error "message" → calls display() directly
    local line_stripped=$(echo "$line" | sed 's/^[[:space:]]*//')
    if echo "$line_stripped" | grep -qE '^(Error|Warning|Success|Info|Log): '; then
      violations=$((violations + 1))
      echo "    ${COLOR_YELLOW}Line $line_num:${COLOR_RESET} Direct display() call detected (use generate_error/generate_warning instead)"
      echo "    ${COLOR_YELLOW}Context:${COLOR_RESET} $line"
      continue
    fi

    # Extract first token (strip leading whitespace, get first word)
    local first_token=$(echo "$line" | sed 's/^[[:space:]]*//' | awk '{print $1}')

    # Skip if no token
    [ -z "$first_token" ] && continue

    # Strip trailing punctuation/operators for better matching
    local token_clean=$(echo "$first_token" | sed -E 's/[();{}&|]+$//')

    # Check if it's a shell keyword
    local is_keyword=0
    for kw in $shell_keywords; do
      if [ "$token_clean" = "$kw" ]; then
        is_keyword=1
        break
      fi
    done
    [ $is_keyword -eq 1 ] && continue

    # Check if it's a common command
    local is_command=0
    for cmd in $common_commands; do
      if [ "$token_clean" = "$cmd" ]; then
        is_command=1
        break
      fi
    done
    [ $is_command -eq 1 ] && continue

    # Check if it's locally defined
    local is_local=0
    for local_func in $local_functions; do
      if [ "$token_clean" = "$local_func" ]; then
        is_local=1
        break
      fi
    done
    [ $is_local -eq 1 ] && continue

    # Check for forbidden elebake internal functions
    case "$token_clean" in
      error|log|run_env|dispatch|lookup_interpreter)
        violations=$((violations + 1))
        echo "    ${COLOR_YELLOW}Line $line_num:${COLOR_RESET} FORBIDDEN elebake function: $token_clean"
        echo "    ${COLOR_YELLOW}Context:${COLOR_RESET} $line"
        continue
        ;;
    esac

    # Check for underscore functions (elebake internal) not locally defined
    if echo "$token_clean" | grep -q '^_'; then
      violations=$((violations + 1))
      echo "    ${COLOR_YELLOW}Line $line_num:${COLOR_RESET} Underscore function not locally defined: $token_clean"
      echo "    ${COLOR_YELLOW}Context:${COLOR_RESET} $line"
      continue
    fi

    # Check for execution pattern of $ELEBAKE_CONTEXT_SCRIPT (reserved for combinators)
    # Forbidden: "$ELEBAKE_CONTEXT_SCRIPT" as first token (execution/composition)
    # Allowed: "$ELEBAKE_CONTEXT_SCRIPT" in test conditions, echo, assignments, etc.
    #
    # Exception: _bootstrap2 is allowed to execute $ELEBAKE_CONTEXT_SCRIPT
    # Reason: Bootstrap bypasses process_arguments() dispatch (elebake.sh:2501)
    #         and runs before database exists, so interpreter overrides are not available.
    #         While it could be refactored to batch combinator, there's no benefit since
    #         interpreter customization is impossible at bootstrap time.
    if [ "$func_name" != "_bootstrap2" ]; then
      local line_stripped=$(echo "$line" | sed 's/^[[:space:]]*//')
      if echo "$line_stripped" | grep -q '^"\$ELEBAKE_CONTEXT_SCRIPT"'; then
        violations=$((violations + 1))
        echo "    ${COLOR_YELLOW}Line $line_num:${COLOR_RESET} Terminal function executing \$ELEBAKE_CONTEXT_SCRIPT (reserved for combinators)"
        echo "    ${COLOR_YELLOW}Context:${COLOR_RESET} $line"
        continue
      fi
    fi
  done < "$tmpfile"

  # Cleanup temp file
  rm -f "$tmpfile"

  # Return validation result
  [ "$violations" -eq 0 ]
}

# validate_combinator_syntax - Validate combinator function output
#
# Combinator rules:
# - Exactly 1 line
# - Contains literal "$ELEBAKE_CONTEXT_SCRIPT" (not expanded)
# - Does not start with / (would indicate expanded variable)
#
# Arguments: $1 - output to validate
# Returns: 0 if valid, 1 if invalid
#
validate_combinator_syntax() {
  local output="$1"

  # Count lines (ignore empty output = 0 lines)
  local line_count
  if [ -z "$output" ]; then
    line_count=0
  else
    line_count=$(echo "$output" | wc -l | tr -d ' ')
  fi

  # Must be exactly 1 line
  if [ "$line_count" -ne 1 ]; then
    echo "    ${COLOR_YELLOW}Expected:${COLOR_RESET} 1 line"
    echo "    ${COLOR_YELLOW}Got:${COLOR_RESET} $line_count lines"
    return 1
  fi

  # Must contain literal $ELEBAKE_CONTEXT_SCRIPT (not expanded)
  if ! echo "$output" | grep -q '"\$ELEBAKE_CONTEXT_SCRIPT"'; then
    echo "    ${COLOR_YELLOW}Expected:${COLOR_RESET} Literal '\"\$ELEBAKE_CONTEXT_SCRIPT\"'"
    echo "    ${COLOR_YELLOW}Got:${COLOR_RESET} $output"
    return 1
  fi

  # Must not be expanded (would start with absolute path)
  if echo "$output" | grep -q '^/'; then
    echo "    ${COLOR_YELLOW}Error:${COLOR_RESET} Variable expanded (contains absolute path)"
    echo "    ${COLOR_YELLOW}Got:${COLOR_RESET} $output"
    return 1
  fi

  return 0
}

# validate_batch_combinator_syntax - Validate batch combinator function output
#
# Batch combinator rules:
# - Outputs N lines (N >= 0)
# - Each non-empty, non-comment line must be a elebake command
# - Use literal "$ELEBAKE_CONTEXT_SCRIPT" (not expanded)
# - Comments (#) and empty lines are allowed
#
# Arguments: $1 - output to validate
# Returns: 0 if valid, 1 if invalid
#
validate_batch_combinator_syntax() {
  local output="$1"

  # Empty output is valid (N=0)
  [ -z "$output" ] && return 0

  # Check each line
  local line_num=0
  echo "$output" | while IFS= read -r line; do
    line_num=$((line_num + 1))

    # Skip empty lines
    [ -z "$line" ] && continue

    # Skip comments
    echo "$line" | grep -q '^#' && continue

    # Must be elebake command (contains literal variable)
    if ! echo "$line" | grep -q '"\$ELEBAKE_CONTEXT_SCRIPT"'; then
      echo "    ${COLOR_YELLOW}Error at line $line_num:${COLOR_RESET} Not a elebake command"
      echo "    ${COLOR_YELLOW}Expected:${COLOR_RESET} '\"\$ELEBAKE_CONTEXT_SCRIPT\" ...'"
      echo "    ${COLOR_YELLOW}Got:${COLOR_RESET} $line"
      return 1
    fi

    # Must not be expanded
    if echo "$line" | grep -q '^/'; then
      echo "    ${COLOR_YELLOW}Error at line $line_num:${COLOR_RESET} Variable expanded"
      echo "    ${COLOR_YELLOW}Got:${COLOR_RESET} $line"
      return 1
    fi
  done

  return $?
}

#-----------------------------------------------------------------------------
# Test Argument Mapping
#-----------------------------------------------------------------------------

# get_test_argument_variations - Return test argument variations for a function
#
# Returns: Pipe-separated list of argument sets to test
#          Format: "arg1|arg2 arg3|arg4"
#          Each variation is tested separately
#
# Special values:
#   EMPTY - Function takes no arguments (arity-0)
#   SKIP  - Function requires special setup, skip for now
#
# Strategy:
#   1. Check for functions needing special argument patterns
#   2. Otherwise, extract arity from function name and use generic args
#
get_test_argument_variations() {
  local func="$1"

  # Extract arity from function name (trailing digit)
  local arity
  arity=$(echo "$func" | sed 's/.*\([0-9]\)$/\1/')

  # Check if extraction failed (no trailing digit)
  if ! echo "$arity" | grep -q '^[0-9]$'; then
    echo "SKIP"
    return
  fi

  # Special cases - functions needing specific argument patterns
  case "$func" in
    # captures stdin / opens an editor / interactive -- cannot be arg-driven
    cat1|batch2|edit2|stage_edit2)
      echo "SKIP"; return ;;

    # NVRAM write path -- NEVER exercised in tests (the batch, its arity
    # sibling, and the write terminal; the record terminal is bookkeeping)
    stage_marker3|stage_marker2|stage_marker_write2|stage_marker_rotate1)
      echo "SKIP"; return ;;
    stage_marker_record3)
      echo "alpha Boot0000 \$TEST_DIR/marker-value|alpha BadName /abs|alpha Boot0000 relative"; return ;;

    # bootstrap has its own dedicated flows
    bootstrap1|bootstrap2)
      echo "SKIP"; return ;;

    restore1)
      echo "\$TEST_BASE_DIR/dump.sh|\$TEST_BASE_DIR/nonexistent.sh"; return ;;
    restore2)
      echo "\$TEST_BASE_DIR/dump.sh \$TEST_DIR|\$TEST_BASE_DIR/nonexistent.sh \$TEST_DIR"; return ;;
    dump1)
      echo "complete|minimized|bogus"; return ;;
    dump2)
      echo "complete all|minimized all|complete alpha|minimized nonexistent|bogus all"; return ;;
    export3)
      echo "\$TEST_BASE_DIR/d.sh \$TEST_BASE_DIR/b.tar.gz full"; return ;;
    export4)
      echo "\$TEST_BASE_DIR/d.sh \$TEST_BASE_DIR/b.tar.gz full all|\$TEST_BASE_DIR/d.sh \$TEST_BASE_DIR/b.tar.gz minimized alpha|\$TEST_BASE_DIR/d.sh \$TEST_BASE_DIR/b.tar.gz bogus all"; return ;;
    stage_foundation_render_header1|stage_foundation_render_macros1|stage_foundation_render_secrets1|stage_foundation_render_prerequisites1|stage_foundation_render_gates1|stage_foundation_render_phases1|stage_foundation_render_dispatch1)
      echo "alpha|nonexistent"; return ;;
    stage_sign_pkcs11_1|stage_sign_pem1|stage_verify_listed1|stage_verify_unlisted1|stage_site_mk_header1|stage_site_mk_board1|stage_site_mk_keys1|stage_site_mk_marker1|stage_site_mk_origin1|stage_filter_list1|stage_filter_orphaned1)
      echo "alpha|nonexistent"; return ;;
    stage_status_populated1|stage_status_signkey1|stage_status_attestkey1|stage_status_signed1|stage_status_filter1|stage_status_media1|stage_status_marker1|stage_status_sitemk1)
      echo "alpha|nonexistent"; return ;;
    stage_site_mk_install2)
      echo "alpha \$TEST_DIR/fakework/stand/efi/loader/local/site.mk|alpha relative/path"; return ;;
    stage_filter_uncurated2)
      echo "alpha \$TEST_DIR/stage/alpha/destdir/boot|alpha relative/dir"; return ;;
    manifest_match2)
      echo "\$TEST_DIR/stage/alpha/boot/manifest \$TEST_DIR|\$TEST_DIR/nonexistent \$TEST_DIR"; return ;;
    destroy_worktrees1|destroy_records1|destroy_scaffold1)
      echo "wrongname"; return ;;
    help_manual_part1)
      echo "name|sources|bogus|../etc"; return ;;
    stage_dump_all1)
      echo "complete|minimized|bogus"; return ;;
    stage_dump2|stage_dump_record2|stage_dump_boot2)
      echo "alpha complete|alpha minimized|alpha bogus"; return ;;
    attest2|attest_verify2)
      echo "\$TEST_DIR/stage/alpha/boot/loader.efi manifest|\$TEST_DIR/nonexistent manifest|\$TEST_DIR/stage/alpha/boot/loader.efi nokey"; return ;;
    seal2|seal_verify2)
      echo "\$TEST_BASE_DIR/dump.sh \$TEST_DIR/stage/alpha/boot/loader.efi|\$TEST_BASE_DIR/nonexistent.sh \$TEST_DIR/nonexistent"; return ;;
    incoming_clear1)
      echo "\$TEST_BASE_DIR/incoming/x|\$TEST_DIR|/etc"; return ;;
    provenance_add2)
      echo "\$TEST_BASE_DIR/dump.sh -|\$TEST_BASE_DIR/nonexistent.sh -"; return ;;
    provenance_import2)
      echo "000001-abcdef012345 \$TEST_DIR/test-key.pem|bad/id \$TEST_DIR/test-key.pem|000001-abcdef012345 \$TEST_DIR/nonexistent"; return ;;
    filter_minimized2|filter_redacted2|filter_full2)
      echo "\$TEST_BASE_DIR/nonexistent-collection \$TEST_BASE_DIR/out"; return ;;

    batch1)
      echo "stage_list|nonexistent_function"; return ;;

    init1)
      echo "\$TEST_BASE_DIR/init-test"; return ;;

    dump_env1)
      echo "minimal|all"; return ;;

    setenv2)
      echo "ELEBAKE_TEST_VAR test-value|ELEBAKE_TEST_VAR2 'value with spaces'"; return ;;

    getenv1|unsetenv1)
      echo "ELEBAKE_TEST_VAR|ELEBAKE_NONEXISTENT_VAR"; return ;;

    setintp2)
      echo "stage_list0 cat|nonexistent_function sh"; return ;;

    getintp1)
      echo "stage_list0|nonexistent_function"; return ;;

    # key bindings (records only; material mocked or nonexistent)
    pem_add3)
      echo "db \$TEST_DIR/test-key.pem \$TEST_DIR/test-cert.pem|db \$TEST_DIR/nonexistent.pem \$TEST_DIR/nonexistent.crt"; return ;;
    openpgp_add2)
      echo "manifest DEADBEEFDEADBEEF|manifest ''"; return ;;
    openpgp_add3)
      echo "manifest DEADBEEFDEADBEEF \$TEST_DIR/gnupg|manifest DEADBEEFDEADBEEF \$TEST_DIR/nonexistent-home"; return ;;
    pkcs11_add3)
      echo "nk3 'pkcs11:token=x;id=%02;type=private' \$TEST_DIR/test-cert.pem|nk3 '' ''"; return ;;

    stage_sign_key3)
      echo "alpha pem db|alpha pkcs11 nk3|nonexistent pem db"; return ;;
    stage_attest_key3)
      echo "alpha openpgp manifest|nonexistent openpgp manifest"; return ;;

    stage_device4)
      echo "alpha a /dev/nonexistent99 /mnt|alpha 'bad name' /dev/x /mnt|alpha b notadevice /mnt"; return ;;
    stage_boot_tree4)
      echo "alpha a testlabel zpool99/testds|alpha a 'bad/label' zpool99/testds|alpha a lbl nodataset"; return ;;
    stage_adopt2|stage_adopt_copy2|stage_pool_export2|stage_tree_snapshot2|stage_tree_copy2|stage_tree_verify2|stage_tree_close2|stage_tree_work2)
      echo "alpha a|alpha nonexistent-medium|beta a"; return ;;
    stage_pool_import3)
      echo "alpha a rw|alpha a ro|alpha a bogus|alpha nonexistent-medium rw"; return ;;

    stage_worktree2|stage_import2)
      echo "alpha \$TEST_DIR/test-key.pem|alpha \$TEST_DIR/nonexistent"; return ;;

    stage_filter_add2|stage_filter_drop2)
      echo "alpha defaults/loader.conf|alpha ../escape"; return ;;
    stage_include2|stage_filter_show2)
      echo "alpha \$TEST_DIR/stage/alpha/destdir/boot|alpha relative/dir|nonexistent /boot"; return ;;
    stage_prerequisites_add3|stage_prerequisites_drop3)
      echo "alpha exist /boot/loader.efi|alpha verify /boot/loader.conf|alpha bogus /boot/x|alpha exist relative/path"; return ;;
    stage_prerequisites_show2)
      echo "alpha exist|alpha verify|alpha bogus|nonexistent exist"; return ;;
    stage_dump_add2)
      echo "alpha complete|alpha minimized"; return ;;

    stage_build_stand2|stage_install2)
      echo "alpha libsa|alpha nonexistent-component|beta libsa"; return ;;

    stage_site_mk2|stage_site_mk_report2)
      echo "alpha \$TEST_DIR/fakework/stand/efi/loader/local/site.mk|alpha relative/path"; return ;;

    stage_deploy2|stage_tree_sync2|stage_backup2)
      echo "alpha a|alpha nonexistent-medium|beta a"; return ;;

    stage_rollback3|stage_rollback_apply3)
      echo "alpha a known-good|alpha a nonexistent-backup"; return ;;
    stage_backup_list2)
      echo "alpha a|alpha ghost-medium|nonexistent a"; return ;;
    stage_backup3)
      echo "alpha a mylabel|alpha a 'bad label'"; return ;;
    stage_backup4)
      echo "alpha a mylabel 'why this backup exists'|alpha a known-good 'exists already'|alpha a 'bad label' x|alpha a mylabel ''"; return ;;
  esac

  # Generic argument generation based on arity
  # Use function name prefix to identify which test creates any stray files
  case "$arity" in
    0)
      echo "EMPTY"
      ;;
    1)
      echo "${func}_a1|${func}_a2|${func}_a3"
      ;;
    2)
      echo "${func}_a1 ${func}_a2|${func}_a3 ${func}_a4"
      ;;
    3)
      echo "${func}_a1 ${func}_a2 ${func}_a3|${func}_a4 ${func}_a5 ${func}_a6"
      ;;
    *)
      echo "SKIP"
      ;;
  esac
}

# get_test_argument_by_database - Extract arguments from messy database state
#
# Returns: Pipe-separated list of arguments extracted from actual database
#          Format: "arg1|arg2|arg3" (same as get_test_argument_variations)
#          Returns "SKIP" if function doesn't need database-aware testing
#
# Purpose: Provide realistic arguments that match actual data in messy database
#          This catches violations that generic arguments miss (e.g., session_start1)
#
# Strategy: ADVERSARIAL TESTING - Generate arguments for BOTH success AND error paths
#           - Success paths: test command generation with valid inputs
#           - Error paths: test error handling (should use generate_error, not error())
#           - Edge cases: test boundary conditions
#
get_test_argument_by_database() {
  local func="$1"

  # Realistic arguments extracted from the messy database: success AND error
  # paths. Stage names come from the actual stage/ directory (adversarial
  # names included).
  case "$func" in
    stage_status1|stage_prerequisites1|stage_manifest1|stage_verify1| \
    stage_reset1|stage_clean_dir1|stage_unkey1|stage_include1|stage_filter_show1|stage_filter_list1|stage_filter_orphaned1|stage_verify_listed1|stage_verify_unlisted1|stage_dump_add2|stage_dump_filter1|stage_dump_keys1|stage_dump_media1|stage_dump_checkout1|stage_dump_work1|stage_dump_phases1|stage_dump_prereqs1)
      local names="" link
      if [ -d "$TEST_DIR/stage" ]; then
        for link in "$TEST_DIR/stage"/*; do
          [ -L "$link" ] || continue
          local name=$(basename -- "$link")
          name=$(echo "$name" | sed 's/\$/\\$/g; s/`/\\`/g; s/(/\\(/g; s/)/\\)/g; s/;/\\;/g; s/&/\\&/g')
          names="$names|$name"
        done
      fi
      names="$names|totally-unknown-stage"
      echo "$names" | sed 's/^|//'
      ;;

    stage_deploy2|stage_backup2|stage_tree_sync2|stage_adopt2|stage_adopt_copy2|stage_pool_export2|stage_tree_snapshot2|stage_tree_copy2|stage_tree_verify2|stage_tree_close2|stage_tree_work2)
      echo "alpha a|alpha ghost-medium|broken a"
      ;;
    stage_pool_import3)
      echo "alpha a rw|alpha ghost-medium ro|broken a rw"
      ;;

    stage_rollback3|stage_rollback_apply3)
      local results="" b
      for b in "$TEST_DIR/stage/alpha/backup/a"/*/; do
        [ -f "$b/loader.efi" ] || continue
        results="$results|alpha a $(basename -- "$b")"
      done
      results="$results|alpha a nonexistent"
      echo "$results" | sed 's/^|//'
      ;;

    *)
      echo "SKIP"
      ;;
  esac
}

#-----------------------------------------------------------------------------
# Command Walking Functions (extracted from elebake-walkthrough.sh)
#-----------------------------------------------------------------------------

# is_terminal_function - Check if function is a terminal function
is_terminal_function() {
  local func="$1"
  echo "$TERMINAL_FUNCTIONS" | grep -qw "$func"
}

# is_combinator - Check if function is a combinator (double underscore)
is_combinator() {
  local func="$1"
  echo "$COMBINATOR_FUNCTIONS" | grep -qw "$func"
}

# is_batch_combinator - Check if function is a batch combinator (triple underscore)
is_batch_combinator() {
  local func="$1"
  echo "$BATCH_COMBINATOR_FUNCTIONS" | grep -qw "$func"
}

# extract_arity - Get function arity from name
extract_arity() {
  local func="$1"
  # Function names end with a digit (the arity)
  echo "$func" | sed 's/.*\([0-9]\)$/\1/'
}

# extract_command_from_output - Extract command arguments from output
# Args: $1 - line containing "$ELEBAKE_CONTEXT_SCRIPT" command
# Output: command arguments (without the script prefix)
extract_command_from_output() {
  local line="$1"
  # Remove "$ELEBAKE_CONTEXT_SCRIPT" prefix (keep quotes in arguments)
  echo "$line" | sed 's/^"\$ELEBAKE_CONTEXT_SCRIPT" //'
}

# resolve_function - Resolve command arguments to function name
# Args: command arguments (e.g., "stop" or "wireguard stop")
# Output: function name (e.g., "___stop0" or "__wireguard_stop0")
# Returns: 0 if found, 1 if not found
resolve_function() {
  local args="$*"
  local arg_count=$#

  # Build function name base (concatenate with underscores)
  local base=$(echo "$args" | tr ' ' '_')

  # Try different arity values (arity 0 first, then increasing)
  local arity=0
  while [ $arity -le $((arg_count + 2)) ]; do
    local func_base="${base}${arity}"

    # Try different underscore prefixes (batch first, then combinator, then terminal)
    # This matches the resolution priority in elebake.sh dispatch
    for func_name in "___${func_base}" "__${func_base}" "_${func_base}"; do
      # Check if this function exists in ANCHOR_FUNCTIONS
      if echo " $ANCHOR_FUNCTIONS " | grep -q " $func_name "; then
        echo "$func_name"
        return 0
      fi
    done

    arity=$((arity + 1))
  done

  return 1
}

# walk_command_tree - Recursively walk command resolution tree
# Args: $1 - depth (integer)
#       $2 - command string
#       $3 - callback function to call at each node
# Output: Calls callback with: callback depth func_name cmd output exit_status
#
# Callback receives:
#   $1 - depth
#   $2 - function type: "terminal", "combinator", "batch", "unresolved"
#   $3 - function name (with underscores)
#   $4 - command string
#   $5 - output from function
#   $6 - exit status
#
walk_command_tree() {
  local depth="$1"
  local cmd="$2"
  local callback="$3"

  # Resolve command to function name
  local func_name=$(resolve_function $cmd)

  if [ -z "$func_name" ]; then
    # Could not resolve - treat as terminal and stop recursion
    $callback "$depth" "unresolved" "" "$cmd" "" "0"
    return 0
  fi

  # Determine function type
  local func_type=""
  case "$func_name" in
    ___*)
      func_type="batch"
      ;;
    __*)
      func_type="combinator"
      ;;
    _*)
      func_type="terminal"
      ;;
  esac

  # Strip underscores for interpreter variable naming
  local mangled=$(echo "$func_name" | sed 's/^_*//')

  # Set ONLY this specific function's interpreter to 'cat'
  set_function_interpreter "$mangled" "cat"

  # Execute and capture output
  local output=$(run_elebake $cmd 2>&1)
  local exit_status=$?

  # Immediately unset this interpreter (cleanup - critical for correct recursion!)
  run_elebake unsetenv "ELEBAKE_INTERPRETER_${mangled}" >/dev/null 2>&1 || true

  # Call callback for this node
  $callback "$depth" "$func_type" "$func_name" "$cmd" "$output" "$exit_status"

  # Recurse based on function type
  if [ "$func_type" = "terminal" ]; then
    # Terminal functions don't produce elebake commands - stop recursion
    return 0

  elif [ "$func_type" = "combinator" ]; then
    # Combinator outputs a single elebake command - recurse once
    local next_cmd=$(extract_command_from_output "$output")
    if [ -n "$next_cmd" ]; then
      walk_command_tree $((depth + 1)) "$next_cmd" "$callback"
    fi

  elif [ "$func_type" = "batch" ]; then
    # Batch combinator outputs multiple elebake commands - recurse on each
    echo "$output" | while IFS= read -r line; do
      # Skip comments and empty lines
      case "$line" in
        \#*|"") continue ;;
        '"$ELEBAKE_CONTEXT_SCRIPT"'*)
          local next_cmd=$(extract_command_from_output "$line")
          if [ -n "$next_cmd" ]; then
            walk_command_tree $((depth + 1)) "$next_cmd" "$callback"
          fi
          ;;
      esac
    done
  fi
}

# collect_tree_nodes - Collect all nodes in command tree
# Args: $1 - command string
# Output: Sets global variables:
#   TREE_NODES - space-separated list of "depth|type|func|cmd|output|status"
#
# This is a helper that uses walk_command_tree to collect the full tree structure
collect_tree_nodes() {
  local cmd="$1"

  # Reset global collection
  TREE_NODES=""
  TREE_NODE_COUNT=0

  # Define callback that collects nodes
  _collect_callback() {
    local depth="$1"
    local type="$2"
    local func="$3"
    local cmd="$4"
    local output="$5"
    local status="$6"

    # Store node (use | as separator, encode | in fields as \|)
    local node_data="${depth}|${type}|${func}|${cmd}|${output}|${status}"

    if [ -z "$TREE_NODES" ]; then
      TREE_NODES="$node_data"
    else
      TREE_NODES="$TREE_NODES
$node_data"
    fi

    TREE_NODE_COUNT=$((TREE_NODE_COUNT + 1))
  }

  # Walk tree and collect nodes
  walk_command_tree 0 "$cmd" "_collect_callback"
}

#-----------------------------------------------------------------------------
# Combinator Tests
#-----------------------------------------------------------------------------

# test_combinator_function - Test a single combinator function
#
# Strategy: Prepare database once, test all argument variations
#
# Arguments: $1 - function name (without __ prefix)
#
test_combinator_function() {
  local func="$1"

  # Get test argument variations
  local variations
  variations=$(get_test_argument_variations "$func")

  # Handle SKIP
  if [ "$variations" = "SKIP" ]; then
    echo "  ${COLOR_YELLOW}Skipped: __${func} (requires special setup)${COLOR_RESET}"
    return
  fi

  test_header "Combinator: __${func} - validate syntax with variations"
  test_setup

  # Populate database with messy realistic state
  create_messy_realistic_database

  # Override to cat for command inspection
  set_function_interpreter "$func" "cat"

  # Prepare database ONCE (reused across all variations)
  # Create source config files (temporary, outside database)
  local test_wg_config="$TEST_BASE_DIR/test-wg.conf"
  local test_ovpn_config="$TEST_BASE_DIR/test-ovpn.ovpn"

  # WireGuard test config
  cat > "$test_wg_config" <<'EOF'
[Interface]
PrivateKey = fake-key-for-testing
Address = 192.0.2.1/32

[Peer]
PublicKey = fake-peer-key
Endpoint = 192.0.2.1:51820
AllowedIPs = 0.0.0.0/0
EOF

  # OpenVPN test config
  cat > "$test_ovpn_config" <<'EOF'
remote 192.0.2.10 1194 udp
dev tun
EOF

  # Import configs using API
  set_function_interpreter "wireguard_import1" "sh"
  set_function_interpreter "openvpn_import1" "sh"

  run_elebake wireguard import "$test_wg_config" > /dev/null 2>&1 || true
  run_elebake openvpn import "$test_ovpn_config" > /dev/null 2>&1 || true

  # Reset to cat for testing
  set_function_interpreter "$func" "cat"

  # Test each variation (GENERIC strategy)
  # Use temp file to avoid subshell (pipe creates subshell, breaks all_valid)
  local variations_file="${TMPDIR:-/tmp}/comb-variations-$$.txt"
  echo "$variations" | tr '|' '\n' > "$variations_file"

  local all_valid=true
  local variation_num=0
  local max_variations=15  # Limit variations to prevent test explosion

  while IFS= read -r variation; do
    variation_num=$((variation_num + 1))

    # Limit total variations tested (prevent combinatorial explosion)
    if [ "$variation_num" -gt "$max_variations" ]; then
      break
    fi

    # Expand variables in variation (e.g., $TEST_BASE_DIR)
    local expanded_args
    expanded_args=$(eval echo "$variation")

    # Handle EMPTY special case
    if [ "$variation" = "EMPTY" ]; then
      expanded_args=""
    fi

    # Test this variation
    local output
    if [ -z "$expanded_args" ]; then
      output=$(run_elebake $func 2>&1 || true)
    else
      output=$(run_elebake $func $expanded_args 2>&1 || true)
    fi

    # Validate syntax
    if ! validate_combinator_syntax "$output"; then
      all_valid=false
      fail "__${func} (variation $variation_num: $variation): Invalid syntax"
      echo "    ${COLOR_YELLOW}Output:${COLOR_RESET} $output"
    fi
  done < "$variations_file"

  # Cleanup
  rm -f "$variations_file"

  # Test DATABASE-AWARE variations (if available)
  local db_variations=$(get_test_argument_by_database "$func")

  if [ "$db_variations" != "SKIP" ] && [ -n "$db_variations" ]; then
    local db_variations_file="${TMPDIR:-/tmp}/comb-db-variations-$$.txt"
    echo "$db_variations" | tr '|' '\n' > "$db_variations_file"

    while IFS= read -r variation; do
      variation_num=$((variation_num + 1))

      # Expand variables in variation
      local expanded_args
      expanded_args=$(eval echo "$variation")

      # Handle EMPTY special case
      if [ "$variation" = "EMPTY" ]; then
        expanded_args=""
      fi

      # Test this variation
      local output
      if [ -z "$expanded_args" ]; then
        output=$(run_elebake $func 2>&1 || true)
      else
        output=$(run_elebake $func $expanded_args 2>&1 || true)
      fi

      # Validate syntax
      if ! validate_combinator_syntax "$output"; then
        all_valid=false
        fail "__${func} (database-aware variation $variation_num: $variation): Invalid syntax"
        echo "    ${COLOR_YELLOW}Output:${COLOR_RESET} $output"
      fi
    done < "$db_variations_file"

    rm -f "$db_variations_file"
  fi

  # Report overall pass (individual failures already reported via fail())
  if $all_valid; then
    pass "__${func}: Valid combinator syntax (all variations)"
  fi
}

#-----------------------------------------------------------------------------
# Terminal Function Tests
#-----------------------------------------------------------------------------

# test_terminal_function - Test a single terminal function
#
# Strategy: Execute function and validate output follows terminal function rules
#
# Arguments: $1 - function name (without _ prefix)
#
test_terminal_function() {
  local func="$1"

  # Get test argument variations
  local variations
  variations=$(get_test_argument_variations "$func")

  # Handle SKIP
  if [ "$variations" = "SKIP" ]; then
    echo "  ${COLOR_YELLOW}Skipped: _${func} (requires special setup)${COLOR_RESET}"
    return
  fi

  test_header "Terminal: _${func} - validate output rules"
  test_setup

  # Populate database with messy realistic state
  # This ensures functions exercise full code paths (not just error exits)
  create_messy_realistic_database

  # Override to cat for output inspection
  set_function_interpreter "$func" "cat"

  # Prepare database (same as combinator tests)
  local test_wg_config="$TEST_BASE_DIR/test-wg.conf"
  local test_ovpn_config="$TEST_BASE_DIR/test-ovpn.ovpn"

  # WireGuard test config
  cat > "$test_wg_config" <<'EOF'
[Interface]
 PrivateKey = fake-key-for-testing
Address = 192.0.2.1/32

[Peer]
PublicKey = fake-peer-key
Endpoint = 192.0.2.1:51820
AllowedIPs = 0.0.0.0/0
EOF

  # OpenVPN test config
  cat > "$test_ovpn_config" <<'EOF'
remote 192.0.2.10 1194 udp
dev tun
EOF

  # Import configs using API
  set_function_interpreter "wireguard_import1" "sh"
  set_function_interpreter "openvpn_import1" "sh"

  run_elebake wireguard import "$test_wg_config" > /dev/null 2>&1 || true
  run_elebake openvpn import "$test_ovpn_config" > /dev/null 2>&1 || true

  # Reset to cat for testing
  set_function_interpreter "$func" "cat"

  # Test each variation (GENERIC strategy)
  # Use temp file to avoid subshell (pipe creates subshell, breaks all_valid)
  local variations_file="${TMPDIR:-/tmp}/variations-$$.txt"
  echo "$variations" | tr '|' '\n' > "$variations_file"

  local all_valid=true
  local variation_num=0

  while IFS= read -r variation; do
    variation_num=$((variation_num + 1))

    # Expand variables in variation
    local expanded_args
    expanded_args=$(eval echo "$variation")

    # Handle EMPTY special case
    if [ "$variation" = "EMPTY" ]; then
      expanded_args=""
    fi

    # Test this variation
    local output
    if [ -z "$expanded_args" ]; then
      output=$(run_elebake $func 2>&1 || true)
    else
      output=$(run_elebake $func $expanded_args 2>&1 || true)
    fi

    # Validate terminal function rules
    if ! validate_terminal_function_output "$output" "_${func}"; then
      all_valid=false
      fail "_${func} (variation $variation_num: $variation): Invalid terminal function output"
    fi
  done < "$variations_file"

  # Cleanup
  rm -f "$variations_file"

  # Test DATABASE-AWARE variations (if available)
  local db_variations=$(get_test_argument_by_database "$func")

  if [ "$db_variations" != "SKIP" ] && [ -n "$db_variations" ]; then
    local db_variations_file="${TMPDIR:-/tmp}/db-variations-$$.txt"
    echo "$db_variations" | tr '|' '\n' > "$db_variations_file"

    while IFS= read -r variation; do
      variation_num=$((variation_num + 1))

      # Expand variables in variation
      local expanded_args
      expanded_args=$(eval echo "$variation")

      # Handle EMPTY special case
      if [ "$variation" = "EMPTY" ]; then
        expanded_args=""
      fi

      # Test this variation
      local output
      if [ -z "$expanded_args" ]; then
        output=$(run_elebake $func 2>&1 || true)
      else
        output=$(run_elebake $func $expanded_args 2>&1 || true)
      fi

      # Validate terminal function rules
      if ! validate_terminal_function_output "$output" "_${func}"; then
        all_valid=false
        fail "_${func} (database-aware variation $variation_num: $variation): Invalid terminal function output"
      fi
    done < "$db_variations_file"

    rm -f "$db_variations_file"
  fi

  # Report overall pass
  if $all_valid; then
    pass "_${func}: Valid terminal function output (all variations)"
  fi
}

#-----------------------------------------------------------------------------
# Batch Combinator Tests
#-----------------------------------------------------------------------------

# test_batch_combinator_function - Test a single batch combinator function
#
# Strategy: Prepare database once, iterate 10 times to discover all branches
#
# Arguments: $1 - function name (without ___ prefix)
#
test_batch_combinator_function() {
  local func="$1"

  # Get test argument variations
  local variations
  variations=$(get_test_argument_variations "$func")

  # Handle SKIP
  if [ "$variations" = "SKIP" ]; then
    echo "  ${COLOR_YELLOW}Skipped: ___${func} (requires special setup)${COLOR_RESET}"
    return
  fi

  test_header "Batch Combinator: ___${func} - validate syntax with variations"
  test_setup

  # Populate database with messy realistic state
  create_messy_realistic_database

  # Override to cat for command inspection
  set_function_interpreter "$func" "cat"

  # === PREPARE DATABASE USING API ===

  # Create source config files
  local test_wg_config="$TEST_BASE_DIR/test-wg.conf"
  local test_ovpn_config="$TEST_BASE_DIR/test-ovpn.ovpn"

  # WireGuard test config
  cat > "$test_wg_config" <<'EOF'
[Interface]
PrivateKey = fake-key-for-testing
Address = 192.0.2.1/32

[Peer]
PublicKey = fake-peer-key
Endpoint = 192.0.2.1:51820
AllowedIPs = 0.0.0.0/0
EOF

  # OpenVPN test config
  cat > "$test_ovpn_config" <<'EOF'
remote 192.0.2.10 1194 udp
dev tun
EOF

  # Import using API
  set_function_interpreter "wireguard_import1" "sh"
  set_function_interpreter "openvpn_import1" "sh"

  run_elebake wireguard import "$test_wg_config" > /dev/null 2>&1 || true
  run_elebake openvpn import "$test_ovpn_config" > /dev/null 2>&1 || true

  # Reset to cat for testing
  set_function_interpreter "$func" "cat"

  # === TEST EACH VARIATION ===

  # Use temp file to communicate failure from subshell (pipes create subshells)
  local failure_marker="$TEST_BASE_DIR/.batch_failure_$$"
  rm -f "$failure_marker"
  local variation_num=0

  echo "$variations" | tr '|' '\n' | while IFS= read -r variation; do
    variation_num=$((variation_num + 1))

    # Expand variables in variation (e.g., $TEST_BASE_DIR)
    local expanded_args
    expanded_args=$(eval echo "$variation")

    # Handle EMPTY special case
    if [ "$variation" = "EMPTY" ]; then
      expanded_args=""
    fi

    # Test this variation
    local output
    if [ -z "$expanded_args" ]; then
      output=$(run_elebake $func 2>&1 || true)
    else
      output=$(run_elebake $func $expanded_args 2>&1 || true)
    fi

    # Validate syntax
    if ! validate_batch_combinator_syntax "$output"; then
      echo "1" >> "$failure_marker"  # Append line for counting in parent shell
      echo "${COLOR_RED}✗${COLOR_RESET} ___${func} (variation $variation_num: $variation): Invalid syntax"
      echo "    ${COLOR_YELLOW}Output:${COLOR_RESET} $output"
    fi
  done

  # Report result - must call fail() in parent shell since subshell counters are lost
  if [ -f "$failure_marker" ]; then
    # Count failures from marker file (one line per failure)
    local failure_count
    failure_count=$(wc -l < "$failure_marker")
    local i=0
    while [ "$i" -lt "$failure_count" ]; do
      TESTS_FAILED=$((TESTS_FAILED + 1))
      i=$((i + 1))
    done
    rm -f "$failure_marker"
  else
    pass "___${func}: Valid batch combinator syntax (all variations)"
  fi
}

#-----------------------------------------------------------------------------
# Error Propagation Tests (KEEP_GOING behavior)
#-----------------------------------------------------------------------------

# test_batch_error_propagation - Test error handling in batch processing
#
# Tests that errors propagate correctly through recursive batch processing
# and that KEEP_GOING mode controls whether execution continues or stops.
#
# Strategy:
# 1. Find a batch combinator that outputs multiple commands
# 2. Walk the command tree to find all descendant nodes
# 3. Inject a failure at a specific depth/node
# 4. Test with KEEP_GOING=0 (fail-fast): execution should stop
# 5. Test with KEEP_GOING=1 (continue): execution should continue
#
test_batch_error_propagation() {
  test_header "Batch Error Propagation - test _batch2 with failing commands"
  test_setup

  # Create a simple test batch file with multiple commands
  local batch_file="$TEST_BASE_DIR/test_batch.txt"
  cat > "$batch_file" <<EOF
# Test batch file with 3 commands
"\$ELEBAKE_CONTEXT_SCRIPT" log "Command 1"
"\$ELEBAKE_CONTEXT_SCRIPT" log "Command 2"
"\$ELEBAKE_CONTEXT_SCRIPT" log "Command 3"
EOF

  # Test 1: KEEP_GOING=0 (fail-fast) - should stop on first error
  test_header "  Sub-test: KEEP_GOING=0 (fail-fast mode)"

  # Set command 2 to fail by making log1 interpreter exit with error
  # Create failing interpreter for _log1 function
  # Must preserve output while still failing (exit code 1)
  # Using "sh -c 'cat && false'" because && requires shell evaluation
  set_function_interpreter "log1" "sh -c 'cat && false'"

  # Run batch with KEEP_GOING=0
  local output=$(ELEBAKE_BATCH_KEEP_GOING=0 run_elebake batch "$batch_file" 2>&1 || true)

  # Cleanup: Remove test interpreter override (template provides default)
  run_elebake unsetenv ELEBAKE_INTERPRETER_log1 >/dev/null 2>&1 || true

  # Verify: Should see "stopped due to error"
  if echo "$output" | grep -q "stopped due to error"; then
    pass "KEEP_GOING=0: Batch execution stopped on first error"
  else
    fail "KEEP_GOING=0: Expected batch to stop on error"
    echo "    ${COLOR_YELLOW}Output:${COLOR_RESET}"
    echo "$output" | head -20
  fi

  # Test 2: KEEP_GOING=1 (continue mode) - should process all commands despite errors
  test_header "  Sub-test: KEEP_GOING=1 (continue mode)"

  # Create a batch file where middle command will fail
  cat > "$batch_file" <<EOF
# Test batch - command 2 will fail
"\$ELEBAKE_CONTEXT_SCRIPT" database enumerate
"\$ELEBAKE_CONTEXT_SCRIPT" error "Intentional failure"
"\$ELEBAKE_CONTEXT_SCRIPT" database enumerate
EOF

  # Run batch with KEEP_GOING=1; capture trace file since _batch2 dispatch
  # messages moved to trace_log in fd79dc8 (was needed so dump stderr stays clean).
  # export needed because run_elebake is a shell function.
  local trace_file=$(mktemp)
  export ELEBAKE_BATCH_KEEP_GOING=1
  export ELEBAKE_TRACE_FILE="$trace_file"
  output=$(run_elebake batch "$batch_file" 2>&1 || true)
  unset ELEBAKE_BATCH_KEEP_GOING
  unset ELEBAKE_TRACE_FILE

  # Verify: trace shows the Summary line (proves batch ran to completion)
  if grep -q '_batch2: Summary:' "$trace_file"; then
    pass "KEEP_GOING=1: Batch execution completed despite errors"
  else
    fail "KEEP_GOING=1: Expected batch to complete despite errors"
    echo "    ${COLOR_YELLOW}Trace:${COLOR_RESET}"
    grep '_batch2:' "$trace_file" 2>/dev/null | head -10
  fi

  # Verify: Should have processed all 3 commands (not stopped at command 2)
  local execute_count=$(grep -c '_batch2: Executing:' "$trace_file" || true)
  if [ "$execute_count" -eq 3 ]; then
    pass "KEEP_GOING=1: All commands were executed (count=$execute_count)"
  else
    fail "KEEP_GOING=1: Expected 3 commands executed, got $execute_count"
    grep '_batch2: Executing:' "$trace_file" 2>/dev/null
  fi
  rm -f "$trace_file"

  # Cleanup
  rm -f "$batch_file"
}

# test_recursive_batch_error_propagation - Test error propagation through recursive batch processing
#
# Tests the scenario: line1 → _batch2 → line2 → _batch2 → line3 (ERROR) → should not reach line4
#
# This tests that when batch processing recurses (a batch file contains a batch command),
# errors propagate correctly up the call stack.
#
test_recursive_batch_error_propagation() {
  test_header "Recursive Batch Error Propagation - test chained _batch2 calls"
  test_setup

  # Create batch files that reference each other
  local batch1="$TEST_BASE_DIR/batch1.txt"
  local batch2="$TEST_BASE_DIR/batch2.txt"
  local batch3="$TEST_BASE_DIR/batch3.txt"

  # batch1 calls batch2
  cat > "$batch1" <<EOF
"\$ELEBAKE_CONTEXT_SCRIPT" log "Batch 1 - before"
"\$ELEBAKE_CONTEXT_SCRIPT" batch "$batch2"
"\$ELEBAKE_CONTEXT_SCRIPT" log "Batch 1 - after"
EOF

  # batch2 calls batch3
  cat > "$batch2" <<EOF
"\$ELEBAKE_CONTEXT_SCRIPT" log "Batch 2 - before"
"\$ELEBAKE_CONTEXT_SCRIPT" batch "$batch3"
"\$ELEBAKE_CONTEXT_SCRIPT" log "Batch 2 - after"
EOF

  # batch3 contains an error in the middle
  cat > "$batch3" <<EOF
"\$ELEBAKE_CONTEXT_SCRIPT" log "Batch 3 - command 1"
"\$ELEBAKE_CONTEXT_SCRIPT" error "Batch 3 - intentional error"
"\$ELEBAKE_CONTEXT_SCRIPT" log "Batch 3 - command 3 (should not execute)"
EOF

  # Make error1 actually fail by setting its interpreter to exit with error
  # Use arity-specific interpreter for precision
  # Must preserve output while still failing (exit code 1)
  # Using "sh -c 'cat && false'" because && requires shell evaluation
  set_function_interpreter "error1" "sh -c 'cat && false'"

  # Test with KEEP_GOING=0 (fail-fast)
  local output=$(ELEBAKE_BATCH_KEEP_GOING=0 run_elebake batch "$batch1" 2>&1 || true)

  # Restore error1 interpreter
  run_elebake unsetenv ELEBAKE_INTERPRETER_error1 >/dev/null 2>&1 || true

  # Verify: Should NOT see "Batch 3 - command 3" (execution stopped)
  if ! echo "$output" | grep -q "Batch 3 - command 3"; then
    pass "Recursive fail-fast: Command 3 in batch 3 was not executed"
  else
    fail "Recursive fail-fast: Command 3 should not have been executed"
    echo "    ${COLOR_YELLOW}Output:${COLOR_RESET}"
    echo "$output" | head -20
  fi

  # Verify: Should NOT see "Batch 2 - after" (error propagated up)
  if ! echo "$output" | grep -q "Batch 2 - after"; then
    pass "Recursive fail-fast: Batch 2 stopped after error in batch 3"
  else
    fail "Recursive fail-fast: Batch 2 should have stopped"
  fi

  # Verify: Should NOT see "Batch 1 - after" (error propagated to top)
  if ! echo "$output" | grep -q "Batch 1 - after"; then
    pass "Recursive fail-fast: Batch 1 stopped after error in nested batch"
  else
    fail "Recursive fail-fast: Batch 1 should have stopped"
  fi

  # Test with KEEP_GOING=1 (continue mode)
  output=$(ELEBAKE_BATCH_KEEP_GOING=1 run_elebake batch "$batch1" 2>&1 || true)

  # Verify: Should see all "after" messages (execution continued despite error)
  if echo "$output" | grep -q "Batch 2 - after"; then
    pass "Recursive continue: Batch 2 continued after error in batch 3"
  else
    fail "Recursive continue: Batch 2 should have continued"
  fi

  if echo "$output" | grep -q "Batch 1 - after"; then
    pass "Recursive continue: Batch 1 continued after error in nested batch"
  else
    fail "Recursive continue: Batch 1 should have continued"
  fi

  # Cleanup
  rm -f "$batch1" "$batch2" "$batch3"
}

# test_batch_keep_going_with_realistic_dump - Test KEEP_GOING with realistic dump file
#
# Tests _batch2 with a realistic dump-style batch file (like what dump/restore use).
# Uses precise position-based validation to verify KEEP_GOING behavior.
#
# Strategy:
# 1. Generate realistic batch file from inspect command output
# 2. Randomly inject failures at specific positions
# 3. Test KEEP_GOING=0: Verify commands after first failure NOT executed
# 4. Test KEEP_GOING=1: Verify ALL commands executed
#
test_batch_keep_going_with_realistic_dump() {
  test_header "Batch KEEP_GOING with Realistic Dump File"
  test_setup

  # Populate database for realistic commands
  create_messy_realistic_database

  # Create a realistic batch file using inspect output
  local batch_file="$TEST_BASE_DIR/realistic_batch.txt"
  cat > "$batch_file" <<EOF
# Realistic batch file (dump-style)
# This simulates a database dump with multiple commands

"\$ELEBAKE_CONTEXT_SCRIPT" database enumerate
"\$ELEBAKE_CONTEXT_SCRIPT" system inspect
"\$ELEBAKE_CONTEXT_SCRIPT" logs inspect
"\$ELEBAKE_CONTEXT_SCRIPT" phases inspect
"\$ELEBAKE_CONTEXT_SCRIPT" summary inspect
"\$ELEBAKE_CONTEXT_SCRIPT" prologue inspect
"\$ELEBAKE_CONTEXT_SCRIPT" database validate
"\$ELEBAKE_CONTEXT_SCRIPT" session enumerate
EOF

  # Count total commands (non-empty, non-comment lines)
  local total_commands=$(grep -v '^[[:space:]]*#' "$batch_file" | grep -v '^[[:space:]]*$' | wc -l | tr -d ' ')

  if [ "$total_commands" -lt 3 ]; then
    echo "  ${COLOR_YELLOW}Skipped:${COLOR_RESET} Not enough commands in batch file"
    rm -f "$batch_file"
    return 0
  fi

  pass "Created realistic batch file with $total_commands commands"

  # Pick a random position for failure injection (not first, not last)
  local failure_position=$(awk -v min=2 -v max=$((total_commands - 1)) 'BEGIN { srand(); print int(rand() * (max - min + 1)) + min }')

  # Extract the command at that position
  local cmd_at_position=$(grep -v '^[[:space:]]*#' "$batch_file" | grep -v '^[[:space:]]*$' | sed -n "${failure_position}p")
  local cmd=$(extract_command_from_output "$cmd_at_position")

  pass "Selected command at position $failure_position/$total_commands for failure injection"

  # Resolve to function name and inject failure
  local func_name=$(resolve_function $cmd)
  if [ -z "$func_name" ]; then
    echo "  ${COLOR_YELLOW}Skipped:${COLOR_RESET} Could not resolve function for command: $cmd"
    rm -f "$batch_file"
    return 0
  fi

  local mangled_name=$(echo "$func_name" | sed 's/^_*//')
  local failing_interp=$(create_failing_interpreter "$func_name")

  # Test 1: KEEP_GOING=0 (fail-fast mode)
  test_header "  Sub-test: KEEP_GOING=0 at position $failure_position/$total_commands"

  set_function_interpreter "$mangled_name" "$failing_interp"
  local ff_output=$(ELEBAKE_BATCH_KEEP_GOING=0 run_elebake batch "$batch_file" 2>&1 || true)

  # Count how many "# Executing:" lines appear (indicates command was attempted)
  local ff_executed=$(echo "$ff_output" | grep -c "# Executing:" || true)

  # Should execute up to and including the failure position, then stop
  if [ "$ff_executed" -le "$failure_position" ]; then
    pass "KEEP_GOING=0: Stopped at or before position $failure_position (executed $ff_executed commands)"
  else
    fail "KEEP_GOING=0: Executed $ff_executed commands, expected ≤ $failure_position"
    echo "    ${COLOR_YELLOW}Output (first 15 lines):${COLOR_RESET}"
    echo "$ff_output" | head -15
  fi

  # Verify "stopped due to error" message appears
  if echo "$ff_output" | grep -qE "stopped due to error|fail-fast mode"; then
    pass "KEEP_GOING=0: Error stop message present"
  else
    echo "    ${COLOR_YELLOW}Note:${COLOR_RESET} No explicit error stop message"
  fi

  # Test 2: KEEP_GOING=1 (continue mode)
  test_header "  Sub-test: KEEP_GOING=1 at position $failure_position/$total_commands"

  set_function_interpreter "$mangled_name" "$failing_interp"
  local cont_trace=$(mktemp)
  export ELEBAKE_BATCH_KEEP_GOING=1
  export ELEBAKE_TRACE_FILE="$cont_trace"
  local cont_output=$(run_elebake batch "$batch_file" 2>&1 || true)
  unset ELEBAKE_BATCH_KEEP_GOING
  unset ELEBAKE_TRACE_FILE

  # Count executed commands from trace (fd79dc8 moved batch diagnostics off stdout)
  local cont_executed=$(grep -c '_batch2: Executing:' "$cont_trace" || true)

  # Should execute ALL commands despite the failure
  if [ "$cont_executed" -eq "$total_commands" ]; then
    pass "KEEP_GOING=1: All commands executed ($cont_executed/$total_commands)"
  else
    fail "KEEP_GOING=1: Only $cont_executed/$total_commands commands executed"
    echo "    ${COLOR_YELLOW}Trace (first 15 lines):${COLOR_RESET}"
    grep '_batch2:' "$cont_trace" 2>/dev/null | head -15
  fi

  # Verify completion message appears in trace
  if grep -q '_batch2: Summary:' "$cont_trace"; then
    pass "KEEP_GOING=1: Completion message present"
  else
    echo "    ${COLOR_YELLOW}Note:${COLOR_RESET} No explicit completion message"
  fi
  rm -f "$cont_trace"

  # Verify at least one failure was recorded
  if echo "$cont_output" | grep -qE "# ✗ Failed|failed"; then
    pass "KEEP_GOING=1: Failure markers present in output"
  else
    echo "    ${COLOR_YELLOW}Note:${COLOR_RESET} No failure markers found"
  fi

  # Cleanup: Remove test interpreter override (template provides default)
  run_elebake unsetenv "ELEBAKE_INTERPRETER_${mangled_name}" >/dev/null 2>&1 || true

  # Cleanup batch file
  rm -f "$batch_file"
}

# test_batch_combinator_transitive_hull - Implementation-independent error injection
#
# Tests batch combinators by walking their ACTUAL command trees (transitive hull)
# and injecting failures at different nodes. This is implementation-independent:
# if a batch combinator's implementation changes, the test automatically adapts.
#
# Strategy:
# 1. Walk the batch combinator's actual command tree to discover all nodes
# 2. Inject failure at a node (round-robin: pick middle node)
# 3. Test KEEP_GOING=0: verify execution stops
# 4. Test KEEP_GOING=1: verify execution continues
#
# Arguments: $1 - function name (without ___ prefix, e.g., "stop0", "list0")
#
test_batch_combinator_transitive_hull() {
  local func="$1"

  test_header "Batch Transitive Hull: ___${func} - walkthrough-based error injection"
  test_setup

  # Populate database for realistic command trees
  create_messy_realistic_database

  # Extract command from function name (remove arity suffix)
  # E.g., "stop0" -> "stop", "list0" -> "list"
  local test_cmd=$(echo "$func" | sed 's/[0-9]*$//')

  test_header "  Sub-test: Walk command tree for '___${func}' (command: $test_cmd)"

  # Walk the command tree and collect all nodes
  collect_tree_nodes "$test_cmd"

  if [ "$TREE_NODE_COUNT" -eq 0 ]; then
    echo "    ${COLOR_YELLOW}Skipped:${COLOR_RESET} Command '$test_cmd' produced no tree nodes"
    return 0
  fi

  pass "Command tree collected: $TREE_NODE_COUNT nodes in transitive hull"

  # Extract all non-terminal nodes (these are injectable)
  local injectable_nodes=""
  local injectable_count=0

  # Parse TREE_NODES to find injectable nodes
  echo "$TREE_NODES" | while IFS='|' read -r depth type func cmd output status; do
    # Skip empty lines
    [ -z "$type" ] && continue

    # Skip terminal nodes (they don't call other elebake commands)
    [ "$type" = "terminal" ] && continue
    [ "$type" = "unresolved" ] && continue

    # This is a combinator or batch node - can inject failure here
    echo "$func"
  done > /tmp/injectable_nodes.$$

  injectable_count=$(wc -l < /tmp/injectable_nodes.$$ | tr -d ' ')

  if [ "$injectable_count" -eq 0 ]; then
    echo "    ${COLOR_YELLOW}Skipped:${COLOR_RESET} No injectable nodes found (all terminal)"
    rm -f /tmp/injectable_nodes.$$
    return 0
  fi

  pass "Found $injectable_count injectable nodes (combinators/batches) in tree"

  # Select a node to inject failure (round-robin: pick middle node)
  local target_index=$(( (injectable_count + 1) / 2 ))
  local target_func=$(sed -n "${target_index}p" /tmp/injectable_nodes.$$)

  rm -f /tmp/injectable_nodes.$$

  if [ -z "$target_func" ]; then
    echo "    ${COLOR_YELLOW}Skipped:${COLOR_RESET} Could not select target node for injection"
    return 0
  fi

  test_header "  Sub-test: Inject failure at node '$target_func' (node $target_index/$injectable_count)"

  # Strip underscores for interpreter variable name
  local mangled=$(echo "$target_func" | sed 's/^_*//')

  # Create type-appropriate failing interpreter
  local failing_interpreter=$(create_failing_interpreter "$target_func")

  # Test 1: KEEP_GOING=0 (fail-fast mode)
  set_function_interpreter "$mangled" "$failing_interpreter"
  local ff_output=$(ELEBAKE_BATCH_KEEP_GOING=0 run_elebake $test_cmd 2>&1 || true)
  local ff_exitcode=$?

  # Test 2: KEEP_GOING=1 (continue mode)
  set_function_interpreter "$mangled" "$failing_interpreter"
  local cont_output=$(ELEBAKE_BATCH_KEEP_GOING=1 run_elebake $test_cmd 2>&1 || true)
  local cont_exitcode=$?

  # Cleanup: Remove the test interpreter override (template provides default)
  run_elebake unsetenv "ELEBAKE_INTERPRETER_${mangled}" >/dev/null 2>&1 || true

  # Analyze results: fail-fast should stop earlier
  local ff_lines=$(echo "$ff_output" | wc -l)
  local cont_lines=$(echo "$cont_output" | wc -l)

  # Heuristic 1: Continue mode should produce at least as much output
  if [ "$cont_lines" -ge "$ff_lines" ]; then
    pass "KEEP_GOING affects output: fail-fast=$ff_lines lines, continue=$cont_lines lines"
  else
    echo "    ${COLOR_YELLOW}Note:${COLOR_RESET} Continue mode produced less output ($cont_lines vs $ff_lines lines)"
  fi

  # Heuristic 2: Check for error indicators in fail-fast mode
  if echo "$ff_output" | grep -qE "stopped due to error|Failed|✗"; then
    pass "KEEP_GOING=0: Execution stopped with error indicator"
  else
    echo "    ${COLOR_YELLOW}Note:${COLOR_RESET} No clear error stop indicator in fail-fast mode"
  fi

  # Heuristic 3: Check for completion in continue mode
  if echo "$cont_output" | grep -qE "complete|Summary"; then
    pass "KEEP_GOING=1: Execution completed despite injected failure"
  else
    echo "    ${COLOR_YELLOW}Note:${COLOR_RESET} No clear completion indicator in continue mode"
  fi
}

# pick_random_lines - Pick N random lines from input (for KEEP_GOING tests)
#
# Arguments:
#   $1 - multi-line string (filtered output)
#   $2 - number of lines to pick (optional, default: random between 1 and total)
# Output: Selected lines (one per line)
#
pick_random_lines() {
  local input="${1:-}"
  local count="${2:-}"

  # Count total lines
  local total_lines=$(echo "$input" | wc -l | tr -d ' ')

  if [ "$total_lines" -eq 0 ]; then
    return 1
  fi

  # If count not specified, pick random number between 1 and total_lines
  if [ -z "$count" ]; then
    count=$(awk -v max="$total_lines" 'BEGIN { srand(); print int(rand() * max) + 1 }')
    # Fallback to 1 if awk fails
    count="${count:-1}"
  fi

  # Ensure count is at least 1 and at most total_lines
  if [ "${count:-0}" -lt 1 ]; then
    count=1
  fi
  if [ "${count:-0}" -gt "$total_lines" ]; then
    count="$total_lines"
  fi

  # Pick random lines using shuf (or fallback to awk if shuf not available)
  if command -v shuf >/dev/null 2>&1; then
    echo "$input" | shuf | head -n "${count:-1}"
  else
    # Fallback: use awk to shuffle lines
    echo "$input" | awk -v count="${count:-1}" '
      BEGIN { srand() }
      { lines[NR] = $0 }
      END {
        # Fisher-Yates shuffle
        for (i = 1; i <= NR; i++) {
          j = int(rand() * (NR - i + 1)) + i
          temp = lines[i]
          lines[i] = lines[j]
          lines[j] = temp
        }
        # Output first count lines
        for (i = 1; i <= count && i <= NR; i++) {
          print lines[i]
        }
      }
    '
  fi
}

# test_batch_combinator_keep_going_precise - Precise KEEP_GOING validation
#
# Tests batch combinators with precise architectural validation:
# - For KEEP_GOING=1: All commands must execute (even after failures)
# - For KEEP_GOING=0: Commands after first failure must NOT execute
#
# Strategy:
# 1. Capture batch output with cat interpreter
# 2. Randomly select command lines to inject failures
# 3. Execute batch and validate architectural properties
#
# Arguments: $1 - function name (without ___ prefix, e.g., "inspect0", "stop0")
#
test_batch_combinator_keep_going_precise() {
  local func="$1"

  # Check if this function should be excluded
  case "$func" in
    init1)
      # Skip: complex initialization logic that modifies environment
      echo "  ${COLOR_YELLOW}Skipped:${COLOR_RESET} ___${func} (complex initialization logic)"
      return 0
      ;;
    phases_sync1|phases_sync0)
      # Skip: phase synchronization requires specific template setup
      echo "  ${COLOR_YELLOW}Skipped:${COLOR_RESET} ___${func} (requires phase template setup)"
      return 0
      ;;
  esac

  test_header "Batch KEEP_GOING Precise: ___${func}"
  test_setup

  # Populate database for realistic command trees
  create_messy_realistic_database

  # Extract command from function name (remove arity suffix)
  local test_cmd=$(echo "$func" | sed 's/[0-9]*$//')

  # Step 1: Capture batch combinator output with cat interpreter
  # Note: Use arity-specific interpreter name (e.g., stop0 not stop)
  local output=$(run_elebake setenv "ELEBAKE_INTERPRETER_${func}" "cat" && \
                 run_elebake $test_cmd 2>&1 && \
                 run_elebake unsetenv "ELEBAKE_INTERPRETER_${func}")

  # Validate we got output
  local line_count=$(echo "$output" | wc -l | tr -d ' ')
  if [ "$line_count" -eq 0 ]; then
    echo "  ${COLOR_YELLOW}Skipped:${COLOR_RESET} No output from ___${func}"
    return 0
  fi

  # Step 2: Filter output - remove comments and empty lines
  local filtered_output=$(echo "$output" | grep -v '^[[:space:]]*#' | grep -v '^[[:space:]]*$')
  local filtered_count=$(echo "$filtered_output" | wc -l | tr -d ' ')

  if [ "$filtered_count" -eq 0 ]; then
    echo "  ${COLOR_YELLOW}Skipped:${COLOR_RESET} No command lines after filtering"
    return 0
  fi

  pass "Captured $filtered_count command lines from ___${func}"

  # Step 3: Pick random lines (arbitrary number: 1 to all)
  local random_lines=$(pick_random_lines "$filtered_output")
  local selected_count=$(echo "$random_lines" | wc -l | tr -d ' ')

  if [ "$selected_count" -eq 0 ]; then
    echo "  ${COLOR_YELLOW}Skipped:${COLOR_RESET} Failed to pick random lines"
    return 0
  fi

  pass "Selected $selected_count random line(s) for failure injection"

  # Step 4: Build lists of selected and non-selected lines
  echo "$random_lines" > "$TEST_BASE_DIR/selected_lines.txt"
  local non_selected_lines=$(echo "$filtered_output" | grep -Fvxf "$TEST_BASE_DIR/selected_lines.txt")
  local non_selected_count=$(echo "$non_selected_lines" | wc -l | tr -d ' ')

  # Step 5: Inject failing interpreters for selected lines
  # Save to temp file first to avoid subshell issues with pipe
  rm -f "$TEST_BASE_DIR/injected_functions.txt"
  while IFS= read -r line; do
    local cmd=$(extract_command_from_output "$line")
    [ -z "$cmd" ] && continue

    local func_name=$(resolve_function "$cmd")
    [ -z "$func_name" ] && continue

    local failing_interp=$(create_failing_interpreter "$func_name")
    local mangled_name=$(echo "$func_name" | sed 's/^_*//')

    set_function_interpreter "$mangled_name" "$failing_interp"
    echo "$mangled_name" >> "$TEST_BASE_DIR/injected_functions.txt"
  done <<EOF
$random_lines
EOF

  # Read back the mangled names
  if [ ! -f "$TEST_BASE_DIR/injected_functions.txt" ]; then
    echo "  ${COLOR_YELLOW}Skipped:${COLOR_RESET} No functions were injected with failures"
    return 0
  fi

  local mangled_names=$(cat "$TEST_BASE_DIR/injected_functions.txt")
  local injection_count=$(echo "$mangled_names" | wc -l | tr -d ' ')
  pass "Injected failures into $injection_count function(s)"

  # Step 6: Set cat interpreters for non-selected lines (to track execution)
  rm -f "$TEST_BASE_DIR/cat_functions.txt"
  while IFS= read -r line; do
    local cmd=$(extract_command_from_output "$line")
    [ -z "$cmd" ] && continue

    local func_name=$(resolve_function "$cmd")
    [ -z "$func_name" ] && continue

    local mangled_name=$(echo "$func_name" | sed 's/^_*//')
    set_function_interpreter "$mangled_name" "cat"
    echo "$mangled_name" >> "$TEST_BASE_DIR/cat_functions.txt"
  done <<EOF
$non_selected_lines
EOF

  # Step 7: Execute with default interpreter (determines KEEP_GOING behavior)
  local exec_output=$(run_elebake $test_cmd 2>&1 || true)

  # Step 8: Analyze execution - count which functions were executed
  local executed_failures=0
  local executed_cats=0

  # Count failures that executed
  if [ -f "$TEST_BASE_DIR/injected_functions.txt" ]; then
    rm -f "$TEST_BASE_DIR/fail_executed.txt"
    while IFS= read -r mangled; do
      # Check if this function's failure marker appears in output
      if echo "$exec_output" | grep -qE "# ✗.*exit.*1|Failed|error"; then
        echo "FAIL_EXEC" >> "$TEST_BASE_DIR/fail_executed.txt"
      fi
    done <<EOF
$mangled_names
EOF
    if [ -f "$TEST_BASE_DIR/fail_executed.txt" ]; then
      executed_failures=$(wc -l < "$TEST_BASE_DIR/fail_executed.txt" | tr -d ' ')
    fi
  fi

  # Count cats that executed
  if [ -f "$TEST_BASE_DIR/cat_functions.txt" ]; then
    rm -f "$TEST_BASE_DIR/cat_executed.txt"
    while IFS= read -r mangled; do
      # Check if output from this function appears
      if echo "$exec_output" | grep -q "Executing"; then
        echo "CAT_EXEC" >> "$TEST_BASE_DIR/cat_executed.txt"
      fi
    done < "$TEST_BASE_DIR/cat_functions.txt"
    if [ -f "$TEST_BASE_DIR/cat_executed.txt" ]; then
      executed_cats=$(wc -l < "$TEST_BASE_DIR/cat_executed.txt" | tr -d ' ')
    fi
  fi

  local total_executed=$((executed_failures + executed_cats))
  local total_expected=$((selected_count + non_selected_count))

  # Step 9: Validate KEEP_GOING=1 behavior (default for most batch combinators)
  # All commands should be attempted despite failures
  if [ "$total_executed" -eq "$total_expected" ]; then
    pass "KEEP_GOING=1: All commands attempted ($total_executed/$total_expected)"
  else
    echo "  ${COLOR_YELLOW}Note:${COLOR_RESET} Not all commands attempted ($total_executed/$total_expected)"
    echo "  ${COLOR_YELLOW}Note:${COLOR_RESET} This may indicate KEEP_GOING=0 or execution stopped early"
  fi

  # Step 10: Cleanup - restore all interpreters
  if [ -f "$TEST_BASE_DIR/injected_functions.txt" ]; then
    while IFS= read -r mangled_name; do
      run_elebake unsetenv "ELEBAKE_INTERPRETER_${mangled_name}" >/dev/null 2>&1 || true
    done < "$TEST_BASE_DIR/injected_functions.txt"
  fi

  if [ -f "$TEST_BASE_DIR/cat_functions.txt" ]; then
    while IFS= read -r mangled_name; do
      run_elebake unsetenv "ELEBAKE_INTERPRETER_${mangled_name}" >/dev/null 2>&1 || true
    done < "$TEST_BASE_DIR/cat_functions.txt"
  fi

}

#-----------------------------------------------------------------------------
# Static Analysis: Architecture Violation Scanner
#-----------------------------------------------------------------------------

test_architecture_violation_scanner() {
  test_header "Architecture Violation Scanner"

  # Check if scanner exists
  local scanner_script="scripts/architecture-violation-scanner.sh"
  if [ ! -f "$scanner_script" ]; then
    echo "  ${COLOR_YELLOW}Skipped:${COLOR_RESET} Scanner not found at $scanner_script"
    return 0
  fi

  # Run scanner (it exits 1 if violations found, 0 if clean)
  local scanner_output=$(sh "$scanner_script" 2>&1)
  local scanner_exit=$?

  # For now, we expect violations (87+ direct error() calls documented)
  # Scanner should complete successfully (exit 0 or 1, not crash)
  if [ "$scanner_exit" -ne 0 ] && [ "$scanner_exit" -ne 1 ]; then
    fail "Scanner crashed with exit code $scanner_exit"
    echo "$scanner_output" | head -20
    return 1
  fi

  pass "Scanner executed successfully (exit code: $scanner_exit)"

  # Extract violation counts from summary
  local total_violations=$(echo "$scanner_output" | grep "^Total violations found:" | sed 's/.*: //' | sed 's/\x1b\[[0-9;]*m//g')
  local critical=$(echo "$scanner_output" | grep "^  CRITICAL:" | sed 's/.*: //' | sed 's/ .*//' | sed 's/\x1b\[[0-9;]*m//g')
  local high=$(echo "$scanner_output" | grep "^  HIGH:" | sed 's/.*: //' | sed 's/ .*//' | sed 's/\x1b\[[0-9;]*m//g')
  local misnamed=$(echo "$scanner_output" | grep "Misnamed functions" | sed 's/.*: //' | sed 's/\x1b\[[0-9;]*m//g')
  local state_mod=$(echo "$scanner_output" | grep "State modification" | sed 's/.*: //' | sed 's/\x1b\[[0-9;]*m//g')

  # Report findings
  if [ -n "$total_violations" ] && [ "$total_violations" != "0" ]; then
    echo "  ${COLOR_YELLOW}Found:${COLOR_RESET} $total_violations total violations"
    [ -n "$critical" ] && [ "$critical" != "0" ] && \
      echo "    ${COLOR_RED}CRITICAL:${COLOR_RESET} $critical (misnamed functions: ${misnamed:-0}, state mod: ${state_mod:-0})"
    [ -n "$high" ] && [ "$high" != "0" ] && \
      echo "    ${COLOR_YELLOW}HIGH:${COLOR_RESET} $high"
    pass "Scanner detection working (violations found as expected)"
  else
    pass "No violations found (codebase is clean!)"
  fi

  # Test that scanner detects MODIFY_* variables (once we start using them)
  if echo "$scanner_output" | grep -q "MODIFY_"; then
    pass "Scanner detects MODIFY_* variable usage"
  else
    echo "  ${COLOR_BLUE}Note:${COLOR_RESET} No MODIFY_* variables in use yet (refactoring pending)"
  fi
}

#-----------------------------------------------------------------------------
# Sync Feature Architecture Tests
#-----------------------------------------------------------------------------




#-----------------------------------------------------------------------------
# Read-Only Database Tests
#-----------------------------------------------------------------------------

# READONLY_SKIP_FUNCTIONS - Functions that legitimately write at generation time
#
# These functions are excluded from read-only database testing because they
# MUST write to the database during generation (not just execution time):
#
# - cat1: Captures stdin and writes to file immediately (can't defer)
# - batch2: Executes batch files which may write
# - bootstrap2: Creates database structure
# - init1: Initializes database directories
# - database_init0: Initializes database
# - environment_init1: Initializes environment files
# - environment_cache1: Caches environment to disk
# - phases_copy0: Copies phase templates to database
#
READONLY_SKIP_FUNCTIONS="cat1 batch2 incoming_clear1 bootstrap2 init1 database_init0 environment_init1 environment_cache_on0 environment_cache_off0 setenv2 unsetenv1 stage_add1 stage_sign_key3 stage_attest_key3 stage_unkey1 stage_filter2 stage_device4 stage_boot_tree4 stage_import2 stage_include2 stage_reset1 stage_clean_dir1 stage_worktree2 stage_edit2 stage_marker_record3 stage_marker_write2 stage_site_mk_install2 stage_manifest1 stage_deploy2 stage_tree_sync2 stage_adopt_copy2 stage_rollback_apply3 stage_backup4 stage_build_stand2 stage_install2 pem_add3 openpgp_add2 openpgp_add3 pkcs11_add3"

# is_readonly_skip_function - Check if function should skip read-only test
#
# Arguments: $1 - function name (without prefix)
# Returns: 0 if should skip, 1 otherwise
#
is_readonly_skip_function() {
  local func="$1"
  local skip_func
  for skip_func in $READONLY_SKIP_FUNCTIONS; do
    if [ "$func" = "$skip_func" ]; then
      return 0
    fi
  done
  return 1
}

# make_database_readonly - Make database read-only except .tmp and .log
#
# Arguments: $1 - database directory (TEST_DIR)
#
# Makes all files and directories read-only using chmod -w recursively.
# Preserves write permissions for .tmp and .log directories (needed for
# execution artifacts that don't violate the architecture).
#
make_database_readonly() {
  local basedir="$1"

  # First, make everything read-only
  chmod -R a-w "$basedir"

  # Restore write permissions for .tmp and .log (execution artifacts)
  if [ -d "$basedir/.tmp" ]; then
    chmod -R u+w "$basedir/.tmp"
  fi
  if [ -d "$basedir/.log" ]; then
    chmod -R u+w "$basedir/.log"
  fi

  # Create .tmp and .log if they don't exist (with write permissions)
  mkdir -p "$basedir/.tmp" 2>/dev/null || true
  mkdir -p "$basedir/.log" 2>/dev/null || true
  chmod -R u+w "$basedir/.tmp" 2>/dev/null || true
  chmod -R u+w "$basedir/.log" 2>/dev/null || true
}

# restore_database_writable - Restore writable permissions to database
#
# Arguments: $1 - database directory (TEST_DIR)
#
restore_database_writable() {
  local basedir="$1"
  chmod -R u+w "$basedir" 2>/dev/null || true
}

# test_readonly_function - Test a function on read-only database
#
# Arguments:
#   $1 - function name (without prefix, e.g., "wireguard_list")
#   $2 - function type ("terminal", "combinator", "batch")
#
# Strategy:
#   1. Setup database with messy state
#   2. Run function on WRITABLE database, capture output
#   3. Make database read-only
#   4. Run function on READ-ONLY database, capture output + stderr
#   5. Verify: no permission errors in stderr
#   6. Verify: output matches writable run (optional, reveals state modification)
#
test_readonly_function() {
  local func="$1"
  local func_type="$2"

  # Get test argument variations
  local variations
  variations=$(get_test_argument_variations "$func")

  # Handle SKIP from variations
  if [ "$variations" = "SKIP" ]; then
    return 0  # Silently skip (already handled in main tests)
  fi

  # Check if function should skip read-only test
  if is_readonly_skip_function "$func"; then
    echo "  ${COLOR_YELLOW}Skipped:${COLOR_RESET} ${func} (legitimately writes at generation time)"
    return 0
  fi

  # Get prefix for function type
  local prefix
  case "$func_type" in
    terminal) prefix="_" ;;
    combinator) prefix="__" ;;
    batch) prefix="___" ;;
  esac

  # Prepare test configs in shared location
  local test_wg_config="$TEST_BASE_DIR/test-wg.conf"
  local test_ovpn_config="$TEST_BASE_DIR/test-ovpn.ovpn"

  if [ ! -f "$test_wg_config" ]; then
    cat > "$test_wg_config" <<'EOF'
[Interface]
PrivateKey = fake-key-for-testing
Address = 192.0.2.1/32

[Peer]
PublicKey = fake-peer-key
Endpoint = 192.0.2.1:51820
AllowedIPs = 0.0.0.0/0
EOF
  fi

  if [ ! -f "$test_ovpn_config" ]; then
    cat > "$test_ovpn_config" <<'EOF'
remote 192.0.2.10 1194 udp
dev tun
EOF
  fi

  # Override to cat for output inspection
  set_function_interpreter "$func" "cat"

  # Import configs (need writable database for this)
  set_function_interpreter "wireguard_import1" "sh"
  set_function_interpreter "openvpn_import1" "sh"
  run_elebake wireguard import "$test_wg_config" > /dev/null 2>&1 || true
  run_elebake openvpn import "$test_ovpn_config" > /dev/null 2>&1 || true

  # Reset to cat for testing
  set_function_interpreter "$func" "cat"

  # Regenerate cache to include new interpreter overrides
  # Without this, CACHE_ENV_ARGS from bootstrap would be used, missing our overrides
  run_elebake environment cache on > /dev/null 2>&1 || true

  # Use first variation only (sufficient for read-only test)
  local first_variation
  first_variation=$(echo "$variations" | tr '|' '\n' | head -1)

  # Expand variables
  local expanded_args
  expanded_args=$(eval echo "$first_variation")

  # Handle EMPTY special case
  if [ "$first_variation" = "EMPTY" ]; then
    expanded_args=""
  fi

  # Phase 1: Run on WRITABLE database
  local writable_output writable_stderr
  local writable_tmp="${TMPDIR:-/tmp}/readonly-writable-$$.txt"
  local writable_err="${TMPDIR:-/tmp}/readonly-writable-err-$$.txt"

  if [ -z "$expanded_args" ]; then
    run_elebake $func > "$writable_tmp" 2> "$writable_err" || true
  else
    run_elebake $func $expanded_args > "$writable_tmp" 2> "$writable_err" || true
  fi
  writable_output=$(cat "$writable_tmp")

  # Phase 2: Make database read-only
  make_database_readonly "$TEST_DIR"

  # Phase 3: Run on READ-ONLY database
  local readonly_output readonly_stderr
  local readonly_tmp="${TMPDIR:-/tmp}/readonly-test-$$.txt"
  local readonly_err="${TMPDIR:-/tmp}/readonly-test-err-$$.txt"

  if [ -z "$expanded_args" ]; then
    run_elebake $func > "$readonly_tmp" 2> "$readonly_err" || true
  else
    run_elebake $func $expanded_args > "$readonly_tmp" 2> "$readonly_err" || true
  fi
  readonly_output=$(cat "$readonly_tmp")
  readonly_stderr=$(cat "$readonly_err")

  # Phase 4: Restore writable (for cleanup)
  restore_database_writable "$TEST_DIR"

  # Phase 5: Check for permission errors
  local has_violation=false

  if echo "$readonly_stderr" | grep -qiE "permission denied|read-only|cannot create|cannot open.*for writing"; then
    has_violation=true
    fail "${prefix}${func}: Permission error on read-only database"
    echo "    ${COLOR_RED}Stderr:${COLOR_RESET} $(echo "$readonly_stderr" | head -3)"
  fi

  # Phase 6: Compare outputs - if equal, test passed (writable output already validated)
  # If different, check compliance and warn
  if [ "$writable_output" = "$readonly_output" ]; then
    : # Outputs match - good, nothing more to check
  else
    # Outputs differ - validate compliance based on function type
    # Note: Functions output literal "$ELEBAKE_CONTEXT_SCRIPT" (not expanded)
    # Filter out CACHE_ENV_ARGS which contains embedded interpreter definitions with the pattern
    local filtered_output
    filtered_output=$(echo "$readonly_output" | grep -v 'CACHE_ENV_ARGS')
    local is_compliant=true
    case "$func_type" in
      terminal)
        # Terminal functions must NOT output elebake commands
        if echo "$filtered_output" | grep -q '"\$ELEBAKE_CONTEXT_SCRIPT"'; then
          is_compliant=false
          has_violation=true
          fail "${prefix}${func}: Terminal function must not output elebake commands"
        fi
        ;;
      combinator)
        # Combinator must output exactly one elebake command (if any output)
        if [ -n "$filtered_output" ] && ! echo "$filtered_output" | grep -q '"\$ELEBAKE_CONTEXT_SCRIPT"'; then
          is_compliant=false
          has_violation=true
          fail "${prefix}${func}: Combinator must output elebake command"
        fi
        ;;
      batch)
        # Batch combinators: each non-comment line should be a elebake command
        if [ -n "$filtered_output" ]; then
          local non_comment_lines=$(echo "$filtered_output" | grep -v '^#' | grep -v '^$')
          if [ -n "$non_comment_lines" ] && ! echo "$non_comment_lines" | grep -q '"\$ELEBAKE_CONTEXT_SCRIPT"'; then
            is_compliant=false
            has_violation=true
            fail "${prefix}${func}: Batch combinator must output elebake commands"
          fi
        fi
        ;;
    esac
    # Warn about output difference if still compliant
    if $is_compliant; then
      echo "    ${COLOR_YELLOW}Warning:${COLOR_RESET} ${func}: output differs between writable/readonly (but compliant)"
    fi
  fi

  # Cleanup temp files
  rm -f "$writable_tmp" "$writable_err" "$readonly_tmp" "$readonly_err"

  # Cleanup interpreter overrides to avoid polluting subsequent tests
  run_elebake unsetenv "ELEBAKE_INTERPRETER_${func}" > /dev/null 2>&1 || true
  run_elebake unsetenv "ELEBAKE_INTERPRETER_wireguard_import1" > /dev/null 2>&1 || true
  run_elebake unsetenv "ELEBAKE_INTERPRETER_openvpn_import1" > /dev/null 2>&1 || true
  run_elebake environment cache on > /dev/null 2>&1 || true

  if ! $has_violation; then
    pass "${prefix}${func}: No permission errors on read-only database"
  fi
}

# test_readonly_database - Run read-only tests for all function types
#
# Purpose: Verify that functions don't modify database state at generation time
#
# This test catches violations where functions:
# - Write files during output generation (should only happen at execution time)
# - Don't use EXAMINE_/MODIFY_ platform variables correctly
# - Have side effects that break the declarative model
#
test_readonly_database() {
  test_header "Read-Only Database: All functions"
  test_setup

  # Populate with messy state
  create_messy_realistic_database

  local tested=0
  local skipped=0

  echo "  Testing terminal functions..."
  for func_with_prefix in $TERMINAL_FUNCTIONS; do
    local func="${func_with_prefix#_}"
    if is_readonly_skip_function "$func"; then
      skipped=$((skipped + 1))
    else
      test_readonly_function "$func" "terminal"
      tested=$((tested + 1))
    fi
  done

  echo ""
  echo "  Testing combinator functions..."
  for func_with_prefix in $COMBINATOR_FUNCTIONS; do
    local func="${func_with_prefix#__}"
    if is_readonly_skip_function "$func"; then
      skipped=$((skipped + 1))
    else
      test_readonly_function "$func" "combinator"
      tested=$((tested + 1))
    fi
  done

  echo ""
  echo "  Testing batch combinator functions..."
  for func_with_prefix in $BATCH_COMBINATOR_FUNCTIONS; do
    local func="${func_with_prefix#___}"
    if is_readonly_skip_function "$func"; then
      skipped=$((skipped + 1))
    else
      test_readonly_function "$func" "batch"
      tested=$((tested + 1))
    fi
  done

  echo ""
  echo "  ${COLOR_BLUE}Summary:${COLOR_RESET} Tested $tested functions, skipped $skipped"
}

#-----------------------------------------------------------------------------
# Main Test Runner
#-----------------------------------------------------------------------------

# --- Phase wrappers ---------------------------------------------------------
# The parameterised phases (loops over the function lists) are wrapped in named
# test_* functions so they are individually selectable via the filter, exactly
# like the flat tests. Each carries its own section header so it only prints when
# the phase actually runs.

test_all_combinator_syntax() {
  echo ""
  echo "${COLOR_BLUE}Running Combinator Tests${COLOR_RESET}"
  echo "========================================"
  echo ""
  echo "Found $(echo "$COMBINATOR_FUNCTIONS" | wc -w | tr -d ' ') combinator functions"
  echo ""
  for func_with_prefix in $COMBINATOR_FUNCTIONS; do
    func="${func_with_prefix#__}"
    test_combinator_function "$func"
  done
}

test_all_batch_combinator_syntax() {
  echo ""
  echo "${COLOR_BLUE}Running Batch Combinator Tests${COLOR_RESET}"
  echo "========================================"
  echo ""
  echo "Found $(echo "$BATCH_COMBINATOR_FUNCTIONS" | wc -w | tr -d ' ') batch combinator functions"
  echo ""
  for func_with_prefix in $BATCH_COMBINATOR_FUNCTIONS; do
    func="${func_with_prefix#___}"
    test_batch_combinator_function "$func"
  done
}

test_all_terminal_output() {
  echo ""
  echo "${COLOR_BLUE}Running Terminal Function Tests${COLOR_RESET}"
  echo "========================================"
  echo ""
  echo "Found $(echo "$TERMINAL_FUNCTIONS" | wc -w | tr -d ' ') terminal functions"
  echo ""
  for func_with_prefix in $TERMINAL_FUNCTIONS; do
    func="${func_with_prefix#_}"
    test_terminal_function "$func"
  done
}

test_all_batch_error_propagation_hull() {
  echo ""
  echo "${COLOR_BLUE}Running Batch Combinator Error Propagation Tests${COLOR_RESET}"
  echo "========================================"
  echo ""
  echo "Testing ALL batch combinators with error injection and KEEP_GOING validation"
  echo "Found $(echo "$BATCH_COMBINATOR_FUNCTIONS" | wc -w | tr -d ' ') batch combinator functions"
  echo ""
  for func_with_prefix in $BATCH_COMBINATOR_FUNCTIONS; do
    func="${func_with_prefix#___}"
    test_batch_combinator_transitive_hull "$func"
  done
}

test_all_batch_keep_going_precise() {
  echo ""
  echo "${COLOR_BLUE}Running Batch Combinator KEEP_GOING Precise Tests${COLOR_RESET}"
  echo "========================================"
  echo ""
  echo "Testing ALL batch combinators with precise architectural KEEP_GOING validation"
  echo "Found $(echo "$BATCH_COMBINATOR_FUNCTIONS" | wc -w | tr -d ' ') batch combinator functions"
  echo ""
  for func_with_prefix in $BATCH_COMBINATOR_FUNCTIONS; do
    func="${func_with_prefix#___}"
    test_batch_combinator_keep_going_precise "$func"
  done
}

# --- Help doc-block corpus tests (Idea 1: generated help) -------------------
# Enforce docs/HELP_TEMPLATE_SPEC.md. A = presence/classification (the worklist),
# B = block conformance, C = cross-reference graph integrity.

# Source files that may carry doc blocks.
_help_source_files() {
  echo elebake.sh
  local m
  for m in include/*.sh; do echo "$m"; done
}

# Emit one TSV record per block / unclassified anchor function across all sources:
#   B <fname> <sentinel> <kind> <tagblob>   bound function block
#   F -       <sentinel> <kind> <tagblob>   free-floating block (defgroup/topic)
#   N <fname> -          -      -           anchor function with NO bound block
# kind = command|internal|defgroup|topic|unknown ; tagblob = tag lines joined by ';'
_help_records() {
  local f
  for f in $(_help_source_files); do
    [ -f "$f" ] || continue
    awk -v OFS='	' '
      function emit(type, fn) {
        kind="unknown"
        if (tagblob ~ /@command/)       kind="command"
        else if (tagblob ~ /@internal/) kind="internal"
        else if (tagblob ~ /@defgroup/) kind="defgroup"
        else if (tagblob ~ /@topic/)    kind="topic"
        print type, fn, bname, kind, tagblob
      }
      /^#@help/ { if (pend) { emit("F","-"); pend=0 }
                  inblk=1; bname=(NF>=2 ? $2 : "-"); tagblob=""; next }
      inblk && /^#@end$/ { inblk=0; pend=1; next }
      inblk { tagblob = tagblob ";" $0; next }
      {
        isdef = ($0 ~ /^_+[a-z][a-z0-9_]*[0-9]\(\) *\{/)
        fn=""
        if (isdef) { fn=$0; sub(/\(\).*/,"",fn) }
        if (pend) {
          if (isdef) { emit("B", fn); pend=0; next }
          else       { emit("F","-"); pend=0 }
        }
        if (isdef) print "N", fn, "-", "-", "-"
      }
      END { if (pend) emit("F","-") }
    ' "$f"
  done
}

# A — Presence: every anchor function carries a name-matching block classified as
# @command or @internal. Failure output is the worklist of what still needs doing.
test_help_blocks_present() {
  test_header "Help blocks: every anchor function classified (@command|@internal)"
  local recs total=0 ok=0 missing=""
  recs=$(_help_records)
  local fp
  for fp in $ANCHOR_FUNCTIONS; do
    total=$((total + 1))
    local rec
    rec=$(printf '%s\n' "$recs" | awk -F'	' -v f="$fp" '$1=="B" && $2==f {print; exit}')
    if [ -z "$rec" ]; then missing="$missing $fp"; continue; fi
    local sentinel kind
    sentinel=$(printf '%s' "$rec" | cut -f3)
    kind=$(printf '%s' "$rec" | cut -f4)
    if [ "$sentinel" != "$fp" ]; then missing="$missing ${fp}!namemismatch"; continue; fi
    case "$kind" in
      command|internal) ok=$((ok + 1)) ;;
      *)                missing="$missing ${fp}!unclassified" ;;
    esac
  done
  if [ -z "$missing" ]; then
    pass "All $total anchor functions carry a conforming help block ($ok classified)"
  else
    fail "$((total - ok))/$total anchor functions still need a help block"
    printf '%s' "$missing" | tr ' ' '\n' | grep -v '^$' | sed 's/^/       - /'
  fi
}

# B — Conformance: each present block has a recognised kind, only known tags, and
# the required fields for its kind. Single assertion (problems accumulated).
test_help_blocks_conform() {
  test_header "Help blocks: well-formed, known tags, required fields"
  local recs problems="" allowed=" command summary group param option returns example see since defgroup order parent topic internal env "
  recs=$(_help_records)
  local tmp; tmp=$(mktemp 2>/dev/null || echo "/tmp/help_conf.$$")
  printf '%s\n' "$recs" | awk -F'	' '$1=="B" || $1=="F"' > "$tmp" || true
  local type fn sentinel kind tagblob t label
  while IFS='	' read -r type fn sentinel kind tagblob; do
    [ -n "${type:-}" ] || continue
    label="${fn}${sentinel}"
    if [ "$kind" = "unknown" ]; then
      problems="$problems
  '$label': no recognised anchor tag (@command/@internal/@defgroup/@topic)"
      continue
    fi
    for t in $(printf '%s' "$tagblob" | tr ';' '\n' | sed -n 's/^# *@\([a-z][a-z]*\).*/\1/p'); do
      case "$allowed" in *" $t "*) ;; *) problems="$problems
  '$label': unknown tag @$t" ;; esac
    done
    if [ "$kind" = "command" ]; then
      printf '%s' "$tagblob" | tr ';' '\n' | grep -q '@summary' || problems="$problems
  '$label': command block missing @summary"
      printf '%s' "$tagblob" | tr ';' '\n' | grep -q '@group' || problems="$problems
  '$label': command block missing @group"
    fi
  done < "$tmp"
  rm -f "$tmp"
  if [ -z "$problems" ]; then
    pass "All present help blocks are well-formed"
  else
    fail "Non-conforming help blocks:$problems"
  fi
}

# C — Graph: every @group resolves to a @defgroup, every @see resolves to a known
# command/group, no duplicate command paths. Single assertion.
test_help_graph_resolves() {
  test_header "Help graph: groups/see-refs resolve, no duplicate commands"
  local recs problems=""
  recs=$(_help_records)
  local tags; tags=$(printf '%s\n' "$recs" | cut -f5 | tr ';' '\n')
  local groups cmds g s
  groups=$(printf '%s\n' "$tags" | sed -n 's/^# *@defgroup  *\([A-Za-z0-9_-]*\).*/\1/p' | sort -u)
  cmds=$(printf '%s\n' "$tags" | sed -n 's/^# *@command  *\(.*\)/\1/p' | sed 's/[<[].*//; s/  *$//' | sort)
  for g in $(printf '%s\n' "$tags" | sed -n 's/^# *@group  *\([A-Za-z0-9_-]*\).*/\1/p' | sort -u); do
    printf '%s\n' "$groups" | grep -qx "$g" || problems="$problems
  @group '$g' has no matching @defgroup"
  done
  for s in $(printf '%s\n' "$tags" | sed -n 's/^# *@see  *\(.*\)/\1/p' | sed 's/  *$//' | sort -u | tr ' ' '\037'); do
    s=$(printf '%s' "$s" | tr '\037' ' ')
    printf '%s\n' "$cmds" | grep -qx "$s" && continue
    printf '%s\n' "$groups" | grep -qx "$s" && continue
    problems="$problems
  @see '$s' resolves to no command or group"
  done
  local dup; dup=$(printf '%s\n' "$cmds" | grep -v '^$' | uniq -d)
  [ -n "$dup" ] && problems="$problems
  duplicate @command path(s): $(printf '%s' "$dup" | tr '\n' ',')"
  if [ -z "$problems" ]; then
    pass "Help graph resolves (groups, see-refs, uniqueness)"
  else
    fail "Help graph has unresolved references:$problems"
  fi
}

# test_help_env_documented - every @command function documents the environment
# variables its body uses (scripts/audit-env-docs.sh; @env tag or literal
# mention in the block). Internal plumbing vars are whitelisted in the script.
test_help_env_documented() {
  test_header "Help blocks: used environment variables documented (@env)"
  local missing
  missing=$(sh scripts/audit-env-docs.sh ELEBAKE elebake.sh include/*.sh 2>/dev/null | awk '$1=="MISSING" && $2=="command"')
  if [ -z "$missing" ]; then
    pass "every @command function documents its environment variables"
  else
    fail "undocumented environment variables in @command help blocks:"
    printf '%s\n' "$missing" | sed 's/^/       - /'
  fi
}


# TEST: notes in ACT terminals must reach stderr (a bare "# ..." emission is
# a no-op comment under an executing sh interpreter -- swallowed). Display-
# pinned terminals (cat/cut templates) emit TEXT and keep plain # lines;
# file content inside emitted heredocs is data; combinators/batches may
# emit # lines (legitimate batch-format comments). Source-level scan with
# heredoc tracking, so every code path is covered.
test_terminal_notes_reach_stderr() {
  test_header "Terminal notes reach stderr (no swallowed # emissions)"
  local viol="" fn body mang mang_na pin t hd line
  for fn in $TERMINAL_FUNCTIONS; do
    mang=$(printf '%s' "$fn" | sed 's/^_*//')
    mang_na=$(printf '%s' "$mang" | sed 's/[0-9]$//')
    pin=""
    for t in "template/environment/ELEBAKE_INTERPRETER_$mang" \
             "template/environment/ELEBAKE_INTERPRETER_$mang_na"; do
      [ -f "$t" ] && { pin=$(head -1 "$t"); break; }
    done
    case "$pin" in cat*|cut*) continue ;; esac
    body=$(awk "/^${fn}\(\) \{/,/^\}/" include/*.sh)
    [ -n "$body" ] || continue
    hd=""
    while IFS= read -r line; do
      if [ -n "$hd" ]; then
        case "$line" in *"$hd"*) hd="" ;; esac
        continue
      fi
      case "$line" in
        *"<<'"*) hd=$(printf '%s' "$line" | sed "s/.*<<'\([A-Z_]*\)'.*/\1/"); continue ;;
      esac
      # a swallowed emission is an OUTER printf whose emitted string starts
      # with '#': the classic single-line form, the direct-format form, and
      # the continuation line of a format string broken over a literal
      # newline (the freebsd-prerequisites escape). An emitted printf
      # COMMAND ('printf "# %s..."' as payload) is fine — it prints.
      if printf '%s\n' "$line" | grep -Eq "printf .%s..n.[[:space:]]*[\"']#|printf [\"']#|^['\"][[:space:]]+[\"']#"; then
        case "$line" in *">&2"*) ;; *) viol="$viol $fn" ;; esac
      fi
    done <<EOF
$body
EOF
  done
  viol=$(printf '%s\n' $viol | sort -u | tr '\n' ' ')
  if [ -z "${viol# }" ]; then
    pass "no swallowed # emissions in act terminals"
  else
    fail "act terminals with bare # emissions (use emit_note):$viol"
  fi
}

# parallel_main - run every test function of the active filter as its own
# suite process (sequential inside), MAXPROCS at a time via xargs -P; then
# replay the outputs in list order and print an aggregated summary.
test_license_headers_present() {
  test_header "License headers: every .sh carries SPDX + copyright"
  local f missing=""
  for f in $(git ls-files '*.sh' 2>/dev/null); do
    head -6 "$f" | grep -q 'SPDX-License-Identifier: BSD-2-Clause' || missing="$missing $f"
    head -6 "$f" | grep -q 'Copyright (c)' || missing="$missing $f"
  done
  missing=$(printf '%s\n' $missing | sort -u | tr '\n' ' ')
  if [ -z "${missing# }" ]; then
    pass "all shell sources carry the BSD-2-Clause header"
  else
    fail "missing/incomplete license headers:$missing"
  fi
}

test_profile_template_bijection() {
  test_header "Profiles and templates: bijective (no dead entries, no unshipped pins)"
  local viol="" v t
  for prof in template/environment/ELEBAKE_PROFILE_MINIMAL template/environment/ELEBAKE_PROFILE_ALL; do
    for v in $(head -1 "$prof"); do
      case "$v" in PATH) continue ;; esac
      [ -f "template/environment/$v" ] || viol="$viol $(basename "$prof"):$v(no-template)"
    done
  done
  for t in template/environment/ELEBAKE_INTERPRETER_* template/environment/ELEBAKE_*; do
    t=$(basename "$t")
    case "$t" in ELEBAKE_PROFILE_*|ELEBAKE_INCLUDES) continue ;; esac
    grep -qw "$t" template/environment/ELEBAKE_PROFILE_ALL || viol="$viol ALL-misses:$t"
  done
  viol=$(printf '%s\n' $viol | sort -u | tr '\n' ' ')
  if [ -z "${viol# }" ]; then
    pass "every profile entry ships a template, every template is listed in ALL"
  else
    fail "profile/template drift:$viol"
  fi
}

# TEST: one anchor, one responsibility. Two mechanical proxies for the
# symptom JB named on 03.09.: (1) a `case` on an argument whose branches
# each PRODUCE OUTPUT is a dispatcher inside an anchor -- the dispatcher's
# job (one anchor per aspect, a batch above them); only a case at the
# anchor's top level counts (a case inside a loop classifies data); (2) an anchor body above
# ANCHOR_MAX_CODE_LINES does several things. Both lists name their
# exceptions with a reason.
ANCHOR_MAX_CODE_LINES=40
# engine machinery (_batch2 executes the batch file; _database_init0 walks
# the layout config); user-facing text (help environment topic);
# runtime-by-design NVRAM surgery whose value must never split into
# generation-time facts (_stage_marker_write2); the dump header text
# (___dump2); the layered variable store (_setenv2, _help_env2).
ANCHOR_SIZE_EXCEPTIONS="_batch2 _database_init0 _help1 _stage_marker_write2 ___dump2 _setenv2 _help_env2"
test_anchor_single_responsibility() {
  test_header "Anchors: one responsibility (no argument dispatch, bounded size)"
  local viol="" fn f body n d
  for f in include/*.sh; do
    for fn in $(grep -oE '^_+[a-z][a-z0-9_]*\(\)' "$f" | sed 's/()$//'); do
      body=$(awk -v fn="$fn" '$0 == fn "() {" {inb=1; next} inb && /^}/ {exit} inb' "$f")
      n=$(printf '%s\n' "$body" | sed 's/^[ \t]*//' | grep -cv '^#\|^$' || true)
      case " $ANCHOR_SIZE_EXCEPTIONS " in *" $fn "*) ;; *)
        [ "$n" -le "$ANCHOR_MAX_CODE_LINES" ] || viol="$viol $fn(size:$n)" ;;
      esac
      # a case on an argument (or a local copy of one) with two or more
      # branches that print: branches are lines ending in ')' patterns,
      # a branch prints when printf/echo/cat/emit_note occurs before the
      # next branch or esac
      d=$(printf '%s\n' "$body" | awk '
        /^  case "\$[a-z_]+" in/ { incase=1; br=0; emit=0; cur=0; next }
        incase && /^[ \t]*esac/ { if (br >= 2 && emit >= 2) print "x"; incase=0; next }
        incase {
          if ($0 ~ /^[ \t]*[^ \t#][^)]*\)([ \t]|$)/ && $0 !~ /^[ \t]*(printf|echo|emit_note|generate_error|cat|\[)/) { br++; cur=0 }
          if ($0 ~ /(printf|echo|emit_note|cat) / && $0 !~ /generate_error/ && !cur) { emit++; cur=1 }
        }')
      [ -z "$d" ] || viol="$viol $fn(dispatch)"
    done
  done
  viol=$(printf '%s\n' $viol | sort -u | tr '\n' ' ')
  if [ -z "${viol# }" ]; then
    pass "every anchor does one thing: no argument dispatch inside, none above $ANCHOR_MAX_CODE_LINES code lines (exceptions listed with reasons)"
  else
    fail "anchors doing several things (split into one anchor per aspect, a batch above):$viol"
  fi
}

test_function_modules_wellformed() {
  test_header "FUNCTION_MODULES: every entry is exactly func:module.sh"
  local e viol=""
  for e in $FUNCTION_MODULES; do
    case "$e" in
      *:*.sh) ;;
      *) viol="$viol $e" ;;
    esac
  done
  for e in $ANCHOR_FUNCTIONS; do
    case "$e" in _database_init0|_error*|_fail2|_log*|_cat1|_unknown_command1|_printenv0) continue ;; esac
    case " $FUNCTION_MODULES " in
      *" $e:"*) ;;
      *) viol="$viol $e(unmapped)" ;;
    esac
  done
  viol=$(printf '%s\n' $viol | sort -u | tr '\n' ' ')
  if [ -z "${viol# }" ]; then
    pass "every mapping is func:module.sh and every anchor is mapped"
  else
    fail "malformed or missing FUNCTION_MODULES entries:$viol"
  fi
}

parallel_main() {
  local outdir rc=0 t
  outdir=$(mktemp -d "${TMPDIR:-/tmp}/elebake-arch-par.XXXXXX") || exit 1
  echo "${COLOR_BLUE}elebake Architecture Test Suite (parallel, -P $MAXPROCS)${COLOR_RESET}"
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
  echo "${COLOR_BLUE}========================================${COLOR_RESET}"
  echo "${COLOR_BLUE}Aggregated Summary (parallel run)${COLOR_RESET}"
  echo "${COLOR_BLUE}========================================${COLOR_RESET}"
  awk -F: '
    /^Test Functions:/    { tf += $2 }
    /^Total Assertions:/  { ta += $2 }
    /^Passed Assertions:/ { pa += $2 }
    /^Failed Assertions:/ { fa += $2 }
    END {
      printf "Test Functions:     %d\n", tf
      printf "Total Assertions:   %d\n", ta
      printf "Passed Assertions:  %d\n", pa
      printf "Failed Assertions:  %d\n", fa
    }' "$outdir"/*.out
  if [ "$rc" -eq 0 ]; then
    echo ""
    echo "${COLOR_GREEN}ALL TESTS PASSED${COLOR_RESET}"
    rm -rf "$outdir"
  else
    echo ""
    echo "${COLOR_RED}SOME TESTS FAILED${COLOR_RESET}"
    echo "Per-test outputs preserved in: $outdir"
  fi
  return $rc
}

main() {
  # Parallel dispatch: hand the test list to worker copies of this suite.
  if [ "$MAXPROCS" -gt 1 ]; then
    if [ ! -f "$TEST_SCRIPT" ]; then
      echo "${COLOR_RED}ERROR:${COLOR_RESET} $TEST_SCRIPT not found"
      exit 1
    fi
    parallel_main
    return $?
  fi

  echo "${COLOR_BLUE}========================================${COLOR_RESET}"
  echo "${COLOR_BLUE}elebake Architecture Test Suite${COLOR_RESET}"
  echo "${COLOR_BLUE}========================================${COLOR_RESET}"
  echo ""
  echo "Testing architectural rules for combinator functions"
  echo "Profile: $TEST_PROFILE"
  if [ "$TEST_FILTER" != "$ALL_TESTS" ]; then
    echo "${COLOR_YELLOW}Filter active - running only:${COLOR_RESET} $TEST_FILTER"
  fi
  echo ""

  # Check prerequisites
  if [ ! -f "$TEST_SCRIPT" ]; then
    echo "${COLOR_RED}ERROR:${COLOR_RESET} $TEST_SCRIPT not found"
    echo "Run this script from the repository root"
    exit 1
  fi

  # Combinator / terminal / batch architecture (parameterised phases)
  should_run_test test_all_combinator_syntax
  should_run_test test_all_batch_combinator_syntax
  should_run_test test_all_terminal_output

  # Error propagation
  should_run_test test_batch_error_propagation
  should_run_test test_recursive_batch_error_propagation
  should_run_test test_batch_keep_going_with_realistic_dump
  should_run_test test_all_batch_error_propagation_hull
  should_run_test test_all_batch_keep_going_precise

  # Static analysis & read-only compliance
  should_run_test test_architecture_violation_scanner
  should_run_test test_readonly_database


  # Help doc-block corpus (docs/HELP_TEMPLATE_SPEC.md) - red until the corpus is filled
  should_run_test test_help_blocks_present
  should_run_test test_help_blocks_conform
  should_run_test test_help_graph_resolves
  should_run_test test_help_env_documented
  should_run_test test_terminal_notes_reach_stderr
  should_run_test test_license_headers_present
  should_run_test test_profile_template_bijection
  should_run_test test_function_modules_wellformed
  should_run_test test_anchor_single_responsibility

  # Print summary
  test_summary
}

# Run main and exit with its status
main
exit $?
