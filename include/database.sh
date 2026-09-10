#!/bin/sh
#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Dr. Johannes Brügmann
# elebake database - the database itself: bootstrap, environment, dump and
# restore, the archive pipeline (collect, filter, bundle, seal, export,
# import), batch execution and destroy.

#@help __bootstrap1
# @command bootstrap <name> <profile>
# @summary Create the database ~/.elebake/<name> (under ELEBAKE_ROOT) with the named profile and point the active-DB symlink db at it. <name> is a plain name, not a path: a slash is refused, db is reserved
# @group   setup
# @param   name     database name below ELEBAKE_ROOT (e.g. production); no slashes
# @param   profile  environment profile (minimal or all)
# @returns shell commands (create structure, copy defaults, stamp version)
# @example elebake bootstrap production all | sh
#@end
__bootstrap1() {
        echo "\"\$ELEBAKE_CONTEXT_SCRIPT\" bootstrap \"$1\" minimal"
}

#@help ___bootstrap2
# @internal arity-2 sibling of 'bootstrap' (bootstrap <name> <profile>): Create the database <root>/<name> with the named profile and point the active-DB symlink <root>/db at it: the name and the profile valid, the scaffold the batch runner of init needs, init against the new database, the link, the log line. Runs before any database exists: the environment is the shipped baseline, the batch runs under sh -e
#@end
___bootstrap2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" bootstrap name valid '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" environment profile valid '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" bootstrap scaffold '$1' '$ELEBAKE_ROOT'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" bootstrap init '$ELEBAKE_ROOT/$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" bootstrap link '$1' '$ELEBAKE_ROOT'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log 'Bootstrap complete: $ELEBAKE_ROOT/$1 ($2) [db -> $1]'"
}

#@help __bootstrap_name_valid1
# @command bootstrap name valid <name>
# @summary The name is a plain database name below ELEBAKE_ROOT -- not empty, no slash, not the reserved 'db' (the active-DB symlink): a comment line, else an error line
# @group   setup
# @internal
# @see     bootstrap
#@end
__bootstrap_name_valid1() {
        if database_name_ok "$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'database name $1 valid'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'bootstrap: <name> is a plain database name -- no slash, not db: $1 (e.g. production)'"
        fi
}

#@help _bootstrap_scaffold2
# @command bootstrap scaffold <name> <root>
# @summary Act terminal: the database directory (0700) with .tmp and .tmp/batch-exits (modes from the layout) -- what the batch runner of the following init needs before its first line
# @group   setup
# @internal
# @see     bootstrap
# @see     database init
#@end
_bootstrap_scaffold2() {
        printf '%s\n' "$MODIFY_DIR_CREATE '$2/$1/.tmp/batch-exits'"
        printf '%s\n' "$MODIFY_FILE_PERMS 0700 '$2/$1'"
        printf '%s\n' "$MODIFY_FILE_PERMS $(printf '%s\n' "$ELEBAKE_INIT_DIR_CONFIG" | awk -F: '$1 == ".tmp" { print $2 }') '$2/$1/.tmp'"
        printf '%s\n' "$MODIFY_FILE_PERMS $(printf '%s\n' "$ELEBAKE_INIT_DIR_CONFIG" | awk -F: '$1 == ".tmp/batch-exits" { print $2 }') '$2/$1/.tmp/batch-exits'"
}

#@help __bootstrap_init2
# @command bootstrap init <base> <profile>
# @summary The one line that initializes the NEW database: 'init <profile>' with ELEBAKE_BASE bound to <base> in front of it (the root is named by the parent: a child derives no root before a database exists) -- its pin maps the context-script word and execs the line (cat = dry-run)
# @group   setup
# @internal
# @env     ELEBAKE_INTERPRETER_bootstrap_init  execs the line with ELEBAKE_BASE bound; cat = dry-run
# @see     bootstrap
# @see     init
#@end
__bootstrap_init2() {
        printf '%s\n' "env ELEBAKE_BASE='$1' \"\$ELEBAKE_CONTEXT_SCRIPT\" init '$2'"
}

#@help _bootstrap_link2
# @command bootstrap link <name> <root>
# @summary Act terminal: point the active-DB symlink <root>/db at the database <name> (forced: a bootstrap re-run or a second database moves it)
# @group   setup
# @internal
# @see     bootstrap
#@end
_bootstrap_link2() {
        printf '%s\n' "$MODIFY_LINK_FORCE '$1' '$2/db'"
}

#@help __environment_profile_valid1
# @command environment profile valid <profile>
# @summary The profile is shipped as template/environment/ELEBAKE_PROFILE_<PROFILE>: a comment line, else an error line
# @group   setup
# @internal
# @see     bootstrap
# @see     environment init
#@end
__environment_profile_valid1() {
        if profile_ok "$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'profile $1 shipped'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'unknown profile $1 (minimal | all)'"
        fi
}
#@help ___database_init0
# @command database init
# @summary Ensure every directory of the database layout (ELEBAKE_INIT_DIR_CONFIG: path, mode, exec flag, content policy), one 'database dir ensure' per line, then the ready line
# @group   setup
# @internal
# @see     init
# @see     database dir ensure
#@end
___database_init0() {
        local dir="" mode="" exec="" policy=""
        printf '%s\n' "$ELEBAKE_INIT_DIR_CONFIG" | while IFS=: read -r dir mode exec policy; do
                test -n "$dir" || continue
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" database dir ensure '$dir' '$mode' '$exec' '$policy'"
        done
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log 'Database ready: $ELEBAKE_BASE'"
}

#@help __database_dir_ensure4
# @command database dir ensure <dir> <mode> <exec-flag> <policy>
# @summary The directory is there: rewrite to 'database dir validate ...', else to 'database dir create <dir> <mode>'
# @group   setup
# @internal
# @see     database init
#@end
__database_dir_ensure4() {
        if test -e "$ELEBAKE_BASE/$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" database dir validate '$1' '$2' '$3' '$4'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" database dir create '$1' '$2'"
        fi
}

#@help __database_dir_validate4
# @command database dir validate <dir> <mode> <exec-flag> <policy>
# @summary The path is a directory, its content admissible (policy operational: any; else empty -- the exclusive hierarchy) and, with the exec flag, its mount runs scripts: rewrite to 'database dir validated <dir> <mode>', else an error line
# @group   setup
# @internal
# @see     database dir ensure
#@end
__database_dir_validate4() {
        if test -d "$ELEBAKE_BASE/$1" && dir_content_ok "$ELEBAKE_BASE/$1" "$4" && dir_exec_ok "$ELEBAKE_BASE/$1" "$3"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" database dir validated '$1' '$2'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'database init: $1 exists but is not a directory, not empty (policy $4) or mounted noexec (flag $3) -- remove or fix it and run init again'"
        fi
}

#@help _database_dir_validated2
# @command database dir validated <dir> <mode>
# @summary Act terminal: the validated line for the directory, with a warning when its mode differs from the layout's
# @group   setup
# @internal
# @see     database dir ensure
#@end
_database_dir_validated2() {
        local actual=""
        actual=$($CMD_STAT_PERMS "$ELEBAKE_BASE/$1" 2>/dev/null | sed 's/^0*//')
        if test "$actual" != "$(printf '%s' "$2" | sed 's/^0*//')"; then
                emit_note "Warning: directory $1 has mode $actual, expected $2"
        fi
        emit_note "Validated: $1"
}

#@help _database_dir_create2
# @command database dir create <dir> <mode>
# @summary Act terminal: create the directory with its mode and say so
# @group   setup
# @internal
# @see     database dir ensure
#@end
_database_dir_create2() {
        printf '%s\n' "$MODIFY_DIR_CREATE '$ELEBAKE_BASE/$1'"
        printf '%s\n' "$MODIFY_FILE_PERMS $2 '$ELEBAKE_BASE/$1'"
        emit_note "Created: $1 (mode $2)"
}

#@help ___environment_init1
# @command environment init <profile>
# @summary Install (or re-sync after an update) the profile's template variables into .env/default: the profile is shipped, then 'environment install'
# @group   setup
# @param   profile  minimal or all
# @example elebake environment init all
# @see     bootstrap
# @see     environment profile valid
# @see     environment install
#@end
___environment_init1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" environment profile valid '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" environment install '$1'"
}

#@help _environment_install1
# @command environment install <profile>
# @summary Act terminal: the script that copies every template the profile lists into .env/default (0600), removes the default pins the profile no longer lists (a renamed terminal's old pin would bind the wrong function), records the profile marker, invalidates the environment cache when one is there and says so; a local pin that names no function is reported
# @group   setup
# @internal
# @see     environment init
# @env     ELEBAKE_TEMPLATE_DIR  where the profile and its templates live
# @env     ELEBAKE_PROFILE_ALL  the profile lists (ELEBAKE_PROFILE_<PROFILE>): line 1 names the variables to install
# @env     ELEBAKE_CACHE_ENV_ARGS  the environment cache, invalidated by the install
#@end
_environment_install1() {
        local var="" f=""
        for var in $(head -1 "$ELEBAKE_TEMPLATE_DIR/environment/ELEBAKE_PROFILE_$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')" 2>/dev/null); do
                printf '%s\n' "$MODIFY_FILE_COPY_FORCE '$ELEBAKE_TEMPLATE_DIR/environment/$var' '$ELEBAKE_BASE/.env/default/$var'"
                printf '%s\n' "$MODIFY_FILE_PERMS 0600 '$ELEBAKE_BASE/.env/default/$var'"
        done
        printf '%s\n' "$MODIFY_FILE_COPY_FORCE '$ELEBAKE_TEMPLATE_DIR/environment/ELEBAKE_PROFILE_$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')' '$ELEBAKE_BASE/.env/default/ELEBAKE_PROFILE_$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')'"
        printf '%s\n' "$MODIFY_FILE_PERMS 0600 '$ELEBAKE_BASE/.env/default/ELEBAKE_PROFILE_$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')'"
        for f in "$ELEBAKE_BASE"/.env/default/ELEBAKE_INTERPRETER_*; do
                test -f "$f" || continue
                pin_listed "${f##*/}" "$1" && continue
                printf '%s\n' "$MODIFY_FILE_REMOVE '$f'"
                emit_note "removed the stale default pin ${f##*/} (the profile no longer lists it)"
        done
        for f in "$ELEBAKE_BASE"/.env/local/ELEBAKE_INTERPRETER_*; do
                test -f "$f" || continue
                pin_names_function "${f##*/}" && continue
                emit_note "stale local pin ${f##*/}: no such function -- unsetenv ${f##*/}"
        done
        printf '%s\n' "$MODIFY_FILE_REMOVE '$ELEBAKE_BASE/.env/local/ELEBAKE_CACHE_ENV_ARGS' 2>/dev/null || true"
        emit_note "Installed $1 profile (environment cache invalidated)"
}

#@help __environment_cache0
# @command environment cache [on|off|status]
# @summary Manage the cached-environment optimisation
# @group   configuration
# @param   on|off|status  enable, disable, or report the cache (default: status)
# @returns shell commands / cache status
# @example elebake environment cache status

# @env ELEBAKE_CACHE_ENV_ARGS  the cache this command manages
#@end
__environment_cache0() {
        # Combinator - delegate to status display
        echo '"$ELEBAKE_CONTEXT_SCRIPT" environment cache status'
}

#@help _environment_cache_on0
# @command environment cache on
# @summary Build the environment cache NOW (a fresh scan of .env/, written at generation time) so every later invocation skips the layered lookup
# @group   configuration
# @env     ELEBAKE_CACHE_ENV_ARGS  the cache file this command writes
# @see     environment cache off
#@end
_environment_cache_on0() {
        local cache_file="$ELEBAKE_BASE/.env/local/ELEBAKE_CACHE_ENV_ARGS" var_count
        # Generation time: write the cache directly (ESSENCE). Force a fresh disk
        # scan: build_env_args_full short-circuits on an in-memory
        # ELEBAKE_CACHE_ENV_ARGS (inherited via env -), so without unsetting it
        # here a rebuild would just rewrite the stale value it is meant to
        # replace. Unset in a subshell so the scan reads .env/ afresh.
        ( unset ELEBAKE_CACHE_ENV_ARGS; build_env_args_full ) > "$cache_file"
        $MODIFY_FILE_PERMS 0600 "$cache_file"
        var_count=$(wc -w < "$cache_file" | tr -d ' ')
        echo "echo '# Environment cache ENABLED' >&2"
        echo "echo '# Cached $var_count variables' >&2"
}

#@help _environment_cache_off0
# @command environment cache off
# @summary Remove the environment cache; later invocations read the layered store again
# @group   configuration
# @env     ELEBAKE_CACHE_ENV_ARGS  the cache file this command removes
# @see     environment cache on
#@end
_environment_cache_off0() {
        local cache_file="$ELEBAKE_BASE/.env/local/ELEBAKE_CACHE_ENV_ARGS"
        if [ -f "$cache_file" ]; then
                echo "$MODIFY_FILE_REMOVE '$cache_file'"
                echo "echo '# Environment cache DISABLED' >&2"
        else
                echo "echo '# Environment cache already disabled' >&2"
        fi
}

#@help _environment_cache_status0
# @command environment cache status
# @summary Is the environment cache on, and how many variables does it hold?
# @group   configuration
# @env     ELEBAKE_CACHE_ENV_ARGS  the cache file this command examines
# @see     environment cache on
#@end
_environment_cache_status0() {
        local cache_file="$ELEBAKE_BASE/.env/local/ELEBAKE_CACHE_ENV_ARGS" var_count
        if [ -f "$cache_file" ]; then
                var_count=$(wc -w < "$cache_file" | tr -d ' ')
                echo "echo '# Environment cache: ENABLED ($var_count vars)' >&2"
        else
                echo "echo '# Environment cache: DISABLED' >&2"
        fi
}

#@help ___init1
# @command init <profile>
# @summary Initialize the database at ELEBAKE_BASE: the layout (database init), then the profile's environment (environment init)
# @group   setup
# @param   profile  minimal or all
# @example elebake init minimal
# @see     bootstrap
#@end
___init1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" database init"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" environment init '$1'"
}

#@help __init0
# @internal low-level database init — complex to call directly; use 'bootstrap'

# @env ELEBAKE_CACHE_ENV_ARGS                 rebuilt as part of init
# @env ELEBAKE_TERMINAL_INTERPRETER          class default seeded by init
# @env ELEBAKE_COMBINATOR_INTERPRETER        class default seeded by init
# @env ELEBAKE_BATCH_COMBINATOR_INTERPRETER  class default seeded by init

#@end
__init0() {
        # Bootstrap: passthrough interpreter variables for init command
        # Since init creates the .env files, we need to provide defaults via CACHE_ENV_ARGS
        echo "ELEBAKE_CACHE_ENV_ARGS=\"ELEBAKE_COMBINATOR_INTERPRETER=sh ELEBAKE_TERMINAL_INTERPRETER=sh ELEBAKE_BATCH_COMBINATOR_INTERPRETER='while IFS= read -r line; do echo \\\"\\\$line\\\" | \\\$ELEBAKE_COMBINATOR_INTERPRETER; done'\" \"\$ELEBAKE_CONTEXT_SCRIPT\" init minimal"
}

#@help ___setenv2
# @command setenv <VAR> <value>
# @summary Set a machine override: the name is a variable name, the value is written to .env/local/<VAR> (0640, owner of the database when possible), the environment cache refreshed when one is on. Effective with the next command
# @group   setup
# @param   VAR    letters, digits and underscores
# @param   value  the first line of the variable's file
# @example elebake setenv ELEBAKE_FREEBSD_SRC /home/brj/git/freebsd-src
# @see     getenv
# @see     unsetenv
# @see     environment cache
#@end
___setenv2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" setenv name valid '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" setenv write '$1' $(sq "$2")"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" environment cache refresh"
}

#@help __setenv_name_valid1
# @command setenv name valid <VAR>
# @summary The name consists of letters, digits and underscores only: a comment line, else an error line
# @group   setup
# @internal
# @see     setenv
#@end
__setenv_name_valid1() {
        if printf '%s\n' "$1" | grep -qx '[A-Za-z0-9_][A-Za-z0-9_]*'; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'variable name $1 valid'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'setenv: invalid variable name $1 (letters, digits and underscores only)'"
        fi
}

#@help _setenv_write2
# @command setenv write <VAR> <value>
# @summary Act terminal: the script that writes the value as .env/local/<VAR> (directory 0700, file 0640) and hands the file to the database's owner when that is someone else (best effort)
# @group   setup
# @internal
# @see     setenv
#@end
_setenv_write2() {
        local owner=""
        owner=$($EXAMINE_FILE_OWNER "$ELEBAKE_BASE/.env/default" 2>/dev/null)
        printf '%s\n' "$MODIFY_DIR_CREATE '$ELEBAKE_BASE/.env/local'"
        printf '%s\n' "$MODIFY_FILE_PERMS 0700 '$ELEBAKE_BASE/.env/local'"
        printf '%s\n' "printf '%s\\n' $(sq "$2") > '$ELEBAKE_BASE/.env/local/$1'"
        printf '%s\n' "$MODIFY_FILE_PERMS 0640 '$ELEBAKE_BASE/.env/local/$1'"
        printf '%s\n' "$MODIFY_FILE_OWNER '$owner' '$ELEBAKE_BASE/.env/local/$1' 2>/dev/null || true"
        emit_note "Set $1 (effective next command)"
}

#@help __environment_cache_refresh0
# @command environment cache refresh
# @summary The environment cache is on (.env/local/ELEBAKE_CACHE_ENV_ARGS is there): rewrite to 'environment cache on' (a fresh scan), else a comment line
# @group   setup
# @internal
# @see     setenv
# @see     unsetenv
# @see     environment cache on
#@end
__environment_cache_refresh0() {
        if test -f "$ELEBAKE_BASE/.env/local/ELEBAKE_CACHE_ENV_ARGS"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" environment cache on"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'environment cache off, nothing to refresh'"
        fi
}

#@help __getenv1
# @command getenv <VAR>
# @summary Show the effective value of a variable and the layer that answers (.env/local override, .env/default, the shipped template): the variable resolves: rewrite to 'getenv read <VAR> <layer> <path>', else an error line
# @group   setup
# @example elebake getenv ELEBAKE_FREEBSD_SRC
# @see     setenv
# @see     printenv
#@end
__getenv1() {
        local resolved=""
        if resolved=$(env_resolve_file "$1" 2>/dev/null); then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" getenv read '$1' '$(printf '%s\n' "$resolved" | sed -n 1p)' '$(printf '%s\n' "$resolved" | sed -n 2p)'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'getenv: variable $1 not found in any layer'"
        fi
}

#@help _getenv_read3
# @command getenv read <VAR> <layer> <path>
# @summary Act terminal: the source line (layer and path; the local layer is the override) on stderr and the value (the file's first line) on stdout
# @group   setup
# @internal
# @see     getenv
#@end
_getenv_read3() {
        emit_note "Source: $3 ($(printf '%s' "$2" | sed 's/^local$/override/'))"
        printf '%s\n' "head -n 1 '$3'"
}

#@help ___unsetenv1
# @command unsetenv <VAR>
# @summary Remove the machine override .env/local/<VAR> when there is one (else say so), and refresh the environment cache when one is on
# @group   setup
# @example elebake unsetenv ELEBAKE_FREEBSD_SRC
# @see     setenv
# @see     getenv
#@end
___unsetenv1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" unsetenv remove '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" environment cache refresh"
}

#@help __unsetenv_remove1
# @command unsetenv remove <VAR>
# @summary The override file is there: rewrite to 'unsetenv erase <VAR>', else a note line (nothing to unset)
# @group   setup
# @internal
# @see     unsetenv
#@end
__unsetenv_remove1() {
        if test -f "$ELEBAKE_BASE/.env/local/$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" unsetenv erase '$1'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" note 'Variable $1 not set (nothing to unset)'"
        fi
}

#@help _unsetenv_erase1
# @command unsetenv erase <VAR>
# @summary Act terminal: remove .env/local/<VAR> and say so
# @group   setup
# @internal
# @see     unsetenv
#@end
_unsetenv_erase1() {
        printf '%s\n' "$MODIFY_FILE_REMOVE '$ELEBAKE_BASE/.env/local/$1'"
        emit_note "Unset $1"
}

#@help ___dump_env_prologue0
# @command dump env prologue
# @summary Emit the prologue of a dump: the SOURCE's .env/local overrides that the restore itself depends on (the PROLOGUE profile's list -- deliberately WITHOUT function-specific interpreter pins, which could deactivate replayed commands), plus the cache switch when the source had it on
# @group   database
# @env     ELEBAKE_TEMPLATE_DIR  the shipped templates, where the PROLOGUE profile lives
# @env     ELEBAKE_PROFILE_PROLOGUE  the profile listing the variables that travel in the prologue
# @env     ELEBAKE_CACHE_ENV_ARGS  the cache switch of the source; its presence emits 'environment cache on'
# @see     dump env epilogue
# @see     dump
#@end
___dump_env_prologue0() {
        local varname="" value=""
        for varname in $(head -n 1 "$ELEBAKE_TEMPLATE_DIR/environment/ELEBAKE_PROFILE_PROLOGUE" 2>/dev/null); do
                test "$varname" != ELEBAKE_CACHE_ENV_ARGS || continue
                value=$(head -n 1 "$ELEBAKE_BASE/.env/local/$varname" 2>/dev/null)
                test -n "$value" && printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" setenv $varname $(sq "$value")"
        done
        test -f "$ELEBAKE_BASE/.env/local/ELEBAKE_CACHE_ENV_ARGS" && printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" environment cache on"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'environment prologue replayed'"
}
#@help ___dump_env_epilogue0
# @command dump env epilogue
# @summary Emit the epilogue of a dump: EVERY .env/local override of the source, including function-specific interpreter pins -- restored at the very end, when the replay is done
# @group   database
# @env     ELEBAKE_CACHE_ENV_ARGS  regenerated by 'environment cache on', never copied
# @see     dump env prologue
# @see     dump
#@end
___dump_env_epilogue0() {
        local local_file="" varname="" value=""
        for local_file in "$ELEBAKE_BASE/.env/local/"*; do
                varname=${local_file##*/}
                test -f "$local_file" && test "$varname" != ELEBAKE_CACHE_ENV_ARGS || continue
                value=$(head -n 1 "$local_file" 2>/dev/null)
                test -n "$value" && printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" setenv $varname $(sq "$value")"
        done
        test -f "$ELEBAKE_BASE/.env/local/ELEBAKE_CACHE_ENV_ARGS" && printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" environment cache on"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'environment epilogue replayed'"
}
#@help ___destroy1
# @command destroy <name>
# @summary Remove this database and everything it owns, IRRECOVERABLY, as three steps: the worktrees and their registration in the source repo, the records, the scaffolding (bundle handover area, active-DB symlink, empty root). The name IS the confirmation, checked before a line runs
# @group   database
# @param   name  must match the database's own name -- the confirmation
# @example elebake destroy current
# @see     destroy worktrees
# @see     dump
#@end
___destroy1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" destroy named '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" destroy warning '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" destroy worktrees '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" destroy records '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" destroy scaffold '$1'"
}

#@help __destroy_named1
# @command destroy named <name>
# @summary The name is this database's own (the basename the active-DB symlink resolves to): a comment line, else an error line -- naming the database IS the confirmation
# @group   database
# @internal
# @see     destroy
#@end
__destroy_named1() {
        local real=""
        real=$(basename "$(readlink -f "$ELEBAKE_BASE")")
        if test "$1" = "$real"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'destroy $1 confirmed by name'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error $(sq "destroy: name '$1' does not match this database ('$real') -- naming it IS the confirmation")"
        fi
}

#@help _destroy_warning1
# @command destroy warning <name>
# @summary Print what destroy removes for good and what it leaves alone -- the warning the batch shows before the first rm
# @group   database
# @internal
# @see     destroy
#@end
_destroy_warning1() {
        printf '%s\n' "# DESTROY '$1' -- everything below is gone for good, with no undo:"
        printf '%s\n' "#   the records, every stage with its boot tree, markers and backups,"
        printf '%s\n' "#   the worktrees under $ELEBAKE_ROOT/worktree and their registration in the source repo,"
        printf '%s\n' "#   the bundle handover area $ELEBAKE_ROOT/bundle (a handover point, never a store --"
        printf '%s\n' "#   copy anything you still need OUT of it first),"
        printf '%s\n' "#   and the active-DB symlink if it points here."
        printf '%s\n' "# Not touched, because they are not this database's: deployed loaders on media,"
        printf '%s\n' "# NVRAM boot entries, and key material in the world (pem/pkcs11/openpgp paths)."
}

#@help __destroy_worktrees1
# @command destroy worktrees <name>
# @summary Step 1 of destroy: the name is this database's: rewrite to 'destroy worktrees remove' (every stage worktree AND its registration in the source repo -- a plain rm -rf would leave "missing but already registered worktree" behind; the ids are only knowable while the database exists), else an error line
# @group   database
# @param   name  the database's own name -- the confirmation
# @see     destroy
# @see     destroy worktrees remove
#@end
__destroy_worktrees1() {
        local real=""
        real=$(basename "$(readlink -f "$ELEBAKE_BASE")")
        if test "$1" = "$real"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" destroy worktrees remove"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error $(sq "destroy worktrees: name '$1' does not match this database ('$real')")"
        fi
}

#@help ___destroy_worktrees_remove0
# @command destroy worktrees remove
# @summary One 'destroy worktree remove' per worktree the stages register under .staging/*/work; none registered: a comment line
# @group   database
# @internal
# @see     destroy worktrees
#@end
___destroy_worktrees_remove0() {
        local link="" n=0
        for link in "$ELEBAKE_BASE"/.staging/*/work; do
                test -L "$link" || continue
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" destroy worktree remove '$(readlink "$link")'"
                n=$((n + 1))
        done
        test "${n:-0}" -gt 0 || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'no stage worktree registered'"
}

#@help __destroy_worktree_remove1
# @command destroy worktree remove <path>
# @summary ELEBAKE_FREEBSD_SRC names the source repo: rewrite to 'destroy worktree unregister' (git removes and prunes it), else to 'destroy worktree delete' (a plain rm -rf, the registration left to you)
# @group   database
# @internal
# @env     ELEBAKE_FREEBSD_SRC  the repo whose worktree it is
# @see     destroy worktrees remove
#@end
__destroy_worktree_remove1() {
        if test -n "${ELEBAKE_FREEBSD_SRC:-}"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" destroy worktree unregister '$1'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" destroy worktree delete '$1'"
        fi
}

#@help _destroy_worktree_unregister1
# @command destroy worktree unregister <path>
# @summary Act terminal: git removes the worktree from the source repo (forced; a vanished directory falls back to rm -rf) and prunes the registration
# @group   database
# @internal
# @env     ELEBAKE_FREEBSD_SRC  the source repo
# @see     destroy worktree remove
#@end
_destroy_worktree_unregister1() {
        printf '%s\n' "git -C '$ELEBAKE_FREEBSD_SRC' worktree remove --force '$1' 2>/dev/null || rm -rf '$1'"
        printf '%s\n' "git -C '$ELEBAKE_FREEBSD_SRC' worktree prune"
}

#@help _destroy_worktree_delete1
# @command destroy worktree delete <path>
# @summary Act terminal: rm -rf of the worktree directory alone -- ELEBAKE_FREEBSD_SRC is unset, so the source repo keeps a stale registration until 'git worktree prune' runs there (noted on stderr)
# @group   database
# @internal
# @see     destroy worktree remove
#@end
_destroy_worktree_delete1() {
        printf '%s\n' "rm -rf '$1'"
        emit_note "note: ELEBAKE_FREEBSD_SRC unset -- worktree '${1##*/}' removed as a plain directory;"
        emit_note "      run 'git -C <src> worktree prune' in the source repo to clear its registration."
}

#@help __destroy_records1
# @command destroy records <name>
# @summary Step 2 of destroy: the name is this database's: rewrite to 'destroy records remove' (the database directory itself, resolved through the active-DB symlink first -- rm -rf on a symlink removes the LINK and orphans the database), else an error line
# @group   database
# @param   name  the database's own name -- the confirmation
# @see     destroy
# @see     destroy records remove
#@end
__destroy_records1() {
        local real=""
        real=$(basename "$(readlink -f "$ELEBAKE_BASE")")
        if test "$1" = "$real"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" destroy records remove"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error $(sq "destroy records: name '$1' does not match this database ('$real')")"
        fi
}

#@help _destroy_records_remove0
# @command destroy records remove
# @summary Act terminal: rm -rf of the resolved database directory and a note of what was destroyed
# @group   database
# @internal
# @see     destroy records
#@end
_destroy_records_remove0() {
        printf '%s\n' "rm -rf '$(readlink -f "$ELEBAKE_BASE")'"
        printf '%s\n' "printf '# destroyed: %s\\n' '$(basename "$(readlink -f "$ELEBAKE_BASE")")' >&2"
}

#@help __destroy_scaffold1
# @command destroy scaffold <name>
# @summary Step 3 of destroy: the name is this database's: rewrite to 'destroy scaffold remove' (the bundle handover area, the active-DB symlink if it points here, the empty scaffolding), else an error line
# @group   database
# @param   name  the database's own name -- the confirmation
# @see     destroy
# @see     destroy scaffold remove
#@end
__destroy_scaffold1() {
        local real=""
        real=$(basename "$(readlink -f "$ELEBAKE_BASE")")
        if test "$1" = "$real"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" destroy scaffold remove"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error $(sq "destroy scaffold: name '$1' does not match this database ('$real')")"
        fi
}

#@help _destroy_scaffold_remove0
# @command destroy scaffold remove
# @summary Act terminal: rm -rf of the bundle handover area, rm of the active-DB symlink when it points to this database, rmdir of worktree/, incoming/ and the root -- rmdir refuses non-empty directories, so a second database in the same root survives untouched; what remains is listed on stderr
# @group   database
# @internal
# @see     destroy scaffold
#@end
_destroy_scaffold_remove0() {
        printf '%s\n' "rm -rf '$ELEBAKE_ROOT/bundle'"
        if test "$(readlink "$ELEBAKE_ROOT/db" 2>/dev/null)" = "$(basename "$(readlink -f "$ELEBAKE_BASE")")"; then
                printf '%s\n' "rm -f '$ELEBAKE_ROOT/db'"
        fi
        printf '%s\n' "rmdir '$ELEBAKE_ROOT/worktree' '$ELEBAKE_ROOT/incoming' 2>/dev/null || true"
        printf '%s\n' "rmdir '$ELEBAKE_ROOT' 2>/dev/null || true"
        printf '%s\n' "printf '# remaining under %s:\\n' '$ELEBAKE_ROOT' >&2"
        printf '%s\n' "ls -A '$ELEBAKE_ROOT' 2>/dev/null | sed 's/^/#   /' >&2 || true"
}

#@help _version0
# @command version
# @summary Print the version of this elebake: the dump format it writes and restores (ELEBAKE_FORMAT) and the commit of the checkout it runs from (git; 'unknown' without one) -- what a dump carries in its header and what a report names
# @group   database
# @env     ELEBAKE_FORMAT  the dump format major version
# @example elebake version
# @see     dump
# @see     restore
#@end
_version0() {
        local commit=""
        commit=$(git -C "$ELEBAKE_LIBDIR" rev-parse --short HEAD 2>/dev/null)
        printf 'elebake %s %s\n' "$ELEBAKE_FORMAT" "${commit:-unknown}"
}

#@help __dump0
# @command dump [<strategy> [<stage>|all]]
# @summary Export the database as an executable shell script; the bare form is the COMPLETE description of every stage (strategy 'complete', scope 'all'). The strategy selects the vocabulary of the body: complete is everything the database holds, minimized is binary management only (loaders, kernel modules, loader.conf, backups, media -- what a rescue system needs to roll back). The dump is an EXECUTABLE description: keep it in git and replaying a committed dump reproduces the database. Import lines reference base elements against "$ELEBAKE_ARCHIVE_BASE"; 'export' pairs the dump with the bundle that carries them
# @group   database
# @example elebake dump > backup.sh
# @see     dump minimized
# @see     restore
# @see     batch
# @see     export
# @see     version
#@end
__dump0() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" dump complete all"
}

#@help __dump1
# @internal 1-arg fallback of 'dump': an unknown strategy is the same error as with a scope
#@end
__dump1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" dump '$1' all"
}

#@help __dump_complete0
# @internal 'dump complete' without a scope is every stage
#@end
__dump_complete0() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" dump complete all"
}

#@help __dump_minimized0
# @internal 'dump minimized' without a scope is every stage
#@end
__dump_minimized0() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" dump minimized all"
}

#@help ___dump_complete1
# @command dump complete <stage>|all
# @summary The complete dump: the prologue (header, environment, keys, provenance), the foundation arsenal as CLI replays, the full description of the stage (or every stage), the epilogue
# @group   database
# @example elebake dump complete daily-v1 > daily-v1.sh
# @see     dump
# @see     dump minimized
#@end
___dump_complete1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" dump prologue complete"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" foundation dump"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage dump complete '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" dump epilogue"
}

#@help ___dump_minimized1
# @command dump minimized <stage>|all
# @summary The minimized dump, the rescue vocabulary: the prologue (header, environment, keys, provenance), per stage only what binary management needs (record, media, backups, the loader/kernel/loader.conf subset of boot/), the epilogue. No foundation, no worktree, no bindings, no rebuild: a rescue system swaps binaries, it does not build them
# @group   database
# @example elebake dump minimized daily-v1 > rescue.sh
# @see     dump
# @see     dump complete
#@end
___dump_minimized1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" dump prologue minimized"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage dump minimized '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" dump epilogue"
}

#@help __dump2
# @internal arity-2 sibling of 'dump' (dump <strategy> <stage>|all): The total fallback behind the strategies (dispatch binds the longer name): an unknown strategy is an error line
#@end
__dump2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'dump: unknown strategy $1 (complete | minimized)'"
}

#@help ___dump_prologue1
# @command dump prologue <strategy>
# @summary The frame every dump opens with: the header (version, date, serial, strategy, base), the environment prologue (the old database's safe settings), the keys as CLI replays per backend, the provenance receipts
# @group   database
# @internal
# @see     dump
#@end
___dump_prologue1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" dump header '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" dump env prologue"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" pem dump"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" openpgp dump"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" pkcs11 dump"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" provenance dump"
}

#@help _dump_header1
# @command dump header <strategy>
# @summary Print the header of a dump: the generator ('elebake <format> <commit>', what 'version' prints), the format as '# Version:' (restore reads it), the date, the lineage serial (the number the last 'export' advanced to), the strategy and the base
# @group   database
# @internal
# @env     ELEBAKE_FORMAT  the dump format major version
# @see     version
# @see     restore
#@end
_dump_header1() {
        local commit=""
        commit=$(git -C "$ELEBAKE_LIBDIR" rev-parse --short HEAD 2>/dev/null)
        printf '# elebake database dump\n# Generator: elebake %s %s\n# Version: %s\n' "$ELEBAKE_FORMAT" "${commit:-unknown}" "$ELEBAKE_FORMAT"
        printf '# Generated: %s\n# Serial: %s\n# Strategy: %s\n# Base: %s\n\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$(serial_current)" "$1" "$ELEBAKE_BASE"
}

#@help ___dump_epilogue0
# @command dump epilogue
# @summary The frame every dump closes with: the environment epilogue (the old database's complete user environment)
# @group   database
# @internal
# @see     dump
#@end
___dump_epilogue0() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" dump env epilogue"
}

#@help __restore1
# @command restore <dump> [<base>]
# @summary Replay a dump into the current database -- only a dump signed by the PINNED attest key, at or above the lineage's serial; <base> binds where its base elements come from (default: this database). The dump's format (its '# Version:' header) selects the restore that speaks it: 'restore v<format> <dump> <base>'
# @group   database
# @env     ELEBAKE_ARCHIVE_ATTEST_KEY  the openpgp record naming the signer the dump must carry
# @example elebake restore backup.sh
# @see     dump
# @see     import
# @see     attest
# @see     version
# @env     ELEBAKE_ARCHIVE_BASE  bound for the replay: the dump's base elements are taken from there
# @env     ELEBAKE_BATCH_KEEP_GOING  0 = stop at the first failing line, 1 = replay everything
# @param   dump  dump file produced by 'dump' and signed by 'attest' (the signature is <dump>.asc)
# @param   base  an old database (migration) or an extracted bundle; absent = the elements are already here
#@end
__restore1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" restore '$1' '$ELEBAKE_BASE'"
}

#@help __restore2
# @internal arity-2 sibling of 'restore' (restore <dump> <base>): The dump's format decides (lifting): read '# Version:' from the header and rewrite to 'restore v<format> <dump> <base>'; a dump without the header is 'v?'
#@end
__restore2() {
        local format=""
        format=$(sed -n "s/^# Version: //p" "$1" 2>/dev/null | head -n1)
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" restore 'v${format:-?}' '$1' '$2'"
}

#@help ___restore_v22
# @command restore v2 <dump> <base>
# @summary Restore a format-2 dump: the file is readable, it carries a serial, the attest key is pinned, the dump is signed by that key, its serial is not below the signer's highest receipt (no downgrade), the base exists -- then the replay (a batch under keep-going, so a re-run survives 'stage add' on an existing stage)
# @group   database
# @internal
# @env     ELEBAKE_ARCHIVE_ATTEST_KEY  the openpgp record naming the signer
# @see     restore
#@end
___restore_v22() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" dump readable '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" dump serial numbered '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" archive key pinned"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" restore signer admissible '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" restore serial admissible '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" restore base exists '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" restore replay '$1' '$2'"
}

#@help __restore3
# @internal arity-3 sibling of 'restore' (restore <format> <dump> <base>): The total fallback behind the formats (dispatch binds the longer name): a dump format this elebake does not speak is an error line naming both formats
#@end
__restore3() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'restore: dump format ${1#v} not admissible (this elebake speaks v$ELEBAKE_FORMAT; re-export with it)'"
}

#@help __dump_readable1
# @command dump readable <dump>
# @summary The dump file is there and readable: a comment line, else an error line
# @group   database
# @internal
# @see     restore v2
#@end
__dump_readable1() {
        if test -r "$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'dump $1 readable'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'restore: dump file not found or not readable: $1'"
        fi
}

#@help __dump_serial_numbered1
# @command dump serial numbered <dump>
# @summary The dump carries a numeric '# Serial:' header: a comment line, else an error line
# @group   database
# @internal
# @see     restore v2
#@end
__dump_serial_numbered1() {
        if sed -n "s/^# Serial: //p" "$1" 2>/dev/null | head -n1 | grep -qx "[0-9][0-9]*"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'dump $1 carries a serial'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'restore: dump carries no numeric # Serial: header: $1'"
        fi
}

#@help __archive_key_pinned0
# @command archive key pinned
# @summary ELEBAKE_ARCHIVE_ATTEST_KEY names an openpgp record that is there with its keyid: a comment line, else an error line -- the signer both artifacts of a pair carry (export) and the receiver expects (import, restore)
# @group   database
# @internal
# @see     restore v2
# @see     export
# @see     import
#@end
__archive_key_pinned0() {
        if test -n "${ELEBAKE_ARCHIVE_ATTEST_KEY:-}" && test -f "$ELEBAKE_BASE/openpgp/${ELEBAKE_ARCHIVE_ATTEST_KEY:-}/keyid"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'attest key ${ELEBAKE_ARCHIVE_ATTEST_KEY:-} pinned'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'ELEBAKE_ARCHIVE_ATTEST_KEY not set or its openpgp record incomplete (openpgp add <name> <fingerprint>; setenv ELEBAKE_ARCHIVE_ATTEST_KEY <name>)'"
        fi
}

#@help __restore_signer_admissible1
# @command restore signer admissible <dump>
# @summary The dump's signature (<dump>.asc) verifies against the pinned key: a comment line, else an error line with the verifier's reason
# @group   database
# @internal
# @see     restore v2
# @env     ELEBAKE_ARCHIVE_ATTEST_KEY  the openpgp record naming the pinned signer
#@end
__restore_signer_admissible1() {
        local fpr=""
        if fpr=$(attest_signer "$1" "$(sed -n 1p "$ELEBAKE_BASE/openpgp/${ELEBAKE_ARCHIVE_ATTEST_KEY:-}/keyid" 2>/dev/null)" "$(sed -n 1p "$ELEBAKE_BASE/openpgp/${ELEBAKE_ARCHIVE_ATTEST_KEY:-}/gnupghome" 2>/dev/null)"); then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'dump $1 signed by $fpr'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error $(sq "restore: $fpr (dump $1, expected signer: openpgp record ${ELEBAKE_ARCHIVE_ATTEST_KEY:-})")"
        fi
}

#@help __restore_serial_admissible1
# @command restore serial admissible <dump>
# @summary The dump's serial is not below the signer's highest receipt in this database: a comment line, else an error line -- a DOWNGRADE is refused
# @group   database
# @internal
# @see     restore v2
# @env     ELEBAKE_ARCHIVE_ATTEST_KEY  the openpgp record naming the pinned signer (its receipts set the floor)
#@end
__restore_serial_admissible1() {
        local fpr="" serial="" floor=""
        fpr=$(attest_signer "$1" "$(sed -n 1p "$ELEBAKE_BASE/openpgp/${ELEBAKE_ARCHIVE_ATTEST_KEY:-}/keyid" 2>/dev/null)" "$(sed -n 1p "$ELEBAKE_BASE/openpgp/${ELEBAKE_ARCHIVE_ATTEST_KEY:-}/gnupghome" 2>/dev/null)" 2>/dev/null)
        serial=$(sed -n "s/^# Serial: //p" "$1" 2>/dev/null | head -n1)
        floor=$(serial_floor "$fpr" 2>/dev/null)
        if test "${serial:-0}" -ge "${floor:-0}" 2>/dev/null; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'dump serial $serial at or above the receipt floor $floor'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'restore: DOWNGRADE refused: dump serial $serial is below the highest receipt $floor of signer $fpr'"
        fi
}

#@help __restore_base_exists1
# @command restore base exists <base>
# @summary The base directory the replay takes its elements from is there: a comment line, else an error line
# @group   database
# @internal
# @see     restore v2
#@end
__restore_base_exists1() {
        if test -d "$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'base $1 exists'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'restore: base directory not found: $1'"
        fi
}

#@help __restore_replay2
# @command restore replay <dump> <base>
# @summary The one line that replays the dump -- 'batch <dump>' with ELEBAKE_ARCHIVE_BASE bound to <base> in front of it (the child skips the startup re-exec, so the batch expands the dump's "$ELEBAKE_ARCHIVE_BASE/..." against that directory). Its interpreter pin wraps the executing interpreter and sets keep-going for the spawned batch; cat = dry-run
# @group   database
# @internal
# @env     ELEBAKE_INTERPRETER_restore_replay  wraps the interpreter and sets keep-going; cat = dry-run
# @see     restore v2
# @see     batch
#@end
__restore_replay2() {
        printf '%s\n' "env ELEBAKE_ARCHIVE_BASE='$2' \"\$ELEBAKE_CONTEXT_SCRIPT\" batch '$1'"
}

#@help ___batch0
# @internal arity-0 sibling of 'batch' (reads commands from stdin)
#@end
___batch0() {
        local tempfile="$ELEBAKE_BASE/.tmp/batch.$$"

        cat <<EOF
"\$ELEBAKE_CONTEXT_SCRIPT" cat "$tempfile"
"\$ELEBAKE_CONTEXT_SCRIPT" batch "$tempfile" true
EOF
}

#@help __batch1
# @command batch <file>
# @summary Execute a file of elebake commands line by line (ELEBAKE_BATCH_KEEP_GOING: 0 = stop at the first failing line, 1 = keep going): the file is readable: rewrite to the runner 'batch <file> false' (no cleanup), else an error line
# @group   database
# @param   file  file of commands to execute
# @example elebake batch commands.txt
# @env     ELEBAKE_BATCH_KEEP_GOING  0 = stop at the first failing line, 1 = keep going
# @see     restore
#@end
__batch1() {
        if test -r "$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" batch '$1' false"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'batch: file not found or not readable: $1'"
        fi
}

#@help _batch2
# @internal batch execution chain step

# @env ELEBAKE_BATCH_KEEP_GOING  0 = stop at the first failing line, 1 = keep going
#@end
_batch2() {
        local filepath="$1"
        local cleanup="${2:-false}"
        local keep_going="${ELEBAKE_BATCH_KEEP_GOING:-0}"
        # keep-going belongs to THIS batch (its pin set it); a nested batch decides
        # for itself -- inherited, the checks of an inner batch would not stop its act
        unset ELEBAKE_BATCH_KEEP_GOING
        local base="$ELEBAKE_BASE"
        local success_count=0
        local fail_count=0

        # Save current batch2 interpreter to prevent nested batch double-cutting
        # Nested batches (e.g., a batch that itself emits a batch) should use "cat" interpreter
        # to avoid applying cut -b3- multiple times, which causes truncated output
        local saved_batch_interpreter="${ELEBAKE_INTERPRETER_batch2:-cat}"
        export ELEBAKE_INTERPRETER_batch2="cat"

        # Get batch ID for exit code storage
        local batch_id
        batch_id=$(get_batch_id)
        if [ -z "$batch_id" ]; then
                trace_log "!" "_batch2" "Failed to allocate batch ID"
                export ELEBAKE_INTERPRETER_batch2="$saved_batch_interpreter"
                set +e
                return 1
        fi

        # Extract producer bit from EXIT_BITS
        # Last character should be the producer bit we just set
        local exit_bits="${ELEBAKE_CONTEXT_EXIT_BITS:-0}"
        local p_bit="${exit_bits##* }"
        # Handle case where EXIT_BITS might just be "0" or "1" (not space-separated)
        case "$p_bit" in
        0|1) ;;  # Valid bit
        *) p_bit=0 ;;  # Default to 0 if unclear
        esac

        # Calculate batch exit code: 128 + (p << 6) + batch_id
        local batch_exit=$((128 + (p_bit << 6) + batch_id))

        # Create batch file with enhanced format
        local batch_file="$ELEBAKE_BASE/.tmp/batch-exits/$batch_id"
        # Truncate existing file or create new one (round-robin allocation)
        if ! : > "$batch_file" 2>>"$LOG_FILE"; then
                echo "# Error: Failed to create batch file: $batch_file" >&2
                export ELEBAKE_INTERPRETER_batch2="$saved_batch_interpreter"
                set +e
                return 1
        fi

        trace_log "|" "_batch2" "Batch execution (batch_id=$batch_id, producer_bit=$p_bit)"

        # Note: .tmp and .env/local directories created by init

        # Read commands from file and execute them
        # Note: || [ -n "$line" ] prevents set -e from triggering on EOF
        # and allows processing the last line even without trailing newline
        while IFS= read -r line || [ -n "$line" ]; do
                # Pass through empty lines (preserves dump formatting)
                if [ -z "$line" ]; then
                        echo ""
                        continue
                fi

                # Reproduce comments to stdout (for dump), then skip processing
                case "$line" in
                \#*)
                echo "$line"
                continue
                ;;
        esac

        # Validate line starts with elebake script context variable reference
        # Batch/dump files use the LITERAL string "$ELEBAKE_CONTEXT_SCRIPT" for portability
        # This ensures the dump is independent of the specific elebake.sh path that created it
        #
        # Expected format: "$ELEBAKE_CONTEXT_SCRIPT" <command> <args...>
        # Example:        "$ELEBAKE_CONTEXT_SCRIPT" setenv ELEBAKE_DISPLAY_ANSI 1
        case "$line" in
        \"\$ELEBAKE_CONTEXT_SCRIPT\"\ *)
        # Valid: quoted variable reference (portable format used in dump files)
        # Strip the literal "$ELEBAKE_CONTEXT_SCRIPT" and extract arguments
        remaining_args="${line#\"\$ELEBAKE_CONTEXT_SCRIPT\"}"
        remaining_args="${remaining_args# }"
        ;;
        *)
        # Invalid line - not a valid batch command
        echo "# ✗ Invalid batch file syntax: $line" >&2
        echo "#   Expected: \"\$ELEBAKE_CONTEXT_SCRIPT\" <command> <args...>" >&2
        echo "#   Example:  \"\$ELEBAKE_CONTEXT_SCRIPT\" setenv ELEBAKE_DISPLAY_ANSI 1" >&2
        fail_count=$((fail_count + 1))

        # Stop on error unless keep-going mode
        if [ "$keep_going" != "1" ]; then
                echo "" >&2
                echo "# Batch execution stopped due to error (fail-fast mode)" >&2
                echo "# Summary: $success_count succeeded, $fail_count failed" >&2
                export ELEBAKE_INTERPRETER_batch2="$saved_batch_interpreter"
                set +e
                return 1
        fi
        continue
        ;;
        esac

        # Skip if remaining_args is empty (malformed command)
        if [ -z "$remaining_args" ]; then
                echo "# ✗ Empty command after stripping script prefix" >&2
                fail_count=$((fail_count + 1))
                continue
        fi

        # Execute elebake commands via process_arguments()
        # This ensures each command gets its proper interpreter (terminal, combinator, or batch_combinator)
        # and tracing continues if ELEBAKE_TRACE_FILE is set
        trace_log "|" "_batch2" "Executing: $line"

        # Get function call for recording (resolve arguments to function name)
        local function_call=$(to_function_call "$ANCHOR_FUNCTIONS" $remaining_args)

        # Execute command
        eval "process_arguments $remaining_args"
        local exit_code=$?

        # Record result in batch file
        # Format: EXIT_CODE|function args|BATCH_REF -- the pointer only for a line
        # whose function returns one (the runner, or a batch combinator)
        local line_is_batch=0
        case "${function_call%% *}" in
        _batch2|___*) line_is_batch=1 ;;
        esac
        if [ "$line_is_batch" = 1 ] && [ "$exit_code" -ge 128 ]; then
                # Nested batch: extract batch_id from exit code
                local nested_batch_id=$(( (exit_code - 128) & 0x3F ))
                echo "${exit_code}|${function_call}|${nested_batch_id}" >> "$batch_file"
        else
                # Regular exit
                echo "${exit_code}|${function_call}|" >> "$batch_file"
        fi

        # Track success/failure using recursive batch checker
        if ! check_batch_success "$exit_code" "$line_is_batch"; then
                trace_log "!" "_batch2" "Failed (exit code: $exit_code)"
                fail_count=$((fail_count + 1))
                echo "# failed: $line" >&2

                # Stop on error unless keep-going mode
                if [ "$keep_going" != "1" ]; then
                        echo "" >&2
                        echo "# Batch execution stopped due to error (fail-fast mode)" >&2
                        echo "# Summary: $success_count succeeded, $fail_count failed" >&2
                        export ELEBAKE_INTERPRETER_batch2="$saved_batch_interpreter"
                        set +e  # Ensure set +e before returning batch code
                        return "$batch_exit"
                fi
        else
                trace_log "|" "_batch2" "Success"
                success_count=$((success_count + 1))
        fi
        done < "$filepath"

        trace_log "|" "_batch2" "While loop completed"

        # Summary
        trace_log "|" "_batch2" "Summary: $success_count succeeded, $fail_count failed"

        # Show EXIT_BITS structure
        if [ -n "${ELEBAKE_CONTEXT_EXIT_BITS:-}" ]; then
                trace_log "|" "_batch2" "EXIT_BITS structure: ${ELEBAKE_CONTEXT_EXIT_BITS}"
        fi

        trace_log "|" "_batch2" "========================================"

        # Clean up temp file only on success (keep on failure for debugging)
        if [ $fail_count -eq 0 ] && [ "$cleanup" = "true" ]; then
                $MODIFY_FILE_REMOVE "$filepath"
        fi

        # Note: batch-exits file NOT cleaned up - retained for diagnostics
        # Round-robin allocation naturally overwrites old batch files

        trace_log "|" "_batch2" "Returning batch_exit=$batch_exit"

        # Restore original batch2 interpreter before returning
        export ELEBAKE_INTERPRETER_batch2="$saved_batch_interpreter"

        # CRITICAL: Ensure set +e before returning batch code >= 128
        # This prevents shell exit when returning non-zero exit codes
        set +e

        # Return batch exit code (128 + (p << 6) + batch_id)
        # This allows the caller to decode results using: elebake debug-exit $?
        return "$batch_exit"
}

#@help _printenv0
# @command printenv [<VAR>]
# @summary Show all effective environment variables, or just one
# @group   configuration
# @param   VAR  restrict output to a single variable
# @returns the effective environment
# @example elebake printenv
# @see     getenv
#@end
_printenv0() {
        cat <<EOF
echo "# =============================================================================="
echo "# Environment variables in isolated context:"
echo "# (sorted alphabetically)"
echo ""
printenv | sort
echo "# =============================================================================="
EOF
}

#@help __collect0
# @command collect [<stage>|all]
# @summary The complete list of files an archive must carry: every key class, the provenance, the foundation -- and with a stage its records and boot artifacts. The bare form is 'collect all'
# @group   database
# @example elebake collect
# @example elebake collect daily-v1
# @see     export
#@end
__collect0() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" collect all"
}

#@help ___collect_all0
# @command collect all
# @summary Every class an archive carries: the stage-independent classes ('collect classes') and every stage ('stage collect')
# @group   database
# @internal
# @see     collect
#@end
___collect_all0() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" collect classes"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage collect"
}

#@help ___collect_classes0
# @command collect classes
# @summary Fan out to the stage-independent classes: pem, openpgp, pkcs11, provenance, foundation
# @group   database
# @internal
# @see     collect all
#@end
___collect_classes0() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" pem collect"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" openpgp collect"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" pkcs11 collect"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" provenance collect"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" foundation collect"
}

#@help ___collect1
# @internal arity-1 sibling of 'collect' (collect <stage>): The stage-independent classes ('collect classes') and the one stage's files
#@end
___collect1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" collect classes"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage collect '$1'"
}

#@help __filter2
# @command filter <collection> <filtered>
# @summary Apply the default strategy to a collection (delegates: default -> redacted)
# @group   database
# @see     filter redacted
#@end
__filter2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" filter default '$1' '$2'"
}

#@help __filter_default2
# @internal the user's notion of a default, as one visible line
#@end
__filter_default2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" filter redacted '$1' '$2'"
}

#@help __filter3
# @internal arity-3 fallback of 'filter': an unknown strategy is an error line
#@end
__filter3() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'filter: unknown strategy $1 (redacted | full | minimized)'"
}

#@help __filter_redacted2
# @command filter redacted <collection> <filtered>
# @summary Drop what is a machine secret in spirit: marker values, site.mk baselines, backups -- and always the operational directories. What a bug report needs, without the reporter's fingerprints. The collection is readable: rewrite to 'filter write redacted ...', else an error line
# @group   database
# @example elebake filter redacted export/collection export/filtered
# @see     filter write
#@end
__filter_redacted2() {
        if test -r "$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" filter write redacted '$1' '$2'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'filter redacted: no such collection $1'"
        fi
}

#@help __filter_full2
# @command filter full <collection> <filtered>
# @summary Keep everything except the operational directories. For one's own disaster recovery, never for sending. The collection is readable: rewrite to 'filter write full ...', else an error line
# @group   database
# @see     filter write
#@end
__filter_full2() {
        if test -r "$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" filter write full '$1' '$2'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'filter full: no such collection $1'"
        fi
}

#@help __filter_minimized2
# @command filter minimized <collection> <filtered>
# @summary Keep binary management only: per stage the loader (built and signed), loader.conf, kernel and modules, the manifest pair, media and backups; keys and receipts. What a rescue system needs to roll back or repair, nothing to build with. The collection is readable: rewrite to 'filter write minimized ...', else an error line
# @group   database
# @example elebake filter minimized export/collection export/filtered
# @see     filter write
#@end
__filter_minimized2() {
        if test -r "$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" filter write minimized '$1' '$2'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'filter minimized: no such collection $1'"
        fi
}

#@help _filter_write3
# @command filter write <strategy> <collection> <filtered>
# @summary Act terminal: the script that writes the filtered collection -- every line of the collection kept, or turned into an auditable '# dropped (<reason>)' comment, as template/filter/<strategy>.drop and .keep say (matched by template/awk/filter.awk); the file is 0600
# @group   database
# @internal
# @env     ELEBAKE_TEMPLATE_DIR  where filter/<strategy>.drop, filter/<strategy>.keep and awk/filter.awk live
# @see     filter redacted
# @see     filter full
# @see     filter minimized
#@end
_filter_write3() {
        printf '%s\n' "cat > '$3' <<'ELVCOLLECTION'"
        awk -v strategy="$1" -v drop="$ELEBAKE_TEMPLATE_DIR/filter/$1.drop" -v keep="$ELEBAKE_TEMPLATE_DIR/filter/$1.keep" -f "$ELEBAKE_TEMPLATE_DIR/awk/filter.awk" "$2" 2>/dev/null
        printf '%s\n' "ELVCOLLECTION"
        printf '%s\n' "$MODIFY_FILE_PERMS 0600 '$3'"
        emit_note "filtered ($1): $3"
}

#@help ___bundle2
# @command bundle <collection> <archive>
# @summary Pack the collected files with ELEBAKE_ARCHIVER: the collection is readable, the archiver set, the archive path absolute, the manifest pair (MANIFEST + MANIFEST.asc) lies beside the collection -- an archive that carries no tamper detection is not an artifact this tool produces -- and the collection lives inside the database (the pair is packed by its database-relative path); then 'bundle pack'
# @group   database
# @env     ELEBAKE_ARCHIVER  the packing template; $a is the archive, $b the base directory
# @env     ELEBAKE_ARCHIVE_BASE  the prefix collection lines are written against
# @example elebake bundle export/filtered ~/.elebake/bundle/a1b2c3d.tar.gz
# @see     extract
# @see     manifest attest
# @see     bundle pack
#@end
___bundle2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" collection readable '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" archiver set"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" bundle archive absolute '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" bundle manifest beside '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" bundle collection inside '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" bundle pack '$1' '$2'"
}

#@help __collection_readable1
# @command collection readable <collection>
# @summary The collection file is there and readable: a comment line, else an error line
# @group   database
# @internal
# @see     bundle
# @see     filter redacted
#@end
__collection_readable1() {
        if test -r "$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'collection $1 readable'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'no such collection $1'"
        fi
}

#@help __archiver_set0
# @command archiver set
# @summary ELEBAKE_ARCHIVER is set: a comment line, else an error line (environment init <profile>)
# @group   database
# @internal
# @env     ELEBAKE_ARCHIVER  the packing template
# @see     bundle
#@end
__archiver_set0() {
        if test -n "${ELEBAKE_ARCHIVER:-}"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'archiver set'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'bundle: ELEBAKE_ARCHIVER not set (environment init <profile>)'"
        fi
}

#@help __bundle_archive_absolute1
# @command bundle archive absolute <archive>
# @summary The archive path is absolute: a comment line, else an error line
# @group   database
# @internal
# @see     bundle
#@end
__bundle_archive_absolute1() {
        if test "${1#/}" != "$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'archive path $1 absolute'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'bundle: archive must be an absolute path: $1'"
        fi
}

#@help __bundle_manifest_beside1
# @command bundle manifest beside <collection>
# @summary MANIFEST and MANIFEST.asc lie beside the collection (where 'manifest attest' puts them; the manifest cannot list itself, exactly as boot/manifest excludes itself and its signature): a comment line, else an error line
# @group   database
# @internal
# @see     bundle
# @see     manifest attest
#@end
__bundle_manifest_beside1() {
        if test -f "$(dirname "$1")/MANIFEST" && test -f "$(dirname "$1")/MANIFEST.asc"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'manifest pair beside $1'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'bundle: no MANIFEST + MANIFEST.asc beside the collection ($(dirname "$1"))' '(manifest attest <collection> <key> first -- an archive without tamper detection is not produced)'"
        fi
}

#@help __bundle_collection_inside1
# @command bundle collection inside <collection>
# @summary The collection's directory lies inside the database, so the manifest pair has a database-relative path to be packed by: a comment line, else an error line
# @group   database
# @internal
# @see     bundle
#@end
__bundle_collection_inside1() {
        if test "${1#"$ELEBAKE_BASE"/}" != "$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'collection $1 inside the database'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'bundle: the collection must live inside the database ($ELEBAKE_BASE), not at $(dirname "$1")' '(the manifest pair is packed by its database-relative path)'"
        fi
}

#@help _bundle_pack2
# @command bundle pack <collection> <archive>
# @summary Act terminal: the packing script -- the archive's directory, $a and $b for the ELEBAKE_ARCHIVER template, the template in a group (a pipeline's heredoc would attach to its LAST command) fed the database-relative file list of the collection plus MANIFEST and MANIFEST.asc beside it; the archive is 0600
# @group   database
# @internal
# @env     ELEBAKE_ARCHIVER  the packing template; $a is the archive, $b the base directory
# @see     bundle
# @env     ELEBAKE_ARCHIVE_BASE  the prefix collection lines are written against
#@end
_bundle_pack2() {
        local line="" rel="" mrel="" n=0
        mrel=${1#"$ELEBAKE_BASE"/}
        mrel=$(dirname "$mrel")/
        printf '%s\n' "$MODIFY_DIR_CREATE '$(dirname "$2")'"
        printf "a='%s'\n" "$2"
        printf "b='%s'\n" "$ELEBAKE_BASE"
        printf '%s\n' "{ $ELEBAKE_ARCHIVER ; } <<'ELVBUNDLE'"
        grep -v '^#' "$1" 2>/dev/null | grep . | sed 's|^"\$ELEBAKE_ARCHIVE_BASE"/||'
        printf '%s\n' "${mrel#./}MANIFEST"
        printf '%s\n' "${mrel#./}MANIFEST.asc"
        printf '%s\n' "ELVBUNDLE"
        printf '%s\n' "$MODIFY_FILE_PERMS 0600 '$2'"
        n=$(grep -v '^#' "$1" 2>/dev/null | grep -c .)
        emit_note "bundled $((n + 2)) entries (MANIFEST + MANIFEST.asc included) -> $2"
}

#@help ___seal2
# @command seal <dump> <bundle>
# @summary Append the bundle's sha256 and size to the dump as its seal line ('# Bundle: sha256=... bytes=...'): both files readable, the dump not yet sealed (a dump names ONE bundle) and not yet attested (sealing after signing would invalidate the signature); then 'seal write'. Attest the dump AFTER sealing so one signature covers both
# @group   database
# @example elebake seal ~/git/config/dump.sh ~/.elebake/bundle/a1b2c3d.tar.gz
# @see     seal verify
# @see     export
# @see     seal write
#@end
___seal2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" dump readable '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" bundle readable '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" seal absent '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" attest absent '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" seal write '$1' '$2'"
}

#@help __bundle_readable1
# @command bundle readable <bundle>
# @summary The bundle (an archive file) is there and readable: a comment line, else an error line
# @group   database
# @internal
# @see     seal
# @see     extract
#@end
__bundle_readable1() {
        if test -r "$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'bundle $1 readable'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'no such bundle $1'"
        fi
}

#@help __seal_absent1
# @command seal absent <dump>
# @summary The dump carries no seal line yet: a comment line, else an error line (a dump names ONE bundle; export again for a new pair)
# @group   database
# @internal
# @see     seal
#@end
__seal_absent1() {
        if ! grep -qs '^# Bundle: sha256=' "$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'dump $1 not yet sealed'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'seal: $1 is already sealed (a dump names ONE bundle; export again for a new pair)'"
        fi
}

#@help __attest_absent1
# @command attest absent <dump>
# @summary No detached signature <dump>.asc exists yet: a comment line, else an error line
# @group   database
# @internal
# @see     seal
#@end
__attest_absent1() {
        if test ! -f "$1.asc"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'dump $1 not yet attested'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'seal: $1 is already attested -- sealing after signing would invalidate the signature'"
        fi
}

#@help _seal_write2
# @command seal write <dump> <bundle>
# @summary Act terminal: the one line that appends the seal ('# Bundle: sha256=<sha256 of the bundle> bytes=<size>') to the dump; the hash is computed here, at generation
# @group   database
# @internal
# @see     seal
#@end
_seal_write2() {
        local line=""
        line="# Bundle: sha256=$(sha256 -q "$2" 2>/dev/null) bytes=$(wc -c 2>/dev/null < "$2" | tr -d ' ')"
        emit_note "seal: $1 names $(basename "$2") (${line#\# Bundle: })"
        printf '%s\n' "printf '%s\\n' '$line' >> '$1'"
}

#@help ___seal_verify2
# @command seal verify <dump> <bundle>
# @summary Check that the dump's seal line names THIS bundle (sha256 and size): both files readable, the dump sealed, the seal matching -- a mismatch fails the command before anything is extracted
# @group   database
# @example elebake seal verify dump.sh ~/.elebake/bundle/a1b2c3d.tar.gz
# @see     seal
# @see     import
#@end
___seal_verify2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" dump readable '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" bundle readable '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" seal present '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" seal matches '$1' '$2'"
}

#@help __seal_present1
# @command seal present <dump>
# @summary The dump carries a seal line: a comment line, else an error line (it was not exported with a bundle -- a dump and a bundle are bound by content, not by name)
# @group   database
# @internal
# @see     seal verify
#@end
__seal_present1() {
        if grep -qs '^# Bundle: sha256=' "$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'dump $1 sealed'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'seal verify: $1 carries no seal line -- it was not exported with a bundle' '(a dump and a bundle are bound by content, not by name)'"
        fi
}

#@help __seal_matches2
# @command seal matches <dump> <bundle>
# @summary The dump's seal line equals this bundle's sha256 and size: a log line, else an error line (MISMATCHED PAIR)
# @group   database
# @internal
# @see     seal verify
#@end
__seal_matches2() {
        local want="" have=""
        want=$(grep '^# Bundle: sha256=' "$1" 2>/dev/null | head -n1)
        have="# Bundle: sha256=$(sha256 -q "$2" 2>/dev/null) bytes=$(wc -c 2>/dev/null < "$2" | tr -d ' ')"
        if test "$want" = "$have"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log 'seal verify: $(basename "$2") is the bundle $1 names (${have#\# Bundle: })'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'seal verify: MISMATCHED PAIR -- $1 does not name this bundle' '(dump says   ${want#\# Bundle: })' '(bundle is   ${have#\# Bundle: })'"
        fi
}

#@help __incoming_clear1
# @command incoming clear <directory>
# @summary Empty one scratch directory under $ELEBAKE_ROOT/incoming/ -- import's own unpacking area, cleared before each extract so a re-import never trips over the last one. The path lies below incoming/ and carries no '..': rewrite to 'incoming remove', else an error line (only import's own scratch is cleared here, never a database)
# @group   database
# @see     extract
# @see     import
#@end
__incoming_clear1() {
        if test "${1#"$ELEBAKE_ROOT"/incoming/}" != "$1" && test "${1%%..*}" = "$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" incoming remove '$1'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'incoming clear: not below $ELEBAKE_ROOT/incoming (or carrying ..): $1' '(only the scratch of import is cleared here, never a database)'"
        fi
}

#@help _incoming_remove1
# @command incoming remove <directory>
# @summary Act terminal: rm -rf of the scratch directory
# @group   database
# @internal
# @see     incoming clear
#@end
_incoming_remove1() {
        emit_note "incoming clear: $1"
        printf '%s\n' "rm -rf '$1'"
}

#@help ___extract2
# @command extract <archive> <destination>
# @summary Unpack an archive into a scratch directory with ELEBAKE_EXTRACTOR: the archive readable, the extractor set, the destination absolute and empty (or not yet there); then 'extract unpack'
# @group   database
# @env     ELEBAKE_EXTRACTOR  the unpacking template; $a is the archive, $d the destination
# @example elebake extract ~/.elebake/bundle/a1b2c3d.tar.gz /tmp/incoming
# @see     bundle
# @see     import
#@end
___extract2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" bundle readable '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" extractor set"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" extract destination absolute '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" extract destination empty '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" extract unpack '$1' '$2'"
}

#@help __extractor_set0
# @command extractor set
# @summary ELEBAKE_EXTRACTOR is set: a comment line, else an error line (environment init <profile>)
# @group   database
# @internal
# @env     ELEBAKE_EXTRACTOR  the unpacking template
# @see     extract
#@end
__extractor_set0() {
        if test -n "${ELEBAKE_EXTRACTOR:-}"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'extractor set'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'extract: ELEBAKE_EXTRACTOR not set (environment init <profile>)'"
        fi
}

#@help __extract_destination_absolute1
# @command extract destination absolute <destination>
# @summary The destination path is absolute: a comment line, else an error line
# @group   database
# @internal
# @see     extract
#@end
__extract_destination_absolute1() {
        if test "${1#/}" != "$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'destination $1 absolute'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'extract: destination must be an absolute path: $1'"
        fi
}

#@help __extract_destination_empty1
# @command extract destination empty <destination>
# @summary The destination is empty or not there yet: a comment line, else an error line (choose an empty or new directory)
# @group   database
# @internal
# @see     extract
#@end
__extract_destination_empty1() {
        if test -z "$(ls -A "$1" 2>/dev/null)"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'destination $1 empty'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'extract: destination not empty: $1 (choose an empty or new directory)'"
        fi
}

#@help _extract_unpack2
# @command extract unpack <archive> <destination>
# @summary Act terminal: the unpacking script -- the destination directory, $a and $d for the ELEBAKE_EXTRACTOR template, the template
# @group   database
# @internal
# @env     ELEBAKE_EXTRACTOR  the unpacking template; $a is the archive, $d the destination
# @see     extract
#@end
_extract_unpack2() {
        printf '%s\n' "$MODIFY_DIR_CREATE '$2'"
        printf "a='%s'\n" "$1"
        printf "d='%s'\n" "$2"
        printf '%s\n' "$ELEBAKE_EXTRACTOR"
        emit_note "extracted $1 -> $2"
}

#@help __export3
# @command export <strategy> <dump> <bundle> [<stage>|all]
# @summary Write the two artifacts that travel apart, bound and signed: the DUMP to a path of your choosing (commit it), the BUNDLE to its store. The strategy is the first word: redacted (no machine secrets, for sending) | full (own disaster recovery) | minimized (rescue: loaders, kernel, loader.conf, backups, media). redacted and full describe the database completely and govern the payload only; minimized describes and carries binary management only. The bare form covers every stage
# @group   database
# @param   strategy  redacted | full | minimized
# @param   stage     narrow the pair to one stage; 'all' is every stage
# @env     ELEBAKE_ARCHIVE_ATTEST_KEY  the openpgp record that signs the bundle's MANIFEST and the dump
# @example elebake export full ~/git/config/dump.sh ~/.elebake/bundle/a1b2c3d.tar.gz
# @example elebake export minimized ~/rescue/dump.sh ~/rescue/bundle.tar.gz
# @example elebake export redacted ~/git/config/dump.sh ~/.elebake/bundle/a1b2c3d.tar.gz daily-v1
# @see     import
# @see     export redacted
# @see     export full
# @see     export minimized
#@end
__export3() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'export: unknown strategy $1 (redacted | full | minimized)'"
}

#@help __export4
# @internal arity-4 fallback of 'export': an unknown strategy with a scope is the same error
#@end
__export4() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'export: unknown strategy $1 (redacted | full | minimized)'"
}

#@help __export_redacted2
# @internal arity-2 sibling of 'export redacted' (export redacted <dump> <bundle>): Export the complete description and the payload without machine secrets (marker values, site.mk baselines, backups), every stage: rewrite to 'export redacted <dump> <bundle> all'
#@end
__export_redacted2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" export redacted '$1' '$2' all"
}

#@help __export_redacted3
# @command export redacted <dump> <bundle> <stage>|all
# @summary Export the complete description and the payload without machine secrets (marker values, site.mk baselines, backups): rewrite to 'export pair complete redacted ...' -- the complete dump with the redacted payload
# @group   database
# @internal
# @see     export pair
#@end
__export_redacted3() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" export pair complete redacted '$1' '$2' '$3'"
}

#@help __export_full2
# @internal arity-2 sibling of 'export full' (export full <dump> <bundle>): Export the complete description and the complete payload, every stage: rewrite to 'export full <dump> <bundle> all'
#@end
__export_full2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" export full '$1' '$2' all"
}

#@help __export_full3
# @command export full <dump> <bundle> <stage>|all
# @summary Export the complete description and the complete payload: rewrite to 'export pair complete full ...' -- the complete dump with the full payload
# @group   database
# @internal
# @see     export pair
#@end
__export_full3() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" export pair complete full '$1' '$2' '$3'"
}

#@help __export_minimized2
# @internal arity-2 sibling of 'export minimized' (export minimized <dump> <bundle>): Export the rescue vocabulary only, description and payload (loaders, kernel, loader.conf, backups, media), every stage: rewrite to 'export minimized <dump> <bundle> all'
#@end
__export_minimized2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" export minimized '$1' '$2' all"
}

#@help __export_minimized3
# @command export minimized <dump> <bundle> <stage>|all
# @summary Export the rescue vocabulary only, description and payload (loaders, kernel, loader.conf, backups, media): rewrite to 'export pair minimized minimized ...' -- the minimized dump with the minimized payload
# @group   database
# @internal
# @see     export pair
#@end
__export_minimized3() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" export pair minimized minimized '$1' '$2' '$3'"
}

#@help ___export_pair5
# @command export pair <dump-strategy> <filter-strategy> <dump> <bundle> <stage>|all
# @summary The one export: advance the serial (so the dump carries it), write the dump, collect the files, filter the collection, attest its MANIFEST, bundle it, seal the pair (the seal hashes the bundle) and attest the dump LAST -- one signature covers the description, the seal and, through MANIFEST.asc, every file. The signer is the pinned archive key
# @group   database
# @internal
# @env     ELEBAKE_ARCHIVE_ATTEST_KEY  the openpgp record that signs
# @see     export
# @see     archive key pinned
# @see     seal
# @see     manifest attest
#@end
___export_pair5() {
        local work="$ELEBAKE_BASE/export" key="${ELEBAKE_ARCHIVE_ATTEST_KEY:-}"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" archive key pinned"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" provenance serial"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" dump '$1' '$5' > '$3'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" collect '$5' > '$work/collection.raw'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" filter '$2' '$work/collection.raw' '$work/collection'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" manifest attest '$work/collection' '$key'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" bundle '$work/collection' '$4'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" seal '$3' '$4'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" attest '$3' '$key'"
}

#@help ___import2
# @command import <dump> <bundle>
# @summary Replay an exported pair into the current database, checked end to end BEFORE anything lands, cheapest first: the pinned signer, the dump's signature, the seal (this bundle is the one the dump names), then -- unpacked into import's own scratch under incoming/ -- the bundle's MANIFEST (pinned signer, every hash). The receipt is filed BEFORE the replay (restore applies its own admissibility: signer, serial floor; the replay runs keep-going, so a redacted pair's withheld elements cost no receipt). restore re-checks the dump as every restore does
# @group   database
# @env     ELEBAKE_ARCHIVE_ATTEST_KEY  the openpgp record naming the signer both artifacts must carry -- the receiver's pin
# @example elebake import dump.sh ~/.elebake/bundle/a1b2c3d.tar.gz
# @see     export
# @see     archive key pinned
# @see     provenance list
#@end
___import2() {
        local inc="$ELEBAKE_ROOT/incoming/$(basename "$2" | sed 's/\.[a-z.]*$//')" key="${ELEBAKE_ARCHIVE_ATTEST_KEY:-}"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" archive key pinned"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" attest verify '$1' '$key'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" seal verify '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" incoming clear '$inc'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" extract '$2' '$inc'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" manifest verify '$inc/export/MANIFEST' '$inc' '$key'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" provenance add '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" restore '$1' '$inc'"
}

