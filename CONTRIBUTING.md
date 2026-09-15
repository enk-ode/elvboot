# Contributing

Contributions arrive as pull requests against `main`.

**Before you open one:**

- `make test` must be green — all three suites (architecture, unit,
  integration). They run on FreeBSD; the architecture suite enforces a
  lot of what follows mechanically.
- POSIX sh only. The combinator classes are load-bearing: `_`
  terminals emit shell (never act themselves), `__` combinators emit
  exactly one re-invocation, `___` batches emit several. Helpers carry
  no leading underscore.
- Notes from act terminals go through `emit_note` (a bare `#` line is
  swallowed under sh — the scanner will tell you).
- No implicit defaults: missing configuration fails early with the way
  out in the message.
- Adds are idempotent-immutable: identical re-add is a no-op, a
  differing one is refused. Dumps replay; keep it that way.
- Every `.sh` carries the SPDX/BSD-2-Clause header (guard test).
- New commands that store state must appear in the integration
  fixture (`make_source_db`) — it is the dump/restore coverage
  contract.

Design discussions live in `docs/DESIGN_*.md`; read the relevant one
before changing the model it describes.
