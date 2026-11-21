# The signed report

*One of the elvboot articles. It reads a real report: the one the
reference machine wrote on 18 October 2026, 3029 lines, signed. The
excerpts are unchanged except that digests are cut to their first eight
digits and long lists are cut where `[...]` says so.*

## A document for someone who was not there

A machine that checks itself produces verdicts, and verdicts are for the
owner at the console. The day the state of the machine matters to
someone else (a lawyer, an expert, a court), that reader needs a
document: what was required of this machine, from which code, under
which keys, what every boot measured against it, and what the owner did
about each finding.

    elvboot report forensic daily-v1 > report.md
    elvboot report sign daily-v1 report.md

The first command writes the document, the second signs it. What
follows is that document, section by section.

## The head: three sources

    # elvboot report -- forensic

    Generated 2026-10-18T08:40:22Z on illyria by brj with elebake 2
    bf2f4d9. This document renders three sources and invents nothing:
    the database (what was required), the state directory of the hooks
    (what every boot measured), the media and their receipts (what the
    witnesses saw). Every section names the files it was read from; the
    last section lists them with their digests.

That paragraph is the method. The report computes nothing of its own; a
reader who doubts a line goes to the file the section names.

## 1 and 2: what is being talked about

    - machine: **illyria**
    - stage: **daily-v1**, created 2026-09-05T14:55:34Z
    - elebake: **elebake 2 bf2f4d9** -- the tool that wrote the database
      and rendered this report
    - loader source: **a75da6e6** -- the commit of the fork the loader,
      earlboot and elvbootd were built from; every measurement named
      below is a function in that tree
    - export serial: **24** -- the database as last exported and attested

Three identifiers make everything below traceable: the commit of the
tool, the commit of the loader source, and the serial of the last
attested export of the database. A claim called `measure_images` further
down is a function a reader can open at that commit.

    - attest key: **attest-key** (`DA115B50[...]`) -- this key signs the
      manifests, the baselines and this report
    - loader: sha256 `aab76813` (the signed loader the media carry)
    - manifest: **903 entries**, signature **present**
    - loader configuration: sha256 `c8a7d5bd`
    - hook `earlboot`: sha256 `d309867a`
    - hook `hook.startup.sh`: sha256 `6278f326`

These are the trust anchors: the keys, the loader binary, the manifest
of the boot tree, the configuration and the hooks that run in userland,
each with its digest. Whoever holds the card can hash the loader on it
and compare.

## 3: the requirements

    ### Phase PHASE_LOADER

    #### Gate inventory, policy watch-inventory

    - reactions: **when_always -> publish_act; when_skipped ->
      report_act; when_fail -> taint_act;**
    - claim **images**: expectation `macro - IMAGES_EXPECTED`,
      measurement `measure_images`
    - claim **acpi**: expectation `macro - ACPI_EXPECTED`,
      measurement `measure_acpi`
    - claim **witness-labels**: expectation `byte WitnessLabels 1`,
      measurement `measure_witness_labels`
    [...]

This section runs to 270 lines and is the specification of the machine:
per phase the gates, per gate the claims, per claim what is expected and
which function measures it, per policy what happens on pass, fail or
skip. A reader learns here that a changed set of loaded firmware images
taints the boot, before reading whether it ever did.

## 4 to 7: the expected values

    - `LOADER_TRUST_IMAGES_DIGEST` (digest): `130c8cf2`,
      recorded 2026-09-28T06:45:21Z
    - `LOADER_TRUST_RECORD_SALT` (string): `<redacted: string, 44
      characters>`, recorded 2026-09-06T14:30:10Z
    - `LOADER_TRUST_TIME_PROMPT_MAX_MS` (int): `90000`,
      recorded 2026-09-12T15:24:55Z

The baselines are the constants compiled into the loader. Each carries
the time of its record, so a reader sees when an expectation was last
changed. Secrets are named with type and length and withheld. Sections 5
to 7 list the loader's configuration leaves the same way, the inventory
sets in full (every firmware image, ACPI table, EFI variable and device
the machine is expected to show, 440 lines), and the internal disks
whose headers and partition tables are measured.

## 8: the witnesses

    ### zcard-a on da1p3

    #### Configured

    - medium: `fd51968f`
    - digest: `1f15c32b`
    - gpt: `097769e1`

    #### Receipts

    - zcard-a:
        - `2026-10-12T09:46:01Z 89306b00-[...] fd51968f 3426afcf`
        - `2026-10-13T15:47:40Z 89306b00-[...] fd51968f 3426afcf`
        - `2026-10-17T09:17:52Z 89306b00-[...] fd51968f 0b781930`
        - `2026-10-18T05:38:04Z 89306b00-[...] fd51968f 1f15c32b`
    - zcard-a.gpt:
        - `2026-10-13T15:47:41Z fd51968f 097769e1`
        - `2026-10-17T09:17:53Z fd51968f 097769e1`
        - `2026-10-18T05:38:05Z fd51968f 097769e1`

    #### Verdict

    [The configured digest equals the newest labels receipt]{.pass}
    (2026-10-18T05:38:04Z).

A witness is a container the loader reads and never opens. The receipt
lines are its history: time, partition, medium, digest. Card a held one
state from the 12th to the 13th, a second on the 17th, a third on the
18th. Section 9 names the cause: the rescue root was built anew
(`snapshot: daily-v1-20261017T155821Z`) and pushed to both cards. The
partition table did not move through all of it. A change of the labels
without a push next to it would stand here in exactly the same form,
with nothing beside it.

    ### Anchor in the TPM (index 0x01c10e26)

    - `2026-10-15T08:01:23Z 51317941`
    - `2026-10-15T08:14:09Z 696065b6`
    - `2026-10-17T10:03:39Z 20097454`
    - `2026-10-18T06:09:45Z 290bdb53`

The anchor is the hash over all receipts, held in the TPM. Its history
follows the receipts: a new value each time the owner measured and
anchored. Sections 9 and 10 then describe the two immutable roots, each
with its snapshot and its signed baseline (167877 entries for the
rescue, 28023 for the decoy), and for the decoy the complete `rc.conf`.

## The boots

Part two is rendered as root from the state directory: 24 boots in this
report, each as its own section. This is boot 17.

    ### Boot 17 (2026-10-17T13:45:33Z)

    - snapshot: `20261017T134533Z-17.kenv`
    - medium: **a**
    - chain: **differs**
    - session: **closed (shutdown run kept)**

    #### Summary

    - failed: kernelpost: [PromptWindow]{.fail}; recordlock:
      [CounterStep]{.fail}, [ChainOnMedium]{.fail}; tellwatch:
      [MediumSwitch]{.fail}
    - skipped: none
    - passed: bootlock: [SecureBoot]{.pass}, [SetupMode]{.pass}, [...]

    #### Failed

    - kernelpost/PromptWindow
        - `loader.trust.kernelpost.time.prompt` =
          `dwell=90703,cadence=4123,attempts=4,prompted=2,retry=0`
    - recordlock/ChainOnMedium
        - `loader.trust.recordlock.anchor` =
          `verified,matches,counter=16,medium=b`
        - `loader.trust.recordlock.anchors` =
          `tpm.reset=2309258669/2309258667,[...],nvme.cycles=390/388`
        - `loader.trust.recordlock.record` =
          `geli=c5a76740,counter=16,last=2026-10-17T13:34:41,
          bootms=58767,flags=4,chain=differs,medium=b`
    - tellwatch/MediumSwitch
        - `loader.trust.tellwatch.medium` = `now=a,last=b`

Four claims fell, and under each the report prints the leaves that
carry the reason. The boot came from card a; the record of the boot
before was written from card b (`now=a,last=b`). The record chain on
this card therefore does not continue the last boot, which is what
`ChainOnMedium` and `CounterStep` say. The anchors give the distance to
that last boot in independent counters: two TPM resets, two NVMe power
cycles, 564 seconds. And the passphrase prompt stood 90.7 seconds, 703
milliseconds over the maximum from section 4.

A swap of the card is what an attacker with a prepared card would do,
and it is what the owner did that afternoon while refreshing both cards;
the receipts of section 8 show the pushes on the same day. The report
does not decide which. It shows that the swap was seen, when, and what
else moved with it. Everything else in that boot passed, by name: Secure
Boot, the firmware inventory, the witnesses, the PCR bank, the kernel
modules.

Boot 13, the same morning, shows the other kind of finding.

    ### Boot 13 (2026-10-17T04:59:47Z)

    - kernellock/PcrBank
        - `loader.trust.kernellock.pcr.expected` = `ede6859f`
        - `loader.trust.kernellock.pcr.sha256` = `9c4362ba`

The expected and the measured value stand side by side: the TPM's
platform registers held another value than the one the loader was built
to expect. What the owner did about it is not in this section but
further down, and that is deliberate.

## Aggregates and chain

    - boots per medium: a=14, b=10
    - failures per claim: [...] MediumSwitch=10, CounterStep=5,
      PcrBank=6, PromptWindow=12 [...]
    - chain restarts (counter fell): 2, gaps (counter stepped by more
      than one): 1
    - last witness state: `zcard-a=match,zcard-b=absent,zempty=match`

The aggregates are the same boots counted. The period was the one in
which the cards and the rescue were rebuilt several times, and the
numbers show it.

    - `36.kenv`: first of the selection (header prev=`none`)
    - `37.kenv`: [NOT chained]{.fail} to `36.kenv` (header prev=`none`)
    [...]
    - `20261014T140756Z-6.kenv`: [NOT chained]{.fail} to
      `20261014T060117Z-3.kenv` (header prev=`ede63fb6`)
    - `20261014T143734Z-7.kenv`: [chained]{.pass} to
      `20261014T140756Z-6.kenv`
    [...]
    - breaks: **12**

Each snapshot carries the hash of its predecessor, and the report
verifies every link. Twelve are broken. Seven of the files are older
than the chain and carry no predecessor hash at all; five fall into the
two days in which the record chain was started anew twice. From boot 7
on the chain holds without a break. The report prints the twelve as
failures and leaves the reading to the reader. A report that showed only
the clean stretch would say less.

## The explanations on file

    ### Acknowledged findings

    - `2026-10-17T05:01:18Z acknowledged: 2026-10-17T04:59:21Z
      narrow_courier fail failed=[class-identity]
      passed=[halt-foreign,moved-repeat] skipped=[]`

    ### Freeze mark now

    none

    ### Learned expectations

    - `loader.trust.kernellock.pcr.expected` = `9c4362ba`
      (recorded 2026-10-17T05:00:45Z)

A finding of the identity class leaves a mark that blocks every further
push to the cards until the owner acknowledges it. The line keeps both
times: the finding at 04:59:21, the acknowledgement at 05:01:18. The
expectation for the PCR bank was learned anew at 05:00:45, between the
two, and the learned value `9c4362ba` is the one boot 13 measured. Boot
14, at 05:05:32, lists `PcrBank` among the passed claims.

Read together, four places in the report give the account: boot 13 saw
another bank than expected, the mark of that minute stopped the pushes,
the owner learned the measured value and acknowledged, and the next boot
was quiet on that claim. Had the owner not looked, the mark would stand
under "Freeze mark now", no expectation would have been learned, and
boot 14 would show the same two values again.

The last section lists all 24 snapshot files, the receipt files and the
acknowledgements with their sha256.

## The form and the signature

The report is flat Markdown: no table carries a digest, every row is a
key-value line, every verdict a span of the class pass, fail or skip. It
reads in a terminal and signs as it is; templates for pandoc render the
same file to PDF or HTML with the classes in colour.

The signature is one detached OpenPGP signature over the whole file,
made with the attest key named in section 2. It says that the holder of
that key issued this text and that the text has not changed since. It is
on the report and not on the log for a reason: a log signed on the
machine is signed by whoever is root on the machine, and the report is
signed where a person with the token sits, after reading it.

What stands behind the text is older than the signature: the record
chain only the loader can extend, the hash chain of the snapshots, the
receipts anchored in the TPM, and the copies that left the machine when
they were made (the snapshot mailed at every boot, the receipt lines on
paper and in a public commit).

## What a reader can check

- Hash the files named in "Sources" and compare.
- Open the loader source at the named commit and read the measurement
  behind any claim.
- Restore the database from the attested export on another machine and
  render part one again; it must come out the same.
- Repeat `stage witness measure` on the media, with a witness present,
  and compare with the last receipt.
- Verify the signatures of the report, the manifest and the baselines
  against the attest key.

## What it weighs

How a document is received depends on the forum; the following is
orientation, not legal advice.

**It is a party's document.** In German civil procedure the court
decides "nach freier Überzeugung" whether a factual assertion is to be
held true (§ 286 ZPO) [1]. A report the owner produced about the owner's
machine enters as that party's detailed submission, and a court expert
may be asked to examine it. The list above is what such an examination
would do.

**An OpenPGP signature is not a qualified electronic signature.** German
law applies the probative force of private deeds to electronic documents
that carry a qualified electronic signature, and gives such a
declaration an appearance of authenticity that only facts raising
serious doubt can shake (§ 371a ZPO) [2]; a qualified signature has the
legal effect of a handwritten one (Regulation (EU) No 910/2014, Article
25) [3]. The attest key is the owner's own: its signature may not be
refused as evidence merely for being electronic, and it carries no
presumption. A qualified signature over the finished file adds that.

**The date benefits most from a third party.** A qualified electronic
time stamp enjoys the presumption that its date and time are accurate
and that the data bound to them are intact (Article 41) [3]. A report or
a line of receipts stamped on the day it was made can later be shown to
have existed then, by someone other than the owner.

**Elsewhere the same two ideas recur.** The United States Federal Rules
of Evidence treat as self-authenticating a record "generated by an
electronic process or system that produces an accurate result" and data
copied from a device "if authenticated by a process of digital
identification", each on the certification of a qualified person (Rule
902(13) and (14)) [4].

## What the report does not say

- What root did after a boot is invisible until the next boot's claims
  fall. The report covers the boots and the closed containers, not the
  content of the running system.
- A receipt proves that something changed and when it was noticed. Who
  changed it is argued from the records, the counters and circumstances
  outside the machine; boot 17 is the example.
- Secrets appear redacted; the traces of the database are kept for a
  day.
- Everything before the first external copy rests on the owner's word.

## Where to look

- [The planted file](the-planted-file.md): why the receipts exist.
- Tutorial, chapter 25 (the report) and chapter 26 (the witnesses).
- `elvboot help report`; `template/report/forensic.sh` and
  `template/report/render.sh` are the report, and short enough to read.

## Sources

1. Zivilprozessordnung, § 286.
   <https://www.gesetze-im-internet.de/zpo/__286.html>
2. Zivilprozessordnung, § 371a.
   <https://www.gesetze-im-internet.de/zpo/__371a.html>
3. Regulation (EU) No 910/2014 (eIDAS), Articles 25 and 41.
   <https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX:32014R0910>
4. Federal Rules of Evidence, Rule 902.
   <https://www.law.cornell.edu/rules/fre/rule_902>
