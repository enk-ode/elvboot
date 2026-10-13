# card-grow -- the rescue partition to the end of the card: no unallocated space left for a planted file

# When: a card carries free space after its rescue partition (gpart show
# da1: the "- free -" line at the end). An attacker with the card writes
# there with dd and nothing witnesses it; a partition that ends with the
# card leaves no such place, and the whole-card receipt (witness-learn)
# covers the card anyway. The resize rewrites the GELI metadata (the
# provider size is in it): the witness medium of that card changes -- drop
# and add the witness afterwards, measure again. The pool is imported
# read-write once, here: measure the labels again afterwards.
# Replace the medium letter and the partition with yours; the card in the slot.
sudo gpart show da1                                          # the free space at the end, and the index of the rescue partition (3)
sudo gpart resize -i 3 da1                                # the partition to the end of the card
sudo geli resize -s $(( 50331648 * 512 )) da1p3           # BEFORE the attach: the OLD provider size in bytes (sectors from the gpart line above x 512); geli reads its metadata at the old last sector and writes it at the new one -- an attach before this finds no metadata
elebake stage rescue passphrase daily-v1
elebake stage rescue card open daily-v1 b                 # geli attach with the passphrase and the key file, the pool imported
sudo zpool online -e zcard da1p3.eli                      # the pool grows into the partition
elebake stage rescue card close daily-v1 b
elebake ram close
elebake stage witness drop daily-v1 zcard-b
elebake stage witness add daily-v1 zcard-b da1p3
elebake stage witness measure daily-v1
elebake stage witness measure full daily-v1
elebake stage witness conf daily-v1
elebake stage loaderconf mk daily-v1
elebake stage include daily-v1
elebake stage push daily-v1 b
# Boot: silent. Then the other card the same way.
