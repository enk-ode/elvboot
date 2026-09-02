# elebake Architecture

elebake is a *compiler for a boot trust chain*: every command GENERATES
shell text that describes an action; whether that text is displayed,
piped, or executed is decided by an *interpreter* the user controls.
Nothing acts unless an executing interpreter is pinned — inspect first
is the default, not a mode.

## 1. Function classes

Three classes, encoded in the leading underscores of the function name;
the trailing digit is the arity:

| class            | prefix | emits                              |
|------------------|--------|------------------------------------|
| Terminal         | `_`    | shell text (the bloody details)    |
| Combinator       | `__`   | exactly ONE elebake re-invocation  |
| Batch combinator | `___`  | SEVERAL elebake re-invocations     |

Rules (sharp):
- Terminals never emit an elebake re-invocation; errors use
  `generate_error` (error shell), never an `elebake error` command.
- Combinators/batches never emit raw shell; errors are an
  `"$ELEBAKE_CONTEXT_SCRIPT" error '...'` command line.
- A batch combinator is an UNCONDITIONAL sequence of commands — what it
  emits is visible at a glance. Checking is itself a command in the
  sequence (`check stage`, `check dir`, `check file`, ...); the batch
  machinery owns stop-at-first-failure, so a failed check stops the run
  before the acting terminal fires.
- Helpers (no leading underscore) are generation-time VALUE functions:
  pure or read-only World probes. They return values to the generator
  and never emit shell.

## 2. Generation time vs. runtime

The generator reads the World as-is (kenv, efivar, files, records) in
the invoking context and BAKES values into the emission. Runtime
constructs appear only for state that a previously emitted effect
creates (a mountpoint after an import, a medium after a cp). If a fact
is missing at generation time, the generator fails early
(`generate_error`) — no implicit defaults.

## 3. Interpreters

Every dispatched function resolves an interpreter:

1. arity-specific: `ELEBAKE_INTERPRETER_<name><arity>` (e.g.
   `..._stage_import4`)
2. arity-agnostic: `ELEBAKE_INTERPRETER_<name>` (e.g. `..._pem_add`)
3. class default: `ELEBAKE_TERMINAL_INTERPRETER` (default `cat`),
   `ELEBAKE_COMBINATOR_INTERPRETER` (executing re-invoke),
   `ELEBAKE_BATCH_COMBINATOR_INTERPRETER` (spool + `batch`).

**Arity rule:** an arity-agnostic pin covers the WHOLE family. It is
only legal when the family is homogeneous (all one class). A
heterogeneous family (combinator cascade + terminal, display terminal +
combinator sibling) takes arity-specific pins only — a stray agnostic
pin under `sudo`'s env_reset is how `sh: : Permission denied` happens.

Display terminals (validate/report/help style) carry `cat`-style pins in
the profiles so their output survives an executing terminal default.
Interpreter pins live in `template/environment/` and are installed into
a database by `environment init <profile>` (the profile's line 1 is the
install list — a template that is not listed is not installed).

## 4. The database

```
$ELEBAKE_ROOT/                  (~/.elebake)
  db -> current                 active database symlink
  current/
    .env/{local,default}/       layered variable store (+ shipped templates)
    .tmp/ .log/                 spool, traces (the debugging ground truth)
    pem/ openpgp/ pkcs11/       key records: PATHS/URIs only, plus any
                                extra files a record accumulated
    provenance/<serial>-<hash>/ receipts of every import (lineage)
    export/                     collection, MANIFEST pair, serial
    stage/<name> -> ../.staging/<id>
    .staging/<id>/              the stage record (see below)
  worktree/<id>/                git worktree of FreeBSD src — build trees
                                live OUTSIDE the database
```

A stage record holds: `metadata`, `filter`, `checkout`, `work` (symlink
into the worktree), `sign-key`/`attest-key` (RELATIVE links into the
backends — the `stage/<name>` symlink IS the resolution, terminals build
paths through it), `media/<m>/` records, `marker/` records (files only;
the NVRAM effect lives exclusively in the `stage marker` command),
`boot/` (the built tree), `backup/<medium>/<label>/` records (loader.efi
plus description, sha256, created, source, by), and the build artifacts
`obj/`, `destdir/`.

## 5. dump & restore

Contract: **the dump emits a complete description of what is stored;
the restore takes such a description and decides what it needs.** The
logic lives in the DUMP (which knows the source, version-aware); the
import commands are logic-free base-element reproducers.

Per stage the dump unrolls: `check stage`, `dump record` (a `stage add`
replay — idempotent, an existing stage is never re-minted — plus CLI
replays for filter/key bindings/media, plus the work/checkout base
elements), `dump marker`, `dump backup`, `dump boot` (structure first:
every directory declared before the files inside it), and `dump rebuild`
(idempotent `stage build`/`stage install` lines — `obj/` and `destdir/`
are never moved, only regenerated). Key backends dump as `add` replays;
DB-internal path values are re-based onto the literal `"$ELEBAKE_BASE"`
so they expand in the TARGET; extra record files travel as
`<backend> import` base elements.

The dump text is framed by `dump env prologue` (the restore-safe minimal
variable set — deliberately WITHOUT function-specific interpreter pins,
which could deactivate replayed commands) and `dump env epilogue` (the
complete local override set, restored after the replay is done).
`# Version: 2` in the header names the dump format; `# Serial:` the
lineage counter, `# Strategy:` the vocabulary (complete | minimized),
`# Bundle:` the seal. `restore` refuses at generation time whatever is
not admissible — unsigned, signed by anyone but the pinned attest key,
a serial below the signer's floor — and otherwise is `batch` under
`ELEBAKE_INTERPRETER_restore`, which wraps the executing default with
`ELEBAKE_BATCH_KEEP_GOING=1`: a re-run's `stage add` conflicts are
skipped, everything else replays. Replays are fully idempotent (stable
stage ids, no `.staging` orphans, `rm -f` before every file copy). The
whole transfer — seal, signatures, receipts, the rescue pair — is
`docs/DESIGN_DUMP_ARCHIVE.md`.

Known property: batch children inherit the bootstrapped environment of
the outermost call, so a `setenv` inside a replay is effective from the
NEXT top-level call on — the rebuild lines therefore act on a second
restore or a manual `stage make`, by design until the engine decision
(see the review list).

## 6. Testing

Three suites, one framework (`--maxprocs N` runs test functions/stories
as parallel worker processes; aggregated summary):
- `elebake-architecture-test.sh` — conformance of every anchor against
  the rules in §1–§3, help corpus, env documentation.
- `elebake-unit-test.sh` — per-command behaviour in sandbox databases.
- `elebake-integration-test.sh` — end-to-end stories (migration
  round-trip, replay idempotence, check stage negative).

Doctrine: tests never touch real interfaces, devices, or NVRAM —
invented node names, sandbox databases, inspect-first assertions on
emissions. The `.log/<date>/*.trace` files are the debugging ground
truth ("Interpreter resolved", input/output to interpreter, exit
combination).
