#!/bin/sh
#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Dr. Johannes Brügmann
# helpenv.sh - Documentation access for environment variables
#
# Surfaces the documentation that lives in template/environment/<VAR> (and the
# DB-activated copies under .env/{local,default}). Each such file holds the
# effective value on line 1 and hand-written docs on lines 2+. getenv shows only
# line 1; help env shows the value PLUS the documentation, honouring the same
# local -> default -> template cascade (via the shared env_resolve_file in
# engine.sh, so the two can never drift). Ported from vpn-switch.
#
# Commands:
#   help env                       list documented variables
#   help env <name>                show value + docs (effective location)
#   help env <name> <location>     show from a specific layer (local|default|template)
#
#   <name> resolves by cascade: literal -> ELEBAKE_<name> -> ELEBAKE_INTERPRETER_<name>

#@help _help_env0
# @command help env [<name> [location]]
# @summary Show env-var documentation (value + docs); with no argument, list all
# @group configuration
# @param name      variable name (full, or short for ELEBAKE_ / ELEBAKE_INTERPRETER_)
# @param location  optional layer to inspect: local | default | template
# @example elebake help env
# @example elebake help env ELEBAKE_STAND_BUILD_SUBDIRS
# @example elebake help env stage_site_mk template
# @see getenv
# @see help intp
# @env ELEBAKE_TEMPLATE_DIR  where the shipped variable templates (and their docs) live
#@end
_help_env0() {
  local base="$ELEBAKE_BASE"
  # Terminal: emit final text directly (default terminal interpreter is 'cat').
  echo "Documented environment variables — show one with: help env <name>"
  echo ""
  {
    ls "$ELEBAKE_TEMPLATE_DIR/environment" 2>/dev/null
    [ -d "$base/.env/default" ] && ls "$base/.env/default" 2>/dev/null
    [ -d "$base/.env/local" ]   && ls "$base/.env/local" 2>/dev/null
  } | sort -u | sed 's/^/  /'
}

#@help __help_env1
# @internal arity-1 of 'help env' (name cascade + resolve effective layer, delegate)
#@end
__help_env1() {
  local arg="$1" var="" cand layer
  # Name cascade: literal -> ELEBAKE_<arg> -> ELEBAKE_INTERPRETER_<arg>
  for cand in "$arg" "ELEBAKE_$arg" "ELEBAKE_INTERPRETER_$arg"; do
    if env_resolve_file "$cand" >/dev/null 2>&1; then var="$cand"; break; fi
  done
  if [ -z "$var" ]; then
    echo "\"\$ELEBAKE_CONTEXT_SCRIPT\" error \"No documented environment variable: $arg\""
    return 0
  fi
  # Resolve the effective layer and delegate to the 2-arg terminal renderer.
  layer=$(env_resolve_file "$var" | sed -n 1p)
  echo "\"\$ELEBAKE_CONTEXT_SCRIPT\" help env $var $layer"
}

#@help _help_env2
# @internal arity-2 of 'help env' (render docs from a forced layer)
#@end
_help_env2() {
  local var="$1" location="${2:-}"
  local resolved layer path label

  # Terminal: emit final text directly (default terminal interpreter is 'cat').
  if ! resolved=$(env_resolve_file "$var" "$location"); then
    if [ -n "$location" ]; then
      echo "# $var: no value in location: $location"
    else
      echo "# Variable $var not found"
    fi
    return 0
  fi
  layer=$(printf '%s\n' "$resolved" | sed -n 1p)
  path=$(printf '%s\n' "$resolved" | sed -n 2p)
  case "$layer" in
    local)    label=".env/local/$var (override)" ;;
    default)  label=".env/default/$var (default)" ;;
    template) label="template/environment/$var (template)" ;;
  esac

  echo "# Source: $label"
  echo "$var = $(head -n 1 "$path")"
  echo ""
  # Documentation source: the shown file -- but a local override written
  # by setenv carries only the value, and an override must not LOSE the
  # documentation. Whenever the shown file documents nothing, fall back
  # to the first deeper layer that does (default, then template), and
  # say so.
  local doc_path="$path" doc_layer="$layer" cand cand_path
  if ! tail -n +2 "$doc_path" | grep -q '[^[:space:]]'; then
    for cand in default template; do
      [ "$cand" = "$layer" ] && continue
      resolved=$(env_resolve_file "$var" "$cand") || continue
      cand_path=$(printf '%s\n' "$resolved" | sed -n 2p)
      if tail -n +2 "$cand_path" | grep -q '[^[:space:]]'; then
        doc_path="$cand_path"; doc_layer="$cand"; break
      fi
    done
    [ "$doc_layer" = "$layer" ] || echo "# (documentation from $doc_layer)"
  fi
  # Documentation: lines 2+, stop at '# @internal', render @tags as labelled
  # sections and everything else as prose (leading '# ' stripped).
  tail -n +2 "$doc_path" | awk '
    /^#[ \t]*@internal/ { exit }
    {
      line=$0
      sub(/^#[ \t]?/,"",line)
      if (sub(/^@summary[ \t]+/,"",line))  { print "Summary:  " line; next }
      if (sub(/^@default[ \t]+/,"",line))  { print "Default:  " line; next }
      if (sub(/^@values[ \t]+/,"",line))   { print "Values:   " line; next }
      if (sub(/^@example[ \t]+/,"",line))  { print "Example:  " line; next }
      if (sub(/^@see[ \t]+/,"",line))      { print "See also: " line; next }
      if (line ~ /^@/)                     { next }
      print line
    }'
}
