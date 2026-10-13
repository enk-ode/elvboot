# tells-narrow -- the tell classes narrow later phases: lock, freeze, courier, shutdown in SYSINIT, bound to what a fallen claim means

# When: once, after the loader's gates are bound and the record chain runs
# (the loader informs, the unlock decides; this is the narrowing behind it,
# policy only -- no loader change, a rebuild of foundation.c, the hooks).
# Seven earlboot measurements read the loader's kenv in SYSINIT; each
# prints 1 when its tell is absent and 0 when it is there, nothing when
# the gate it reads published nothing (a bypassed loader fails every one).
# The label of the expectation is the gate the measurement reads
# (bootlock, recordlock, kernelpost, tellwatch; '-' for the scan over all).
# Replace the gate names with yours (elebake gate show).
elebake expectation add class-identity byte - 1
elebake claim add class-identity measure_class_identity diagnose_class_identity identity.fallen class-identity
elebake expectation add setup-factory byte bootlock 1
elebake claim add setup-factory measure_setup_factory diagnose_setup_factory setup.failed setup-factory
elebake expectation add storage-long byte recordlock 1
elebake claim add storage-long measure_storage_long diagnose_storage_long storage.long storage-long
elebake expectation add smart-clone byte recordlock 1
elebake claim add smart-clone measure_smart_clone diagnose_smart_clone smart.clone smart-clone
elebake expectation add halt-foreign byte recordlock 1
elebake claim add halt-foreign measure_halt_foreign diagnose_halt_foreign halt.foreign halt-foreign
elebake expectation add attempts-nonzero byte kernelpost 1
elebake claim add attempts-nonzero measure_attempts_nonzero diagnose_attempts_nonzero attempts.nonzero attempts-nonzero
elebake expectation add moved-repeat byte tellwatch 1
elebake claim add moved-repeat measure_moved_repeat diagnose_moved_repeat moved.repeat moved-repeat

# The gates: one per reaction, so a policy's when_fail carries the acts
# the class asks for (an act binds to a gate's verdict, not to a claim).
elebake gate add narrow                           # every tell: spooled and marked, the next boot's motd shows it
elebake gate claim add narrow class-identity
elebake gate claim add narrow setup-factory
elebake gate claim add narrow storage-long
elebake gate claim add narrow smart-clone
elebake gate claim add narrow halt-foreign
elebake gate claim add narrow attempts-nonzero
elebake gate claim add narrow moved-repeat
elebake gate add narrow-lock                      # the factory state of the firmware, an absence beyond a month: zdata stays closed, elebake refuses push and seal until the owner acknowledges
elebake gate claim add narrow-lock setup-factory
elebake gate claim add narrow-lock storage-long
elebake gate add narrow-courier                   # a moved identity, foreign attempts at the loader, a firmware state played back: the finding travels on the card to the admin machine, the push is frozen
elebake gate claim add narrow-courier class-identity
elebake gate claim add narrow-courier halt-foreign
elebake gate claim add narrow-courier moved-repeat
elebake gate add narrow-stop                      # a disk read whole since the last boot: the clone's size -- running it on serves only the one who holds the clone
elebake gate claim add narrow-stop smart-clone

# The triggers (the ones named here may exist from earlier workflows:
# elebake trigger show):
elebake trigger add spool-fail when_fail spool_act
elebake trigger add mark-fail when_fail mark_act
elebake trigger add lock-fail when_fail lock_act
elebake trigger add freeze-fail when_fail freeze_act
elebake trigger add courier-fail when_fail courier_act
elebake trigger add shutdown-fail when_fail shutdown_act
elebake policy add tells-narrow narrow
elebake policy trigger add tells-narrow spool-fail
elebake policy trigger add tells-narrow mark-fail
elebake policy add tells-narrow-lock narrow-lock
elebake policy trigger add tells-narrow-lock lock-fail
elebake policy trigger add tells-narrow-lock freeze-fail
elebake policy add tells-narrow-courier narrow-courier
elebake policy trigger add tells-narrow-courier freeze-fail
elebake policy trigger add tells-narrow-courier courier-fail
elebake policy add tells-narrow-stop narrow-stop
elebake policy trigger add tells-narrow-stop freeze-fail
elebake policy trigger add tells-narrow-stop shutdown-fail
elebake stage phase policy add daily-v1 SYSINIT tells-narrow
elebake stage phase policy add daily-v1 SYSINIT tells-narrow-lock
elebake stage phase policy add daily-v1 SYSINIT tells-narrow-courier
elebake stage phase policy add daily-v1 SYSINIT tells-narrow-stop

# The windows the two thresholds multiply (four times, a thousand times)
# are the stage's: loader.trust.storage.gap.max.days, loader.trust.smart.step.units.max.
elebake stage phase show daily-v1
elebake stage foundation make daily-v1
elebake stage earlboot mk daily-v1 && elebake stage earlboot install daily-v1
elebake stage earlboot test daily-v1 /tmp/ram/boot.kenv          # a captured boot replayed: the narrow gates pass on a quiet boot
elebake stage make daily-v1                                        # foundation.c carries the gates: a rebuild, then pcr-learn
elebake stage elvbootd mk daily-v1 && elebake stage elvbootd install daily-v1
elebake stage push daily-v1 b
# Boot: the narrow gates pass; PcrBank falls once (new loader): pcr-learn.
# The probes (Anchor list §6.6): Secure Boot off in the setup -> the unlock
# at kernellock, zdata stays closed (lock), elebake frozen; setup restored,
# acknowledged, quiet. beacon_act stays unbound until an addressee exists.
