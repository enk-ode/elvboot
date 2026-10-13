# rescue-expectations -- the rescue path judges with its own expectations: loader.trust.<gate>.rescue.<claim> in the stage's conf

# When: after the first rescue boot of a stage, when the production's
# claims fall on the rescue path for reasons of the path, not of the
# machine: the card's key slot instead of the TPM key file (TpmKeyfile is
# not even measured there -- the TPM is not asked; GeliSlot is 1 on both
# paths: the card's slot 0 is passphrase and key file), the production's anchor and counters (AnchorValid,
# CounterStep, and the tells MediumSwitch and FirmwareBootStep -- the
# production boots in between step the counters), the preloads of the
# rescue path (SoftPcr). PcrBank is the same on both paths: the loader is
# measured before the divert, the production's expectation holds. A claim
# reads loader.trust.<gate>.rescue.<claim name in lower case> when the boot
# goes to the rescue root: "skip" disarms it there, a value replaces the
# expectation; an absent measurement matches no value, only skip. The conf
# is part of the manifest: loaderconf mk, include, push -- no rebuild, no
# PCR round.
elebake stage kenv add daily-v1 loader.trust.recordlock.rescue.tpmkeyfile skip   # not measured on the rescue path
elebake stage kenv add daily-v1 loader.trust.recordlock.rescue.anchorvalid skip  # the anchor is the production's
elebake stage kenv add daily-v1 loader.trust.recordlock.rescue.counterstep skip  # the production boots in between stepped the counters
elebake stage kenv add daily-v1 loader.trust.tellwatch.rescue.mediumswitch skip  # the rescue chain knows no last medium
elebake stage kenv add daily-v1 loader.trust.tellwatch.rescue.firmwarebootstep skip
elebake stage kenv add daily-v1 loader.trust.kernelpost.rescue.attempts 1         # the y at the rescue offer
elebake stage kenv add daily-v1 loader.trust.kernelpost.rescue.promptwindow skip  # the dialog of the rescue path has its own length
elebake stage kenv learn daily-v1 loader.trust.kernellock.rescue.softpcr loader.trust.kernellock.softpcr.sha256   # from a rescue boot: kenv of the rescue system (again after every rebuild that changes the preloads)
elebake stage loaderconf mk daily-v1
elebake stage include daily-v1                    # the conf into the boot tree
elebake stage push daily-v1 b                     # push attests the manifest itself: no stage sign here -- a re-signed loader has a new digest the hooks do not know
# Boot (rescue): the record claims of the rescue chain pass from the second
# rescue boot on (RecordValid, ChainOnMedium, LastBootGap, StorageGap,
# ClockOrder judge the rescue's own record, ElvRescueRecord and chain-rescue
# on the medium); the skipped ones are skipped, SoftPcr judges the rescue
# path's own value, PcrBank and GeliSlot the shared ones. The production
# boot is untouched: no rescue.* leaf is read there.
