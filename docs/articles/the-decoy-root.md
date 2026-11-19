# The decoy root

*One of the elvboot articles. On the reference machine the decoy root is
a ZFS pool called `zempty`, and the article uses that name.*

## The second passphrase

The disk of an elvboot machine opens with three things: a passphrase
the owner knows, a key file on the card the owner carries, and 32 bytes
the TPM releases only while the firmware, the option ROMs and the Secure
Boot keys are what they were when the owner sealed it. The tutorial's
chapter 21 tells how the loader lost every password comparison on the
way, so that a stolen card gives no hash to test against.

But the TPM does compare. It holds two sealed objects, and the typed
passphrase is the authorization value it checks. The owner's passphrase
opens the first object, which carries the key file of the production
root. A second passphrase opens the second object, which carries the key
file of a different disk: a small GELI container on the second NVMe,
and in it a pool with one FreeBSD root, `zempty`.

From the console nothing differs. The same dialog, the same number of
tries, the same quiet after Enter. Then a login prompt. Whoever typed the
second passphrase, or made the owner type it, is looking at a running
FreeBSD with a hostname, a user, a network, and nothing else: no root
password anyone knows, no sudo, no sshd, securelevel 2, no TPM driver,
and the production providers closed. The production disks are in the
machine. They are not open, and inside this root there is no way to
open them.

## What the decoy is for

The decoy root is not a hiding place. Anyone with `gpart show` sees two
more encrypted partitions on the internal disks; elvboot does not try
for deniability against an expert, because a laptop with two NVMe
devices and three GELI containers is not deniable. The concept notes
say what the decoy is for in three words: damage limitation, evidence,
alarm.

**Damage limitation.** The data is not released. The coercer wanted an
open machine and has one; it just holds nothing. The decoy's own guard
script, `/etc/rc.d/geomcheck`, runs right after the local file systems
are mounted and before anything else: it exports every pool except its
own, detaches every GELI provider that lets itself be detached, and
unloads the TPM driver before securelevel goes up. The guard measures
the result, not the intention: if the chain that led here had a flaw and
a production provider were open, the guard closes it. A decoy that
switched itself off would not be one, so it does not halt; it empties
the room and leaves the light on.

**Evidence.** The duress opening is counted where root cannot reach: the
TPM's `pinCount` on the duress index steps on every successful opening,
and the loader raises an increment-only counter as well. Both outlive
the session, a wipe of the decoy, a reinstall. `elebake stage tpm
status` reads them with the hierarchy password, which no machine holds.

**Alarm, and a door that closes behind.** The second counter,
`duress.count.nv`, is the one that matters most. The owner's sealed
object was created against the value this counter had at seal time. Any
increment kills the object, inside the TPM, with nothing a script could
undo. The loader increments it on every duress opening; earlboot
increments it when the sentinel answer (see [the question](the-question.md))
was of the coercion class. So after one coerced boot the everyday
passphrase no longer opens anything: the next boot, forced or not, lands
in the decoy again. The coercer who forces a second attempt learns that
insisting does not help. The only way back to the production root is the
disk's other key slot, the recovery passphrase, which lives on paper
where the owner is not.

## What the owner sees afterwards

The owner's next boot, at home:

    tpm.keyfile="unsealed=0,providers=0,added=0,key=verified,duress.count=808/805,TPM_RC 0x9a2"

805 was sealed, three events since. The loader falls through to the
recovery slot and asks the passphrase from the paper. The chain of boot
records starts anew once, because the record's key is derived from the
GELI user key and that key changed with the slot. The reseal is a
workflow, `elebake workflow show duress-reseal`: reset the duress
index's count after reading it, drop the sealed value from the records,
read the counter's new value, seal both objects again, probe both, push
the new sealed value onto the cards. One more boot and the machine is
silent again. The witness of the decoy container (below) will have moved
too, because the decoy boot imported its pool, and the owner learns it
anew. Everything the coerced boot did is on record: when, how often, and
from which card.

## How the decoy is built

For a while the decoy was installed by hand, following a playbook. That
is exactly the kind of knowledge elvboot exists to replace, so since
October `stage quarantine` builds it the way `stage rescue` builds the
card: described in records, built by the tool, snapshotted, signed,
witnessed. The workflow `quarantine` is the whole procedure; its shape:

    elebake stage quarantine dataset add daily-v1 zroot/ROOT/zempty    # the build root on the production pool
    elebake stage quarantine pool add daily-v1 zempty
    elebake stage quarantine partition add daily-v1 nda1p1
    elebake stage quarantine keyfile add daily-v1 zempty.bin           # the TPM's file, on the RAM disk for every open
    elebake stage quarantine user add daily-v1 brj                     # the show user: one login, no group
    elebake stage quarantine rc add daily-v1 'kern_securelevel="2"'    # and the other rc lines, one each
    elebake stage quarantine container init daily-v1                   # GELI with the file alone, zeros, pool with ROOT
    elebake stage quarantine build daily-v1                            # base set, rc.conf, frame, user, guard, signed baseline
    elebake stage quarantine snapshot daily-v1
    elebake stage quarantine push daily-v1                             # the snapshot into the container, bootfs, readonly
    elebake stage quarantine verify daily-v1                           # signature, GUID, tree against the baseline

Three choices in the build deserve a word each.

*The container opens with the TPM's file alone.* No passphrase, no key
file on the card. The bytes are the ones the duress object seals,
derived from the owner's seed, written onto a RAM disk for each open
and wiped after. A disk without boot code and without a kernel boots
nowhere by itself; the decoy needs the loader on the card to be of any
use, and the loader only takes that way under duress.

*The content is nobody's system.* The base set from the owner's package
repository, `rc.conf` written whole from recorded lines, a root
password of 48 random bytes nobody keeps, the console marked insecure so
single user asks for it, one show user with an everyday password the
owner can hand over, read-only root with `/tmp` and `/var` in memory.
There is no `rc.conf` to mirror from production, and that is right: the
decoy must not look like the production root, it must look like a fresh
installation someone never got around to using.

*The container is a witness.* The decoy is immutable by design: a
session writes nothing that survives. So the sha256 over its four ZFS
vdev labels and its GELI metadata sector, taken in the ciphertext with
the container closed, is a receipt of its state, and the loader compares
that receipt on every boot (`WitnessLabels`), without opening anything.
A decoy boot moves the labels, because the pool was imported; the next
production boot says so. Someone who found the decoy and planted
something in it moves them too.

## Why a decoy at all, and why not a wipe

GrapheneOS answers the same threat with a duress PIN that wipes the
device. elvboot does not wipe, decided early and kept. A wipe destroys
the owner's data to protect it, which is the wrong trade for a machine
whose data is the point, and it is visible: the coercer sees a device
that just died and knows what the owner did. The decoy gives the coercer
something that looks like compliance, keeps the data sealed where it
was, and leaves the owner a way back that does not pass through the
room the coercion happened in.

VeraCrypt's hidden operating system is the closer relative, and the
difference is instructive. VeraCrypt aims at deniability: the hidden
volume should be unprovable. elvboot gives that up, as said above, and
buys two things with it: a decoy that may be built, signed and verified
openly like every other part of the system, and a TPM that takes a side.
The hidden-OS design cannot use a TPM, because a TPM that opens one
volume and not the other is itself the proof that there are two. elvboot
is content for the TPM to know. It only insists that the TPM tells
nobody else, and that what it does in response cannot be undone.

## What is not solved

- The decoy boot runs the measured kernel with a live network. A
  coercer with time has a FreeBSD shell as an unprivileged user and
  could, in principle, attack the kernel from there. securelevel 2, no
  TPM driver and detached providers are the mitigations; a kernel
  exploit is outside the model.
- The seconds between the sentinel answer and the power-off (the other
  way into the decoy, via earlboot) are seconds with the production
  keys in the kernel. The relay idea in the concept notes, an armed
  state that earlboot does not release under the coercion class, is
  designed and not built.
- The TPM counter's increment needs no authorization. root on the
  production system can raise it and kill the owner's seal: a denial of
  service, accepted, because root can keep the machine from booting in
  simpler ways and no secret is lost. The way back is the same paper.
- Deleting the everyday GELI key slot under duress, so that even the
  forced passphrase opens nothing afterwards, is written up in the
  concept notes with its conditions (a loader that can write GELI
  metadata, a recovery slot practised once, no metadata backups in
  reach). It is not built.

## Where to look

- `elebake help stage quarantine` and `elebake workflow show
  quarantine`.
- `tpm_keyfile.h` in `stand/efi/loader/local/` of the patch series:
  the two objects, two policies, two counters, and why the owner
  hierarchy is never on the boot path.
- The guard: `template/quarantine/geomcheck` in this repository.
- Tutorial, chapters 24, 26 and 27: the duress factor, the integrity
  witnesses, the quarantine built like the rescue.
