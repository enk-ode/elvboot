# module-from-ports -- a kernel module from a port (drm-kmod, nvidia-driver): loaded at runtime nothing changes on the medium; preloaded by the loader it joins the tree
# When: pkg install of a port that ships a .ko under /boot/modules, or a
# pkg upgrade that replaces one.
# --- case A, the rule: the module loads at runtime (kld_list) ---
# The module lives under zroot:/boot/modules, behind the encrypted root,
# and rc loads it from there; the medium carries kernel/ for the loader's
# preloads and the kernel itself, not /boot/modules. Nothing in the stage
# changes, no push, no PCR round. What guards the module is not the boot
# chain (veriexec is inactive at runtime by design, the custody claim
# veriexec-inactive says so) but the protection of the root: securelevel,
# schg on /boot, the periodic mtree specification. Keep that in mind when
# a port is the only thing standing between the kernel and a file root can
# write.
sudo pkg install drm-kmod                         # or pkg upgrade
sudo sysrc kld_list+=" i915kms"                   # the runtime list
sudo kldload i915kms                              # now, or the next boot does it
# Boot: silent. Check once: kldstat lists the module; the module was built
# for the kernel on the MEDIUM (freebsd-version -k), not for the one under
# zroot:/boot/kernel -- with pkgbase both are the same release, a patch
# level apart at most, and the ABI holds within a release.
# --- case B, the exception: the loader preloads it (<name>_load="YES") ---
# Needed only when the kernel must have the module before the root is
# open (a storage or crypto driver). The module must then ride on the
# medium, be in the manifest, and it is measured into SoftPcr:
cd "$HOME/.elebake/db/stage/daily-v1/boot" && mkdir -p modules && cp /boot/modules/<name>.ko modules/ && cd -   # the adopted file (the build does not deliver it): as the operator, never as root
elebake stage filter add daily-v1 modules/<name>.ko   # curated: include keeps it ("absent from the source, present in boot/")
elebake stage edit daily-v1 loader.conf           # <name>_load="YES"
elebake stage include daily-v1
elebake stage push daily-v1 b
# Boot: SoftPcr falls (a new preload), then baseline-relearn with the pair
#   LOADER_TRUST_SOFTPCR_DIGEST  loader.trust.kernellock.softpcr.sha256
# -- a rebuild and a PCR round. Prefer case A whenever the module can wait
# for rc.
