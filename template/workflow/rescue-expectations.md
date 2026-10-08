# rescue-expectations -- the rescue path judges with its own expectations: loader.trust.<gate>.rescue.<claim> in the stage's conf

# When: after the first rescue boot of a stage, when the production's
# claims fall on the rescue path for reasons of the path, not of the
# machine: the card's key slot instead of the TPM key file (TpmKeyfile,
# GeliSlot), the production's anchor and counters (AnchorValid,
# CounterStep -- the TPM reset count and the NVMe power cycles step with
# every production boot in between), the preloads of the rescue path
# (SoftPcr, PcrBank). A claim reads loader.trust.<gate>.rescue.<claim name
# in lower case> when the boot goes to the rescue root: "skip" disarms it
# there, a value replaces the expectation. The conf is part of the
# manifest: loaderconf mk, sign, push -- no rebuild, no PCR round.
elebake stage kenv add daily-v1 loader.trust.recordlock.rescue.tpmkeyfile 0      # the card's key file opened the root, not the TPM's
elebake stage kenv add daily-v1 loader.trust.recordlock.rescue.gelislot 0        # slot 0: passphrase and key file
elebake stage kenv add daily-v1 loader.trust.recordlock.rescue.anchorvalid skip  # the anchor is the production's
elebake stage kenv add daily-v1 loader.trust.recordlock.rescue.counterstep skip  # the production boots in between stepped the counters
elebake stage kenv learn daily-v1 loader.trust.kernellock.rescue.softpcr loader.trust.kernellock.softpcr.sha256   # from a rescue boot: kenv of the rescue system
elebake stage kenv learn daily-v1 loader.trust.kernellock.rescue.pcrbank loader.trust.kernellock.pcr.sha256
elebake stage loaderconf mk daily-v1
elebake stage sign daily-v1
elebake stage push daily-v1 b
# Boot (rescue): the record claims of the rescue chain pass from the second
# rescue boot on (RecordValid, ChainOnMedium, LastBootGap, StorageGap,
# ClockOrder judge the rescue's own record, ElvRescueRecord and chain-rescue
# on the medium); the four above are skipped or expected as the path has
# them; SoftPcr and PcrBank judge the rescue path's own digests. The
# production boot is untouched: no rescue.* leaf is read there.
