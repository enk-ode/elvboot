# pcr-learn -- PcrBank fell after a legitimate change: take this boot's bank as the expectation

# When: PcrBank failed on a boot you understand -- a rebuilt loader (PCR 4),
# a firmware setting you changed (PCR 1), a firmware update (PCR 0, and then
# the TPM keeps its key file: recover with the disk's passphrase slot and
# reseal, see tpm-seal). Never after a boot you do not understand: then
# nothing is typed, the machine goes to the workbench.

kenv | grep -i "loader.trust.kernellock.failed\|kernellock.pcr"   # PcrBank in failed, the new sha256 published

elebake stage kenv drop daily-v1 loader.trust.kernellock.pcr.expected   # records are immutable: drop first
elebake stage kenv learn daily-v1 loader.trust.kernellock.pcr.expected loader.trust.kernellock.pcr.sha256
elebake stage loaderconf mk daily-v1              # the new expectation into loader.trust.conf
elebake stage include daily-v1                    # the conf into the boot tree
elebake stage push daily-v1 b                     # no rebuild: the loader is unchanged, PCR 4 stays

# Then the owner's off-machine baseline (D.3): a full dump of the EFI
# variables next to the PCR bank, into the infrastructure repository --
# the state you just confirmed, kept where root of this machine cannot
# rewrite it (a snapshot of efivar -l and the PCR bank, then commit).

# Boot: PcrBank passes. loader.trust.pcr.require (kenv) selects the
# registers -- 0,1,2,3,4,6,7 on a machine with two boot cards of unequal
# size, since PCR 5 measures the boot disk's GPT.
