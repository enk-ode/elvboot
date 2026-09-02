# elebake Quickstart

From zero to a signed, attested, deployed boot loader. Every command
below GENERATES shell; with the shipped defaults it only displays.
Read what it emits, then execute — either by piping to `sh` where shown,
or by pinning executing interpreters (the `minimal` profile pins the
usual suspects already).

## 0. Database

```sh
./elebake.sh bootstrap current minimal | sh
./elebake.sh environment init minimal | sh    # after upgrades: refresh pins
```

## 0b. The FreeBSD sources -- the tree with the platform-trust-gates series

Without it the catalogs are empty and no foundation can be built:

```sh
git clone -b platform-trust-gates-15.1 https://github.com/johannes-bruegmann/freebsd-src.git ~/git/freebsd-src
./elebake.sh setenv ELEBAKE_FREEBSD_SRC ~/git/freebsd-src
./elebake.sh freebsd prerequisites          # git, make, clang, and the repo
```

## 1. Keys (records hold paths/URIs only — material stays in place)

```sh
./elebake.sh pkcs11 add db 'pkcs11:token=MyToken;object=db' /root/sb/db.crt
./elebake.sh openpgp add manifest 0123456789ABCDEF /root/sb/manifest/.gnupg
./elebake.sh pkcs11 prerequisites      # can we sign RIGHT NOW? (asks the token)
```

## 2. Stage: workspace for one boot tree

```sh
./elebake.sh stage add smoke1
./elebake.sh stage sign key smoke1 pkcs11 db
./elebake.sh stage attest key smoke1 openpgp manifest
./elebake.sh stage checkout smoke1 platform-trust-gates-15.1^0 | sh   # git worktree, outside the DB
./elebake.sh stage filter smoke1 +loader.efi.signed # curate what boot/ carries
```

Provision the measured expectations (machine identity, marker — needs
root for efivar reads, base explicit because sudo resets $HOME):

```sh
./elebake.sh stage trust anchor smoke1
./elebake.sh stage trust mk smoke1
sudo env ELEBAKE_BASE=$HOME/.elebake/db ./elebake.sh stage site mk smoke1
```

## 3. Build, sign, publish

```sh
./elebake.sh stage make smoke1        # prereqs, clean, build, install, include, sign
./elebake.sh stage status smoke1      # derived state: signed: yes (current)?
./elebake.sh stage device smoke1 b /dev/da1p1   # name the medium (operator intent)
./elebake.sh stage boot tree smoke1 b sdcard-x pool/boot
./elebake.sh stage push smoke1 b      # manifest, attest, verify, tree sync, deploy
```

Reboot from the medium; the loader's gates report into
`kenv | grep loader.trust` — an empty `...bootlock.failed` is the goal.

## 4. Everyday

```sh
./elebake.sh stage list                  # all stages, one line each
./elebake.sh last                        # recent invocations; last <n> opens a trace
./elebake.sh help / help env / help intp   # living reference
```

## 5. Migration / backup

A migration is an export/import pair like any other transfer (see below):
`full` from the old database, then in the new one register the attest key,
pin it, import.

```sh
env ELEBAKE_BASE=$HOME/.old/current ./elebake.sh export ~/mig.sh ~/mig.tar.gz full
./elebake.sh bootstrap current minimal | sh
./elebake.sh openpgp add manifest-attest <fingerprint>
./elebake.sh setenv ELEBAKE_ARCHIVE_ATTEST_KEY manifest-attest
./elebake.sh import ~/mig.sh ~/mig.tar.gz  # idempotent; artifacts rebuild, not move
```

## 6. Tests

```sh
./elebake-architecture-test.sh --maxprocs $(sysctl -n hw.ncpu)
./elebake-unit-test.sh          --maxprocs $(sysctl -n hw.ncpu)
./elebake-integration-test.sh   --maxprocs 3
```

## Taking a database elsewhere, and taking it away

Two artifacts travel separately: the DUMP is the versioned description
(commit it), the BUNDLE is the payload (store it, named after the
commit). Neither contains the other; the dump names the bundle by hash.

```
elebake export dump.sh ~/.elebake/bundle/a1b2c3d.tar.gz redacted
elebake import dump.sh ~/.elebake/bundle/a1b2c3d.tar.gz
```

One key signs everything that leaves — the bundle's `MANIFEST` (the same
pair `/boot` carries) and the dump itself — and the SAME setting on the
receiving side pins the signer an incoming pair must carry. Name it once,
with the full fingerprint:

```
elebake openpgp add manifest-attest 4E1F0A2B7C9D8E6F5A4B3C2D1E0F9A8B7C6D5E4F
elebake setenv ELEBAKE_ARCHIVE_ATTEST_KEY manifest-attest
```

`import` checks the dump's signature, the seal, then every hash of the
bundle before `restore` replays a single line; an edited dump, a foreign
bundle, a changed file, a signer other than the pinned one or an older
serial (downgrade) stops the chain and names what is wrong. A successful
import files a receipt: `elebake provenance list`.

`redacted` leaves machine secrets at home — marker values, site.mk
baselines, backups — and says so in both artifacts. `full` is for your
own recovery and migration. `minimized` is the rescue pair: loaders,
kernel and modules, loader.conf, media and every backup record, nothing
to build with — small enough for the rescue system, and its import back
merges (see `docs/DESIGN_DUMP_ARCHIVE.md`). The packer is yours to
choose: `ELEBAKE_ARCHIVER` is a template with `$a` (archive) and `$b`
(base).

Backups are records with a label and a description:

```
elebake stage backup smoke1 a known-good-p2 'booted silently on 25.08.'
elebake stage backup list smoke1 a
elebake stage rollback smoke1 a known-good-p2   # saves the suspect loader first
```

When a database has served its purpose:

```
elebake destroy current
```

Naming the database is the confirmation. It removes the records, the
worktrees (including their registration in the source repo), the
bundle handover area and the active-DB symlink — irrecoverably. Copy
anything you still need out of `bundle/` first.
