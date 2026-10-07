#!/bin/sh
#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Dr. Johannes Brügmann
# elebake attest - a detached OpenPGP signature beside a file, and the pinned
# check of one. The same recipe signs the boot manifest, the archive MANIFEST
# and the dump: gpg --detach-sign -a with a registered openpgp record.
#
# One attest identity per database (ELEBAKE_ARCHIVE_ATTEST_KEY): the sender
# signs with it, the receiver pins it. Pinning is the trust decision -- made
# once, explicitly, as an openpgp record -- so the keyring's web-of-trust
# levels are never consulted. libsecureboot verifies RSA OpenPGP signatures
# only; that constraint belongs to the boot manifest, but one key for all
# keeps one attest identity instead of two.

#@help ___attest2
# @command attest <file> <key>
# @summary Sign a file with a registered openpgp key (armored detached signature -> <file>.asc): the file exists, the record exists and carries its keyid; then 'attest sign'
# @group   database
# @param   file  the file to sign (a MANIFEST, a dump)
# @param   key   an 'openpgp add' record name
# @example elebake attest ~/git/config/dump.sh attest-v1
# @see     attest verify
# @see     manifest attest
# @see     stage attest
#@end
___attest2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" attest file exists '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" key record exists openpgp '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" openpgp record complete '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" attest sign '$1' '$2'"
}

#@help __attest_file_exists1
# @command attest file exists <file>
# @summary The file is there: a comment line, else an error line
# @group   database
# @internal
# @see     attest
#@end
__attest_file_exists1() {
        if test -f "$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'file $1 exists'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'attest: no such file $1'"
        fi
}

#@help __openpgp_record_complete1
# @command openpgp record complete <key>
# @summary The openpgp record carries its keyid: a comment line, else an error line
# @group   database
# @internal
# @see     attest
# @see     attest verify
#@end
__openpgp_record_complete1() {
        if test -f "$ELEBAKE_BASE/openpgp/$1/keyid"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'openpgp record $1 complete'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'openpgp record $1 incomplete (keyid missing; openpgp add $1 <keyid> [<gnupghome>])'"
        fi
}

#@help _attest_sign2
# @command attest sign <file> <key>
# @summary Act terminal: rm -f of a stale signature, GPG_TTY pointed at the terminal for a card's pinentry (the isolated environment carries none and stdin is the emission), gpg --detach-sign with the record's keyid (the signature 0600, the pair's files are the owner's alone) and GNUPGHOME; a failed signature leaves no file
# @group   database
# @internal
# @see     attest
#@end
_attest_sign2() {
        local gpgenv=""
        test ! -f "$ELEBAKE_BASE/openpgp/$2/gnupghome" || gpgenv="GNUPGHOME='$(head -n1 "$ELEBAKE_BASE/openpgp/$2/gnupghome")' "
        emit_note "elebake attest '$1' with openpgp key '$2' ($(head -n1 "$ELEBAKE_BASE/openpgp/$2/keyid" 2>/dev/null))"
        printf '%s\n' "rm -f '$1.asc'"
        printf '%s\n' "GPG_TTY=\$( { tty </dev/tty; } 2>/dev/null ); export GPG_TTY; ${gpgenv}gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1 || true"
        printf '%s\n' "${gpgenv}gpg --yes --openpgp -a --detach-sign --local-user '$(head -n1 "$ELEBAKE_BASE/openpgp/$2/keyid" 2>/dev/null)' -o '$1.asc' '$1' || { rm -f '$1.asc'; printf '# Error: attestation failed for %s\\n' '$(head -n1 "$ELEBAKE_BASE/openpgp/$2/keyid" 2>/dev/null)' >&2; exit 1; }"
        printf '%s\n' "$MODIFY_FILE_PERMS 0600 '$1.asc'"
        printf '%s\n' "printf '# attested %s by %s\\n' '$1' '$(head -n1 "$ELEBAKE_BASE/openpgp/$2/keyid" 2>/dev/null)' >&2"
}

#@help ___attest_verify2
# @command attest verify <file> <key>
# @summary Check a detached signature at generation time -- signed by the PINNED key, key neither expired nor revoked: the file exists, the record exists and is complete; then 'attest signer pinned' (a finding fails the command)
# @group   database
# @param   file  the signed file; its signature is <file>.asc
# @param   key   the openpgp record naming the signer you expect (keyid = fingerprint or long id, 16+ hex digits)
# @example elebake attest verify ~/git/config/dump.sh attest-v1
# @see     attest
# @see     manifest verify
# @see     restore
#@end
___attest_verify2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" attest file exists '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" key record exists openpgp '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" openpgp record complete '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" attest signer pinned '$1' '$2'"
}

#@help __attest_signer_pinned2
# @command attest signer pinned <file> <key>
# @summary The signature is good and made by the pinned key (the pin a keyid of 16+ hex digits, gpg's status lines read here): a log line naming the signer, else an error line with the one reason (a pin too short, unsigned, bad, expired, revoked, a different key)
# @group   database
# @internal
# @see     attest verify
#@end
__attest_signer_pinned2() {
        local keyid="" gh="" status="" fpr="" pfpr="" why=""
        keyid=$(head -n1 "$ELEBAKE_BASE/openpgp/$2/keyid" 2>/dev/null | sed 's/^0[xX]//' | tr 'a-f' 'A-F')
        gh=$(head -n1 "$ELEBAKE_BASE/openpgp/$2/gnupghome" 2>/dev/null)
        case "$keyid" in
                "") why="pinned keyid missing (openpgp record $2)" ;;
                *[!0-9A-F]*) why="pinned keyid is not hexadecimal: $keyid" ;;
                ????????????????*) ;;
                *) why="pinned keyid too short (${#keyid} digits, need 16+): $keyid" ;;
        esac
        if test -n "$why"; then
                :
        elif ! test -f "$1.asc"; then
                why="unsigned: no $1.asc"
        elif test -n "$gh"; then
                status=$(GNUPGHOME="$gh" gpg --batch --status-fd 1 --verify "$1.asc" "$1" 2>>"${LOG_FILE:-/dev/null}")
        else
                status=$(gpg --batch --status-fd 1 --verify "$1.asc" "$1" 2>>"${LOG_FILE:-/dev/null}")
        fi
        printf '%s\n' "$status" >>"${LOG_FILE:-/dev/null}"
        fpr=$(printf '%s\n' "$status" | awk '/^\[GNUPG:\] VALIDSIG /{print $3; exit}')
        pfpr=$(printf '%s\n' "$status" | awk '/^\[GNUPG:\] VALIDSIG /{print $NF; exit}')
        test -n "$why" || case "$status" in
                *"[GNUPG:] NO_PUBKEY"*) why="signer public key not in the keyring${gh:+ $gh}" ;;
                *"[GNUPG:] BADSIG"*)    why="BAD SIGNATURE -- file or signature altered" ;;
                *"[GNUPG:] REVKEYSIG"*) why="signed by a REVOKED key" ;;
                *"[GNUPG:] EXPKEYSIG"*) why="signed by an EXPIRED key" ;;
                *"[GNUPG:] EXPSIG"*)    why="signature itself has expired" ;;
                *"[GNUPG:] GOODSIG"*)   case "$fpr|$pfpr|" in *"$keyid|"*) ;; *) why="signed by a DIFFERENT key: $fpr (expected ...$keyid)" ;; esac ;;
                *) why="no good signature (see the log for gpg status)" ;;
        esac
        if test -z "$why"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log 'attest verify: $1 signed by $fpr (record $2)'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error $(sq "attest verify: $why") '(file $1, expected signer: openpgp record $2)'"
        fi
}
