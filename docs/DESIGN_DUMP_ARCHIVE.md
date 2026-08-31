# archive — the dump plus its base elements, as one bundle

The dump is an executable description: kept in git, replaying a
committed dump reproduces the database — reproducible builds from
versioned decisions. What the dump does NOT carry are the BASE
ELEMENTS: its `stage import` lines reference files by absolute source
path, and its key replays reference paths/URIs whose files stay in
place by design. A dump travels; its world does not.

`archive` closes that gap:

```
elebake archive [<stage>]        the dump plus every referenced base
                                 element, bundled into one directory
```

## Mechanics (sketch)

- `archive` emits into a target directory (deterministic layout):
  - `dump.sh` — the ordinary dump, with ONE rewrite: every base-element
    source path is replaced by the bundled RELATIVE path (`elements/...`),
    so the bundle is self-contained and replays anywhere.
  - `elements/` — one copy of every file the dump references (stage
    imports; pkcs11 certs; NOT private key material — pem key/cert stay
    path promises exactly as in the live database).
- The stage-isolated form `archive <stage>` bundles the stage's dump
  plus the TRANSITIVE closure it replays: the bound key records, the
  referenced foundation records (macros/expectations/claims/gates/
  triggers/policies of its bindings), its conf values. That closure is
  what makes the bundle an EXCHANGE FORMAT: a bug report or a
  third-party analysis receives one directory (tar it if you like),
  replays it into a fresh database, and sees exactly the reporter's
  configuration — without the reporter's machine.
- Naming rule: `archive` is an artifact command (the artifact is the
  bundle); `dump` stays what it is. An alternative considered — an
  interpreter setting that turns `dump` itself into a bundler — is
  rejected as a first approach: an interpreter changes HOW an emission
  runs, not WHAT the command means; a bundle is a different artifact
  and deserves its own name.

## Open points (to decide before building)

- Redaction: marker values, backup blobs and site.mk baselines are
  machine secrets in spirit. An exchange bundle likely wants a
  `--redacted` mode (the dump already knows redaction from the marker
  handling) — default open question: redact by default and opt IN to
  full fidelity, or the reverse?
- Scope of the closure for `archive <stage>`: keys yes (paths only),
  foundation yes; the worktree NO (the checkout ref + HEAD in the
  provenance header identify it — the receiver checks out their own).
- Determinism: file order sorted, no timestamps, byte-stable rewrites —
  the erosion story pattern applies (an archive replayed twice must be
  identical).
