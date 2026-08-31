# elebake tutorial — the full walk

A guided session, recorded live: every command was typed on the target
machine, every output below is the original (captured via script(1)).
The companion `docs/tutorial-replay.sh` accumulates each successful
command, so any point of this walk can be reproduced into a fresh
database at any time — replays are an architecture principle here, not
an emergency measure.

Conventions: the session runs inside `script ~/tutorial/transcript.txt`
in a screen session. No configuration ever travels via environment
variables (see the isolation excursus below) — the ONLY sanctioned
environment override is the database SELECTION (ELEBAKE_BASE /
ELEBAKE_ROOT), and this walk does not even need that.


## 1. The birth of a database

elebake keeps a FAMILY of databases under one root (default:
`~/.elebake`); the symlink `db` marks the ACTIVE one, and
`ELEBAKE_BASE` defaults to `~/.elebake/db` — so a stock installation
needs no environment at all. `bootstrap <name> <profile>` creates the
named database AND points the active-DB symlink at it:

```
$ cd ~/git/elvboot
$ ./elebake.sh bootstrap tutorial minimal
# Validated: .tmp
# Validated: .tmp/batch-exits
# Validated: .log
# Created: .env (mode 0700)
# Created: .env/default (mode 0700)
# Created: .env/local (mode 0700)
# Created: pkcs11 (mode 0700)
# Created: openpgp (mode 0700)
# Created: pem (mode 0700)
# Created: .staging (mode 0700)
# Created: stage (mode 0700)
# Database ready: /home/brj/.elebake/tutorial
# Installed minimal profile
# Bootstrap complete: /home/brj/.elebake/tutorial (minimal) [db -> tutorial]
```

Note the last line: `[db -> tutorial]` — bootstrap moved the active-DB
symlink itself; a manual `ln -sfn` is never needed. The name `db` is
reserved for exactly this reason. Switching back to another database
later is `ln -sfn current ~/.elebake/db` (or a fresh bootstrap).

The layout: `.env/default` holds the installed profile (the interpreter
pins — act families execute, display families page through cat),
`.env/local` your overrides; `pkcs11/openpgp/pem` are the key backends,
`stage/` and `.staging/` the stage records.

## 2. setenv — and why export does NOT work

The first real command in any new database:

```
$ ./elebake.sh setenv ELEBAKE_DISPLAY_ANSI 0
# Set ELEBAKE_DISPLAY_ANSI (effective next command)
```

Why not `export ELEBAKE_DISPLAY_ANSI=0`? Because it would do NOTHING.
elebake isolates its environment by construction: every interpreter is
executed via `run_env()` as `env - PATH=... <vars from .env files>` —
the inherited process environment is DISCARDED and rebuilt exclusively
from the database, plus a short passthrough list of pure infrastructure
(bootstrap marker, cache, trace, log). An exported configuration
variable never reaches anything. Verified live:

```
$ ELEBAKE_INTERPRETER_stage_list=sh ./elebake.sh printenv | grep stage_list
... ELEBAKE_INTERPRETER_stage_list='cat' ...     # the DB value, untouched
```

Configuration has exactly one home (the database, via setenv), one
resolution order (`.env/local` over `.env/default` over the template),
and one exception (ELEBAKE_BASE/ELEBAKE_ROOT select WHICH database —
they must work from outside, or nothing could find a database to read
its configuration from).

## 3. Reading the environment

```
$ ./elebake.sh printenv
```

prints the EFFECTIVE environment — exactly what `run_env()` hands to
every interpreter, rebuilt from the database. The whole pin model is
visible at a glance: act families on `sh`, display families on `cat`,
the ESP-touching families on `sudo sh`, and the three class defaults
(`ELEBAKE_TERMINAL_INTERPRETER=cat` — safe by default — plus the
combinator and batch interpreters). A single variable, with provenance:

```
$ ./elebake.sh getenv ELEBAKE_DISPLAY_ANSI
# Source: .env/local/ELEBAKE_DISPLAY_ANSI (override)
0
```

`local (override)` is your setenv from chapter 2; an untouched variable
answers with `default` (the installed profile) or `template`. `help` is
fully GENERATED from the sources — no hand-maintained help text exists,
so the help cannot erode. (`help env <VAR>` shows a variable's
documentation; on databases from before the multi-word command rework
the same thing was spelled `helpenv`.)

## 4. Emit-and-inspect, lived once — with the REAL key

The examples use the machine's real secure-boot signing key. The
record name `uefi-db` says what it is: the key of the UEFI Signature
Database (db) that authenticode-signs loader.efi. (The production
database calls the same record just `db` — correct too, but in a
tutorial that word is taken by the active-DB symlink.)

The three-step that IS elebake:

```
$ ./elebake.sh getintp pem_add
# Source: .env/default/ELEBAKE_INTERPRETER_pem_add (default)
sh
$ ./elebake.sh setintp pem_add cat
# Set ELEBAKE_INTERPRETER_pem_add (effective next command)
$ ./elebake.sh pem add uefi-db /root/secureboot/db.key /root/secureboot/db.crt
mkdir -p '/home/brj/.elebake/db/pem/uefi-db'
chmod 0700 '/home/brj/.elebake/db/pem/uefi-db'
echo '/root/secureboot/db.key' > '/home/brj/.elebake/db/pem/uefi-db/key'
echo '/root/secureboot/db.crt' > '/home/brj/.elebake/db/pem/uefi-db/cert'
chmod 0600 '/home/brj/.elebake/db/pem/uefi-db/key' '/home/brj/.elebake/db/pem/uefi-db/cert'
printf '# Registered pem key %s (paths only; material stays in place)\n' 'uefi-db' >&2
```

Under `cat` NOTHING happened — you read the shell that WOULD run. And
that emission answers the important question by itself: this works
although `/root/secureboot` is unreadable for the calling user, because
`pem add` registers PATHS AS PROMISES — no file is read, copied or
touched. A registration command that could copy a signing key would be
the wrong design; custody stays with root. The promise is redeemed
later, in the right context (`stage sign` under its `sudo sh` pin) and
checked by the prerequisites. Now let it act:

```
$ ./elebake.sh setintp pem_add sh
# Set ELEBAKE_INTERPRETER_pem_add (effective next command)
$ ./elebake.sh pem add uefi-db /root/secureboot/db.key /root/secureboot/db.crt
# Registered pem key uefi-db (paths only; material stays in place)
$ ./elebake.sh pem prerequisites
# prerequisites ok: pem
```

(Note what prerequisites checks here: the signing TOOLCHAIN. The
readability of the promised paths surfaces at the stage level, where
the sudo context exists.)

The attest key — the OpenPGP key that detach-signs the stage manifest;
records hold the key ID, custody stays with the keyring:

```
$ ./elebake.sh openpgp add manifest 77B2C2E8F5A4C6C7
# Registered openpgp key manifest
$ ./elebake.sh openpgp prerequisites
# prerequisites ok: openpgp
```

## 5. The stage and its key slots

A STAGE is the named workspace for exactly one boot tree; the name
says what it is for — `illyria-boot` is the stage behind this
machine's boot anchor. Every column below is DERIVED state: nothing is
cached, each line is read off the artifacts at display time.

```
$ ./elebake.sh stage list
# stages (name	id  populated  signed  sign-key/attest-key)
#   (no stages -- stage add <name>)
$ ./elebake.sh stage add illyria-boot
# Created stage illyria-boot -> stage-faa35dcef54e
$ ./elebake.sh stage list
# stages (name	id  populated  signed  sign-key/attest-key)
#   illyria-boot   stage-faa35dcef54e no	no     -/-
```

The two key SLOTS bind the chapter-4 records by reference — the same
promise logic, one level up. The attest key must be bound BEFORE the
build: its trust anchor is embedded into the loader at build time, so
the binding is building material, not bookkeeping:

```
$ ./elebake.sh stage sign key illyria-boot pem uefi-db
# Bound pem key uefi-db to stage illyria-boot (sign-key)
$ ./elebake.sh stage attest key illyria-boot openpgp manifest
# Bound openpgp key manifest to stage illyria-boot (attest-key)
$ ./elebake.sh stage status illyria-boot
# stage illyria-boot (stage-faa35dcef54e)
#   populated : no (boot/loader.efi missing)
#   sign-key  : uefi-db
#   attest-key: manifest
#   signed    : no
#   filter    : none (stage filter <stage> +<rel>)
#   media     : none (stage device <stage> <medium> /dev/<node>)
#   marker    : none (stage marker <stage> BootXXXX <file>)
#   site.mk   : none (stage site mk)
```

(`stage sign-key` with a hyphen works identically — the one tolerated
equivalence: hyphens in command words normalize to spaces.)

## 6. Connecting the source, checking out — and the first real find

Deliberately run WITHOUT the variable first — fail early is worth
seeing once:

```
$ ./elebake.sh freebsd prerequisites
# Error: freebsd prerequisites: ELEBAKE_FREEBSD_SRC not set -- elebake setenv ELEBAKE_FREEBSD_SRC <path-to-freebsd-src>
$ ./elebake.sh setenv ELEBAKE_FREEBSD_SRC /home/brj/git/freebsd-src
# Set ELEBAKE_FREEBSD_SRC (effective next command)
$ ./elebake.sh freebsd prerequisites
# freebsd prerequisites ok (checked at generation time): git make clang; src: /home/brj/git/freebsd-src
```

> **A find of this manual pass.** The second call was originally
> SILENT: the success line was emitted as a bare `#` comment, which the
> sh pin executes as a no-op — swallowed. Checks may be silent on
> success; a REPORT command must report, to stderr. Fixed to emit_note,
> and the architecture scanner was hardened to catch the pattern
> (including the multi-line printf form this one hid behind).

The checkout, with one deliberate detail on the ref: the branch
`platform-trust-gates-15.1` is already checked out in the production
stage's worktree, and git refuses the same BRANCH in two worktrees —
while any number may share a COMMIT. `^0` resolves the branch to its
commit (detached), so stages share the state without fighting over the
branch. Collisions are impossible on the other axes too: the worktree
path carries the stage id (`worktree/<stage-id>` under the root), and
sharing the `.git` objects is the point — that is why this takes
seconds instead of a second clone.

Pipeline commands are inspect-by-default. Read first:

```
$ ./elebake.sh stage checkout illyria-boot platform-trust-gates-15.1^0
# freebsd prerequisites ok (checked at generation time): git make clang; src: /home/brj/git/freebsd-src
mkdir -p '/home/brj/.elebake/worktree'
git -C '/home/brj/git/freebsd-src' worktree add '/home/brj/.elebake/worktree/stage-faa35dcef54e' 'platform-trust-gates-15.1^0'
ln -sfn '/home/brj/.elebake/worktree/stage-faa35dcef54e' '/home/brj/.elebake/db/.staging/stage-faa35dcef54e/work'
echo 'platform-trust-gates-15.1^0' > '/home/brj/.elebake/db/.staging/stage-faa35dcef54e/checkout'
chmod 0600 '/home/brj/.elebake/db/.staging/stage-faa35dcef54e/checkout'
printf '# Checked out %s at %s (worktree %s)\n' 'illyria-boot' 'platform-trust-gates-15.1^0' '/home/brj/.elebake/worktree/stage-faa35dcef54e' >&2
```

Note `mkdir -p`: every directory emission is idempotent by doctrine
(MODIFY_DIR_CREATE) — replays must never fail on what already exists.
`git worktree add` itself is deliberately NOT idempotent: a second
checkout of the same stage is a decision, not a silent overwrite; the
batch stops at git's error. Now act:

```
$ ./elebake.sh stage checkout illyria-boot platform-trust-gates-15.1^0 | sh
# freebsd prerequisites ok (checked at generation time): git make clang; src: /home/brj/git/freebsd-src
Preparing worktree (detached HEAD 59a2380128b)
Updating files: 100% (109084/109084), done.
HEAD is now at 59a2380128b stand: set st_dev/st_ino in the loader's ZFS stat for veriexec
# Checked out illyria-boot at platform-trust-gates-15.1^0 (worktree /home/brj/.elebake/worktree/stage-faa35dcef54e)
```

(That HEAD is this machine's own story: the commit is the loader ZFS
veriexec fix this whole tutorial builds on.)

Open observation from this chapter: `stage status` shows no
checkout/worktree aspect yet — the state exists (work symlink,
checkout file) but the summary does not surface it.

## 7. The catalogs: elebake reads the World

Four display commands, all parsed LIVE from the headers of the stage's
checkout — nothing cached, nothing duplicated into the database:

```
$ ./elebake.sh stage measure illyria-boot
# measurement catalog of stage illyria-boot (checkout: platform-trust-gates-15.1^0)
#   measure_prerequisites_exist
#   measure_prerequisites_verify
#   measure_secureboot
#   measure_setupmode
#   measure_board
#   measure_keys
#   measure_marker
#   measure_strict
#   measure_ve_strict
#
# diagnose functions (optional claim field):
#   diagnose_prerequisites_exist
#   diagnose_prerequisites_verify
#   diagnose_keys
#   diagnose_marker
$ ./elebake.sh stage action illyria-boot
# action catalog of stage illyria-boot (checkout: platform-trust-gates-15.1^0)
#   proceed_act
#   publish_act
#   report_act
#   message_act
#   prompt_act
#   confirm_act
#   lock_act
#   unlock_act
#   halt_act
#   panic_act
#   reboot_act
$ ./elebake.sh stage when illyria-boot
# when catalog of stage illyria-boot (checkout: platform-trust-gates-15.1^0)
#   when_always
#   when_fail
#   when_pass
$ ./elebake.sh stage phase show illyria-boot
# phase catalog of stage illyria-boot (checkout: platform-trust-gates-15.1^0)
#   PHASE_BOOT
#	(no policies bound)
#   PHASE_LOADER
#	(no policies bound)
```

> **Why aren't measure/action/when part of the arsenal?** Because they
> are not decisions but CAPABILITIES — C facts, born as patches,
> reviewed as code. And capabilities are VERSIONED: there is no "world
> as such", only the world of one checkout; another stage may sit on a
> state without `measure_ve_strict` or with actions this one lacks.
> Hence the provenance line on every catalog. The formula: the ARSENAL
> is what you want (portable across stages), the CATALOG is what this
> state can do (versioned) — and the BINDING is the contract between
> the two. One could defer all checking to a final verify; the design
> chooses layered safety instead: the binding checks early (where the
> error is cheap and the message precise), `stage foundation check`
> re-verifies right before emission (the world may have drifted), and
> the C compiler stays the last line.

## 8. The arsenal, smallest complete chain: strictwatch

The soft guarantee of this system — strict should be active, WATCHED,
never enforced. Built bottom-up; every `show` renders the C that WOULD
be emitted.

An EXPECTATION is a named, reusable expected value:

```
$ ./elebake.sh expectation add strict-active byte StrictActive 1
# expectation 'strict-active' stored
$ ./elebake.sh expectation add strict-marker byte VeStrictPresent 1
# expectation 'strict-marker' stored
$ ./elebake.sh expectation show
# strict-active: MEASUREMENT_BYTE("StrictActive", 1)
# strict-marker: MEASUREMENT_BYTE("VeStrictPresent", 1)
```

A CLAIM marries a catalog measurement to an expectation —
`<measurement> <diagnose|-> <publish|-> <exp>`; `-` renders as NULL,
the publish leaf becomes `loader.trust.<gate>.<leaf>` at runtime (the
gate namespaces it). Claim and expectation share a name here on
purpose: the families have separate namespaces, and matching names for
matching things is good style. Note that `measure_strict` is NOT
checked against the catalog now — add is dumb, dangling is allowed;
the contract comes at the binding:

```
$ ./elebake.sh claim add strict-active measure_strict - strict.active strict-active
# claim 'strict-active' stored
$ ./elebake.sh claim add strict-marker measure_ve_strict - strict.marker strict-marker
# claim 'strict-marker' stored
$ ./elebake.sh claim show
# strict-active: CLAIM(measure_strict, NULL, "strict.active", MEASUREMENT_BYTE("StrictActive", 1))
# strict-marker: CLAIM(measure_ve_strict, NULL, "strict.marker", MEASUREMENT_BYTE("VeStrictPresent", 1))
```

The GATE is AND over its claims; the append order is the evaluation
order (`gate claim add ... [<position>]` inserts deliberately). No
secret slot — strictwatch only watches, there is nothing to unlock.
Gate names must be C identifiers: they land verbatim in the generate,
and `gate show` now produces the first GATE_DEFINE that fell out of
your decisions instead of being typed:

```
$ ./elebake.sh gate add strictwatch
# gate 'strictwatch' created
$ ./elebake.sh gate claim add strictwatch strict-active
# gate 'strictwatch': claim 'strict-active' appended
$ ./elebake.sh gate claim add strictwatch strict-marker
# gate 'strictwatch': claim 'strict-marker' appended
$ ./elebake.sh gate show strictwatch
# GATE_DEFINE(strictwatch, NULL,
#     CLAIM(measure_strict, NULL, "strict.active", MEASUREMENT_BYTE("StrictActive", 1)),
#     CLAIM(measure_ve_strict, NULL, "strict.marker", MEASUREMENT_BYTE("VeStrictPresent", 1)));
```

A TRIGGER is a named FIRE(when, &action) pair; the POLICY ties gate
and triggers together — the detection core in one line: measure,
compare, publish — never halt:

```
$ ./elebake.sh trigger add publish-always when_always publish_act
# trigger 'publish-always' stored
$ ./elebake.sh policy add watch-strict strictwatch
# policy 'watch-strict' created (gate strictwatch)
$ ./elebake.sh policy trigger add watch-strict publish-always
# policy 'watch-strict': trigger 'publish-always' appended
$ ./elebake.sh policy show watch-strict
# watch-strict: POLICY(strictwatch,
#     FIRE(when_always, &publish_act)),
```

Everything here is idempotent-immutable: an identical re-add is a
silent no-op (that is what makes replays safe), a DIFFERING re-add
under the same name is refused — change is drop + add, a name's
meaning never shifts under its users.

## 9. bootlock & loaderlock: diagnose, baseline macros, the backstop

Board identity, secure-boot keys and the boot marker have no values
one could type today — they are measured at PROVISIONING time and
arrive at BUILD time as -D macros from site.mk. A `macro` record
describes that slot, and `macro show` displays all three derivations:

```
$ ./elebake.sh macro add BOARD_DIGEST sha256 BoardIdentity
# macro 'BOARD_DIGEST' stored
$ ./elebake.sh macro show BOARD_DIGEST
# BOARD_DIGEST:
#   #ifdef LOADER_TRUST_BOARD_DIGEST
#   #define	BOARD_EXPECTED	MEASUREMENT_SHA256("BoardIdentity", LOADER_TRUST_BOARD_DIGEST)
#   #else
#   #define	BOARD_EXPECTED	MEASUREMENT_NONE("BoardIdentity", MEAS_SHA256)
#   #endif
```

The guard is the site.mk convention (`LOADER_TRUST_<NAME>`), the
defined name replaces `_DIGEST` with `_EXPECTED`, and `MEAS_SHA256`
comes from the World — `enum meas_type` in measurement.h: even a
measurement WITHOUT a baseline is typed, and the `#else` branch means
UNPROVISIONED IS NOT WRONG — the claim skips instead of lying. (Both
the `#else` alternative and the defined name can be overridden:
`macro add <MACRO> <type> <label> [<else>] [<defined>]`.)

KEYS_DIGEST and MARKER_DIGEST follow the same shape; the macro
expectations reference the DEFINED names (`expectation add
board-expected macro - BOARD_EXPECTED`) — recorded first, referenced
after, verified sharply by `stage foundation check`.

The bootlock claims bring the second claim field to life — DIAGNOSE:
`measure_*` only measures a value; `diagnose_*` (where the catalog
offers one) delivers the WHY of a finding into the appraisal —
`diagnose_keys` publishes WHICH secure-boot keys deviate,
`diagnose_marker` the marker details. The publish leafs `board.sha256`
and `keys.sha256` publish the MEASURED hashes as evidence:

```
$ ./elebake.sh gate add bootlock LOADER_TRUST_BOOTLOCK_SECRET
# gate 'bootlock' created
$ ./elebake.sh gate show bootlock
# GATE_DEFINE(bootlock, BOOTLOCK_SECRET,
#     CLAIM(measure_secureboot, NULL, NULL, MEASUREMENT_BYTE("SecureBoot", 1)),
#     CLAIM(measure_setupmode, NULL, NULL, MEASUREMENT_BYTE("SetupMode", 0)),
#     CLAIM(measure_marker, diagnose_marker, NULL, MARKER_EXPECTED),
#     CLAIM(measure_board, NULL, "board.sha256", BOARD_EXPECTED),
#     CLAIM(measure_keys, diagnose_keys, "keys.sha256", KEYS_EXPECTED));
```

The second `gate add` argument is the secret SLOT: it NAMES the -D
macro — never a value; the secret lives in the SIGNED loader,
deliberately not in loader.conf. In the rendering it appears as the
LOCAL macro (`BOOTLOCK_SECRET`), exactly as the emission writes it.

> **Second find of this pass.** `gate show` originally rendered the
> raw slot (`LOADER_TRUST_BOOTLOCK_SECRET`) where the emission writes
> the local macro — a violation of "show renders what emission WOULD
> produce". Fixed: the display renderer now uses the same secret
> expression as the C renderer.

loaderlock guards the loader's own prerequisites; its expected values
are HEADER CONSTANTS — an expectation value is verbatim C, so
`LOADER_PREREQUISITES_EXIST_N` is a perfectly good expected value.
The backstop policy carries TWO fires — publish always, and on
failure `unlock_act`, the config-independent way out when the Lua
chain itself is unusable. Note `publish-always` being REUSED across
all three policies: that is the arsenal idea at work.

```
$ ./elebake.sh policy add backstop-loaderlock loaderlock
# policy 'backstop-loaderlock' created (gate loaderlock)
$ ./elebake.sh policy trigger add backstop-loaderlock publish-always
# policy 'backstop-loaderlock': trigger 'publish-always' appended
$ ./elebake.sh policy trigger add backstop-loaderlock unlock-fail
# policy 'backstop-loaderlock': trigger 'unlock-fail' appended
```

## 10. The binding: where the arsenal meets the catalog

A deliberate negative first — the contract, snapping shut once:

```
$ ./elebake.sh stage phase policy add illyria-boot PHASE_KERNEL watch-strict
# Error: stage check policy: unknown phase 'PHASE_KERNEL' (stage phase show illyria-boot lists them)
```

`stage phase policy add` is check-then-act: `check stage` ->
`check policy` -> `append`. PHASE_KERNEL is not in this checkout's
enum, so the batch stops before anything is written. `check policy`
validates the TRANSITIVE chain — policy -> gate -> claims ->
expectations (including macro resolution: BOARD_EXPECTED must be
produced by a macro record) and policy -> triggers -> whens/actions —
against the catalog of THIS stage's checkout. The real bindings pass:

```
$ ./elebake.sh stage phase policy add illyria-boot PHASE_BOOT publish-bootlock
$ ./elebake.sh stage phase policy add illyria-boot PHASE_LOADER backstop-loaderlock
$ ./elebake.sh stage phase policy add illyria-boot PHASE_LOADER watch-strict
```

The binding order is the table order in the C (a `[<position>]`
argument inserts deliberately), and the detail view now renders the
table exactly as the emission will write it:

```
$ ./elebake.sh stage phase show illyria-boot PHASE_LOADER
#   policy: backstop-loaderlock
#   policy: watch-strict
#
# static const struct policy loader_policies[] = {
# 	POLICY(loaderlock,
# 	    FIRE(when_always, &publish_act),
# 	    FIRE(when_fail, &unlock_act)),
# 	POLICY(strictwatch,
# 	    FIRE(when_always, &publish_act)),
# 	POLICY_END,
# };
```

## 11. The harvest: stage foundation

The sharp re-verification answers its caller (the world may have
drifted since the bindings were made — checkout switch, arsenal drop):

```
$ ./elebake.sh stage foundation check illyria-boot
# foundation check ok: 3 binding(s) across 2 phase(s), every chain in this checkout's catalog
```

The full batch — check stage -> foundation check -> make -> report:

```
$ ./elebake.sh stage foundation illyria-boot
$ ./elebake.sh stage foundation report illyria-boot
# foundation report of stage illyria-boot (checkout: platform-trust-gates-15.1^0)
#   PHASE_BOOT
#       policy: publish-bootlock
#   PHASE_LOADER
#       policy: backstop-loaderlock
#       policy: watch-strict
#   gates: bootlock loaderlock strictwatch
#   macros: BOARD_DIGEST KEYS_DIGEST MARKER_DIGEST
#   target: /home/brj/.elebake/db/stage/illyria-boot/work/stand/efi/loader/local/foundation/foundation.c
```

foundation.c now sits in the worktree — compiled from the database.
Its generated-by header carries DETERMINISTIC provenance (stage name,
checkout ref, the worktree's git HEAD); deliberately no timestamp,
which would break the hardest guarantee of the design: after
dump/restore the target REGENERATES THE IDENTICAL FILE. License and
author lines are the user's decision, entered once:

```
$ ./elebake.sh setenv ELEBAKE_SPDX BSD-2-Clause
$ ./elebake.sh setenv ELEBAKE_COPYRIGHT '2026 Johannes Bruegmann'
$ ./elebake.sh stage foundation make illyria-boot
```

The acceptance, done by hand — against the committed truth of the
branch (the hand-written original only exists there):

```
$ git -C ~/git/freebsd-src show platform-trust-gates-15.1:stand/efi/loader/local/foundation/foundation.c \
    | diff - ~/.elebake/worktree/stage-faa35dcef54e/stand/efi/loader/local/foundation/foundation.c
```

The diff shows ONLY: the prose comments (which move to policy.h by
design — foundation.c is generated-only now), the order of two
preamble #ifdef blocks, and claim-line whitespace. Every active C line
is identical. That is the structural acceptance of the design,
reproduced live from this database.

## 12. site mk: measuring THIS machine

Provisioning begins. `stage site mk` measures the machine AT
GENERATION TIME — and that is a lesson in itself: interpreter pins
govern EMISSIONS, but what the generator itself must measure needs the
OUTER context. Reading PK/KEK/db requires root, so the generator runs
under sudo, with the database selected explicitly (the one legitimate
environment exception — and under sudo mandatory, since root's HOME
would find the wrong database):

```
$ ./elebake.sh stage site mk illyria-boot
# Error: stage site mk 'illyria-boot': cannot read PK/KEK/db (run the GENERATOR in a context that can, e.g. sudo)
$ sudo ELEBAKE_BASE=$HOME/.elebake/db ./elebake.sh stage site mk illyria-boot
# elebake stage site mk 'illyria-boot' (measured at generation time)
# note: no boot marker bound/readable -- BootMarker stays asleep (stage marker, then re-run site mk)
# site.mk written for stage illyria-boot -- rebuild + sign + deploy to arm it
# site.mk of stage 'illyria-boot' (.../work/stand/efi/loader/local/site.mk):
# # Generated by elebake -- this machine trust expectations.
# # Not tracked in git: the values are site fingerprints, not source.
# # Pulled in by stand/efi/loader/Makefile via .-include local/site.mk.
# CFLAGS.foundation.c += -DLOADER_TRUST_BOARD_DIGEST='0xd0,0x29,...'   [redacted: site fingerprint]
# CFLAGS.foundation.c += -DLOADER_TRUST_KEYS_DIGEST='0x8b,0xc5,...'    [redacted: site fingerprint]
```

This closes the macro loop of chapter 9: the two `-DLOADER_TRUST_*`
lines are exactly what the BOARD_DIGEST/KEYS_DIGEST slots receive at
build time; the marker slot stays asleep (`MEASUREMENT_NONE` — the
claim will SKIP, not lie) until a marker is bound. The digests are
this machine's fingerprints — site.mk never enters git, and this
tutorial redacts them.

The `exit 137` seen on the failed first try is the batch exit
arithmetic: fail-fast encodes WHERE the batch stopped into the exit
code for callers — the odd number is by design.

After a tool update, one command syncs the new template variables into
the database — the idempotent post-update ritual:

```
$ ./elebake.sh environment init minimal
# Installed minimal profile
$ ./elebake.sh setenv ELEBAKE_SPDX BSD-2-Clause
$ ./elebake.sh setenv ELEBAKE_COPYRIGHT '2026 Dr. Johannes Brügmann'
$ ./elebake.sh stage foundation make illyria-boot
$ head -10 ~/.elebake/worktree/stage-faa35dcef54e/stand/efi/loader/local/foundation/foundation.c
/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2026 Dr. Johannes Brügmann
 */

/* generated by elebake stage foundation make -- do not edit
 * stage: illyria-boot	checkout: platform-trust-gates-15.1^0 (59a2380128b) */
```

License and author are the USER's decision, entered once via setenv —
never an implicit default. `stage site mk report <stage>` shows the
written site.mk any time (this 1-arg form was the seventh find of this
pass: it only existed as an internal 2-arg batch building block).
