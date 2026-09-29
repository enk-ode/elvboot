# rescue-build -- the rescue system: a dataset on the production pool, described in the stage, sent to every card

# When: first provisioning of the rescue system, or a rebuild from the
# description on a second machine. The rescue root is a ZFS dataset tree
# (<dataset>/ROOT/default, mountpoint /, canmount noauto) on the production
# pool: built here, edited here, snapshotted here, and sent to a GELI
# partition of every boot medium (the card) by zfs send. The database does
# not travel as a copy but as its signed export pair, placed under
# /root/elvboot/<serial>/ of the rescue root, so the rescue system rebuilds
# it into an empty database (workflow restore). The stage records the
# description only: dataset, pool, tools, mirrored paths, the cards; what a
# card holds is read from the card. Replace daily-v1, the medium letter and
# the partition with yours.

elebake stage rescue dataset add daily-v1 zroot/rescue      # the source tree
elebake stage rescue pool add daily-v1 zcard                # the pool every card carries
elebake stage rescue card add daily-v1 b da1p3              # the medium's rescue partition (stage device b first)
elebake stage rescue tools add daily-v1 tpm2-tools          # what the rescue system carries beyond base
elebake stage rescue tools add daily-v1 gnupg
elebake stage rescue tools add daily-v1 git
elebake stage rescue config add daily-v1 /etc/wpa_supplicant.conf      # mirrored as it is
elebake stage rescue config add daily-v1 /root/.local/share/hkdf-tree/seed.gpg   # encrypted; its passphrase is not the rescue passphrase
elebake stage rescue show daily-v1

elebake stage rescue dataset make daily-v1                  # zfs create, three datasets
elebake stage rescue dataset open daily-v1                  # mounted for editing under $ELEBAKE_ROOT/mnt/daily-v1-rescue
elebake stage rescue base install daily-v1                  # FreeBSD-set-base and the generic kernel (the rescue boots on its own)
elebake stage rescue tools install daily-v1
elebake stage rescue config mirror daily-v1
sudo mount -t tmpfs -o size=64m tmpfs /tmp/ram && sudo chown $(id -un) /tmp/ram
elebake stage rescue database describe daily-v1             # export full into /root/elvboot/<serial>/ of the rescue root
elebake stage rescue dataset close daily-v1
elebake stage rescue snapshot daily-v1                      # <dataset>@daily-v1-<stamp>, recorded

elebake stage rescue passphrase daily-v1                    # the rescue passphrase (hidden, twice) -> /tmp/ram/auth-rescue.txt
elebake stage rescue card init daily-v1 b                   # ONCE per card: geli, zeros, pool, exported (minutes)
elebake stage rescue push daily-v1 b                        # the whole tree the first time, verified by snapshot GUID
elebake stage rescue verify daily-v1 b
rm -P /tmp/ram/auth-rescue.txt && cd / && sudo umount /tmp/ram
elebake stage rescue status daily-v1

# The second card: stage rescue card add daily-v1 a da1p3, card init a, push a.
# After a change to the rescue root: workflow rescue-refresh. What the
# rescue boot needs from the loader (the leaf naming the rescue root, the
# deliberate divert) is the loader's side and stays in its own workflow.
