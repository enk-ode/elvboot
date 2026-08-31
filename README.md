# elebake

**elebake** compiles a boot trust chain: a build → sign → attest →
deploy pipeline for FreeBSD verified boot, built around one goal —
**tamper detection** for a machine's boot path. The owner decides what
is measured, when, and what happens on a shortfall; elebake turns those
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

Design stage (documented, not yet built): the `archive` exchange
bundle, the earlboot/elvbootd runtime containers, loaderconf
generation. See `docs/DESIGN_*.md`.

A companion FreeBSD patch series provides the loader-side trust gates
(measurement/claim/gate/policy engine); its publication is pending —
the generated `foundation.c` in this repo's docs shows the interface.

## Getting started

- `docs/QUICKSTART.md` — the short path.
- `docs/TUTORIAL.md` — a full guided walk, recorded live on real
  hardware, including the seventeen findings that walk fixed.
- `docs/ARCHITECTURE.md` — the combinator model (`_` terminals emit
  shell, `__` combinators re-invoke once, `___` batches sequence).
- `elebake help` — fully generated, cannot erode.

Requirements: FreeBSD (base system tools; `uefisign`, `gpg` and a
PKCS#11 stack where the respective backends are used).

## License

BSD-2-Clause — see `LICENSE`. Contributions welcome, see
`CONTRIBUTING.md`.
