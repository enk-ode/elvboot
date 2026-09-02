#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Dr. Johannes Brügmann

trace_log() {
  if [ -z "${ELEBAKE_TRACE_FILE:-}" ]; then
    return 0
  fi

  local marker="${1:-|}"
  local caller="${2:-unknown}"
  shift 2 2>>"$LOG_FILE" || return 0  # Shift safely, return if not enough args
  local message="$*"

  # Get current depth (default to 0)
  local depth="${ELEBAKE_TRACE_DEPTH:-0}"

  # Build depth prefix ("> " repeated depth times)
  local depth_prefix=""
  local i=0
  while [ "$i" -lt "$depth" ]; do
    depth_prefix="${depth_prefix}>  "
    i=$((i + 1))
  done

  # Format and write log entry
  # Format: <depth_prefix><marker> <caller>: <message>
  echo "${depth_prefix}${marker} ${caller}: ${message}" >> "$ELEBAKE_TRACE_FILE"
  return 0
}

safety_first_message() {
  cat <<'EOF'
# First time seeing commands instead of execution?
# This is safety-first mode (ELEBAKE_TERMINAL_INTERPRETER=cat).
# For auto-execution setup: elebake help environment
EOF
}

# should_skip_env_value - Should this env-file value be ignored?
#
# Args: $1 - value (first line of an .env file)
# Returns: 0 = skip (empty / whitespace-only / comment), 1 = use it.
#
# Lets a variable be disabled by commenting/blanking its file without deleting
# it, while keeping resolution simple: a comment does NOT block the default.
should_skip_env_value() {
  local value="$1"

  # Empty line - skip
  case "$value" in
    '') return 0 ;;
  esac

  # Whitespace-only line - skip
  case "$value" in
    *[![:space:]]*) ;;  # Has non-whitespace - continue checking
    *) return 0 ;;      # Only whitespace - skip
  esac

  # Comment line (with optional leading whitespace) - skip
  local trimmed=$(echo "$value" | sed 's/^[[:space:]]*//')
  case "$trimmed" in
    \#*) return 0 ;;    # Comment - skip
  esac

  return 1  # Use this value
}

build_env_args_full() {
  # Full environment scan (excludes cache file to avoid recursion)
  # Called by build_env_args() when cache is not available
  # Called by "environment cache on" to generate cache content

  # Return in-memory cached value if available (passed through env -)
  if [ -n "${ELEBAKE_CACHE_ENV_ARGS:-}" ]; then
    echo "$ELEBAKE_CACHE_ENV_ARGS"
    return 0
  fi

  local env_base="$ELEBAKE_ENV_DIR"
  local env_args=""
  local seen_vars=""

  # First pass: Load local overrides (highest priority)
  if [ -d "$env_base/local" ]; then
    for varfile in "$env_base/local"/*; do
      [ ! -f "$varfile" ] && continue

      local varname=$(basename "$varfile")

      # CRITICAL: Skip cache file to avoid recursion
      if [ "$varname" = "ELEBAKE_CACHE_ENV_ARGS" ]; then
        continue
      fi

      local value=$(head -n1 "$varfile")

      # Use helper to check if should skip
      if should_skip_env_value "$value"; then
        # DON'T mark as seen - allow default to load (less surprising)
        continue
      fi

      # Mark as seen ONLY when we actually use the value
      seen_vars="$seen_vars $varname "

      # Escape single quotes for shell eval: ' becomes '\''
      local escaped_value=$(printf '%s\n' "$value" | sed "s/'/'\\\\''/g")
      env_args="$env_args $varname='$escaped_value'"
    done
  fi

  # Second pass: Load defaults (only if not already set by local)
  if [ -d "$env_base/default" ]; then
    for varfile in "$env_base/default"/*; do
      [ ! -f "$varfile" ] && continue

      local varname=$(basename "$varfile")

      # Skip ELEBAKE_BASE - it's passed explicitly in run_env()
      if [ "$varname" = "ELEBAKE_BASE" ]; then
        display_warning "ELEBAKE_BASE found in .env files but will be ignored (must be set via environment)" >&2
        continue
      fi

      # Skip if already loaded from local
      case "$seen_vars" in
        *" $varname "*) continue ;;
      esac

      local value=$(head -n1 "$varfile")

      # Use helper to check if should skip
      if should_skip_env_value "$value"; then
        continue
      fi

      # Escape single quotes for shell eval: ' becomes '\''
      local escaped_value=$(printf '%s\n' "$value" | sed "s/'/'\\\\''/g")
      env_args="$env_args $varname='$escaped_value'"
    done
  fi

  echo "$env_args"
}

build_env_args() {
  # Smart router: Check disk cache first, fall back to full scan
  # Cache optimization: Reads 1 file instead of 41+ files
  # Enable with: elebake environment cache on

  local cache_file="$ELEBAKE_BASE/.env/local/ELEBAKE_CACHE_ENV_ARGS"

  # If disk cache exists, use it (fast path)
  if [ -f "$cache_file" ]; then
    cat "$cache_file"
    return 0
  fi

  # No cache - do full scan
  build_env_args_full
}

run_env() {
  # Execute external command (interpreter) in isolated environment
  # Usage: run_env -- <interpreter> [args...]
  # Example: run_env -- sh -c "wg-quick up wg0"
  #
  # This function is used ONLY for executing interpreters with proper environment isolation.
  # Internal commands no longer need run_env since environment is loaded at top level.

  # Validate usage
  if [ "$1" != "--" ]; then
    display error "run_env requires '--' marker for external commands"
    display plain "Usage: run_env -- <command> [args...]"
    return 1
  fi
  shift

  # Build or reuse cached environment variable arguments (performance optimization)
  local env_args
  if [ -n "${ELEBAKE_CACHE_ENV_ARGS:-}" ]; then
    env_args="$ELEBAKE_CACHE_ENV_ARGS"
  else
    env_args=$(build_env_args)
    # Cache for child processes by passing through env - boundary
    ELEBAKE_CACHE_ENV_ARGS="$env_args"
  fi

  local script_path="$ELEBAKE_CONTEXT_SCRIPT"

  # Build passthrough variables (context, cache, trace) - simple list for easy extension
  local passthrough=""

  # Add bootstrap marker to context (indicates environment loaded from .env files)
  passthrough="$passthrough ELEBAKE_CONTEXT_BOOTSTRAPPED=1"

  # Add cache (performance - reuse env_args in child processes)
  if [ -n "${ELEBAKE_CACHE_ENV_ARGS:-}" ]; then
    passthrough="$passthrough ELEBAKE_CACHE_ENV_ARGS=\"\$ELEBAKE_CACHE_ENV_ARGS\""
  fi

  # Add trace file (debugging context)
  if [ -n "${ELEBAKE_TRACE_FILE:-}" ]; then
    passthrough="$passthrough ELEBAKE_TRACE_FILE=\"\$ELEBAKE_TRACE_FILE\""
  fi

  # Add log file (debugging infrastructure - stderr redirection)
  if [ -n "${LOG_FILE:-}" ]; then
    passthrough="$passthrough LOG_FILE=\"\$LOG_FILE\""
  fi

  # Add trace depth (subprocess nesting level)
  if [ -n "${ELEBAKE_TRACE_DEPTH:-}" ]; then
    passthrough="$passthrough ELEBAKE_TRACE_DEPTH=\"\$ELEBAKE_TRACE_DEPTH\""
  fi

  # Add exit code bits (exit code accumulation through call tree)
  # Always pass through since it's initialized at startup
  passthrough="$passthrough ELEBAKE_CONTEXT_EXIT_BITS=\"\$ELEBAKE_CONTEXT_EXIT_BITS\""

  # Add command (interpreter context)
  if [ -n "${ELEBAKE_CONTEXT_COMMAND:-}" ]; then
    passthrough="$passthrough ELEBAKE_CONTEXT_COMMAND=\"\$ELEBAKE_CONTEXT_COMMAND\""
  fi

  # Add resolved function call (dispatch context)
  if [ -n "${ELEBAKE_CONTEXT_CALL:-}" ]; then
    passthrough="$passthrough ELEBAKE_CONTEXT_CALL=\"\$ELEBAKE_CONTEXT_CALL\""
  fi

  # Add display mode (inspect context override for plain-text diagnostics)
  if [ -n "${ELEBAKE_DISPLAY_ANSI:-}" ]; then
    passthrough="$passthrough ELEBAKE_DISPLAY_ANSI=\"\$ELEBAKE_DISPLAY_ANSI\""
  fi

  # Get current depth for logging (default to 0)
  local current_depth="${ELEBAKE_TRACE_DEPTH:-0}"
  # Calculate next depth for subprocess
  local next_depth=$((current_depth + 1))

  # Execute external command in isolated environment
  trace_log ">" "run_env" "External command: $*"
  # Update passthrough to include incremented depth for subprocess
  local subprocess_passthrough="$passthrough ELEBAKE_TRACE_DEPTH=$next_depth"

  # Build optional runtime variables (from parent environment, not .env files)
  local runtime_vars=""
  if [ -n "${ELEBAKE_BATCH_KEEP_GOING:-}" ]; then
    runtime_vars="$runtime_vars ELEBAKE_BATCH_KEEP_GOING=\"$ELEBAKE_BATCH_KEEP_GOING\""
  fi

  # PATH for the isolated command environment. The "$PATH" below is only a
  # fallback: if PATH is set in .env it appears later in $env_args and wins
  # (env applies the last assignment of a duplicate var). ELEBAKE_PATH is
  # NOT consulted here - it is baked only into generated command scripts.
  eval "env - PATH=\"$PATH\" $env_args $subprocess_passthrough $runtime_vars ELEBAKE_CONTEXT_SCRIPT=\"\$script_path\" ELEBAKE_BASE=\"\$ELEBAKE_BASE\" \"\$@\""
  local exit_code=$?
  trace_log "<" "run_env" "External command completed (exit: $exit_code)"

  # CRITICAL: Ensure set +e before returning (subprocess may have returned batch code >= 128)
  set +e
  return $exit_code
}

# _unknown_command1 - terminal for an unresolved command line (engine-generic).
# to_function_call() routes here when no anchor function matches the command.
# Emits an error to stderr plus a hint and exits non-zero. The argument is the
# accumulated command (underscore-joined by the resolver); shown space-joined.
# Pinned to sh via ELEBAKE_INTERPRETER_unknown_command=sh so it takes effect.
#@help _unknown_command1
# @internal dispatch fallback for an unresolved command line (pinned to sh)
#@end
_unknown_command1() {
  local cmd
  cmd=$(printf '%s' "$1" | tr '_' ' ')
  if [ "${ELEBAKE_DISPLAY_ANSI:-0}" != "0" ]; then
    echo "printf \"# \\033[1;31mError:\\033[0m unknown command: %s\\n\" \"$cmd\" >&2"
  else
    echo "printf \"# Error: unknown command: %s\\n\" \"$cmd\" >&2"
  fi
  echo "printf \"# (no such command, or a known command with the wrong number of arguments)\\n\" >&2"
  echo "printf \"# Run 'help' for usage.\\n\" >&2"
  # exit 1 matches generate_error()'s convention; the exit-propagation layer
  # normalizes error terminals to 1 regardless.
  echo "exit 1"
}

to_function_call() {
  # First argument is the function list (mandatory)
  local functions="${1:-}"
  shift

  local curr="${1:-}"
  local next="${2:-}"

  # Command words may use hyphens (e.g. `stage sign key`), but shell function and
  # variable names cannot. Normalize the command token to underscores for
  # matching only; args ($next-as-arg and "$@") keep their form, so hyphenated
  # key names still work.
  curr=$(printf '%s' "$curr" | tr '-' '_')

  # Bare invocation (no command word): route to the help terminal.
  if [ -z "$functions" ] || [ -z "$curr" ]; then
    echo "_help0"
    return 0
  fi

  # Shift past curr to get remaining args
  shift

  # Save argument count for accurate arity (after shifting curr)
  # This is the total count of arguments that will be passed to the function
  # Includes $next (if present) plus all remaining args in "$@"
  local arity=$#

  # Now shift $next so "$@" contains only the remaining args
  if [ -n "$next" ]; then
    shift
  fi

  # === STEP 1: Filter FIRST to narrow search space (performance optimization) ===
  # Only keep functions that match current prefix
  # This dramatically reduces search space for subsequent operations
  local filtered=""
  for line in $functions; do
    case "$line" in
      ${curr}|_${curr}|__${curr}|___${curr}|_${curr}_*|__${curr}_*|___${curr}_*|_${curr}[0-9]*|__${curr}[0-9]*|___${curr}[0-9]*)
        filtered="$filtered $line"
        ;;
    esac
  done

  # === STEP 1b: OUTSIDE-IN (JB's design): try the LONGER name FIRST ===
  # The longest word chain wins; the arity grows only while shrinking back.
  # Without this, a short function with a matching arity would swallow
  # multi-word commands (e.g. _help1 eating 'help env' as an argument).
  if [ -n "$next" ]; then
    local filtered_deep=""
    for line in $filtered; do
      case "$line" in
        _${curr}_*|__${curr}_*|___${curr}_*)
          filtered_deep="$filtered_deep $line"
          ;;
      esac
    done
    if [ -n "$filtered_deep" ]; then
      local deep_result
      deep_result=$(to_function_call "$filtered_deep" "${curr}_${next}" "$@")
      case "$deep_result" in
        _unknown_command1*) ;;    # nothing deeper -- fall through to local match
        *) printf '%s\n' "$deep_result"; return 0 ;;
      esac
    fi
  fi

  # === STEP 2: Search in filtered set for exact matches ===
  # Arity was calculated above (total argument count after shifting curr)

  # Try: exact match, with underscore prefix(es), with underscore + arity
  # Support terminal (_), combinator (__), and set-combinator (___) functions
  # Search ONLY in filtered set (much faster than full list)
  for line in $filtered; do
    if [ "$curr" = "$line" ] || \
       [ "_${curr}" = "$line" ] || \
       [ "__${curr}" = "$line" ] || \
       [ "___${curr}" = "$line" ] || \
       [ "_${curr}${arity}" = "$line" ] || \
       [ "__${curr}${arity}" = "$line" ] || \
       [ "___${curr}${arity}" = "$line" ]; then
      # Found exact match - output function call with quoted arguments
      # Use printf with %q to properly quote each argument for eval safety
      printf "%s" "$line"
      if [ -n "$next" ]; then
        printf " %s" "$(printf '%s\n' "$next" | sed "s/'/'\\\\''/g; s/^/'/; s/$/'/")"
      fi
      for arg in "$@"; do
        printf " %s" "$(printf '%s\n' "$arg" | sed "s/'/'\\\\''/g; s/^/'/; s/$/'/")"
      done
      printf '\n'
      return 0
    fi
  done

  # === STEP 3: nothing here and nothing deeper: unknown command ===
  # (the deep branch already ran FIRST -- outside-in)
  printf '%s %s\n' "_unknown_command1" "$(printf '%s\n' "$curr" | sed "s/'/'\\\\''/g; s/^/'/; s/$/'/")"
  return 0
}

env_resolve_file() {
  local var_name="$1"
  local location="${2:-}"
  local base="$ELEBAKE_BASE"
  local local_file="$base/.env/local/$var_name"
  local default_file="$base/.env/default/$var_name"
  local template_file="$ELEBAKE_TEMPLATE_DIR/environment/$var_name"

  case "$location" in
    local)    [ -f "$local_file" ]    && { printf 'local\n%s\n' "$local_file"; return 0; }; return 1 ;;
    default)  [ -f "$default_file" ]  && { printf 'default\n%s\n' "$default_file"; return 0; }; return 1 ;;
    template) [ -f "$template_file" ] && { printf 'template\n%s\n' "$template_file"; return 0; }; return 1 ;;
    "")
      if   [ -f "$local_file" ];    then printf 'local\n%s\n' "$local_file"
      elif [ -f "$default_file" ];  then printf 'default\n%s\n' "$default_file"
      elif [ -f "$template_file" ]; then printf 'template\n%s\n' "$template_file"
      else return 1
      fi
      ;;
    *) return 1 ;;
  esac
}

# resolve_item <dir> [<name>] [<strict>]
# The uniform "name / default / random" resolution automatism used across DB
# directories of symlinks (keys/, stage/, .staging/*/keys/), modeled on
# vpn-switch's resolve_session_id. $dir is relative to $ELEBAKE_BASE.
#   1. <name> given and <dir>/<name> is a symlink -> basename of its target
#   2. else <dir>/default is a symlink            -> basename of its target
#   3. else <strict> non-empty                    -> return 1 (FAIL-CLOSED)
#   4. else                                        -> a random entry's basename
# Prints the resolved id on stdout; returns 0 when resolved, 1 otherwise.
# Callers that must never guess (signing keys) pass strict=non-empty.
# install_layout <basedir> <layout> — emit the mkdir/chmod commands for a
# directory layout (generic: the same pattern serves the DB structure, a stage,
# /boot, ...). <layout> is newline-separated "relpath:mode" entries; any extra
# colon-fields are ignored (so ELEBAKE_INIT_DIR_CONFIG can be fed in unchanged).
# The base directory itself is created at 0700. Dumb: it just walks the list.
install_layout() {
  local base="$1" layout="$2" rel mode rest
  printf '%s\n' "$MODIFY_DIR_CREATE '$base'"
  printf '%s\n' "$MODIFY_FILE_PERMS 0700 '$base'"
  printf '%s\n' "$layout" | while IFS=: read -r rel mode rest; do
    [ -n "$rel" ] || continue
    printf '%s\n' "$MODIFY_DIR_CREATE '$base/$rel'"
    printf '%s\n' "$MODIFY_FILE_PERMS ${mode:-0700} '$base/$rel'"
  done
}

# is_pseudo_backend <name> — true if <name> is NOT a real signing backend:
# a hidden (.*) directory, or one listed in ELEBAKE_PSEUDO_BACKEND (e.g. stage).
# Lets `___prerequisites_verify0` enumerate the real backends (pkcs11, openpgp)
# from `ls $ELEBAKE_BASE` without hardcoding their names (mirrors vpn-switch's
# is_pseudo_protocol / PSEUDO_PROTOCOL).
is_pseudo_backend() {
  case "$1" in .*) return 0 ;; esac
  local p
  for p in $ELEBAKE_PSEUDO_BACKEND; do
    [ "$1" = "$p" ] && return 0
  done
  return 1
}

resolve_item() {
  local dir="$1"
  local name="${2:-}"
  local strict="${3:-}"
  local abs="$ELEBAKE_BASE/$dir"

  # Explicit name: it must exist, and never falls through to default/random.
  # A SYMLINK entry (named->hidden, e.g. stage/<name> -> ../.staging/<id>)
  # resolves to the hidden id via readlink; a DIR entry (a named record, e.g.
  # pkcs11/<name>/) resolves to the name itself.
  if [ -n "$name" ]; then
    if [ -L "$abs/$name" ]; then
      basename -- "$(readlink "$abs/$name")"
      return 0
    elif [ -e "$abs/$name" ]; then
      printf '%s\n' "$name"
      return 0
    fi
    return 1
  fi

  # No name: a 'default' symlink names the fallback entry.
  if [ -L "$abs/default" ]; then
    basename -- "$(readlink "$abs/default")"
    return 0
  fi

  # No name, no default: fail-closed in strict mode (never a random signing key).
  if [ -n "$strict" ]; then
    return 1
  fi

  # Non-strict: pick a random entry (excluding 'default').
  local entries count idx pick
  entries=$(ls -1 "$abs" 2>>"$LOG_FILE" | grep -v '^default$')
  count=$(printf '%s\n' "$entries" | grep -c .)
  if [ "$count" -eq 0 ]; then
    return 1
  fi
  idx=$(( $(od -An -tu4 -N4 /dev/urandom) % count + 1 ))
  pick=$(printf '%s\n' "$entries" | sed -n "${idx}p")
  if [ -L "$abs/$pick" ]; then
    basename -- "$(readlink "$abs/$pick")"
  else
    printf '%s\n' "$pick"
  fi
  return 0
}

dispatch() {
  # Read resolved function call from environment (set by main)
  # This avoids stdin consumption, allowing batch-combinators to capture stdin
  local function_call="$ELEBAKE_CONTEXT_CALL"

  # Defensive: Check for empty function call
  if [ -z "$function_call" ]; then
    trace_log "!" "dispatch" "Called with empty ELEBAKE_CONTEXT_CALL"
    return 1
  fi

  # Parse function name (first word) and remaining arguments
  local function_name="${function_call%% *}"
  local args="${function_call#* }"

  # If no space found, args would equal function_call (no arguments case)
  if [ "$args" = "$function_call" ]; then
    args=""
  fi

  # Defensive: Check for empty function name
  if [ -z "$function_name" ]; then
    trace_log "!" "dispatch" "Empty function name (function_call='$function_call')"
    return 1
  fi

  # CRITICAL: Disable set -e before calling function
  # This prevents shell exit if the function returns non-zero (including batch codes >= 128)
  set +e

  # Execute the function with its arguments (using eval to preserve quoting)
  if [ -z "$args" ]; then
    $function_name
  else
    eval "$function_name $args"
  fi
  local func_exit=$?

  # CRITICAL: Ensure set +e before returning (nested functions may have re-enabled set -e)
  # This allows returning non-zero exit codes (including batch codes >= 128) without shell exit
  set +e
  return $func_exit
}

lookup_interpreter() {
  # Read resolved function call from stdin
  local function_call
  read -r function_call

  # Extract function name (first word)
  local function_name="${function_call%% *}"

  # Try arity-specific override first (most specific)
  # Example: ELEBAKE_INTERPRETER_getenv1
  local mangled_with_arity=$(echo "$function_name" | sed 's/^_*//')
  local interp_var_arity="ELEBAKE_INTERPRETER_${mangled_with_arity}"
  local override_arity=$(eval echo "\${${interp_var_arity}:-}")

  if [ -n "$override_arity" ]; then
    echo "$override_arity"
    return 0
  fi

  # Try arity-agnostic override (less specific)
  # Example: ELEBAKE_INTERPRETER_getenv
  local mangled=$(echo "$function_name" | sed 's/^_*//; s/[0-9]$//')
  local interp_var="ELEBAKE_INTERPRETER_${mangled}"
  local override=$(eval echo "\${${interp_var}:-}")

  if [ -n "$override" ]; then
    echo "$override"
    return 0
  fi

  # Use defaults based on underscore count (intrinsic classification)
  case "$function_name" in
    ___*)
      # Triple underscore = batch-combinator function (outputs multiple commands)
      echo "$ELEBAKE_BATCH_COMBINATOR_INTERPRETER"
      ;;
    __*)
      # Double underscore = combinator function (outputs single command)
      echo "$ELEBAKE_COMBINATOR_INTERPRETER"
      ;;
    _*)
      # Single underscore = terminal function (outputs shell commands)
      echo "$ELEBAKE_TERMINAL_INTERPRETER"
      ;;
    *)
      # No underscore prefix (shouldn't happen with proper naming)
      error "Function name without underscore prefix: $function_name (check function naming convention)"
      ;;
  esac
}

# ANSI color codes (only applied when ELEBAKE_DISPLAY_ANSI=1; defined
# unconditionally so functions can reference them safely under set -u).
COLOR_RESET='\033[0m'
COLOR_RED='\033[1;31m'      # Errors
COLOR_YELLOW='\033[1;33m'   # Warnings
COLOR_GREEN='\033[1;32m'    # Success
COLOR_BLUE='\033[1;34m'     # Info/headings
COLOR_CYAN='\033[1;36m'     # Commands/examples
COLOR_GRAY='\033[2m'        # Debug/log

display() {
  local level="${1:-plain}"
  shift
  local message="$*"
  local color=""
  local prefix=""

  # Determine color and prefix based on level
  case "$level" in
    error)
      color="$COLOR_RED"
      prefix="Error: "
      ;;
    warning)
      color="$COLOR_YELLOW"
      prefix="Warning: "
      ;;
    success)
      color="$COLOR_GREEN"
      prefix=""
      ;;
    info)
      color="$COLOR_BLUE"
      prefix=""
      ;;
    log)
      color="$COLOR_GRAY"
      prefix=""
      ;;
    plain|*)
      color=""
      prefix=""
      ;;
  esac

  # Output with or without color
  # Note: %b interprets backslash escapes in color codes (\033 -> ESC)
  if [ "${ELEBAKE_DISPLAY_ANSI:-0}" = "1" ] && [ -n "$color" ]; then
    printf '%b%s%s%b\n' "$color" "$prefix" "$message" "$COLOR_RESET" >&2
  else
    printf "%s%s\n" "$prefix" "$message" >&2
  fi
}

display_error()   { display error "$@"; }
display_warning() { display warning "$@"; }
display_success() { display success "$@"; }
display_info()    { display info "$@"; }
display_log()     { display log "$@"; }

# error - Print error message and exit
#
# Kept for backward compatibility, now uses display()
#
error() {
  display_error "$*"
  exit 1
}

generate_error() {
  local first=true

  if [ "${ELEBAKE_DISPLAY_ANSI:-0}" != "0" ]; then
    # Color version
    for line in "$@"; do
      if $first; then
        printf '%s\n' "printf \"# \\033[1;31mError:\\033[0m %s\\n\" \"$line\" >&2"
        first=false
      else
        printf '%s\n' "printf \"#   %s\\n\" \"$line\" >&2"
      fi
    done
  else
    # Plain version
    for line in "$@"; do
      if $first; then
        printf '%s\n' "printf \"# Error: %s\\n\" \"$line\" >&2"
        first=false
      else
        printf '%s\n' "printf \"#   %s\\n\" \"$line\" >&2"
      fi
    done
  fi

  printf '%s\n' "exit 1"
}

log() {
  display_log "$*"
}

follow_symlinks_safe() {
  local dir="$1"
  local name="$2"

  local symlink_depth=0
  local max_symlinks=40  # POSIX SYMLOOP_MAX

  while [ -L "$dir/$name" ]; do
    symlink_depth=$((symlink_depth + 1))
    if [ "$symlink_depth" -gt "$max_symlinks" ]; then
      return 1  # Symlink loop or too deep
    fi

    name=$(readlink "$dir/$name")
    # If relative path, resolve it
    case "$name" in
      /*) ;;  # absolute path
      *) name="$dir/$name" ;;  # relative path
    esac
  done

  # Return basename only
  basename -- "$name"
  return 0
}

has_newline_in_path() {
  local path="$1"
  # wc -l counts newlines - if > 0, the path contains embedded newlines
  [ "$(printf '%s' "$path" | wc -l)" -gt 0 ]
}

check_batch_success() {
	local exit_code="$1"

	# Exit 0: Success
	if [ "$exit_code" -eq 0 ]; then
		return 0
	fi

	# Exit 1-127: Real failure
	if [ "$exit_code" -lt 128 ]; then
		return 1
	fi

	# Exit 128-255: Batch completion - recursively check children
	local batch_id=$(( (exit_code - 128) & 0x3F ))
	local batch_file="$ELEBAKE_BASE/.tmp/batch-exits/$batch_id"

	if [ ! -f "$batch_file" ]; then
		# Batch file missing
		return 1
	fi

	# Check each child recursively
	# Note: || [ -n "$child_exit" ] prevents set -e from triggering on EOF
	while IFS='|' read -r child_exit child_func child_ref || [ -n "$child_exit" ]; do
		if ! check_batch_success "$child_exit"; then
			return 1
		fi
	done < "$batch_file"

	# All children succeeded
	return 0
}

produce_with_exit() {
	local exit_file="$1"
	local stdout_file="$2"
	# $3 (stderr_file) unused - stderr flows naturally

	trace_log "|" "produce_with_exit" "ENTRY: ELEBAKE_CONTEXT_CALL='$ELEBAKE_CONTEXT_CALL'"

	set +e  # Temporarily disable errexit to capture exit code
	# Close stdin to prevent reading from inherited pipes (nested pipeline issue)
	# Stderr flows naturally (not captured) to allow LOG_FILE redirections to work
	dispatch </dev/null > "$stdout_file"
	local dispatch_exit=$?
	trace_log "|" "produce_with_exit" "dispatch returned: $dispatch_exit before set -e"
	set -e  # Re-enable errexit

	trace_log "|" "produce_with_exit" "dispatch returned: $dispatch_exit after set -e"

	# Store exit code in file
	echo "$dispatch_exit" > "$exit_file"

	trace_log "|" "produce_with_exit" "Wrote exit code to file: $exit_file"

	# Use recursive helper to check if execution succeeded
	if ! check_batch_success "$dispatch_exit"; then
		# Failure path: show captured output, report on stderr.
		# The failure already propagates out-of-band via the producer exit
		# channel (combine_exit_codes), so no error script is injected into
		# the pipe — an injected script would be executed by sh interpreters
		# but rendered as garbage by data interpreters (cat, cut -b3-).
		cat "$stdout_file"
		printf "# Error: %s\n" "Command failed with exit $dispatch_exit" >&2
		return "$dispatch_exit"
	else
		# Success path: output dispatch results
		cat "$stdout_file"
		return $dispatch_exit
	fi
}

extract_line1() {
	IFS= read -r first_line
	echo "$first_line"
	cat
}

to_trace_file() {
	local prefix="$1"
	local context="$2"
	local message="$3"

	if [ -n "${ELEBAKE_TRACE_FILE:-}" ]; then
		# Capture stdin to temp file first
		local temp_data=$(mktemp "$ELEBAKE_BASE/.tmp/trace-data.XXXXXX")
		cat > "$temp_data"

		# Write marker to trace file
		trace_log "$prefix" "$context" "$message"

		# Write captured data to trace file (appears after marker)
		cat "$temp_data" >> "$ELEBAKE_TRACE_FILE"

		# Output captured data to stdout (continue pipeline)
		cat "$temp_data"
		$MODIFY_FILE_REMOVE "$temp_data"
	else
		# No tracing - just pass through
		cat
	fi
}

consume_with_exit() {
	local exit_file="$1"
	local interpreter="$2"

	# Defensive: If exit_file not provided, just pass through
	if [ -z "$exit_file" ]; then
		cat
		return 1
	fi

	# Create temp file for interpreter stdout
	local stdout_file=$(mktemp "$ELEBAKE_BASE/.tmp/consumer-out.XXXXXX")

	# Run interpreter and capture exit code
	# CRITICAL: set +e prevents shell exit on non-zero, allowing exit code capture
	set +e
	eval "run_env -- $interpreter" > "$stdout_file"
	local exit_code=$?
	set -e

	# Store exit code for caller
	echo "$exit_code" > "$exit_file"

	# Output interpreter results to stdout
	cat "$stdout_file"
	$MODIFY_FILE_REMOVE "$stdout_file"

	return $exit_code
}

get_batch_id() {
	local counter_file="$ELEBAKE_BASE/.tmp/batch-counter"
	local batch_dir="$ELEBAKE_BASE/.tmp/batch-exits"
	local batch_id=0

	# Read current position (or start at 0)
	if [ -f "$counter_file" ]; then
		batch_id=$(cat "$counter_file" 2>>"$LOG_FILE")
		# Sanitize: ensure it's in valid range
		batch_id=$(( batch_id % 64 ))
	fi

	# Calculate next position (circular)
	local next_id=$(( (batch_id + 1) % 64 ))
	echo "$next_id" > "$counter_file" 2>>"$LOG_FILE"

	# Return current position (caller will overwrite this batch file)
	echo "$batch_id"
}

store_batch_exits() {
	local batch_id="$1"
	shift
	local batch_file="$ELEBAKE_BASE/.tmp/batch-exits/$batch_id"

	# Create batch file with space-separated exit codes
	echo "$@" > "$batch_file" 2>>"$LOG_FILE"
}

free_batch_id() {
	local batch_id="$1"
	local batch_file="$ELEBAKE_BASE/.tmp/batch-exits/$batch_id"

	$MODIFY_FILE_REMOVE "$batch_file" 2>>"$LOG_FILE"
}

combine_exit_codes() {
	local init_bits="$1"
	local producer_exit="$2"
	local consumer_exit="$3"

	# Trace entry point with all parameters
	trace_log "|" "combine_exit_codes" "ENTRY: init_bits='$init_bits' producer_exit='$producer_exit' consumer_exit='$consumer_exit'"

	# Defensive: Check if exit codes are valid numbers
	if [ -z "$producer_exit" ] || ! [ "$producer_exit" -eq "$producer_exit" ] 2>/dev/null; then
		trace_log "!" "combine_exit_codes" "Invalid producer_exit='$producer_exit' - FAILING"
		echo "# ERROR: Invalid producer_exit='$producer_exit' in combine_exit_codes" >&2
		return 1
	fi
	if [ -z "$consumer_exit" ] || ! [ "$consumer_exit" -eq "$consumer_exit" ] 2>/dev/null; then
		trace_log "!" "combine_exit_codes" "Invalid consumer_exit='$consumer_exit' - FAILING"
		echo "# ERROR: Invalid consumer_exit='$consumer_exit' in combine_exit_codes" >&2
		return 1
	fi

	# Check if producer is batch completion code
	if [ "$producer_exit" -ge 128 ]; then
		# Producer returned batch code - propagate it up
		# Extract batch_id and read batch file
		local batch_id=$(( (producer_exit - 128) & 0x3F ))
		local batch_file="$ELEBAKE_BASE/.tmp/batch-exits/$batch_id"

		if [ ! -f "$batch_file" ]; then
			echo "# ERROR: Batch file not found: $batch_file" >&2
			return 1
		fi

		# Build space-separated list of child results
		local children=""
		# Note: || [ -n "$exit_code" ] prevents set -e from triggering on EOF
		while IFS='|' read -r exit_code function_args batch_ref || [ -n "$exit_code" ]; do
			# Skip empty lines
			[ -z "$exit_code" ] && continue

			if [ -z "$children" ]; then
				children="$exit_code"
			else
				children="$children $exit_code"
			fi
		done < "$batch_file"

		# Construct hierarchical structure: "batch_children . consumer"
		# Consumer normalized to bit
		local c_bit=0
		if [ "$consumer_exit" -ne 0 ]; then
			c_bit=1
		fi
		ELEBAKE_CONTEXT_EXIT_BITS="$children . $c_bit"
		export ELEBAKE_CONTEXT_EXIT_BITS

		# Propagate batch completion code
		return "$producer_exit"
	fi

	# Check if consumer is batch completion code
	if [ "$consumer_exit" -ge 128 ]; then
		# Consumer returned batch code
		# Extract batch_id from batch exit code
		local batch_id=$(( (consumer_exit - 128) & 0x3F ))

		# Read batch file and construct child results
		local batch_file="$ELEBAKE_BASE/.tmp/batch-exits/$batch_id"

		if [ ! -f "$batch_file" ]; then
			echo "# ERROR: Batch file not found: $batch_file" >&2
			return 1
		fi

		# Build space-separated list of child results
		local children=""
		# Note: || [ -n "$exit_code" ] prevents set -e from triggering on EOF
		while IFS='|' read -r exit_code function_args batch_ref || [ -n "$exit_code" ]; do
			# Skip empty lines
			[ -z "$exit_code" ] && continue

			# Each line is a child result (already encoded as single exit code)
			if [ -z "$children" ]; then
				children="$exit_code"
			else
				children="$children $exit_code"
			fi
		done < "$batch_file"

		# Normalize producer to bit
		local p_bit=0
		if [ "$producer_exit" -ne 0 ]; then
			p_bit=1
		fi

		# Construct hierarchical structure: "p . child1 child2 child3"
		# Store in EXIT_BITS for debugging/analysis
		ELEBAKE_CONTEXT_EXIT_BITS="$p_bit . $children"
		export ELEBAKE_CONTEXT_EXIT_BITS

		# Propagate batch completion code
		return "$consumer_exit"
	fi

	# Both producer and consumer are regular exit codes (0-127)
	# Normalize to bits and encode
	local p_bit=0
	if [ "$producer_exit" -ne 0 ]; then
		p_bit=1
	fi

	local c_bit=0
	if [ "$consumer_exit" -ne 0 ]; then
		c_bit=1
	fi

	# Build pair structure: "p.c"
	ELEBAKE_CONTEXT_EXIT_BITS="$p_bit.$c_bit"
	export ELEBAKE_CONTEXT_EXIT_BITS

	# Encode into bit pattern
	# Current level encoding: (p << 1) | c
	local encoded=$(( (p_bit << 1) | c_bit ))

	# Return encoded exit code
	return "$encoded"
}

#@help _error1
# @internal emit an error line + exit 1 (arity family: 1-3 message parts)
#@end
_error1() {
  generate_error "$1"
}

#@help _error2
# @internal arity sibling of error (two message parts)
#@end
_error2() {
  generate_error "$1" "$2"
}

#@help _error3
# @internal arity sibling of error (three message parts)
#@end
_error3() {
  generate_error "$1" "$2" "$3"
}

#@help _fail2
# @internal emit a labeled failure with exit code (used by prerequisite chains)
#@end
_fail2() {
  local exit_code="$1"
  local message="$2"

  # Output error message to stderr
  if [ "${ELEBAKE_DISPLAY_ANSI:-0}" != "0" ]; then
    echo "printf \"# \\033[1;31mError:\\033[0m %s\\n\" \"$message\" >&2"
  else
    echo "printf \"# Error: %s\\n\" \"$message\" >&2"
  fi

  # Exit with preserved code
  echo "exit $exit_code"
}

#@help _log1
# @internal emit a log line (arity family: 1-3 message parts)
#@end
_log1() {
  echo "printf \"# %s\\n\" \"$1\""
}

#@help _log2
# @internal arity sibling of log (two message parts)
#@end
_log2() {
  echo "printf \"# %s\\n\" \"$1\""
  echo "printf \"# %s\\n\" \"$2\""
}

#@help _log3
# @internal arity sibling of log (three message parts)
#@end
_log3() {
  echo "printf \"# %s\\n\" \"$1\""
  echo "printf \"# %s\\n\" \"$2\""
  echo "printf \"# %s\\n\" \"$3\""
}

environment_sanity_check() {
  local errors=""
  local warnings=""

  # Check ELEBAKE_BASE is set
  if [ -z "${ELEBAKE_BASE:-}" ]; then
    warnings="${warnings}WARNING: ELEBAKE_BASE is not set\n"
  elif [ ! -d "${ELEBAKE_BASE}" ]; then
    errors="${errors}ERROR: ELEBAKE_BASE directory does not exist: ${ELEBAKE_BASE}\n"
  fi

  # Check all interpreter variables are set (required for proper operation)
  if [ -z "${ELEBAKE_COMBINATOR_INTERPRETER:-}" ]; then
    errors="${errors}ERROR: ELEBAKE_COMBINATOR_INTERPRETER is not set\n"
  fi

  if [ -z "${ELEBAKE_TERMINAL_INTERPRETER:-}" ]; then
    errors="${errors}ERROR: ELEBAKE_TERMINAL_INTERPRETER is not set\n"
  fi

  if [ -z "${ELEBAKE_BATCH_COMBINATOR_INTERPRETER:-}" ]; then
    errors="${errors}ERROR: ELEBAKE_BATCH_COMBINATOR_INTERPRETER is not set\n"
  fi

  # Print warnings if any
  if [ -n "${warnings}" ]; then
    printf "%b" "${warnings}" >&2
  fi

  # Print errors and exit if any
  if [ -n "${errors}" ]; then
    printf "%b" "${errors}" >&2
    exit 1
  fi
}

ensure_interpreter_var() {
  local var_name="$1"

  # Skip if variable already present in env_args
  if echo "$env_args" | grep -q "$var_name"; then
    return 0
  fi

  # Use ELEBAKE_TEMPLATE_DIR (already set as bootstrap variable)
  # Read default value from template (first line)
  local template_file="$ELEBAKE_TEMPLATE_DIR/environment/$var_name"
  local default_value

  if [ -f "$template_file" ]; then
    default_value=$(head -n 1 "$template_file")
  else
    # Fallback if template doesn't exist (should never happen in normal operation)
    echo "# Warning: Template not found: $template_file" >&2
    case "$var_name" in
      ELEBAKE_TERMINAL_INTERPRETER)
        default_value="cat"
        ;;
      ELEBAKE_COMBINATOR_INTERPRETER)
        default_value='xargs sh -c '"'"'eval exec "$0" "$@"'"'"' --'
        ;;
      ELEBAKE_BATCH_COMBINATOR_INTERPRETER)
        # Note: $MODIFY_FILE_PERMS expands now; other $ vars are escaped for later execution
        default_value="sh -c 'tmp=\$(mktemp \"\$ELEBAKE_BASE/.tmp/batch.XXXXXX\"); $MODIFY_FILE_PERMS 0600 \"\$tmp\"; cat > \"\$tmp\"; \"\$ELEBAKE_CONTEXT_SCRIPT\" batch \"\$tmp\" true'"
        ;;
      *)
        echo "# Error: Unknown interpreter variable: $var_name" >&2
        return 1
        ;;
    esac
  fi

  # Escape single quotes in value for safe inclusion in env_args
  # Replace each ' with '\'' (close quote, escaped quote, open quote)
  local escaped_value
  escaped_value=$(printf '%s' "$default_value" | sed "s/'/'\\\\''/g")

  env_args="$env_args $var_name='$escaped_value'"
}

#-----------------------------------------------------------------------------
# process_arguments + main (generic orchestration, moved from the monolith)
#-----------------------------------------------------------------------------

COMMAND_ALIASES="env:environment"

#@help apply_command_alias
# @internal expand a short command word to its full form (first word only)
#@end
apply_command_alias() {
  local pair
  for pair in $COMMAND_ALIASES; do
    case "$pair" in
      "$1":*)
        printf '%s' "${pair#*:}"
        return 0
        ;;
    esac
  done
  printf '%s' "$1"
}

process_arguments() {
  if [ $# -gt 0 ]; then
    local first_word
    first_word=$(apply_command_alias "$1")
    shift
    set -- "$first_word" "$@"
  fi

  # Resolve function call first (needed for module loading and execution)
  local resolved_call=$(to_function_call "$ANCHOR_FUNCTIONS" "$@")
  export ELEBAKE_CONTEXT_CALL="$resolved_call"

  # Dynamic module loading: deterministic function-to-module lookup
  # Extract function name (first word before space or entire string if no space)
  local func_name="${resolved_call%% *}"

  # Look up module in FUNCTION_MODULES mapping (format: "func:module.sh func:module.sh ...")
  # This is a build-time generated mapping - see scripts/generate-metadata.sh
  for mapping in $FUNCTION_MODULES; do
    case "$mapping" in
      "$func_name":*)
        # Extract module name after colon
        local module_name="${mapping#*:}"
        local module_file="$ELEBAKE_LIBDIR/include/$module_name"

        # Load module if it exists
        if [ -f "$module_file" ]; then
          . "$module_file"
        fi
        break
        ;;
    esac
  done

  # Setup automatic logging and tracing (if retention configured)
  # Note: func_name already extracted above for module loading

  # Check retention settings (default: LOG=1 day, TRACE=1 day)
  local log_retention=${ELEBAKE_RETENTION_DAYS_LOG:-1}
  local trace_retention=${ELEBAKE_RETENTION_DAYS_TRACE:-1}

  # Generate timestamp components
  local log_date=$(date +%Y-%m-%d)
  local log_time=$(date +%H%M%S)
  local log_timestamp="${log_time}.$$"  # Include PID to prevent collisions

  # Determine log base directory (bootstrap uses target database, others use current)
  local log_base="$ELEBAKE_BASE"
  if [ "$func_name" = "__bootstrap2" ]; then
    # Bootstrap: extract basedir from first argument
    log_base="$1"
  fi

  # Create log directory for today (if logging/tracing enabled)
  if [ "$log_retention" -gt 0 ] || [ "$trace_retention" -gt 0 ]; then
    local log_dir="$log_base/.log/$log_date"
    $MODIFY_DIR_CREATE "$log_dir" 2>>"$LOG_FILE" || true
    # Set proper permissions on .log directory (extract from ELEBAKE_INIT_DIR_CONFIG)
    local log_mode=$(echo "$ELEBAKE_INIT_DIR_CONFIG" | grep '^\.log:' | cut -d: -f2)
    if [ -n "$log_mode" ]; then
      $MODIFY_FILE_PERMS "$log_mode" "$log_base/.log" 2>>"$LOG_FILE" || true
    fi
  fi

  # Ensure .tmp directory exists (required for exit code propagation)
  # This is needed before any mktemp calls in the pipeline execution below
  # Note: init also creates .tmp, but dispatch needs it first (chicken-and-egg problem)
  # Mode 0750: allows group access for sudo scenarios (operational directory)
  if [ ! -d "$ELEBAKE_BASE/.tmp" ]; then
    $MODIFY_DIR_CREATE "$ELEBAKE_BASE/.tmp" 2>>"$LOG_FILE" || true
    $MODIFY_FILE_PERMS 0750 "$ELEBAKE_BASE/.tmp" 2>>"$LOG_FILE" || true
  fi

  # Setup LOG_FILE (if not already set and retention > 0)
  # Treat /dev/null as "not set" since it's the default value
  if { [ -z "${LOG_FILE:-}" ] || [ "$LOG_FILE" = "/dev/null" ]; } && [ "$log_retention" -gt 0 ]; then
    # Only use real log file if directory exists and is writable (graceful degradation)
    if [ -d "$log_base/.log/$log_date" ] && [ -w "$log_base/.log/$log_date" ]; then
      export LOG_FILE="$log_base/.log/$log_date/${log_timestamp}_${func_name}.log"
    else
      export LOG_FILE="/dev/null"
    fi
  elif [ "$log_retention" -eq 0 ]; then
    # Retention disabled - redirect to /dev/null
    export LOG_FILE="/dev/null"
  fi

  # Setup TRACE_FILE automatically based on retention setting
  # If user hasn't explicitly set ELEBAKE_TRACE_FILE, create it in database's .log/ directory
  if [ -z "${ELEBAKE_TRACE_FILE:-}" ] && [ "$trace_retention" -gt 0 ]; then
    # Only use real trace file if directory exists and is writable (graceful degradation)
    if [ -d "$log_base/.log/$log_date" ] && [ -w "$log_base/.log/$log_date" ]; then
      export ELEBAKE_TRACE_FILE="$log_base/.log/$log_date/${log_timestamp}_${func_name}.trace"
    else
      unset ELEBAKE_TRACE_FILE
    fi
  elif [ "$trace_retention" -eq 0 ]; then
    # Trace disabled - unset the variable
    unset ELEBAKE_TRACE_FILE
  fi

  # Execute pipeline with optional tracing
  # If ELEBAKE_TRACE_FILE is set, capture intermediate output via tee
  if [ -n "${ELEBAKE_TRACE_FILE:-}" ]; then
    # Validate trace file path to prevent creating files with bare PIDs
    # Path must contain a slash (absolute or relative) or start with a dot
    case "$ELEBAKE_TRACE_FILE" in
      */*|.*)
        # Valid path - contains directory component
        ;;
      *)
        # Invalid: bare filename without directory (could be corrupted to PID)
        echo "# ERROR: Invalid trace file path (must be absolute or relative with directory): $ELEBAKE_TRACE_FILE" >&2
        echo "#        Disabling tracing for safety." >&2
        ELEBAKE_TRACE_FILE=""
        ;;
    esac
  fi

  # Read inherited EXIT_BITS from environment (default: 0 for top level)
  local init_bits="${ELEBAKE_CONTEXT_EXIT_BITS:-0}"

  # If ELEBAKE_TRACE_FILE is still set after validation, capture intermediate output via tee
  if [ -n "${ELEBAKE_TRACE_FILE:-}" ]; then
    trace_log "|" "process_arguments" "provided arguments '$*' resolve to function call: '$resolved_call'"
    trace_log "|" "process_arguments" "inherited EXIT_BITS: $init_bits"

    # Determine interpreter based on resolved function (intrinsic classification)
    local interpreter=$(echo "$resolved_call" | lookup_interpreter)
    trace_log "|" "process_arguments" "Interpreter resolved: $interpreter"


    # Store trace file locally and export for subshells in pipeline
    local trace_file="$ELEBAKE_TRACE_FILE"
    export ELEBAKE_TRACE_FILE

    # Create temp files for exit codes
    local temp_producer_exit=$(mktemp "$ELEBAKE_BASE/.tmp/producer-exit.XXXXXX")
    local temp_producer_out=$(mktemp "$ELEBAKE_BASE/.tmp/producer-out.XXXXXX")
    local temp_producer_err=$(mktemp "$ELEBAKE_BASE/.tmp/producer-err.XXXXXX")
    local temp_consumer_exit=$(mktemp "$ELEBAKE_BASE/.tmp/consumer-exit.XXXXXX")

    # Debug temp files to trace data flow
    local temp_after_produce=$(mktemp "$ELEBAKE_BASE/.tmp/debug-after-produce.XXXXXX")
    local temp_after_trace1=$(mktemp "$ELEBAKE_BASE/.tmp/debug-after-trace1.XXXXXX")
    local temp_after_consume=$(mktemp "$ELEBAKE_BASE/.tmp/debug-after-consume.XXXXXX")

    # Run pipeline: produce_with_exit | to_trace_file | consume_with_exit | to_trace_file
    produce_with_exit "$temp_producer_exit" "$temp_producer_out" "$temp_producer_err" \
      | tee "$temp_after_produce" \
      | to_trace_file '=' 'process_arguments' '--- input to interpreter ---' \
      | tee "$temp_after_trace1" \
      | consume_with_exit "$temp_consumer_exit" "$interpreter" \
      | tee "$temp_after_consume" \
      | to_trace_file '>' 'process_arguments' '--- output from interpreter ---'

    # Read exit codes from temp files; trace only the error paths and the
    # final values (logged below as "producer/consumer exit code: ...")
    if [ ! -f "$temp_producer_exit" ]; then
      trace_log "!" "process_arguments" "Producer exit file missing!"
    elif [ ! -s "$temp_producer_exit" ]; then
      trace_log "!" "process_arguments" "Producer exit file exists but is empty!"
    fi
    local producer_exit=$(cat "$temp_producer_exit" 2>/dev/null || echo "ERROR_PRODUCER")

    if [ ! -f "$temp_consumer_exit" ]; then
      trace_log "!" "process_arguments" "Consumer exit file missing!"
    elif [ ! -s "$temp_consumer_exit" ]; then
      trace_log "!" "process_arguments" "Consumer exit file exists but is empty!"
    fi
    local consumer_exit=$(cat "$temp_consumer_exit" 2>/dev/null || echo "ERROR_CONSUMER")

    # Clean up temp files
    $MODIFY_FILE_REMOVE "$temp_producer_exit" "$temp_producer_out" "$temp_producer_err" "$temp_consumer_exit" \
          "$temp_after_produce" "$temp_after_trace1" "$temp_after_consume"

    trace_log "|" "process_arguments" "producer exit code: $producer_exit"
    trace_log "|" "process_arguments" "consumer exit code: $consumer_exit"

    # Combine exit codes and construct hierarchical structure
    # Let combine_exit_codes understand what exit codes mean and handle them
    # CRITICAL: Disable set -e to allow capturing exit codes >127
    local combined_exit
    set +e
    combine_exit_codes "$init_bits" "$producer_exit" "$consumer_exit"
    combined_exit=$?
    set -e

    trace_log "|" "process_arguments" "combined exit code: $combined_exit"
    trace_log "|" "process_arguments" "final EXIT_BITS: ${ELEBAKE_CONTEXT_EXIT_BITS}"
    trace_log "=" "process_arguments" "=========================================="

    set +e
    return $combined_exit
  else
    # No tracing: direct execution (faster, cleaner output)
    local interpreter=$(echo "$resolved_call" | lookup_interpreter)

    # Create temp files for exit codes
    local temp_producer_exit=$(mktemp "$ELEBAKE_BASE/.tmp/producer-exit.XXXXXX")
    local temp_producer_out=$(mktemp "$ELEBAKE_BASE/.tmp/producer-out.XXXXXX")
    local temp_producer_err=$(mktemp "$ELEBAKE_BASE/.tmp/producer-err.XXXXXX")
    local temp_consumer_exit=$(mktemp "$ELEBAKE_BASE/.tmp/consumer-exit.XXXXXX")

    # Run pipeline: produce_with_exit | consume_with_exit (no tracing)
    produce_with_exit "$temp_producer_exit" "$temp_producer_out" "$temp_producer_err" \
      | consume_with_exit "$temp_consumer_exit" "$interpreter"

    local producer_exit=$(cat "$temp_producer_exit" 2>/dev/null || echo "ERROR_PRODUCER")
    local consumer_exit=$(cat "$temp_consumer_exit" 2>/dev/null || echo "ERROR_CONSUMER")

    $MODIFY_FILE_REMOVE "$temp_producer_exit" "$temp_producer_out" "$temp_producer_err" "$temp_consumer_exit"

    # Combine exit codes and construct hierarchical structure
    # Let combine_exit_codes understand what exit codes mean and handle them
    # CRITICAL: Disable set -e to allow capturing exit codes >127
    local combined_exit
    set +e
    combine_exit_codes "$init_bits" "$producer_exit" "$consumer_exit"
    combined_exit=$?
    set -e
    set +e
    return $combined_exit
  fi
}

main() {
  # Normal user flow starts here
  # (Environment already bootstrapped at top level before main() was called)

  # Capture original command for interpreter context
  ELEBAKE_CONTEXT_COMMAND="$*"

  # Trace: Initial command invocation
  trace_log "=" "main" "=========================================="
  trace_log "|" "main" "Session started: $(date '+%Y-%m-%d %H:%M:%S')"
  trace_log "|" "main" "Command: elebake.sh $*"

  #---------------------------------------------------------------------------
  # Part 1: Special commands that run BEFORE environment checks
  #---------------------------------------------------------------------------
  #
  # Some commands need to run before ELEBAKE_BASE existence checks:
  # - bootstrap: Creates the database, so BASE doesn't need to exist yet
  #
  # These commands handle their own environment setup and exit early.
  #
  if [ "${1:-}" = "bootstrap" ]; then
    # Bootstrap command: Configure environment before dispatch
    # Bootstrap runs BEFORE database exists, so we must provide complete
    # environment via CACHE_ENV_ARGS (no .env files available yet)

    # Resolve function call first (needed for module loading)
    local resolved_call=$(to_function_call "$ANCHOR_FUNCTIONS" "$@")
    export ELEBAKE_CONTEXT_CALL="$resolved_call"

    # Dynamic module loading: deterministic function-to-module lookup
    # Bootstrap bypasses process_arguments(), so we must load module manually
    local func_name="${resolved_call%% *}"
    for mapping in $FUNCTION_MODULES; do
      case "$mapping" in
        "$func_name":*)
          local module_name="${mapping#*:}"
          local module_file="$ELEBAKE_LIBDIR/include/$module_name"
          if [ -f "$module_file" ]; then
            . "$module_file"
          fi
          break
          ;;
      esac
    done

    # IMPORTANT: Set ELEBAKE_BASE to an existing directory for bootstrap
    # The nested init call needs BASE to exist, so we use /tmp as a safe default
    # The actual target directory is passed by _bootstrap1 as an argument to init
    ELEBAKE_BASE="${TMPDIR:-/tmp}"

    # Export complete environment for bootstrap execution
    # Override bootstrap and init interpreters (init is called by bootstrap)
    # Provide PATH for file operations (no sbin directories needed)
    export ELEBAKE_CACHE_ENV_ARGS="PATH='/bin:/usr/bin:/usr/local/bin' ELEBAKE_INTERPRETER_bootstrap='sh' ELEBAKE_INTERPRETER_init='sh'"

    # Evaluate CACHE_ENV_ARGS to make variables available for lookup_interpreter
    eval "export $ELEBAKE_CACHE_ENV_ARGS"

    # Dispatch function (generates commands, reads from CONTEXT_CALL)
    local function_output=$(dispatch)

    # Lookup interpreter (can now see CACHE_ENV_ARGS with interpreter override)
    local interpreter=$(echo "$resolved_call" | lookup_interpreter)

    # Execute the captured output
    echo "$function_output" | run_env -- $interpreter

    return 0  # Bootstrap complete, exit early
  fi

  #---------------------------------------------------------------------------
  # Part 2: Environment checks (required for all normal commands)
  #---------------------------------------------------------------------------

  # Emit warning if ELEBAKE_BASE was not explicitly set
  if [ -z "$ELEBAKE_BASE_EXPLICIT" ]; then
    echo "# Warning: ELEBAKE_BASE not set, using default: $ELEBAKE_BASE" >&2
    echo "#          Set ELEBAKE_BASE=/path/to/db to suppress this warning." >&2
  fi

  # Allow certain commands without database (defined in COMMANDS_WITHOUT_DATABASE)
  # These commands can run before database initialization (e.g., help, bootstrap).
  # ONLY when no database exists: with a database present every command --
  # including the help family -- takes the full path (env loaded, user pins
  # honoured, and 'help env' resolves the REAL layer cascade; the /tmp
  # fallback below would otherwise shadow the database).
  if [ ! -d "$ELEBAKE_BASE/.env" ]; then
  for cmd in $COMMANDS_WITHOUT_DATABASE; do
    for arg in "$@"; do
      if [ "$arg" = "$cmd" ]; then
        # Help command needs ELEBAKE_BASE set to an existing directory
        # because process_arguments() uses .tmp for exit code propagation
        # Other commands (bootstrap, init) handle their own ELEBAKE_BASE
        if [ "$cmd" = "help" ]; then
          ELEBAKE_BASE="${TMPDIR:-/tmp}"
        fi

        # Ensure interpreter variables have defaults (no .env files available)
        # Start with CACHE_ENV_ARGS if set (e.g., from bootstrap's init call)
        env_args="${ELEBAKE_CACHE_ENV_ARGS:-}"
        ensure_interpreter_var "ELEBAKE_TERMINAL_INTERPRETER"
        ensure_interpreter_var "ELEBAKE_COMBINATOR_INTERPRETER"
        ensure_interpreter_var "ELEBAKE_BATCH_COMBINATOR_INTERPRETER"
        eval "export $env_args"

        local exit_code
        process_arguments "$@"
        exit_code=$?
        # Use check_batch_success to handle batch completion codes
        if check_batch_success "$exit_code"; then
          return 0
        else
          return 1
        fi
      fi
    done
  done
  fi

  # Ensure ELEBAKE_BASE exists (required for all other commands)
  if [ ! -d "$ELEBAKE_BASE" ]; then
    error "elebake base directory not found: $ELEBAKE_BASE"
  fi

  #---------------------------------------------------------------------------
  # Part 3: Normal command execution via process_arguments()
  #---------------------------------------------------------------------------
  #
  # Delegate to process_arguments() which handles:
  # 1. Command-line arg resolution via to_function_call()
  # 2. Interpreter lookup via lookup_interpreter() (intrinsic classification)
  # 3. Execution via dispatch | run_env -- $interpreter
  # 4. Optional tracing (if ELEBAKE_TRACE_FILE is set)
  #
  # This ensures consistent execution logic for both:
  # - Top-level commands (via main)
  # - Batch commands (via _batch2)
  #
  # Tracing flows continuously through nested calls, including batch execution.
  #
  local exit_code
  process_arguments "$@"
  exit_code=$?

  # Convert batch completion codes to simple success/failure for user
  # Use check_batch_success() to recursively determine if execution succeeded
  if check_batch_success "$exit_code"; then
    return 0
  else
    return 1
  fi
}

# --- dump/restore helpers shared by the key backends (pem/openpgp/pkcs11) ---

# rebase_db_path <value> — generation-time: emit <value> as a dump argument.
# A value pointing INSIDE this database is re-based onto the literal
# "$ELEBAKE_BASE" (expanded at replay time in the TARGET database — without
# this, a restored record would keep pointing into the source); anything
# else is emitted single-quoted as-is.
rebase_db_path() {
  local v="$1" rv rb
  rv=$(readlink -f "$v" 2>/dev/null) || rv="$v"
  rb=$(readlink -f "$ELEBAKE_BASE" 2>/dev/null) || rb="$ELEBAKE_BASE"
  case "$rv" in
    "$rb"/*) printf '"%s"\n' "\$ELEBAKE_BASE/${rv#"$rb"/}" ;;
    *)       printf "'%s'\n" "$v" ;;
  esac
}

# backend_dump_extra_lines <backend> <name> <schema-file...> — generation-time:
# one '<backend> import' line per file in the key record that the 'add'
# replay does NOT reproduce (the schema files travel as add arguments; a
# record may hold more — the dump describes ALL of it).
backend_dump_extra_lines() {
  local backend="$1" name="$2" base="$ELEBAKE_BASE" f b
  shift 2
  for f in "$base/$backend/$name"/*; do
    { [ -f "$f" ] || [ -L "$f" ]; } || continue
    b=$(basename "$f")
    case " $* " in *" $b "*) continue ;; esac
    printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" $backend import '$name' '$f'"
  done
  return 0
}

# line_pos_ok <pos> <count> — generation-time: is <pos> a valid 1-based
# insert position for a list of <count> lines (append = count+1)?
line_pos_ok() {
  case "$1" in ''|*[!0-9]*) return 1 ;; esac
  [ "$1" -ge 1 ] && [ "$1" -le "$(($2 + 1))" ]
}

# line_insert_emit <file> <pos> <line> — emit the shell that inserts <line>
# at 1-based <pos> of <file> (position validated at generation time)
line_insert_emit() {
  printf '%s\n' "{ head -n $(($2 - 1)) '$1'; printf '%s\\n' '$3'; tail -n +$2 '$1'; } > '$1.new' && mv '$1.new' '$1'"
}


# sq <text> — <text> as ONE single-quoted shell word (a quote inside becomes
# '\''), for values that travel inside an emitted line: labels, descriptions,
# error reasons that may contain quotes or parentheses
sq() {
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

# emit_note <text> — emit a runtime stderr note from a terminal: visible
# under an executing interpreter (sh) AND under cat. A bare "# ..." line in
# an ACT terminal's emission would be a no-op comment under sh — swallowed.
# Display-pinned terminals (cat/cut) emit text and keep writing plain
# "# ..." lines; file content inside emitted heredocs is data, not a note.
emit_note() {
  local t
  t=$(printf '%s' "$*" | sed "s/'/'\\\\''/g")
  printf '%s\n' "printf '%s\\n' '# $t' >&2"
}
