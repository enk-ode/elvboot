# baseline-relearn -- a compiled-in expectation moved (a digest, a window): learn it from this boot, rebuild

# When: a claim with a compiled baseline fell for a reason you understand --
# SoftPcr after a changed module or Lua file, a set digest after an
# inventory drop, the TPM storage key after a reseal, a time window after a
# series of settled boots. Baselines are -D macros in site.mk: relearning
# is a rebuild, so a PCR round follows.

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
