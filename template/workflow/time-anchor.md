# time-anchor -- the machine-local time anchor: two NV indices, the cap PCR, six leafs, seven loader claims, the runtime side

# When: first provisioning of the time anchors, or after a TPM clear
# (the indices are gone: stage tpm status says so). What it adds, in the
# loader: StorageGap (the unpowered time since the last boot), ClockOrder
# (RTC against TPM clock and NVMe hours), SmartStep (the disks' counters
# across the shutdown), AnchorValid (the pair in the TPM equals the record)
# -- all four in recordlock, an unlock when one falls; and the tells
# MediumSwitch, UnsafeStep, EfiVarsForeign in the gate tellwatch, which
# only publishes. In earlboot: the login warning after an unclean shutdown
# (gate shutdownwatch) and the RTC note for the runtime. In elvbootd: the
# shutdown index written at SHUTDOWN, the NTP gap after the tunnel.
# Assumed: wall time is the RTC, which anyone with the setup can set; the
# anchor makes a forged RTC agree with two clocks the attacker cannot turn
# back (Konzepte/zeitanker-lagerung.md).

# --- the leafs (template/tbl/boot-leafs.tbl, gate-free) ---
elebake stage kenv add daily-v1 loader.trust.tpm.anchor.nv 0x01c10e22
elebake stage kenv add daily-v1 loader.trust.tpm.shutdown.nv 0x01c10e23
elebake stage kenv add daily-v1 loader.trust.tpm.cap.pcr 14          # not in pcr.require, not in keyfile.pcrs
elebake stage kenv add daily-v1 loader.trust.storage.gap.max.days 7  # a week unpowered is an unlock; start generous, judge after a series of boots
elebake stage kenv add daily-v1 loader.trust.clock.skew.s 300
elebake stage kenv add daily-v1 loader.trust.smart.step.units.max 64  # NVMe data units of 512,000 bytes: a boot reads a few, a clone terabytes
elebake stage kenv add daily-v1 loader.trust.firmware.counter.var ea1fcaee-3a77-4bb8-9b98-518e75d29a99-MotherBoardHealth:8:4   # the firmware's boot counter (Insyde: bytes 8-11)
elebake stage kenv add daily-v1 loader.trust.firmware.moving.var ea1fcaee-3a77-4bb8-9b98-518e75d29a99-MotherBoardHealth:0:8    # its moving part (bytes 0-7), never the same twice

# --- the TPM: the two indices under the two states of the cap PCR ---
# A database initialised before these acts existed lacks their interpreter
# pins (the profile installs pins at environment init only): set them once,
# or the acts print their script instead of running it.
elebake setenv ELEBAKE_INTERPRETER_stage_tpm_anchor_make 'sudo sh'
elebake setenv ELEBAKE_INTERPRETER_stage_medium_stamp_write 'sudo sh'
sudo mount -t tmpfs -o size=64m tmpfs /tmp/ram && sudo chown $(id -un) /tmp/ram
elebake stage tpm anchor daily-v1
elebake stage tpm status daily-v1
cd / && sudo umount /tmp/ram

# --- the loader: recordlock takes the four, tellwatch the three tells ---
elebake expectation add storage-gap byte StorageGap 1
elebake expectation add clock-order byte ClockOrder 1
elebake expectation add disk-step byte SmartStep 1                # smart-step is the runtime twin in earlboot
elebake expectation add anchor-valid byte AnchorValid 1
elebake expectation add medium-switch byte MediumSwitch 1
elebake expectation add unsafe-step byte UnsafeStep 1
elebake expectation add efivars-foreign byte EfiVarsForeign 0
elebake expectation add firmware-boot-step byte FirmwareBootStep 1
elebake expectation add firmware-moved byte FirmwareMoved 1
elebake claim add storage-gap measure_storage_gap diagnose_storage_gap - storage-gap
elebake claim add clock-order measure_clock_order diagnose_clock_order - clock-order
elebake claim add disk-step measure_smart_step diagnose_smart_step - disk-step
elebake claim add anchor-valid measure_anchor_valid diagnose_anchor_valid - anchor-valid
elebake claim add medium-switch measure_medium_switch diagnose_medium_switch - medium-switch
elebake claim add unsafe-step measure_unsafe_step diagnose_unsafe_step - unsafe-step
elebake claim add efivars-foreign measure_efivars_foreign diagnose_efivars_foreign - efivars-foreign
elebake claim add firmware-boot-step measure_firmware_boot_step diagnose_firmware_boot_step - firmware-boot-step
elebake claim add firmware-moved measure_firmware_moved diagnose_firmware_moved - firmware-moved
elebake gate claim add recordlock storage-gap
elebake gate claim add recordlock clock-order
elebake gate claim add recordlock disk-step
elebake gate claim add recordlock anchor-valid
elebake gate add tellwatch                        # publishes, never prompts: the tells
elebake gate claim add tellwatch medium-switch
elebake gate claim add tellwatch unsafe-step
elebake gate claim add tellwatch efivars-foreign
elebake gate claim add tellwatch firmware-boot-step             # a tell first: promote to recordlock once the +1 has held over a series of boots
elebake gate claim add tellwatch firmware-moved
elebake policy add watch-tells tellwatch
elebake policy trigger add watch-tells publish-always
elebake stage phase policy add daily-v1 PHASE_KERNEL watch-tells
elebake expectation add attempts-zero byte Attempts 0             # Attempts counts what the boot did not ask for
elebake gate claim drop kernelpost attempts                        # claims are immutable: the claim is re-made on the new expectation
elebake claim drop attempts
elebake claim add attempts measure_attempts - attempts attempts-zero
elebake gate claim add kernelpost attempts

# --- earlboot: the login warning after an unclean shutdown, the RTC note ---
elebake expectation add unsafe-grew byte tellwatch 1
elebake expectation add marker-kept byte bootlock 1
elebake claim add unsafe-grew measure_unsafe_grew diagnose_unsafe_grew - unsafe-grew
elebake claim add marker-kept measure_marker_kept diagnose_marker_kept - marker-kept
elebake gate add shutdownwatch
elebake gate claim add shutdownwatch unsafe-grew
elebake gate claim add shutdownwatch marker-kept
elebake policy add shutdown-watch shutdownwatch
elebake trigger add warn-fail when_fail warn_shutdown_act
elebake policy trigger add shutdown-watch warn-fail
elebake policy trigger add shutdown-watch spool-fail
elebake policy trigger add shutdown-watch mark-fail
elebake stage phase policy add daily-v1 SYSINIT shutdown-watch
elebake trigger add clock-always when_always clock_note_act
elebake policy trigger add custody-watch clock-always
elebake expectation add tells-tellwatch byte tellwatch 1                    # the tells gate spools and marks a fallen tellwatch
elebake claim add tells-tellwatch measure_gate_clean diagnose_gate_clean - tells-tellwatch
elebake gate claim add tells tells-tellwatch

# --- elvbootd: the shutdown index, the NTP gap ---
elebake expectation add ntp-gap byte 600 1
elebake claim add ntp-gap measure_ntp_gap diagnose_ntp_gap - ntp-gap
elebake gate claim add daily ntp-gap                       # PERIODIC only: at STARTUP ntpd is not synchronised yet, an armed claim without a measurement fails
elebake expectation add health-unique byte ea1fcaee/MotherBoardHealth 1
elebake claim add health-unique measure_efivar_unique diagnose_efivar_unique - health-unique
elebake gate claim add daily health-unique                 # the full history: this boot's digest in no earlier record
elebake gate add shutdownanchor
elebake policy add shutdown-anchor shutdownanchor
elebake trigger add anchor-always when_always smart_anchor_act
elebake policy trigger add shutdown-anchor anchor-always
elebake stage phase policy add daily-v1 SHUTDOWN shutdown-anchor

# --- build, install, push (the letter is stamped by push) ---
elebake stage phase show daily-v1
elebake stage foundation make daily-v1
elebake stage site mk daily-v1
elebake stage loaderconf mk daily-v1
elebake stage make daily-v1
elebake stage earlboot mk daily-v1 && elebake stage earlboot install daily-v1
elebake stage elvbootd mk daily-v1 && elebake stage elvbootd install daily-v1
elebake stage push daily-v1 b

# Boot 1: the record is version 2 -- the chain starts once more: RecordValid
# falls, and with it every claim that measures against the record or the
# anchor (an armed claim without a measurement FAILS, claim.c): one unlock
# for recordlock, one for kernellock (PcrBank, PCR 4). The anchor is written
# for the first time, the boot answer is confirmed once more before the
# first record (a new chain). tellwatch falls too (no anchor, no record) --
# a tell, spooled by the tells gate. Then pcr-learn. Boot 2 (after a clean
# shutdown): everything present, the answer once; still. Then the other
# card: clone, stamp (stage medium stamp daily-v1 a), boot -- MediumSwitch
# tells once.
