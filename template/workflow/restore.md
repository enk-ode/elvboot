# restore -- the database on a second machine, or after a loss: dump and bundle into an EMPTY database

# When: the rescue case, or the restore probe. The export pair (dump +
# bundle) is signed by the pinned OpenPGP key; import refuses an unsigned
# pair, a foreign signer, or a serial below the last receipt. Import only
# into an empty database -- never over a working one.

export ELEBAKE_ROOT=~/.elebake-restore            # an isolated root: never the production db symlink
elebake bootstrap restore minimal                 # the empty database with the minimal profile
elebake openpgp add archive 7CD2BCDFF6D8567A      # the signer to trust (the same key that attested the export)
elebake setenv ELEBAKE_ARCHIVE_ATTEST_KEY archive

elebake ram open
gpg --decrypt illyria/production/dump.sh.gpg > ~/.elebake/db/.ram/dump.sh          # the pair, decrypted on the RAM disk
gpg --verify illyria/production/dump.asc ~/.elebake/db/.ram/dump.sh
gpg --decrypt illyria/production/12.tar.gz.gpg > ~/.elebake/db/.ram/bundle.tar.gz
elebake import ~/.elebake/db/.ram/dump.sh ~/.elebake/db/.ram/bundle.tar.gz    # replays the dump, unpacks the bundle, files the receipt
elebake ram close

elebake stage require daily-v1                    # the same lines as on the source machine
elebake provenance list                           # the receipt: serial, signer, when

# What does not travel: key material. stage trust needs the attest key's
# keyring, stage sign the db key -- building on the second machine is an
# air-gap decision. The boot tree in the bundle is what a rescue needs.
# The binary runner (elebake-binary.sh, RUNNER=binary) imports in one
# process: seconds instead of minutes.
