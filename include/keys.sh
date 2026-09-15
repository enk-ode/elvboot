#!/bin/sh
#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Dr. Johannes Brügmann
# elebake keys - what every key backend (pem, openpgp, pkcs11) shares: the
# record name rule, the import of an extra file into a record, the file
# list of a record for an archive. The backends rewrite to these lines
# with their own name first ('key import pem ...'); the records differ
# only in their schema files, which travel as the backend's add replay.
#
# ARCHITECTURE: every check is a combinator line (a comment line, else an
# error line) in front of one act terminal; the record holds public
# material and references only.

#@help __key_name_valid1
# @command key name valid <name>
# @summary The key record name is a record name ([A-Za-z0-9_.-], not . or ..): a comment line, else an error line
# @group   keys
# @internal
# @see     pem add
# @see     openpgp add
# @see     pkcs11 add
#@end
__key_name_valid1() {
        if key_name_ok "$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'key name $1 valid'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'invalid key name $1 ([A-Za-z0-9_.-])'"
        fi
}

#@help ___key_import3
# @command key import <backend> <name> <absfile>
# @summary Copy ONE extra file into a key record: the record exists, the source is an absolute existing file or symlink; then 'key import copy'
# @group   keys
# @internal
# @see     pem import
# @see     openpgp import
# @see     pkcs11 import
#@end
___key_import3() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" key record exists '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" base element exists '$3'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" key import copy '$1' '$2' '$3'"
}

#@help __base_element_exists1
# @command base element exists <absfile>
# @summary The base element is an absolute path to an existing file or symlink in the OTHER database: a comment line, else an error line
# @group   keys
# @internal
# @see     key import
# @see     provenance import
# @see     stage import
#@end
__base_element_exists1() {
        if test "${1#/}" != "$1" && { test -L "$1" || test -f "$1"; }; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'base element $1 exists'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'no such file: $1'"
        fi
}

#@help _key_import_copy3
# @command key import copy <backend> <name> <absfile>
# @summary Act terminal: rm -f and cp -Pp of the file into the record (idempotent; a link stays a link)
# @group   keys
# @internal
# @see     key import
#@end
_key_import_copy3() {
        printf '%s\n' "rm -f '$ELEBAKE_BASE/$1/$2/${3##*/}' && cp -Pp '$3' '$ELEBAKE_BASE/$1/$2/' || { printf '# Error: %s import failed\\n' '$1' >&2; exit 1; }"
}

#@help _key_collect_files2
# @command key collect files <backend> <name>
# @summary Text terminal: the files of one key record by their real path, written against "$ELEBAKE_ARCHIVE_BASE"
# @group   keys
# @internal
# @see     pem collect
# @see     openpgp collect
# @see     pkcs11 collect
#@end
_key_collect_files2() {
        printf '# %s %s\n' "$1" "$2"
        find "$ELEBAKE_BASE/$1/$2" \( -type f -o -type l \) 2>/dev/null | sort | sed "s|^$ELEBAKE_BASE/|\"\$ELEBAKE_ARCHIVE_BASE\"/|"
}

