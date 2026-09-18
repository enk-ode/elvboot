# policy-change -- a trigger, claim, expectation or gate changes: foundation.c, rebuild, PCR round

# When: the policy of a gate changes (a trigger bound or dropped, its
# position), a claim is added or replaced, an expectation's value moves.
# The arsenal records are immutable: to change one, drop it and add it
# again; the gate's claim list and the policy's trigger list keep their
# order, a position argument inserts.

elebake trigger add unlock-fail when_fail unlock_act        # a trigger: when, action
elebake policy trigger add guard-kernellock unlock-fail 2   # bound at position 2: right after publish, BEFORE the dialog
elebake policy trigger drop guard-kernellock report-fail    # the one it replaces

elebake gate claim drop kernelpost attempts                 # an expectation changes: unlink, drop, add, link
elebake claim drop attempts
elebake expectation add attempts-three byte Attempts 3
elebake claim add attempts measure_attempts - attempts attempts-three
elebake gate claim add kernelpost attempts

elebake stage phase show daily-v1 PHASE_KERNEL     # the tables as foundation.c will carry them
elebake stage foundation check daily-v1           # every reference resolves against the checkout's catalog
elebake stage foundation make daily-v1
elebake stage make daily-v1
elebake stage earlboot mk daily-v1 && elebake stage earlboot install daily-v1
elebake stage elvbootd mk daily-v1 && elebake stage elvbootd install daily-v1
elebake stage push daily-v1 b

# Boot, then pcr-learn. earlboot and elvbootd policies (SYSINIT, MOUNTED,
# STARTUP ...) need no rebuild of the loader: their mk + install is enough.
