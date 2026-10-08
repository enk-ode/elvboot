# tpm-seal -- the TPM's key files: storage key, the duress index, the second counter, two policies, two objects, the counters, the probes

# When: first provisioning of the device factor, a reseal after a
# firmware update (PCR 0, 2 or 7 moved: the TPM keeps the old objects
# closed; boot with the disk's recovery slot, then reseal), or after a
# duress event: then NOT the whole list -- the storage key, the index, the
# counters and the anchors stand; run stage tpm duress reset (pinCount 0),
# stage kenv drop <stage> loader.trust.tpm.duress.count.sealed (the record
# is immutable), stage tpm duress count and count record (the counter's
# new value), stage tpm seal read <stage> duress (the passphrase for the
# trial PolicySecret), stage tpm policy, seal owner, seal duress, the two
# probes, clean; then loaderconf mk, include, push -- no rebuild. The
# record chain starts anew once (the GELI user key changed). The stage's leafs say
# what the loader expects (stage require). Everything on the RAM disk; the
# two secrets and the TPM's owner password come from the owner's seed
# (hkdf-tree), the secrets' paths are the arguments, the password is
# auth-hierarchy.hex on the RAM disk; the passphrases are typed hidden,
# twice. The owner's secret
# is the production root's key file; the duress secret is the decoy
# root's key file (the loader's way into the decoy root, whether the
# duress passphrase opened it or the second counter had closed the
# owner's object after a boot answer of the coercion class).

elebake ram open                                  # the RAM disk under the database (.ram)
gpg --decrypt ~/.local/share/hkdf-tree/seed.gpg | hkdf-tree show --config ~/.config/hkdf-tree/inventory.yaml --entry enk-ode/illyria/tpm-reflected-v1 | base64 -d > ~/.elebake/db/.ram/secret.bin
gpg --decrypt ~/.local/share/hkdf-tree/seed.gpg | hkdf-tree show --config ~/.config/hkdf-tree/inventory.yaml --entry enk-ode/illyria/zempty-tpm-v1 | base64 -d > ~/.elebake/db/.ram/zempty.bin
gpg --decrypt ~/.local/share/hkdf-tree/seed.gpg | hkdf-tree show --config ~/.config/hkdf-tree/inventory.yaml --entry enk-ode/illyria/tpm-hierarchy-v1 | base64 -d | hexdump -ve '1/1 "%02x"' > ~/.elebake/db/.ram/auth-hierarchy.hex

elebake stage tpm hierarchy                       # ONCE, on a TPM whose owner and lockout password are empty: from then on every act below passes the file (a TPM that has the password: skip this line, keep the file)
elebake stage require daily-v1                    # the TPM leafs with values: key.handle, keyfile.handles, keyfile.pcrs, counter.nv, duress.nv, duress.count.nv, decoy.providers, decoy.root (duress.count.sealed comes below)
elebake stage tpm key daily-v1                    # the storage key, persistent; prints its name's digest
elebake stage tpm duress daily-v1                 # the duress passphrase (hidden, twice), the PIN_PASS index: pinCount 0, pinLimit 0xffffffff (counts, never spends)
elebake stage tpm duress count daily-v1           # the second counter, defined and incremented once; its value -> ~/.elebake/db/.ram/count-sealed.hex
elebake stage tpm duress count record daily-v1    # ... recorded as loader.trust.tpm.duress.count.sealed
elebake stage tpm policy daily-v1                 # owner.policy (PCR, auth value, counter == sealed -- read through the index), duress.policy (PolicySecret, PCR); pinCount back to 0
elebake stage tpm seal daily-v1 owner ~/.elebake/db/.ram/secret.bin     # the owner's passphrase (hidden, twice), object 1: the production root's key file
elebake stage tpm seal daily-v1 duress ~/.elebake/db/.ram/zempty.bin    # object 2, no auth value: the decoy root's key file
elebake stage tpm counter daily-v1                # the increment-only indices: counter.nv (object 2 opened), halt.nv (a shutdown earlboot fired); defined, then incremented once (uninitialized reads fail)
elebake stage tpm anchor daily-v1                 # the time anchor and the shutdown index under the two states of the cap PCR (workflow time-anchor)
elebake stage tpm probe daily-v1 owner ~/.elebake/db/.ram/secret.bin    # unseal-owner-ok
elebake stage tpm probe daily-v1 duress ~/.elebake/db/.ram/zempty.bin   # unseal-duress-ok, then pinCount back to 0 (the probe counted)
elebake stage tpm clean                           # the auth hashes, policies and contexts wiped
elebake ram close
elebake stage tpm status daily-v1                 # the persistent handles, the indices and the counters, as the TPM has them

# Then the disks. The production root: slot 0 of every provider takes the
# medium's key file and the TPM's, and no passphrase (the TPM judges the
# passphrase):
#   geli setkey -n 0 -P -K <boot tree>/keys/zroot.key -K tpm.bin nda0p1
# (tpm.bin = the unsealed bytes, on the RAM disk, from the probe). The
# decoy root (workflow quarantine): slot 0 of nda1p1 takes the TPM's file
# alone:
#   geli init -b -P -K zempty.bin -a HMAC/SHA256 -e AES-XTS -l 256 -s 4096 nda1p1
# Then loaderconf mk (the new leaf duress.count.sealed rides on the medium),
# rebuild with keyfile.providers and decoy.providers set, boot; after the
# first boot learn LOADER_TRUST_TPM_KEY_DIGEST from loader.trust.tpm.key.sha256
# (baseline-relearn), then pcr-learn. The record chain starts anew once
# (the GELI user key changed). The runtime side of the second counter is
# the workflow duress-bind.
