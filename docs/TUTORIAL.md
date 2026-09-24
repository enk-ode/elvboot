# elebake tutorial — the full walk

A guided session, recorded live: every  command was typed on the target machine,
every  output below  is the  original (captured  via script(1)).   The companion
`docs/tutorial-replay.sh` accumulates  each successful command, so  any point of
this walk can be  reproduced into a fresh database at any time  — replays are an
architecture principle here, not an emergency measure.

Conventions:  the session  runs inside  `script ~/tutorial/transcript.txt`  in a
screen session. No configuration ever travels via environment variables (see the
isolation  excursus below)  — the  ONLY sanctioned  environment override  is the
database SELECTION  (ELEBAKE_BASE / ELEBAKE_ROOT),  and this walk does  not even
need that.


## 1. The birth of a database

elebake keeps a FAMILY of databases  under one root (default: `~/.elebake`); the
symlink   `db`  marks   the   ACTIVE  one,   and   `ELEBAKE_BASE`  defaults   to
`~/.elebake/db`   —  so   a   stock  installation   needs   no  environment   at
all.  `bootstrap <name>  <profile>` creates  the named  database AND  points the
active-DB symlink at it:

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

Note the last  line: `[db -> tutorial]` — bootstrap  moved the active-DB symlink
itself;  a manual  `ln -sfn`  is never  needed. The  name `db`  is reserved  for
exactly  this reason.  Switching  back to  another database  later  is `ln  -sfn
current ~/.elebake/db` (or a fresh bootstrap).

The layout: `.env/default`  holds the installed profile (the  interpreter pins —
act  families execute,  display families  page through  cat), `.env/local`  your
overrides; `pkcs11/openpgp/pem`  are the key backends,  `stage/` and `.staging/`
the stage records.

## 2. setenv — and why export does NOT work

The first real command in any new database:

```
$ ./elebake.sh setenv ELEBAKE_DISPLAY_ANSI 0
# Set ELEBAKE_DISPLAY_ANSI (effective next command)
```

Why not `export  ELEBAKE_DISPLAY_ANSI=0`? Because it would  do NOTHING.  elebake
isolates  its environment  by construction:  every interpreter  is executed  via
`run_env()` as `env  - PATH=... <vars from .env files>`  — the inherited process
environment is DISCARDED and rebuilt exclusively from the database, plus a short
passthrough  list  of  pure  infrastructure  (bootstrap  marker,  cache,  trace,
log). An exported configuration variable never reaches anything. Verified live:

```
$ ELEBAKE_INTERPRETER_stage_list=sh ./elebake.sh printenv | grep stage_list
... ELEBAKE_INTERPRETER_stage_list='cat' ...     # the DB value, untouched
```

Configuration has  exactly one home  (the database, via setenv),  one resolution
order (`.env/local`  over `.env/default` over  the template), and  one exception
(ELEBAKE_BASE/ELEBAKE_ROOT select WHICH database —  they must work from outside,
or nothing could find a database to read its configuration from).

## 3. Reading the environment

```
$ ./elebake.sh printenv
```

prints  the EFFECTIVE  environment —  exactly  what `run_env()`  hands to  every
interpreter, rebuilt  from the  database. The  whole pin model  is visible  at a
glance:  act families  on  `sh`,  display families  on  `cat`, the  ESP-touching
families     on    `sudo     sh`,     and    the     three    class     defaults
(`ELEBAKE_TERMINAL_INTERPRETER=cat` — safe by default  — plus the combinator and
batch interpreters). A single variable, with provenance:

```
$ ./elebake.sh getenv ELEBAKE_DISPLAY_ANSI
# Source: .env/local/ELEBAKE_DISPLAY_ANSI (override)
0
```

`local (override)` is your setenv from  chapter 2; an untouched variable answers
with `default` (the installed profile)  or `template`. `help` is fully GENERATED
from  the sources  — no  hand-maintained help  text exists,  so the  help cannot
erode. (`help  env <VAR>`  shows a variable's  documentation; on  databases from
before the multi-word command rework the same thing was spelled `helpenv`.)

## 4. Emit-and-inspect, lived once — with the REAL key

The examples  use the machine's  real secure-boot  signing key. The  record name
`uefi-db` says  what it  is: the key  of the UEFI  Signature Database  (db) that
authenticode-signs loader.efi.  (The production  database calls the  same record
just `db` — correct  too, but in a tutorial that word is  taken by the active-DB
symlink.)

The three-step that IS elebake:

```
$ ./elebake.sh getintp pem_record
# Source: /home/brj/.elebake/db/.env/default/ELEBAKE_INTERPRETER_pem_record (default)
sh
$ ./elebake.sh setintp pem_record cat
# Set ELEBAKE_INTERPRETER_pem_record (effective next command)
$ ./elebake.sh pem add uefi-db /root/secureboot/db.key /root/secureboot/db.crt
mkdir -p '/home/brj/.elebake/db/pem/uefi-db'
chmod 0700 '/home/brj/.elebake/db/pem/uefi-db'
echo '/root/secureboot/db.key' > '/home/brj/.elebake/db/pem/uefi-db/key'
echo '/root/secureboot/db.crt' > '/home/brj/.elebake/db/pem/uefi-db/cert'
chmod 0600 '/home/brj/.elebake/db/pem/uefi-db/key' '/home/brj/.elebake/db/pem/uefi-db/cert'
printf '# Registered pem key %s (paths only; material stays in place)\n' 'uefi-db' >&2
```

Under `cat` NOTHING happened — you read the shell that WOULD run. `pem add` is a
batch of  two lines:  the check  that the  name is  a record  name, and  the act
terminal  `pem  record`,  whose pin  you  just  set.  The  check ran  (it  is  a
combinator:  a comment  line,  else an  error  line), the  act  was shown.  That
emission  answers  the  important  question   by  itself:  this  works  although
`/root/secureboot`  is  unreadable  for  the calling  user,  because  `pem  add`
registers PATHS AS PROMISES — no file is read, copied or touched. A registration
command that could copy  a signing key would be the  wrong design; custody stays
with root.  The promise is  redeemed later, in  the right context  (`stage sign`
under its `sudo sh` pin) and checked by the prerequisites. Now let it act:

```
$ ./elebake.sh setintp pem_record sh
# Set ELEBAKE_INTERPRETER_pem_record (effective next command)
$ ./elebake.sh pem add uefi-db /root/secureboot/db.key /root/secureboot/db.crt
# Registered pem key uefi-db (paths only; material stays in place)
$ ./elebake.sh pem prerequisites
# prerequisites ok: pem
```

(Note what prerequisites checks here:  the signing TOOLCHAIN. The readability of
the promised paths surfaces at the stage level, where the sudo context exists.)

The attest key  — the OpenPGP key that detach-signs  the stage manifest; records
hold the key ID, custody stays with the keyring:

```
$ ./elebake.sh openpgp add manifest 77B2C2E8F5A4C6C7
# Registered openpgp key manifest
$ ./elebake.sh openpgp prerequisites
# prerequisites ok: openpgp
```

## 5. The stage and its key slots

A STAGE is the named workspace for exactly  one boot tree; the name says what it
is for  — `illyria-boot` is the  stage behind this machine's  boot anchor. Every
column below  is DERIVED  state: nothing is  cached, each line  is read  off the
artifacts at display time.

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

The two  key SLOTS bind  the chapter-4 records by  reference — the  same promise
logic, one level  up. The attest key  must be bound BEFORE the  build: its trust
anchor is  embedded into the  loader at build time,  so the binding  is building
material, not bookkeeping:

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

(`stage  sign-key`  with  a  hyphen   works  identically  —  the  one  tolerated
equivalence: hyphens in command words normalize to spaces.)

## 6. Connecting the source, checking out — and the first real find

The source is  the FreeBSD tree that carries the  platform-trust-gates series --
`https://github.com/johannes-bruegmann/freebsd-src`,                      branch
`platform-trust-gates-15.1` (based on releng/15.1). A stock tree has no catalogs
to offer, and everything from chapter 7 on would be empty.

Deliberately run WITHOUT the variable first — fail early is worth seeing once:

```
$ ./elebake.sh freebsd prerequisites
# Error: freebsd prerequisites: ELEBAKE_FREEBSD_SRC not set -- elebake setenv ELEBAKE_FREEBSD_SRC <path-to-freebsd-src>
$ ./elebake.sh setenv ELEBAKE_FREEBSD_SRC /home/brj/git/freebsd-src
# Set ELEBAKE_FREEBSD_SRC (effective next command)
$ ./elebake.sh freebsd prerequisites
# freebsd prerequisites ok (checked at generation time): git make clang; src: /home/brj/git/freebsd-src
```

> **A find  of this manual  pass.** The second  call was originally  SILENT: the
> success line was emitted as a bare `#` comment, which the sh pin executes as a
> no-op —  swallowed. Checks  may be  silent on success;  a REPORT  command must
> report,  to stderr.  Fixed  to  emit_note, and  the  architecture scanner  was
> hardened to catch  the pattern (including the multi-line printf  form this one
> hid behind).

The   checkout,  with   one   deliberate   detail  on   the   ref:  the   branch
`platform-trust-gates-15.1`  is already  checked out  in the  production stage's
worktree, and git  refuses the same BRANCH  in two worktrees —  while any number
may share a COMMIT. `^0` resolves the branch to its commit (detached), so stages
share the state  without fighting over the branch. Collisions  are impossible on
the   other   axes    too:   the   worktree   path   carries    the   stage   id
(`worktree/<stage-id>` under  the root), and  sharing the `.git` objects  is the
point — that is why this takes seconds instead of a second clone.

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

Note  `mkdir   -p`:  every   directory  emission   is  idempotent   by  doctrine
(MODIFY_DIR_CREATE)  — replays  must never  fail on  what already  exists.  `git
worktree add`  itself is deliberately NOT  idempotent: a second checkout  of the
same stage  is a  decision, not  a silent  overwrite; the  batch stops  at git's
error. Now act:

```
$ ./elebake.sh stage checkout illyria-boot platform-trust-gates-15.1^0 | sh
# freebsd prerequisites ok (checked at generation time): git make clang; src: /home/brj/git/freebsd-src
Preparing worktree (detached HEAD 59a2380128b)
Updating files: 100% (109084/109084), done.
HEAD is now at 59a2380128b stand: set st_dev/st_ino in the loader's ZFS stat for veriexec
# Checked out illyria-boot at platform-trust-gates-15.1^0 (worktree /home/brj/.elebake/worktree/stage-faa35dcef54e)
```

(That HEAD is  this machine's own story:  the commit is the  loader ZFS veriexec
fix this whole tutorial builds on.)

Open observation  from this chapter:  `stage status` shows  no checkout/worktree
aspect yet — the state exists (work symlink, checkout file) but the summary does
not surface it.

## 7. The catalogs: elebake reads the World

Four display commands, all parsed LIVE  from the headers of the stage's checkout
— nothing cached, nothing duplicated into the database:

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

> **Why aren't measure/action/when  part of the arsenal?** Because  they are not
> decisions but CAPABILITIES  — C facts, born as patches,  reviewed as code. And
> capabilities are VERSIONED: there is no "world as such", only the world of one
> checkout; another stage may sit on a state without `measure_ve_strict` or with
> actions  this one  lacks.  Hence  the provenance  line on  every catalog.  The
> formula: the ARSENAL is what you want (portable across stages), the CATALOG is
> what this state can  do (versioned) — and the BINDING  is the contract between
> the two. One  could defer all checking  to a final verify;  the design chooses
> layered safety instead: the binding checks early (where the error is cheap and
> the  message  precise),  `stage  foundation check`  re-verifies  right  before
> emission (the world may have drifted), and the C compiler stays the last line.

## 8. The arsenal, smallest complete chain: strictwatch

The soft  guarantee of  this system  — strict should  be active,  WATCHED, never
enforced. Built bottom-up; every `show` renders the C that WOULD be emitted.

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

A  CLAIM  marries a  catalog  measurement  to  an expectation  —  `<measurement>
<diagnose|-> <publish|-> <exp>`;  `-` renders as NULL, the  publish leaf becomes
`loader.trust.<gate>.<leaf>`  at runtime  (the  gate namespaces  it). Claim  and
expectation share a name here on purpose: the families have separate namespaces,
and matching names for matching things is good style. Note that `measure_strict`
is NOT checked against  the catalog now — add is dumb,  dangling is allowed; the
contract comes at the binding:

```
$ ./elebake.sh claim add strict-active measure_strict - strict.active strict-active
# claim 'strict-active' stored
$ ./elebake.sh claim add strict-marker measure_ve_strict - strict.marker strict-marker
# claim 'strict-marker' stored
$ ./elebake.sh claim show
# strict-active: CLAIM(measure_strict, NULL, "strict.active", MEASUREMENT_BYTE("StrictActive", 1))
# strict-marker: CLAIM(measure_ve_strict, NULL, "strict.marker", MEASUREMENT_BYTE("VeStrictPresent", 1))
```

The GATE is AND over its claims; the append order is the evaluation order (`gate
claim add ... [<position>]` inserts  deliberately). A gate  carries no  secret:
the loader compares no password (section 9). Gate names must be C identifiers:
they  land verbatim  in the  generate, and  `gate show`  now produces  the first
GATE_DEFINE that fell out of your decisions instead of being typed:

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

A TRIGGER is a named FIRE(when, action)  pair; the POLICY ties gate and triggers
together —  the detection core  in one line:  measure, compare, publish  — never
halt:

```
$ ./elebake.sh trigger add publish-always when_always publish_act
# trigger 'publish-always' stored
$ ./elebake.sh policy add watch-strict strictwatch
# policy 'watch-strict' created (gate strictwatch)
$ ./elebake.sh policy trigger add watch-strict publish-always
# policy 'watch-strict': trigger 'publish-always' appended
$ ./elebake.sh policy show watch-strict
# policy watch-strict:
#
#   POLICY_TABLE_DEFINE(watch_strict_bindings,
#       FIRE(when_always, publish_act));
```

Everything here is  idempotent-immutable: an identical re-add is  a silent no-op
(that is  what makes replays  safe), a DIFFERING re-add  under the same  name is
refused — change is drop + add, a name's meaning never shifts under its users.

A when can be a composition -- `and(a,b)`, `or(a,b)`, `not(a)`, nested -- and an
action  `compose(a,b)`,  several   in  order;  the  C   form  shows  `AND(...)`,
`NOT(...)`, `COMPOSE(...)`, the sh containers get `{ a && b; }` and `! a`:

```
$ ./elebake.sh trigger add report-measured 'and(when_fail,not(when_skipped))' report_act
# trigger 'report-measured' stored
$ ./elebake.sh trigger show report-measured
# report-measured: FIRE(AND(when_fail, NOT(when_skipped)), report_act)
```

## 9. bootlock & loaderlock: diagnose, baseline macros, the report

Board identity,  secure-boot keys and the  boot marker have no  values one could
type today — they are measured at  PROVISIONING time and arrive at BUILD time as
-D macros from  site.mk. A `macro` record describes that  slot, and `macro show`
displays all three derivations:

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

The guard  is the site.mk  convention (`LOADER_TRUST_<NAME>`), the  defined name
replaces `_DIGEST`  with `_EXPECTED`, and  `MEAS_SHA256` comes from the  World —
`enum  meas_type` in  measurement.h: even  a measurement  WITHOUT a  baseline is
typed, and the `#else` branch means UNPROVISIONED IS NOT WRONG — the claim skips
instead of  lying. (Both  the `#else`  alternative and the  defined name  can be
overridden: `macro add <MACRO> <type> <label> [<else>] [<defined>]`.)

KEYS_DIGEST  and MARKER_DIGEST  follow the  same shape;  the macro  expectations
reference   the  DEFINED   names  (`expectation   add  board-expected   macro  -
BOARD_EXPECTED`) — recorded first, referenced  after, verified sharply by `stage
foundation check`.

The bootlock claims bring the second claim field to life — DIAGNOSE: `measure_*`
only measures a value; `diagnose_*` (where  the catalog offers one) delivers the
WHY  of  a  finding  into   the  appraisal  —  `diagnose_keys`  publishes  WHICH
secure-boot  keys deviate,  `diagnose_marker`  the marker  details. The  publish
leafs `board.sha256` and `keys.sha256` publish the MEASURED hashes as evidence:

```
$ ./elebake.sh gate add bootlock
# gate 'bootlock' created
$ ./elebake.sh gate show bootlock
# GATE_DEFINE(bootlock,
#     CLAIM(measure_secureboot, NULL, NULL, MEASUREMENT_BYTE("SecureBoot", 1)),
#     CLAIM(measure_setupmode, NULL, NULL, MEASUREMENT_BYTE("SetupMode", 0)),
#     CLAIM(measure_marker, diagnose_marker, NULL, MARKER_EXPECTED),
#     CLAIM(measure_board, NULL, "board.sha256", BOARD_EXPECTED),
#     CLAIM(measure_keys, diagnose_keys, "keys.sha256", KEYS_EXPECTED));
```

The head  carries the name  and nothing else.  Earlier versions took  a second
argument here, the -D macro of a passphrase hash compiled into the signed loader,
and a third for a duress hash; on 16.09. they went. The reason is the threat
model: the loader lives on the medium the owner carries, so whoever has the
medium has both hashes and can check offline, with a passphrase in hand, which
of the two it is — the one thing a duress passphrase must never allow. The
loader now compares no password at all. Its one dialog asks the GELI passphrase
and applies the three factors as they are — passphrase, the key file on the
medium, the key file the TPM releases under its PCR policy — to the encrypted
providers; a provider that opens is the only proof, and it exists only on this
machine with unchanged firmware. Gates measure and publish; none of them halts,
none of them asks.

loaderlock guards the loader's own prerequisites; its expected values are HEADER
CONSTANTS     —     an    expectation     value     is     verbatim    C,     so
`LOADER_PREREQUISITES_EXIST_N` is a perfectly good expected value.  The backstop
policy carries TWO fires — publish always, and on failure `report_act`, the line
on the console that says which claims fell, then "Press any key to continue, x
to power off": any key goes on, loudly, and the record carries the failure; x
raises the halt counter (`loader.trust.halt.nv`, the HaltQuiet claim) and powers
off, so the halt the owner chose at the report leaves the same trace as any
other. Note `publish-always` being REUSED across all three
policies: that is the arsenal idea at work.

```
$ ./elebake.sh policy add backstop-loaderlock loaderlock
# policy 'backstop-loaderlock' created (gate loaderlock)
$ ./elebake.sh policy trigger add backstop-loaderlock publish-always
# policy 'backstop-loaderlock': trigger 'publish-always' appended
$ ./elebake.sh policy trigger add backstop-loaderlock report-fail
# policy 'backstop-loaderlock': trigger 'report-fail' appended
```

## 10. The binding: where the arsenal meets the catalog

A deliberate negative first — the contract, snapping shut once:

```
$ ./elebake.sh stage phase policy add illyria-boot PHASE_KERNEL watch-strict
# Error: stage phase policy resolves: unknown phase PHASE_KERNEL (stage phase show illyria-boot lists them)
```

`stage phase policy  add` is check-then-act: `check stage` ->  `check policy` ->
`append`. PHASE_KERNEL is not in this checkout's enum, so the batch stops before
anything is written.  `check policy` validates the TRANSITIVE chain  — policy ->
gate -> claims -> expectations  (including macro resolution: BOARD_EXPECTED must
be produced by a macro record) and policy -> triggers -> whens/actions — against
the catalog of THIS stage's checkout. The real bindings pass:

```
$ ./elebake.sh stage phase policy add illyria-boot PHASE_BOOT publish-bootlock
$ ./elebake.sh stage phase policy add illyria-boot PHASE_LOADER backstop-loaderlock
$ ./elebake.sh stage phase policy add illyria-boot PHASE_LOADER watch-strict
```

The binding order is the table order in the C (a `[<position>]` argument inserts
deliberately), and the detail view now renders the table exactly as the emission
will write it:

```
$ ./elebake.sh stage phase show illyria-boot PHASE_LOADER
#   policy: backstop-loaderlock
#   policy: watch-strict
#
# POLICY_TABLE_DEFINE(backstop_loaderlock_bindings,
#     FIRE(when_always, publish_act),
#     FIRE(when_fail, report_act));
#
# POLICY_TABLE_DEFINE(watch_strict_bindings,
#     FIRE(when_always, publish_act));
#
# static const struct policy loader_policies[] = {
# 	POLICY(loaderlock, backstop_loaderlock_bindings),
# 	POLICY(strictwatch, watch_strict_bindings),
# 	POLICY_END,
# };
```

## 11. The harvest: stage foundation

The sharp re-verification  answers its caller (the world may  have drifted since
the bindings were made — checkout switch, arsenal drop):

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

foundation.c  now sits  in  the  worktree —  compiled  from  the database.   Its
generated-by header carries DETERMINISTIC  provenance (stage name, checkout ref,
the  worktree's git  HEAD); deliberately  no  timestamp, which  would break  the
hardest guarantee of  the design: after dump/restore the  target REGENERATES THE
IDENTICAL FILE. License and author lines are the user's decision, entered once:

```
$ ./elebake.sh setenv ELEBAKE_SPDX BSD-2-Clause
$ ./elebake.sh setenv ELEBAKE_COPYRIGHT '2026 Johannes Bruegmann'
$ ./elebake.sh stage foundation make illyria-boot
```

The acceptance, done  by hand — against  the committed truth of  the branch (the
hand-written original only exists there):

```
$ git -C ~/git/freebsd-src show platform-trust-gates-15.1:stand/efi/loader/local/foundation/foundation.c \
    | diff - ~/.elebake/worktree/stage-faa35dcef54e/stand/efi/loader/local/foundation/foundation.c
```

The diff  shows ONLY:  the prose comments  (which move to  policy.h by  design —
foundation.c is  generated-only now), the  order of two preamble  #ifdef blocks,
and  claim-line whitespace.  Every  active  C line  is  identical.  That is  the
structural acceptance of the design, reproduced live from this database.

## 12. site mk: measuring THIS machine

Provisioning begins. `stage  site mk` measures the machine AT  GENERATION TIME —
and that is a lesson in itself:  interpreter pins govern EMISSIONS, but what the
generator  itself  must  measure  needs the  OUTER  context.  Reading  PK/KEK/db
requires root,  so the  generator runs  under sudo,  with the  database selected
explicitly (the one legitimate environment exception — and under sudo mandatory,
since root's HOME would find the wrong database):

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

This closes  the macro loop of  chapter 9: the two  `-DLOADER_TRUST_*` lines are
exactly  what the  BOARD_DIGEST/KEYS_DIGEST  slots receive  at  build time;  the
marker slot  stays asleep (`MEASUREMENT_NONE`  — the  claim will SKIP,  not lie)
until a marker  is bound. The digests are this  machine's fingerprints — site.mk
never enters git, and this tutorial redacts them.

The  `exit 137`  seen on  the failed  first try  is the  batch exit  arithmetic:
fail-fast encodes WHERE the  batch stopped into the exit code  for callers — the
odd number is by design.

After  a tool  update, one  command syncs  the new  template variables  into the
database — the idempotent post-update ritual:

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

License and author are  the USER's decision, entered once via  setenv — never an
implicit default. `stage  site mk report <stage>` shows the  written site.mk any
time (this 1-arg form  was the seventh find of this pass: it  only existed as an
internal 2-arg batch building block).

## 13. The prerequisites lists: decisions leave the C

The loader's  prerequisites arrays (the  .lua chain  that must EXIST,  the files
that must VERIFY against  the manifest) were historically hard C  — but they are
pure DECISIONS,  so they moved into  the database: per-stage lists  that elebake
emits into  the generated  foundation.c exactly when  the checkout  expects them
(extern  declarations  in measurement.h  —  old  checkouts stay  untouched;  the
catalog decides).

The stdin form  makes the source dictate  the list — a  FROZEN snapshot, sixteen
entries in one pipe:

```
$ ls ~/.elebake/tutorial/.staging/stage-*/destdir/boot/lua | sed 's|^|/boot/lua/|' \
    | ./elebake.sh stage prerequisites exist add illyria-boot -
# prerequisites exist of illyria-boot: + /boot/lua/cli.lua
...
# prerequisites exist of illyria-boot: + /boot/lua/screen.lua
$ ./elebake.sh stage prerequisites verify add illyria-boot /boot/loader.conf
$ ./elebake.sh stage prerequisites verify add illyria-boot /boot/device.hints
$ ./elebake.sh stage prerequisites verify add illyria-boot /boot/loader.efi.signed
$ ./elebake.sh stage prerequisites verify show illyria-boot
# prerequisites verify of illyria-boot
#   /boot/loader.conf
#   /boot/device.hints
#   /boot/loader.efi.signed
```

The third  verify entry is this  tutorial's own contribution to  the design: the
manifest-covered loader  RESERVE is now checked  by verified read on  every boot
(an unverified reserve is not a reserve). The short spelling `stage prereqs ...`
works for everything except `add -`  (an alias combinator's child cannot inherit
your stdin — the long form keeps the pipe).

> Safety default, remembered: every UNPINNED terminal displays instead
> of acting (ELEBAKE_TERMINAL_INTERPRETER=cat). Experienced users flip
> it once: `elebake setenv ELEBAKE_TERMINAL_INTERPRETER sh` — and
> inspect single commands via `setintp <family> cat` when wanted.

## 14. One to one: the stick becomes the card

The  goal was  never  a new,  minimal  boot tree  —  it was  the  SAME tree  the
production card  carries, produced by  an empty  database. That is  a measurable
claim, so  it is  measured: the  stage's `boot/` must  be diff-identical  to the
production stage's `boot/`,  except for the four files an  empty database has to
produce itself — `loader.efi`, `loader.efi.signed`, `manifest`, `manifest.asc`.

The curation is therefore not invented, it is read off the reference:

```
$ ls ~/.elebake/current/stage/smoke1/boot \
    | grep -vE '^(loader\.efi|loader\.efi\.signed|manifest|manifest\.asc)$' \
    | ./elebake.sh stage filter add illyria-boot -
$ ./elebake.sh stage include illyria-boot ~/.elebake/current/stage/smoke1/boot
# Included 72 filter entries into boot/ of stage illyria-boot
$ diff -rq ~/.elebake/current/stage/smoke1/boot \
           ~/.elebake/tutorial/stage/illyria-boot/boot | grep -vE 'loader\.efi|manifest'
```

Empty output. Every  .4th file, dtb/, firmware/, keys/,  the curated loader.conf
with  its  password  control,  loader.ve.strict, the  kernel  —  identical.  The
two-argument form of `stage include` made  this a normal operation rather than a
special case: the same curated filter list, applied to a chosen source.

## 15. The RSA lesson: libsecureboot verifies OpenPGP RSA only

The first boot of the stick failed, and the log read like a chain of dominoes:

```
Unverified ta_ASC: Testing verify OpenPGP signature: Failed
Unverified /boot/manifest
*** loaderlock: verification failed [PrereqsVerify] ***
ERROR: cannot open /boot/lua/loader.lua
OK (LoaderPrompt)
```

The     root      cause     is      one     sentence     in      the     sources
(`lib/libsecureboot/openpgp/opgp_sig.c`):  *"We only  support RSA"*.  The attest
key that  had been bound was  the ed25519 key on  the smartcard — so  the loader
could not even  verify its own compiled-in trust  anchor.  Everything downstream
follows:  manifest unverified,  loader.conf unverified,  `password_sha256` never
set, the Lua chain never loaded, and an UNPROTECTED loader prompt.

Two things to take away:

1.  **The attest  key must  be  RSA.** The  production  card had  always used  a
   separate RSA software key for exactly this reason; it lives in root's keyring
   (`/root/.gnupg`),  and the  key record  carries that  location: `openpgp  add
   manifest <keyid> /root/.gnupg`. The `trust  anchor` and `attest` families run
   under `sudo sh` because the key does.
2. **The prompt protection is fail-open  today.** It lives in loader.conf, which
   is itself subject  to verification — when verification  fails, the protection
   falls with it. The fix belongs  in the design's follow-up package: the prompt
   hash as a  site.mk slot compiled into the SIGNED  loader, the same philosophy
   the gate secrets already follow.

After rebuilding with the RSA anchor (the anchor is compiled in, so a rebuild is
mandatory),  signing, and  pushing  again, the  stick  booted: anchor  self-test
passed, manifest verified, Lua loaded, the prompt protected. bootlock did fire —
the stick carries  no boot marker, so  the BootMarker claim falls  short and the
gate asks for the  bootlock password. That is not a defect;  it is the detection
system doing its work on its first encounter with a new medium.

## 16. The daily stage: one cycle, and why it is long

The  production  stage  is  `daily-v1`;  its medium  is  the  microSD  card  `b`
(`/dev/da1p1`,  GPT label  `sdcard-zkey`,  dataset `zkey/boot-illyria`).   Every
change to  the loader  sources or to  the stage's records  runs the  same cycle,
typed in this order and never abbreviated:

```
elebake stage recheckout daily-v1 ptg-15.1-next^0
elebake stage trust daily-v1
elebake stage foundation make daily-v1
elebake stage site mk daily-v1
elebake stage loaderconf mk daily-v1
elebake stage build daily-v1
elebake stage install daily-v1
elebake stage include daily-v1
elebake stage sign daily-v1
elebake stage earlboot mk daily-v1
elebake stage earlboot install daily-v1
elebake stage elvbootd mk daily-v1
elebake stage elvbootd install daily-v1
elebake stage push daily-v1 b
elebake stage marker write daily-v1 restore | sudo sh
```

`recheckout` replaces  the worktree  with the  named ref  (a second  checkout is
refused, on  purpose); `trust` exports the  OpenPGP anchor into the  worktree --
`build` refuses without  it, because a loader built without  its anchor verifies
nothing and  opens the prompt.  `foundation make`  renders the gates,  `site mk`
measures this machine and renders the baselines, `loaderconf mk` writes the kenv
records   into    `boot/loader.trust.conf`,   `build`/`install`/`include`/`sign`
produce  the boot  tree, the  two `mk`/`install`  pairs generate  and place  the
hooks, `push` writes the card, and the  marker is written last, from root's copy
of the recorded value. Two things learned the hard way: the card reader may drop
off the USB bus after a boot  (`push` then says "device not present: /dev/da1p1"
-- re-seat the reader, not the card), and a second tap at "Press any key" or the
Enter  that chose  the  card in  the  firmware menu  used to  land  in the  GELI
passphrase;  every  hidden  prompt  drains  the  keyboard  first  now,  and  the
passphrase is typed when the prompt stands.

## 17. The record chain: the loader proves it was here

The kernellock gate carries  four claims that need a *record*:  a sealed note in
NVRAM (`ElvRecord`) the loader writes after every  boot and reads at the next --
counter,  boot time,  TPM reset  count  and clock,  NVMe power  cycles, a  chain
link. `RecordValid` opens it, `CounterStep`  checks that every anchor stepped by
exactly  one,  `ChainOnMedium`  matches  the link  against  the  medium's  copy,
`LastBootGap` the time between boots.

The key that seals it is derived from the  GELI user key of the root -- the same
passphrase and key  file the kernel uses  -- plus the *boot  answer*, one hidden
line typed twice. The loader derives  the key itself (`geli_keys.c`): it decodes
the GELI metadata of every partition the firmware shows, keeps the providers the
kernel  attaches at  boot (`geli  init -b`;  libsa's own  taste keeps  only `-g`
providers, which is why the first  attempts saw "no GELI partition"), feeds each
provider its own key  files as the kernel does, and stops at  the first key. Its
verdict is readable after the boot:

```
$ kenv loader.trust.kernellock.record
geli=f226d506,counter=6,last=2026-09-12T09:21:27,bootms=113470,flags=4,chain=match
$ kenv loader.trust.kernellock.anchors
tpm.reset=230/229,tpm.nv=2056/2056,tpm.clock=24985188/24594102,safe=0,nvme.cycles=187/186,unsafe=8
```

`geli=` is  a keyed  fingerprint of the  GELI part: equal  across boots  iff the
derived key is; when  a record is present but invalid, it  tells whether the key
or the answer moved. Two assumptions the  design makes and states: the TPM clock
is saved orderly only  when the OS shuts the TPM down  -- FreeBSD's `tpm.ko` was
not  loaded on  illyria, so  `kld_list+="tpm"` went  into rc.conf;  and a  wrong
answer  breaks the  chain silently,  by design  (a record  then proves  the PAIR
passphrase and  answer) -- which  is why the answer  is confirmed at  entry. The
boot budget is the GELI dialog's: `loader.trust.geli.tries` lines (three when
unset), then the boot halts and the reboot is the retry -- the whole chain from
the start, nothing cached, nothing sticky. The record's derivation is a fresh
attempt per line, so a typo costs one derivation, not the boot's record (a
typo cached by the old Lua prompt once poisoned the one attempt per boot).

The manual path, when the Lua chain  aborts (it did once, over a missing `table`
library): at the prompt the modules  are loaded by hand -- `load mac_veriexec_sha256`,
`load mac_veriexec`, `load  mac_bootlock`, `load geom_eli`, `load  zfs`, the key
files with `load -t <prov>:geli_keyfile0 /boot/keys/zroot.key`, then `boot`; the
dialog runs in the KERNEL phase as always. The record stayed valid across that boot.

## 18. Learning the witnesses, and what moves

A  digest baseline  is  learned from  the  kenv of  a trusted  boot,  and it  is
immutable -- a changed value needs `drop` first:

```
elebake stage baseline drop daily-v1 LOADER_TRUST_ACPI_DIGEST
elebake stage baseline learn daily-v1 LOADER_TRUST_ACPI_DIGEST loader.trust.inventory.acpi.sha256
```

Three witnesses fell on the boots right after they were learned, and each taught
something:

- `SoftPcr`, libsecureboot's  running hash over the files  it verified, differed
  between two  boots of identical  files. Recomputed offline from  the manifest,
  the two  values were the  same sixteen files in  a different *order*:  the Lua
  loader walked its module table with  `pairs()`, whose order is not stable from
  boot to boot. The  modules load in name order now  (sorted without the `table`
  library, which the loader's Lua does not carry).
- `AcpiTables` and `EfiVariables` hashed  everything the firmware shows, and the
  firmware  rewrites some  of it  every boot.  Instead of  guessing, the  loader
  publishes the lists -- one entry per table and per non-volatile variable, with
  an 8-hex digest -- and elvbootd files them per boot. Two boots compared: of 43
  tables exactly  `PHAT` (the  platform health record)  moved, of  117 variables
  exactly `MotherBoardHealth`.  Twenty of those variables  carry attribute NV+BS
  without  RT:  no  operating  system  can see  them,  only  the  loader  before
  ExitBootServices.
- `PcrBank` and `LoadedImages`  can never be compiled into the  loader: PCR 4 is
  the firmware's hash of  the loader image, and the loader is  one of the loaded
  images. Their expectation is read from the conf instead.

The mechanism  that came out  of it has add  semantics, never an  exclusion: the
stage names the SET a claim measures.

```
elebake stage inventory import daily-v1        # root's per-boot lists into the stage
elebake stage inventory show daily-v1 efivars  # side by side: size, attrs, boots, same|MOVES, in the set, digests
elebake stage inventory add daily-v1 efivars 8be4df61/BootOrder
elebake stage inventory add daily-v1 acpi FACP/ARL
elebake stage inventory list daily-v1 acpi
```

An ACPI table is identified as `<signature>/<OEM table id>` -- thirty SSDTs tell
apart only  so -- an EFI  variable as `<guid's first  word>/<name>`. `stage site
mk` renders the  sets (`stage inventory make`), sorted, so  the digest runs over
the members in a fixed order; an empty set claims nothing. To take in everything
that held across all imported boots:

```
elebake stage inventory show daily-v1 acpi | awk '$5 == "same" { print $1 }' \
    | while read -r e; do elebake stage inventory add daily-v1 acpi "$e"; done
```

And the two  values the loader is  part of are `key`  expectations, learned into
the kenv, carried by `loaderconf mk`, `include`, `sign`, `push` -- no build:

```
elebake expectation add pcr-expected key PcrBank pcr.expected
elebake claim add pcr measure_pcr - pcr.sha256 pcr-expected
elebake stage require daily-v1
#   loader.trust.kernellock.pcr.expected  (claim pcr)  MISSING -- stage kenv learn ...
elebake stage kenv learn daily-v1 loader.trust.kernellock.pcr.expected loader.trust.kernellock.pcr.sha256
```

`stage kenv` is the family formerly  called `conf`: the records are the loader's
kenv lines, the counterpart of `baseline` (compiled) is what the loader reads at
run time. earlboot  adds the second witness for  both: `measure_pcr_agree` reads
PCR  0..7   from  the  TPM   itself  and   compares  with  the   loader's  word,
`measure_images_expected` the  loader's LoadedImages  with the stage's  value at
generation time.

## 19. Where the walk stands

Boot  E of  `daily-v1`, 13  September: every  gate green,  the ledger  without a
failed gate, record counter  16, the chain intact, no claim  skipped any more --
the three  inventory sets are adopted  (acpi 40 identities, efivars  116, images
253 of 333; the  50 images whose data sections move between  boots stay out, the
loader itself is covered by the PCR bank), and the PCR bank is a key expectation
the kenv  answers. The  database is published:  `elvboot-dump-publish.sh` writes
the attested,  encrypted dump into  the private repository  `elvboot-dump` under
`<host>/<db>/` and the export bundle beside it, serial 4 today; both passphrases
are   on   paper   first   (hkdf-tree   `brj/cold-storage/elvboot-dump-v1`   and
`elvboot-export-v1`), never in  a shell. The time windows (BootWindow  300 s for
now)  wait  for a  series  of  settled boots  --  the  times measured  during  a
walkthrough,  with  questions in  between,  are  an  attacker's times,  not  the
owner's. Open, and decided together as they  come: the restore probe of the dump
into a  second database, the  earlboot witnesses  bound into custody  once their
values exist, a uniform verb for `mk`/`make`, and the pipeline in one command.

## 20. The restore probe: the database on a second machine

A backup that was never restored is a  hope. On 13 and 14 September the database
left the laptop:  `elvboot-dump-publish.sh full` wrote the attested  dump into a
private  repository  and  the  export  bundle beside  it,  both  encrypted  with
passphrases      that      exist       on      paper      first      (hkdf-tree,
`brj/cold-storage/elvboot-dump-v1`  and  `elvboot-export-v1`),   and  the  older
desktop received them:

```
elebake bootstrap probe minimal
elebake openpgp add archive 7CD2BCDFF6D8567A
elebake setenv ELEBAKE_ARCHIVE_ATTEST_KEY archive
elebake import /tmp/ram/dump.sh /tmp/ram/7.tar.gz
```

Four serials it took, and each one paid for itself:

- **Serial  4** stopped at  the first `stage inventory  add`: the add  demands a
  record that  lists the identity, the  bundle carried the records,  but no dump
  line imported them  -- on the source  machine they had always  been there. The
  dump imports the records first now.
- **The  bootstrap took two  minutes** on the  old machine: before  any database
  exists  the engine  had bound  its scratch  to `${TMPDIR:-/tmp}`,  an implicit
  default of  the kind  the tool forbids,  and every one  of the  ~330 bootstrap
  lines rebuilt  the environment from 311  template files. The scratch  lives in
  the database being created now, and init ends with the environment cache on.
- **Serial 6** failed on `stage import daily-v1 . …/work`: the dump imported the
  work symlink, the collection had never bundled it.
- **Serial 7**  ran to the end  -- signature, seal, a manifest  of 1367 entries,
  every record  -- and failed  only in its  closing `stage build`:  the checkout
  record  named `ptg-15.1-next^0`,  a ref  of the  laptop's repository,  and the
  dangling work link passed  for a worktree. The record names  the commit now, a
  dangling link is no worktree, and  the dump closes with `stage rebuild`, which
  without a worktree names the way instead of failing.

The import  itself is a replay  of some 600  lines, each an elebake  process: 22
minutes on  the old  desktop. Two changes  took the count  down from  about 5600
process starts to under 200 -- the  three inventory sets travel as files (`stage
import  <stage>  inventory <file>`,  three  lines  for  what  had been  240  add
batches), and the boot tree is one  `stage import tree` line instead of one line
per file. The next  lever, lines of a batch in one process,  is an engine change
and waits for its plan.

Then the  comparison. On the desktop  the worktree is re-anchored  from the same
fork -- `stage checkout daily-v1 platform-trust-gates-15.1`, 109111 files -- and
`stage require  daily-v1` prints on  both machines the  same 34 lines:  the five
kenv  leafs the  bound actions  read, the  one key  expectation, every  baseline
provisioned, the  three digests that have  no value yet. The  database describes
the same chain wherever it is.

The probe is passed:  `stage require daily-v1` prints the same  34 lines on both
machines, and the database  on the desktop was made by  the dump's own commands,
checked by  their own predicates,  in order. What  the 22 minutes  taught became
`elebake-binary.sh` the  same day:  the import  in one  process, the  anchors as
functions, every emitted line  a call -- 20 seconds for the same  dump, 25 on an
empty database. Serial 8, the same database with its boot tree, on the desktop's
disk: 19 minutes per process, 55 seconds in one -- since 15.09. the binary is an
override  of `process_arguments`,  `"$ELEBAKE_CONTEXT_SCRIPT"`  is the  engine's
`main` and `env` a function, so the batch runner and the exit arithmetic are the
engine's  own. On  the laptop  itself,  serial 8  into an  empty database:  2:28
minutes per process,  7.3 seconds in one;  the six failing lines at  the end are
the rebuild, which  needs the trust anchor that never  travels. Its second name,
`elebake-compile.sh`, writes the script instead  of running it; compiled against
an  empty database  that script  has 862  error fragments,  because a  predicate
judged at  compile time is  an answer in  the script, not  a check --  the order
survives, the state does not. The interpreter is for import; the compiled script
is for reading.

What does  not travel, on purpose:  key material.  `stage trust`  on the desktop
fails at once -- the attest key record names `/root/secureboot/manifest/.gnupg`,
a keyring  that exists  on the laptop  and nowhere else.   Building on  a second
machine is an air-gap decision, not a side effect of an import; the boot tree in
the bundle is what a rescue needs, and it is there.

## 21. Three factors: knowledge, possession, this device

16 September. The encrypted root opens with three things, and with nothing
less: a passphrase the owner knows (`fde-daily-v1`), the key file on the boot
medium the owner carries (`/boot/keys/zroot.key`), and 32 bytes this laptop's
TPM releases only under its PCR policy -- firmware code, option ROMs and the
Secure Boot state unchanged (`tpm-reflected-v1`, sealed as `0x81010001`).
GELI takes the two key files in the kernel's order, zroot.key then the
TPM's, folds them with the passphrase into the user key, and the master key
opens or it does not. The
TPM bytes decrypt nothing by themselves; they are the second key file, as
they are.

The loader changed for this, and the change is a subtraction. It compares no
password any more: no unlock secret, no duress secret, no console lock, no
loader-prompt password. The reason is the threat model, not taste. The
loader binary lives on the medium the owner carries, so an attacker who has
the medium has any hash compiled into it; with a passphrase in hand he could
tell, at home, which of two hashes it matches -- and a duress passphrase is
worth exactly nothing once that is possible. So the gates measure and
publish, none of them halts, none of them asks; the one dialog of the boot
asks the GELI passphrase and applies the three factors to the providers
(`geli_open.c`, `loader.trust.geli.tries` lines, then a halt whose retry is
the reboot). Keys reach the kernel in the keybuf; the kernel asks nothing.
The TPM key file is released first thing in the KERNEL phase, before any
gate runs and before anything is typed (`loader.trust.tpm.keyfile.*`, the
boot's own leafs in `template/tbl/boot-leafs.tbl`; `stage require` lists
them, `stage loaderconf mk` insists on them). Duress classification lives
behind the encrypted root, in earlboot's answer gates, and nowhere else.

The rollout, three boots of card b:

- **Two factors, new loader.** `tpm.keyfile="unsealed=1,providers=0"`: the
  TPM opened, nothing was added yet, slot 0 still took passphrase and
  zroot.key. The first attempt landed at the loader prompt: the old
  password.lua had started the autoboot itself when a password hash was
  set, the stock one does not, and `autoboot_delay="NO"` means "never boot
  by yourself". It is `"-1"` now. And `stage loaderconf mk` belongs to
  every command group after a kenv change -- the trust conf on the card was
  the old one, and the TPM leafs were not there.
- **Slot 0 re-keyed.** `geli setkey -n 0 -K zroot.key -K tpm.bin` on both
  providers, after a probe on an md volume that opened with both files and
  refused with one. The metadata backups went into the owner's repository.
- **Three factors.** `tpm.keyfile="unsealed=1,providers=2,added=2,ok"`,
  every gate green but recordlock: the record is keyed from the GELI user
  key, the user key changed with the slot, so the previous record cannot be
  checked once and a new chain starts at counter 1 (record.c says so). The
  next boot closed it. A mistyped boot answer the boot after that made
  Attempts 4 instead of 3 -- the tell working, not a fault.

Two findings the cards taught, decided on the same day: PcrBank hashed PCR 0
to 7, and PCR 5 measures the GPT of the boot disk, so two cards of unequal
size never agree; the claim now takes `loader.trust.kernellock.pcr.require`
(`0,1,2,3,4,6,7` here). And the chain on the medium is one chain for all
media: a boot from the reserve card leaves the daily card behind, and that
deviation is not healed silently -- it asks for an informed decision, the
unlock with the one passphrase left in the loader, `loader-prompt-v1`, with
no second role a hash could give away.

The provisioning moved into the tool the same night: `stage tpm key`,
`stage tpm policy`, `stage tpm seal <stage> owner|duress <secret-file>`,
`stage tpm counter`, `stage tpm probe` and `stage tpm clean` render the
tpm2-tools commands from the stage's leafs (`loader.trust.tpm.key.handle`,
`keyfile.handles`, `keyfile.pcrs`, `counter.nv`), run as root on the RAM
disk, the passphrases read hidden, twice -- the playbook shrank to six
lines. And the sequences that were typed from memory during the walk --
rebuild, pcr-learn, kenv-change, baseline-relearn, inventory-drop,
policy-change, tpm-seal, restore -- are files now: `elebake workflow`
lists them, `elebake workflow show rebuild` prints one, commands and the
comments between them, to read and to type after.

## 22. The time anchor: two clocks the setup cannot turn back

24 September. Every witness so far answers "is the machine the same?"; none
answers "how long was it out of my hands?". Wall time is the RTC, and the RTC
is a setup menu: anyone with the supervisor password -- or, on this board,
anyone at all after a pull of the CMOS battery -- sets it. A stolen laptop can
come back with the date of the day it left. Two clocks on the board do not
turn back: the TPM's clock (it only counts while powered, and its reset
counter tells a power loss apart from a pause) and the NVMe's power-on hours.
The anchor makes the RTC answer to both, and it makes the previous boot
answer for this one.

The parts, in the order the workflow `time-anchor` adds them
(`elebake workflow show time-anchor`):

- **Six leafs**, gate-free, in `boot-leafs.tbl`: the anchor index
  `loader.trust.tpm.anchor.nv` (0x01c10e22), the shutdown index
  `tpm.shutdown.nv` (0x01c10e23), the cap PCR `tpm.cap.pcr` (14 -- in neither
  `pcr.require` nor `keyfile.pcrs`), `storage.gap.max.days` (7),
  `clock.skew.s` (300) and `smart.step.units.max` (64 NVMe data units of
  512,000 bytes: a boot reads a handful, a clone of the disks reads
  terabytes). Two more name a firmware variable and a byte range in it,
  `firmware.counter.var` and `firmware.moving.var` (below).
- **Two NV indices**, both under a PCR policy over the cap PCR: the anchor
  index is writable while PCR 14 is in its boot state, the shutdown index
  only after the loader has extended PCR 14 with the cap digest
  (sha256 of "elvboot cap"). So the loader writes the anchor -- record
  counter, TPM clock, NVMe hours -- then caps the PCR; from then until the
  next reset nothing can rewrite the anchor, and only the running system can
  write the shutdown index. `stage tpm anchor daily-v1` renders the
  tpm2-tools for both (an interpreter pin, `sudo sh`, runs them on the RAM
  disk); `stage tpm status` lists them beside the counter.
- **Four claims in recordlock** (an unlock when one falls): StorageGap, the
  unpowered time since the previous boot -- the RTC advance minus the TPM
  clock advance -- against `storage.gap.max.days`; ClockOrder, the RTC
  advance against the TPM clock and the power-on hours, within
  `clock.skew.s`; SmartStep, the disks' counters now against what the
  shutdown index recorded at the last clean shutdown; AnchorValid, the pair
  in the TPM against the record.
- **Five tells in a new gate, tellwatch**, which publishes and never asks:
  MediumSwitch (the letter stamped on the medium, `EFI/elvboot/medium`,
  written by `stage push`, against the record's), UnsafeStep (the NVMe
  unsafe-shutdown count), EfiVarsForeign (non-volatile variables the
  firmware shows that are neither in the learned set nor in
  `LOADER_TRUST_EFIVARS_KNOWN`, every variable any inventory record ever
  listed -- a health counter that moves every boot is known, not foreign),
  FirmwareBootStep and FirmwareMoved.
- **The runtime side**: elvbootd writes the shutdown index at SHUTDOWN
  (`smart_anchor_act`; the log says `shutdown anchor written: hours=1030
  read=541319 written=34690100 medium=a`), earlboot warns at login after an
  unclean shutdown (gate shutdownwatch: `warn_shutdown_act` into the motd),
  and PERIODIC checks the NTP offset (`ntp-gap`, 600 s -- PERIODIC only: at
  STARTUP ntpd has not synchronised yet, and an armed claim without a
  measurement fails) and `health-unique`.

FirmwareBootStep and FirmwareMoved came out of the inventory. The Insyde
firmware keeps a variable `MotherBoardHealth`, sixteen bytes, and the
EfiVariables digest fell on every boot until the inventory showed why: bytes
8 to 11 count the firmware's boots, bytes 0 to 7 change every time. Left out
of the set the digest is stable again; the variable was noise. Read as two
leafs (`<guid>-MotherBoardHealth:8:4` and `:0:8`) it is two witnesses: the
firmware's own boot counter must step by exactly one across the owner's
shutdown -- it counts the POSTs that reach a boot medium, so a boot into the
boot manager or from another medium costs a step, a setup visit ended at the
logo does not -- and the moving part must not repeat any of
the last four the record kept (`firmware.moving="now=5b48c9309,kept=
5b78a6a7b,5ba8dade5,0,0"`), nor, in PERIODIC, any of the whole history
(`measure_efivar_unique` over every inventory record). A firmware image put
back from a dump would repeat both.

The Attempts expectation changed with the anchor: it counts what the boot did
not ask for -- attempts minus two passphrases, minus the unlocks the gates
prompted for, minus the retries of the boot answer -- so its expectation is
0 (`attempts-zero`; claims are immutable, the claim was re-made on the new
expectation: gate claim drop, claim drop, claim add, gate claim add). And
the boot answer is typed once: the record's MAC proves it against the
previous record, and only when no record can be checked -- a new chain --
does the loader ask it again to confirm.

The rollout on card a, from a chain that had to start over:

- **The boot without gates.** `stage recheckout` leaves the checkout's
  foundation.c -- the empty one. The build that followed skipped
  `stage foundation make`, and the loader that came out had no gates: no
  prompt, no sentinel question, straight into the kernel. earlboot caught it
  from the other side (`custody fail [word-ok, taint-open, prompted-set,
  book-step]`), the reserve card was the way back, and the sequence is a
  file since: `elebake workflow show rebuild`. Two things the walk wrote
  down for the loader and the tool: a loader whose ledger is empty must not
  open the root, and a build from the checkout's empty foundation.c with
  policies bound must refuse.
- **Chain restart.** The repaired loader asked the sentinel question again;
  recordlock fell as a whole (RecordValid and, with it, every claim that
  measures against the record or the anchor -- an armed claim without a
  measurement fails), PcrBank fell (a new loader, a new bank), HaltQuiet
  fell: the halt counter had stepped when earlboot powered the machine off.
  `anchor="verified,differs,counter=1"` -- the anchor already there, from
  the boot before, correctly not matching a record it had never seen.
  EfiVarsForeign was 0 for the first time: the KNOWN list at work.
- **pcr-learn and halt-relearn together**, one `loaderconf mk`, one
  `include`, one `push`, no rebuild. The next boot: the chain closed
  (`counter=1, chain=match`, `anchor matches`), `storage.gap gap.s=11`
  (RTC 1046 s against TPM 1035 s), `smart.step units.read.diff=6,
  units.written.diff=20`, `firmware.counter 257/256`. One claim fell, and it
  was the rule, not the machine: ClockOrder compared the RTC advance against
  the power-on hours times 3600, and the hours had stepped from 1028 to 1029
  in an eighteen-minute pause. Whole hours at an unknown phase: a step of
  h hours proves only (h - 1) * 3600 seconds. The claim takes that lower
  bound now (measure_record.c), a step of one hour proves nothing.
- **The fix, one more bank**, PcrBank once more, learned once more; the boot
  after that was the first silent one of the anchor: eight gates pass,
  `counter=3`, `gap.s=13`, `smart 6/17`, `firmware 259/258`, the moving
  history three of four full, attempts 0. `sudo sh
  /usr/local/etc/periodic/security/900.elvboot` by hand: `daily pass ...
  smart-quiet, ntp-gap, health-unique`.
- **The reserve card.** `stage push daily-v1 b` with card b in the reader:
  the push stamps the letter (the mount is the same for both cards, the
  stamp is what tells them apart -- a wrong card in the reader during a push
  is stamped with the wrong letter, so check `EFI/elvboot/medium` after).
  The boot from b: `tellwatch fail [MediumSwitch] now=b,last=a`, a tell, and
  `recordlock fail [ChainOnMedium] chain=differs` -- the one chain lives on
  the medium and card b's copy was days old; the unlock, as chapter 21 said
  it would be. The record and the shutdown anchor carry `medium=b` from
  here; the second boot from b is silent.

The clock, both ways, on the reserve card: with the RTC set ten days ahead in
the setup, StorageGap fell (`gap.s=864068`, the RTC 884,905 s ahead against
20,837 s of TPM clock) and ClockOrder passed -- a clock set forward is
consistent with itself, which is why StorageGap exists -- and CounterStep
fell with it: four TPM resets and four NVMe power cycles for one shutdown
(a missed cold start, the setup's own reboot, the power-off at the logo),
the detour counted. After ntpd had put the clock back, the next boot fell on
LastBootGap (the record said the 4th of October, the RTC the 24th of
September); StorageGap and ClockOrder fell with it, a negative gap being no
measurement (`storage.gap="unknown"`) -- one unlock for the gate. The boot
after that was silent, `counter=7`.

Two numbers to judge later, after a series of boots, not now: the prompt
dwell (108.8 s with two passphrases and a fumble, 88.8 s, 54.4 s with one,
180 s with three prompts and a typo -- `PROMPT_MAX_MS` is 90000 and sits
close to a slow evening) and
`storage.gap.max.days`, generous at 7 until the machine has shown what a
weekend and a holiday look like.
