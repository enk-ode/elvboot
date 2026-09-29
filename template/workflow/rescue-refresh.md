# rescue-refresh -- the rescue root changed (a tool, a mirrored file, a new export pair): snapshot, send the increment

# When: after every change to the rescue root -- a package added to the
# tool list, a mirrored path that moved, and always after a change to the
# database (the export pair on the card is the description the rescue
# system restores from: an old pair restores an old database). The card
# receives only what changed since its last receipt (zfs send -I), and the
# snapshot GUID on the card proves the arrival.

elebake stage rescue dataset open daily-v1
elebake stage rescue tools install daily-v1                 # when the tool list changed
elebake stage rescue config mirror daily-v1                 # when a mirrored file changed
sudo mount -t tmpfs -o size=64m tmpfs /tmp/ram && sudo chown $(id -un) /tmp/ram
elebake stage rescue database describe daily-v1             # the current export pair (serial + 1)
elebake stage rescue dataset close daily-v1
elebake stage rescue snapshot daily-v1

elebake stage rescue passphrase daily-v1
elebake stage rescue push daily-v1 b                        # the increment since the card's receipt
elebake stage rescue push daily-v1 a
rm -P /tmp/ram/auth-rescue.txt && cd / && sudo umount /tmp/ram
elebake stage rescue show daily-v1                          # the cards' receipts
