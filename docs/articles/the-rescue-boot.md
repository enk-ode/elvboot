# The rescue boot

*One of the elvboot articles. On the reference machine the rescue pool
on the card is called `zcard` and the rescue root `zcard/ROOT/rescue`.*

## A system that must work when the other does not

Every verified-boot design has a day it was not built for: the day the
production root does not come up. A loader rebuilt with an empty policy
table, a baseline that moved, a kernel module that no longer loads, a
ZFS pool that needs a hand. On that day the owner needs a working
FreeBSD, with the tools and the keys to repair the production root, and
it needs to be trustworthy in exactly the way the production root was,
or the repair is the attack.

Most people keep a USB installer for this. An installer is a stranger: a
generic kernel, no network configuration, no tools, no database, nothing
signed by the owner, and a boot path that bypasses every gate the owner
spent months binding. elvboot's answer is a rescue system that is part
of the described system: built from the same database by the same
commands, carried on the same card as the loader, booted by the same
measured kernel, and witnessed like everything else.

## What the rescue is

The rescue is a complete FreeBSD on a GELI partition of the boot card:
the owner's package set (X11, the window manager, the browsers, the TPM
tools, printing, the smart card stack), the network configuration
mirrored one to one from the production root (bridges, WireGuard, DNS,
pf), the users with their password hashes, the host keys, and the two
databases that describe the system, elebake's and vpn-switch's, built
into the image at build time. Root is read-only on the card; `/etc`,
`/home`, `/var` and a few more get a memory layer at boot. A rescue
session leaves nothing behind. What should persist is changed on the
production side, built into a new image, and pushed onto every card.

The card is described by records, like everything else in the stage,
and the description is in the dump:

    elebake stage rescue dataset add daily-v1 zroot/ROOT/rescue     # the build root, a boot environment on the production pool
    elebake stage rescue pool add daily-v1 zcard                    # the pool every card carries
    elebake stage rescue package add daily-v1 illyria-rescue        # the meta package that names the tools
    elebake stage rescue tools add daily-v1 tpm2-tools              # one line per dependency
    elebake stage rescue config add daily-v1 /etc/rc.conf           # mirrored from production, one path per line
    elebake stage rescue local add daily-v1 'sshd_enable="NO"'      # what the rescue keeps different
    elebake stage rescue user add daily-v1 brj
    elebake stage rescue transient add daily-v1 /etc                # the memory layers

`stage rescue build` runs the phases: package install into the dataset,
kernel mirror (the stage's kernel, so loader and rescue agree on the
modules), config mirror, local write, user mirror, transient write, the
recorded patches that build the databases into the image, and a signed
baseline of the tree. `stage rescue snapshot` and `stage rescue push`
send it to a card by `zfs send`. The workflows `rescue-build` and
`rescue-refresh` are the two procedures written out.

Why a meta package and not a list of files? Because the rescue is a
system, and FreeBSD already has a vocabulary for describing a system:
packages with dependencies. `pkg create -M` from a rendered manifest,
`pkg --rootdir install` from the owner's repositories and a local one in
the stage. The version of the meta package is the export serial of the
database, so a rescue image can be traced to the dump that describes it.

## The way in

How does one get into the rescue without opening a hole? The first idea
was the loader prompt, and it was rejected: the loader prompt is too
much freedom, for the owner and for anyone else. What was built instead
is one question with a timeout, before the GELI dialog:

    loaderlock: boot the rescue root zfs:zcard/ROOT/rescue? (y/N) [3 s]

Enter, any other key, or three seconds of silence keep the silent boot
silent, so an unattended cold start never stops here. On `y` the loader
asks for the owner's acknowledgement, the one unlock passphrase whose
PBKDF2 hash it carries, because leaving the silent boot is a deviation
and every deviation is acknowledged the same way. Then the divert: the
kernel's root is set to the fixed target from the card's trust
configuration, no free text, no variable from a running system, so the
measured kernel boots nothing but the rescue root. The rescue
partition's own key file is loaded from the card; the rescue passphrase
opens it at the GELI dialog; the TPM is not asked, so the owner's seal
and the counters stay untouched, as on the duress path. The boot record
carries a RESCUE flag, and the next production boot sees that a rescue
boot lay between. It also sees the TPM reset counter and the NVMe
cycles stepped by two for one record, and says so once.

This is `offer_act`, bound on the `loaderlock` gate in the LOADER phase
with `when_always`. Its first probe on the machine taught three things
in one day, recorded in the tutorial and the source: the trust
configuration has to be read by the loader before the LOADER phase, not
by the Lua side afterwards; a key file cannot be loaded before a kernel
is; and a production `loader.conf` must name no key file for the card,
or the kernel asks for the card's passphrase on every production boot,
twelve times.

## The rescue judged by the production's rules

The first rescue boot was loud. The loader's gates measured the rescue
path against the production baselines: the PCR bank differed, because
a different root was diverted to; the sentinel question was asked three
times, so attempts and prompt window fell. Correct findings, wrong
expectations. The fix was not to silence the gates on the rescue path.
A claim on the rescue path now reads its own expectation from the
card's configuration, `loader.trust.<gate>.rescue.<claim>`, a value or
`skip`; the workflow `rescue-expectations` sets them, and the rescue
learns its own PCR once (`stage kenv learn` from a rescue boot). The
rescue has its own record too, `ElvRescueRecord`, so the production
chain is not broken by a rescue boot and the rescue's own boots are
counted.

## The card as a witness

The card carries the loader, the kernel, the rescue root, and the
chain file of the boot records. It is what the owner holds in their
hand, and the one thing an attacker with access to the room would
rather swap than the laptop. Three things keep it honest.

Each card is stamped with a letter, `EFI/elvboot/medium`, once, by a
human (`stage medium stamp`). Every push reads the stamp before writing
and refuses the wrong card; the loader records which card booted, and
`MediumSwitch` says when it changed. Two cards that are clones in every
other byte are told apart by this one.

The rescue partition is a witness: the sha256 over its ZFS labels and
GELI metadata, taken with the container closed, travels in the signed
trust configuration on both cards, and the loader compares the card in
the slot against the receipt without opening it (`WitnessLabels`,
`WitnessTables` for the partition table, `WitnessSlot` for "at least
one card we know is present"). A rescue push moves the labels and the
owner takes a new receipt; a push nobody made moves them too.

And the whole card, `stage witness measure full`: the sha256 over the
entire device, GPT, every partition, the free tail. The cards are grown
to their end first (workflow `card-grow`) so there is no unallocated
space to hide in. The loader never reads this one; the report and the
owner on suspicion do.

## What the card does not carry

The card carries only what can be revoked. The elebake database on it
is the `redacted` export: no marker values, no site baselines; the
rescue relearns them on the machine. vpn-switch's export is `full`,
because its keys are revocable. The seed from which every secret is
derived stays on the production root and is reachable from the rescue
only through the recovery slot, with the paper. A thief with the card
and its passphrase has a FreeBSD that knows how the owner's network is
built, and no way into the owner's data.

## Where to look

- `elebake help stage rescue`, `elebake workflow show rescue-build`,
  `rescue-refresh`, `rescue-expectations`, `card-grow`, `witness-learn`.
- `offer_act` in `stand/efi/loader/local/action.c` of the patch series.
- Tutorial, chapters 20 (the restore probe), 23 (the card proves
  itself) and 26 (the integrity witnesses).
