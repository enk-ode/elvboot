# witness-learn -- the integrity witnesses of zcard and zempty: record, measure, build the loader with the baseline, bind the claims, keep the hash outside

# When: after a rollout of the rescue card or of the quarantine container
# (a new image pushed, zempty filled anew). A witness is a GELI container the
# loader reads but never opens: the hash of its four ZFS vdev labels and its
# GELI metadata sector in the ciphertext changes with every transaction group
# written into it -- so it says whether anything was written since the
# rollout, without a key. Prerequisite: after the rollout the pool is never
# imported read-write again (the probe below shows whether a rescue boot
# does; until the import is read-only the witness of the card is worthless).
elebake stage witness add daily-v1 zcard-b da1p3                # the card b; card a in the slot: zcard-a da1p3 -- its own witness, told apart by the medium of its first receipt (the sha256 of its GELI metadata sector: the cards are dd clones with one GPT uuid), measure and check skip the card that is not in the slot
elebake stage witness add daily-v1 zempty nda1p1
elebake stage witness measure daily-v1                           # root: per witness the labels receipt (UTC, uuid, medium, digest) and the table receipt (<name>.gpt: the GPT of its disk), the containers closed
elebake stage witness show daily-v1                              # the receipt lines: on paper beside the rescue passphrase, and into the public commit (the one witness outside the machine)
elebake expectation add witness-labels byte WitnessLabels 1
elebake expectation add witness-present byte WitnessPresent 1
elebake claim add witness-labels measure_witness_labels diagnose_witness witness.state witness-labels
elebake claim add witness-present measure_witness_present - - witness-present
elebake gate claim add inventory witness-labels                  # the labels of every witness present match their receipts
elebake expectation add witness-tables byte WitnessTables 1
elebake claim add witness-tables measure_witness_tables diagnose_witness_tables witness.tables witness-tables
elebake gate claim add inventory witness-tables                  # the partition table of every present witness's disk matches its .gpt receipt (the cards differ in size: each its own witness, not a term in PartitionTables)
elebake stage kenv add daily-v1 loader.trust.inventory.witness.slot zcard-a,zcard-b   # the witnesses that share one slot
elebake expectation add witness-slot byte WitnessSlot 1
elebake claim add witness-slot measure_witness_slot - - witness-slot
elebake gate claim add inventory witness-slot                    # at least one card the conf knows is in the slot
# WitnessPresent (every listed witness present) stays unbound while one slot serves two cards: one is always absent, and the absent card is its own state -- witness.state names it. Bind it on a machine with a slot per card.
elebake stage make daily-v1                                      # the claims into the loader, once
elebake stage earlboot mk daily-v1 && elebake stage earlboot install daily-v1    # the hooks carry the loader's digest: after every make
elebake stage elvbootd mk daily-v1 && elebake stage elvbootd install daily-v1
elebake stage witness conf daily-v1                              # the receipts as kenv records: loader.trust.inventory.witnesses, .witness.<name>.guid/medium/digest
elebake stage loaderconf mk daily-v1
elebake stage include daily-v1
elebake stage push daily-v1 b
# The third witness, the anchor in the TPM: an NV index holds sha256 over
# the table "<name>:<medium>:<digest>" of the conf, written by the owner
# under PolicyPCR of the production AND the owner's passphrase (the index's
# auth value) -- root on the running machine cannot move it, a conf
# rewritten on a medium by whoever holds the signing key carries a table the
# index does not. The loader reads it (WitnessAnchor: match, differ; absent
# without TPM, index or witnesses -- a rescue on another board never fails
# here), elvbootd reads it again at STARTUP (witness_anchor_act). Once:
elebake stage kenv add daily-v1 loader.trust.tpm.witness.nv 0x01c10e26
elebake expectation add witness-anchor byte WitnessAnchor 1
elebake claim add witness-anchor measure_witness_anchor diagnose_witness_anchor witness.anchor witness-anchor
elebake gate claim add inventory witness-anchor                  # the claim into the loader: stage make once more (foundation.c), then the hooks
elebake trigger add witness-anchor-always when_always witness_anchor_act
elebake policy trigger add runtime-watch witness-anchor-always
# After every stage witness conf (a rollout moved a receipt): the anchor
# anew -- root, the RAM disk open, the owner's passphrase typed hidden.
elebake ram open
elebake stage witness anchor daily-v1
elebake ram close
elebake stage witness show daily-v1                              # the anchor line (UTC, digest) beside the receipts
# Boot: WitnessLabels passes; the kenv leaf
# loader.trust.inventory.witness.state names each witness with match, differ
# or absent. PcrBank falls once (new loader): pcr-learn.
# Every later rollout of a card (a rescue push moves its labels) is:
#   stage witness measure, stage witness conf, stage loaderconf mk, stage
#   include, stage push -- the conf is in the signed manifest, no rebuild.
# Probe (once per card, before trusting the card's witness): boot the rescue
# from the card, come back, compare -- a CHANGED card means the rescue boot
# imported the pool read-write.
elebake stage witness check daily-v1
# The whole-card receipt (minutes per card: the entire disk is read): GPT,
# every partition and the free space after the last one -- a byte written
# anywhere on the card since the rollout, inside or outside the containers,
# shows here. The loader never reads it; the report and the owner on
# suspicion do. Take it with the labels at every rollout.
elebake stage witness measure full daily-v1
elebake stage witness check full daily-v1
