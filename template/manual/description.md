# DESCRIPTION

**elebake** maintains the trust chain of a locally built FreeBSD boot
loader: checked-out source, measured expectations, Authenticode
signature, OpenPGP-attested manifest, deployment to removable boot
media, and tamper witnesses read back at boot. Detection, not
enforcement: the design assumes the boot medium *can* be tampered with
and concentrates on noticing.

Every **elebake** command is a *generator*: it emits shell text
describing an action. Whether that text is displayed, piped, or
executed is decided by an *interpreter* the operator controls per
function (see ENVIRONMENT). The shipped default displays (`cat`):
inspect first, then pin an executing interpreter. Batch commands emit an
unconditional sequence of further **elebake** commands; checking is
itself a command in the sequence, and the batch machinery stops at the
first failure.

The command reference below is generated from the tool's own help
corpus and is therefore always current; `elebake help` renders the same
corpus in the terminal.
