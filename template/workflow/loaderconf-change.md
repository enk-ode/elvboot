# loaderconf-change -- a loader.conf line changes (a kernel tunable, a hint, a module to preload): no rebuild, usually no PCR round
# When: a tunable the kernel reads at boot (hw.dmar.enable, kern.*, hint.*),
# a _load="YES" line, anything in loader.conf that is not a loader.trust.*
# leaf. The stage's boot/loader.conf IS the machine's loader.conf: the
# tree on the medium is what the loader reads, the copy under zroot:/boot
# is never read. So every tunable goes here, whether or not it has to do
# with the boot itself. loader.trust.* values are the other workflow
# (kenv-change: stage kenv add, stage loaderconf mk).
elebake stage edit daily-v1 loader.conf           # the pinned editor; one line, quoted: hw.dmar.enable="1"
elebake stage include daily-v1                    # the file back into the tree, the manifest signed again
elebake stage push daily-v1 b                     # loader.conf rides on the medium under PrereqsVerify
# Boot: silent. PrereqsVerify checks loader.conf against the new manifest;
# KenvGuard hashes ten fixed keys only (vfs.root.mountfrom, init_path,
# module_path, kernel, kernelname, loader_conf_files, ...): a line outside
# that list changes no compiled baseline. A line INSIDE it (a new root
# dataset, another kernel directory) moves LOADER_TRUST_KENV_GUARD_DIGEST:
# then baseline-relearn (rebuild, PCR round) with the pair
#   LOADER_TRUST_KENV_GUARD_DIGEST  loader.trust.kernellock.kenv.sha256
# A _load="YES" line preloads a module: the module must be in the tree
# (workflow module-from-ports, case B) and SoftPcr moves.
