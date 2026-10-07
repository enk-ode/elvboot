# rescue-refresh -- the rescue root changed (a tool, a mirrored file, a database): build again, snapshot, send the increment

# When: after every change to the rescue root -- a package added to the
# tool list, a mirrored path that moved, a user, and always after a change
# to a database (the image carries the databases: an old pair in the
# resource directory builds an old database into it). The meta package is
# rebuilt (its version is the next export serial) and 'stage rescue build'
# runs its phases again -- pkg upgrades what changed, the mirrors are
# copied anew, the patches import the current pairs, the baseline is signed
# again; the card receives only what changed since its last receipt (zfs
# send -I), and the snapshot GUID on the card proves the arrival.

elebake export redacted ~/.elebake/db/.resource/elvboot/dump.sh ~/.elebake/db/.resource/elvboot/bundle.tar.gz        # the current pairs (serial + 1) ...
vpn-switch export full ~/.elebake/db/.resource/vpn-switch/dump.sh ~/.elebake/db/.resource/vpn-switch/bundle.tar.gz   # ... the patches import them (signer.asc stays from the build)
elebake stage rescue dataset open daily-v1
elebake stage rescue tool package daily-v1 elvboot            # when a tool's checkout moved on
elebake stage rescue tool package daily-v1 vpn-switch
elebake stage rescue package build daily-v1                   # the meta package of the next serial
elebake stage rescue build daily-v1                           # package install, config mirror, local write, user mirror, transient write, patch apply, baseline
elebake stage rescue dataset close daily-v1
elebake stage rescue snapshot daily-v1

sudo mount -t tmpfs -o size=64m tmpfs /tmp/ram && sudo chown $(id -un) /tmp/ram
elebake stage rescue passphrase daily-v1
elebake stage rescue push daily-v1 b                          # the increment since the card's receipt
elebake stage rescue push daily-v1 a
elebake stage rescue verify daily-v1 b
rm -P /tmp/ram/auth-rescue.txt && cd / && sudo umount /tmp/ram
elebake stage rescue show daily-v1                            # the cards' receipts
