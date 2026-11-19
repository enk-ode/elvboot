#!/bin/sh
#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Dr. Johannes Brügmann
# elebake intp - interpreter sugar (setintp / getintp / unsetintp / help intp):
# the token is a function name, the variable is its pin
# ELEBAKE_INTERPRETER_<function>, and the command rewrites to setenv / getenv /
# unsetenv / help env of that variable. Nothing else: the class defaults
# (ELEBAKE_TERMINAL_INTERPRETER, ELEBAKE_COMBINATOR_INTERPRETER,
# ELEBAKE_BATCH_COMBINATOR_INTERPRETER) are set with setenv by their name.

#@help __setintp2
# @command setintp <function> <interpreter>
# @summary Pin a function's interpreter: rewrite to 'setenv ELEBAKE_INTERPRETER_<function> <interpreter>' -- sugar for the pin's name, nothing more; a class default is set with setenv by its own name
# @group   configuration
# @param   function     a function name, with or without its arity digit (e.g. stage_deploy_write)
# @param   interpreter  cat | sh | sudo sh | ...
# @example elebake setintp stage_deploy_write 'sudo sh'
# @see     getintp
# @see     unsetintp
# @see     setenv
# @env     ELEBAKE_INTERPRETER_  the per-function pin prefix
#@end
__setintp2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" setenv ELEBAKE_INTERPRETER_$1 $(sq "$2")"
}

#@help __getintp1
# @command getintp <function>
# @summary Show a function's pinned interpreter: rewrite to 'getenv ELEBAKE_INTERPRETER_<function>'
# @group   configuration
# @example elebake getintp stage_deploy_write
# @see     setintp
# @see     getenv
# @env     ELEBAKE_INTERPRETER_  the per-function pin prefix
#@end
__getintp1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" getenv ELEBAKE_INTERPRETER_$1"
}

#@help __unsetintp1
# @command unsetintp <function>
# @summary Drop a function's local interpreter pin: rewrite to 'unsetenv ELEBAKE_INTERPRETER_<function>'; the default of the profile applies again
# @group   configuration
# @example elebake unsetintp stage_deploy_write
# @see     setintp
# @see     unsetenv
# @env     ELEBAKE_INTERPRETER_  the per-function pin prefix
#@end
__unsetintp1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" unsetenv ELEBAKE_INTERPRETER_$1"
}

#@help __help_intp1
# @command help intp <function> [<location>]
# @summary Show the documentation of a function's interpreter pin: rewrite to 'help env ELEBAKE_INTERPRETER_<function>'
# @group   configuration
# @param   location  the layer to inspect: local | default | template
# @example elebake help intp stage_deploy_write
# @see     help env
# @env     ELEBAKE_INTERPRETER_  the per-function pin prefix
#@end
__help_intp1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" help env ELEBAKE_INTERPRETER_$1"
}

#@help __help_intp2
# @internal arity-2 of 'help intp' (a forced layer): rewrite to 'help env ELEBAKE_INTERPRETER_<function> <location>'
#@end
__help_intp2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" help env ELEBAKE_INTERPRETER_$1 '$2'"
}
