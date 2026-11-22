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

The cases below have nothing to do with one another. They come from
different countries and years, the actors differ, and so do their
reasons. They stand side by side for one purpose only: to show in how
many forms data comes to lie on a machine without its owner's doing.
For the person it happens to, it hardly matters whether one actor did
it for one reason or another actor for another. The machine says the
same thing in each case, and its owner faces the same question.

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

## Integrity in the law

The integrity of a person's own machine is a protected interest. In
Germany it has had constitutional rank since 2008, when the Federal
Constitutional Court derived a "fundamental right to the guarantee of
the confidentiality and integrity of information technology systems"
from the Basic Law [8]. Integrity, not only confidentiality.

Where the state itself accesses a system covertly, the law says what
may be changed there. Criminal procedure allows only what is
indispensable for collecting the data, requires that it be undone when
the measure ends, and requires that it be logged (§ 100a (5) StPO)
[9]. A reform of the intelligence services law, passed by the
Bundestag in November 2026, extends covert access to IT systems and
places the measures under prior review by the Independent Control
Council [10][11].

The law thus asks for what this article is about: that a change to a
system can be accounted for. For the owner of a machine the practical
question is the same in every case of this article, whoever acted and
on whatever ground: what state was the machine in, and what can be
shown about it.

## The developer's machine

A developer's laptop holds more than the developer's files. It holds
the keys that sign a release, the token that publishes a package, the
session that reaches the build system. Whoever writes on that machine
writes, one step later, on every machine that installs what the
developer ships. The cases of the last years follow one line: first the
workstation, then the project, then the project's users.

**FreeBSD, 2012.** Two head nodes of the package building cluster were
found compromised on 11 November 2012. The project traced the intrusion
to an SSH key leaked from a developer who legitimately had access, not
to a flaw in FreeBSD, and stated that it could not guarantee the
integrity of any package offered for installation between 19 September
and 11 November [12].

**Security researchers, 2021.** Google's Threat Analysis Group described
a campaign by a North Korean government-backed group against
vulnerability researchers. The attackers built a reputation over
months, proposed joint work and sent a Visual Studio project; building
it ran a DLL that connected to their server [13].

**3CX, 2023.** An employee installed a trading application on a
personal computer. Its installer had been tampered with at the vendor.
The attackers took the employee's corporate credentials from that
computer, reached the build environment of 3CX and shipped a trojanized
desktop client to its customers. Mandiant, which investigated,
attributed the intrusion to a group with a North Korean nexus and
called it the first case it had seen of one software supply chain
attack leading to another [14].

**Bybit, 2025.** The attackers posed as an open source contributor and
got a developer of Safe{Wallet}, one of the few with administrative
rights, to run a Docker project. From the workstation they took AWS
session tokens, which pass multi-factor authentication, and kept access
for nearly twenty days. They replaced one JavaScript file of the wallet
interface. When the exchange Bybit signed its next large transfer, the
funds went elsewhere: about 1.4 billion dollars, attributed by the FBI
to the North Korean group it tracks as TraderTraitor. Before leaving,
the attackers removed their malware from the developer's machine and
cleared the shell history [15].

**The npm worm, 2025.** A self-replicating package, publicly called
Shai-Hulud, searched the machines it was installed on for credentials,
published them, and used each developer's npm token to add itself to
that developer's other packages. The US agency CISA counted more than
500 compromised packages and advised rotating every developer
credential [16].

**Job interviews, since 2023.** In the campaign known as Contagious
Interview, recruiters who do not exist send developers a coding
assignment whose dependencies carry the malware. Socket counted 338
malicious npm packages in a single wave in October 2025 and attributes
the campaign to North Korean actors [17].

**axios, 2026.** The lead maintainer of the HTTP library axios was
approached about two weeks before the attack by someone posing as the
founder of a company, invited into a Slack workspace built to match,
and in a video call told that something on his system was out of date.
What he installed was a remote access tool. On 31 March 2026 two
releases of axios went out under his npm account, which had two-factor
authentication enabled; they were live for about three hours and
installed a backdoor on macOS, Windows and Linux. The affected release
lines have more than 100 million and 83 million weekly downloads.
Google attributes the attack to UNC1069, a North Korea-nexus group
active since 2018 [18][19]. The maintainer wiped every device he owned
and wrote of the tool on his machine: "they have full unilateral
control of everything on your machine" [18].

**Binance, 2026.** In September 2026 a software engineer of the
exchange was approached on a professional networking platform by
someone posing as a project director. Two video interviews followed,
then a coding assignment: a repository to download, with the malware
inside. By the exchange's account, from that workstation the attackers
reached the machines of further engineers who ran the wallet
infrastructure, on 20 October, and used an internal AI tool on the way
to the withdrawals. On 29 October about 6.3 billion dollars left
through ten blockchains in about twenty minutes, the largest theft of
its kind so far. The chief executive called it "a campaign built over
many months" [22]. The FBI tied the attack to TraderTraitor, the group
it had named in the Bybit case; North Korea denies it [22][23].

In none of these cases did the attackers have to break the project.
They wrote with the developer's own hands: the developer's key, the
developer's token, the developer's name on the release. That is also
where the first question goes afterwards. The record of a compromised
release names its publisher, and the publisher is the one who has to
show that the machine was not his own at that hour.

**Whose trace it is.** That attackers leave traces pointing at someone
else is documented between states. The malware that disrupted the
opening of the 2018 Winter Olympics carried a forged header copied from
a sample of another group, which Kaspersky identified as a deliberately
placed false flag [20]. In 2019 the British NCSC and the NSA reported
that the group Turla had taken over the tools and the infrastructure of
an Iranian group and attacked through them [21]. A public case in which
material was planted on a developer's machine to assign the blame for
an attack to that developer was not found for this article. The means
are those of the cases above: the same remote access that publishes a
release can leave a file, a shell history or a key behind, and the same
access can remove what was there, as on the workstation in the Bybit
case. After such an intrusion the machine holds what the attacker chose
to leave.

For the developer the question is therefore the one this article
started with, with a larger audience: what state was this machine in,
when, and who can check that.

## Why the base comes first

Nearly all of the cases above came over the network: a download, a
dependency, a project someone was asked to build. The defences against
that are many and they are layers: isolation of what is untrusted,
hardware tokens for keys, reviews, scanners, monitoring. elvboot is
none of them. It concerns the layer they all stand on, and the reasons
that layer comes first are technical.

**A layer cannot vouch for the layer below it.** Every defence is
software. It runs on a kernel, the kernel was loaded by a loader, the
loader by firmware. A scanner learns the list of files from the kernel;
a monitor reports through the kernel's network stack; the kernel
believes what the loader handed it. Each of them can judge what lies
above it and has to take on trust what lies below. Ken Thompson showed
in 1984 that this holds down to the compiler: a tool that was itself
altered reproduces the alteration in everything it builds, and no
inspection of the sources above it finds it [24]. The set of
components whose correctness everything else depends on is called the
trusted computing base. A defence in depth has depth only above a base
that is known.

**The base is a target in practice.** Code that runs before the
operating system decides what the operating system sees. In 2023 ESET
analysed BlackLotus, a UEFI bootkit sold on forums for 5000 dollars
that ran on fully patched systems with Secure Boot enabled, bypassing
it through a vulnerability more than a year old, and established its
persistence before the system started [25]. What sits there is out of
reach of every tool that starts later, and it survives a reinstalled
system.

**Recovery needs a place to return to.** The maintainer of axios wiped
every device he owned. That is the right answer, and it rests on a
premise: that the installer, the medium it boots from, the firmware
and the loader are what they are supposed to be. NIST's guideline for
platform firmware names three properties, protection, detection and
recovery, and defines recovery as the return to a state of integrity
[26]. Without a receipt of that state there is nothing to compare the
result of a wipe with.

**Detection needs a before.** To say that an intrusion began on a
certain day, and that the machine was the owner's own until then,
takes a state recorded earlier and a way to show that the record was
not rewritten since. A machine with no such record can report an
intrusion; it cannot bound one.

So the order is not one of importance. Most attacks will go on arriving
over the network, and the defences against them stay necessary. The
base does not stop a download. It is what gives the statements of the
other layers their value, what the rebuild starts from, and what the
owner can show when the question is what state the machine was in.

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

- **The running production root.** Most of the cases above, those of
  the developers among them, were remote access tools writing through
  the owner's own session. The production root changes with every use,
  so it has no receipt to compare, and elvboot's witnesses say nothing
  about a file a compromised session wrote. What elvboot does say after
  such an intrusion is what lay below the session: that the boot path,
  the rescue root and the decoy are in the state of their receipts, so
  the rebuild can start from a medium that is known. What narrows the
  rest lies beside elvboot: frequent snapshots replicated off the
  machine bound the time at which a file appeared; a browser, a mail
  client or a stranger's project built in a guest without a view of the
  home has nothing to write into; and a signing key on a hardware token
  that asks for a touch signs nothing the owner did not see.
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
12. The FreeBSD Project, "FreeBSD.org intrusion announced November 17th
    2012".
    <https://www.freebsd.org/news/2012-compromise/>
13. Google Threat Analysis Group, "New campaign targeting security
    researchers", 25 January 2021.
    <https://blog.google/threat-analysis-group/new-campaign-targeting-security-researchers/>
14. 3CX, "Mandiant identifies the source of internal network
    compromise", April 2023.
    <https://www.3cx.com/blog/news/mandiant-security-update2/>
15. SecurityWeek, "How Social Engineering Sparked a Billion-Dollar
    Supply Chain Cryptocurrency Heist", 6 March 2025.
    <https://www.securityweek.com/how-social-engineering-sparked-a-billion-dollar-supply-chain-cryptocurrency-heist/>
16. CISA, "Widespread Supply Chain Compromise Impacting npm Ecosystem",
    23 September 2025.
    <https://www.cisa.gov/news-events/alerts/2025/09/23/widespread-supply-chain-compromise-impacting-npm-ecosystem>
17. Socket, "North Korea's Contagious Interview Campaign Escalates: 338
    Malicious npm Packages", October 2025.
    <https://socket.dev/blog/north-korea-contagious-interview-campaign-338-malicious-npm-packages>
18. Jason Saayman, "Post Mortem: axios npm supply chain compromise",
    axios issue 10636, 2 April 2026, with the maintainer's comments.
    <https://github.com/axios/axios/issues/10636>
19. Google Threat Intelligence Group, "North Korea-Nexus Threat Actor
    Compromises Widely Used Axios NPM Package in Supply Chain Attack",
    31 March 2026.
    <https://cloud.google.com/blog/topics/threat-intelligence/north-korea-threat-actor-targets-axios-npm-package/>
20. Kaspersky, "The devil's in the Rich header", Securelist, March 2018.
    <https://securelist.com/the-devils-in-the-rich-header/84348/>
21. National Cyber Security Centre (UK), update on the Turla group,
    with the joint advisory of NCSC and NSA, 21 October 2019.
    <https://www.ncsc.gov.uk/news/turla-group-behind-cyber-attack>
22. Brussels Signal, "Binance shares details of €5.7 billion crypto
    heist", 4 November 2026, on the exchange's findings of 3 November.
    <https://brusselssignal.eu/2026/11/binance-shares-details-of-e5-7-billion-crypto-heist/>
23. Associated Press, as carried by PBS News, "FBI says North Korea was
    behind $6.3 billion Binance heist, the biggest crypto hack in
    history", 1 November 2026.
    <https://www.pbs.org/newshour/world/fbi-says-north-korea-was-behind-6-3-billion-binance-heist-the-biggest-crypto-hack-in-history>
24. Ken Thompson, "Reflections on Trusting Trust", Communications of
    the ACM 27 (8), August 1984.
    <https://doi.org/10.1145/358198.358210>
25. ESET Research, "ESET Research analyzes BlackLotus: A UEFI bootkit
    that can bypass UEFI Secure Boot on fully patched systems", March
    2023.
    <https://www.eset.com/us/about/newsroom/research/eset-research-analyzes-blacklotus-a-uefi-bootkit-that-can-bypass-uefi-secure-boot-on-fully-patched-systems>
26. NIST Special Publication 800-193, "Platform Firmware Resiliency
    Guidelines", May 2018.
    <https://doi.org/10.6028/NIST.SP.800-193>
