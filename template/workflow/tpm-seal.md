# tpm-seal -- the TPM's key file: storage key, policy, two objects, the counter, the probe

# When: first provisioning of the device factor, or a reseal after a
# firmware update (PCR 0, 2 or 7 moved: the TPM keeps the old objects
# closed; boot with the disk's passphrase slot, then reseal). The stage's
# leafs say what the loader expects (stage require). Everything on the RAM
# disk; the secret comes from the owner's seed (hkdf-tree), its path is
# the argument; the passphrases are typed hidden, twice.

sudo mount -t tmpfs -o size=64m tmpfs /tmp/ram && sudo chown $(id -un) /tmp/ram
gpg --decrypt ~/.local/share/hkdf-tree/seed.gpg | hkdf-tree show --config ~/.config/hkdf-tree/inventory.yaml --entry enk-ode/illyria/tpm-reflected-v1 | base64 -d > /tmp/ram/secret.bin

elebake stage require daily-v1                    # the four TPM leafs with values: key.handle, keyfile.handles, keyfile.pcrs, counter.nv
elebake stage tpm key daily-v1                    # the storage key, persistent; prints its name's digest
elebake stage tpm policy daily-v1                 # PolicyPCR over keyfile.pcrs + PolicyAuthValue -> /tmp/ram/pcrauth.policy
elebake stage tpm seal daily-v1 owner /tmp/ram/secret.bin     # the owner's passphrase (hidden, twice), object 1
elebake stage tpm seal daily-v1 duress /tmp/ram/secret.bin    # the duress passphrase, object 2 -- the same bytes
elebake stage tpm counter daily-v1                # the increment-only indices: counter.nv (object 2 opened), halt.nv (a shutdown earlboot fired); defined, then
elebake stage tpm anchor daily-v1                 # the time anchor and the shutdown index under the two states of the cap PCR (workflow time-anchor) incremented once (uninitialized reads fail)
elebake stage tpm probe daily-v1 owner /tmp/ram/secret.bin    # unseal-owner-ok
elebake stage tpm probe daily-v1 duress /tmp/ram/secret.bin   # unseal-duress-ok
elebake stage tpm clean                           # the auth hashes and contexts wiped
rm -P /tmp/ram/secret.bin && cd / && sudo umount /tmp/ram
elebake stage tpm status daily-v1                 # the persistent handles and the counter, as the TPM has them

# Then the disk: slot 0 of every provider takes the medium's key file and
# the TPM's, and no passphrase (the TPM judges the passphrase):
#   geli setkey -n 0 -P -K <boot tree>/keys/zroot.key -K tpm.bin nda0p1
# (tpm.bin = the unsealed bytes, on the RAM disk, from the probe). Then
# rebuild with keyfile.providers set, boot; after the first boot learn
# LOADER_TRUST_TPM_KEY_DIGEST from loader.trust.tpm.key.sha256
# (baseline-relearn), then pcr-learn. The record chain starts anew once
# (the GELI user key changed).
