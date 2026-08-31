#!/bin/sh
#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Dr. Johannes Brügmann
# tutorial-replay.sh — every successful command of docs/TUTORIAL.md, in
# order. Replays the whole walk into a fresh database: adds are
# idempotent-immutable, so re-running is safe. The active-DB symlink is
# moved by bootstrap (db -> tutorial); switch back manually afterwards.
set -eu
cd "$(dirname "$0")/.."

# 1. The birth of a database
./elebake.sh bootstrap tutorial minimal

# 2. setenv — the only way configuration enters the database
./elebake.sh setenv ELEBAKE_DISPLAY_ANSI 0

# 3. Reading the environment (display commands, no state change)
./elebake.sh printenv > /dev/null
./elebake.sh getenv ELEBAKE_DISPLAY_ANSI

# 4. Emit-and-inspect with the real keys (paths are promises)
./elebake.sh pem add uefi-db /root/secureboot/db.key /root/secureboot/db.crt
./elebake.sh pem prerequisites
./elebake.sh openpgp add manifest 77B2C2E8F5A4C6C7
./elebake.sh openpgp prerequisites

# 5. The stage and its key slots
./elebake.sh stage add illyria-boot
./elebake.sh stage sign key illyria-boot pem uefi-db
./elebake.sh stage attest key illyria-boot openpgp manifest

# 6. Source + checkout (fresh DB => fresh stage id => fresh worktree path;
# old tutorial worktrees accumulate under worktree/ -- prune deliberately)
./elebake.sh setenv ELEBAKE_FREEBSD_SRC /home/brj/git/freebsd-src
./elebake.sh freebsd prerequisites
./elebake.sh stage checkout illyria-boot platform-trust-gates-15.1^0 | sh

# 7. Catalogs (display only -- no state)
./elebake.sh stage measure illyria-boot > /dev/null

# 8. The arsenal: strictwatch (smallest complete chain)
./elebake.sh expectation add strict-active byte StrictActive 1
./elebake.sh expectation add strict-marker byte VeStrictPresent 1
./elebake.sh claim add strict-active measure_strict - strict.active strict-active
./elebake.sh claim add strict-marker measure_ve_strict - strict.marker strict-marker
./elebake.sh gate add strictwatch
./elebake.sh gate claim add strictwatch strict-active
./elebake.sh gate claim add strictwatch strict-marker
./elebake.sh trigger add publish-always when_always publish_act
./elebake.sh policy add watch-strict strictwatch
./elebake.sh policy trigger add watch-strict publish-always

# 9. bootlock & loaderlock: baseline macros, diagnose, the backstop
./elebake.sh macro add BOARD_DIGEST sha256 BoardIdentity
./elebake.sh macro add KEYS_DIGEST sha256 SecureBootKeys
./elebake.sh macro add MARKER_DIGEST sha256 BootMarker
./elebake.sh expectation add secureboot-on byte SecureBoot 1
./elebake.sh expectation add setupmode-off byte SetupMode 0
./elebake.sh expectation add marker-expected macro - MARKER_EXPECTED
./elebake.sh expectation add board-expected macro - BOARD_EXPECTED
./elebake.sh expectation add keys-expected macro - KEYS_EXPECTED
./elebake.sh claim add secureboot measure_secureboot - - secureboot-on
./elebake.sh claim add setupmode measure_setupmode - - setupmode-off
./elebake.sh claim add marker measure_marker diagnose_marker - marker-expected
./elebake.sh claim add board measure_board - board.sha256 board-expected
./elebake.sh claim add keys measure_keys diagnose_keys keys.sha256 keys-expected
./elebake.sh gate add bootlock LOADER_TRUST_BOOTLOCK_SECRET
./elebake.sh gate claim add bootlock secureboot
./elebake.sh gate claim add bootlock setupmode
./elebake.sh gate claim add bootlock marker
./elebake.sh gate claim add bootlock board
./elebake.sh gate claim add bootlock keys
./elebake.sh expectation add prereqs-exist byte PrereqsExist LOADER_PREREQUISITES_EXIST_N
./elebake.sh expectation add prereqs-verify byte PrereqsVerify LOADER_PREREQUISITES_VERIFY_N
./elebake.sh claim add prereqs-exist measure_prerequisites_exist diagnose_prerequisites_exist exist.count prereqs-exist
./elebake.sh claim add prereqs-verify measure_prerequisites_verify diagnose_prerequisites_verify verify.count prereqs-verify
./elebake.sh gate add loaderlock LOADER_TRUST_LOADERLOCK_SECRET
./elebake.sh gate claim add loaderlock prereqs-exist
./elebake.sh gate claim add loaderlock prereqs-verify
./elebake.sh trigger add unlock-fail when_fail unlock_act
./elebake.sh policy add publish-bootlock bootlock
./elebake.sh policy trigger add publish-bootlock publish-always
./elebake.sh policy add backstop-loaderlock loaderlock
./elebake.sh policy trigger add backstop-loaderlock publish-always
./elebake.sh policy trigger add backstop-loaderlock unlock-fail

# 10. The binding (check-then-act against the catalog)
./elebake.sh stage phase policy add illyria-boot PHASE_BOOT publish-bootlock
./elebake.sh stage phase policy add illyria-boot PHASE_LOADER backstop-loaderlock
./elebake.sh stage phase policy add illyria-boot PHASE_LOADER watch-strict

# 11. The harvest: license header (user decision) + the foundation batch
./elebake.sh setenv ELEBAKE_SPDX BSD-2-Clause
./elebake.sh setenv ELEBAKE_COPYRIGHT '2026 Johannes Bruegmann'
./elebake.sh stage foundation illyria-boot

# 12. site mk: generator needs the outer sudo context (interactive!)
sudo ELEBAKE_BASE=$HOME/.elebake/db ./elebake.sh stage site mk illyria-boot
./elebake.sh stage site mk report illyria-boot > /dev/null

# 13. Prerequisites lists (frozen snapshot from the build's lua/ + verify trio)
ls "$HOME/.elebake/tutorial/.staging/"stage-*/destdir/boot/lua | sed 's|^|/boot/lua/|' \
  | ./elebake.sh stage prerequisites exist add illyria-boot -
./elebake.sh stage prerequisites verify add illyria-boot /boot/loader.conf
./elebake.sh stage prerequisites verify add illyria-boot /boot/device.hints
./elebake.sh stage prerequisites verify add illyria-boot /boot/loader.efi.signed
