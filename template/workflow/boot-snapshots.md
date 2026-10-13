# boot-snapshots -- elvbootd keeps the loader's kenv of every boot, with the session's verdicts: the raw material of a report

# When: once per stage. The boot summary line in syslog carries the gate
# verdicts only; what the loader measured and what it expected lives in
# the kenv of the running boot and is gone with the next. kenv_act
# (elvbootd) writes every loader.trust.* leaf of the boot under
# /var/db/elvboot/boots/<stamp>-<counter>.kenv at STARTUP (root; the
# header carries the sha256 of the previous snapshot: a rewritten past
# breaks the chain; the stamp leads the name because the counter starts
# at 1 again when the record chain starts anew) and appends the
# session's appraisals and spool lines to the same file at SHUTDOWN. The
# 200 newest stay. persist_act on the runtime gates puts their verdicts
# into appraisal-<gate>, which the SHUTDOWN run copies -- without it the
# snapshot carries the loader's side only. The hooks are regenerated
# from the stage's checkout: the fork must carry this kenv_act
# (elvboot-dev-15.1 with kenv_act) -- recheckout first when it does not.
elebake trigger add kenv-always when_always kenv_act
elebake policy trigger add runtime-watch kenv-always
elebake policy trigger add shutdown-anchor kenv-always          # the SHUTDOWN run appends (policy from workflow time-anchor)
elebake trigger add persist-always when_always persist_act     # when custody-watch does not already define it
elebake policy trigger add runtime-watch persist-always        # ... and every other runtime policy whose verdict the report should carry: elebake policy show
elebake stage elvbootd mk daily-v1 && elebake stage elvbootd install daily-v1   # no rebuild: the hooks only
# Before the install, a replay without root: elebake stage elvbootd test daily-v1 STARTUP /tmp/ram/boot.kenv
# Boot: /var/db/elvboot/boots/<stamp>-<counter>.kenv appears (sudo ls /var/db/elvboot/boots); after a shutdown it ends in '# elvbootd at=...'.
