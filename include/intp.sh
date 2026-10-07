#!/bin/sh
#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Dr. Johannes Brügmann
# elebake intp - interpreter sugar (setintp / getintp / help intp): a token
# names an interpreter variable (a class default from template/tbl/intp.tbl, or
# the per-function pin ELEBAKE_INTERPRETER_<function>), and the command
# rewrites to setenv / getenv / help env of that variable.

#@help __setintp2
# @command setintp <function> <interpreter>
# @summary Pin a function's interpreter: rewrite to 'setenv <variable> <interpreter>' (the variable from the token)
# @group   configuration
# @param   function     a class default (terminal | combinator | batch) or a function name (e.g. stage_deploy_write)
# @param   interpreter  cat | sh | sudo sh | ...
# @example elebake setintp stage_deploy_write 'sudo sh'
# @see     getintp
# @see     setenv
# @env     ELEBAKE_TEMPLATE_DIR  the template directory (awk programs, tables)
# @env     ELEBAKE_INTERPRETER_  the per-function pin prefix: ELEBAKE_INTERPRETER_<function> when the token names no class
#@end
__setintp2() {
        local var=""
        var=$(awk -v t="$(printf '%s' "$1" | tr 'A-Z' 'a-z')" '$1 == t { print $2 }' "$ELEBAKE_TEMPLATE_DIR/tbl/intp.tbl" 2>/dev/null)
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" setenv ${var:-ELEBAKE_INTERPRETER_$1} $(sq "$2")"
}

#@help __getintp1
# @command getintp <function>
# @summary Show a function's pinned interpreter: rewrite to 'getenv <variable>'
# @group   configuration
# @example elebake getintp stage_deploy_write
# @see     setintp
# @see     getenv
# @env     ELEBAKE_TEMPLATE_DIR  the template directory (awk programs, tables)
# @env     ELEBAKE_INTERPRETER_  the per-function pin prefix: ELEBAKE_INTERPRETER_<function> when the token names no class
#@end
__getintp1() {
        local var=""
        var=$(awk -v t="$(printf '%s' "$1" | tr 'A-Z' 'a-z')" '$1 == t { print $2 }' "$ELEBAKE_TEMPLATE_DIR/tbl/intp.tbl" 2>/dev/null)
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" getenv ${var:-ELEBAKE_INTERPRETER_$1}"
}

#@help __help_intp1
# @command help intp <function> [<location>]
# @summary Show the documentation of an interpreter variable (class default or per-function): rewrite to 'help env <variable>'
# @group   configuration
# @param   function  a class default (terminal | combinator | batch) or a function name
# @param   location  the layer to inspect: local | default | template
# @example elebake help intp stage_deploy_write
# @see     help env
# @env     ELEBAKE_TEMPLATE_DIR  the template directory (awk programs, tables)
# @env     ELEBAKE_INTERPRETER_  the per-function pin prefix: ELEBAKE_INTERPRETER_<function> when the token names no class
#@end
__help_intp1() {
        local var=""
        var=$(awk -v t="$(printf '%s' "$1" | tr 'A-Z' 'a-z')" '$1 == t { print $2 }' "$ELEBAKE_TEMPLATE_DIR/tbl/intp.tbl" 2>/dev/null)
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" help env ${var:-ELEBAKE_INTERPRETER_$1}"
}

#@help __help_intp2
# @internal arity-2 of 'help intp' (a forced layer): rewrite to 'help env <variable> <location>'
#@end
__help_intp2() {
        local var=""
        var=$(awk -v t="$(printf '%s' "$1" | tr 'A-Z' 'a-z')" '$1 == t { print $2 }' "$ELEBAKE_TEMPLATE_DIR/tbl/intp.tbl" 2>/dev/null)
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" help env ${var:-ELEBAKE_INTERPRETER_$1} '$2'"
}
