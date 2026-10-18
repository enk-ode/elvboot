# duress-reseal -- after a duress boot, the probe or the real thing: the owner's object is dead, the recovery slot is the way back, then the seal anew, the halt, the rescue, the witnesses

# When: a boot took the duress passphrase (object 2 opened the decoy root
# and stepped the second counter), or earlboot's coercion class raised the
# counter (workflow duress-bind). Before the probe: the recovery passphrase
# of every disk on paper, checked -- after the probe it is the only way in.
#
# The probe boot itself: the duress passphrase at the GELI prompt, the boot
# answer asked as a dummy, no further question, no GELI prompt at the
# kernel's console, the decoy root up with the show user's login; uname,
# the root read-only on the decoy pool, the production pools absent,
# securelevel as the quarantine's rc says. Power off.
#
# The boot after it, with the owner's passphrase: TpmKeyfile falls
# (unsealed=0, duress.count=<sealed+1>/<sealed>, TPM_RC 0x9a2 -- the
# PolicyNV over the counter), the dialog shows the fallen claims of the
# earlier gates, and the disks open from the recovery slot alone (GeliSlot
# slot1). One try with the owner's passphrase shows the object dead; three
# passphrases at the GELI prompt are three: the loader halts, the halt
# counter steps (HaltQuiet on the next boot). The record's key is derived
# from the GELI user key, and slot 1's differs from slot 0's: the chain
# starts anew (record present,invalid with a new ikm, counter=1), so
# recordlock falls as a whole once -- RecordValid, CounterStep,
# ChainOnMedium, LastBootGap, StorageGap, ClockOrder, AnchorValid -- with
# the tells of a restarted chain (MediumSwitch, UnsafeStep,
# FirmwareBootStep, FirmwareMoved). The decoy boot imported its pool and
# wrote its labels: WitnessLabels, zempty differ -- the witness saw the
# decoy boot, as it should.

kenv | grep -i "recordlock.failed\|tpm.keyfile\|geli.slot\|witness.state\|halt.count"   # the picture above, nothing else

elvboot freeze daily-v1                           # the identity tells froze the stage (WitnessLabels, HaltQuiet, GeliSlot): read ...
elvboot freeze ack daily-v1                       # ... and acknowledge, or stage tpm seal and stage push refuse

# The seal anew, the short form of tpm-seal: the storage key, the record
# counter, the halt index and the time anchor stand. The duress index back
# to pinCount 0, the second counter's new value recorded and sealed into
# the owner's policy, both objects anew, both probes. The owner's
# passphrase is the one slot 0 was set with (geli setkey -J): a new one
# would open the object and leave the disks closed.
elebake ram open
gpg --decrypt ~/.local/share/hkdf-tree/seed.gpg | hkdf-tree show --config ~/.config/hkdf-tree/inventory.yaml --entry enk-ode/illyria/tpm-reflected-v1 | base64 -d > ~/.elebake/db/.ram/secret.bin
gpg --decrypt ~/.local/share/hkdf-tree/seed.gpg | hkdf-tree show --config ~/.config/hkdf-tree/inventory.yaml --entry enk-ode/illyria/zempty-tpm-v1 | base64 -d > ~/.elebake/db/.ram/zempty.bin
gpg --decrypt ~/.local/share/hkdf-tree/seed.gpg | hkdf-tree show --config ~/.config/hkdf-tree/inventory.yaml --entry enk-ode/illyria/tpm-hierarchy-v1 | base64 -d | hexdump -ve '1/1 "%02x"' > ~/.elebake/db/.ram/auth-hierarchy.hex
elebake stage tpm duress reset daily-v1
elebake stage kenv drop daily-v1 loader.trust.tpm.duress.count.sealed
elebake stage tpm duress count daily-v1
elebake stage tpm duress count record daily-v1
elebake stage tpm seal read daily-v1 duress
elebake stage tpm policy daily-v1
elebake stage tpm seal daily-v1 owner ~/.elebake/db/.ram/secret.bin
elebake stage tpm seal daily-v1 duress ~/.elebake/db/.ram/zempty.bin
elebake stage tpm probe daily-v1 owner ~/.elebake/db/.ram/secret.bin
elebake stage tpm probe daily-v1 duress ~/.elebake/db/.ram/zempty.bin
elebake stage tpm clean

# The halt, when the loader halted (workflow halt-relearn):
elebake stage kenv drop daily-v1 loader.trust.recordlock.halt.expected
elebake stage kenv learn daily-v1 loader.trust.recordlock.halt.expected loader.trust.recordlock.halt.sha256

# The rescue carries the database: the records above into its image
# (workflow rescue-refresh, the tools unchanged), the RAM disk still open
# for the rescue passphrase. Every push moves the card's labels, so the
# witnesses come after it, card by card -- the receipts of the final state
# can never be inside the image, the production's database and the paper
# hold them.
elebake export redacted ~/.elebake/db/.resource/elvboot/dump.sh ~/.elebake/db/.resource/elvboot/bundle.tar.gz
elebake stage rescue dataset open daily-v1
elebake stage rescue package build daily-v1
elebake stage rescue build daily-v1
elebake stage rescue baseline daily-v1            # the token's PIN at the very end of the build: when pinentry timed out, this signs alone
elebake stage rescue dataset close daily-v1
elebake stage rescue snapshot daily-v1
elebake stage rescue passphrase daily-v1
elebake stage rescue push daily-v1 b              # card b in the slot
elebake stage rescue verify daily-v1 b
elebake stage witness measure daily-v1            # zcard-b, and zempty: its receipt after the decoy boot
elebake stage witness measure full daily-v1
elebake stage rescue push daily-v1 a              # card a in the slot
elebake stage rescue verify daily-v1 a
elebake stage witness measure daily-v1
elebake stage witness measure full daily-v1
elebake stage witness conf daily-v1
gpg --decrypt ~/.local/share/hkdf-tree/seed.gpg | hkdf-tree show --config ~/.config/hkdf-tree/inventory.yaml --entry enk-ode/illyria/tpm-hierarchy-v1 | base64 -d | hexdump -ve '1/1 "%02x"' > ~/.elebake/db/.ram/auth-hierarchy.hex   # stage tpm clean took the file with the auth hashes: once more for the anchor
elebake stage witness anchor daily-v1
elebake ram close
elebake stage witness show daily-v1               # the receipt lines: paper and the public commit

elebake stage loaderconf mk daily-v1
elebake stage include daily-v1
elebake stage push daily-v1 a                     # the conf is in the signed manifest, no rebuild
# Boot a with the owner's passphrase: TpmKeyfile passes (slot 0), HaltQuiet
# passes, the witnesses and the anchor match -- and the chain starts anew
# once more, back to slot 0's key: recordlock falls as before, the unlock
# passphrase is asked once. The boot after that is silent. Then the other
# card:
elebake stage push daily-v1 b
# Boot b: ChainOnMedium and MediumSwitch of the card change, nothing else.
