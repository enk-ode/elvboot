# [elvboot](https://enk-ode.github.io/elvboot/) — elevated boot

**elvboot** is the project: a FreeBSD verified-boot / tamper-detection
effort for a machine's own boot path. The family, by name:

- **[elebake](https://enk-ode.github.io/elvboot/)** — the tool this repository ships today: the compiler of
  the boot trust chain (everything below).
- **elvbootd** — the planned runtime side: hardened hook scripts in
  the OS's native mechanisms (devd/periodic/resume) that watch the
  runtime threat windows; design stage, see
  `docs/DESIGN_STAGE_FOUNDATION.md`.
- **elvboot** — tentatively reserved as the CLI companion to elvbootd;
  not settled yet.

## The FreeBSD sources -- read this first

[elebake](https://enk-ode.github.io/elvboot/) is nothing without the loader it compiles for. The
measurement/claim/gate/policy engine that reads the compiled decisions
at boot is a FreeBSD patch series, *platform trust gates*, and the
catalogs [elebake](https://enk-ode.github.io/elvboot/) offers are parsed from the headers of that series.
Against a stock FreeBSD tree the catalogs are empty and nothing
measures anything.

```
git clone -b platform-trust-gates-15.1 \
    https://github.com/johannes-bruegmann/freebsd-src.git ~/git/freebsd-src
./elebake.sh setenv ELEBAKE_FREEBSD_SRC ~/git/freebsd-src
```

Branch `platform-trust-gates-15.1` is based on releng/15.1; the
loader-side engine lives under `stand/efi/loader/local/` and its README
points back here. Parts of the series are on their way upstream.

## [elebake](https://enk-ode.github.io/elvboot/)

**[elebake](https://enk-ode.github.io/elvboot/) compiles a boot trust chain: a build → sign → attest →
deploy pipeline for FreeBSD verified boot, built around one goal —
**tamper detection** for a machine's boot path. The owner decides what
is measured, when, and what happens on a shortfall; [elebake](https://enk-ode.github.io/elvboot/) turns those
decisions into generated artifacts (C policy tables, veriexec
manifests, site baselines) and keeps every step inspectable.

Detection, not enforcement: the design assumes the boot medium *can*
be tampered with and concentrates on **noticing** — measurements are
published, findings survive reboots, and every generated file is
reproducible from the database.

## Ideas that carry the tool

- **Emit and inspect.** Every command *generates* shell; pipeline
  commands print it for review (append `| sh` to act), bookkeeping is
  pinned to act directly. Nothing hides what it is about to do.
- **Catalogs come from the World, records hold decisions.** What the
  loader *can* measure is parsed live from the checked-out sources;
  what you *want* lives in the database as named, reusable records
  (expectations, claims, gates, triggers, policies) — validated
  sharply where arsenal meets catalog.
- **Replays are an architecture principle.** `dump` exports the whole
  database as an executable script; adds are idempotent-immutable, so
  restores and re-runs are safe. Keep the dump in git and your
  configuration becomes reproducible.
- **No implicit defaults.** The kernel that guards a machine, the
  license header of a generated file, the curation of a boot tree —
  all explicit decisions, all fail-early when missing.

## Status

Working today: database + environment model, key registries
(pem/openpgp/pkcs11), stages (checkout, isolated stand/ and kernel
builds, curation filter, include from build or binary directory,
manifest/verify/attest, sign, deploy, markers, site baselines), the
foundation compiler (measurement catalogs, DB-wide arsenal, per-phase
policy binding, generated foundation.c with structural acceptance
against a hand-written original), dump/restore with migration-proof
round trips, and three test suites (architecture scanners, unit,
integration stories).

Also working: the signed exchange pair (`export`/`import` -- dump and
bundle bound by seal and one OpenPGP signature, pinned on arrival,
receipts and a serial against downgrade), backup records with label and
description, a rollback that saves the suspect loader first, and the
`minimized` rescue pair (`docs/DESIGN_DUMP_ARCHIVE.md`).

Design stage (documented, not yet built): the earlboot/elvbootd runtime
containers, loaderconf generation. See `docs/DESIGN_*.md`.

The companion FreeBSD patch series (the loader-side trust gates) is
published: see *The FreeBSD sources* above.

## Getting started

- `docs/QUICKSTART.md` — the short path.
- `docs/TUTORIAL.md` — a full guided walk, recorded live on real
  hardware, including the seventeen findings that walk fixed.
- `docs/ARCHITECTURE.md` — the combinator model (`_` terminals emit
  shell, `__` combinators re-invoke once, `___` batches sequence).
- `elebake help` — fully generated, cannot erode; `docs/elebake.8` is
  rendered from the same corpus (`make man`).

Requirements: FreeBSD (base system tools; `uefisign`, `gpg` and a
PKCS#11 stack where the respective backends are used).

## License

BSD-2-Clause — see `LICENSE`. Contributions welcome, see
`CONTRIBUTING.md`.
