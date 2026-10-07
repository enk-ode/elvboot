# rescue-build -- the rescue system: a boot environment on the production pool, described by a meta package, built in phases, sent to every card

# When: first provisioning of the rescue system, or a rebuild from the
# description on a second machine. The rescue root is ONE dataset on the
# production pool (zroot/ROOT/rescue: mountpoint /, canmount noauto -- a boot
# environment bectl sees), built here in phases by 'stage rescue build'
# (package install, config mirror, local write, user mirror, transient
# write, patch apply, baseline), snapshotted here, and sent to a GELI
# partition of every boot medium (the card) by zfs send. The rescue is
# FINISHED, not a kit: the databases are built INTO the image by the
# recorded patches -- a patch is a script, a user and a resource directory
# $ELEBAKE_BASE/.resource/<name>/ the owner fills beforehand (here: the
# export pair of each database and the signer's public key); the patches
# run INSIDE the root (a one-shot jail on it, the resources hung in
# read-only), the shipped patch scripts call the IMAGE's own tool as the
# user, and import makes the database when there is none. The stage records the description
# only; the repository is built, what a card holds is read from the card.
# Replace daily-v1, the medium letter, the paths and the names with yours.

elebake stage rescue dataset add daily-v1 zroot/ROOT/rescue   # the rescue root, a boot environment
elebake stage rescue pool add daily-v1 zcard                  # the pool every card carries
elebake stage rescue package add daily-v1 illyria-rescue      # the meta package that describes the system
elebake stage rescue keyfile add daily-v1 /boot/keys/zroot.key   # the cards open with the passphrase AND this
elebake stage rescue source add daily-v1 elvboot /home/brj/git/elvboot        # 'make package' there
elebake stage rescue source add daily-v1 vpn-switch /home/brj/git/vpn-switch
elebake stage rescue tools add daily-v1 elvboot               # the dependencies of the meta package ...
elebake stage rescue tools add daily-v1 vpn-switch
elebake stage rescue tools add daily-v1 tpm2-tools            # ... one package per line (pkg prime-list is a start)
elebake stage rescue tools add daily-v1 gnupg
elebake stage rescue tools add daily-v1 xorg-server
elebake stage rescue tools add daily-v1 wmx
elebake stage rescue config add daily-v1 /etc/rc.conf         # the network 1:1 ...
elebake stage rescue config add daily-v1 /etc/pf.conf
elebake stage rescue config add daily-v1 /etc/wpa_supplicant.conf
elebake stage rescue config add daily-v1 /var/unbound
elebake stage rescue config add daily-v1 /etc/ssh             # ... the host keys too: the same identity. NEVER seed.gpg: the card carries revocable secrets only, the seed stays on zroot
elebake stage rescue config add daily-v1 /usr/local/etc/cups
elebake stage rescue local add daily-v1 'sshd_enable="NO"'    # what the rescue keeps different (rc.conf.local)
elebake stage rescue user add daily-v1 brj                    # read from this machine's passwd; the hash follows at mirror
elebake stage rescue user add daily-v1 root                   # root's password only
elebake stage rescue transient add daily-v1 /home             # the rescue is transient: these get a memory layer at boot ...
elebake stage rescue transient add daily-v1 /etc
elebake stage rescue transient add daily-v1 /var              # ... (rc.d rescue_union, tmpmfs; the root itself is read-only on the card)
elebake stage rescue patch add daily-v1 elvboot /usr/local/lib/elebake/template/rescue/elvboot-import-db-patch.sh brj           # the databases, built into the image as brj by the image's own tools (the script paths are paths IN the image: the template tree of each tool's package) ...
elebake stage rescue patch add daily-v1 vpn-switch /usr/local/lib/vpn-switch/template/rescue/vpn-switch-import-db-patch.sh brj  # ... from the pairs under ~/.elebake/db/.resource/<name>/
elebake stage rescue card add daily-v1 b da1p3                # the medium's rescue partition (stage device b first)
elebake stage rescue show daily-v1

elebake export redacted ~/.elebake/db/.resource/elvboot/dump.sh ~/.elebake/db/.resource/elvboot/bundle.tar.gz        # the pair the elvboot patch takes (redacted: no marker values, no site.mk baselines -- the rescue learns them on the machine)
vpn-switch export full ~/.elebake/db/.resource/vpn-switch/dump.sh ~/.elebake/db/.resource/vpn-switch/bundle.tar.gz   # the pair the vpn-switch patch takes (full: the configurations travel)
gpg --export --armor 0123456789ABCDEF > ~/.elebake/db/.resource/elvboot/signer.asc                                 # the signer's PUBLIC key: the scripts seed the user's keyring in the image with it ...
gpg --export --armor 0123456789ABCDEF > ~/.elebake/db/.resource/vpn-switch/signer.asc                              # ... (the image has no keyring of yours; the rescue keeps the public key)
elebake stage rescue dataset make daily-v1                    # zfs create, one dataset
elebake stage rescue dataset open daily-v1                    # mounted for editing under $ELEBAKE_ROOT/mnt/daily-v1-rescue
elebake stage rescue tool package daily-v1 elvboot            # the two tools as packages into the stage's repository
elebake stage rescue tool package daily-v1 vpn-switch
elebake stage rescue package build daily-v1                   # +MANIFEST rendered, pkg create, pkg repo
elebake stage rescue build daily-v1                           # package install, config mirror, local write, user mirror, transient write, patch apply, baseline (minutes; the baseline signs)
elebake stage rescue dataset close daily-v1
elebake stage rescue snapshot daily-v1                        # <dataset>@daily-v1-<stamp>, recorded -- the image the baseline describes

sudo mount -t tmpfs -o size=64m tmpfs /tmp/ram && sudo chown $(id -un) /tmp/ram
elebake stage rescue passphrase daily-v1                      # the rescue passphrase (hidden, twice) -> /tmp/ram/auth-rescue.txt
elebake stage rescue card init daily-v1 b                     # ONCE per card: geli (passphrase + key file), zeros, pool with ROOT, exported (minutes)
elebake stage rescue push daily-v1 b                          # the whole root the first time, bootfs set, root read-only, verified by snapshot GUID
elebake stage rescue verify daily-v1 b                        # GUID, read-only, and the tree against the signed baseline (nothing missing, changed or unlisted)
rm -P /tmp/ram/auth-rescue.txt && cd / && sudo umount /tmp/ram
elebake stage rescue status daily-v1

# The second card: stage rescue card add daily-v1 a da1p3, card init a, push a.
# After a change: workflow rescue-refresh. After a rotation of zroot.key:
# stage rescue card rekey daily-v1 <medium> <old key file>. What the rescue
# boot needs from the loader (the leaf naming the rescue root, the deliberate
# divert) is the loader's side and stays in its own workflow.
