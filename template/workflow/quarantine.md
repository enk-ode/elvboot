# quarantine -- the decoy root zempty: built like the rescue, sent into the container the TPM's file opens, snapshotted, signed, witnessed

# When: the first fill of the quarantine container, and every rollout of
# it afterwards (a package set updated). zempty is the root the loader
# diverts to on the duress way: a default installation nobody maintains,
# no sensitive data, no access -- a system that distrusts the chain it
# was booted by (its guard exports every foreign pool, detaches every
# idle GELI provider, unloads tpm.ko before anything else runs). Its
# content is DEFINED and built by elebake: the base set from the owner's
# repository, no kernel (the medium's, verified, boots it), no boot code
# on its disk, a random root password, no user, no sshd, securelevel 2,
# a read-only root with /tmp and /var in memory. The description is in
# the dump, the baseline is signed, the container holds the snapshot
# ZFS proves (GUID), the witness says whether it was written since.
# Replace daily-v1, the partition, the pool, the swap device and the
# interface with yours.
# --- 1. the description (once; replayed by the dump) ---
elebake stage quarantine dataset add daily-v1 zroot/ROOT/zempty     # the build root on the production pool; its basename names the root on the container
elebake stage quarantine pool add daily-v1 zempty
elebake stage quarantine partition add daily-v1 nda1p1
elebake stage quarantine keyfile add daily-v1 zempty.bin            # the TPM's file on the RAM disk, from the seed (step 2)
elebake stage quarantine swap add daily-v1 /dev/gpt/illyria-swap.eli
elebake stage quarantine rc add daily-v1 'hostname="illyria"'
elebake stage quarantine rc add daily-v1 'zfs_enable="YES"'
elebake stage quarantine rc add daily-v1 'keymap="de.acc.kbd"'
elebake stage quarantine rc add daily-v1 'dumpdev="NO"'
elebake stage quarantine rc add daily-v1 'moused_enable="NO"'
elebake stage quarantine rc add daily-v1 'sshd_enable="NO"'
elebake stage quarantine rc add daily-v1 'ifconfig_igc0="DHCP"'
elebake stage quarantine rc add daily-v1 'kern_securelevel_enable="YES"'
elebake stage quarantine rc add daily-v1 'kern_securelevel="2"'
elebake stage quarantine rc add daily-v1 'devmatch_enable="NO"'         # no kernel of its own, no linker.hints: devmatch would print a page per device
elebake stage quarantine rc add daily-v1 'geli_swap_flags="-e AES-XTS -l 256 -s 4096 -d"'
elebake stage quarantine rc add daily-v1 'syslogd_flags="-ss"'
elebake stage quarantine rc add daily-v1 'tmpmfs="YES"'                 # the root is read-only on the container: /tmp and /var in memory
elebake stage quarantine rc add daily-v1 'varmfs="YES"'
elebake stage quarantine show daily-v1
# --- 2. the TPM's file on the RAM disk (every open of the container: init, push, verify) ---
elebake ram open
gpg --decrypt ~/.local/share/hkdf-tree/seed.gpg | hkdf-tree show --config ~/.config/hkdf-tree/inventory.yaml --entry enk-ode/illyria/zempty-tpm-v1 | base64 -d > ~/.elebake/db/.ram/zempty.bin
# --- 3. the container (once, or anew: zeros over every sector -- a provider grown without them writes integrity failures on every read of the new space) ---
elebake stage quarantine container init daily-v1                  # geli init with the file alone (no passphrase), attach, zeros (minutes), pool with ROOT, exported
# --- 4. the build (every rollout) ---
elebake stage quarantine dataset make daily-v1
elebake stage quarantine dataset open daily-v1
elebake stage quarantine build daily-v1                           # base set, rc.conf, frame (fstab, localtime, console insecure, root password random), guard, baseline signed
sudo env GEOMCHECK_DRYRUN=1 sh ~/.elebake/mnt/daily-v1-quarantine/etc/rc.d/geomcheck start   # the guard's dry run in THIS system: would export zdata and zempty, would unmount the build root, no "would detach" for zroot's providers
sudo cat /var/log/geomcheck.log
sudo rm /var/log/geomcheck.log
elebake stage quarantine dataset close daily-v1
elebake stage quarantine snapshot daily-v1
elebake stage quarantine push daily-v1                            # the whole tree the first time, the increment after; bootfs, readonly, GUID proven, receipt
elebake stage quarantine verify daily-v1                          # the signature, the GUID, the tree against the baseline
elebake ram close
# The hand-filled root of the first fill (zempty/ROOT/default) stays on the
# pool until the owner removes it: elebake stage quarantine container open,
# sudo zfs destroy -r zempty/ROOT/default, elebake stage quarantine container close.
# --- 5. the loader's way to it, the seal, the witness ---
elebake stage kenv add daily-v1 loader.trust.tpm.decoy.providers nda1p1
elebake stage kenv add daily-v1 loader.trust.tpm.decoy.root zfs:zempty/ROOT/zempty   # the dataset's basename on the pool (stage kenv drop first when the leaf named ROOT/default)
elebake workflow show tpm-seal                     # the duress object carries zempty.bin: seal, or reseal after a rotation
elebake stage witness add daily-v1 zempty nda1p1   # once; the receipt at every rollout:
elebake stage witness measure daily-v1             # the labels and the table (the uberblock moved with the push: a new receipt)
elebake stage witness measure full daily-v1        # the container and the free tail of its disk, minutes
elebake stage witness conf daily-v1
elebake ram open
gpg --decrypt ~/.local/share/hkdf-tree/seed.gpg | hkdf-tree show --config ~/.config/hkdf-tree/inventory.yaml --entry enk-ode/illyria/tpm-hierarchy-v1 | base64 -d | hexdump -ve '1/1 "%02x"' > ~/.elebake/db/.ram/auth-hierarchy.hex
elebake stage witness anchor daily-v1              # the table of all witnesses anew into the TPM (the owner hierarchy)
elebake ram close
elebake stage loaderconf mk daily-v1
elebake stage include daily-v1
elebake stage push daily-v1 b
elebake stage witness show daily-v1                # the receipt lines: paper and the public commit
# Boot: quiet; witness.state names zempty=match. The probe of the decoy
# way (duress passphrase at the loader: zempty comes up, zroot and zdata
# stay closed, the guard leaves the root and the swap, a session leaves
# nothing) is the Anchor list's §6.2; after it the owner object is dead:
# slot 1, tpm-seal's short form, quiet.
