# EXAMPLES

Create a database, connect the sources, register keys, build and
publish a stage (every command that changes the database acts by itself;
the pins decide what runs as root):

    elebake bootstrap current minimal
    elebake setenv ELEBAKE_FREEBSD_SRC ~/git/freebsd-src
    elebake pkcs11 add db 'pkcs11:token=...;object=db' /root/sb/db.crt
    elebake openpgp add manifest 4E1F0A2B7C9D8E6F5A4B3C2D1E0F9A8B7C6D5E4F /root/sb/.gnupg
    elebake stage add smoke1
    elebake stage sign key smoke1 pkcs11 db
    elebake stage attest key smoke1 openpgp manifest
    elebake stage checkout smoke1 platform-trust-gates-15.1^0
    elebake stage make smoke1
    elebake stage push smoke1 b

Take the database elsewhere -- one signed pair, pinned on arrival:

    elebake setenv ELEBAKE_ARCHIVE_ATTEST_KEY manifest
    elebake export full ~/git/config/dump.sh ~/.elebake/bundle/a1b2c3d.tar.gz
    # on the receiving machine
    elebake openpgp add manifest 4E1F0A2B7C9D8E6F5A4B3C2D1E0F9A8B7C6D5E4F
    elebake setenv ELEBAKE_ARCHIVE_ATTEST_KEY manifest
    elebake import ~/git/config/dump.sh ~/.elebake/bundle/a1b2c3d.tar.gz
    elebake provenance list

The rescue pair, and a rollback that keeps the evidence:

    elebake export minimized ~/rescue/dump.sh ~/rescue/bundle.tar.gz
    elebake stage backup list smoke1 a
    elebake stage rollback smoke1 a known-good-p2

Inspect instead of act (any command): pin its act terminal to `cat`
(`elebake setintp stage_deploy_write cat`), read the emitted shell, then
pin it back. `elebake` is the wrapper `make install` places in
`$PREFIX/bin`; from a checkout the same commands read `./elebake.sh ...`.
