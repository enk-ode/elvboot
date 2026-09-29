# duress-bind -- the coercion classes raise the second counter before the stop: slot 0 dies in the TPM, the next boot is the decoy boot

# When: tpm-seal has run (the second counter and duress.count.sealed
# exist) and the checkout's earlboot carries duress_count_act. The answer
# classes that mean coercion ("safely manipulated") bind shutdown-pass
# today; the counter's increment has to sit right in front of it -- the
# owner's object opens only while the counter still reads the sealed
# value, one increment closes it for good, and only the paper slot leads
# back. The stop stays a power-off, never a reboot: a warm restart moves
# the firmware volumes in LoadedImages, inventory falls in the boot that
# follows, and that boot is the decoy boot, where every gate before the
# dialog still runs. A cold start keeps the inventory; what the stop's
# halt_count_act raises (HaltQuiet) lives in recordlock, the dialog's
# gate, which the decoy boot does not bind.

elebake trigger add duress-count-pass when_pass duress_count_act   # the trigger: the class matched, the counter rises (spool line duress-count: pass, unconfirmed or fail)
elebake answer show daily-v1                                        # the classes and their policies; the coercion classes are the ones bound to shutdown-pass
elebake policy show fish-0                                          # the class's triggers in order: shutdown-pass is the last

elebake policy trigger drop fish-0 shutdown-pass                    # the stop leaves ...
elebake policy trigger add fish-0 duress-count-pass                 # ... the counter takes the end of the list ...
elebake policy trigger add fish-0 shutdown-pass                     # ... and the stop follows it again
# The same three lines for every other coercion class (fish-7, fish-8,
# fish-9 on illyria) and for the template they were made from (answer
# policy show daily-v1 <template>), so a class added later inherits it.

elebake stage phase show daily-v1 SYSINIT          # the tables as earlboot will carry them: duress_count_act before shutdown_act
elebake stage foundation check daily-v1           # every reference resolves against the checkout's catalog (earlboot/action.sh has duress_count_act)
elebake stage foundation make daily-v1
elebake stage earlboot mk daily-v1 && elebake stage earlboot install daily-v1    # SYSINIT is earlboot's: no rebuild of the loader
elebake stage push daily-v1 b

# The probe (test plan, paper checked first): boot with the owner
# passphrase, answer the sentinel with a coercion class -> the spool line
# "duress-count pass attempt=1 count=<sealed+1> sealed=<sealed>", then the
# power-off. Cold start, the duress passphrase at the loader: the decoy
# root comes up, no further prompt. The boot after that with the owner
# passphrase: the owner's object is dead (tpm.keyfile unsealed=0,
# duress.count=<sealed+1>/<sealed>) -> the paper slot, then tpm-seal (it
# reads the counter's new value), boot silent.
