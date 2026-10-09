# witness-learn -- the integrity witnesses of zcard and zempty: record, measure, build the loader with the baseline, bind the claims, keep the hash outside

# When: after a rollout of the rescue card or of the quarantine container
# (a new image pushed, zempty filled anew). A witness is a GELI container the
# loader reads but never opens: the hash of its four ZFS vdev labels and its
# GELI metadata sector in the ciphertext changes with every transaction group
# written into it -- so it says whether anything was written since the
# rollout, without a key. Prerequisite: after the rollout the pool is never
# imported read-write again (the probe below shows whether a rescue boot
# does; until the import is read-only the witness of the card is worthless).
elebake stage witness add daily-v1 zcard-b da1p3                # the card b (zcard-a when card a is in the dock: its own GPT uuid, its own receipt)
elebake stage witness add daily-v1 zempty nda1p1
elebake stage witness measure daily-v1                           # root: a receipt per witness (UTC, uuid, digest), the containers closed
elebake stage witness show daily-v1                              # the receipt lines: on paper beside the rescue passphrase, and into the public commit (the one witness outside the machine)
elebake expectation add witness-labels byte WitnessLabels 1
elebake expectation add witness-present byte WitnessPresent 1
elebake claim add witness-labels measure_witness_labels diagnose_witness witness.state witness-labels
elebake claim add witness-present measure_witness_present - - witness-present
elebake gate claim add inventory witness-labels                  # the labels of every witness present match their receipts
elebake gate claim add inventory witness-present                 # every witness is present (a missing card is its own state, not a mismatch)
elebake stage site mk daily-v1                                   # LOADER_TRUST_WITNESS_LABELS from the receipts
elebake stage make daily-v1
elebake stage earlboot mk daily-v1 && elebake stage earlboot install daily-v1    # the hooks carry the loader's digest: after every make
elebake stage elvbootd mk daily-v1 && elebake stage elvbootd install daily-v1
elebake stage push daily-v1 b
# Boot: WitnessLabels and WitnessPresent pass; the kenv leaf
# loader.trust.inventory.witness.state names each witness with match, differ
# or absent. PcrBank falls once (new loader): pcr-learn.
# Probe (once per card, before trusting the card's witness): boot the rescue
# from the card, come back, compare -- a CHANGED card means the rescue boot
# imported the pool read-write.
elebake stage witness check daily-v1
