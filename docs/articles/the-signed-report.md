# The signed report

*One of the elvboot articles. The stage on the reference machine is
called `daily-v1`; the commands use that name.*

## A document for someone who was not there

A machine that checks itself produces verdicts, and verdicts are for the
owner at the console: a gate fell, a witness moved, the boot was quiet.
The day the state of the machine matters to someone else (a lawyer, an
expert, an insurer, a court), a verdict on a console is nothing. That
reader needs a document: what was required of this machine, from which
code, under which keys, what every boot measured against it, and what
the owner did about each finding.

`elvboot report forensic` writes that document. This article shows what
is in it, where each line comes from, and what the document can and
cannot carry as evidence.

## Where the material comes from

Three sources, and the report's first paragraph names them:

- **The database** holds what was required: the gates, their claims,
  the expectations, the keys, the baselines. It is the owner's, it is
  exported and attested under a serial number, and it can be rebuilt on
  a second machine.
- **The state directory of the hooks** holds what happened. At every
  start elvbootd writes each `loader.trust.*` leaf of the boot into a
  snapshot file, and at shutdown appends the session's verdicts. The
  header of each snapshot carries the sha256 of the one before, so a
  rewritten past breaks the chain.
- **The media and their receipts** hold what the witnesses saw: one
  line per measurement, with time, partition, medium and digest.

The report renders these and computes nothing else. Its last section
lists every file it was read from, with its sha256.

## What the report contains

Part one is rendered by the owner from the database alone.

1. **Subject.** The machine, the database, the stage, and three
   identifiers that make every later statement traceable: the version
   and commit of the tool that wrote the database, the commit of the
   loader source (every measurement named in the report is a function in
   that tree), and the serial of the last attested export.
2. **Trust anchors.** The signing key and the attest key with their
   ids, the digest of the signed loader, the manifest with its entry
   count and signature, the loader configuration, the hooks.
3. **Requirements.** One row per claim, ordered by phase and gate: the
   expectation (kind, label, value), the measurement that produces the
   value at boot, and the reactions bound to the outcome.
4. **Baselines.** The learned values, secrets shown as redacted with
   their length.
5. **Loader leaves**, each with the time of its record.
6. **Inventory sets**: the loaded images, ACPI tables, EFI variables
   and devices the machine is expected to show.
7. **Disks.**
8. **Witnesses.** Per container: what the loader is configured to
   expect, every receipt ever taken (labels, partition table, whole
   device), and a verdict whether the configuration equals the newest
   receipt; then the anchor in the TPM.
9. **Rescue** and 10. **Quarantine**: dataset, pool, snapshot, the
   signed baseline of the tree, and for the decoy its `rc.conf` in full.

Part two is rendered as root, because the state directory is root's.

- **The boots**, as a table and then one by one: counter, time, medium,
  chain, the fallen gates with the expected and the measured value side
  by side, the verdicts of the running system, the unlocks.
- **Aggregates**: boots per medium, failures per claim, restarts and
  gaps of the chain, boot times.
- **Chain**: every snapshot file checked against its predecessor, and a
  count of breaks.
- **Explanations on file**: the findings the owner acknowledged, each
  with the time of the acknowledgement; the mark standing now, if one
  stands; the expectations the owner learned anew, with the time of the
  record.
- **Sources**: every file with its digest.

A boot is read together with the explanation next to it. A rebuild moved
the PCR bank at 10:21, the owner learned the new bank at 10:34, the
boots since are quiet: three lines from three files, and the report
shows all three.

## The form

The report is Markdown, in English, and deliberately flat: no table
carries a digest, every row is a key-value line, every value a code
span, every verdict a span of the class pass, fail or skip.

    ### zempty on nda1p1

    #### Verdict

    [The configured digest equals the newest labels receipt]{.pass} (2026-10-14T09:12:40Z).

    ## Chain

    - `20261014T091502Z-41.kenv`: [chained]{.pass} to `20261013T184410Z-40.kenv`
    - breaks: **0**

It reads in a terminal and it signs as it is. Templates for pandoc turn
the same file into PDF or HTML with the classes in colour; the Markdown
remains the document.

    elvboot report forensic daily-v1 > report.md
    elvboot report sign daily-v1 report.md

The signature is one detached OpenPGP signature over the whole file,
made with the stage's attest key, the same key that signs the manifests
and the baselines.

## What the signature says

The signature says: the holder of this key issued this text, and the
text has not changed since. It is on the report and not on the log for a
reason. A log signed on the machine is signed by whoever is root on the
machine. The report is signed where a person with the token sits, after
reading it.

What stands behind the text is older than the signature, and that is
where its strength lies:

- the loader's own record chain, which only the loader can extend;
- the hash chain of the snapshots;
- the receipts, anchored in a TPM index that needs the owner's
  passphrase to write;
- copies that left the machine when they were made: the snapshot mailed
  at every boot, the receipt lines in a public commit and on paper.

A reader does not have to believe the report. The files are listed with
their digests, the code is public at the named commit, the database can
be restored on another machine from the attested export, and
`stage witness measure` can be repeated on the media in front of a
witness.

## What it weighs

How a document is received depends on the forum; the following is
orientation, not legal advice.

**It is a party's document.** In German civil procedure the court
decides "nach freier Überzeugung" whether a factual assertion is to be
held true (§ 286 ZPO) [1]. A report the owner produced about the owner's
machine enters as that party's detailed submission, and a court expert
may be asked to examine it. The report is built for that examination:
it explains its method, names its sources and can be reproduced.

**An OpenPGP signature is not a qualified electronic signature.** German
law applies the probative force of private deeds to electronic documents
that carry a qualified electronic signature, and gives such a
declaration an appearance of authenticity that only facts raising
serious doubt can shake (§ 371a ZPO) [2]. A qualified signature also has
the legal effect of a handwritten one (Regulation (EU) No 910/2014,
Article 25) [3]. The attest key is the owner's own; its signature may
not be refused as evidence merely for being electronic, but it carries
no presumption. Signing the finished file once more with a qualified
signature adds that.

**The date is the part that benefits most from a third party.** A
qualified electronic time stamp enjoys the presumption that its date and
time are accurate and that the data bound to them are intact (Article
41) [3]. A report, an export or a line of receipts that receives such a
stamp on the day it is made can later be shown to have existed then, by
someone other than the owner. The public commit and the mailbox serve
the same purpose with less formal weight.

**Elsewhere the same two ideas recur.** The United States Federal Rules
of Evidence treat as self-authenticating a record "generated by an
electronic process or system that produces an accurate result" and data
copied from a device "if authenticated by a process of digital
identification", each on the certification of a qualified person (Rule
902(13) and (14)) [4]. A described process and a hash comparison are
what the report consists of.

## What the report does not say

The report prints its own limits, and they belong in any use of it:

- What root did after a boot is invisible until the next boot's claims
  fall. The report covers the boots and the closed containers, not the
  content of the running system.
- A receipt proves that something changed and when it was noticed. Who
  changed it is argued from the boot records, the counters and
  circumstances outside the machine.
- Secrets appear redacted; the traces of the database are kept for a
  day.
- Everything before the first external copy rests on the owner's word.
  The earlier the first receipt was published or stamped, the shorter
  that stretch.

## Where to look

- [The planted file](the-planted-file.md): why the receipts exist.
- Tutorial, chapter 25 (the report) and chapter 26 (the witnesses).
- `elvboot help report`, `template/report/forensic.sh` and
  `template/report/render.sh`: the report is those two scripts, and they
  are short enough to read.

## Sources

1. Zivilprozessordnung, § 286.
   <https://www.gesetze-im-internet.de/zpo/__286.html>
2. Zivilprozessordnung, § 371a.
   <https://www.gesetze-im-internet.de/zpo/__371a.html>
3. Regulation (EU) No 910/2014 (eIDAS), Articles 25 and 41.
   <https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX:32014R0910>
4. Federal Rules of Evidence, Rule 902.
   <https://www.law.cornell.edu/rules/fre/rule_902>
