# baseline-relearn -- a compiled-in expectation moved (a digest, a window): learn it from this boot, rebuild

# When: a claim with a compiled baseline fell for a reason you understand --
# SoftPcr after a changed module or Lua file, a set digest after an
# inventory drop, the TPM storage key after a reseal, a time window after a
# series of settled boots. Baselines are -D macros in site.mk: relearning
# is a rebuild, so a PCR round follows.
#
# LoadedImages after a change BELOW the operating system: a repartitioned
# disk, a re-provisioned TPM (new objects, new indices), a device added to
# the dock. The firmware's disk, partition and TPM drivers keep what they
# enumerated in their data sections, and LoadedImages digests those
# images as they sit in memory -- a dozen members of the set change their
# digest at once, deterministically, and keep the new one on the next
# cold boot. That is a new state, not a moving member: relearn
# LOADER_TRUST_IMAGES_DIGEST here, do not drop (inventory-drop is for a
# member that differs from boot to boot).

kenv | grep -i "loader.trust.*failed="            # which claim, and the published value beside it

elebake stage baseline drop daily-v1 LOADER_TRUST_SOFTPCR_DIGEST          # immutable: drop first
elebake stage baseline learn daily-v1 LOADER_TRUST_SOFTPCR_DIGEST loader.trust.kernellock.softpcr.sha256
elebake stage site mk daily-v1                    # the macro into site.mk
elebake stage make daily-v1
elebake stage earlboot mk daily-v1 && elebake stage earlboot install daily-v1
elebake stage elvbootd mk daily-v1 && elebake stage elvbootd install daily-v1
elebake stage push daily-v1 b

# Boot: the relearned claim passes, PcrBank falls once (new loader).
# Continue with pcr-learn. Pairs seen so far:
#   LOADER_TRUST_SOFTPCR_DIGEST   loader.trust.kernellock.softpcr.sha256
#   LOADER_TRUST_IMAGES_DIGEST    loader.trust.inventory.images.sha256   (after inventory-drop)
#   LOADER_TRUST_TPM_KEY_DIGEST   loader.trust.tpm.key.sha256            (after tpm-seal)
#   LOADER_TRUST_TIME_BOOT_MAX_MS is set by hand (stage baseline add ... int), not learned
