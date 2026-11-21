# The planted file

*One of the elvboot articles. On the reference machine the decoy root is
the pool `zempty` and the rescue root lives on the card in the pool
`zcard`; the article uses those names.*

## The other half of the threat

Disk encryption answers one question: who may read. Most of what is
written about protecting a laptop stops there. But the attacker who can
reach a disk can do two things with it, and the second is the one that
ends up in a court file: he can write.

A file that appears on a machine is, to everyone who looks later, the
owner's file. It lies in the owner's home, under the owner's uid, on a
disk only the owner's passphrase opens. The owner says "I did not put
that there", and has nothing to show for it. The person who planted it
does not need to break the encryption for long, or at all, if he can
get the owner's own session to do the writing.

This article is about that half: what it takes for a machine to say
"this is the state my owner left me in", to the owner first, and in a
form a third party could check. It is why elvboot counts bytes in places
where nobody keeps files.

## It has happened

**Turkey, OdaTV.** Journalists of the news site OdaTV were arrested in
2011 on the strength of documents found on their computers. The
forensics firm Arsenal Consulting later reported that the documents had
been placed on the machines of Barış Pehlivan and Müyesser Yıldız
without their knowledge, by malware and, in Arsenal's account as the
press reported it, also by someone with the disk in his hands. The
defendants were acquitted in April 2017, after six years on trial
[1][2].

**India, Bhima Koregaon.** Sixteen activists, lawyers and academics were
jailed under anti-terror law, largely on letters found on seized
laptops. Arsenal examined the disk images for the defence and reported
in 2021 that an attacker had controlled Rona Wilson's laptop through the
commercial remote access tool NetWire and had delivered at least ten of
the incriminating letters into a hidden folder; a second report raised
the count by 22, a third found 14 planted letters on Surendra Gadling's
machine, and a later one found the same on the computer of Stan Swamy,
an 83-year-old priest who had been under attack for nearly five years
when his device was seized and who died in custody [3][4]. India's
National Investigation Agency rejects the findings. In February 2022
SentinelLabs described the actor behind the intrusions, which it calls
ModifiedElephant, as active for a decade, with the objective of
"planting incriminating digital evidence" [5].

Those are the documented cases; nobody knows the number of the others,
because finding out took a defence team, a disk image handed over by a
court, and months of specialist work.

**Extortion.** The crude version of writing to someone else's disk is
ransomware. In July 2021 the German district of Anhalt-Bitterfeld
declared a disaster, the first in the country caused by a cyber attack;
social benefits could not be paid for more than a week, and the district
put the damage at 2.5 million euros [6]. The Federal Office for
Information Security's 2025 report still names ransomware the largest
threat and finds that 72 percent of the attacks came with a data leak
[7]. An attacker who can encrypt every file could as well have added
one.

**The law.** In Germany the right to the integrity of one's own machine
has had constitutional rank since 2008, when the Federal Constitutional
Court derived a "fundamental right to the guarantee of the
confidentiality and integrity of information technology systems" from
the Basic Law [8]. Integrity, not only confidentiality. Covert access to
a system is a regulated instrument beside that right. Criminal procedure
allows it and says what may be changed on the target: only what is
indispensable for collecting the data, undone when the measure ends,
and logged (§ 100a (5) StPO) [9]. In November 2026 the Bundestag passed
a reform of the intelligence services law [10][11]. It gives the
domestic service the covert online search of private IT systems, and
both services protective measures against IT systems from which an
immediate danger arises; the report of the vote lists redirecting or
blocking data streams, deleting or falsifying harmful data, and shutting
down servers from which attacks originate [10]. The measures are
subsidiary to those of the police and stand under prior review by the
Independent Control Council [10][11].

For this article the legal detail matters less than the technical fact
underneath it: changing data on a system from outside, unseen by its
owner, is an established capability. It exists with a legal frame and
without one, and the tools do not differ by who holds them.

Whoever the writer is (an agency, a criminal, a business rival, a
former partner), the owner's problem is the same.

## What the owner needs

Not a promise that nothing can be written. No design delivers that
against someone who holds the machine. The owner needs three smaller
things that add up to an account:

1. **Every place where bytes can lie is described.** A place nobody
   described is a place nobody will miss a change in.
2. **Every described place has a receipt**, taken by the owner at a
   moment the owner chose, and kept where the machine's root cannot
   rewrite it.
3. **Every deviation is loud and stays on record** until the owner has
   looked at it. A warning that can be clicked away, or that a later
   boot overwrites, is not a record.

With these the sentence "I did not put that there" stops being a bare
denial. It becomes: here is the receipt from the 14th, here is the boot
on the 16th that I did not make, here is the witness that moved. That is
what plausibility means on a computer.

## How elvboot keeps the account

**The boot path.** The firmware's loaded images, the ACPI tables, the
EFI variables and the PCI devices are learned sets; the loader is signed
by the owner's key; the kernel and the modules are measured. This is the
part other verified-boot designs also do, and the tutorial covers it.

**Containers that never change.** The decoy root `zempty` and the rescue
root on `zcard` are immutable by construction: the root is read-only, a
session works in memory, and nothing survives it. So their state can be
pinned from outside. The witness is the sha256 over the four ZFS labels
and the GELI metadata sector, taken in the ciphertext with the container
closed. Every transaction group writes a new uberblock into the labels,
so every file that becomes visible in the pool moves the value. The
loader compares the receipts on every boot without opening anything
(`WitnessLabels`).

The decoy deserves this more than any other part. It is the one root a
coercer is let into, and a root the owner never uses is the ideal place
to leave something for a later search to find. A decoy boot moves the
witness; so does anyone who found the container and wrote to it.

**The rules for both.** They are the same for the decoy and the rescue,
and each exists because its absence would be a place to write unseen:

- *Built from records by the tool, never by hand.* What was installed is
  a list in the database with a commit id, not a memory of an afternoon.
- *A signed baseline of the tree.* `stage quarantine verify` and its
  rescue counterpart compare the content entry by entry against a
  manifest the owner signed.
- *The snapshot is the content.* A push sends a ZFS snapshot whose GUID
  is recorded; the root is set read-only and stays so.
- *A new receipt after every push, and only then.* A witness that moved
  without a push is a finding. It is never relearned silently: the owner
  measures, the receipt goes into the signed configuration, and the
  cards carry it.
- *A session leaves nothing.* `/etc`, `/var`, `/tmp` and the homes are
  memory layers; what should persist is changed on the production side
  and built into a new image.

**No free places.** A partition table has gaps, a disk has a tail, a new
container has sectors nobody wrote yet. All three hold bytes, and none
of them is in any file system. So:

- The cards are grown to their end before they are measured (workflow
  `card-grow`); there is no unallocated space after the last partition.
- A container is created with zeros over every sector. GELI
  authenticates each sector, and a sector nobody wrote does not carry a
  valid tag; an unwritten sector and a tampered one must not look alike.
- The partition table of each card and of the internal disks is a
  witness of its own (`WitnessTables`, `PartitionTables`), and so are
  the GELI metadata sectors (`GeliHeaders`). A partition added in a gap
  moves the table.
- `stage witness measure full` hashes a whole device: table, every
  partition, the tail. The loader never reads it; the owner does, on
  suspicion, and it leaves nothing out.

**Time.** A receipt says what, not when. The loader writes a chained
boot record that only it can extend: a counter, the TPM's reset count,
the NVMe power cycles, the letter of the card that booted. A boot the
owner did not make is a step in the counters between two records the
owner did make, and a card swapped for its clone shows as a changed
letter.

**Out of root's reach.** A receipt on the same disk as the data is worth
what root's honesty is worth. So the table of receipts is anchored in a
TPM index that needs the owner's passphrase to write, it is in the
signed configuration on both cards, and the lines are on paper and in a
public commit. The last one is what answers a stranger: the value was
published on a date before the dispute began.

**Deviations stay.** A fallen gate leaves a mark that blocks the next
push to the cards until the owner has read it and acknowledged it. The
owner signs the report, not the log.

## What this does not solve

- **The running production root.** Both documented cases above were
  remote access tools writing through the owner's own session. The
  production root changes with every use, so it has no receipt to
  compare, and elvboot's witnesses say nothing about a file a compromised
  session wrote. What narrows this lies beside elvboot: frequent
  snapshots replicated off the machine bound the time at which a file
  appeared, and a browser or a mail client in a guest without a view of
  the home has nothing to write into.
- **A receipt proves change, not authorship.** A moved witness says the
  container was written; who wrote it is for the boot records, the
  counters and the owner's own calendar to argue.
- **Proof for others is only as good as the publication.** A hash the
  owner alone ever saw convinces the owner. For a court it has to have
  left the owner's control at a known time: a public commit, a
  timestamp, a copy with a notary.
- **Firmware and hardware below the measurements** are outside the
  model. The measured-boot chain starts where the platform starts
  measuring.

## Where to look

- [The decoy root](the-decoy-root.md) and [the rescue boot](the-rescue-boot.md):
  the two immutable containers and how they are built.
- [The signed report](the-signed-report.md): the document a third
  party reads, and what it weighs.
- Tutorial, chapters 23 (the card proves itself), 25 (the report the
  owner signs) and 26 (the integrity witnesses).
- `elebake help stage witness`, `elebake workflow show witness-learn`,
  `card-grow`, `quarantine`, `rescue-refresh`.

## Sources

1. Arsenal Consulting, press release, "Turkish Journalists Acquitted
   After Six Years on Trial Based on Arsenal Consulting's Digital
   Forensics", 2017.
   <https://www.prnewswire.com/news-releases/turkish-journalists-acquitted-after-six-years-on-trial-based-on-arsenal-consultings-digital-forensics-300440004.html>
2. Forensic Focus, "Arsenal Reveals Sophisticated Evidence Tampering
   Involving Turkish Journalists".
   <https://www.forensicfocus.com/news/arsenal-reveals-sophisticated-evidence-tampering-involving-turkish-journalists/>
3. Scroll.in, "In Bhima Koregaon case, new forensic report shows how
   hacker planted key files on accused's computer", and the report on
   the Stan Swamy findings.
   <https://scroll.in/article/992857/in-bhima-koregaon-case-new-forensic-report-shows-how-hacker-planted-key-files-on-accuseds-computer>,
   <https://scroll.in/latest/1039689/scroll_in>
4. The Wire, on the report about Surendra Gadling's computer, and The
   Register, 7 July 2021.
   <https://thewire.in/rights/elgar-parishad-surendra-gadling-cyber-attack-documents-planted>,
   <https://www.theregister.co.uk/2021/07/07/bhima_koregaon_case_evidence_planted/>
5. SentinelLabs, "ModifiedElephant APT and a Decade of Fabricating
   Evidence", February 2022.
   <https://www.sentinelone.com/labs/modifiedelephant-apt-and-a-decade-of-fabricating-evidence/>
6. KommunalWiki, "Cyberangriff auf Landkreis Anhalt-Bitterfeld 2021".
   <https://kommunalwiki.boell.de/index.php/Cyberangriff_auf_Landkreis_Anhalt-Bitterfeld_2021>
7. Bundesamt für Sicherheit in der Informationstechnik, "Die Lage der
   IT-Sicherheit in Deutschland 2025", as reported by ZDF.
   <https://www.zdfheute.de/politik/deutschland/bsi-lagebericht-dobrindt-hacker-100.html>
8. Bundesverfassungsgericht, judgment of 27 February 2008, 1 BvR 370/07
   and 1 BvR 595/07, BVerfGE 120, 274.
   <https://www.bundesverfassungsgericht.de/SharedDocs/Entscheidungen/DE/2008/02/rs20080227_1bvr037007.html>
9. Strafprozessordnung, § 100a (5).
   <https://www.gesetze-im-internet.de/stpo/__100a.html>
10. Universität des Saarlandes, "Bundestag beschließt erweiterte
    digitale Befugnisse für BND und Verfassungsschutz", 20 November
    2026 (vote of 13 November 2026).
    <https://www.jura.uni-saarland.de/bundestag-beschliesst-erweiterte-digitale-befugnisse-fuer-bnd-und-verfassungsschutz/>
11. Deutscher Bundestag, Drucksache 21/9161 (neu), Beschlussempfehlung
    und Bericht des Innenausschusses zum Entwurf eines Gesetzes zur
    Reform des Nachrichtendienstrechts (Drucksachen 21/7868, 21/8295),
    11 November 2026.
    <https://dserver.bundestag.de/btd/21/091/2109161.pdf>
