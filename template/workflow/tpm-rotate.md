# tpm-rotate -- every boot secret anew: the TPM's key files, the sealed objects, slot 0 of every provider, the witness anchor, then relearn and the chain starts anew

# When: the key exchange (T1.4), or a suspicion that a secret left the
# machine. Nothing here changes the loader; the record chain starts anew
# once (the GELI user key changes), PcrBank and the TPM key digest relearn.
# Before the first line: the recovery slot on paper is checked (geli
# attach -k with slot 1 opens zroot and zdata -- the way back when a step
# below goes wrong); the new secrets exist in the owner's seed (hkdf-tree:
# a new version of every entry named below, the inventory committed and
# copied to the machine); the owner, duress and rescue passphrases are
# chosen. Replace daily-v1, the medium letter and the entry names with yours.

# --- 1. the RAM disk, the new secrets, the TPM's password ---
elebake ram open
gpg --decrypt ~/.local/share/hkdf-tree/seed.gpg | hkdf-tree show --config ~/.config/hkdf-tree/inventory.yaml --entry enk-ode/illyria/tpm-reflected-v2 | base64 -d > ~/.elebake/db/.ram/secret.bin
gpg --decrypt ~/.local/share/hkdf-tree/seed.gpg | hkdf-tree show --config ~/.config/hkdf-tree/inventory.yaml --entry enk-ode/illyria/zempty-tpm-v2 | base64 -d > ~/.elebake/db/.ram/zempty.bin
gpg --decrypt ~/.local/share/hkdf-tree/seed.gpg | hkdf-tree show --config ~/.config/hkdf-tree/inventory.yaml --entry enk-ode/illyria/tpm-hierarchy-v1 | base64 -d | hexdump -ve '1/1 "%02x"' > ~/.elebake/db/.ram/auth-hierarchy.hex

# --- 2. the TPM: the old objects and indices out, the new in ---
elebake stage tpm status daily-v1                  # what stands: the handles, the indices, the counters (pinCount: how often the decoy opened)
elebake stage tpm duress reset daily-v1            # pinCount 0, pinLimit back
sudo tpm2_evictcontrol --hierarchy=o --object-context=0x81010001 --hierarchy-auth="hex:$(cat ~/.elebake/db/.ram/auth-hierarchy.hex)"   # the owner object (loader.trust.tpm.keyfile.handles)
sudo tpm2_evictcontrol --hierarchy=o --object-context=0x81010002 --hierarchy-auth="hex:$(cat ~/.elebake/db/.ram/auth-hierarchy.hex)"   # the duress object
sudo tpm2_nvundefine 0x01c10e26 --hierarchy=o --hierarchy-auth="hex:$(cat ~/.elebake/db/.ram/auth-hierarchy.hex)"                    # the witness anchor: its auth value is the owner's passphrase, which changes
elebake stage tpm key daily-v1                     # the storage key anew; prints its name's digest -- the two lines take it:
elebake stage baseline drop daily-v1 LOADER_TRUST_TPM_KEY_DIGEST
elebake stage baseline add daily-v1 LOADER_TRUST_TPM_KEY_DIGEST digest <the sha256 stage tpm key printed>
elebake stage tpm duress daily-v1                  # the new duress passphrase into the PIN index (hidden, twice)
elebake stage kenv drop daily-v1 loader.trust.tpm.duress.count.sealed
elebake stage tpm duress count daily-v1            # the second counter's stand anew ...
elebake stage tpm duress count record daily-v1     # ... recorded
elebake stage tpm seal read daily-v1 duress
elebake stage tpm policy daily-v1
elebake stage tpm seal daily-v1 owner ~/.elebake/db/.ram/secret.bin    # the new owner passphrase (hidden, twice)
elebake stage tpm seal daily-v1 duress ~/.elebake/db/.ram/zempty.bin
elebake stage tpm probe daily-v1 owner ~/.elebake/db/.ram/secret.bin
elebake stage tpm probe daily-v1 duress ~/.elebake/db/.ram/zempty.bin

# --- 3. the disks: slot 0 of every provider with the new three factors ---
# The medium's key file anew (the stage's boot tree carries it: a new
# boot/keys/zroot.key from the seed, then stage include signs it into the
# manifest), the TPM's new file, the new passphrase; slot 1 stays the
# recovery and is NOT touched here (its rotation is paper: geli setkey -n 1).
# the new passphrase into a file on the RAM disk, typed hidden (by hand, no echo):
#   stty -echo; printf 'new GELI passphrase: '; IFS= read -r pw; stty echo; echo; printf '%s' "$pw" > ~/.elebake/db/.ram/auth.txt; unset pw
sudo geli setkey -n 0 -J ~/.elebake/db/.ram/auth.txt -K ~/.elebake/db/stage/daily-v1/boot/keys/zroot.key -K ~/.elebake/db/.ram/secret.bin nda2p1
sudo geli setkey -n 0 -J ~/.elebake/db/.ram/auth.txt -K ~/.elebake/db/stage/daily-v1/boot/keys/zroot.key -K ~/.elebake/db/.ram/secret.bin nda0p1
sudo geli setkey -n 0 -P -K ~/.elebake/db/.ram/zempty.bin nda1p1      # the decoy root: the TPM's file alone (the duress way)
elebake stage tpm clean
elebake ram close

# --- 4. the boot tree, the witnesses' anchor, the medium ---
elebake stage witness measure daily-v1             # the headers moved on zempty (setkey): its receipt anew
elebake stage witness conf daily-v1
elebake ram open
elebake stage witness anchor daily-v1              # the index anew under the new passphrase
elebake ram close
elebake stage site mk daily-v1                     # GeliHeaders: the metadata of zroot, zdata, zempty moved
elebake stage loaderconf mk daily-v1
elebake stage make daily-v1
elebake stage earlboot mk daily-v1 && elebake stage earlboot install daily-v1
elebake stage elvbootd mk daily-v1 && elebake stage elvbootd install daily-v1
elebake stage push daily-v1 a
# Boot (a): the new passphrase, the boot answer once more and confirmed
# (a new chain starts), PcrBank falls (new loader); the rest reads as the
# first boot of a chain (RecordValid, CounterStep, ChainOnMedium,
# LastBootGap, StorageGap, ClockOrder, AnchorValid, the tells) -- once.
# Then pcr-learn, boot: quiet. Then the other card:
elebake stage push daily-v1 b
# Boot (b): ChainOnMedium and MediumSwitch once (the card switch). The
# paper: the new recovery passphrase of slot 1 when it was rotated, the
# witness receipts (elvboot witness daily-v1), the new DB baseline (export,
# bundle). The old secrets' entries in the inventory: retired, never deleted.
