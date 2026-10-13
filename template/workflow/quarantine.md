# quarantine -- the decoy root zempty: a defined content, sealed, snapshotted, witnessed

# When: the first fill of the quarantine container, and every rollout of
# it afterwards (a package set updated). zempty is the root the loader
# diverts to on the duress way: a default installation nobody maintains,
# no sensitive data, no access -- a system that distrusts the chain it
# was booted by (its guard exports every foreign pool, detaches every
# idle GELI provider, unloads tpm.ko before anything else runs). Its
# content is DEFINED: the base set from the owner's package repository,
# no kernel (the medium's, verified, boots it), no boot code on its disk,
# a random root password, no user in wheel, no sshd, securelevel 2 -- the
# playbook's steps; here the elebake side, the seal and the witness.
# Replace daily-v1, the partition and the repository with yours.

# --- 1. the container (once): the TPM's file alone opens it, no passphrase, no paper ---
elebake ram open
gpg --decrypt ~/.local/share/hkdf-tree/seed.gpg | hkdf-tree show --config ~/.config/hkdf-tree/inventory.yaml --entry enk-ode/illyria/zempty-tpm-v1 | base64 -d > ~/.elebake/db/.ram/zempty.bin
sudo geli init -b -P -K ~/.elebake/db/.ram/zempty.bin -e AES-XTS -l 256 -a HMAC/SHA256 -s 4096 -T nda1p1
sudo geli attach -p -k ~/.elebake/db/.ram/zempty.bin nda1p1
sudo dd if=/dev/zero of=/dev/nda1p1.eli bs=1m status=progress       # every sector gets its HMAC (ENOSPC = done)
sudo zpool create -o altroot=/mnt -o ashift=12 -o autotrim=off -O compression=lz4 -O atime=off -O xattr=sa -O dnodesize=auto -O mountpoint=none -O canmount=off zempty /dev/nda1p1.eli
sudo zfs create -o mountpoint=none zempty/ROOT
sudo zfs create -o mountpoint=/ zempty/ROOT/default
sudo zpool set bootfs=zempty/ROOT/default zempty

# --- 2. the content (every rollout): the base set, the configuration without access, the guard ---
sudo mkdir -p /mnt/dev /mnt/usr/share/keys && sudo mount -t devfs devfs /mnt/dev
sudo cp -a /usr/share/keys/pkg /usr/share/keys/pkgbase-15 /mnt/usr/share/keys/
sudo pkg --rootdir /mnt -o REPOS_DIR=/etc/pkg,/usr/local/etc/pkg/repos update -r FreeBSD-base
sudo pkg --rootdir /mnt -o REPOS_DIR=/etc/pkg,/usr/local/etc/pkg/repos install -y -r FreeBSD-base FreeBSD-set-base
# the configuration and the guard rc.d geomcheck: Playbooks/zempty-zettel.md
# steps 5 and 8 (root's password random, no wheel, no sshd, devmatch off,
# kern_securelevel 2; the guard after mountcritlocal and before zpool, kld, zfs)
sudo umount /mnt/dev

# --- 3. the snapshot and the close: from here the pool is never imported read-write again ---
sudo zfs snapshot zempty/ROOT/default@rollout-$(date -u +%Y%m%dT%H%M%SZ)
sudo zfs list -t snapshot -r zempty
sudo zpool export zempty
sudo geli detach nda1p1
elebake ram close

# --- 4. the loader's way to it, the seal, the witness ---
elebake stage kenv add daily-v1 loader.trust.tpm.decoy.providers nda1p1
elebake stage kenv add daily-v1 loader.trust.tpm.decoy.root zfs:zempty/ROOT/default
elebake workflow show tpm-seal                     # the duress object carries zempty.bin: seal, or reseal after a rotation
elebake stage witness add daily-v1 zempty nda1p1   # once; the receipt at every rollout:
elebake stage witness measure daily-v1             # the labels and the table (the uberblock moved with the snapshot: a new receipt)
elebake stage witness measure full daily-v1        # the whole disk, minutes
elebake stage witness conf daily-v1
elebake ram open
elebake stage witness anchor daily-v1              # the table of all witnesses anew into the TPM (the owner's passphrase)
elebake ram close
elebake stage loaderconf mk daily-v1
elebake stage include daily-v1
elebake stage push daily-v1 b
elebake stage witness show daily-v1                # the receipt lines: paper and the public commit
# Boot: quiet; witness.state names zempty=match. The probe of the decoy
# way (duress passphrase at the loader: zempty comes up, zroot and zdata
# stay closed, the guard leaves the root and the swap) is the Anchor
# list's §6.2; after it the owner object is dead: slot 1, tpm-seal's short
# form, quiet.
