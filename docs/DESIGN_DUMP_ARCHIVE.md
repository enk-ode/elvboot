# export / import — two artifacts, one signature, one lineage

The dump is the versioned description: it goes into git, gets committed
and pushed. The bundle is the payload — the base elements the dump
references — and goes into a backup area. They never contain each other,
and they are bound by content, not by name.

```
elebake export <dump> <bundle> <strategy> [<stage>]
elebake import <dump> <bundle>
elebake destroy <name>
```

## The chain

One key — the database's attest identity, `ELEBAKE_ARCHIVE_ATTEST_KEY`,
an `openpgp add` record — signs everything that leaves, and the SAME
setting on the receiving side names the signer an incoming pair must
carry. What one signature covers:

```
dump.asc ──signs──> dump ──seal line──> bundle sha256 ──MANIFEST.asc──> every file
```

- **`MANIFEST` + `MANIFEST.asc`** in the bundle: the same pair `/boot`
  carries, same recipe as `stage manifest`/`stage attest` — LC_ALL=C
  sorted `path sha256=hash` lines (symlinks as `path symlink=target`),
  hashed at generation time, `gpg --detach-sign -a`. A retargeted
  `stage/<name>` link is exactly the edit a hash-only manifest misses.
- **The seal**: after packing, `export` appends `# Bundle: sha256=… bytes=…`
  to the dump. Naming the tarball after the commit id stays the filing
  convention; the seal is what the receiver can check.
- **`dump.asc`**: the dump is attested LAST, so the signature covers the
  description, the seal and — through `MANIFEST.asc` — every file. The
  receiver makes one trust decision, not two.
- **The serial**: `# Serial: N` in the dump header, advanced by every
  export (`export/serial`). `restore` refuses a serial below the highest
  receipt of the same signer: a validly signed OLD dump cannot reinstate
  a retired key or a weakened expectation. A fresh database has no
  floor — the serial protects a lineage, not a first import.
- **The receipt**: an ADMITTED `import` files `provenance/<serial>-<hash>/`
  (serial, signer, dump and bundle hashes, restored, into, by) and raises
  the export serial to the imported one. Admitted means every check
  passed and the serial is at or above the floor; the receipt is filed
  right before the replay, because the replay runs keep-going — a
  redacted pair legitimately reports withheld elements — and must not
  decide whether the pair was genuine. Receipts are records: they are
  collected, dumped and imported like everything else, so the NEXT export
  carries them and a database can be asked where it came from.

**Pinning is the trust decision.** `gpg --verify` exits 0 for any key in
the keyring, expired and revoked ones included; that is not the question.
`attest verify`, `manifest verify` and `restore` read gpg's status lines
and accept only a GOODSIG whose VALIDSIG fingerprint ends in the pinned
record's keyid (16+ hex digits — a short id is refused as a pin). The
keyring's web-of-trust levels are never consulted. A fresh database
therefore imports NOTHING until its owner has registered the sender's key
and named it:

```
elebake openpgp add manifest-attest 4E1F0A2B7C9D8E6F5A4B3C2D1E0F9A8B7C6D5E4F
elebake setenv ELEBAKE_ARCHIVE_ATTEST_KEY manifest-attest
```

What this does not protect against: the attest key itself. It lives on
the Nitrokey; whoever holds the card and its PIN can sign.

## The batches

```
export:  provenance serial
         dump <complete|minimized> [<stage>]   > <dump>
         collect [<stage>]                      > export/collection.raw
         filter <strategy> export/collection.raw export/collection
         manifest attest export/collection <key>      (manifest + attest)
         bundle export/collection <bundle>
         seal <dump> <bundle>
         attest <dump> <key>

import:  attest verify <dump> <key>
         seal verify <dump> <bundle>
         incoming clear <incoming>
         extract <bundle> <incoming>
         manifest verify <incoming>/export/MANIFEST <incoming> <key>
         provenance add <dump> <bundle>          (admission: signer, serial floor)
         restore <dump> <incoming>
```

Plain re-invocations, sequenced by the batch machinery: fail-fast,
exit-code arithmetic, every step inspectable, intermediate results in
files. The order IS the security argument: on export the serial advances
before the dump is written, the bundle is packed before the seal hashes
it, the dump is signed after sealing. On import the cheapest checks come
first and nothing is touched until all three descriptions agree; the
tampered-payload case is found after extraction — into import's own
scratch directory, which is emptied before every extract.

`restore <dump> [<base>]` binds `ELEBAKE_ARCHIVE_BASE` to `<base>`, or to
`$ELEBAKE_BASE` when absent, and refuses at generation time: no
`# Version: 2` header, unsigned, wrong or expired or revoked signer,
serial below the floor. A refused restore replays nothing.

## Strategies

The strategy is an argument of `filter` and, for `minimized`, of `dump`:

| strategy | payload | description | for |
|---|---|---|---|
| `redacted` | no marker values, no site.mk, no backups | complete | sending: a bug report without the reporter's fingerprints |
| `full` | everything but `.tmp/`, `.log/` | complete | one's own recovery and migration |
| `minimized` | binary management only | minimized | the rescue system |

`redacted` and `full` describe the database COMPLETELY — the dump says
what the database is, and `restore` reports each withheld element as
missing. That is the intended reading. `minimized` is different: a rescue
system swaps binaries, it does not build them, so BOTH artifacts speak the
rescue vocabulary. One definition, `minimized_keep`, decides for the
collection and the dump alike: per stage `metadata`, `filter`,
`checkout`, the key bindings, `media/`, every `backup/` record, and of
`boot/` only `loader.efi`, `loader.efi.signed`, `loader.conf`, `kernel/`
and the manifest pair; keys and receipts travel, the foundation, the
worktree, phase bindings, markers and rebuild lines stay home.

## Rescue

```
big:     elebake export ~/rescue/dump.sh ~/rescue/bundle.tar.gz minimized
rescue:  elebake openpgp add manifest-attest <fingerprint>; setenv ELEBAKE_ARCHIVE_ATTEST_KEY manifest-attest
         elebake import ~/rescue/dump.sh ~/rescue/bundle.tar.gz
         elebake stage backup list smoke1 a          # the decision view
         elebake stage rollback smoke1 a known-good-p2  # saves the suspect FIRST
         elebake export ~/rescue/back.sh ~/rescue/back.tar.gz minimized
big:     elebake import ~/rescue/back.sh ~/rescue/back.tar.gz
```

The rescue database continues the lineage (its first export numbers
above what it absorbed), and the import back is a MERGE by construction:
the minimized dump describes only binary management, `stage add` is
idempotent, `stage import` replaces exactly the files it names. The new
suspect record and a repaired loader.conf land; lua/, markers and the
arsenal are never mentioned and never touched. The big database then
holds both receipts.

## Backup records

```
backup/<medium>/<label>/loader.efi description sha256 created source by
```

A backup is a record, not a timestamped file. The label is the record
name — unique per medium, immutable — and what `stage rollback` puts
back. `stage backup <stage> <medium>` defaults the label to the UTC stamp
and the description to medium/stage/user (two combinators delegating to
the four-argument terminal); `stage deploy` files `pre-deploy-<stamp>`
for what it displaces. `stage rollback` is a batch: `stage backup …
suspect-<stamp> "loader found on medium … before rollback to …"` — the
loader about to be overwritten may be the evidence — then `stage rollback
apply`, which refuses a record whose loader no longer matches its own
sha256. `stage backup list` is the view for the decision.

## Families

| command | job | pin |
|---|---|---|
| `collect [<stage>]` | per class: which files belong to it | cat |
| `filter <strategy> <in> <out>` | which of them may travel | sh |
| `manifest <collection> <MANIFEST>` | hash every entry that travels | sh |
| `manifest attest <collection> <key>` | manifest + attest, beside the collection | batch |
| `manifest verify <MANIFEST> <base> <key>` | pinned signer, every hash | sh |
| `attest <file> <key>` / `attest verify <file> <key>` | detached signature / pinned check | sh |
| `bundle <collection> <archive>` | pack (refuses without the manifest pair) | sh |
| `seal <dump> <bundle>` / `seal verify` | the dump names its bundle | sh |
| `incoming clear <dir>` / `extract <archive> <dest>` | import's scratch | sh |
| `provenance serial` / `add` / `list` / `collect` / `dump` / `import` | lineage | sh / cat |
| `stage backup [list]`, `stage rollback [apply]` | backup records | sudo sh / cat |

`collect` fans out to `pem`, `openpgp`, `pkcs11`, `provenance`,
`foundation` and `stage collect` — only a class knows its own files.
Rules: private material never travels (a `pem` key is a path promise
into the world); symlinks are content and are never followed; empty
directories are the dump's job; bundles live at `$ELEBAKE_ROOT/bundle/`
so a collection cannot collect its own products.

`bundle` and `extract` are ordinary act terminals: the generator reads
the collection FILE, substitutes a template and emits one shell command.
The shipped `ELEBAKE_ARCHIVER` uses FreeBSD base tar — `--uid 0 --gid 0
--uname root --gname wheel -cf - -C "$b" -T - | gzip -n > "$a"`,
byte-stable without `--sort=name` (bsdtar has no such option; `collect`
already sorts) and without a gzip timestamp; the template is wrapped in
a group so the heredoc reaches the packer that reads stdin.

## One variable carries the base

Every path in dump and collection alike is written against
`"$ELEBAKE_ARCHIVE_BASE"`. Who binds it decides what the artifact means:
`restore <dump>` — this database; `restore <dump> <old-db>` — a migration;
`restore <dump> <incoming>` — the bundle case. The binding is emitted
code, no engine change: `restore` emits `env ELEBAKE_ARCHIVE_BASE='…'
"$ELEBAKE_CONTEXT_SCRIPT" batch '<dump>'`, and `_batch2` expands every
line in a process that has the variable. Because the line starts with
`env`, `ELEBAKE_INTERPRETER_restore` maps the one literal script word to
the path and execs the words as they are — an eval would re-split a quoted
argument such as a refusal reason. The archive is plain file
storage: it holds files under the paths the dump names, nothing else;
every structural act is performed by the commands IN the dump.

---

**Rejected, so it is not proposed again:** a pipeline of elebake
instances (`collect | filter | bundle`) — no other command composes that
way, and a shell pipe carries no exit status backwards (measured: a
failing left side still ends in rc=0 and an EMPTY archive). Re-pinning
an interpreter at runtime for one call — not atomic, overwrites a user
setting. Digests on the import lines (`stage import … sha256=…`) —
strictly stronger, but the chain above already closes; it would change
the import grammar for redundancy, not coverage. A gpg-free `# Digest:`
self-line in the dump — an editor recomputes it; it detects accidents,
not tampering, and would read like protection where there is none.
Filtering the dump for `redacted` — an artifact that no longer describes
anything reproducibly.

---

## destroy — the other end of the lifecycle

```
elebake destroy <name>
```

Removes a database and everything it owns, irrecoverably. The name IS
the confirmation: it is checked at generation time, so no interactive
prompt is needed. The pin is `cat`, so the `rm -rf` lines are read before
they are handed to `sh`. Measured, not assumed: worktrees are
deregistered (`git worktree remove --force`, then `prune`); the active-DB
symlink is resolved first (`rm -rf` on a symlink removes the LINK); the
handover area `$ELEBAKE_ROOT/bundle/` goes too — it is where an archive is
handed to the user, never a store; empty scaffolding is cleared with
`rmdir`, so a second database in the same root survives. Not touched, and
named in the warning: deployed loaders on media, NVRAM boot entries, key
material in the world.
