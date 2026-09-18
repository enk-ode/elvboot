# kenv-change -- a loader.trust.* value changes: no rebuild, no PCR round

# When: a leaf the loader reads at boot changes -- a question, a display
# list, a deadline, the TPM handles, the GELI tries, pcr.require. The kenv
# records land in loader.trust.conf, which rides on the medium in clear
# and is covered by the manifest; the loader binary does not change.

elebake stage require daily-v1                    # what the bound actions and the boot read, each with its record or MISSING
elebake stage kenv drop daily-v1 loader.trust.kernellock.question     # immutable: drop first (skip for a new leaf)
elebake stage kenv add daily-v1 loader.trust.kernellock.question "Do you have fish?"
elebake stage loaderconf mk daily-v1              # refuses while a required leaf has no value
elebake stage include daily-v1
elebake stage push daily-v1 b

# Boot: no PcrBank report (PCR 4 unchanged). A value with blanks is one
# argument, quoted. Boot leafs (template/tbl/boot-leafs.tbl) have no gate
# in their name: loader.trust.tpm.*, loader.trust.pcr.require,
# loader.trust.geli.tries.
