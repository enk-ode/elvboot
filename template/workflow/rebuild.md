# rebuild -- a new loader from a changed checkout or policy, then relearn the PCR bank

# When: the fork branch moved (recheckout), a policy, trigger, claim or
# gate changed (foundation.c), a baseline changed (site.mk). Anything that
# changes loader.efi changes PCR 4, so PcrBank falls once and is relearned.
# Replace daily-v1 and the medium letter with yours.

elebake stage recheckout daily-v1 ptg-15.1-next   # only when the branch moved
elebake stage trust daily-v1                      # the fresh worktree has no trust anchor
elebake stage foundation make daily-v1            # the policy tables into foundation.c
elebake stage site mk daily-v1                    # the baselines into site.mk (and the inventory sets)
elebake stage loaderconf mk daily-v1              # loader.trust.conf from the kenv records -- after EVERY kenv change
elebake stage make daily-v1                       # build, install, include, sign
elebake stage earlboot mk daily-v1 && elebake stage earlboot install daily-v1    # the hooks carry the loader's digest:
elebake stage elvbootd mk daily-v1 && elebake stage elvbootd install daily-v1    # regenerate after every make (install: never with sudo, the pins do it)
elebake stage push daily-v1 b                     # manifest, attest, tree onto the medium, loader onto the ESP

# Boot. Expected: kernellock reports PcrBank and, with unlock-fail bound,
# asks the unlock passphrase (the informed decision); everything else
# green. Then the PCR bank of the new loader becomes the expectation:

elebake stage kenv drop daily-v1 loader.trust.kernellock.pcr.expected
elebake stage kenv learn daily-v1 loader.trust.kernellock.pcr.expected loader.trust.kernellock.pcr.sha256
elebake stage loaderconf mk daily-v1
elebake stage include daily-v1                    # the conf into the boot tree, no rebuild
elebake stage push daily-v1 b

# Boot: silent but for the dialog (GELI passphrase, boot answer, the
# sentinel question). Then the other medium: clone it from this one and
# boot it once (PCR 5, the boot disk's GPT, is out of pcr.require, so
# both cards measure the same).
