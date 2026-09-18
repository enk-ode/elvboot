# inventory-drop -- a member of a learned set moves between boots: take it out, relearn the set's digest

# When: an inventory claim (LoadedImages, AcpiTables, EfiVariables, PciDevices)
# fell and the records show one member with a changing digest -- a
# firmware volume whose data section moves, a volatile ACPI table. The
# set is what the owner took in; a moving member leaves it. The set's
# digest is a compiled baseline, so the drop is followed by
# baseline-relearn and a PCR round.

elebake stage inventory import daily-v1           # the loader's records of the last boots into the stage
elebake stage inventory show daily-v1 images | grep " + " | grep -v same   # the members that moved (id, digests per boot)
elebake stage inventory drop daily-v1 images fv/5f59b483                    # one item out of the set
elebake stage site mk daily-v1                    # the set without it
elebake stage make daily-v1
elebake stage earlboot mk daily-v1 && elebake stage earlboot install daily-v1
elebake stage elvbootd mk daily-v1 && elebake stage elvbootd install daily-v1
elebake stage push daily-v1 b

# Boot: the claim still fails -- against the OLD digest baseline. This
# boot publishes the new one; continue with baseline-relearn for
# LOADER_TRUST_IMAGES_DIGEST (loader.trust.inventory.images.sha256), then
# pcr-learn. Two more boots.
