# How the disk opens

*One of the elvboot articles. A walk through the loader at run time,
from the typed passphrase to the kernel that finds its root open: first
the owner's way, then the duress way, then the rescue way. The code is
the patch series under `stand/efi/loader/local/` of the FreeBSD fork;
excerpts are shortened (`[...]`) and re-wrapped, nothing else. Device
names are those of the reference machine.*

## The material

Three things open the production root, and each alone opens nothing:

- **the passphrase**, typed at the one dialog of the boot;
- **the card's key file**, `/boot/keys/zroot.key` on the boot medium,
  preloaded by `loader.conf` for every production provider;
- **the TPM's key file**, 32 bytes sealed in the TPM, released into the
  loader's memory when the TPM agrees.

On the disks this is GELI's ordinary key model. A provider has two key
slots, each holding the master key encrypted under a user key:

| Provider | Slot 0 | Slot 1 |
|---|---|---|
| `nda0p1`, `nda2p1` (production) | passphrase + `zroot.key` + TPM file | recovery passphrase alone |
| `nda1p1` (decoy, `zempty`) | the duress object's file alone | |
| rescue partition on the card | rescue passphrase + the card's key file | |

The TPM holds two sealed objects and three NV indices that matter here:

| Object or index | Opens under | Holds |
|---|---|---|
| owner object | PolicyPCR, PolicyAuthValue, PolicyNV(counter == sealed value) | the production TPM file |
| duress object | PolicySecret(PIN index), PolicyPCR | the decoy's key file |
| PIN index (`duress.nv`) | its authValue is the duress passphrase | counts each use |
| `duress.count.nv` | increment-only counter | the value the owner object is sealed against |
| `counter.nv` | increment-only counter | the trace of duress openings |

The loader compares no passphrase. That sentence is the design, and the
walk below is its proof: at no point does a typed line meet a stored
hash of itself.

## When it runs

The dialog runs in the KERNEL phase: the kernel and the modules are
loaded and verified, the interactive window is over, and
`ExitBootServices` has not been called. `elf64_exec` calls it just
before the boot information is packed:

    #ifdef LOADER_VERIEXEC
            local_run_kernel();
    #endif
            [...]
            err = bi_load(fp->f_args, &modulep, &kernend, true);

Inside the phase the dialog is lazy. The first claim that needs the
boot record asks for the record's key, the record's key comes from the
GELI user keys, and so that claim triggers `geli_open_ensure()`. If no
such claim is bound, `local_run()` calls it after the policies, so the
kernel always gets its keys:

    if (ph == PHASE_KERNEL) {
            geli_open_ensure();
            if (evidence()->duress) {
                    record_cap();
                    decoy_divert();
                    return;
            }
            if (evidence()->rescue)
                    rescue_divert();
            (void)record_commit(record_flags());
            record_cap();
    }

## The dialog

`geli_open.c` is short enough to read whole. Its loop:

    for (t = 1; t <= max; t++) {
            printf("\nGELI passphrase: ");
            readsecret(pw, sizeof(pw));
            printf("\n");
            if (!evidence()->rescue)
                    tpm_keyfile_prepare(pw);
            if (geli_keys_prepare(pw, evidence()->rescue ? false :
                tpm_keyfile_state()->unsealed) > 0) {
                    explicit_bzero(pw, sizeof(pw));
                    opened = true;
                    return;
            }
            explicit_bzero(pw, sizeof(pw));
            printf("no provider opened (%s)\n", geli_keys_reason());
    }
    (void)halt_count_raise();
    halt_boot("no provider opened");

A line is typed, handed to the TPM, handed to GELI, and wiped. It is
never put into the environment and never kept for a later attempt. The
only proof that it was right is a provider that opens. `max` is
`loader.trust.geli.tries`, three by default; after that the boot halts,
a TPM counter records the halt, and the retry is a cold start through
the whole chain.

`readsecret()` reads without echo and measures while it reads:

    while ((c = getchar()) != '\r' && c != '\n' && c != -1) {
            clock_now(&tk);
            if (!first) {
                    gap = clock_ms_between(&tprev, &tk);
                    if (gap > cadence)
                            cadence = gap;
            }
            [...]
            if (n + 1 < sz)
                    buf[n++] = c;
    }
    buf[n] = '\0';
    clock_now(&tk);
    evidence_note_prompt(clock_ms_between(&t0, &tk), cadence);
    evidence_note_attempt();

The time from the prompt to Enter, the longest pause between two keys
and the number of attempts go to the evidence ledger. They become
claims of their own (`PromptWindow`, `Attempts`); nothing about the
line itself is kept.

## The owner's way

The whole way in one picture (the source is
`how-the-disk-opens-owner.puml`, rendered with `plantuml -ttxt`):

         ,-.          ,-.                            ,-.               ,-.          ,-.
         |O|          |L|                            |T|               |D|          |K|
         `+'          `+'                            `+'               `+'          `+'
          |passphrase  |                              |                 |            |
          |----------->|                              |                 |            |
          |            |                              |                 |            |
          |            |     ReadPublic(key) [c]      |                 |            |
          |            |----------------------------->|                 |            |
          |            |                              |                 |            |
          |            |    name, public part [c]     |                 |            |
          |            |<- - - - - - - - - - - - - - -|                 |            |
          |            |                              |                 |            |
          |            |----.                         |                 |            |
          |            |    | name == baseline        |                 |            |
          |            |<---'                         |                 |            |
          |            |                              |                 |            |
          |            |StartAuthSession(OAEP(salt))  |                 |            |
          |            |----------------------------->|                 |            |
          |            |                              |                 |            |
          |            |    session, nonceTPM [c]     |                 |            |
          |            |<- - - - - - - - - - - - - - -|                 |            |
          |            |                              |                 |            |
          |            |----.                         |                 |            |
          |            |    | sessionKey = KDFa(salt) |                 |            |
          |            |<---'                         |                 |            |
          |            |                              |                 |            |
          |            |                              |----.            |            |
          |            |                              |    | sessionKey |            |
          |            |                              |<---'            |            |
          |            |                              |                 |            |
          |            |        PolicyPCR [c]         |                 |            |
          |            |----------------------------->|                 |            |
          |            |                              |                 |            |
          |            |     PolicyAuthValue [c]      |                 |            |
          |            |----------------------------->|                 |            |
          |            |                              |                 |            |
          |            |     PolicyNV(count) [c]      |                 |            |
          |            |----------------------------->|                 |            |
          |            |                              |                 |            |
          |            |      Unseal(owner) [h]       |                 |            |
          |            |----------------------------->|                 |            |
          |            |                              |                 |            |
          |            |        file [e] [h]          |                 |            |
          |            |<- - - - - - - - - - - - - - -|                 |            |
          |            |                              |                 |            |
          |            |----.                         |                 |            |
          |            |    | verify HMAC, decrypt    |                 |            |
          |            |<---'                         |                 |            |
          |            |                              |                 |            |
          |            |----.                         |                 |            |
          |            |    | preload file            |                 |            |
          |            |<---'                         |                 |            |
          |            |                              |                 |            |
          |            |               read last sectors                |            |
          |            |----------------------------------------------->|            |
          |            |                              |                 |            |
          |            |                 GELI metadata|                 |            |
          |            |<- - - - - - - - - - - - - - - - - - - - - - - -|            |
          |            |                              |                 |            |
          |            |----.                         |                 |            |
          |            |    | PBKDF2(passphrase)      |                 |            |
          |            |<---'                         |                 |            |
          |            |                              |                 |            |
          |            |----.                         |                 |            |
          |            |    | HMAC(files, PBKDF2)     |                 |            |
          |            |<---'                         |                 |            |
          |            |                              |                 |            |
          |            |----.                         |                 |            |
          |            |    | master key verifies     |                 |            |
          |            |<---'                         |                 |            |
          |            |                              |                 |            |
          |            |                    user keys, key files        |            |
          |            |------------------------------------------------------------>|
          |            |                              |                 |            |
          |            |                              |                 |  attach    |
          |            |                              |                 |<-----------|
          |            |                              |                 |            |

O = owner, L = loader, T = TPM, D = disks, K = kernel. A dashed arrow
is an answer; an arrow back to its own line is a step inside.

How each message to and from the TPM travels:

- `[c]` in clear: public data and policy commands, no secret in them.
- `OAEP(salt)`: the session's salt, RSA-encrypted to the storage key.
  Both sides derive the session key from it; the key never travels.
- `[h]` authorized by an HMAC whose key is the session key and the
  auth value (the SHA256 of the typed line).
- `[e]` encrypted by the TPM with AES-128-CFB under a key derived from
  the session key and the auth value.

So the session is salted, authenticated and, for the one secret that
crosses the bus, encrypted. Steps 2 to 4 below show the code.

### 1. The line goes to the TPM

`tpm_keyfile_prepare()` first reads its configuration from the leafs
of the signed trust configuration (`loader.trust.tpm.*`): the handle
of the storage key, the two object handles, the providers, the PCR
list, the indices, and the counter value the owner object was sealed
against. A missing or malformed leaf ends the attempt with a reason;
nothing is tried on half a configuration.

Then the storage key. Every session below is salted to it, so it must
be the key the owner provisioned and not one a manipulated firmware
offers:

    if (!key_digest_baseline(base)) {
            st.reason = "incomplete: no storage key baseline [...]";
            return;
    }
    if (!tpm_key_digest(keyhandle, kd)) {
            st.reason = "storage key unread";
            return;
    }
    [...]
    if (!ct_equal(kd, base, sizeof(kd))) {
            st.reason = "storage key is not the one in the baseline";
            return;
    }

`base` is compiled into the loader (`LOADER_TRUST_TPM_KEY_DIGEST`);
`kd` is the digest of the key's name as `TPM2_ReadPublic` returns it. A
session salted to a foreign key would hand that key's holder the salt,
and with the salt an offline test for the passphrase. Without a
matching name no session is opened.

The typed line becomes an auth value:

    SHA256_Init(&ctx);
    SHA256_Update(&ctx, passphrase, strlen(passphrase));
    SHA256_Final(auth, &ctx);

This is what `tpm2_create -p` took when the object was sealed. It is
the object's authValue, known to the TPM and to nobody else; the loader
computes it from the line and holds it for the length of this function.

The owner's policy, in the order it was sealed in:

    const struct tpm_policy_step owner[] = {
            { .op = TPM_POLICY_PCR, .mask = mask },
            { .op = TPM_POLICY_AUTHVALUE },
            { .op = TPM_POLICY_NV, .index = cntindex, .oplen = 8,
              .offset = 0, .eo = TPM_EO_EQ, .operand = { sealed8[0],
              [...] sealed8[7] } },
    };

    ok = tpm_unseal(keyhandle, kdp, handle, owner,
        TPM_KEYFILE_STEPS(owner), auth, sizeof(auth), secret,
        sizeof(secret), &len);

### 2. The session

There is no TPM driver in the loader. `tpm.c` builds raw TPM 2.0
commands and passes them to the firmware:

    if (EFI_ERROR(t->SubmitCommand(t, cmd->n, cmd->p, rcap, resp))) {
            last_error = "SubmitCommand failed";
            return (false);
    }

The bus between CPU and TPM is assumed to be readable. So the session
is salted and encrypting, and `session_start()` sets it up in four
steps.

*The salt.* 32 bytes and the caller's nonce come from RDRAND, not from
the TPM: `TPM2_GetRandom` would send them over the bus in clear. A CPU
without RDRAND ends the attempt; there is no fallback to an unsalted
session.

*The salt to the TPM.* It is encrypted to the storage key's RSA public
part with OAEP, label `SECRET`:

    enclen = br_rsa_i31_oaep_encrypt(rnd, &br_sha256_vtable, label,
        sizeof(label), &pk, enc, sizeof(enc), salt, sizeof(salt));

*The command.* `TPM2_StartAuthSession` with the storage key as
`tpmKey`, no bind, the caller's nonce, the encrypted salt, session type
policy, AES-128-CFB as the symmetric algorithm, SHA256 as the hash.

*The session key.* Both sides derive it; it never travels:

    kdfa(salt, sizeof(salt), "ATH", s->nonce_tpm, s->nonce_tpm_len,
        s->nonce_caller, sizeof(s->nonce_caller), 256, s->key);

### 3. The policy, replayed

The loader does not compute a policy digest. It issues the policy
commands in order and the TPM accumulates the digest in the session:

    case TPM_POLICY_PCR:
            ok = policy_pcr(s.handle, st->mask);
            break;
    case TPM_POLICY_AUTHVALUE:
            ok = policy_authvalue(s.handle);
            break;
    [...]
    case TPM_POLICY_NV:
            ok = policy_nv(s.handle, st->index, st->operand,
                st->oplen, st->offset, st->eo);
            break;

- **PolicyPCR** is sent with an empty `pcrDigest`: the TPM folds in the
  PCRs it holds now (on the reference machine 0, 2 and 7: firmware
  code, option ROMs, Secure Boot state). A changed firmware gives a
  different digest and the object stays closed. The loader cannot
  assert PCR values; it can only ask.
- **PolicyAuthValue** tells the TPM that the command to come must be
  authorized with the object's authValue in the session's HMAC key.
- **PolicyNV** makes the TPM read `duress.count.nv` and compare its
  eight bytes with the operand, the value at seal time. The index
  authorizes its own read with an empty password, so the owner
  hierarchy is not used on the boot path. If the counter has moved, the
  command fails here and the walk for this object is over.

### 4. Unseal

The command carries no passphrase and no hash of one. It carries an
HMAC whose key includes the auth value:

    memcpy(key, s->key, sizeof(s->key));
    memcpy(key + sizeof(s->key), s->auth, s->authlen);
    hmac256(key, sizeof(s->key) + s->authlen, cphash, sizeof(cphash),
        s->nonce_caller, sizeof(s->nonce_caller), s->nonce_tpm,
        s->nonce_tpm_len, &attrs, 1, mac);

`cphash` is SHA256 over the command code and the name of the sealed
object. The TPM computes the same HMAC with the authValue it stored
when the object was created. If the typed line was wrong, the two
differ and the TPM refuses; the loader learns a response code and
nothing else.

If the TPM agrees, it answers with the 32 bytes encrypted. The key and
the IV again come from both secrets:

    kdfa(key, sizeof(s->key) + s->authlen, "CFB", s->nonce_tpm,
        s->nonce_tpm_len, s->nonce_caller, sizeof(s->nonce_caller),
        256, kiv);
    [...]
    memcpy(out, r + poff + 2, sz);
    if (!cfb_decrypt(kiv, kiv + 16, out, sz))
            goto out;

Before decrypting, `check_response()` verifies the TPM's HMAC over the
response with the same key. A wrong HMAC means the answer did not come
from the TPM the session was started with, and the attempt ends.

So on the bus there were: an RSA-encrypted salt, nonces, HMACs, and an
AES-encrypted answer. Whoever recorded all of it holds nothing to test
a passphrase against without the storage key's private part, which
does not leave the TPM.

### 5. The file is placed

The 32 bytes become a preloaded file, as if `loader.conf` had loaded
them from a medium:

    snprintf(type, sizeof(type), "%s:geli_keyfile%d", prov,
        next_index(prov));
    if (file_addbuf("tpm.keyfile", type, len, secret) == 0)
            st.added++;

`next_index()` finds the first free number after the files already
preloaded for that provider. The card's `zroot.key` is
`nda0p1:geli_keyfile0`, so the TPM's file becomes
`nda0p1:geli_keyfile1`, and the same for `nda2p1`. The order matters:
GELI hashes key files in this order, and it is the order `geli setkey
-K zroot.key -K tpm.bin` used. Then:

    explicit_bzero(secret, sizeof(secret));

The loader's own copy is gone. The bytes exist once more, in the
preload area, where the derivation below and later the kernel read
them.

### 6. The disks are tasted

`geli_keys_prepare()` walks the fixed disks the firmware shows,
`disk0` to `disk7`, opens each as a whole disk, reads its partition
table and looks at the last sector of every partition for GELI
metadata:

    error = keys_partread(NULL, c, at, buf, DEV_GELIBOOT_BSIZE);
    if (error == 0) {
            error = eli_metadata_decode(buf, md);
            [...]
    }
    [...]
    if ((md->md_flags & G_ELI_FLAG_ONETIME) != 0 ||
        (md->md_flags & (G_ELI_FLAG_BOOT | G_ELI_FLAG_GELIBOOT)) == 0) {
            explicit_bzero(md, sizeof(*md));
            return (false);
    }

Providers the kernel attaches at boot (flag BOOT) are taken; swap with
its one-time key is skipped. Nothing is attached and nothing is
decrypted here: the loader derives keys, the kernel opens disks.
Removable media are not tasted on this way. A planted provider on a
stick would cost its PBKDF2 and could open nothing. The metadata is
not authenticated at this point, so its iteration count is capped:

    #define GELI_ITERATIONS_MAX     (1 << 24)

### 7. The user key

`keys_derive()` builds the user key the way the kernel's `g_eli_taste`
does. The loader cannot tell which `diskNpM` is `nda0p1`, so it
collects the provider names from the preloaded files and tries each
provider's set of key files in turn.

The first round runs only when the TPM released its file. It tries the
key files alone, without the passphrase and before any PBKDF2:

    for (g = 0; g < np && !ok && keyfiles_only; g++) {
            g_eli_crypto_hmac_init(&ctx, NULL, 0);
            nfiles[g] = keys_hmac_keyfiles(&ctx, provs[g]);
            if (nfiles[g] <= 0)
                    continue;
            g_eli_crypto_hmac_final(&ctx, key, 0);
            if (g_eli_mkey_decrypt_any(md, key, mkey, &keynum) == 0) {
                    geli_add_key(key);
                    ok = files = true;
            }
    }

On a production provider this round finds nothing: slot 0 was set with
a passphrase. It is the round that opens the decoy, further down.

Then the passphrase part, computed once per provider:

    pkcs5v2_genkey(dkey, sizeof(dkey), md->md_salt,
        sizeof(md->md_salt), passphrase, md->md_iterations);

PBKDF2-HMAC-SHA512 over the typed line, with the salt and the
iteration count from the provider's metadata. This is the expensive
step, seconds per disk, and it is where a guess at the passphrase
costs what GELI makes it cost.

The second round folds key files and passphrase together:

    for (g = 0; g <= np && !ok; g++) {
            g_eli_crypto_hmac_init(&ctx, NULL, 0);
            if (g < np) {
                    nfiles[g] = keys_hmac_keyfiles(&ctx, provs[g]);
                    if (nfiles[g] <= 0)
                            continue;
            } else if (md->md_iterations < 0)
                    break;
            [...]
            } else if (md->md_iterations > 0)
                    g_eli_crypto_hmac_update(&ctx, dkey, sizeof(dkey));
            g_eli_crypto_hmac_final(&ctx, key, 0);
            if (g_eli_mkey_decrypt_any(md, key, mkey, &keynum) == 0) {
                    geli_add_key(key);
                    ok = true;
            }
    }

The user key is an HMAC-SHA512 with an empty key over, in this order:
the bytes of `zroot.key`, the bytes of the TPM's file, the 64 bytes of
the PBKDF2 output. Three factors, one 64-byte value. The last pass of
the loop (`g == np`) is the passphrase alone, which is what slot 1
takes.

`g_eli_mkey_decrypt_any()` is the judge. For each of the two slots it
derives an encryption key from the user key, decrypts the slot's copy
of the master key and verifies the HMAC stored with it:

    g_eli_crypto_hmac(key, G_ELI_USERKEYLEN, "\x01", 1, enckey, 0);
    [...]
    error = g_eli_crypto_decrypt(md->md_ealgo, tmpmkey,
        G_ELI_MKEYLEN, enckey, md->md_keylen);
    [...]
    if (g_eli_mkey_verify(tmpmkey, key)) {
            bcopy(tmpmkey, mkey, G_ELI_DATAIVKEYLEN);

A master key that verifies is the proof that all three inputs were
right. The loader does not keep it: `mkey` is wiped at the end of
`keys_derive()`. What it keeps is the user key, and the number of the
slot that opened:

    if (ok)
            keys_files_slot = ok && keynum == 0;

Slot 0 is the silent case. Slot 1 means the recovery passphrase was
used, and the claim `GeliSlot` says so in the record.

### 8. To the record and to the kernel

`geli_add_key()` stores the user key in libsa's key buffer. Two
consumers follow.

The boot record takes its keying material from there, as a digest over
every user key of this boot in a canonical order:

    SHA256_Init(&ctx);
    for (i = 0; i < nsaved_keys; i++)
            SHA256_Update(&ctx, sorted[i], G_ELI_USERKEYLEN);
    SHA256_Final(out, &ctx);

So the record's MAC key depends on the passphrase, the card's file and
the TPM's file together, and a guess at the record costs the same
PBKDF2 as a guess at the disk.

The kernel takes the keys themselves. `bi_load()` attaches the buffer
to the kernel's metadata and wipes the loader's copy:

    geli_export_key_buffer(keybuf);
    file_addmetadata(kfp, MODINFOMD_KEYBUF, GELI_KEYBUF_SIZE, keybuf);
    explicit_bzero(keybuf, GELI_KEYBUF_SIZE);

In the kernel, `g_eli_taste` tries the buffer's keys on each provider
before it does anything else:

    if (g_eli_mkey_decrypt_any(&md, key, mkey, &nkey) == 0 ) {
            explicit_bzero(key, sizeof(key));
            goto have_key;
    }

The providers attach, the pool imports, the root mounts. The kernel
computed no PBKDF2 and asked nothing. The preloaded key files are
still there for it, the TPM's among them, but it did not need them.

### What a wrong line costs

- **In the TPM:** the HMAC of `Unseal` does not match, the TPM refuses,
  and the loader then tries the duress object with the same line
  (below), which refuses as well.
- **On the disks:** no TPM file was placed, so the first round is
  skipped; PBKDF2 runs per provider; no set fits. The dialog prints
  the reason and asks again.
- **After the last try:** `halt_boot()` wipes what could be left and
  powers the machine off:

      tpm_keyfile_wipe();
      geli_keys_wipe();

The recovery passphrase is typed at the same prompt. The TPM refuses
it like any wrong line; the second round reaches its last pass, the
passphrase alone, and slot 1 opens.

## The duress way

The whole way in one picture (the source is
`how-the-disk-opens-duress.puml`, rendered with `plantuml -ttxt`):

         ,-.          ,-.                           ,-.                 ,-.          ,-.
         |O|          |L|                           |T|                 |D|          |K|
         `+'          `+'                           `+'                 `+'          `+'
          |passphrase  |                             |                   |            |
          |----------->|                             |                   |            |
          |            |                             |                   |            |
          |            |     Unseal(owner) [h]       |                   |            |
          |            |---------------------------->|                   |            |
          |            |                             |                   |            |
          |            |          refused            |                   |            |
          |            |<- - - - - - - - - - - - - - |                   |            |
          |            |                             |                   |            |
          |            |StartAuthSession(OAEP(salt)) |                   |            |
          |            |---------------------------->|                   |            |
          |            |                             |                   |            |
          |            |   StartAuthSession, 2nd     |                   |            |
          |            |---------------------------->|                   |            |
          |            |                             |                   |            |
          |            |   PolicySecret(PIN) [h2]    |                   |            |
          |            |---------------------------->|                   |            |
          |            |                             |                   |            |
          |            |                             |----.              |            |
          |            |                             |    | pinCount + 1 |            |
          |            |                             |<---'              |            |
          |            |                             |                   |            |
          |            |       PolicyPCR [c]         |                   |            |
          |            |---------------------------->|                   |            |
          |            |                             |                   |            |
          |            |     Unseal(duress) [h]      |                   |            |
          |            |---------------------------->|                   |            |
          |            |                             |                   |            |
          |            |        file [e] [h]         |                   |            |
          |            |<- - - - - - - - - - - - - - |                   |            |
          |            |                             |                   |            |
          |            |----.                        |                   |            |
          |            |    | verify HMAC, decrypt   |                   |            |
          |            |<---'                        |                   |            |
          |            |                             |                   |            |
          |            |  NV_Increment(trace) [h]    |                   |            |
          |            |---------------------------->|                   |            |
          |            |                             |                   |            |
          |            |  NV_Increment(count) [h]    |                   |            |
          |            |---------------------------->|                   |            |
          |            |                             |                   |            |
          |            |                             |----.              |            |
          |            |                             |    | seal dead    |            |
          |            |                             |<---'              |            |
          |            |                             |                   |            |
          |            |     NV_Read(count) [c]      |                   |            |
          |            |---------------------------->|                   |            |
          |            |                             |                   |            |
          |            |----.                        |                   |            |
          |            |    | preload file           |                   |            |
          |            |<---'                        |                   |            |
          |            |                             |                   |            |
          |            |               read last sectors                 |            |
          |            |------------------------------------------------>|            |
          |            |                             |                   |            |
          |            |                 GELI metadata                   |            |
          |            |<- - - - - - - - - - - - - - - - - - - - - - - - |            |
          |            |                             |                   |            |
          |            |----.                        |                   |            |
          |            |    | decoy opens            |                   |            |
          |            |<---'                        |                   |            |
          |            |                             |                   |            |
          |            |----.                        |                   |            |
          |            |    | others closed          |                   |            |
          |            |<---'                        |                   |            |
          |            |                             |                   |            |
          |            |----.                        |                   |            |
          |            |    | root = decoy           |                   |            |
          |            |<---'                        |                   |            |
          |            |                             |                   |            |
          |            |                        one user key             |            |
          |            |------------------------------------------------------------->|
          |            |                             |                   |            |
          |            |                             |                   |  attach    |
          |            |                             |                   |<-----------|
          |            |                             |                   |            |

O = whoever types the duress passphrase, L = loader, T = TPM, D =
disks, K = kernel. PIN = the index `duress.nv`, trace = `counter.nv`,
count = `duress.count.nv`; seal = the owner object. The tags are those
of the first diagram; `[h2]` is the HMAC of the second session, which
carries the PIN index's auth value. Every session here is salted the
same way, and the decoy's file crosses the bus encrypted.

Nothing before the TPM differs. The same prompt, the same
`readsecret()`, the same SHA256 of the line. The owner object is asked
first and refuses, because the line is not its authValue. Then:

    const struct tpm_policy_step decoy[] = {
            { .op = TPM_POLICY_SECRET, .index = pinindex,
              .auth = auth, .authlen = sizeof(auth) },
            { .op = TPM_POLICY_PCR, .mask = mask },
    };
    [...]
    if (duress != 0 && tpm_unseal(keyhandle, kdp, duress,
        decoy, TPM_KEYFILE_STEPS(decoy), NULL, 0, secret,
        sizeof(secret), &len)) {
            ok = true;
            duress_opened = true;
    }

### PolicySecret

The duress object has no authValue of its own. Its policy asks for
proof that the caller knows the authValue of another entity: the PIN
index, whose authValue is SHA256 of the duress passphrase.

`policy_secret()` gives that proof with a second session, of type
HMAC, salted to the same storage key the same way. The index's auth
value goes into that session's HMAC key; the command names the index
and the policy session:

    if (!session_start(k, keyhandle, TPM_SE_HMAC, &a))
            return (false);
    memcpy(a.auth, auth, authlen);
    a.authlen = authlen;
    put32(&b, index);               /* authHandle: the entity */
    put32(&b, session);             /* policySession */
    ok = put_auth_session(&b, &a, 0, TPM_CC_PolicySecret, names,
        sizeof(names), params, sizeof(params));

Again the value is proven and not sent. The index is of type
`TPM_NT_PIN_PASS`: the TPM itself raises its `pinCount` on every
successful authorization. That count is the first trace, kept where no
operating system writes.

Then `PolicyPCR`, as on the owner's way, and `Unseal` with an empty
auth value. The 32 bytes that come back are a different secret: the
key file of the decoy container.

### What the loader does before it goes on

    st.unsealed = true;
    if (duress_opened) {
            evidence_set_duress();
            if (nvindex != 0)
                    (void)tpm_nv_policy_increment(keyhandle, nvindex);
            for (tries = 0; tries < 5; tries++) {
                    (void)tpm_nv_policy_increment(keyhandle, cntindex);
                    if (tpm_nv_index_read(cntindex, &now) &&
                        now > st.count_sealed)
                            break;
                    delay(200000);
            }
            read_indices(cntindex);
            place(dp, secret, len);
    }

Three things happen in the TPM and one in memory.

- `evidence_set_duress()` marks the ledger. From here on
  `policy_run()` returns at once: no gate fires, nothing is published,
  nothing prompts.
- `counter.nv` is raised: the second trace.
- `duress.count.nv` is raised. The owner object is sealed against the
  old value with `PolicyNV`, and a counter does not go back, so from
  this command on the owner's passphrase unseals nothing. The
  increment is read back and repeated up to five times, because this
  is the step that must not fail silently.
- The file is placed for the decoy provider, `nda1p1:geli_keyfile0`.

Each increment runs under its own salted policy session with
`PolicyCommandCode(NV_Increment)`; the index authorizes itself.

### The disks

`geli_keys_prepare()` runs as before, with `keyfiles_only` true.

On `nda1p1` the first round succeeds: the provider was initialised
with the TPM's file alone (`geli init -b -P -K zempty.bin`), the set
`nda1p1` holds exactly that file, and the HMAC over it is the user key
of slot 0.

On `nda0p1` and `nda2p1` the sets hold only `zroot.key`: the
production TPM file was never released. The first round fails, PBKDF2
runs over the duress passphrase, the second round fails too. These
providers stay closed. The console shows the same derivation lines as
on the owner's way, because the work is the same.

One provider opened, so the dialog returns.

### The divert

    if (evidence()->duress) {
            record_cap();
            decoy_divert();
            return;
    }

    [...]
    setenv("vfs.root.mountfrom", note, 1);
    unsetenv("vfs.root.mountfrom.options");
    setenv("kern.geom.eli.boot_prompt", "0", 1);

The root becomes the fixed target from the trust configuration
(`loader.trust.tpm.decoy.root`). No boot record is written: the
record's key would be the decoy's, and no record of the production
chain verifies under it. `boot_prompt=0` is for the kernel, which
would otherwise stop at the production providers and ask:

    if (!g_eli_boot_prompt) {
            [...]
            g_eli_keyfiles_clear(pp->name);
            return (NULL);
    }

The kernel is the measured one from the card. It receives one user key
in the buffer, attaches `nda1p1`, and mounts `zempty`. What the decoy
does next is in [the decoy root](the-decoy-root.md).

### The next owner boot

The owner's line reaches `PolicyNV`, the counter no longer equals the
sealed value, and the TPM refuses. The diagnosis carries both numbers
(`duress.count=808/805`). The line still goes to the disks, without
the TPM's file, and opens nothing on slot 0. The way in is slot 1, the
recovery passphrase from paper, at the same prompt; then the reseal.

## The rescue way

The whole way in one picture (the source is
`how-the-disk-opens-rescue.puml`, rendered with `plantuml -ttxt`):

         ,-.                 ,-.                             ,-.                ,-.
         |O|                 |L|                             |C|                |K|
         `+'                 `+'                             `+'                `+'
          |rescue root? (y/N) |                               |                  |
          |<------------------|                               |                  |
          |                   |                               |                  |
          |        y          |                               |                  |
          |------------------>|                               |                  |
          |                   |                               |                  |
          |unlock passphrase  |                               |                  |
          |------------------>|                               |                  |
          |                   |                               |                  |
          |                   |----.                          |                  |
          |                   |    | PBKDF2 == compiled hash  |                  |
          |                   |<---'                          |                  |
          |                   |                               |                  |
          |                   |----.                          |                  |
          |                   |    | note root, key file      |                  |
          |                   |<---'                          |                  |
          |                   |                               |                  |
          |                   |     load rescue key file      |                  |
          |                   |------------------------------>|                  |
          |                   |                               |                  |
          |                   |     key file (preloaded)      |                  |
          |                   |<- - - - - - - - - - - - - - - |                  |
          |                   |                               |                  |
          |rescue passphrase  |                               |                  |
          |------------------>|                               |                  |
          |                   |                               |                  |
          |                   |      read last sectors        |                  |
          |                   |------------------------------>|                  |
          |                   |                               |                  |
          |                   |        GELI metadata          |                  |
          |                   |<- - - - - - - - - - - - - - - |                  |
          |                   |                               |                  |
          |                   |----.                          |                  |
          |                   |    | PBKDF2(passphrase)       |                  |
          |                   |<---'                          |                  |
          |                   |                               |                  |
          |                   |----.                          |                  |
          |                   |    | HMAC(key file, PBKDF2)   |                  |
          |                   |<---'                          |                  |
          |                   |                               |                  |
          |                   |----.                          |                  |
          |                   |    | master key verifies      |                  |
          |                   |<---'                          |                  |
          |                   |                               |                  |
          |                   |----.                          |                  |
          |                   |    | root = rescue, read-only |                  |
          |                   |<---'                          |                  |
          |                   |                               |                  |
          |                   |               user key, key file                 |
          |                   |------------------------------------------------->|
          |                   |                               |                  |
          |                   |                               |attach, read-only |
          |                   |                               |<-----------------|
          |                   |                               |                  |

O = owner, L = loader, C = the boot card, K = kernel. The TPM does not
appear: on this way it is not asked.

The rescue root lives on the boot card, in a GELI partition of its
own, and the way into it starts earlier, in the LOADER phase.

### The offer and the acknowledgement

`offer_act` asks one question with a timeout of three seconds:

    printf("%s: boot the rescue root %s? (y/N) [%d s] ",
        a->gate->name, note, OFFER_WAIT_S);

Anything but `y` leaves the boot as it was. On `y` the owner
acknowledges with the unlock passphrase. This is the one place where
the loader does compare, and the code says what it compares against:

    pkcs5v2_genkey_raw(key, sizeof(key), (const uint8_t *)salt,
        UNLOCK_SALT_LEN, (const uint8_t *)got, strlen(got),
        UNLOCK_ITERATIONS);
    [...]
    if (strlen(hash) == strlen(LOADER_TRUST_UNLOCK_SECRET) &&
        ct_equal(hash, LOADER_TRUST_UNLOCK_SECRET, strlen(hash))) {

A PBKDF2 hash with 100000 rounds, compiled into the loader. The unlock
passphrase opens no disk and releases nothing from the TPM; it
acknowledges a deviation. That is why its hash may be on the card.

Then the phase only takes notes:

    if (provider[0] != '\0' && file[0] != '\0') {
            snprintf(type, sizeof(type), "%s:geli_keyfile0", provider);
            evidence_set_rescue_keyfile(file, type);
    }
    evidence_set_rescue(note);

The target root, the provider and the key file's path come from the
signed trust configuration, not from the keyboard.

### The key file

A file cannot be preloaded before a kernel is. So the card's key file
is loaded at the start of the KERNEL phase:

    if (file_loadraw(e->rescue_keyfile, e->rescue_keytype, 1) == NULL) {
            [...]
            halt_boot("rescue key file");
    }

On the production way this file is never loaded, and `loader.conf`
names no key file for the card. The kernel of a production boot
therefore never tries the card and never asks for it.

### The dialog without the TPM

The same dialog runs, with two differences that are both in its loop:

    if (!evidence()->rescue)
            tpm_keyfile_prepare(pw);
    if (geli_keys_prepare(pw, evidence()->rescue ? false :
        tpm_keyfile_state()->unsealed) > 0) {

The TPM is not asked. No session is opened, no object is tried, no
counter moves; the owner's seal is after a rescue boot what it was
before. And the first round of the derivation is off.

In `geli_keys_prepare()` the rule about removable media turns around:

    if (!evidence()->rescue && keys_disk_removable(unit)) {
            keys_note("%sdisk%d:removable", [...]);
            continue;
    }

On the rescue way every disk is tasted, the card among them. On the
card's rescue partition the second round finds the set of the rescue
provider, one file, folds it with the PBKDF2 of the typed line, and
slot 0 opens: two factors, the card and the rescue passphrase.

### The divert

    setenv("vfs.root.mountfrom", note, 1);
    setenv("vfs.root.mountfrom.options", "ro", 1);
    setenv("vfs.zfs.rootpool_readonly", "1", 1);

The pool is imported read-only, so its labels do not move and the
witness of the card stays what the owner measured. Unlike the duress
way, this boot is recorded: `record_commit()` runs with the flag
RESCUE, and the next production boot shows that a rescue boot lay
between.

## The three ways side by side

| | Owner | Duress | Rescue |
|---|---|---|---|
| Typed | owner passphrase | duress passphrase | unlock passphrase, then rescue passphrase |
| Compared in the loader | nothing | nothing | the unlock hash |
| TPM asked | owner object | owner object, then duress object | no |
| TPM counters | unchanged | `pinCount`, `counter.nv`, `duress.count.nv` raised | unchanged |
| Key files in the user key | `zroot.key`, TPM file | the duress object's file | the card's rescue key file |
| Passphrase in the user key | yes (PBKDF2) | no | yes (PBKDF2) |
| Root | production | `zempty` | rescue, read-only |
| Boot record | written | none | written, flag RESCUE |

## What the walk does not cover

- **How the objects get into the TPM.** Sealing, the indices and the
  hierarchy passwords are provisioning: `elebake workflow show
  tpm-seal`, `duress-reseal`, `tpm-rotate`.
- **The time between the dialog and the kernel.** The user keys and
  the preloaded key files are in memory from the dialog until the
  kernel has taken them. A boot that halts wipes them; a machine that
  is taken apart while running is outside this walk.
- **The kernel side of GELI** beyond the lines quoted: it is stock
  FreeBSD except for `kern.geom.eli.boot_prompt`.
- **A TPM that lies.** The response HMAC binds the answer to the
  storage key the baseline names. A TPM whose storage key was
  extracted is outside the model.

## Where to look

- `geli_open.c`, `geli_keys.c`, `tpm_keyfile.c`, `tpm.c`, `policy.c`
  and `action.c` in `stand/efi/loader/local/` of the patch series;
  each header states what it assumes.
- `stand/libsa/geli/geliboot.c` for the key buffer,
  `sys/geom/eli/g_eli.c` and `g_eli_key.c` for the kernel's side.
- [The decoy root](the-decoy-root.md), [the rescue boot](the-rescue-boot.md)
  and [the question](the-question.md) for why the three ways exist.
- Tutorial, chapters 21 (three factors) and 24 (the duress factor).
