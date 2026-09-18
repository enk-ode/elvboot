# halt-relearn -- HaltQuiet fell: a halt (a shutdown class of the sentinel, a probe) raised the counter; acknowledge it, or investigate

# When: the boot after a shutdown that earlboot fired -- a fish class bound
# to shutdown-pass, or any halt of yours -- reports HaltQuiet in recordlock
# and asks the unlock passphrase. The counter is an NV index in the TPM
# (loader.trust.halt.nv), raised by shutdown_act, lowered by nobody: what
# the loader compares it with is the learned leaf halt.expected, never the
# record, so deleting the record does not hide the halt. If YOU caused the
# halt, relearn; if not, the machine goes to the workbench first.

kenv | grep -i "recordlock.failed\|recordlock.halt"     # HaltQuiet in failed, halt.count and halt.sha256 published

elebake stage kenv drop daily-v1 loader.trust.recordlock.halt.expected      # immutable: drop first (skip the first time)
elebake stage kenv learn daily-v1 loader.trust.recordlock.halt.expected loader.trust.recordlock.halt.sha256
elebake stage loaderconf mk daily-v1
elebake stage include daily-v1
elebake stage push daily-v1 b                     # no rebuild

# Boot: HaltQuiet passes. The duress counter (loader.trust.tpm.counter.nv)
# is a different index and stays silent: only earlboot reads the duress
# bit, from the handover word.
