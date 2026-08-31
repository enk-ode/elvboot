# foundation — compiling trust decisions for every phase container

elebake compiles a boot trust chain. The foundation is the part where
the USER decides what is checked, when, and what happens on a shortfall
— and elebake turns those decisions into generated artifacts: C tables
for the loader, a hardened rc.d script for earlboot, hardened hook
scripts for elvbootd, and the loader.conf entries the chosen actions
require.

The guiding cut: **catalogs come from the World, records hold only
decisions.** Measurements, actions, whens and phases are facts of the
code in the stage's checkout — elebake READS them from the worktree at
generation time (never cached, never duplicated into records). Claims,
gates, triggers and policies are the user's decisions — THOSE are
records: CRUD-managed, DB-wide, dump/restore-complete by construction.

Adding is DUMB, verifying is SHARP, and each lives where it belongs:

- `add` just stores. A reference may DANGLE at definition time; name
  syntax and add-refuses-existing are the only checks. Immutability by
  construction: change = drop + add, so a name's meaning never shifts
  under its users. Drop is free — dangling is verify's business.
- The BINDING is the contract. `elebake stage phase policy add`
  validates the bound policy's transitive chain against the catalog of
  the stage's checkout, and refuses without a worktree.
- `elebake stage foundation check` re-verifies everything right before
  emission (the world may have drifted: checkout switch, arsenal drop).
- The C compiler stays the last line anyway.


## 1. Phase containers

A container is an execution environment that HOSTS phases. It owns
four things: a set of phases (each phase belongs to exactly one
container), a catalog source in the worktree (its measurements and
actions are facts of ITS code), an emission format, and a deploy
location.

| container | runs                     | phases                       | emits                  |
|-----------|--------------------------|------------------------------|------------------------|
| loader    | EFI, before the kernel   | BOOT, LOADER, KERNEL         | foundation.c           |
|           |                          | (pre-kernel, via local_run())| (C initializers)       |
| earlboot  | one-shot rc.d, earliest  | SYSINIT (kenv + read-only    | hardened rc.d          |
|           | userland                 | root), MOUNTED (file/        | script (sh)            |
|           |                          | manifest measurements)       |                        |
| elvbootd  | runtime hooks in native  | STARTUP (rc.d), PERIODIC     | hardened hook          |
|           | mechanisms (§8)          | (periodic), RESUME           | scripts (sh) +         |
|           |                          | (rc.resume), MEDIA (devd)    | devd/periodic glue     |

The elvbootd phases map to the real threat windows: RESUME pairs with
the lock/wake regime, MEDIA with the one-port removable-media
discipline (verify WHICH medium appeared, not how many).

Containers attest each other with ordinary records, not special logic:
earlboot's catalog offers `measure_kenv`, which reads what the loader
published (`loader.trust.<gate>.<leaf>`) — so "the loader ran,
appraised, and published" is a normal claim over a normal expectation,
and an empty kenv namespace is itself a finding (loader bypassed).
earlboot persists its appraisal for the elvbootd hooks; those watch
for drift from there — and leave a heartbeat file behind, so the NEXT
boot's earlboot can claim "the runtime watch actually ran" (a silenced
watchdog is itself a finding).


## 2. Catalogs (read-only, from work/)

```
elebake stage measure <stage> [<container>]   available measurement functions
elebake stage action  <stage> [<container>]   available actions
elebake stage when    <stage> [<container>]   available firing predicates
elebake stage require <stage> [<container>]   kenv leafs each action consumes
elebake stage phase show <stage> [<phase>]    phases (with their container)
                                              and the bound policy lines
```

`<container>` defaults to `loader`. Each catalog is parsed from the
respective container's source in the stage's checkout (loader:
`stand/efi/loader/local/*.h`; earlboot/elvbootd: their sources) and
shows the checkout ref as provenance. No checkout -> fail early
("stage checkout first"); a container whose source does not exist in
the checkout offers no phases. The user cannot define catalog entries
from elebake — new offers are born as code and reviewed as patches.

Today's loader catalog, for reference in the examples below:

- measurements: `measure_secureboot`, `measure_setupmode`,
  `measure_board`, `measure_keys`, `measure_marker`, `measure_strict`,
  `measure_ve_strict`, `measure_prerequisites_exist`,
  `measure_prerequisites_verify` (+ `diagnose_*` where offered)
- actions: `proceed_act`, `publish_act`, `report_act`, `message_act`,
  `prompt_act`, `confirm_act`, `lock_act`, `unlock_act`, `halt_act`,
  `panic_act`, `reboot_act`
- whens: `when_always`, `when_fail`, `when_pass` — planned additions
  (all containers): `when_skipped` (fires when any claim of the gate
  was SKIPPED, i.e. its measurement yielded no value — unprovisioned
  baselines stop being silent), `when_maybe` (fires probabilistically —
  spot checks an observer cannot time exactly. This is noise, not
  cryptography: a three-line homegrown PRNG (xorshift), seeded from
  the TSC at boot, suffices in every container — no EFI RNG protocol
  needed. Two rules keep it uncritical: seed from the fine-grained
  cycle counter, never a coarse clock alone; and when_maybe only ever
  ADDS spot checks — no critical check may exist solely behind it)
- requires (parsed from the `kenv(a, "...")` calls of each action):
  `message_act` -> message, `prompt_act`/`confirm_act` -> question,
  `unlock_act`/`lock_act` -> secret

Planned earlboot catalog (born as code, §12):

- SYSINIT: `measure_kenv` (the loader's publication), `measure_securelevel`,
  `measure_veriexec_state` (mac_veriexec active/enforced), `measure_rootdev`
  (root device identity), `measure_kernel_ident` (osrelease/ident),
  `measure_tpm_pcr` (PCR 4 against the deployed loader's expected
  digest — the ONE outside measurement of the RUNNING image: the
  firmware hashes BOOTX64.EFI into the TPM before jumping, extend-only,
  unforgeable by the loader; detects the valid-but-old rollback loader.
  Prerequisite: TPM enabled + driver, currently open on illyria)
- MOUNTED: `measure_file_sha256`, `measure_manifest` (verify a manifest's
  files), `measure_efivar` (BootOrder/BootNext/our marker variable from
  userland), `measure_esp_digest` (the deployed loader.efi against the
  provisioned digest)
- actions: the shared userland palette (§14) plus `persist_act`
  (write the appraisal for the runtime hooks)

Planned elvbootd catalog (born as code, §12):

- PERIODIC/RESUME: `measure_efivar`, `measure_esp_digest`,
  `measure_geom` (partition table of the anchor medium),
  `measure_heartbeat` (the watch itself ran recently), `measure_rtc_gap`
  (implausible sleep/clock windows after wake)
- MEDIA: `measure_media_serial`, `measure_media_partitions`,
  `measure_media_bootcode` (EFI files on the medium against the
  provisioned digests)
- actions: the shared userland palette (§14) plus `quarantine_act`
  (MEDIA: leave the suspect medium unmounted/read-only)

These lists are curated on purpose — every entry answers a concrete
threat window; anything further is born as a patch when a window shows
up.


## 3. The arsenal (DB-wide records, CRUD)

Five families mirror the initializer grammar one to one. They are
DB-wide, top-level commands (backend analogy: like pem/openpgp keys,
stages REFERENCE shared objects). The user builds one configuration
arsenal and reuses it across stages and containers.

```
elebake macro add  <MACRO> <type> <label> [<else>] [<defined>]
                                              # build-provided baseline slot:
                                              #   #ifdef LOADER_TRUST_<MACRO> ...
                                              # <else>: the #else alternative as a
                                              #   verbatim C expression ('-' or omitted:
                                              #   MEASUREMENT_NONE -> the claim skips)
                                              # <defined>: explicit defined name ('-'
                                              #   or omitted: the _DIGEST->_EXPECTED
                                              #   derivation)
elebake macro drop <MACRO>
elebake macro show [<MACRO>]                  # renders the full #ifdef block

elebake expectation add  <exp> <type> <label> <value>
elebake expectation drop <exp>
elebake expectation show [<exp>]      # MEASUREMENT_<TYPE>("<label>", <value>)
                                      # type macro: renders <value> verbatim

elebake claim add  <claim> <measurement> <diagnose|-> <publish|-> <exp>
elebake claim drop <claim>
elebake claim show [<claim>]          # CLAIM(<measurement>, <diagnose>, "<publish>", <exp>)

elebake gate add        <gate> [<secret-slot>]      # slot NAMES the -D macro, never a value;
                                                    # gate names land in the C output: C identifier
elebake gate drop       <gate>
elebake gate claim add  <gate> <claim> [<position>] # order = evaluation order; default
                                                    # append, 1-based insert otherwise
elebake gate claim drop <gate> <claim>              # unlink only, the claim survives
elebake gate show       [<gate>]      # GATE_DEFINE(<gate>, <secret>, <claims...>)

elebake trigger add  <trigger> <when> <action>
elebake trigger drop <trigger>
elebake trigger show [<trigger>]      # FIRE(<when>, &<action>)

elebake policy add          <policy> <gate>
elebake policy trigger add  <policy> <trigger> [<position>]   # a FIRE; default append,
                                                              # 1-based insert otherwise
elebake policy trigger drop <policy> <trigger>
elebake policy drop         <policy>
elebake policy show         [<policy>]              # POLICY(<gate>, <FIREs...>)
```

`show` always renders what emission WOULD produce; a dangling
reference renders as `/* undefined ...: <name> */` — visible, not
fatal (the sharp check is elsewhere).

A `macro` record names a BUILD-PROVIDED baseline (site.mk delivers the
value via `-DLOADER_TRUST_<MACRO>=...`; absent -> the claim skips).
Three fixed derivations turn the record into C, so no name is stored
twice: the guard is `LOADER_TRUST_<MACRO>`, the defined macro is
`<MACRO>` with a `_DIGEST` suffix replaced by `_EXPECTED` (else
`_EXPECTED` appended), and the type maps to the measurement pair
(`sha256` -> `MEASUREMENT_SHA256(label, guard)` /
`MEASUREMENT_NONE(label, MEAS_SHA256)`). `macro show BOARD_DIGEST`
renders exactly the block foundation.c carries today:

```
#ifdef LOADER_TRUST_BOARD_DIGEST
#define	BOARD_EXPECTED	MEASUREMENT_SHA256("BoardIdentity", LOADER_TRUST_BOARD_DIGEST)
#else
#define	BOARD_EXPECTED	MEASUREMENT_NONE("BoardIdentity", MEAS_SHA256)
#endif
```

A macro expectation references the DEFINED name (`expectation add
board-expected macro - BOARD_EXPECTED`); add stays dumb (the reference
may dangle), and `stage foundation check` verifies that every
referenced defined name is produced by exactly one macro record — the
sharp end of "recorded first, referenced after".

`<position>` is the one ordering tool, uniform across the element
verbs (`gate claim add`, `policy trigger add`, `stage phase policy
add`): 1-based, default append, out of range -> error (fail early).
Reordering is drop + add-at-position — no extra `order` command, and
add stays dumb (a position is placement, not validation).

Storage — every record CLI-replayable, dump/restore-complete:

```
$ELEBAKE_BASE/foundation/macros/<NAME>          "<type> <label> <defined|-> <else...|->"
$ELEBAKE_BASE/foundation/expectations/<name>    "<type> <label> <value>"
$ELEBAKE_BASE/foundation/claims/<name>          "<measurement> <diagnose> <publish> <exp>"
$ELEBAKE_BASE/foundation/gates/<name>/secret    optional -D slot name
$ELEBAKE_BASE/foundation/gates/<name>/claims    ordered claim names
$ELEBAKE_BASE/foundation/triggers/<name>        "<when> <action>"
$ELEBAKE_BASE/foundation/policies/<name>        "gate <gate>" + ordered "trigger <t>"
```

Per stage, only the bindings: `.staging/<id>/phases/<PHASE>` (ordered
policy names) and `.staging/<id>/conf/<key>` (loaderconf values, §5).

Dump: one foundation section in the database dump (CLI replays per
family, dependency order: macros, expectations, claims, triggers,
gates, policies); the stage dump replays only its phase and conf
bindings.


## 4. Binding and emission

```
elebake stage phase policy add  <stage> <phase> <policy> [<position>]
elebake stage phase policy drop <stage> <phase> [<policy>]
```

The verb pair lives under `phase policy` deliberately: phases exist in
code (or conceptually, per container) and are never created or removed
here — what is added or dropped is a POLICY BINDING on a phase. The
grammar matches the other element verbs (`gate claim add`,
`policy trigger add`), including `<position>` (§3). A duplicate
binding is refused: the same policy at most once per phase (binding it
twice has no meaning — the gate would just fire twice), which keeps
the NAME the unambiguous address for drop.

`stage phase policy add` is check-then-act: `check stage` ->
`check policy` -> append. `check policy` resolves the container FROM
the phase and validates the transitive chain — policy -> gate ->
claims -> expectations, policy -> triggers -> whens/actions — for
internal completeness AND against that container's catalog in the
stage's checkout. The same policy may be bound to phases of different
containers, provided each container's catalog offers what it
references.

Emission, per container, named after the artifact:

```
elebake stage foundation check  <stage>     sharp re-verification, all bound phases
elebake stage foundation make   <stage>     generate foundation.c into the worktree
elebake stage foundation report <stage>     summary of gates/claims/policies per phase
elebake stage foundation <stage>            the batch: check stage -> check -> make -> report

elebake stage earlboot mk <stage>           generate the earlboot rc.d script
elebake stage elvbootd mk <stage>           generate the elvbootd hook set (§8)
elebake stage loaderconf mk|check|report <stage>    (§5)
```

The emitter expands each referenced claim inline into the
`CLAIM(measure, diagnose, publish, expected)` form inside
`GATE_DEFINE` — no C schema change. It emits ONLY what the stage's
bindings transitively reference (a DB-wide arsenal may hold more), one
`<phase>_policies[]` table per bound enum phase (name: the enum entry
minus `PHASE_`, lowercased), and the `phase_policies()` switch. Gate
secret SLOTS keep today's local-macro convention (`#ifdef <slot>` ->
`#define <slot minus LOADER_TRUST_> <slot>` else NULL).

foundation.c is GENERATED-ONLY: the prose comments of the hand-written
file move into policy.h (patch series), the generated file carries
just a generated-by header. The acceptance baseline is therefore
STRUCTURAL: the generated C must be identical to today's hand-written
foundation.c after comment stripping — same macros, gates, claims,
tables, switch. Regeneration belongs to the post-checkout provisioning
block (trust anchor / trust mk / site mk / foundation).


## 5. loaderconf and the require axis

The user's selection implies kenv keys that MUST exist in loader.conf:
actions consume `kenv(a, "<leaf>")` and `gate.c` owns the naming
`loader.trust.<gate>.<leaf>`. elebake derives the obligation instead
of documenting it.

The require axis has two sides with different owners:

- The CONSUMER side is a catalog, i.e. a fact of the code: WHICH leafs
  an action reads is decided by the action's implementation. The user
  cannot invent consumers from elebake — a new consumer is a new
  action, born as a patch (like every catalog entry).
- The VALUE side is the user's: `elebake stage conf add <stage> <key>
  <value>` is a dumb store, per stage (messages and secret hashes are
  medium-specific), and it is OPEN — any `loader.trust.*` key may be
  stored and will be emitted. require defines the mandatory FLOOR, not
  a ceiling: extra keys ride along unprüfed, missing required keys
  refuse the artifact.

The artifact mechanics:

- `elebake stage loaderconf mk <stage>` crosses bound phases x
  require catalog x conf records and REFUSES on any missing value
  (fail early, no implicit defaults). It emits `loader.trust.conf`, a
  file wholly owned by elebake and hooked in via `loader_conf_files`
  — the hand-written loader.conf stays untouched, and the veriexec
  manifest covers the generated file as its own object.
- `elebake stage loaderconf check <stage>` regenerates and diffs
  against the boot medium — tamper detection extended to the conf;
  `report` renders the comparison.
- earlboot/elvbootd requires map to an rc.conf.d fragment with the
  same mk/check mechanics.

What require deliberately does NOT cover: it forces configuration to
EXIST, it never encodes reactions or classifications — those remain
claims and policies (see the sentinel prompt, §10, for the pattern
that combines both). Note also the two secret paths, kept deliberately
distinct: the gate's secret SLOT is compiled into the signed loader
via site.mk (`-D`, safe against a tampered conf), while
`loader.trust.<gate>.secret` is a runtime kenv expectation an action
may consult. The require catalog makes the second path visible; the
first never touches loaderconf.


## 6. Worked example: the loader (reproducing today's strict-watch)

The examples run with the profile's pins in place (`environment init`):
the act families execute directly, the display families page through
`cat` — no piping in sight; `elebake <family> ... | sh` remains the
pin-free long form.

The user configures the soft guarantee — strict should be active,
watched not enforced:

```
$ elebake expectation add strict-active byte StrictActive 1
$ elebake expectation add strict-marker byte VeStrictPresent 1
$ elebake claim add strict-active measure_strict    - strict.active strict-active
$ elebake claim add strict-marker measure_ve_strict - strict.marker strict-marker
$ elebake gate add strictwatch
$ elebake gate claim add strictwatch strict-active
$ elebake gate claim add strictwatch strict-marker
$ elebake trigger add publish-always when_always publish_act
$ elebake policy add watch-strict strictwatch
$ elebake policy trigger add watch-strict publish-always
$ elebake stage phase policy add smoke1 LOADER watch-strict
```

Inspection at any point:

```
$ elebake gate show strictwatch
# GATE_DEFINE(strictwatch, NULL,
#     CLAIM(measure_strict, NULL, "strict.active", MEASUREMENT_BYTE("StrictActive", 1)),
#     CLAIM(measure_ve_strict, NULL, "strict.marker", MEASUREMENT_BYTE("VeStrictPresent", 1)));
```

`elebake stage foundation smoke1` then generates a foundation.c whose
strictwatch gate and `POLICY(strictwatch, FIRE(when_always,
&publish_act))` line in `loader_policies[]` are diff-identical to the
hand-written file. Compile-provided baselines stay macro expectations
(`elebake expectation add board-expected macro - BOARD_EXPECTED`), so
the `-D`/site.mk mechanism is untouched.


## 7. Worked example: earlboot (custody of the loader's verdict)

```
$ elebake expectation add bootlock-clean string loader.trust.bootlock.failed ""
$ elebake claim add bootlock-clean measure_kenv - - bootlock-clean
$ elebake gate add custody
$ elebake gate claim add custody bootlock-clean
$ elebake trigger add log-always when_always log_act
$ elebake trigger add console-fail when_fail console_act
$ elebake policy add custody-watch custody
$ elebake policy trigger add custody-watch log-always
$ elebake policy trigger add custody-watch console-fail
$ elebake stage phase policy add smoke1 SYSINIT custody-watch
```

`elebake stage earlboot mk smoke1` generates the rc.d script — the
same gate/claim/policy structure, emitted as sh. The script is
MAXIMALLY HARDENED, generation-time style: self-contained (no sourcing
beyond rc.subr), every external command by absolute path, environment
sealed:

```sh
#!/bin/sh
# generated by elebake stage earlboot mk -- do not edit
# PROVIDE: earlboot
# BEFORE: disks

readonly PATH=/sbin:/bin; export PATH
IFS=' 	
'; umask 077
set -f

# --- phase SYSINIT ---
# gate custody
_m=$(/bin/kenv -q loader.trust.bootlock.failed 2>/dev/null || echo '<unset>')
if [ "$_m" = "" ]; then
        custody_pass="$custody_pass bootlock-clean"
else
        custody_fail="$custody_fail bootlock-clean"
fi
# policy custody-watch
log_act custody               # FIRE(when_always, log_act)
[ -n "$custody_fail" ] && console_act custody   # FIRE(when_fail, console_act)
```

(`log_act`/`console_act` are generated inline functions using absolute
paths — nothing is looked up at runtime that elebake already knew at
generation time.)

A bypassed loader shows up here as `<unset>` — a failing claim, not a
special case. The script persists its appraisal (pass/fail lists per
gate) to `/var/db/elvboot/appraisal` for the elvbootd hooks, and
checks LAST run's heartbeat (§1) so a silenced runtime watch surfaces
at the next boot.


## 8. Worked example: elvbootd (runtime windows)

elvbootd emits SCRIPTS, not a configuration. Three shapes were on the
table:

1. A long-running daemon binary reading elvbootd.conf — rejected: it
   adds a config PARSER (runtime intelligence our generation-time
   principle avoids), a new long-running attack surface, and a second
   schema that can drift against the emitter.
2. One generated elvbootd.sh daemon — better (everything hard-coded),
   but an sh event loop must re-implement what the OS already offers:
   device events, timers, resume hooks.
3. Generated HOOK SCRIPTS plugged into FreeBSD's native mechanisms —
   chosen: everything hard-coded and hardened like earlboot (§7), no
   new long-running process, each phase lands in the mechanism built
   for it, and every artifact is a manifest-covered file.

"elvbootd" thus names the CONTAINER (the runtime phase family), not a
process. `elebake stage elvbootd mk <stage>` emits one hook per bound
phase plus the glue:

```
/usr/local/etc/elvboot/hook.media.sh        MEDIA    (invoked by devd)
/usr/local/etc/elvboot/hook.resume.sh       RESUME   (rc.resume)
/usr/local/etc/elvboot/hook.periodic.sh     PERIODIC (periodic/security)
/usr/local/etc/elvboot/hook.startup.sh      STARTUP  (rc.d one-shot)
/usr/local/etc/devd/elvboot.conf            devd glue for MEDIA
```

The runtime watch leaves a heartbeat under /var/db/elvboot/ that
earlboot claims at the next boot — the watchdog is itself watched.

The MEDIA phase guards the one-port discipline — when a removable
medium appears, verify it is THE boot anchor:

```
$ elebake expectation add anchor-serial string MediaSerial "SDCIT2/32GB 0xdeadbeef"
$ elebake claim add anchor-serial measure_media_serial - - anchor-serial
$ elebake gate add anchor-medium
$ elebake gate claim add anchor-medium anchor-serial
$ elebake trigger add console-fail when_fail console_act
$ elebake policy add media-watch anchor-medium
$ elebake policy trigger add media-watch console-fail
$ elebake stage phase policy add smoke1 MEDIA media-watch
```

`elebake stage elvbootd mk smoke1` then emits the devd glue

```
# generated by elebake stage elvbootd mk -- do not edit
notify 100 {
        match "system" "DEVFS";
        match "type"   "CREATE";
        match "cdev"   "da[0-9]+";
        action "/usr/local/etc/elvboot/hook.media.sh $cdev";
};
```

and `hook.media.sh` with the same hardened prologue as earlboot,
measuring the attached medium and firing per policy; a shortfall is an
ordinary finding:

```
elvboot-media: anchor-medium: claim anchor-serial FAILED
elvboot-media:   measured "Lexar 64GB 0x..." expected "SDCIT2/32GB 0xdeadbeef"
```

RESUME and PERIODIC hooks bind policies the same way (e.g. re-run the
manifest watch after wake).


## 9. Worked example: loaderconf

The user binds `unlock_act` on the loaderlock gate; the require
catalog says `unlock_act` consumes the `secret` leaf, and `message_act`
would consume `message`:

```
$ elebake stage require smoke1
# unlock_act: loader.trust.<gate>.secret
# message_act: loader.trust.<gate>.message
...
$ elebake stage loaderconf mk smoke1
elebake: error: loaderconf: no value for 'loader.trust.loaderlock.secret'
                (bound via LOADER/backstop -> unlock_act; stage conf add first)
$ elebake stage conf add smoke1 loader.trust.loaderlock.secret "<sha256-hex>"
$ elebake stage loaderconf mk smoke1
```

generates `loader.trust.conf` on the target:

```
# generated by elebake stage loaderconf mk -- do not edit
loader.trust.loaderlock.secret="<sha256-hex>"
```

Later, `elebake stage loaderconf check smoke1` regenerates and diffs
against the medium:

```
# loaderconf drift: loader.trust.loaderlock.secret
#     medium:   "0ab3..."
#     database: "9f21..."
```


## 10. Worked example: the sentinel prompt (open answer set)

DURESS (English for coercion): the situation where the legitimate user
operates the machine UNDER COMPULSION — someone forces them to unlock
or boot. A duress code is a second, equally valid-looking input that
signals exactly that: to the coercer everything appears normal, while
the system covertly marks the session as coerced and reacts (GrapheneOS
uses the same concept: its duress PIN wipes the device on entry). The
crucial property is indistinguishability at entry time — the coerced
input must LOOK like success.

The scenario: just before the kernel boots, a prompt asks an innocent
question — "Name ihres Lieblingsspielzeugs:" — and the ANSWER selects
the reaction: one keyword means all is well, one is the duress answer
(coerced — act, but not visibly), one means "irregularities observed,
verify extra-carefully", any unknown answer fires a configured action,
and a missing answer fires the strict one. An open set of inputs, an
open set of reactions.

require alone cannot express this — and must not: require forces
configuration to exist, it never classifies. The sentinel is the
combination of all three layers, each doing what it already does:

- **Loader (KERNEL phase)**: a new action `sentinel_act` asks the
  question (text via require -> `loader.trust.<gate>.question`) and
  publishes ONLY the SHA256 of the answer as
  `loader.trust.<gate>.answer` — it never classifies, never reacts
  visibly. Under duress the loader must not betray that anything was
  understood; it behaves identically for every input, including none
  (then it publishes the empty marker).
- **loaderconf**: carries the question text — and nothing else. The
  answer-class hashes do NOT live on the boot medium: an attacker
  holding the powered-off medium learns neither how many classes exist
  nor their values.
- **earlboot/elvbootd**: the classification is ordinary arsenal
  configuration behind the encrypted root — one expectation per answer
  class, one claim each over `measure_kenv`, policies choose the
  reactions:

```
$ elebake expectation add toy-ok      string loader.trust.sentinel.answer "<sha256(Ball)>"
$ elebake expectation add toy-duress  string loader.trust.sentinel.answer "<sha256(Fahrrad)>"
$ elebake expectation add toy-doubt   string loader.trust.sentinel.answer "<sha256(Puppe)>"
$ elebake expectation add toy-missing string loader.trust.sentinel.answer ""
$ elebake claim add toy-ok      measure_kenv - - toy-ok
$ elebake claim add toy-duress  measure_kenv - - toy-duress
$ elebake claim add toy-doubt   measure_kenv - - toy-doubt
$ elebake claim add toy-missing measure_kenv - - toy-missing
$ elebake gate add sentinel-duress
$ elebake gate claim add sentinel-duress toy-duress
$ elebake trigger add duress-pass when_pass duress_act
$ elebake policy add on-duress sentinel-duress
$ elebake policy trigger add on-duress duress-pass
$ elebake stage phase policy add smoke1 STARTUP on-duress
```

  ... and equally: a gate per class with its reaction policy
  (`on-doubt` -> rearm/extra checks, `on-missing` -> the strict
  action), plus a catch-all gate over ALL known classes whose
  `when_fail` means "an answer was given, but none we know" — the
  configured action for an obvious wrong entry. The open answer set is
  an open set of expectations; the open reaction set is the existing
  action catalog.

The division of labor is the custody chain used deliberately: the
loader MEASURES and publishes (hash only), the userland CLASSIFIES and
reacts — where the reaction table is unreadable without the unlocked
root, and where reactions may be silent (elvbootd acting later, at a
moment the coercer no longer controls).

Two operational consequences, spelled out:

- **Answers wear out.** Whoever watches the user type "Ball" once can
  force exactly that answer next time — an observed answer is burnt
  and must be replaced. Mechanically that is ordinary CRUD: the
  expectations are immutable, so replacing an answer word is
  `expectation drop toy-ok` + `expectation add toy-ok ... "<new
  hash>"` — the claims and policies reference the NAME and survive
  the rotation untouched. How often to rotate is user discipline, not
  a tool feature.

- **Classes are SETS, not single words.** Nothing stops the user from
  binding many words to one reaction — "Ball", "Bus", "Bomb", "BBQ"
  all meaning duress. Gates are AND over their claims, so the OR over
  answers lives one level up, where it already exists: one expectation
  + claim + single-claim gate PER WORD, every gate's policy firing the
  SAME action. The command block grows linearly, and generating it is
  an ordinary user script — elebake stays dumb. PATTERN classes
  ("starts with B") cannot be derived from a full-answer hash; for
  them `sentinel_act` additionally publishes the hash of the FIRST
  character (`loader.trust.sentinel.answer.first`), turning a whole
  dictionary series (the B-series = duress, the P-series = probably)
  into a single comparison. Two hygiene rules come with this: the
  published hashes are SALTED (the salt travels in loader.trust.conf;
  answers are dictionary words, an unsalted leaked value would fall to
  a word sweep), and earlboot UNSETS the answer keys from kenv after
  persisting — no readable residue on the running system.

- **The question lives on the medium, per stage.** The question text
  travels via `stage conf add` into loader.trust.conf, and `stage
  conf` is per-stage by construction — so each medium can carry its
  own question. That is the right default: identical questions across
  media would tie the devices to one owner for anyone who reads two
  of them. Nothing extra to design; the mechanics already decide it.

- **The prompt SHOWS before it asks.** The user is the one measurement
  instrument the platform cannot enumerate: they often know what
  SHOULD have been — and that judgement flows back through the answer
  choice (noticing an oddity, they pick from the probably-series).
  `sentinel_act` therefore displays a curated context line before the
  question; WHICH items is per-medium configuration via the require
  path (`loader.trust.sentinel.display="bootcount lastboot"`).
  Candidate items, each also usable as an ordinary measurement so the
  machine cross-checks what the human sees:
  - `bootcount` — own EFI variable, incremented by the loader; the
    user remembers "last time plus one", and earlboot verifies the
    +1 monotonicity as a claim against the persisted last value
  - `lastboot` / `lastshutdown` — RTC timestamps of the previous boot
    and whether the shutdown was clean (an unclean one the user does
    not remember causing is exactly the kind of oddity this exists for)
  - `wakecount` — resumes since the previous boot
  - `gates` — the current appraisal in shortest form (n passed/m failed)
  - `attempts` — sentinel entries since the last accepted one

  The guardrail: the coercer reads the display too. Only values whose
  knowledge does not help an attacker belong in it, and the selection
  is the user's explicit conf decision — the default shows nothing.

## 11. Acceptance and tests

The first population is a command block reproducing TODAY's
hand-written foundation.c; `elebake stage foundation smoke1` must
generate a diff-identical file (modulo the generated-by header). Unit
tests: catalog parsing against fixture headers, CRUD round-trips,
order preservation, drop semantics, dangling-show rendering, binding
validation negatives (unknown measurement, phase without container
source, missing worktree).

Integration stories, explicit. Each is implemented WITH the block that
provides its machinery — 1-8 with the CRUD/loaderconf block, 9-12 with
the emitter blocks (that is sequencing, not deferral):

1. **Arsenal migration**: build arsenal + bindings, dump, restore into
   a fresh DB, regenerate — foundation.c diff-identical.
2. **Acceptance**: the §6 command block reproduces TODAY's hand-written
   foundation.c diff-identically (modulo generated-by header).
3. **Binding drift**: bind against a fixture checkout (passes); switch
   the checkout so a referenced measurement vanishes — `foundation
   check` fails, and a new `phase policy add` refuses.
4. **loaderconf cycle**: require -> mk refuses on the missing value ->
   conf add -> mk emits -> check clean -> mutate the medium copy ->
   check reports the drift.
5. **Ordering**: claims/triggers/policies inserted via `<position>` —
   emission order exactly as placed.
6. **Replay idempotence**: the full dump replayed twice — DB
   byte-identical after both runs.
7. **Negatives**: add on an existing name, duplicate phase binding,
   out-of-range position — precise errors, DB unchanged.
8. **Dangling lifecycle**: drop a referenced claim — show renders the
   undefined marker, `foundation check` fails, re-add heals.
9. **Duress story** (with the earlboot emitter): fixture kenv via
   interpreter pins (echo-doctrine — assertions on command strings,
   nothing real fires). Four runs: ok answer -> only the ok policy
   fires; duress answer -> the duress action fires AND the hook's
   visible output is indistinguishable from the ok run; unknown answer
   -> the catch-all; unset -> the strict action.
10. **Hardening**: every generated hook passes `sh -n` and the
    architecture scan (readonly PATH, absolute paths, set -f, umask).
11. **Heartbeat chain**: the fixture runtime hook writes its heartbeat
    -> earlboot's claim passes; remove the heartbeat -> a finding.
12. **Rotation**: expectation drop + add with a new hash — bindings
    untouched, the new emission classifies the new word.
13. **Erosion detector**: a COMFORTABLE database — every key backend,
    several stages (markers, backups, boot trees, site.mk), the full
    arsenal, conf values and bindings — built by ONE fixture script
    that exercises every storing command family. dump -> restore ->
    `diff -r --no-dereference` byte-identical, and the re-dump equals
    the dump. The fixture script IS the coverage contract: a new
    command that stores state and is missing there is exactly the
    erosion this story exists to catch.

## 12. Manual C/code prerequisites (patch-series TODOs, not elebake)

- The KERNEL phase (immediately before kernel boot): the enum entry
  plus its `local_run()` call site are hand-added to the patch series;
  elebake then lists the phase automatically.
- `when_skipped` and `when_maybe` (§2) in the loader and their sh
  equivalents (when_maybe: the three-line xorshift PRNG, TSC-seeded).
- `sentinel_act` (§10): prompt + hash + publish, reaction-free.
- The ESP-identity/rollback closure package (from the tutorial control
  pass): (1) `stage esp check <stage> <medium>` — compare BOOTX64.EFI
  and the reserve against the attested manifest hashes at every card
  contact; (2) BOOTX64.EFI and
  loader.efi.signed join the loader's prerequisites VERIFY list
  (JB: the machinery exists — verified read checks each entry against
  the manifest, LOADER_PREREQUISITES_VERIFY_N counts them,
  diagnose_prerequisites_verify publishes what fell short; the ESP
  entry needs the device-qualified path, the reserve is a plain bootfs
  path). Checks the RESTING files — a running hostile loader is (3); (3) the earlboot MVP (kenv custody +
  heartbeat) — an empty loader.trust.* namespace IS the finding
  "loader bypassed", wrong baselines betray the old one; (4) a dbx
  runbook — revoke superseded loader signatures so "validly signed"
  stops meaning "any version ever signed"; (5) `measure_tpm_pcr` (§2)
  plus the SOFT-PCR that ALREADY EXISTS: libsecureboot/veriexec keeps
  `loader.ve.pcr`, a software extend-only aggregate over every
  verified file, published to kenv — use it, do not reinvent it:
  earlboot claims it via `measure_kenv`, elvbootd watches its
  constancy; with TPM both run side by side (the soft register
  cross-checks the hard one).
- `rescue_act` (§14): the KERNEL-phase diversion into the signed
  rescue partition, GELI untouched; plus the rescue system's startup
  hook with the opt-in `delkey_act` escalation.
- earlboot and elvbootd themselves (sources = their catalog roots),
  including the §2 planned catalogs, the hardened-emission templates,
  the appraisal persistence and heartbeat formats.
- A declarative requires table per action (replacing the
  generation-time grep of `kenv(a, "...")` calls).
- Prose relocation: the explanatory comments of the hand-written
  foundation.c move to policy.h/the design docs; foundation.c becomes
  generated-only (acceptance is structural, see §4).


## 13. Naming rule

Artifact commands are named AFTER their artifact (`manifest`,
`trust anchor`, `trust mk` -> site.trust.mk, `site mk` -> site.mk,
`stage foundation` -> foundation.c, `stage loaderconf` ->
loader.trust.conf); family STEPS are `<family> <verb>`
(`foundation check|make|report`, `claim add|drop|show`, ...). `site
mk` deliberately keeps `mk`: the artifact IS a .mk file, and "make"
already means the build pipeline (`stage make`). The import checks
(`check stage|dir|file`) verify ARGUMENT objects, not families, and
keep their verb-first form.


## 14. The userland action palette (air-gap first)

A networked "alert" does not exist here — the machine is air-gapped on
purpose, so every reaction must work with what is local: the console,
the disks, the EFI variables, and the removable medium that already
travels between machines. The palette, curated like the measurement
catalogs (every entry answers "who learns of the finding, and when"):

- `log_act` — syslog, the baseline record.
- `console_act` — immediate human visibility: console line, wall to
  active terminals, next-login banner (motd). Never for duress.
- `spool_act` — append a structured finding to a local append-only
  spool (`chflags sappnd`); the foundation for everything delayed.
- `mark_act` — persist the finding as a marker (file or EFI variable)
  that SURVIVES reboot and is itself claimed by the next earlboot run:
  a finding cannot be forgotten by power-cycling.
- `freeze_act` — write the mark that elebake itself honors: trust
  operations (make, sign, deploy, marker rotation) refuse until the
  user acknowledges the finding. The system stops extending trust on
  a platform it no longer believes.
- `lock_act` — end/lock the local session (runtime hooks).
- `shutdown_act` — the hard stop, for findings where continuing to
  run is worse than stopping (e.g. MEDIA bootcode mismatch).
- `quarantine_act` — MEDIA: leave the suspect medium unmounted.
- `courier_act` — the air-gap "alert": spool the finding ONTO the
  removable medium, so the report travels the existing sneaker channel
  and surfaces on the administration machine at the next contact.
  Detection news moves at the speed of the courier — which is exactly
  the speed everything else here moves at.

- `rescue_act` — loader, KERNEL phase: instead of booting zroot,
  divert into the SIGNED rescue partition (zcard) WITHOUT attaching
  GELI. The suspect system is never entered, zroot stays sealed, and
  the machine still boots — into a repair environment. On a false
  alarm the cost is small: slot 1 (the recovery passphrase) repairs
  everything from there. As a configurable ESCALATION the rescue
  system's own startup hook may remove GELI key slot 0 (`delkey_act`),
  invalidating the everyday credential while slot 1 survives — repair
  stays possible, coercion on the everyday secret stops working. The
  slot removal runs in the RESCUE USERLAND, opt-in per finding class,
  never in the loader: the loader reads, publishes and diverts;
  writing GELI metadata from EFI code is a risk we do not take.

Duress reactions compose from the silent members (spool, mark,
courier) plus DELAY: fire deliberately late, at a moment the coercer
no longer controls. The sharpest option — destroying key material,
the GrapheneOS wipe analogy — is documented as exactly that: an
opt-in enforcement step outside the detection philosophy, never a
default.

Which member an action may take in which container is a catalog fact
like everything else; what remains genuinely open is the acknowledge
flow of `freeze_act` (how the user clears a finding: a signed
acknowledgement? plain `elebake` command?) — decided with the
earlboot/elvbootd patches.
