#!/bin/sh
#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Dr. Johannes Brügmann
#
# elvboot-import-db-patch.sh -- a patch script of 'elebake stage rescue
# patch': the elebake database of a user, built into a rescue root from an
# export pair, by the elebake of the image itself. It lives under template/rescue/
# of the tool and travels with it: in the image it is
# /usr/local/lib/elebake/template/rescue/elvboot-import-db-patch.sh -- the path 'stage rescue
# patch add' records.
#
# The contract of every patch script: sh <script> <user> <resources>, run as
# root INSIDE the rescue root (elebake puts a one-shot jail on the mounted
# root; no network) -- $1 the user the patch is for, $2 the resource
# directory the owner filled, hung into the root read-only; a non-zero exit
# fails the batch. Here the resources are the pair 'elebake export' wrote,
# dump.sh (with dump.sh.asc beside it) and bundle.tar.gz, and signer.asc,
# the public key of the signer (gpg --export --armor <keyid>).
#
# What it does: the user's ~/.elebake of the image removed (a previous build
# leaves none behind), then as the user with a login shell (su -l: HOME, PATH and the
# default base ~/.elebake/db of the image), the public key imported into
# the user's keyring of the image (what the signature is checked against;
# the rescue keeps it), then 'elebake import <dump> <bundle>' -- import
# makes the database when there is none (bootstrap with the profile the
# dump names, the signer pinned under the record name the dump carries) and
# replays the dump.
set -u
user=${1:-}; res=${2:-}
me=$(basename "$0")
test -n "$user" && test -n "$res" || { printf '%s: usage: sh %s <user> <resources>\n' "$me" "$me" >&2; exit 2; }
home=$(getent passwd "$user" 2>/dev/null | cut -d: -f6)
test -n "$home" || { printf '%s: no such user in the image: %s (stage rescue user mirror first)\n' "$me" "$user" >&2; exit 1; }
test -d "$home" || { printf '%s: the image carries no home for %s: %s\n' "$me" "$user" "$home" >&2; exit 1; }
test -r "$res/dump.sh" && test -r "$res/dump.sh.asc" && test -r "$res/bundle.tar.gz" \
        || { printf '%s: the resources are not the pair: %s/dump.sh, dump.sh.asc, bundle.tar.gz (elebake export <strategy> ... first)\n' "$me" "$res" >&2; exit 1; }
test -r "$res/signer.asc" || { printf '%s: no %s/signer.asc -- the public key of the signer (gpg --export --armor <keyid> > signer.asc)\n' "$me" "$res" >&2; exit 1; }
test -x /usr/local/bin/elebake || { printf '%s: no /usr/local/bin/elebake in the image (the elvboot package installed?)\n' "$me" >&2; exit 1; }
rm -rf "$home/.elebake"	# the database of the image IS the dump: never a union with a previous build
printf '%s: elebake import as %s (home %s)\n' "$me" "$user" "$home" >&2
su -l "$user" -c "gpg --batch --quiet --import '$res/signer.asc' && elebake import '$res/dump.sh' '$res/bundle.tar.gz'"; rc=$?
su -l "$user" -c "gpgconf --kill all" 2>/dev/null
exit $rc
