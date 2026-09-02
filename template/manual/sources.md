# THE FREEBSD SOURCES

**elebake** is nothing without the loader it compiles for. The
measurement, claim, gate and policy engine that reads the compiled
decisions at boot is a FreeBSD patch series -- *platform trust gates*
-- and the catalogs **elebake** offers (`stage measure`, `stage action`,
`stage when`, `stage phase show`) are parsed from the headers of that
series. Against a stock FreeBSD tree the catalogs are empty and no
foundation can be built.

Get the tree that carries the series:

    git clone -b platform-trust-gates-15.1 \
        https://github.com/johannes-bruegmann/freebsd-src.git ~/git/freebsd-src
    elebake setenv ELEBAKE_FREEBSD_SRC ~/git/freebsd-src
    elebake freebsd prerequisites

The branch is based on releng/15.1 (15.1-RELEASE); the loader-side
engine lives under `stand/efi/loader/local/` and its README points back
at this project. Parts of the series are on their way upstream.
`stage checkout` adds a git worktree of that repository per stage, so
the source stays one repository and every stage builds from a named
ref.
