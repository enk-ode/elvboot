# EXAMPLES

Create a database, connect the sources, register keys, build and
publish a stage:

    ./elebake.sh bootstrap current minimal | sh
    ./elebake.sh setenv ELEBAKE_FREEBSD_SRC ~/git/freebsd-src
    ./elebake.sh pkcs11 add db 'pkcs11:token=...;object=db' /root/sb/db.crt
    ./elebake.sh openpgp add manifest 4E1F0A2B7C9D8E6F5A4B3C2D1E0F9A8B7C6D5E4F /root/sb/.gnupg
    ./elebake.sh stage add smoke1
    ./elebake.sh stage sign key smoke1 pkcs11 db
    ./elebake.sh stage attest key smoke1 openpgp manifest
    ./elebake.sh stage checkout smoke1 platform-trust-gates-15.1^0 | sh
    ./elebake.sh stage make smoke1
    ./elebake.sh stage push smoke1 b

Take the database elsewhere -- one signed pair, pinned on arrival:

    ./elebake.sh setenv ELEBAKE_ARCHIVE_ATTEST_KEY manifest
    ./elebake.sh export ~/git/config/dump.sh ~/.elebake/bundle/a1b2c3d.tar.gz full
    # on the receiving machine
    ./elebake.sh openpgp add manifest 4E1F0A2B7C9D8E6F5A4B3C2D1E0F9A8B7C6D5E4F
    ./elebake.sh setenv ELEBAKE_ARCHIVE_ATTEST_KEY manifest
    ./elebake.sh import ~/git/config/dump.sh ~/.elebake/bundle/a1b2c3d.tar.gz
    ./elebake.sh provenance list

The rescue pair, and a rollback that keeps the evidence:

    ./elebake.sh export ~/rescue/dump.sh ~/rescue/bundle.tar.gz minimized
    ./elebake.sh stage backup list smoke1 a
    ./elebake.sh stage rollback smoke1 a known-good-p2

Inspect instead of act (any command): run it while the terminal default
is `cat`, read the emitted shell, then re-run under an executing pin.
