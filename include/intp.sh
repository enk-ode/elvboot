#!/bin/sh
#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Dr. Johannes Brügmann
# elebake intp - interpreter sugar (setintp / getintp).
#
# Shortcut for setenv/getenv of an interpreter variable: a token resolves via
# intp_var to the full env-var name (a class default terminal|combinator|batch,
# or a per-function ELEBAKE_INTERPRETER_<fn>). These are Combinators — they emit
# a setenv/getenv re-invocation. Ported from vpn-switch's helpenv.sh.
#
#   setintp terminal 'sh'          -> setenv ELEBAKE_TERMINAL_INTERPRETER 'sh'
#   setintp stage_authenticode1 sh -> setenv ELEBAKE_INTERPRETER_stage_authenticode1 sh
#   getintp terminal               -> getenv ELEBAKE_TERMINAL_INTERPRETER

# intp_var <token> — resolve an interpreter token to its full env-var name.
intp_var() {
  case "$(printf '%s' "$1" | tr 'A-Z' 'a-z')" in
    terminal)               echo "ELEBAKE_TERMINAL_INTERPRETER" ;;
    combinator)             echo "ELEBAKE_COMBINATOR_INTERPRETER" ;;
    batch|batch_combinator) echo "ELEBAKE_BATCH_COMBINATOR_INTERPRETER" ;;
    *)                      echo "ELEBAKE_INTERPRETER_$1" ;;
  esac
}

# __setintp2 <fn> <value> — setenv of the resolved interpreter var.
#@help __setintp2
# @command setintp <function> <interpreter>
# @summary Pin a function's interpreter (sugar for setenv ELEBAKE_INTERPRETER_*)
# @group   configuration
# @example elebake setintp stage_filter2 sh
#@end
__setintp2() {
  local fn="$1" val="$2" q
  q=$(printf '%s\n' "$val" | sed "s/'/'\\\\''/g; s/^/'/; s/\$/'/")
  echo "\"\$ELEBAKE_CONTEXT_SCRIPT\" setenv $(intp_var "$fn") $q"
}

# __getintp1 <fn> — getenv of the resolved interpreter var.
#@help __getintp1
# @command getintp <function>
# @summary Show a function's pinned interpreter (sugar for getenv)
# @group   configuration
#@end
__getintp1() {
  echo "\"\$ELEBAKE_CONTEXT_SCRIPT\" getenv $(intp_var "$1")"
}

#@help __help_intp1
# @command help intp <fn> [location]
# @summary Show docs for an interpreter variable (class default or per-function)
# @group configuration
# @param fn        class default (terminal|combinator|batch) or function name (e.g. stage_deploy2)
# @param location  optional layer to inspect: local | default | template
# @example elebake help intp terminal
# @example elebake help intp stage_deploy2 template
# @see help env
# @see setintp
#@end
__help_intp1() {
  echo "\"\$ELEBAKE_CONTEXT_SCRIPT\" help env $(intp_var "$1")"
}

#@help __help_intp2
# @internal arity-2 of 'help intp' (forced layer)
#@end
__help_intp2() {
  echo "\"\$ELEBAKE_CONTEXT_SCRIPT\" help env $(intp_var "$1") $2"
}
