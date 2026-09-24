#!/bin/sh
#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Dr. Johannes Brügmann
# tutorial-replay.sh — the database side of docs/TUTORIAL.md, chapter by
# chapter, into a fresh database: adds are idempotent-immutable, so
# re-running is safe. The active-DB symlink is moved by bootstrap
# (db -> tutorial); switch back manually afterwards.
#
# What needs the machine -- a checkout, the build, the cards, the TPM, a
# boot and its kenv -- is not run here; those chapters name the workflow
# that holds the sequence (elebake workflow show <name>) and the replay
# prints it. The stage is called illyria-boot throughout; the walk renames
# it daily-v1 from chapter 16 on, the commands are the same.
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
./elebake.sh stage checkout illyria-boot ptg-15.1-next^0 | sh

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
./elebake.sh gate add bootlock
./elebake.sh gate claim add bootlock secureboot
./elebake.sh gate claim add bootlock setupmode
./elebake.sh gate claim add bootlock marker
./elebake.sh gate claim add bootlock board
./elebake.sh gate claim add bootlock keys
./elebake.sh expectation add prereqs-exist byte PrereqsExist LOADER_PREREQUISITES_EXIST_N
./elebake.sh expectation add prereqs-verify byte PrereqsVerify LOADER_PREREQUISITES_VERIFY_N
./elebake.sh claim add prereqs-exist measure_prerequisites_exist diagnose_prerequisites_exist exist.count prereqs-exist
./elebake.sh claim add prereqs-verify measure_prerequisites_verify diagnose_prerequisites_verify verify.count prereqs-verify
./elebake.sh gate add loaderlock
./elebake.sh gate claim add loaderlock prereqs-exist
./elebake.sh gate claim add loaderlock prereqs-verify
./elebake.sh trigger add unlock-fail when_fail unlock_act
./elebake.sh trigger add report-skipped when_skipped report_act
./elebake.sh policy add guard-bootlock bootlock
./elebake.sh policy trigger add guard-bootlock publish-always
./elebake.sh policy trigger add guard-bootlock report-skipped
./elebake.sh policy add backstop-loaderlock loaderlock
./elebake.sh policy trigger add backstop-loaderlock publish-always
./elebake.sh policy trigger add backstop-loaderlock unlock-fail

# 10. The binding (check-then-act against the catalog)
./elebake.sh stage phase policy add illyria-boot PHASE_BOOT guard-bootlock
./elebake.sh stage phase policy add illyria-boot PHASE_LOADER backstop-loaderlock
./elebake.sh stage phase policy add illyria-boot PHASE_LOADER watch-strict

# 11. The harvest: license header (user decision) + the foundation batch
./elebake.sh setenv ELEBAKE_SPDX BSD-2-Clause
./elebake.sh setenv ELEBAKE_COPYRIGHT '2026 Johannes Bruegmann'
./elebake.sh stage foundation make illyria-boot

# 12. site mk: generator needs the outer sudo context (interactive!)
sudo ELEBAKE_BASE=$HOME/.elebake/db ./elebake.sh stage site mk illyria-boot
./elebake.sh stage site mk report illyria-boot > /dev/null

# 13. Prerequisites lists (frozen snapshot from the build's lua/ + verify trio)
ls "$HOME/.elebake/tutorial/.staging/"stage-*/destdir/boot/lua | sed 's|^|/boot/lua/|' \
  | ./elebake.sh stage prerequisites exist add illyria-boot -
./elebake.sh stage prerequisites verify add illyria-boot /boot/loader.conf
./elebake.sh stage prerequisites verify add illyria-boot /boot/device.hints
./elebake.sh stage prerequisites verify add illyria-boot /boot/loader.efi.signed

# 14. One to one: the filter names what the boot tree carries, the media
# are the two cards in the one reader (the stamp tells them apart, ch. 22)
for f in kernel loader.conf keys device.hints loader.ve.strict loader.efi lua defaults loader.help.efi fonts; do
  ./elebake.sh stage filter add illyria-boot "$f"
done
./elebake.sh stage device illyria-boot a /dev/da1p1 /mnt
./elebake.sh stage device illyria-boot b /dev/da1p1 /mnt

# 15. The RSA lesson: the attest key is RSA (libsecureboot verifies OpenPGP
# RSA only) -- a property of the key from chapter 4, nothing to add here.

# 16. The daily stage: one cycle, and why it is long (the machine: a
# checkout, the build, the cards) -- the sequence is the workflow rebuild
./elebake.sh workflow show rebuild

# 17. The record chain: the loader proves it was here -- recordlock, and
# the kernel phase it belongs to
./elebake.sh expectation add tpm-keyfile byte TpmKeyfile 1
./elebake.sh expectation add record-valid byte RecordValid 1
./elebake.sh expectation add counter-step byte CounterStep 1
./elebake.sh expectation add chain-ok byte ChainOnMedium 1
./elebake.sh expectation add lastboot-gap byte LastBootGap 1
./elebake.sh expectation add halt-expected key HaltQuiet halt.expected
./elebake.sh expectation add geli-slot byte GeliSlot 1
./elebake.sh claim add tpm-keyfile measure_tpm_keyfile diagnose_tpm_keyfile tpm.keyfile tpm-keyfile
./elebake.sh claim add record measure_record diagnose_record - record-valid
./elebake.sh claim add counter-step measure_counter_step diagnose_counter_step - counter-step
./elebake.sh claim add chain measure_chain - - chain-ok
./elebake.sh claim add lastboot-gap measure_lastboot_gap diagnose_lastboot_gap - lastboot-gap
./elebake.sh claim add halt-quiet measure_halt diagnose_halt halt.sha256 halt-expected
./elebake.sh claim add geli-slot measure_geli_slot diagnose_geli_slot - geli-slot
./elebake.sh gate add recordlock
for c in tpm-keyfile record counter-step chain lastboot-gap halt-quiet geli-slot; do
  ./elebake.sh gate claim add recordlock "$c"
done
./elebake.sh trigger add record-always when_always record_act
./elebake.sh policy add guard-recordlock recordlock
./elebake.sh policy trigger add guard-recordlock publish-always
./elebake.sh policy trigger add guard-recordlock report-skipped
./elebake.sh policy trigger add guard-recordlock record-always
./elebake.sh policy trigger add guard-recordlock unlock-fail
./elebake.sh stage phase policy add illyria-boot PHASE_KERNEL guard-recordlock

# 18. Learning the witnesses, and what moves: kernellock with the PCR bank
# and the digests, kernelpost after the prompt; the learning itself needs a
# boot's kenv -- workflows pcr-learn, baseline-relearn, halt-relearn
./elebake.sh macro add KENV_GUARD_DIGEST sha256 KenvGuard
./elebake.sh macro add SOFTPCR_DIGEST sha256 SoftPcr
./elebake.sh expectation add howto-clean byte BootHowto 0
./elebake.sh expectation add kenv-guard-expected macro - KENV_GUARD_EXPECTED
./elebake.sh expectation add preload-ok byte PreloadVerified 1
./elebake.sh expectation add softpcr-expected macro - SOFTPCR_EXPECTED
./elebake.sh expectation add boot-window byte BootWindow 1
./elebake.sh expectation add clock-agree byte ClockAgree 1
./elebake.sh expectation add tpm-present byte TpmPresent 1
./elebake.sh expectation add pcr-expected key PcrBank pcr.expected
./elebake.sh expectation add nvme-present byte NvmePresent 1
./elebake.sh expectation add ledger-clean byte LedgerFailed 0
./elebake.sh expectation add ledger-noprompt byte LedgerPrompted 0
./elebake.sh claim add howto measure_howto diagnose_howto howto howto-clean
./elebake.sh claim add kenv-guard measure_kenv_guard - kenv.sha256 kenv-guard-expected
./elebake.sh claim add preload measure_preload diagnose_preload - preload-ok
./elebake.sh claim add softpcr measure_softpcr - softpcr.sha256 softpcr-expected
./elebake.sh claim add boot-window measure_time_boot diagnose_time_boot - boot-window
./elebake.sh claim add clock-agree measure_time_rtc_tsc diagnose_time_rtc_tsc - clock-agree
./elebake.sh claim add tpm measure_tpm diagnose_tpm - tpm-present
./elebake.sh claim add pcr measure_pcr - pcr.sha256 pcr-expected
./elebake.sh claim add nvme measure_nvme diagnose_nvme - nvme-present
./elebake.sh claim add ledger-failed measure_ledger_failed diagnose_ledger - ledger-clean
./elebake.sh claim add ledger-prompted measure_ledger_prompted - - ledger-noprompt
./elebake.sh gate add kernellock
for c in howto kenv-guard preload softpcr boot-window clock-agree tpm pcr nvme ledger-failed ledger-prompted; do
  ./elebake.sh gate claim add kernellock "$c"
done
./elebake.sh trigger add sentinel-always when_always sentinel_act
./elebake.sh trigger add expire-always when_always expire_act
./elebake.sh trigger add taint-fail when_fail taint_act
./elebake.sh policy add guard-kernellock kernellock
for t in publish-always unlock-fail sentinel-always report-skipped record-always expire-always taint-fail; do
  ./elebake.sh policy trigger add guard-kernellock "$t"
done
./elebake.sh stage phase policy add illyria-boot PHASE_KERNEL guard-kernellock
./elebake.sh expectation add prompt-window byte PromptWindow 1
./elebake.sh expectation add attempts-zero byte Attempts 0
./elebake.sh claim add prompt-window measure_time_prompt diagnose_time_prompt - prompt-window
./elebake.sh claim add attempts measure_attempts - attempts attempts-zero
./elebake.sh gate add kernelpost
./elebake.sh gate claim add kernelpost prompt-window
./elebake.sh gate claim add kernelpost attempts
./elebake.sh trigger add handover-always when_always handover_act
./elebake.sh policy add guard-kernelpost kernelpost
./elebake.sh policy trigger add guard-kernelpost publish-always
./elebake.sh policy trigger add guard-kernelpost handover-always
./elebake.sh stage phase policy add illyria-boot PHASE_KERNEL_POST guard-kernelpost
./elebake.sh stage kenv add illyria-boot loader.trust.pcr.require 0,1,2,3,4,6,7
./elebake.sh stage kenv add illyria-boot loader.trust.kernellock.display 'bootcount lastboot cycles unclean gates attempts'
./elebake.sh stage require illyria-boot
./elebake.sh workflow show pcr-learn
./elebake.sh workflow show baseline-relearn

# 19. Where the walk stands (display only)
./elebake.sh stage phase show illyria-boot
./elebake.sh stage foundation report illyria-boot

# 20. The restore probe: the database on a second machine -- a second
# database and the archive key; the sequence is the workflow restore
./elebake.sh workflow show restore

# 21. Three factors: the TPM leafs (handles, PCRs, providers of this
# machine); sealing runs on the machine -- workflow tpm-seal
./elebake.sh stage kenv add illyria-boot loader.trust.tpm.key.handle 0x81000001
./elebake.sh stage kenv add illyria-boot loader.trust.tpm.keyfile.handles '0x81010001 0x81010002'
./elebake.sh stage kenv add illyria-boot loader.trust.tpm.keyfile.pcrs 0,2,7
./elebake.sh stage kenv add illyria-boot loader.trust.tpm.keyfile.providers 'nda0p1 nda2p1'
./elebake.sh stage kenv add illyria-boot loader.trust.tpm.counter.nv 0x01c10e20
./elebake.sh stage kenv add illyria-boot loader.trust.halt.nv 0x01c10e21
./elebake.sh workflow show tpm-seal

# 22. The time anchor: the leafs, the four claims in recordlock, the tells
# in tellwatch, the runtime side; the two NV indices and the push run on
# the machine -- the whole sequence is the workflow time-anchor
./elebake.sh stage kenv add illyria-boot loader.trust.tpm.anchor.nv 0x01c10e22
./elebake.sh stage kenv add illyria-boot loader.trust.tpm.shutdown.nv 0x01c10e23
./elebake.sh stage kenv add illyria-boot loader.trust.tpm.cap.pcr 14
./elebake.sh stage kenv add illyria-boot loader.trust.storage.gap.max.days 7
./elebake.sh stage kenv add illyria-boot loader.trust.clock.skew.s 300
./elebake.sh stage kenv add illyria-boot loader.trust.smart.step.units.max 64
./elebake.sh stage kenv add illyria-boot loader.trust.firmware.counter.var ea1fcaee-3a77-4bb8-9b98-518e75d29a99-MotherBoardHealth:8:4
./elebake.sh stage kenv add illyria-boot loader.trust.firmware.moving.var ea1fcaee-3a77-4bb8-9b98-518e75d29a99-MotherBoardHealth:0:8
./elebake.sh expectation add storage-gap byte StorageGap 1
./elebake.sh expectation add clock-order byte ClockOrder 1
./elebake.sh expectation add disk-step byte SmartStep 1
./elebake.sh expectation add anchor-valid byte AnchorValid 1
./elebake.sh expectation add medium-switch byte MediumSwitch 1
./elebake.sh expectation add unsafe-step byte UnsafeStep 1
./elebake.sh expectation add efivars-foreign byte EfiVarsForeign 0
./elebake.sh expectation add firmware-boot-step byte FirmwareBootStep 1
./elebake.sh expectation add firmware-moved byte FirmwareMoved 1
./elebake.sh claim add storage-gap measure_storage_gap diagnose_storage_gap - storage-gap
./elebake.sh claim add clock-order measure_clock_order diagnose_clock_order - clock-order
./elebake.sh claim add disk-step measure_smart_step diagnose_smart_step - disk-step
./elebake.sh claim add anchor-valid measure_anchor_valid diagnose_anchor_valid - anchor-valid
./elebake.sh claim add medium-switch measure_medium_switch diagnose_medium_switch - medium-switch
./elebake.sh claim add unsafe-step measure_unsafe_step diagnose_unsafe_step - unsafe-step
./elebake.sh claim add efivars-foreign measure_efivars_foreign diagnose_efivars_foreign - efivars-foreign
./elebake.sh claim add firmware-boot-step measure_firmware_boot_step diagnose_firmware_boot_step - firmware-boot-step
./elebake.sh claim add firmware-moved measure_firmware_moved diagnose_firmware_moved - firmware-moved
for c in storage-gap clock-order disk-step anchor-valid; do
  ./elebake.sh gate claim add recordlock "$c"
done
./elebake.sh gate add tellwatch
for c in medium-switch unsafe-step efivars-foreign firmware-boot-step firmware-moved; do
  ./elebake.sh gate claim add tellwatch "$c"
done
./elebake.sh policy add watch-tells tellwatch
./elebake.sh policy trigger add watch-tells publish-always
./elebake.sh stage phase policy add illyria-boot PHASE_KERNEL watch-tells
./elebake.sh stage phase show illyria-boot
./elebake.sh stage foundation check illyria-boot
./elebake.sh workflow show time-anchor
