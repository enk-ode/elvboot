# Features against documentation

*One of the elvboot articles, and the least narrative: a map of what
the tool and the loader can do against where it is explained, with the
gaps named. Counted on 17 November 2026 against `README.md`,
`docs/QUICKSTART.md`, `docs/TUTORIAL.md`, `docs/ARCHITECTURE.md`, the
generated manual and the 25 workflows. The command counts are
`# @command` blocks in `include/`.*

## How to read the table

Every feature has four possible homes. The **manual** (`elebake help`,
`docs/elebake.8`) is generated from the code and always complete, but
it explains one command at a time and never the idea. A **workflow**
(`elebake workflow show <name>`) is the procedure written out, with the
reason in its header comment. The **tutorial** is the story of how the
feature was built and probed, with the findings. An **article** is the
idea from the owner's side. A feature with only the manual has
documentation that cannot erode and that nobody will find.

| Feature | Commands | Manual | Workflow | Tutorial | Article |
|---|---|---|---|---|---|
| Database, environment, pins, dump and restore | ~100 | yes | restore | ch. 1 to 5, 20 | ARCHITECTURE |
| Keys: openpgp, pem, pkcs11 | 30 | yes | | ch. 5, 15 | |
| Stage: checkout, build, sign, manifest, attest, push | ~60 | yes | rebuild | ch. 6, 14, 16 | |
| Arsenal: expectations, claims, gates, triggers, policies, binding | ~45 | yes | policy-change | ch. 8 to 11 | why-compiled |
| Baselines and `site mk` | 26 | yes | baseline-relearn | ch. 12 | why-compiled |
| Prerequisites lists | 19 | yes | | ch. 13 | |
| Inventory sets (ACPI, EFI variables, images, PCI) | 24 | yes | inventory-drop | ch. 18, 22 | |
| Markers (NVRAM, boot variable, file) | 12 | yes | | ch. 9 (brief) | |
| kenv leafs and `loader.trust.conf` | 17 | yes | kenv-change, loaderconf-change | ch. 17, 21 | why-compiled |
| Record chain and anchors | loader | n/a | | ch. 17 | |
| Three factors, TPM key file | 50 (`stage tpm`) | yes | tpm-seal, tpm-rotate | ch. 21 | the-decoy-root |
| Time anchor | leafs, loader | yes | time-anchor | ch. 22 | |
| Medium stamp, ensure, identify | 14 | yes | | ch. 23 | the-rescue-boot |
| Duress: two objects, two counters | `stage tpm duress` | yes | duress-bind, duress-reseal | ch. 24 | the-decoy-root |
| Sentinel question and answer classes | 16 (`answer`) | yes | duress-bind | **no** | the-question |
| Context line (`display_act`), `reveal_act`, `tarpit_act`, `expire_act` | loader | n/a | | **no** | the-question (display only) |
| Tells and narrowing (SYSINIT) | earlboot | n/a | tells-narrow | ch. 26 (one paragraph) | |
| Snapshots, mail, report, forensic report, freeze | 18 (`elvboot`) | yes | boot-snapshots, boot-mail | ch. 25 | |
| Integrity witnesses, anchor, whole card | 24 | yes | witness-learn, card-grow | ch. 26 | the-rescue-boot |
| Rescue system | 104 | yes | rescue-build, rescue-refresh, rescue-expectations | ch. 26, 27 (indirect) | the-rescue-boot |
| Rescue offer (`offer_act`) | loader | n/a | | **no** | the-rescue-boot |
| Quarantine (decoy root) | 73 | yes | quarantine | ch. 27 | the-decoy-root |
| Disks: GELI headers, partition tables | 10 | yes | disks-bind | **no** | |
| Kernel: build, install, backup, rollback, boot environments | 9 | yes | module-from-ports | ch. 16 (brief) | |
| Hooks: earlboot, elvbootd, test with mocks | 23 | yes | | ch. 25 | why-compiled |
| `stage adopt`, `stage tree`, rollback on the medium | 13 | yes | | ch. 23 | |
| `environment freeze` | 1 | yes | | **no** | |
| Containers (`catalog.tbl`, a fourth container) | 17 | yes | | ch. 7 | |

## The gaps, by weight

**The sentinel question has no prose anywhere.** Sixteen commands, the
most owner-facing feature of the project, the one a reader of the
forum post will ask about first, and until these articles the word
"sentinel" appeared in the tutorial twice, in passing, in the story of a
rebuild gone wrong. The README does not mention it. QUICKSTART does not
mention it. [The question](the-question.md) is the first explanation;
the tutorial should get a chapter on the day the catch-all class and
the context line were probed on the machine, with the boots.

**The rescue offer is undocumented outside the source.** `offer_act`
is the way into the rescue system, and the only description of it was
the comment block in `action.c` and a German playbook in the owner's
infrastructure repository. [The rescue boot](the-rescue-boot.md) now
carries it; the tutorial should carry the three probes of 4 October
that shaped it (preload of the conf, the key file after the kernel,
`boot_prompt=0`).

**Four loader actions are documented only in `action.h`.**
`display_act`, `reveal_act`, `tarpit_act` and `expire_act`. The first
is in the article on the question. `reveal_act` (four words derived from
the gate secret so the human recognises the honest loader before typing)
deserves its own page: it is the inverse of Qubes AEM and the answer to
"how do I know the prompt is yours". `tarpit_act` and `expire_act` are
small and should be a paragraph each in a page on the action catalog.

**QUICKSTART stops at the first boot.** It covers database, keys,
stage, build, publish, migration and tests, which is the right short
path for a reader who wants to try the tool. It names nothing that
elvboot does after the first boot: no record chain, no TPM, no
witnesses, no rescue, no question. A second short path, "from the
silent boot to the full setup", of about the same length, would take
the reader from chapter 16 of the tutorial to chapter 27 by workflow
names alone.

**The README describes the family and the state, not the way in.** It
links the quickstart and the tutorial and stops. The articles should be
linked from it, and the "Hardware tested" section the forum note asked
for is still missing.

**Disks, kernel, hooks, freeze have a manual and nothing else.**
`stage disks` (GELI headers and partition tables as claims) has a
workflow and no story; `stage kernel` (a kernel built from the stage,
installed as a boot environment, rolled back) is a chapter's worth of
decisions compressed into two sentences of chapter 16; `stage hook` and
the mock test of the generated scripts (`stage earlboot test`, `stage
elvbootd test`) are the proof that the generated artifacts do what the
records say, and the tutorial mentions the test once; `environment
freeze`, the one irreversible operation on a database besides destroy,
is a manual entry.

**The German concept documents are the design record and are not
public.** The reasons behind the decisions, the rejected alternatives
(wipe, hidden OS, loader prompt, classification in the loader), the
coercion ladder, the GELI slot deletion idea, the ELEBAKE_SUDO note, the
TPM-judged duress hash under PCR 4, live in the owner's infrastructure
repository in German. [Why it is compiled in](why-compiled.md) and the
two articles above carry the reasons that have been decided; the ideas
not yet built are named in each article's "what is not solved" section,
and that is as far as the public documentation should go until they are
built.

## What the map says about the tool

Where the counts are high and the prose is thin, the family is young:
rescue (104 commands, one workflow, no tutorial chapter of its own) and
quarantine (73, one workflow, one chapter) were built in October and
the tutorial caught up with a chapter each. Where the prose is rich and
the counts are low, the feature is old and settled: the medium, the
manifest, dump and restore. That is the normal shape of a project that
writes its tutorial while it builds; the articles exist to give the
young families the explanation the old ones got by living through the
walk.

Two structural notes for the maintainer.

The manual cannot say *why*. Its text is the `@summary` of each
command, and a summary that explained the design would be a paragraph
in 556 places. The right place for the why is the workflow header, and
the workflows that have one (duress-bind, tells-narrow, quarantine,
rescue-build) read well. The ones that do not (boot-mail, kenv-change,
restore) should get the three lines.

The tutorial is a walk, and a walk is in the order things happened,
not in the order a reader needs them. A reader who wants the question
reads chapters 21, 22 and 24 and still does not find `answer add`. An
index at the top of the tutorial, feature to chapter, would cost a page
and save every reader an hour; the table above is a first draft of it.
