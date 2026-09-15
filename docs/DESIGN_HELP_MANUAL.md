# Design: help as the single documentation emitter (`help manual`)

Status: AGREED (JB 2026-08-29), IMPLEMENTED 2026-09-02 (`help manual`,
`make man`, prose in `template/manual/`). Kills the
two-truths problem (hand-written manpage vs. help corpus): the help
family emits **Pandoc-Markdown as an intermediate format**, and the
interpreter (or a plain pipe) decides the target.

## 1. Emission

- `help` / `help <command>` stay the user views — same corpus, rendered
  as Markdown (readable as-is in a terminal).
- NEW `help manual`: the complete document — `% ELEBAKE(8)` title block,
  NAME/SYNOPSIS/DESCRIPTION prose, COMMANDS generated from the
  `@command` corpus (grouped by `@group`), ENVIRONMENT from the helpenv
  corpus, FILES/EXAMPLES. Prose sections are NOT in the corpus and do
  not belong there: they live as `template/manual/*.md` building blocks
  the generator interleaves. One truth per content kind: commands in
  the corpus, prose in the template, nothing twice.

## 2. Consumption

Canonical: default cat + pipe (NO env-override of interpreter
variables — forbidden by design; a permanent preference is a setenv pin):

```sh
./elebake.sh help manual | pandoc -s -f markdown -t man -o docs/elebake.8   # make man
./elebake.sh help manual | lowdown -sTterm | less -R                        # pretty terminal
```

`make man` becomes the target; `docs/elebake.8` becomes a GENERATED,
committed artifact (like the metadata lists) — pandoc stays a
contributor-only dependency. The hand-written mdoc page is replaced by
the generated man(7) output (mandoc renders both).

## 3. Consequences

- vpn-switch back-port replaces the region surgery of
  `scripts/generate-help-manpage.sh` with the same `help manual`
  pattern (part of the engine-library work, see
  vpn-switch docs/DESIGN_ENGINE_LIBRARY.md).
- The architecture suite's help-conformance tests then check Markdown
  structure (title block present exactly once, one `#`-section per
  group, code fences balanced).

## 4. Open review questions

1. Terminal default for `help`: keep `cat` (raw md) or pin
   `lowdown -Tterm` in the profiles (extra runtime dependency)?
2. Does `help manual` include `@internal` blocks in an appendix, or
   strictly user-facing commands only?
3. man section: 8 (system manager) vs 1 (user command)?
