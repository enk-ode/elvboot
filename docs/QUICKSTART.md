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
./elebake.sh stage checkout smoke1 mybranch | sh    # git worktree, outside the DB
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

```sh
env ELEBAKE_BASE=$HOME/.old/current ./elebake.sh dump > mig.sh
./elebake.sh bootstrap current minimal | sh
./elebake.sh restore mig.sh              # idempotent; artifacts rebuild, not move
```

## 6. Tests

```sh
sh elebake-architecture-test.sh --maxprocs $(sysctl -n hw.ncpu)
sh elebake-unit-test.sh          --maxprocs $(sysctl -n hw.ncpu)
sh elebake-integration-test.sh   --maxprocs 3
```
