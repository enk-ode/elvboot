# elebake

Emit-and-inspect tooling for verified boot and boot-path tamper detection on
FreeBSD (elevated veriexec loader builds).

elebake is deliberately a *dumb* tool: commands do not act, they **emit** the
shell they would run. You read the emitted commands, then pipe them to `sh`.

    elebake.sh stage checkout p2 <ref>        # inspect
    elebake.sh stage checkout p2 <ref> | sh   # execute

## Architecture

A combinator engine (extracted from vpn-switch) dispatches three function
kinds: terminals (`_`) emit shell, combinators (`__`) emit one re-invocation,
batch-combinators (`___`) emit several. State lives in a key-addressed
database (`~/.elebake`) with named symlinks on top; build trees are git
worktrees of a FreeBSD source repo (`ELEBAKE_FREEBSD_SRC`), one per stage,
with a per-stage object tree — shared trees (`/usr/src`, `/usr/obj`) are
never touched.

The stage pipeline: `checkout → trustanchor/trustmk → build → install →
manifest → sign/attest → verify → deploy`.

## Principles

- No implicit defaults; fail early.
- Knowledge lives in function names; arity is part of the name (`_setenv2`).
- Derive state, do not cache it.
- Every emitted script is reviewable before it runs.

POSIX sh, tested on FreeBSD.
