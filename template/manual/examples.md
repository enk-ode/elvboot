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

A trigger whose when is a composition, and one that runs two actions:

    elebake trigger add unlock-measured 'and(when_fail,not(when_skipped))' unlock_act
    elebake trigger add silence-duress when_duress 'compose(taint_act,silence_act)'
    elebake trigger show unlock-measured
    # unlock-measured: FIRE(AND(when_fail, NOT(when_skipped)), unlock_act)

A value the loader itself is part of -- the PCR bank, the loaded images --
is expected from the conf, not the binary; learned after a trusted boot,
carried by loaderconf mk, include, sign, push, no build:

    elebake expectation add pcr-expected key PcrBank pcr.expected
    elebake claim add pcr measure_pcr - pcr.sha256 pcr-expected
    elebake stage require daily-v1
    # loader.trust.kernellock.pcr.expected  (claim pcr)  MISSING -- stage kenv learn ...
    elebake stage kenv learn daily-v1 loader.trust.kernellock.pcr.expected loader.trust.kernellock.pcr.sha256

The platform sets, add semantics: import what elvbootd filed per boot,
see what moves, take in what holds, render, build, learn:

    elebake stage inventory import daily-v1
    elebake stage inventory show daily-v1 efivars
    elebake stage inventory add daily-v1 efivars 8be4df61/BootOrder
    elebake stage inventory add daily-v1 acpi FACP/-
    elebake stage inventory list daily-v1 acpi
    elebake stage site mk daily-v1
