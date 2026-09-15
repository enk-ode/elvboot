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
#@end
__setintp2() {
        if true; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" setenv $(intp_var "$1") $(sq "$2")"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" setenv $(intp_var "$1") $(sq "$2")"
        fi
}

#@help __getintp1
# @command getintp <function>
# @summary Show a function's pinned interpreter: rewrite to 'getenv <variable>'
# @group   configuration
# @example elebake getintp stage_deploy_write
# @see     setintp
# @see     getenv
#@end
__getintp1() {
        if true; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" getenv $(intp_var "$1")"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" getenv $(intp_var "$1")"
        fi
}

#@help __help_intp1
# @command help intp <function> [<location>]
# @summary Show the documentation of an interpreter variable (class default or per-function): rewrite to 'help env <variable>'
# @group   configuration
# @param   function  a class default (terminal | combinator | batch) or a function name
# @param   location  the layer to inspect: local | default | template
# @example elebake help intp stage_deploy_write
# @see     help env
#@end
__help_intp1() {
        if true; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" help env $(intp_var "$1")"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" help env $(intp_var "$1")"
        fi
}

#@help __help_intp2
# @internal arity-2 of 'help intp' (a forced layer): rewrite to 'help env <variable> <location>'
#@end
__help_intp2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" help env $(intp_var "$1") '$2'"
}
