# The question

*One of the elvboot articles. The tutorial records how the tool was
built; these pages explain one idea each, from the owner's side, and say
why it is built the way it is. The question on the reference machine is
"Do you have fish?", and the article keeps that name.*

## A quiet suspicion

Imagine the morning after a trip. The laptop lies where you left it, in
the hotel room, in the office, on the kitchen table. Nothing is visibly
wrong. But you were out for two hours, the door was not locked the whole
time, and somewhere in the back of your mind a small voice says: did
someone touch this?

Full disk encryption answers a different question. It promises that a
thief who takes the disk reads nothing. It does not promise that the
machine you are about to type your passphrase into is still your
machine: the loader that asks could have been swapped, a firmware
setting changed, the boot stick cloned. And it has nothing at all to say
about the other case, the one nobody likes to think through: the person
next to you who wants the machine open and is prepared to insist.

Both cases have the same shape. The machine cannot know. It can measure
a great deal, and elvboot's loader does: firmware state, option ROMs,
the GPT of every disk, the ACPI tables, the EFI variables, the TPM's
counters and clock, the NVMe's power cycles, the time since the last
boot, the card in the slot. The tutorial's chapters 17 to 24 tell how
each of these became a claim. But there is one instrument the platform
cannot enumerate, and it is the one that was in the room: the owner.
You know whether you switched the machine on last night. You know
whether the person beside you is a friend. The machine does not, and no
sensor will tell it.

So the loader asks.

## The question at the end of the boot

Late in the boot, after the disk is open and before the kernel starts,
the loader prints one line and waits:

    kernellock: boot 812, last 2026-11-16T22:41:07, cycles +1, unclean +0, gates 8 ok 0 failed, attempts 1
    Do you have fish?

The first line is the context line: this boot's number, the time of the
previous boot, how many times the machine was powered on since then and
how many of those were unclean, how the gates did, how many hidden
lines were typed so far. The owner reads it the way one reads a
familiar face. Last boot yesterday evening, one power-on since: that is
me, now. Two power-ons: someone switched this on while I slept. The
machine has already counted; the line hands the count to the one who
can place it in a story.

Then the question. It is deliberately innocent. "Do you have fish?" has
no right answer a stranger could guess, and it does not look like a
security prompt. The answer is typed hidden, like a passphrase, and the
loader does exactly one thing with it: it hashes the answer together
with a salt and publishes the hash as a kernel environment variable,
`loader.trust.kernellock.answer`, alongside the hash of its first
character. Then it boots the kernel. Whatever was typed, including
nothing, the loader behaves identically. It never says "wrong". It does
not know what wrong is.

## Where the judgment lives

The classification happens later, behind the encrypted root, in
`earlboot`, the rc script elebake generates and that runs right after
the local file systems are mounted. There the salted hashes of the
owner's answer words are expectations, one per class, each with a
policy that says what to do:

- the everyday word: log a line, carry on. This is the silent boot.
- the "I am not sure" word: log, spool a note, set a mark that the
  next boot and the daily report will show. The owner typed it because
  the context line said two power-ons where one was expected, or
  because the hotel door was open. Nothing visible happens now, and
  that is the point: a suspicion is not yet a verdict, but it is on
  record, with a time, before anyone could have talked the owner out of
  it.
- the coercion words, several of them: spool the finding, raise the
  TPM's duress counter, power off. On the console it looks like the
  machine simply stopped. Someone watching sees a boot that did not
  complete, which happens. What they cannot see is that the owner's
  sealed TPM object is dead from this moment on: the next boot with the
  everyday passphrase opens the decoy root (see [the decoy
  root](the-decoy-root.md)), and only the recovery passphrase on paper,
  which is not in the room, brings the production back.
- no word of ours, or no word at all: the catch-all class fires. It is
  treated as manipulation, not as a typo: spool and power off. The
  owner without the word is a stranger until proven otherwise, and the
  owner with a typo pays one reboot.

Every class is a set, not a word. The reaction belongs to the policy,
the policy to a neutral name, `fish-7`, and the word is nowhere on the
machine. Whoever reads the database learns that a class named `fish-7`
leads to a power-off. They do not learn the word, nor how many words
there are, nor which of them the owner would type with a hand on their
shoulder.

## Why the loader does not classify

The obvious design would be to put the comparison where the question
is asked: the loader knows the hashes, compares, reacts. elvboot does
not do that, for a reason that is easy to state and easy to forget.

The loader binary lives on the medium the owner carries, the card.
Whoever takes the card for an afternoon has the binary, and with it
every hash compiled into it. The code is public. A passphrase overheard
once, a word seen typed once, can then be hashed at home and compared
against the list: this one is the everyday word, that one is the
duress word. A duress signal that can be told apart at leisure is worth
nothing. The same argument removed every password comparison from the
loader in September (tutorial, chapter 21): the GELI passphrase is not
compared either, it is applied, and the TPM judges it.

So the loader measures and publishes. The classification sits where
the card thief cannot read it, behind the encrypted root, in a table
that only exists once the disk is open. And because the answer hashes
are salted with a value that lives on the card and not in the loader
binary, the hashes that do reach the running system cannot be swept
with a dictionary by someone who has only the binary.

There is a cost, stated plainly. The reaction cannot happen before the
disk is open, because the table that decides is on the disk. Under
coercion the machine therefore does boot, with the keys in the kernel,
for the seconds it takes earlboot to read the kenv and power off. The
concept notes call this the relay: the system cannot refuse what the
coercer already has, it can only withhold what is not yet released,
record, and raise an alarm later. The TPM counter is the part of the
alarm that cannot be undone from the running system, which is why it
is raised first and the power-off comes last.

## What the owner has to do

Answers wear out. A word seen over the shoulder is burnt, and must be
replaced the next day. That is deliberate user discipline, not a tool
feature; the mechanics make it cheap:

    elebake answer drop daily-v1 SYSINIT fish-3
    elebake answer add  daily-v1 SYSINIT kernellock fish-3 react-halt     # the new word, read hidden, twice

The word is read from the terminal, hidden, twice, hashed with the
stage's salt, and never reaches argv, the shell history, the trace or
the batch. It exists in the owner's inventory on paper, nowhere else.
`elebake answer show daily-v1` lists the classes by their policies; it
cannot list words, because it has none.

The question itself travels on the card as a kenv leaf, so every medium
can carry its own question, and a thief with two cards does not learn
that they belong together. The context line is configuration too, and
the default shows nothing: the coercer reads the line as well, so only
items whose knowledge does not help an attacker belong in it. The six
items above are the ones chosen on the reference machine.

## Why the question is not a second passphrase

A second passphrase would be a knowledge factor. The question is
something else: a channel for a judgment the owner has already made,
with the coercer watching. The passphrase proves that the owner is at
the keyboard. The answer says what the owner thinks of the situation,
in a form the situation cannot read.

That is also why the empty and the wrong answer are treated alike and
harshly. A duress word that is worth something must look like success
to the coercer, so the everyday word and the duress word both boot the
machine. A system that had a soft failure mode for "I forgot" would
hand the coercer a safe third option: type nothing, see what happens.
There is nothing safe to see. The owner who forgets the word reboots
and types the recovery passphrase in single user mode, where earlboot
does not run, and starts again from the playbook. That is the price of
a prompt that cannot be bargained with.

## What is not solved

The article would be dishonest without this list.

- Whoever knows the design knows there is a second word and can demand
  it. No mechanism helps against that. What the owner has is that
  every word of the coercion class is equally plausible and that
  nothing on the machine says which class a word is in.
- The question is asked once per boot. A coercer who forces a second
  boot gets a second answer. The TPM counter has stepped by then and
  the second boot lands in the decoy root, which is the designed
  outcome, but it is an outcome, not a defence of the data in the
  first boot's seconds.
- The context line is only as honest as the loader that prints it,
  which is why the display is bound after the record claims and why
  `reveal_act` exists to let the owner recognise the binary before
  typing anything. Secure Boot with the owner's own keys is assumed
  throughout.
- The dwell time, the cadence and the time-of-day tells from the
  concept exist as measurements (`measure_time.c`), but on the reference
  machine only the word classes are bound. The others are judged after
  a series of boots, not before.

## Where to look

- `elebake help answer` lists the family: `answer add`, `answer hash
  add`, `answer file add`, `answer catchall add`, `answer drop`,
  `answer show`.
- The loader side is `sentinel_act` and `display_act` in
  `stand/efi/loader/local/action.c` of the patch series; the earlboot
  side is `measure_answer`, `measure_answer_first`,
  `measure_answer_matched` and `answer_matched_act` in
  `local/earlboot/`.
- Workflow `duress-bind` (`elebake workflow show duress-bind`) puts the
  TPM counter in front of the power-off for every coercion class.
- Tutorial, chapters 21, 22 and 24: the three factors, the time
  anchor and the duress factor the question is bound into.
