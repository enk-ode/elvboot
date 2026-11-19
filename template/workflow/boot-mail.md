# boot-mail -- every boot's snapshot by mail: the owner's mailbox keeps a copy of the record with the time it arrived

# When: once per stage, after boot-snapshots (kenv_act must write the file
# first). mail_act (elvbootd) mails the snapshot kenv_act wrote or appended,
# in the same phase: at STARTUP the loader's leaves with the chain header,
# at SHUTDOWN the same file with the session's appraisals under it. Subject
# "<host>: elvboot[<phase>]: boot <counter> <stamp>", body the file as it
# is. The address is the engine's ELEBAKE_MAIL_TO (the constant ELV_MAIL_TO
# of the hooks; empty, nothing is sent) -- the host's, not the loader's, so
# no baseline and no loader rebuild. Delivery is the host's
# MTA (sendmail -t -oi); with dma and a smarthost the SHUTDOWN mail waits
# in the queue and leaves with the next boot. The mails of consecutive
# boots hang together by the chain header; the mailbox adds the time of
# arrival. What the mail proves: that this file left this host under root
# at that time. It is a copy, not a signature -- the forensic report
# ('report forensic', 'report sign' with the attest key on the card) is.
# The fork must carry mail_act (elvboot-dev-15.1) -- recheckout first when
# it does not. The order of the triggers in the policy is the order of
# the actions: kenv-always before mail-always.
elebake setenv ELEBAKE_MAIL_TO <owner>+<host>.elvboot.boot@<domain>
elebake trigger add mail-always when_always mail_act
elebake policy trigger add runtime-watch mail-always              # STARTUP, after kenv-always
elebake policy trigger add shutdown-anchor mail-always            # SHUTDOWN, after kenv-always
elebake stage elvbootd mk daily-v1 && elebake stage elvbootd install daily-v1   # no rebuild: the hooks only
# Before the install, a replay without root: the tee mock prints the mail
# (headers and body) in place of sendmail:
#   elebake stage elvbootd test daily-v1 STARTUP /tmp/ram/boot.kenv
# Boot: the mail arrives; its body is /var/db/elvboot/boots/<stamp>-<counter>.kenv.
# Mail of the host: the MTA's smarthost and the recipient's folder rule
# (Infrastruktur, Konzepte/proton-sync-architektur.md, Systemmails).
