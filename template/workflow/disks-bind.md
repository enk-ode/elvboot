# disks-bind -- the internal GELI containers and their partition tables as claims: GeliHeaders and PartitionTables

# When: the disks record names the internal GELI partitions (stage disks
# add nda0p1 ...) and site mk has measured them (LOADER_TRUST_GELI_PARTS,
# _GELI_DIGEST, _GPT_DIGEST in site.mk), but no claim judges them yet.
# GeliHeaders is the sha256 over the GELI metadata sector of every listed
# partition: a geli setkey, delkey or re-init on zroot, zdata or zempty
# moves it. PartitionTables is the sha256 over the GPT header and entry
# array of every disk that carries one: a moved, resized, added or
# relabelled partition moves it. Both are compiled baselines (site.mk):
# binding them is a rebuild and a PCR round; a legitimate change (a key
# rotation, a repartitioning) is site mk and the same rebuild.
elebake macro add GELI_DIGEST sha256 GeliHeaders
elebake macro add GPT_DIGEST sha256 PartitionTables
elebake expectation add geli-headers macro - GELI_EXPECTED        # the defined name of the macro record (stem minus _DIGEST plus _EXPECTED)
elebake expectation add partition-tables macro - GPT_EXPECTED
elebake claim add geli-headers measure_geli - - geli-headers
elebake claim add partition-tables measure_gpt - - partition-tables
elebake gate claim add inventory geli-headers
elebake gate claim add inventory partition-tables
elebake stage site mk daily-v1                    # the digests measured now (root for the raw reads: the disks acts are pinned sudo sh)
elebake stage make daily-v1
elebake stage earlboot mk daily-v1 && elebake stage earlboot install daily-v1
elebake stage elvbootd mk daily-v1 && elebake stage elvbootd install daily-v1
elebake stage push daily-v1 b
# Boot: GeliHeaders and PartitionTables pass, PcrBank falls once (new
# loader): pcr-learn. The cards are not in the disks record: the two cards
# differ in size and carry their own tables -- the card is witnessed by
# WitnessLabels, the internal disks by these two.
