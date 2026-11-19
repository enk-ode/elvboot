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
- The suites change the sandbox database only through the API: a pin with
  `setintp`/`unsetintp`, a variable with `setenv`/`unsetenv`, a record with
  the command that owns it (`stage marker store`, `stage quarantine value
  record`, `stage checkout` against a fixture repository). Nothing in a
  test writes into `.env/` or `stage/` by hand. The one exception is what
  no API can produce: a database broken on purpose (the scan tests), a
  build artefact of make, the answer of an interactive prompt, a receipt
  of a real measurement.

The model is described in `docs/ARCHITECTURE.md` and in the help of the
command family concerned (`elebake help <command>`); read it before
changing the model it describes. Design discussions, review packets and
working notes do not belong in this repository.
