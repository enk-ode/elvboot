#!/bin/sh
#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Dr. Johannes Brügmann
# elebake stage - the staging object (named workspaces for a boot tree).
#
# stage/<name> -> ../.staging/<id> ; the hidden record .staging/<id>/ holds the
# boot tree (boot/), metadata, and AT MOST TWO fixed key slots:
#   sign-key   -> ../../pkcs11/<name>    (Authenticode / loader, UEFI SecureBoot db)
#   attest-key -> ../../openpgp/<name>   (detached GPG / manifest, libsecureboot)
#
# Design principle: THE TOOL IS DUMB. The user hands us a name/token; we assume
# they know what they mean. We check only: is the argument present, and does the
# object exist at the expected filesystem location — if yes, we use it. No
# clever re-verification. State is DERIVED from the artifacts (see stage status).
#
# ARCHITECTURE (sharp): TERMINALS (single _) emit ONLY shell, never an elebake
# re-invocation — errors use generate_error (error shell), NOT `elebake error`.
# COMBINATORS (___) emit ONLY elebake commands, never shell.

# STAGE_LAYOUT — the directory layout of a stage (relpath:mode), fed to the
# generic install_layout by _stage_add1. Everything a stage contains, at a
# glance; grows as staging does.
STAGE_LAYOUT="boot:0700
destdir:0700
backup:0700"

#-----------------------------------------------------------------------------
# _stage_add1 <name> — create a named stage (dumb: walk STAGE_LAYOUT)
#-----------------------------------------------------------------------------
#@help _stage_list0
# @command stage list
# @summary List all stages with their derived state (one line each)
# @group   stage
# @example elebake stage list
# @see     stage status
#@end
_stage_list0() {
  local base="$ELEBAKE_BASE" l name id d pop sig sk ak n=0
  printf '%s\n' "# stages (name  id  populated  signed  sign-key/attest-key)"
  for l in "$base"/stage/*; do
    [ -L "$l" ] || continue
    n=$((n+1))
    name=$(basename "$l"); id=$(basename "$(readlink "$l")"); d="$base/.staging/$id"
    if [ -f "$d/boot/loader.efi" ]; then pop=yes; else pop=no; fi
    if [ -f "$d/boot/loader.efi.signed" ] && [ "$d/boot/loader.efi.signed" -nt "$d/boot/loader.efi" ]; then sig=yes
    elif [ -f "$d/boot/loader.efi.signed" ]; then sig=STALE; else sig=no; fi
    { [ -L "$d/sign-key" ] && [ -e "$d/sign-key" ]; } && sk=$(basename "$(readlink "$d/sign-key")") || sk=-
    { [ -L "$d/attest-key" ] && [ -e "$d/attest-key" ]; } && ak=$(basename "$(readlink "$d/attest-key")") || ak=-
    printf '#   %-14s %-16s %-9s %-6s %s/%s\n' "$name" "$id" "$pop" "$sig" "$sk" "$ak"
  done
  [ "$n" -gt 0 ] || printf '#   (no stages -- stage add <name>)\n'
}

#@help _stage_add1
# @command stage add <stage>
# @summary Create a named stage (workspace for one boot tree); IDEMPOTENT -- an existing stage is left untouched
# @group   stage
#@end
_stage_add1() {
  local name="$1" base="$ELEBAKE_BASE"
  case "$name" in
    ""|*/*|.|..|*[!A-Za-z0-9_.-]*)
      generate_error "stage add: invalid stage name '$name'"
      return 0
      ;;
  esac
  # IDEMPOTENT: an existing stage stays as it is -- without this guard a
  # replayed dump would mint a fresh id and bend the stage/<name> symlink,
  # orphaning the old record.
  if [ -L "$base/stage/$name" ]; then
    printf '%s\n' "printf '# stage %s already exists (idempotent add)\\n' '$name' >&2"
    return 0
  fi
  local id="stage-$(od -An -tx1 -N6 /dev/urandom | tr -d ' \n')"
  local stamp; stamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>>"$LOG_FILE")
  install_layout "$base/.staging/$id" "$STAGE_LAYOUT"
  printf '%s\n' "echo 'name=$name' > '$base/.staging/$id/metadata'"
  printf '%s\n' "echo 'created=$stamp' >> '$base/.staging/$id/metadata'"
  printf '%s\n' "$MODIFY_FILE_PERMS 0600 '$base/.staging/$id/metadata'"
  # TODO(v1): populate .staging/<id>/boot/ from /boot here.
  printf '%s\n' "$MODIFY_LINK_FORCE '../.staging/$id' '$base/stage/$name'"
  printf '%s\n' "printf '# Created stage %s -> %s\\n' '$name' '$id' >&2"
}

#-----------------------------------------------------------------------------
# stage sign key <stage> <backend> <name> / stage attest key <stage> <backend> <name>
#-----------------------------------------------------------------------------
# Generic + explicit: the command names the SLOT, the args name the backend and
# key. Dumb: does <backend>/<name> exist? link it. A NEW backend works with no
# code change here.
#@help _stage_sign_key3
# @command stage sign key <stage> <backend> <key>
# @summary Bind the loader-signing key slot (backend: pem | pkcs11)
# @group   stage
# @example elebake stage sign key smoke1 pem db
#@end
_stage_sign_key3() {
  local name="$1" backend="$2" key="$3" base="$ELEBAKE_BASE"
  local stageid
  stageid=$(resolve_item stage "$name" strict) || {
    generate_error "stage sign key: unknown stage '$name'"; return 0; }
  [ -e "$base/$backend/$key" ] || {
    generate_error "stage sign key: unknown key '$backend/$key' (register it with '$backend add')"; return 0; }
  printf '%s\n' "$MODIFY_LINK_FORCE '../../$backend/$key' '$base/.staging/$stageid/sign-key'"
  printf '%s\n' "printf '# Bound %s key %s to stage %s (sign-key)\\n' '$backend' '$key' '$name' >&2"
}

#@help _stage_attest_key3
# @command stage attest key <stage> <backend> <key>
# @summary Bind the attest key slot (openpgp) -- required BEFORE build: its anchor is embedded
# @group   stage
# @example elebake stage attest key smoke1 openpgp manifest
#@end
_stage_attest_key3() {
  local name="$1" backend="$2" key="$3" base="$ELEBAKE_BASE"
  local stageid
  stageid=$(resolve_item stage "$name" strict) || {
    generate_error "stage attest key: unknown stage '$name'"; return 0; }
  [ -e "$base/$backend/$key" ] || {
    generate_error "stage attest key: unknown key '$backend/$key' (register it with '$backend add')"; return 0; }
  printf '%s\n' "$MODIFY_LINK_FORCE '../../$backend/$key' '$base/.staging/$stageid/attest-key'"
  printf '%s\n' "printf '# Bound %s key %s to stage %s (attest-key)\\n' '$backend' '$key' '$name' >&2"
}

#-----------------------------------------------------------------------------
# _stage_unkey1 <name> — clear both key slots
#-----------------------------------------------------------------------------
#@help _stage_unkey1
# @command stage unkey <stage>
# @summary Clear both key slots
# @group   stage
#@end
_stage_unkey1() {
  local name="$1" base="$ELEBAKE_BASE"
  local stageid
  stageid=$(resolve_item stage "$name" strict) || {
    generate_error "stage unkey: unknown stage '$name'"; return 0; }
  printf '%s\n' "$MODIFY_FILE_REMOVE '$base/.staging/$stageid/sign-key' '$base/.staging/$stageid/attest-key'"
  printf '%s\n' "printf '# Cleared key slots of stage %s\\n' '$name' >&2"
}

#-----------------------------------------------------------------------------
# _stage_prerequisites1 <stage> — stage-specific build readiness (derived gate)
#-----------------------------------------------------------------------------
# Both keys must be bound BEFORE build — the attest-key's cert is embedded into
# the loader at build time; the sign-key signs the built loader afterwards.
#@help _stage_prerequisites1
# @internal build-readiness gate (both key slots bound); part of 'stage build'
#@end
_stage_prerequisites1() {
  local name="$1" base="$ELEBAKE_BASE"
  local stageid
  stageid=$(resolve_item stage "$name" strict) || {
    generate_error "stage prerequisites: unknown stage '$name'"; return 0; }
  local d="$base/.staging/$stageid"
  [ -e "$d/sign-key" ] || {
    generate_error "stage prerequisites '$name': no sign-key bound (stage sign key $name <backend> <key>)"; return 0; }
  [ -e "$d/attest-key" ] || {
    generate_error "stage prerequisites '$name': no attest-key bound — its cert is embedded in the loader at build (stage attest key $name <backend> <key>)"; return 0; }
  # TODO(build): once checkout/patch/clean land, also require the worktree, a
  # 'patched' marker, and a clean build dir here.
  printf '%s\n' "printf '# prerequisites ok: stage %s (keys bound)\\n' '$name' >&2"
}

#-----------------------------------------------------------------------------
# _stage_status1 <name> — DERIVED state (display; inspect-by-default)
#-----------------------------------------------------------------------------
#@help ___stage_status1
# @command stage status <stage>
# @summary Show the stage's derived state (nothing cached -- read from the artifacts)
# @group   stage
#@end
___stage_status1() {
  # One dispatchable line per aspect -- each independently runnable
  # (`stage status smoke1 signed`); the aspect list is a generation-time
  # constant (complete enumeration, not policy -- deliberately not an env var).
  local name="$1" sec
  stageid_probe=$(resolve_item stage "$name" strict) || {
    printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage status: unknown stage $name'"; return 0; }
  printf '%s\n' "# stage $name ($stageid_probe)"
  for sec in populated sign-key attest-key signed filter media marker sitemk; do
    printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage status '$name' '$sec'"
  done
}

#@help _stage_status2
# @internal one derived-state aspect of 'stage status' (arity sibling); aspect in
# populated | sign-key | attest-key | signed | filter | media | marker | site mk
#@end
_stage_status2() {
  local name="$1" sec="$2" base="$ELEBAKE_BASE"
  local stageid
  stageid=$(resolve_item stage "$name" strict) || {
    generate_error "stage status: unknown stage '$name'"; return 0; }
  local d="$base/.staging/$stageid"
  case "$sec" in
    populated)
      if [ -f "$d/boot/loader.efi" ]; then printf '#   populated : yes\n'
      else printf '#   populated : no (boot/loader.efi missing)\n'; fi ;;
    sign-key)
      if [ -L "$d/sign-key" ] && [ -e "$d/sign-key" ]; then printf '#   sign-key  : %s\n' "$(basename "$(readlink "$d/sign-key")")"
      elif [ -L "$d/sign-key" ]; then printf '#   sign-key  : STALE\n'
      else printf '#   sign-key  : none\n'; fi ;;
    attest-key)
      if [ -L "$d/attest-key" ] && [ -e "$d/attest-key" ]; then printf '#   attest-key: %s\n' "$(basename "$(readlink "$d/attest-key")")"
      elif [ -L "$d/attest-key" ]; then printf '#   attest-key: STALE\n'
      else printf '#   attest-key: none\n'; fi ;;
    signed)
      if [ -f "$d/boot/loader.efi.signed" ] && [ "$d/boot/loader.efi.signed" -nt "$d/boot/loader.efi" ]; then printf '#   signed    : yes (current)\n'
      elif [ -f "$d/boot/loader.efi.signed" ]; then printf '#   signed    : STALE (loader changed after signing)\n'
      else printf '#   signed    : no\n'; fi ;;
    filter)
      if [ -s "$d/filter" ]; then printf '#   filter    : %s entries\n' "$(grep -c . "$d/filter")"
      else printf '#   filter    : none (stage filter add <stage> <rel>)\n'; fi ;;
    media)
      if [ -d "$d/media" ] && [ -n "$(ls "$d/media" 2>>"$LOG_FILE")" ]; then
        local m mm
        for m in "$d/media"/*; do
          mm=$(basename "$m")
          printf '#   medium %-3s: %s on %s (backups: %s)\n' "$mm" "$(head -n1 "$m/node")" "$(head -n1 "$m/mountpoint")" "$(ls "$d/backup/$mm" 2>>"$LOG_FILE" | wc -l | tr -d ' ')"
        done
      else printf '#   media     : none (stage device <stage> <medium> /dev/<node>)\n'; fi ;;
    marker)
      if [ -f "$d/marker/bootvar" ]; then printf '#   marker    : %s (%s)\n' "$(head -n1 "$d/marker/bootvar")" "$(head -n1 "$d/marker/file")"
      else printf '#   marker    : none (stage marker <stage> BootXXXX <file>)\n'; fi ;;
    sitemk)
      if [ -f "$d/work/stand/efi/loader/local/site.mk" ]; then printf '#   site.mk   : present (worktree)\n'
      else printf '#   site.mk   : none (stage site mk)\n'; fi ;;
    *)
      generate_error "stage status '$name': unknown aspect '$sec' (populated|sign-key|attest-key|signed|filter|media|marker|sitemk)"; return 0 ;;
  esac
}

#-----------------------------------------------------------------------------
# _stage_authenticode1 <name> — emit the loader-signing command (dumb terminal)
#-----------------------------------------------------------------------------
# Inspect-by-default (cat). Dumb: sign-key slot present? use it. The slot's
# record decides the mechanism (state derived, no extra config):
#   uri + cert  -> pkcs11 token, osslsigncode (bridge-aware)
#   key + cert  -> file-based PEM, uefisign (FreeBSD-native)
#@help _stage_authenticode1
# @internal signing terminal behind 'stage sign'; mechanism derived from the bound slot
#@end
_stage_authenticode1() {
  local name="$1" base="$ELEBAKE_BASE"
  local stageid
  stageid=$(resolve_item stage "$name" strict) || {
    generate_error "stage sign: unknown stage '$name'"; return 0; }
  local d="$base/.staging/$stageid" slot="$base/.staging/$stageid/sign-key"
  [ -e "$slot" ] || {
    generate_error "stage sign '$name': no sign-key bound (stage sign key $name <backend> <key>)"; return 0; }
  [ -f "$d/boot/loader.efi" ] || {
    generate_error "stage sign '$name': boot/loader.efi not present (stage not populated)"; return 0; }
  local cert loader
  loader="$d/boot/loader.efi"

  if [ -f "$slot/uri" ]; then
    # pkcs11 record: uri + cert, else fail loudly. No implicit defaults.
    [ -f "$slot/cert" ] || {
      generate_error "stage sign '$name': pkcs11 sign-key record incomplete (cert missing)"; return 0; }
    local uri mod bridge
    uri=$(head -n1 "$slot/uri"); cert=$(head -n1 "$slot/cert")
    mod="$ELEBAKE_PKCS11_MODULE"; bridge="$ELEBAKE_PKCS11_BRIDGE"

    emit_note "elebake stage sign '$name' (Authenticode via pkcs11 token)"
    if [ "$bridge" != engine ]; then
      emit_note "bridge=provider: assumes pkcs11-provider is configured in openssl.cnf;"
      emit_note "verify the exact osslsigncode flags against the installed version on .79"
    fi
    # PIN: prompted hidden on the controlling tty, handed to osslsigncode
    # via a transient -readpass file (never argv, never env), removed
    # immediately. Trailing newline on purpose (readpass reads a line).
    printf '%s\n' "printf 'Token PIN (hidden): ' > /dev/tty"
    printf '%s\n' "stty -echo < /dev/tty; IFS= read -r pin < /dev/tty; stty echo < /dev/tty; printf '\\n' > /dev/tty"
    printf '%s\n' "pf=\$(mktemp) && chmod 600 \"\$pf\" && printf '%s\\n' \"\$pin\" > \"\$pf\" && unset pin || exit 1"
    if [ "$bridge" = engine ]; then
      printf '%s\n' "osslsigncode sign \\"
      printf '%s\n' "  -pkcs11engine '$ELEBAKE_PKCS11_ENGINE' \\"
    else
      # base OpenSSL only searches /usr/lib/ossl-modules; point it at the
      # port's directory. Caveat: this HIDES the base legacy provider.
      printf '%s\n' "OPENSSL_MODULES='$(dirname "${ELEBAKE_PKCS11_PROVIDER:-/usr/local/lib/ossl-modules/x}")' osslsigncode sign \\"
    fi
    printf '%s\n' "  -pkcs11module '$mod' \\"
    printf '%s\n' "  -key '$uri' \\"
    printf '%s\n' "  -certs '$cert' \\"
    printf '%s\n' "  -in '$loader' \\"
    printf '%s\n' "  -readpass \"\$pf\" \\"
    printf '%s\n' "  -out '$loader.signed'"
    printf '%s\n' "rc=\$?; rm -f \"\$pf\""
    printf '%s\n' "[ \"\$rc\" -eq 0 ] || { rm -f '$loader.signed'; printf '# Error: osslsigncode failed (PIN? token?)\\n' >&2; exit 1; }"
  elif [ -f "$slot/key" ]; then
    # pem record: key + cert paths, else fail loudly.
    [ -f "$slot/cert" ] || {
      generate_error "stage sign '$name': pem sign-key record incomplete (cert missing)"; return 0; }
    local key
    key=$(head -n1 "$slot/key"); cert=$(head -n1 "$slot/cert")

    emit_note "elebake stage sign '$name' (Authenticode via file-based key, uefisign)"
    printf '%s\n' "uefisign -c '$cert' -k '$key' -o '$loader.signed' '$loader' || { rm -f '$loader.signed'; printf '# Error: uefisign failed (input already signed? key unreadable?)\\n' >&2; exit 1; }"
    printf '%s\n' "printf '# signed: %s -> %s.signed\\n' '$(basename "$loader")' '$(basename "$loader")' >&2"
  else
    generate_error "stage sign '$name': sign-key record unrecognized (neither uri nor key present)"
  fi
}

#-----------------------------------------------------------------------------
# _stage_detachsign1 <name> — emit the manifest-attest command (dumb terminal)
#-----------------------------------------------------------------------------
#@help _stage_detachsign1
# @internal attest terminal behind 'stage attest' (armored detached signature
# boot/manifest.asc, exactly what the loader verifies against the anchor)
#@end
_stage_detachsign1() {
  local name="$1" base="$ELEBAKE_BASE"
  local stageid
  stageid=$(resolve_item stage "$name" strict) || {
    generate_error "stage attest: unknown stage '$name'"; return 0; }
  local d="$base/.staging/$stageid" slot="$base/.staging/$stageid/attest-key"
  [ -e "$slot" ] || {
    generate_error "stage attest '$name': no attest-key bound (stage attest key $name openpgp <key>)"; return 0; }
  [ -f "$slot/keyid" ] || {
    generate_error "stage attest '$name': attest-key record incomplete (keyid missing)"; return 0; }
  [ -f "$d/boot/manifest" ] || {
    generate_error "stage attest '$name': no boot/manifest (stage manifest first)"; return 0; }
  local keyid gpgenv=""
  keyid=$(head -n1 "$slot/keyid")
  [ -f "$slot/gnupghome" ] && gpgenv="GNUPGHOME='$(head -n1 "$slot/gnupghome")' "
  emit_note "elebake stage attest '$name' (armored detached signature -> boot/manifest.asc)"
  # Card signature needs a pinentry: the isolated environment carries no
  # GPG_TTY and the interpreter's stdin is a pipe — the EMISSION determines
  # its terminal itself and points the agent at it (same cure as trust
  # anchor). rm -f first: a failed earlier run must not leave a stale or
  # foreign-owned manifest.asc behind. No false green: failure stops here.
  printf '%s\n' "rm -f '$d/boot/manifest.asc'"
  printf '%s\n' "GPG_TTY=\$(tty </dev/tty 2>/dev/null); export GPG_TTY; ${gpgenv}gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1 || true"
  printf '%s\n' "${gpgenv}gpg --yes --openpgp -a --detach-sign --local-user '$keyid' -o '$d/boot/manifest.asc' '$d/boot/manifest' || { rm -f '$d/boot/manifest.asc'; printf '# Error: manifest attestation failed for %s\\n' '$keyid' >&2; exit 1; }"
  printf '%s\n' "printf '# manifest attested for stage %s\\n' '$name' >&2"
}

#-----------------------------------------------------------------------------
# ___stage_sign1 <name> / ___stage_attest1 <name> — BatchCombinators
#-----------------------------------------------------------------------------
# Prepend the backend's own prerequisites check, then the real signing terminal.
# The backend is DERIVED from the bound sign-key slot (symlink into <backend>/),
# so pkcs11 and pem stages get their matching toolchain check automatically.
#@help ___stage_sign1
# @command stage sign <stage>
# @summary Authenticode-sign boot/loader.efi with the bound sign-key (pem: uefisign, pkcs11: osslsigncode)
# @group   stage
# @example elebake stage sign smoke1 | sudo sh
# @see     stage sign key
#@end
___stage_sign1() {
  local name="$1" base="$ELEBAKE_BASE"
  local stageid backend
  stageid=$(resolve_item stage "$name" strict) || {
    printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage sign: unknown stage $name'"; return 0; }
  local slot="$base/.staging/$stageid/sign-key"
  [ -L "$slot" ] || {
    printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage sign $name: no sign-key bound (stage sign key $name <backend> <key>)'"; return 0; }
  backend=$(basename "$(dirname "$(readlink "$slot")")")
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" $backend prerequisites"
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage authenticode '$name'"
}

#@help ___stage_attest1
# @command stage attest <stage>
# @summary Detach-sign the stage manifest with the bound attest key
# @group   stage
# @see     stage manifest
#@end
___stage_attest1() {
  local name="$1"
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" openpgp prerequisites"
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage detachsign '$name'"
}

#-----------------------------------------------------------------------------
# checkout: git worktree of ELEBAKE_FREEBSD_SRC at <ref>, external + symlinked
#-----------------------------------------------------------------------------
# The build tree does NOT live in the DB: the worktree sits at
# $ELEBAKE_ROOT/worktree/<id> (shares the repo's .git objects), and the stage
# points at it via a `work` symlink. Build-pipeline terminals are inspect-by-
# default (cat) — review the git/make commands, then run with sh.

# _stage_worktree2 <stage> <ref> — add the worktree + `work` symlink + record ref
#@help _stage_worktree2
# @internal worktree terminal behind 'stage checkout'
#@end
_stage_worktree2() {
  local name="$1" ref="$2" base="$ELEBAKE_BASE" src="${ELEBAKE_FREEBSD_SRC:-}"
  local stageid
  stageid=$(resolve_item stage "$name" strict) || {
    generate_error "stage checkout: unknown stage '$name'"; return 0; }
  [ -n "$src" ] || {
    generate_error "stage checkout: ELEBAKE_FREEBSD_SRC not set"; return 0; }
  local wt="$ELEBAKE_ROOT/worktree/$stageid"
  printf '%s\n' "$MODIFY_DIR_CREATE '$ELEBAKE_ROOT/worktree'"
  printf '%s\n' "git -C '$src' worktree add '$wt' '$ref'"
  printf '%s\n' "$MODIFY_LINK_FORCE '$wt' '$base/.staging/$stageid/work'"
  printf '%s\n' "echo '$ref' > '$base/.staging/$stageid/checkout'"
  printf '%s\n' "$MODIFY_FILE_PERMS 0600 '$base/.staging/$stageid/checkout'"
  printf '%s\n' "printf '# Checked out %s at %s (worktree %s)\\n' '$name' '$ref' '$wt' >&2"
}

# ___stage_checkout2 <stage> <ref> — freebsd prerequisites, then the worktree
#@help ___stage_checkout2
# @command stage checkout <stage> <ref>
# @summary Add a git worktree of ELEBAKE_FREEBSD_SRC at <ref> and point the stage at it
# @group   stage
# @example elebake stage checkout smoke1 platform-trust-gates-15.1 | sh
#@end
___stage_checkout2() {
  local name="$1" ref="$2"
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" freebsd prerequisites"
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage worktree '$name' '$ref'"
}

#-----------------------------------------------------------------------------
# clean: clean dir the worktree build + reset the stage's local build outputs
#-----------------------------------------------------------------------------
# _stage_clean_dir1 <stage> — `make clean dir` in the worktree (isolated obj)
#@help _stage_clean_dir1
# @internal clean dir terminal (isolated obj); part of 'stage clean'
#@end
_stage_clean_dir1() {
  local name="$1" base="$ELEBAKE_BASE"
  local stageid
  stageid=$(resolve_item stage "$name" strict) || {
    generate_error "stage clean dir: unknown stage '$name'"; return 0; }
  local obj="$base/.staging/$stageid/obj"
  # stand/ only -- a top-level cleandir recurses the ENTIRE src tree (libc
  # tests included), takes minutes and probes objdirs it may not create
  # ("warning: /lib: Permission denied"). The build scope is stand/, so is
  # the clean scope. NOTE the make target is ONE word, cleandir -- the
  # command word 'stage clean dir' is elebake vocabulary, the target is
  # make's (a rename-wave once split it and the batch died on the
  # unknown target 'dir').
  printf '%s\n' "$MODIFY_DIR_CREATE '$obj'"
  printf '%s\n' "MAKEOBJDIRPREFIX='$obj' make -C '$base/.staging/$stageid/work/stand' cleandir"
}

# _stage_reset1 <stage> — empty the local build outputs (keep keys/metadata/work)
#@help _stage_reset1
# @internal reset terminal (clear destdir/, boot/); part of 'stage clean'
#@end
_stage_reset1() {
  local name="$1" base="$ELEBAKE_BASE"
  local stageid
  stageid=$(resolve_item stage "$name" strict) || {
    generate_error "stage reset: unknown stage '$name'"; return 0; }
  local d="$base/.staging/$stageid"
  # destdir/ ONLY: boot/ is the curated truth (adopted config + included
  # artifacts) and must survive every rebuild.
  printf '%s\n' "$MODIFY_FILE_REMOVE -r '$d/destdir/'*"
  printf '%s\n' "printf '# Reset build outputs of stage %s (destdir/)\\n' '$name' >&2"
}

# ___stage_clean1 <stage> — clean dir + reset
#@help ___stage_clean1
# @command stage clean <stage>
# @summary clean dir the worktree build and reset the stage's build outputs
# @group   stage
#@end
___stage_clean1() {
  local name="$1"
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage clean dir '$name'"
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage reset '$name'"
}

#=============================================================================
# build pipeline (terminals emit shell; the make/manifest/deploy specifics are
# BEST-GUESS skeletons — marked "refine on .79" — for JB to correct against his
# libsecureboot build practice). Inspect-by-default: review, then run with sh.
#=============================================================================

# ___stage_build_stand1 <stage> — build stand/ (loader + boot components) in
# SUBDIR_DEPEND order (secboot.sh build_stand, SSoT). The component list is a
# generation-time constant: the loop unrolls HERE into one dispatchable
# command per component; stop-at-first-failure is the batch machinery's job
# (ELEBAKE_BATCH_KEEP_GOING=0), never emitted rc-plumbing. Cleaning is the
# separate 'stage clean' step (already ahead of us in the 'stage build'
# chain); build logging is the interpreter's business (e.g. pin `sh | tee`).
# Arity siblings: this batch (broad, 1 arg) delegates to the terminal
# _stage_build_stand2 (narrow, 2 args).
#@help ___stage_build_stand1
# @internal batch behind 'stage build': one 'stage build stand <stage> <component>' per stand/ component
#@end
___stage_build_stand1() {
  local name="$1" sd
  # Curated policy from the environment (SUBDIR_DEPEND order; see the
  # template). No implicit default: an unconfigured DB emits an error
  # command -- the interpreter deals with it.
  [ -n "${ELEBAKE_STAND_BUILD_SUBDIRS:-}" ] || {
    printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage build stand: ELEBAKE_STAND_BUILD_SUBDIRS not set (environment init <profile>)'"
    return 0; }
  for sd in $ELEBAKE_STAND_BUILD_SUBDIRS; do
    printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage build stand '$name' '$sd'"
  done
}

#@help _stage_build_stand2
# @internal build ONE stand/ component (validated against the checked-out worktree; isolated obj)
#@end
_stage_build_stand2() {
  local name="$1" sd="$2" base="$ELEBAKE_BASE"
  local stageid
  stageid=$(resolve_item stage "$name" strict) || {
    generate_error "stage build stand: unknown stage '$name'"; return 0; }
  local work="$base/.staging/$stageid/work" obj="$base/.staging/$stageid/obj"
  [ -L "$work" ] || {
    generate_error "stage build stand '$name': not checked out (stage checkout $name <ref>)"; return 0; }
  [ -d "$work/stand/$sd" ] || {
    generate_error "stage build stand '$name': no such stand/ component: $sd"; return 0; }
  # Isolated per-stage object tree — never the shared /usr/obj.
  printf '%s\n' "$MODIFY_DIR_CREATE '$obj'"
  printf '%s\n' "MAKEOBJDIRPREFIX='$obj' make -C '$work/stand/$sd'"
}

# ___stage_build1 <stage> — env + stage prereqs, clean, then compile
#@help ___stage_make1
# @command stage make <stage>
# @summary BUILD the stage: prereqs, clean, build stand, install, include, sign -- publishing is stage push
# @group   stage
# @param   needs executing interpreter pins on the terminals underneath,
# @param   otherwise every step only displays -- see the environment topic
# @example elebake stage make smoke1
# @see     stage build
#@end
___stage_make1() {
  local name="$1"
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage build '$name'"
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage install '$name'"
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage include '$name'"
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage sign '$name'"
}

#@help ___stage_build1
# @command stage build <stage>
# @summary prerequisites + clean + build stand: the isolated stand/ build
# @group   stage
# @env     ELEBAKE_STAND_BUILD_SUBDIRS  curated components in SUBDIR_DEPEND order (see the template)
# @example elebake stage build smoke1 | sh
#@end
___stage_build1() {
  local name="$1"
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" freebsd prerequisites"
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage prerequisites '$name'"
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage clean '$name'"
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage build stand '$name'"
}

# ___stage_install1 <stage> — DESTDIR-install the boot bits into destdir/,
# one component per dispatched command (same declarative shape as build stand:
# the deliverable list is a generation-time constant, unrolled HERE; the batch
# machinery owns stop-at-first-failure). Only the deliverable subdirs — a
# plain `make -C stand install` recurses into subdirs the build never made
# (libsa32 & friends). The kernel is a separate, future slice — this covers
# the LOADER path only. Arity siblings: batch (1 arg) -> terminal (2 args).
#@help ___stage_install1
# @command stage install <stage>
# @summary Unprivileged stand/ DESTDIR install into destdir/, per component (from the stage's obj tree)
# @group   stage
# @env     ELEBAKE_STAND_INSTALL_SUBDIRS  curated components that land in destdir/ (see the template)
#@end
___stage_install1() {
  local name="$1" sd
  # Curated policy from the environment (see the template). No implicit
  # default: an unconfigured DB emits an error command.
  [ -n "${ELEBAKE_STAND_INSTALL_SUBDIRS:-}" ] || {
    printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage install: ELEBAKE_STAND_INSTALL_SUBDIRS not set (environment init <profile>)'"
    return 0; }
  for sd in $ELEBAKE_STAND_INSTALL_SUBDIRS; do
    printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage install '$name' '$sd'"
  done
}

#@help _stage_install2
# @internal DESTDIR-install ONE stand/ component into destdir/ (validated; self-contained)
#@end
_stage_install2() {
  local name="$1" sd="$2" base="$ELEBAKE_BASE"
  local stageid
  stageid=$(resolve_item stage "$name" strict) || {
    generate_error "stage install: unknown stage '$name'"; return 0; }
  local d="$base/.staging/$stageid" work="$base/.staging/$stageid/work" obj="$base/.staging/$stageid/obj"
  [ -L "$work" ] || {
    generate_error "stage install '$name': not checked out"; return 0; }
  [ -d "$obj" ] || {
    generate_error "stage install '$name': no obj tree (stage build $name first)"; return 0; }
  [ -d "$work/stand/$sd" ] || {
    generate_error "stage install '$name': no such stand/ component: $sd"; return 0; }
  # INSTALL='install -U' = unprivileged (no chown; media get real ownership
  # at deploy time). Man pages and debug files are not boot content.
  # install(1) does not create directories — pre-create the /boot skeleton
  # (idempotent, emitted per component so each line runs self-contained).
  printf '%s\n' "$MODIFY_DIR_CREATE '$d/destdir/boot/defaults' '$d/destdir/boot/fonts' '$d/destdir/boot/images' '$d/destdir/boot/lua'"
  printf '%s\n' "MAKEOBJDIRPREFIX='$obj' make -C '$work/stand/$sd' install INSTALL=\"install -U\" -DWITHOUT_MAN -DWITHOUT_DEBUG_FILES DESTDIR='$d/destdir'"
}

# per-stage prerequisites lists — the DECISIONS behind the loader's
# prerequisites_exist / prerequisites_verify arrays (emitted into the
# generated foundation.c when the checkout expects extern arrays; see
# render_foundation_c). Stored one absolute bootfs path per line under
# .staging/<id>/prereqs/{exist,verify}; `add -` reads paths from stdin
# at GENERATION time (arsenal templates arrive by pipe — stage A).

# prereq_kind_ok <kind> — exist | verify
prereq_kind_ok() { [ "$1" = "exist" ] || [ "$1" = "verify" ]; }

# prereq_path_ok <path> — absolute, no .., no quotes
prereq_path_ok() {
  case "$1" in
    /*) ;;
    *) return 1 ;;
  esac
  case "$1" in
    *..*|*"'"*) return 1 ;;
  esac
  return 0
}

# stage_prereqs_add_emit <stage> <kind> <path> — one idempotent append
stage_prereqs_add_emit() {
  local stageid f
  stageid=$(resolve_item stage "$1" strict) || return 1
  f="$ELEBAKE_BASE/.staging/$stageid/prereqs/$2"
  printf '%s\n' "$MODIFY_DIR_CREATE '$ELEBAKE_BASE/.staging/$stageid/prereqs'"
  printf '%s\n' "grep -qxF '$3' '$f' 2>/dev/null || echo '$3' >> '$f'"
  printf '%s\n' "$MODIFY_FILE_PERMS 0600 '$f'"
  printf '%s\n' "printf '# prerequisites %s of %s: + %s\\n' '$2' '$1' '$3' >&2"
}

# _stage_prerequisites_x2 <kind> <stage> <path|-> — shared add worker
stage_prereqs_add_worker() {
  local kind="$1" name="$2" path="$3" line
  prereq_kind_ok "$kind" || {
    generate_error "stage prerequisites: unknown list '$kind' (exist|verify)"; return 0; }
  resolve_item stage "$name" strict >/dev/null || {
    generate_error "stage prerequisites $kind add: unknown stage '$name'"; return 0; }
  if [ "$path" = "-" ]; then
    # caller stdin at generation time (fd 3 — see elebake.sh): one path
    # per line, validated per line, each emitted as its own idempotent
    # append (replay-safe)
    while IFS= read -r line <&3; do
      [ -n "$line" ] || continue
      prereq_path_ok "$line" || {
        generate_error "stage prerequisites $kind add: invalid path '$line' (absolute bootfs path, no .., no quotes)"; return 0; }
      stage_prereqs_add_emit "$name" "$kind" "$line"
    done
    return 0
  fi
  prereq_path_ok "$path" || {
    generate_error "stage prerequisites $kind add: invalid path '$path' (absolute bootfs path, no .., no quotes)"; return 0; }
  stage_prereqs_add_emit "$name" "$kind" "$path"
}

#@help _stage_prerequisites_exist_add2
# @command stage prerequisites exist add <stage> <path|->
# @summary Add one absolute bootfs path to the stage's EXIST prerequisites (the loader claims its presence); '-' reads paths from stdin, one per line
# @group   stage
# @example elebake stage prerequisites exist add smoke1 /boot/lua/loader.lua
# @see     stage prerequisites verify add
#@end
_stage_prerequisites_exist_add2() {
  stage_prereqs_add_worker exist "$1" "$2"
}

#@help _stage_prerequisites_verify_add2
# @command stage prerequisites verify add <stage> <path|->
# @summary Add one absolute bootfs path to the stage's VERIFY prerequisites (verified read against the manifest — presence AND integrity); '-' reads from stdin
# @group   stage
# @example elebake stage prerequisites verify add smoke1 /boot/loader.efi.signed
# @see     stage prerequisites exist add
#@end
_stage_prerequisites_verify_add2() {
  stage_prereqs_add_worker verify "$1" "$2"
}

# shared drop worker
stage_prereqs_drop_worker() {
  local kind="$1" name="$2" path="$3" stageid f
  prereq_kind_ok "$kind" || {
    generate_error "stage prerequisites: unknown list '$kind' (exist|verify)"; return 0; }
  stageid=$(resolve_item stage "$name" strict) || {
    generate_error "stage prerequisites $kind drop: unknown stage '$name'"; return 0; }
  f="$ELEBAKE_BASE/.staging/$stageid/prereqs/$kind"
  grep -qxF "$path" "$f" 2>/dev/null || {
    generate_error "stage prerequisites $kind drop: not listed: $path"; return 0; }
  printf '%s\n' "grep -vxF '$path' '$f' > '$f.new'; mv '$f.new' '$f'"
  emit_note "prerequisites $kind of $name: - $path"
}

#@help _stage_prerequisites_exist_drop2
# @command stage prerequisites exist drop <stage> <path>
# @summary Remove one path from the stage's EXIST prerequisites
# @group   stage
#@end
_stage_prerequisites_exist_drop2() {
  stage_prereqs_drop_worker exist "$1" "$2"
}

#@help _stage_prerequisites_verify_drop2
# @command stage prerequisites verify drop <stage> <path>
# @summary Remove one path from the stage's VERIFY prerequisites
# @group   stage
#@end
_stage_prerequisites_verify_drop2() {
  stage_prereqs_drop_worker verify "$1" "$2"
}

# shared show worker (display)
stage_prereqs_show_worker() {
  local kind="$1" name="$2" stageid f
  stageid=$(resolve_item stage "$name" strict) || {
    generate_error "stage prerequisites $kind show: unknown stage '$name'"; return 0; }
  f="$ELEBAKE_BASE/.staging/$stageid/prereqs/$kind"
  printf '# prerequisites %s of %s\n' "$kind" "$name"
  if [ -s "$f" ]; then
    sed 's/^/#   /' "$f"
  else
    printf '#   (empty — stage prerequisites %s add %s <path|->)\n' "$kind" "$name"
  fi
}

#@help _stage_prerequisites_exist_show1
# @command stage prerequisites exist show <stage>
# @summary Show the stage's EXIST prerequisites list
# @group   stage
#@end
_stage_prerequisites_exist_show1() {
  stage_prereqs_show_worker exist "$1"
}

#@help _stage_prerequisites_verify_show1
# @command stage prerequisites verify show <stage>
# @summary Show the stage's VERIFY prerequisites list
# @group   stage
#@end
_stage_prerequisites_verify_show1() {
  stage_prereqs_show_worker verify "$1"
}

# `prereqs` — the SHORT form, one alias combinator per verb (exactly ONE
# re-invocation: one truth, spelled twice). NOTE: the stdin form `add -`
# needs the LONG spelling — a combinator's child does not inherit the
# caller's stdin.
#@help __stage_prereqs_exist_add2
# @internal alias combinator: stage prereqs exist add -> stage prerequisites exist add
#@end
__stage_prereqs_exist_add2() {
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage prerequisites exist add '$1' '$2'"
}
#@help __stage_prereqs_verify_add2
# @internal alias combinator for the verify list
#@end
__stage_prereqs_verify_add2() {
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage prerequisites verify add '$1' '$2'"
}
#@help __stage_prereqs_exist_drop2
# @internal alias combinator
#@end
__stage_prereqs_exist_drop2() {
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage prerequisites exist drop '$1' '$2'"
}
#@help __stage_prereqs_verify_drop2
# @internal alias combinator
#@end
__stage_prereqs_verify_drop2() {
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage prerequisites verify drop '$1' '$2'"
}
#@help __stage_prereqs_exist_show1
# @internal alias combinator
#@end
__stage_prereqs_exist_show1() {
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage prerequisites exist show '$1'"
}
#@help __stage_prereqs_verify_show1
# @internal alias combinator
#@end
__stage_prereqs_verify_show1() {
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage prerequisites verify show '$1'"
}

#@help _stage_build_kernel1
# @command stage build kernel <stage>
# @summary Build the kernel from the stage's checkout (KERNCONF from ELEBAKE_KERNCONF, no implicit default; isolated per-stage obj) — the source delivers EVERYTHING, the filter selects
# @group   stage
# @env     ELEBAKE_KERNCONF  the kernel configuration to build (e.g. GENERIC); the guarding kernel is a decision
# @example elebake stage build kernel smoke1
# @see     stage install kernel
#@end
_stage_build_kernel1() {
  local name="$1" base="$ELEBAKE_BASE" kc="${ELEBAKE_KERNCONF:-}"
  local stageid
  stageid=$(resolve_item stage "$name" strict) || {
    generate_error "stage build kernel: unknown stage '$name'"; return 0; }
  local work="$base/.staging/$stageid/work" obj="$base/.staging/$stageid/obj"
  [ -L "$work" ] || {
    generate_error "stage build kernel '$name': not checked out (stage checkout $name <ref>)"; return 0; }
  [ -n "$kc" ] || {
    generate_error "stage build kernel: ELEBAKE_KERNCONF not set (elebake setenv ELEBAKE_KERNCONF GENERIC)"; return 0; }
  [ -f "$work/sys/amd64/conf/$kc" ] || {
    generate_error "stage build kernel '$name': no such KERNCONF in this checkout: $kc"; return 0; }
  printf '%s\n' "$MODIFY_DIR_CREATE '$obj'"
  printf '%s\n' "MAKEOBJDIRPREFIX='$obj' make -C '$work' -j\$(sysctl -n hw.ncpu) buildkernel KERNCONF='$kc'"
}

#@help _stage_install_kernel1
# @command stage install kernel <stage>
# @summary Unprivileged installkernel into the stage's destdir — destdir/boot/kernel becomes selectable by the filter
# @group   stage
# @env     ELEBAKE_KERNCONF  the kernel configuration to install (must match the build)
# @example elebake stage install kernel smoke1
# @see     stage filter add
#@end
_stage_install_kernel1() {
  local name="$1" base="$ELEBAKE_BASE" kc="${ELEBAKE_KERNCONF:-}"
  local stageid
  stageid=$(resolve_item stage "$name" strict) || {
    generate_error "stage install kernel: unknown stage '$name'"; return 0; }
  local d="$base/.staging/$stageid" work="$base/.staging/$stageid/work" obj="$base/.staging/$stageid/obj"
  [ -L "$work" ] || {
    generate_error "stage install kernel '$name': not checked out"; return 0; }
  [ -n "$kc" ] || {
    generate_error "stage install kernel: ELEBAKE_KERNCONF not set (elebake setenv ELEBAKE_KERNCONF GENERIC)"; return 0; }
  [ -d "$obj" ] || {
    generate_error "stage install kernel '$name': no obj tree (stage build kernel $name first)"; return 0; }
  printf '%s\n' "$MODIFY_DIR_CREATE '$d/destdir/boot'"
  printf '%s\n' "MAKEOBJDIRPREFIX='$obj' make -C '$work' installkernel KERNCONF='$kc' INSTALL=\"install -U\" DESTDIR='$d/destdir'"
}

# filter — the CURATED list of what belongs in boot/. Stored as
# .staging/<id>/filter (one destdir/boot-relative path per line), maintained
# via `stage filter add <stage> <rel>` / `stage filter drop <stage> <rel>`
# (family-verb grammar), displayed via `stage filter show <stage>`; survives
# `stage reset` like the key bindings do. `stage include <stage>` works the
# filter off dumbly.

# filter_covers <flt> <entry> — is <entry> covered by the curation
# (listed itself, or living under a listed directory entry)?
filter_covers() {
  local flt="$1" e="$2" line
  grep -qxF "$e" "$flt" 2>/dev/null && return 0
  while IFS= read -r line; do
    case "$e" in "$line"/*) return 0 ;; esac
  done < "$flt"
  return 1
}

# stage_filter_show_worker <stage> <srclabel> <src> — ONE view, the whole
# truth: the curated list, what sits uncurated in the source (top level),
# and what lies orphaned in boot/ (not covered by the filter and not a
# generated artifact: manifest, manifest.asc, *.signed).
stage_filter_show_worker() {
  local name="$1" srclabel="$2" src="$3" base="$ELEBAKE_BASE"
  local stageid e
  stageid=$(resolve_item stage "$name" strict) || {
    generate_error "stage filter show: unknown stage '$name'"; return 0; }
  local flt="$base/.staging/$stageid/filter" bootd="$base/.staging/$stageid/boot"
  printf '# filter of %s (%s)\n' "$name" "$stageid"
  if [ -s "$flt" ]; then
    sed 's/^/#   /' "$flt"
  else
    printf '#   (empty — stage filter add %s <rel>)\n' "$name"
  fi
  printf '#\n# uncurated in %s (top level):\n' "$srclabel"
  if [ -d "$src" ]; then
    local found=0
    for e in "$src"/* "$src"/.[!.]*; do
      [ -e "$e" ] || continue
      e=$(basename "$e")
      filter_covers "$flt" "$e" && continue
      printf '#   %s\n' "$e"; found=1
    done
    [ "$found" -eq 1 ] || printf '#   (none)\n'
  else
    printf '#   (source not present)\n'
  fi
  printf '#\n# orphaned in boot/ (not covered, not generated):\n'
  if [ -d "$bootd" ]; then
    local found=0
    for e in "$bootd"/* "$bootd"/.[!.]*; do
      [ -e "$e" ] || continue
      e=$(basename "$e")
      case "$e" in manifest|manifest.asc|*.signed) continue ;; esac
      filter_covers "$flt" "$e" && continue
      printf '#   %s\n' "$e"; found=1
    done
    [ "$found" -eq 1 ] || printf '#   (none)\n'
  else
    printf '#   (boot/ empty)\n'
  fi
}

#@help _stage_filter_show1
# @command stage filter show <stage> [<srcdir>]
# @summary ONE view, the whole truth: the curated list, what sits uncurated in the source, what lies orphaned in boot/
# @group   stage
# @see     stage filter add
# @see     stage include
#@end
_stage_filter_show1() {
  local base="$ELEBAKE_BASE" stageid
  stageid=$(resolve_item stage "$1" strict) || {
    generate_error "stage filter show: unknown stage '$1'"; return 0; }
  stage_filter_show_worker "$1" "destdir/boot" "$base/.staging/$stageid/destdir/boot"
}

#@help _stage_filter_show2
# @internal 2-arg sibling of 'stage filter show': delta against a chosen
# source directory (matches stage include <stage> <srcdir>)
#@end
_stage_filter_show2() {
  case "$2" in
    /*) ;;
    *) generate_error "stage filter show: source must be an absolute directory: '$2'"; return 0 ;;
  esac
  stage_filter_show_worker "$1" "$2" "$2"
}

stage_filter_add_emit() {
  local flt="$1" name="$2" rel="$3"
  printf '%s\n' "grep -qxF '$rel' '$flt' 2>/dev/null || echo '$rel' >> '$flt'"
  printf '%s\n' "$MODIFY_FILE_PERMS 0600 '$flt'"
  printf '%s\n' "printf '# filter of %s: + %s\\n' '$name' '$rel' >&2"
}

stage_filter_rel_ok() {
  case "$1" in
    ""|/*|*..*|*"'"*) return 1 ;;
  esac
  return 0
}

#@help _stage_filter_add2
# @command stage filter add <stage> <rel|->
# @summary Curate one destdir/boot-relative path into the boot/ list (idempotent append); '-' reads a FROZEN snapshot from stdin, one path per line
# @group   stage
# @example elebake stage filter add smoke1 loader.efi
# @see     stage include
# @see     stage filter drop
#@end
_stage_filter_add2() {
  local name="$1" rel="$2" base="$ELEBAKE_BASE" line
  local stageid
  stageid=$(resolve_item stage "$name" strict) || {
    generate_error "stage filter add: unknown stage '$name'"; return 0; }
  local flt="$base/.staging/$stageid/filter"
  if [ "$rel" = "-" ]; then
    # stdin at generation time: one destdir/boot-relative path per line
    # (e.g. `ls /my-filter | elebake stage filter add <stage> -`) — a
    # FROZEN curation snapshot, vs. a directory entry which is a LIVING
    # one (new files under it travel along).
    while IFS= read -r line <&3; do
      [ -n "$line" ] || continue
      stage_filter_rel_ok "$line" || {
        generate_error "stage filter add: invalid path '$line' (destdir/boot-relative, no ..)"; return 0; }
      stage_filter_add_emit "$flt" "$name" "$line"
    done
    return 0
  fi
  stage_filter_rel_ok "$rel" || {
    generate_error "stage filter add: invalid path '$rel' (destdir/boot-relative, no ..)"; return 0; }
  stage_filter_add_emit "$flt" "$name" "$rel"
}

#@help _stage_filter_drop2
# @command stage filter drop <stage> <rel>
# @summary Remove one entry from the boot/ curation list
# @group   stage
# @see     stage filter add
#@end
_stage_filter_drop2() {
  local name="$1" rel="$2" base="$ELEBAKE_BASE"
  local stageid
  stageid=$(resolve_item stage "$name" strict) || {
    generate_error "stage filter drop: unknown stage '$name'"; return 0; }
  local flt="$base/.staging/$stageid/filter"
  [ -f "$flt" ] || {
    generate_error "stage filter drop '$name': no filter yet (stage filter add $name <rel>)"; return 0; }
  grep -qxF "$rel" "$flt" || {
    generate_error "stage filter drop '$name': not listed: $rel"; return 0; }
  printf '%s\n' "grep -vxF '$rel' '$flt' > '$flt.new'; mv '$flt.new' '$flt'"
  printf '%s\n' "printf '# filter of %s: - %s\\n' '$name' '$rel' >&2"
}

# stage_include_worker <stage> <srcdir-label> <srcdir> — the shared body:
# the SAME curated filter list, a selectable SOURCE. Default source is the
# stage's own build (destdir/boot, variant a); any binary directory such as
# the host's /boot serves as variant (b) — nothing to derive, the curation
# is source-relative by construction.
stage_include_worker() {
  local name="$1" srclabel="$2" src="$3" base="$ELEBAKE_BASE"
  local stageid
  stageid=$(resolve_item stage "$name" strict) || {
    generate_error "stage include: unknown stage '$name'"; return 0; }
  local d="$base/.staging/$stageid" inc="$base/.staging/$stageid/filter"
  [ -s "$inc" ] || {
    generate_error "stage include '$name': filter empty or missing (stage filter add $name <rel>)"; return 0; }
  [ -d "$src" ] || {
    generate_error "stage include '$name': source not present: $srclabel (stage install first?)"; return 0; }
  # Two passes: validate EVERY entry before emitting a single command, so a
  # broken manifest aborts before anything ran — not halfway through.
  local rel dir
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    [ -e "$src/$rel" ] || {
      generate_error "stage include '$name': listed but not in $srclabel: $rel"; return 0; }
  done < "$inc"
  emit_note "elebake stage include '$name' (work the filter off; source: $srclabel)"
  # rm -rf before cp: adopted trees carry 0555 files (install -m 555), which
  # even the owner cannot open for writing — and directory entries must be
  # REPLACED wholesale or a re-include dies on the existing dir (a bare
  # rm -f cannot remove one). Fail loudly per entry.
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    dir=$(dirname "boot/$rel")
    printf '%s\n' "$MODIFY_DIR_CREATE '$d/$dir'"
    printf '%s\n' "rm -rf '$d/boot/$rel' && cp -a '$src/$rel' '$d/boot/$rel' || { printf '# Error: include failed for %s\\n' '$rel' >&2; exit 1; }"
  done < "$inc"
  printf '%s\n' "printf '# Included %s filter entries into boot/ of stage %s (source: %s)\\n' \"\$(grep -c . '$inc')\" '$name' '$srclabel' >&2"
}

#@help _stage_include1
# @internal 1-arg sibling of 'stage include': the default source is the
# stage's own destdir/boot (variant a)
#@end
_stage_include1() {
  local base="$ELEBAKE_BASE" stageid
  stageid=$(resolve_item stage "$1" strict) || {
    generate_error "stage include: unknown stage '$1'"; return 0; }
  stage_include_worker "$1" "destdir/boot" "$base/.staging/$stageid/destdir/boot"
}

#@help _stage_include2
# @command stage include <stage> [<srcdir>]
# @summary Work the curated filter off from a chosen SOURCE directory (default: the stage's own destdir/boot; e.g. /boot takes the same selection from the host's binaries)
# @group   stage
# @example elebake stage include smoke1 /boot
# @see     stage filter add
#@end
_stage_include2() {
  case "$2" in
    /*) ;;
    *) generate_error "stage include: source must be an absolute directory: '$2'"; return 0 ;;
  esac
  stage_include_worker "$1" "$2" "$2"
}

# _stage_manifest1 <stage> — hash the boot set (incl. the SIGNED loader) -> manifest
#@help _stage_adopt4
# @command stage adopt <stage> <medium> <gpt-label> <pool/dataset>
# @summary One-time adoption: copy the medium's boot tree into the stage -- boot/ becomes the single source of truth
# @group   stage
# @param   medium        which registered medium is inserted (presence check + bookkeeping)
# @param   gpt-label     GPT label of the pool partition (e.g. sdcard-zkey); the
# @param                 import is CONFINED to /dev/gpt/<label> -- no device scan
# @param   pool/dataset  ZFS dataset carrying the boot/ tree (e.g. zkey/boot-illyria)
# @example elebake stage adopt smoke1 b sdcard-zkey zkey/boot-illyria
# @see     stage filter add
#@end
_stage_adopt4() {
  local name="$1" medium="$2" label="$3" ds="$4" base="$ELEBAKE_BASE"
  local stageid node mnt rel owner pool
  stageid=$(resolve_item stage "$name" strict) || {
    generate_error "stage adopt: unknown stage '$name'"; return 0; }
  local d="$base/.staging/$stageid"
  stage_read_medium "$d" "$medium" || {
    generate_error "stage adopt '$name': unknown medium '$medium' (stage device $name $medium /dev/<node>)"; return 0; }
  case "$label" in
    ""|*/*|*[!A-Za-z0-9_.-]*)
      generate_error "stage adopt: invalid gpt label '$label'"; return 0 ;;
  esac
  case "$ds" in */*) pool="${ds%%/*}" ;; *)
    generate_error "stage adopt: expected <pool>/<dataset>, got '$ds'"; return 0 ;;
  esac
  owner=$(id -un 2>>"$LOG_FILE")
  emit_note "elebake stage adopt '$name' (medium '$medium': $ds from /dev/gpt/$label -> boot/; read-only import)"
  printf '%s\n' "test -c '$node' || { printf '# Error: device not present: %s (insert medium %s)\\n' '$node' '$medium' >&2; exit 1; }"
  printf '%s\n' "test -c '/dev/gpt/$label' || { printf '# Error: no such gpt label: /dev/gpt/%s (wrong medium?)\\n' '$label' >&2; exit 1; }"
  printf '%s\n' "ad=\$(mktemp -d) || exit 1"
  printf '%s\n' "zpool import -d '/dev/gpt/$label' -o readonly=on -R \"\$ad\" -N '$pool' || { printf '# Error: cannot import pool %s read-only from /dev/gpt/%s (already imported?)\\n' '$pool' '$label' >&2; exit 1; }"
  printf '%s\n' "zfs mount '$pool' 2>/dev/null; zfs mount '$ds' || { zpool export '$pool'; printf '# Error: cannot mount %s\\n' '$ds' >&2; exit 1; }"
  printf '%s\n' "mp=\$(zfs get -H -o value mountpoint '$ds')"
  printf '%s\n' "[ -d \"\$mp/boot\" ] || { zpool export '$pool'; printf '# Error: no boot/ under %s -- not a boot dataset?\\n' \"\$mp\" >&2; exit 1; }"
  printf '%s\n' "cp -a \"\$mp/boot/.\" '$d/boot/' || { zpool export '$pool'; printf '# Error: copy failed\\n' >&2; exit 1; }"
  # export can be transiently busy (zfsd/devd poking the fresh pool):
  # unmount explicitly, then retry bounded before declaring failure.
  printf '%s\n' "zfs umount '$ds' 2>/dev/null; zfs umount '$pool' 2>/dev/null"
  printf '%s\n' "n=0; until zpool export '$pool' 2>/dev/null; do n=\$((n+1)); [ \"\$n\" -ge 5 ] && { printf '# Error: pool %s still busy after 5 tries -- export manually: zpool export %s\\n' '$pool' '$pool' >&2; exit 1; }; sleep 1; done"
  printf '%s\n' "rmdir \"\$ad\" 2>/dev/null || true"""
  printf '%s\n' "chown -R '$owner' '$d/boot' 2>/dev/null || true"
  printf '%s\n' "echo 'adopted=$ds via gpt/$label (medium $medium)' >> '$d/metadata'"
  printf '%s\n' "printf '# adopted %s files from %s into boot/ of stage %s\\n' \"\$(find '$d/boot' -type f | wc -l | tr -d ' ')\" '$ds' '$name' >&2"
}

#@help _stage_loader2
# @command stage loader <stage> <loader.efi>
# @summary Ingest an ALREADY-BUILT external loader as boot/loader.efi -- sign it without building
# @group   stage
# @param   loader.efi  path to a pre-built EFI loader (e.g. a stock installer's BOOTX64.EFI)
# @example elebake stage loader lexar /tmp/bootx64.efi
# @see     stage sign
#@end
_stage_loader2() {
  local name="$1" src="$2" base="$ELEBAKE_BASE"
  local stageid
  stageid=$(resolve_item stage "$name" strict) || {
    generate_error "stage loader: unknown stage '$name'"; return 0; }
  [ -f "$src" ] || {
    generate_error "stage loader '$name': no such file: $src"; return 0; }
  local d="$base/.staging/$stageid"
  # Sign-only path: no build/checkout/trust needed. Places the external loader
  # as boot/loader.efi; 'stage sign' then produces boot/loader.efi.signed.
  # rm -f first (an adopted/earlier loader may be 0555 and unwritable).
  emit_note "elebake stage loader '$name' ($src -> boot/loader.efi)"
  printf '%s\n' "$MODIFY_DIR_CREATE '$d/boot'"
  printf '%s\n' "rm -f '$d/boot/loader.efi' && cp '$src' '$d/boot/loader.efi' || { printf '# Error: loader ingest failed\\n' >&2; exit 1; }"
  printf '%s\n' "printf '# ingested %s -> boot/loader.efi of stage %s (now: stage sign %s)\\n' '$src' '$name' '$name' >&2"
}

# generation-time VALUE helpers (not dispatchable, PURE or read-only World
# probes -- they return values to the generator, they never emit shell).

# hex digest -> C byte-array initializer (0xAB,0xCD,...). Applied by the
# generator; its result is baked into the output.
hex_to_bytes() {
  printf '%s' "$1" | sed 's/\(..\)/0x\1,/g; s/,$//'
}

# is a smbios string a real board identity, or a vendor placeholder?
board_usable() {
  case "$1" in
    ''|'Not Applicable'|'Not Specified'|None|'N/A'|'Default string'|'To Be Filled By O.E.M.'|'System Serial Number'|Unknown|0)
      return 1 ;;
  esac
  return 0
}

# byte offset of OptionalData in an EFI_LOAD_OPTION file: 4B Attributes,
# 2B FilePathListLength, UCS-2 Description up to NUL, device path -- the tail
# is OptionalData. Echoes the offset, fails when the file does not parse.
# Mirrors secboot.sh _fact_optdata_offset.
optdata_offset() {
  local f="$1" size fplen desclen off
  size=$(wc -c < "$f" | tr -d ' ')
  [ "$size" -gt 8 ] || return 1
  fplen=$(od -An -tu1 -j4 -N2 "$f" | awk '{print $1 + $2*256}')
  desclen=$(od -An -tu1 -j6 "$f" | awk '{for (i = 1; i <= NF; i++) v[n++] = $i} END {for (k = 0; k + 1 < n; k += 2) if (v[k] == 0 && v[k+1] == 0) {print k + 2; exit}}')
  off=$((6 + ${desclen:-0} + ${fplen:-0}))
  { [ -n "$fplen" ] && [ -n "$desclen" ] && [ "$off" -gt 8 ] && [ "$off" -le "$size" ]; } || return 1
  printf '%s\n' "$off"
}

#@help _stage_manifest1
# @command stage manifest <stage>
# @summary Generate the REAL veriexec manifest over boot/ (path sha256=hash; includes loader.efi as disaster reserve)
# @group   stage
# @see     stage attest
#@end
_stage_manifest1() {
  local name="$1" base="$ELEBAKE_BASE"
  local stageid
  stageid=$(resolve_item stage "$name" strict) || {
    generate_error "stage manifest: unknown stage '$name'"; return 0; }
  local d="$base/.staging/$stageid"
  [ -f "$d/boot/loader.efi" ] || {
    generate_error "stage manifest '$name': boot/ not populated"; return 0; }
  # secboot.sh recipe (internal_manifest_generate): every file except the
  # manifest pair, LC_ALL=C-sorted, 'path sha256=hash'. loader.efi included on
  # purpose -- it is the disaster reserve, and an unverified reserve is not a
  # reserve. boot/ is World the generator sees as-is, so the WHOLE manifest is
  # computed HERE: the emission is one concrete heredoc write -- the trace
  # shows the exact file that will land, no runtime hashing left.
  local rel hash entries="" count=0
  for rel in $( { cd "$d/boot" 2>/dev/null && find . -type f ! -name manifest ! -name manifest.asc; } | sed 's|^\./||' | LC_ALL=C sort ); do
    hash=$(sha256 -q "$d/boot/$rel" 2>>"$LOG_FILE") || {
      generate_error "stage manifest '$name': cannot hash $rel (sha256 available in this context?)"; return 0; }
    entries="${entries}${rel} sha256=${hash}
"
    count=$((count+1))
  done
  [ "$count" -gt 0 ] || {
    generate_error "stage manifest '$name': boot/ holds no files to list"; return 0; }
  emit_note "elebake stage manifest '$name' ($count entries, hashed at generation time)"
  printf '%s\n' "cat > '$d/boot/manifest.new' <<'ELVEOF'"
  printf '%s' "$entries"
  printf '%s\n' "ELVEOF"
  printf '%s\n' "mv '$d/boot/manifest.new' '$d/boot/manifest' && chmod 0644 '$d/boot/manifest'"
  printf '%s\n' "printf '# manifest written: $count entries\\n' >&2"
}

# _stage_verify1 <stage> — non-modifying inspection: the manifest and the tree
# are both World the generator sees as-is, so BOTH directions are checked at
# generation time and the findings are emitted as comment lines (a
# misconfigured interpreter cannot execute them). Findings end in an emitted
# error; a clean tree emits the ok line.
#@help _stage_verify1
# @command stage verify <stage>
# @summary Manifest consistency BOTH ways, checked at generation time: listed entries must match, unlisted files are findings
# @group   stage
#@end
_stage_verify1() {
  local name="$1" base="$ELEBAKE_BASE"
  local stageid
  stageid=$(resolve_item stage "$name" strict) || {
    generate_error "stage verify: unknown stage '$name'"; return 0; }
  local d="$base/.staging/$stageid"
  [ -f "$d/boot/manifest" ] || {
    generate_error "stage verify '$name': no boot/manifest (stage manifest first)"; return 0; }
  local rel hash have findings="" count=0 tree
  # direction 1: every manifest entry exists and hashes identically
  while read -r rel hash; do
    case "$hash" in sha256=*) ;; *) continue ;; esac
    count=$((count+1))
    # Findings are emitted as stderr prints so they are VISIBLE under the
    # executing sh pin too (a bare # comment is a no-op there).
    if [ ! -f "$d/boot/$rel" ]; then
      findings="${findings}printf '%s\n' '# MISSING  $rel' >&2
"
    else
      have="sha256=$(sha256 -q "$d/boot/$rel" 2>>"$LOG_FILE")"
      [ "$have" = "$hash" ] || findings="${findings}printf '%s\n' '# MISMATCH $rel' >&2
"
    fi
  done < "$d/boot/manifest"
  # direction 2: every file in the tree is listed (set difference, computed now)
  tree=$( { cd "$d/boot" 2>/dev/null && find . -type f ! -name manifest ! -name manifest.asc; } | sed 's|^\./||' | LC_ALL=C sort )
  for rel in $tree; do
    cut -d' ' -f1 "$d/boot/manifest" | grep -qxF -- "$rel" || findings="${findings}printf '%s\n' '# UNLISTED $rel' >&2
"
  done
  if [ -n "$findings" ]; then
    printf '%s' "$findings"
    generate_error "stage verify '$name': manifest inconsistent (see findings above)"
    return 0
  fi
  printf '%s\n' "printf '%s\\n' '# verify ok: $name ($count entries, checked at generation time)' >&2"
}

# deploy targets — NAMED media records (.staging/<id>/media/<medium>/ with
# node, mountpoint, loaderpath), registered via `stage device`. Backups sort
# under backup/<medium>/ so a rollback can never replay one card's (possibly
# ancient) loader onto the other. The medium NAME states operator INTENT:
# with dd-cloned cards the tool cannot verify which one is inserted — the
# operator can. Defaults (/mnt, EFI/BOOT/BOOTX64.EFI) are materialized INTO
# the record at registration; consumers never default. The ESP needs root,
# so backup/deploy/rollback run as `... | sudo sh` (or via their pins).

# shared generation-time helper (not dispatchable): read a medium record
stage_read_medium() {
  local d="$1" m="$2"
  [ -f "$d/media/$m/node" ] || return 1
  node=$(head -n1 "$d/media/$m/node")
  mnt=$(head -n1 "$d/media/$m/mountpoint")
  rel=$(head -n1 "$d/media/$m/loaderpath")
}

#@help __stage_device3
# @internal arity-3 sibling of 'stage device': rewrites to the full command
# with the /mnt default materialized (never a direct function call)
#@end
__stage_device3() {
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage device '$1' '$2' '$3' /mnt"
}

#@help _stage_device4
# @command stage device <stage> <medium> </dev/node> [<mountpoint>]
# @summary Register a NAMED deploy medium; its backups sort under backup/<medium>
# @group   deploy
# @param   medium  operator's name for the physical card/stick (e.g. a, b)
# @param   node    device node the medium appears as (e.g. /dev/da1p1)
# @example elebake stage device smoke1 a /dev/da1p1
# @see     stage deploy
#@end
_stage_device4() {
  local name="$1" medium="$2" node="$3" mnt="$4" base="$ELEBAKE_BASE"
  local stageid
  stageid=$(resolve_item stage "$name" strict) || {
    generate_error "stage device: unknown stage '$name'"; return 0; }
  case "$medium" in
    ""|*/*|.|..|*[!A-Za-z0-9_.-]*)
      generate_error "stage device: invalid medium name '$medium'"; return 0 ;;
  esac
  case "$node" in /dev/*) ;; *)
    generate_error "stage device: not a device node: '$node' (expected /dev/...)"; return 0 ;;
  esac
  local rec="$base/.staging/$stageid/media/$medium"
  printf '%s\n' "$MODIFY_DIR_CREATE '$rec'"
  printf '%s\n' "$MODIFY_FILE_PERMS 0700 '$rec'"
  printf '%s\n' "echo '$node' > '$rec/node'"
  printf '%s\n' "echo '$mnt' > '$rec/mountpoint'"
  printf '%s\n' "echo 'EFI/BOOT/BOOTX64.EFI' > '$rec/loaderpath'"
  printf '%s\n' "$MODIFY_FILE_PERMS 0600 '$rec/node' '$rec/mountpoint' '$rec/loaderpath'"
  printf '%s\n' "printf '# Registered medium %s: %s (mount %s) on stage %s\\n' '$medium' '$node' '$mnt' '$name' >&2"
}

#@help _stage_backup2
# @command stage backup <stage> <medium>
# @summary Save the loader currently ON that medium into backup/<medium>/ (timestamped)
# @group   deploy
# @example elebake stage backup smoke1 a
#@end
_stage_backup2() {
  local name="$1" medium="$2" base="$ELEBAKE_BASE"
  local stageid node mnt rel owner
  stageid=$(resolve_item stage "$name" strict) || {
    generate_error "stage backup: unknown stage '$name'"; return 0; }
  local d="$base/.staging/$stageid"
  stage_read_medium "$d" "$medium" || {
    generate_error "stage backup '$name': unknown medium '$medium' (stage device $name $medium /dev/<node>)"; return 0; }
  owner=$(id -un 2>>"$LOG_FILE")
  local stamp; stamp=$(date -u '+%Y%m%dT%H%M%SZ' 2>>"$LOG_FILE")
  local bdir="$d/backup/$medium" bak="$d/backup/$medium/$(basename "$rel").$stamp"
  emit_note "elebake stage backup '$name' medium '$medium' ($node:$rel -> backup/$medium/)"
  printf '%s\n' "test -c '$node' || { printf '# Error: device not present: %s (insert medium %s)\\n' '$node' '$medium' >&2; exit 1; }"
  printf '%s\n' "$MODIFY_DIR_CREATE '$bdir'"
  printf '%s\n' "mount -r -t msdosfs '$node' '$mnt' || { printf '# Error: mount failed -- already mounted or device busy? (mount | grep %s)\\n' '$node' >&2; exit 1; }"
  printf '%s\n' "test -f '$mnt/$rel' || { umount '$mnt'; printf '# Error: no loader on medium %s: %s\\n' '$medium' '$rel' >&2; exit 1; }"
  printf '%s\n' "cp -p '$mnt/$rel' '$bak'"
  printf '%s\n' "umount '$mnt'"
  printf '%s\n' "chown '$owner' '$bdir' '$bak' 2>/dev/null || true"
  printf '%s\n' "printf '# backed up %s (%s) -> %s\\n' '$rel' '$medium' '$bak' >&2"
}

#@help _stage_deploy2
# @command stage deploy <stage> <medium>
# @summary The loader swap onto the NAMED medium: mount, backup, copy, verify, umount
# @group   deploy
# @param   medium  which registered medium is inserted -- the operator's claim
# @example elebake stage deploy smoke1 a
# @see     stage rollback
#@end
_stage_deploy2() {
  local name="$1" medium="$2" base="$ELEBAKE_BASE"
  local stageid node mnt rel owner
  stageid=$(resolve_item stage "$name" strict) || {
    generate_error "stage deploy: unknown stage '$name'"; return 0; }
  local d="$base/.staging/$stageid"
  stage_read_medium "$d" "$medium" || {
    generate_error "stage deploy '$name': unknown medium '$medium' (stage device $name $medium /dev/<node>)"; return 0; }
  local src="$d/boot/loader.efi.signed"
  { [ -f "$src" ] && [ "$src" -nt "$d/boot/loader.efi" ]; } || {
    generate_error "stage deploy '$name': signed loader missing or stale (stage sign $name first)"; return 0; }
  owner=$(id -un 2>>"$LOG_FILE")
  local stamp; stamp=$(date -u '+%Y%m%dT%H%M%SZ' 2>>"$LOG_FILE")
  local bdir="$d/backup/$medium" bak="$d/backup/$medium/$(basename "$rel").$stamp"
  # the EXPECTED hash is local World -- computed now and baked in, so the
  # trace shows which loader is meant to land before anything runs
  local want
  want=$(sha256 -q "$src" 2>>"$LOG_FILE") || {
    generate_error "stage deploy '$name': cannot hash $src"; return 0; }
  emit_note "elebake stage deploy '$name' medium '$medium' ($node:$rel <- boot/loader.efi.signed, sha256 $want)"
  printf '%s\n' "test -c '$node' || { printf '# Error: device not present: %s (insert medium %s)\\n' '$node' '$medium' >&2; exit 1; }"
  printf '%s\n' "$MODIFY_DIR_CREATE '$bdir'"
  printf '%s\n' "mount -t msdosfs '$node' '$mnt' || { printf '# Error: mount failed -- already mounted or device busy? (mount | grep %s)\\n' '$node' >&2; exit 1; }"
  printf '%s\n' "if [ -f '$mnt/$rel' ]; then cp -p '$mnt/$rel' '$bak'; printf '# backed up %s (%s) -> %s\\n' '$rel' '$medium' '$bak' >&2; else printf '# note: no existing loader on medium %s to back up\\n' '$medium' >&2; fi"
  printf '%s\n' "cp '$src' '$mnt/$rel'"
  printf '%s\n' "[ \"\$(sha256 -q '$mnt/$rel')\" = '$want' ] || { printf '# Error: hash mismatch after deploy (medium left mounted at %s)\\n' '$mnt' >&2; exit 1; }"
  printf '%s\n' "umount '$mnt'"
  printf '%s\n' "sync"
  printf '%s\n' "chown '$owner' '$bdir' '$bak' 2>/dev/null || true"
  printf '%s\n' "printf '# deployed signed loader to medium %s (%s:%s, sha256 $want)\\n' '$medium' '$node' '$rel' >&2"
}

#@help __stage_rollback2
# @internal newest-backup sibling of 'stage rollback': resolves the newest
# backup OF THAT MEDIUM at generation time and rewrites to the full command
#@end
__stage_rollback2() {
  local name="$1" medium="$2" base="$ELEBAKE_BASE"
  local stageid newest
  stageid=$(resolve_item stage "$name" strict) || {
    printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage rollback: unknown stage $name'"; return 0; }
  newest=$(ls "$base/.staging/$stageid/backup/$medium" 2>/dev/null | sort | tail -n1)
  [ -n "$newest" ] || {
    printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage rollback $name: no backups for medium $medium (stage backup / stage deploy first)'"; return 0; }
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage rollback '$name' '$medium' '$newest'"
}

#@help _stage_rollback3
# @command stage rollback <stage> <medium> [<backup>]
# @summary Restore the newest (or a named) backup OF THAT MEDIUM to the medium
# @group   deploy
# @example elebake stage rollback smoke1 a
#@end
_stage_rollback3() {
  local name="$1" medium="$2" file="$3" base="$ELEBAKE_BASE"
  local stageid node mnt rel
  stageid=$(resolve_item stage "$name" strict) || {
    generate_error "stage rollback: unknown stage '$name'"; return 0; }
  local d="$base/.staging/$stageid"
  stage_read_medium "$d" "$medium" || {
    generate_error "stage rollback '$name': unknown medium '$medium' (stage device $name $medium /dev/<node>)"; return 0; }
  local bak="$d/backup/$medium/$file"
  [ -f "$bak" ] || {
    generate_error "stage rollback '$name': no such backup for medium '$medium': $file"; return 0; }
  # expected hash is local World -- computed now, baked into the check
  local want
  want=$(sha256 -q "$bak" 2>>"$LOG_FILE") || {
    generate_error "stage rollback '$name': cannot hash $bak"; return 0; }
  emit_note "elebake stage rollback '$name' medium '$medium' ($node:$rel <- backup/$medium/$file, sha256 $want)"
  printf '%s\n' "test -c '$node' || { printf '# Error: device not present: %s (insert medium %s)\\n' '$node' '$medium' >&2; exit 1; }"
  printf '%s\n' "mount -t msdosfs '$node' '$mnt' || { printf '# Error: mount failed -- already mounted or device busy? (mount | grep %s)\\n' '$node' >&2; exit 1; }"
  printf '%s\n' "cp '$bak' '$mnt/$rel'"
  printf '%s\n' "[ \"\$(sha256 -q '$mnt/$rel')\" = '$want' ] || { printf '# Error: hash mismatch after rollback (medium left mounted at %s)\\n' '$mnt' >&2; exit 1; }"
  printf '%s\n' "umount '$mnt'"
  printf '%s\n' "sync"
  printf '%s\n' "printf '# rolled back medium %s (%s:%s) from backup/%s/%s\\n' '$medium' '$node' '$rel' '$medium' '$file' >&2"
}

#=============================================================================
# source phase — derive the deploy into the worktree (trust config first;
# the C-file deploys from ELEBAKE_ORIGIN follow in a later slice). Recipes from
# secboot.sh's source steps (SSoT). Inspect-by-default.
#=============================================================================

# _stage_trust_anchor1 <stage> — place the OpenPGP trust anchor + its self-test
# signature into <work>/lib/libsecureboot (recipe: secboot.sh trust_anchor +
# self_test_sig). Derives from the stage's bound attest-key.
#@help _stage_trust_anchor1
# @command stage trust anchor <stage>
# @summary Export the attest key + self-test signature into the worktree's libsecureboot
# @group   stage
# @example elebake stage trust anchor smoke1 | sudo sh
#@end
_stage_trust_anchor1() {
  local name="$1" base="$ELEBAKE_BASE"
  local stageid
  stageid=$(resolve_item stage "$name" strict) || {
    generate_error "stage trust anchor: unknown stage '$name'"; return 0; }
  local d="$base/.staging/$stageid" lsb="$base/.staging/$stageid/work/lib/libsecureboot"
  [ -L "$d/work" ] || {
    generate_error "stage trust anchor '$name': not checked out (stage checkout $name <ref>)"; return 0; }
  [ -f "$d/attest-key/keyid" ] || {
    generate_error "stage trust anchor '$name': no attest-key bound (stage attest key $name openpgp <key>)"; return 0; }
  local keyid gpgenv=""
  keyid=$(head -n1 "$d/attest-key/keyid")
  [ -f "$d/attest-key/gnupghome" ] && gpgenv="GNUPGHOME='$(head -n1 "$d/attest-key/gnupghome")' "
  emit_note "elebake stage trust anchor '$name' (OpenPGP trust anchor + self-test sig)"
  # IDEMPOTENT: clear previous artifacts first -- a failed earlier run
  # (worse: an elevated one) may have left root-owned empties behind.
  printf '%s\n' "rm -f '$lsb/ta_openpgp.asc' '$lsb/vc_openpgp.asc'"
  # gpg --export exits 0 even on "nothing exported" -- the emptiness test
  # is the real check; every step stops the batch on failure (no false
  # green: a "placed" note over a failed export would be a lie).
  printf '%s\n' "${gpgenv}gpg --export -a '$keyid' > '$lsb/ta_openpgp.asc' || { printf '# Error: trust anchor export failed for %s\\n' '$keyid' >&2; exit 1; }"
  printf '%s\n' "[ -s '$lsb/ta_openpgp.asc' ] || { printf '# Error: trust anchor export empty -- key %s not in this keyring? (openpgp add <name> <keyid> <gnupghome> for a keyring living elsewhere)\\n' '$keyid' >&2; exit 1; }"
  # The signature may need a pinentry (card key). The isolated
  # environment carries no GPG_TTY and the interpreter's stdin is a
  # pipe -- so the EMISSION determines its terminal itself, at run
  # time, and points the agent at it.
  printf '%s\n' "GPG_TTY=\$(tty </dev/tty 2>/dev/null); export GPG_TTY; ${gpgenv}gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1 || true"
  printf '%s\n' "${gpgenv}gpg --yes --openpgp -a --detach-sign --local-user '$keyid' -o '$lsb/vc_openpgp.asc' '$lsb/ta_openpgp.asc' || { printf '# Error: self-test signature failed for %s\\n' '$keyid' >&2; exit 1; }"
  printf '%s\n' "printf '# trust anchor + self-test sig placed for stage %s\\n' '$name' >&2"
}

# _stage_trust_mk1 <stage> — write site.trust.mk (VE_ config for the elevated
# OpenPGP build) into <work>/lib/libsecureboot. local.trust.mk .-includes it.
# Content from secboot.sh _fact_site_trust_mk; absolute paths (required).
#@help _stage_trust_mk1
# @command stage trust mk <stage>
# @summary Write site.trust.mk (elevated veriexec config) into the worktree
# @group   stage
#@end
_stage_trust_mk1() {
  local name="$1" base="$ELEBAKE_BASE"
  local stageid
  stageid=$(resolve_item stage "$name" strict) || {
    generate_error "stage trust mk: unknown stage '$name'"; return 0; }
  local d="$base/.staging/$stageid" lsb="$base/.staging/$stageid/work/lib/libsecureboot"
  [ -L "$d/work" ] || {
    generate_error "stage trust mk '$name': not checked out (stage checkout $name <ref>)"; return 0; }
  emit_note "elebake stage trust mk '$name' (site.trust.mk: elevated OpenPGP config)"
  printf '%s\n' "cat > '$lsb/site.trust.mk' <<'ELVEOF'"
  printf '%s\n' "# Generated by elebake -- do not edit by hand. Serverless OpenPGP."
  printf '%s\n' "VE_SIGNATURE_LIST= OPENPGP"
  printf '%s\n' "VE_HASH_LIST= SHA256 SHA384"
  printf '%s\n' "VE_SELF_TESTS= yes"
  printf '%s\n' "TRUST_ANCHORS= $lsb/ta_openpgp.asc"
  printf '%s\n' "TA_ASC_LIST= $lsb/ta_openpgp.asc"
  printf '%s\n' "VC_ASC_LIST= $lsb/vc_openpgp.asc"
  printf '%s\n' "ta_asc.h: \${TA_ASC_LIST} \${VC_ASC_LIST}"
  printf '%s\n' "XCFLAGS.opgp_key+= -DHAVE_TA_ASC_H"
  printf '%s\n' "CFLAGS+= -DLOADER_VERIEXEC_ELEVATED"
  printf '%s\n' "ELVEOF"
  printf '%s\n' "printf '# site.trust.mk written for stage %s\\n' '$name' >&2"
}

# ___stage_source1 <stage> — the source/trust phase (grows: + C-file deploys)
#@help ___stage_source1
# @command stage source <stage>
# @summary trust anchor + trust mk in one step
# @group   stage
#@end
___stage_source1() {
  local name="$1"
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage trust anchor '$name'"
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage trust mk '$name'"
}

# shared generation-time helper (not dispatchable): read a medium's boot tree
stage_read_boottree() {
  local d="$1" m="$2"
  [ -f "$d/media/$m/gptlabel" ] || return 1
  label=$(head -n1 "$d/media/$m/gptlabel")
  ds=$(head -n1 "$d/media/$m/dataset")
}

#@help _stage_boot_tree4
# @command stage boot tree <stage> <medium> <gpt-label> <pool/dataset>
# @summary Register where the medium's boot tree lives (used by stage push/tree sync)
# @group   deploy
# @param   gpt-label     GPT label of the pool partition (e.g. sdcard-zkey)
# @param   pool/dataset  ZFS dataset carrying the boot/ tree (e.g. zkey/boot-illyria)
# @example elebake stage boot tree smoke1 b sdcard-zkey zkey/boot-illyria
# @see     stage push
#@end
_stage_boot_tree4() {
  local name="$1" medium="$2" label="$3" ds="$4" base="$ELEBAKE_BASE"
  local stageid node mnt rel
  stageid=$(resolve_item stage "$name" strict) || {
    generate_error "stage boot tree: unknown stage '$name'"; return 0; }
  local d="$base/.staging/$stageid"
  stage_read_medium "$d" "$medium" || {
    generate_error "stage boot tree '$name': unknown medium '$medium' (stage device $name $medium /dev/<node>)"; return 0; }
  case "$label" in
    ""|*/*|*[!A-Za-z0-9_.-]*)
      generate_error "stage boot tree: invalid gpt label '$label'"; return 0 ;;
  esac
  case "$ds" in */*) ;; *)
    generate_error "stage boot tree: expected <pool>/<dataset>, got '$ds'"; return 0 ;;
  esac
  local rec="$base/.staging/$stageid/media/$medium"
  printf '%s\n' "echo '$label' > '$rec/gptlabel'"
  printf '%s\n' "echo '$ds' > '$rec/dataset'"
  printf '%s\n' "$MODIFY_FILE_PERMS 0600 '$rec/gptlabel' '$rec/dataset'"
  printf '%s\n' "printf '# Registered boot tree of medium %s: %s on gpt/%s (stage %s)\\n' '$medium' '$ds' '$label' '$name' >&2"
}

#@help _stage_tree_sync2
# @command stage tree sync <stage> <medium>
# @summary Write the stage's boot/ tree onto the medium's dataset -- snapshot first, verify in place, export
# @group   deploy
# @example elebake stage tree sync smoke1 b
# @see     stage push
#@end
_stage_tree_sync2() {
  local name="$1" medium="$2" base="$ELEBAKE_BASE"
  local stageid node mnt rel label ds pool
  stageid=$(resolve_item stage "$name" strict) || {
    generate_error "stage tree sync: unknown stage '$name'"; return 0; }
  local d="$base/.staging/$stageid"
  stage_read_medium "$d" "$medium" || {
    generate_error "stage tree sync '$name': unknown medium '$medium' (stage device $name $medium /dev/<node>)"; return 0; }
  stage_read_boottree "$d" "$medium" || {
    generate_error "stage tree sync '$name': no boot tree registered for medium '$medium' (stage boot tree $name $medium <gpt-label> <pool/dataset>)"; return 0; }
  { [ -f "$d/boot/manifest" ] && [ -f "$d/boot/manifest.asc" ]; } || {
    generate_error "stage tree sync '$name': boot/manifest(.asc) missing (stage manifest + stage attest first)"; return 0; }
  pool="${ds%%/*}"
  local stamp; stamp=$(date -u '+%Y%m%dT%H%M%SZ' 2>>"$LOG_FILE")
  local snap="$ds@elebake-$stamp"
  emit_note "elebake stage tree sync '$name' medium '$medium' (boot/ -> $ds, snapshot $snap)"
  printf '%s\n' "test -c '$node' || { printf '# Error: device not present: %s (insert medium %s)\\n' '$node' '$medium' >&2; exit 1; }"
  printf '%s\n' "test -c '/dev/gpt/$label' || { printf '# Error: no such gpt label: /dev/gpt/%s (wrong medium?)\\n' '$label' >&2; exit 1; }"
  printf '%s\n' "ad=\$(mktemp -d) || exit 1"
  printf '%s\n' "zpool import -d '/dev/gpt/$label' -R \"\$ad\" -N '$pool' || { printf '# Error: cannot import pool %s from /dev/gpt/%s (already imported?)\\n' '$pool' '$label' >&2; exit 1; }"
  printf '%s\n' "zfs mount '$pool' 2>/dev/null; zfs mount '$ds' || { zpool export '$pool'; printf '# Error: cannot mount %s\\n' '$ds' >&2; exit 1; }"
  printf '%s\n' "mp=\$(zfs get -H -o value mountpoint '$ds')"
  printf '%s\n' "[ -d \"\$mp/boot\" ] || { zpool export '$pool'; printf '# Error: no boot/ under %s -- not a boot dataset?\\n' \"\$mp\" >&2; exit 1; }"
  printf '%s\n' "zfs snapshot '$snap' || { zpool export '$pool'; printf '# Error: cannot snapshot %s\\n' '$snap' >&2; exit 1; }"
  printf '%s\n' "rm -rf \"\$mp/boot\" && mkdir \"\$mp/boot\" && cp -a '$d/boot/.' \"\$mp/boot/\" || { zfs rollback '$snap'; zpool export '$pool'; printf '# Error: tree copy failed -- rolled back to %s\\n' '$snap' >&2; exit 1; }"
  # On-medium verify: the copy exists only after the emitted cp (genuine
  # runtime), but the EXPECTATIONS -- paths and hashes -- are the manifest,
  # World the generator reads now. Unrolled here into one concrete check per
  # entry against "$mp/boot"; a mismatch triggers the emitted rollback.
  local vrel vhash vcount=0
  while read -r vrel vhash; do
    case "$vhash" in sha256=*) ;; *) continue ;; esac
    vcount=$((vcount+1))
    printf '%s\n' "[ \"sha256=\$(sha256 -q \"\$mp/boot/$vrel\" 2>/dev/null)\" = '$vhash' ] || { zfs rollback '$snap'; zpool export '$pool'; printf '# Error: on-medium verify failed at %s -- rolled back to %s\\n' '$vrel' '$snap' >&2; exit 1; }"
  done < "$d/boot/manifest"
  printf '%s\n' "zfs umount '$ds' 2>/dev/null; zfs umount '$pool' 2>/dev/null"
  printf '%s\n' "n=0; until zpool export '$pool' 2>/dev/null; do n=\$((n+1)); [ \"\$n\" -ge 5 ] && { printf '# Error: pool %s still busy after 5 tries -- export manually: zpool export %s\\n' '$pool' '$pool' >&2; exit 1; }; sleep 1; done"
  printf '%s\n' "rmdir \"\$ad\" 2>/dev/null || true"
  printf '%s\n' "printf '# tree synced to medium %s ($vcount entries verified in place; snapshot %s)\\n' '$medium' '$snap' >&2"
}

#@help ___stage_push2
# @command stage push <stage> <medium>
# @summary Publish the stage: manifest, attest, verify, tree onto the medium, loader onto the ESP
# @group   stage
# @example elebake stage push smoke1 a
# @see     stage make
#@end
___stage_push2() {
  local name="$1" medium="$2"
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage manifest '$name'"
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage attest '$name'"
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage verify '$name'"
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage tree sync '$name' '$medium'"
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage deploy '$name' '$medium'"
}

#@help _stage_edit2
# @command stage edit <stage> <relpath>
# @summary Edit a file of the stage's boot tree (the single source of truth); publish with stage push
# @group   stage
# @param   relpath  boot/-relative, e.g. loader.conf
# @env     EDITOR  the editor to open (default: FreeBSD ee)
# @example elebake stage edit smoke1 loader.conf | sh
# @see     stage push
#@end
_stage_edit2() {
  local name="$1" rel="$2" base="$ELEBAKE_BASE"
  local stageid
  stageid=$(resolve_item stage "$name" strict) || {
    generate_error "stage edit: unknown stage '$name'"; return 0; }
  local d="$base/.staging/$stageid"
  [ -f "$d/boot/$rel" ] || {
    generate_error "stage edit '$name': no such file in boot/: $rel (stage adopt / stage include first)"; return 0; }
  # ${EDITOR:-edit}: FreeBSD's base editor (ee). stdin from /dev/tty -- under
  # `| sh` the editor would otherwise inherit the script pipe as stdin.
  printf '%s\n' "\${EDITOR:-edit} '$d/boot/$rel' </dev/tty"
  printf '%s\n' "printf '# edited %s -- publish with: stage push %s <medium>\\n' '$rel' '$name' >&2"
}

#=============================================================================
# provisioning phase — the machine-bound trust expectations. Recipes are
# secboot.sh's (SSoT): internal_boot_marker, internal_trust_provision,
# _fact_board_id/_fact_keys_sha256/_fact_optdata_offset. Registration is
# bookkeeping (pinned sh); the write/measure steps need root -> `... | sudo sh`.
#=============================================================================

# _stage_marker3 <stage> <Boot####> <markerfile> — register the boot entry
# variable and the (root-only) file holding the marker VALUE. Paths/names are
# data; nothing is validated against the firmware here (the medium may not
# even be inserted).
#@help _stage_marker3
# @command stage marker <stage> <BootXXXX|new> [<filepath>]
# @summary Write the boot-entry marker: BootXXXX targets that load option, 'new' rotates the value; filepath (re)records the value file
# @group   provisioning
# @param   BootXXXX|new  load option to write into, or 'new' to force a fresh value
# @param   filepath      root-only file holding the marker value; optional once recorded
# @example elebake stage marker smoke1 Boot0000 /root/secureboot/boot-marker | sudo sh
# @example elebake stage marker smoke1 new | sudo sh
# @see     stage site mk
#@end
_stage_marker3() {
  local name="$1" op="$2" file="$3" base="$ELEBAKE_BASE"
  local stageid owner bootvar force=""
  stageid=$(resolve_item stage "$name" strict) || {
    generate_error "stage marker: unknown stage '$name'"; return 0; }
  local d="$base/.staging/$stageid" rec="$base/.staging/$stageid/marker"
  case "$file" in /*) ;; *)
    generate_error "stage marker: markerfile must be absolute: '$file'"; return 0 ;;
  esac
  case "$op" in
    Boot[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]) bootvar="$op" ;;
    new)
      force=new
      [ -f "$rec/bootvar" ] || {
        generate_error "stage marker '$name': 'new' needs a recorded load option (stage marker $name BootXXXX <filepath> first)"; return 0; }
      bootvar=$(head -n1 "$rec/bootvar")
      ;;
    *)
      generate_error "stage marker: neither a load option nor 'new': '$op'"; return 0 ;;
  esac
  owner=$(id -un 2>>"$LOG_FILE")
  local bak="$d/backup/$bootvar.orig"
  emit_note "elebake stage marker '$name' ($bootvar${force:+, FORCE NEW value})"
  printf '%s\n' "$MODIFY_DIR_CREATE '$rec' '$d/backup'"
  printf '%s\n' "echo '$bootvar' > '$rec/bootvar'"
  printf '%s\n' "echo '$file' > '$rec/file'"
  printf '%s\n' "$MODIFY_FILE_PERMS 0700 '$rec'; $MODIFY_FILE_PERMS 0600 '$rec/bootvar' '$rec/file'; chown '$owner' '$rec' '$rec/bootvar' '$rec/file' 2>/dev/null || true"
  printf '%s\n' "g=8be4df61-93ca-11d2-aa0d-00e098032b8c; v='$bootvar'"
  printf '%s\n' "t=\$(mktemp) || exit 1"
  printf '%s\n' "efivar --no-name --name \"\$g-\$v\" --binary > \"\$t\" 2>/dev/null || { printf '# Error: cannot read %s (root? entry present?)\\n' \"\$v\" >&2; exit 1; }"
  # EFI_LOAD_OPTION offset parse at RUNTIME on purpose: the entry is read and
  # rewritten in the same privileged execution; the marker VALUE must never
  # appear in a trace, so nothing of it is computed at generation time.
  printf '%s\n' "size=\$(wc -c < \"\$t\" | tr -d ' ')"
  printf '%s\n' "[ \"\$size\" -gt 8 ] || { printf '# Error: %s too short for an EFI_LOAD_OPTION\\n' \"\$v\" >&2; exit 1; }"
  printf '%s\n' "fplen=\$(od -An -tu1 -j4 -N2 \"\$t\" | awk '{print \$1 + \$2*256}')"
  printf '%s\n' "desclen=\$(od -An -tu1 -j6 \"\$t\" | awk '{for (i = 1; i <= NF; i++) v[n++] = \$i} END {for (k = 0; k + 1 < n; k += 2) if (v[k] == 0 && v[k+1] == 0) {print k + 2; exit}}')"
  printf '%s\n' "off=\$((6 + desclen + fplen))"
  printf '%s\n' "{ [ -n \"\$fplen\" ] && [ -n \"\$desclen\" ] && [ \"\$off\" -gt 0 ] && [ \"\$off\" -le \"\$size\" ]; } || { printf '# Error: %s does not parse as an EFI_LOAD_OPTION\\n' \"\$v\" >&2; exit 1; }"
  printf '%s\n' "[ -f '$bak' ] || cp \"\$t\" '$bak'"
  if [ -n "$force" ]; then
    printf '%s\n' "m=\$(openssl rand -hex 16) || { printf '# Error: openssl rand failed\\n' >&2; exit 1; }"
    printf '%s\n' "( umask 077; printf '%s\\n' \"\$m\" > '$file' ) || { printf '# Error: cannot write %s\\n' '$file' >&2; exit 1; }"
    printf '%s\n' "printf '# new marker generated and saved to %s\\n' '$file' >&2"
  else
    printf '%s\n' "if [ -s '$file' ]; then m=\$(cat '$file'); printf '# restoring the known marker from %s\\n' '$file' >&2; else m=\$(openssl rand -hex 16) || exit 1; ( umask 077; printf '%s\\n' \"\$m\" > '$file' ) || { printf '# Error: cannot write %s\\n' '$file' >&2; exit 1; }; printf '# new marker generated and saved to %s\\n' '$file' >&2; fi"
  fi
  printf '%s\n' "new=\$(mktemp) || exit 1"
  printf '%s\n' "dd if=\"\$t\" of=\"\$new\" bs=1 count=\"\$off\" 2>/dev/null"
  printf '%s\n' "printf 'RC %s' \"\$m\" >> \"\$new\""
  printf '%s\n' "dd if=/dev/zero bs=1 count=1 2>/dev/null >> \"\$new\""
  printf '%s\n' "efivar --write --name \"\$g-\$v\" < \"\$new\" || { printf '# Error: writing %s failed -- restore with: efivar --write --name %s < %s\\n' \"\$v\" \"\$g-\$v\" '$bak' >&2; exit 1; }"
  printf '%s\n' "rm -f \"\$t\" \"\$new\""
  printf '%s\n' "printf '# marker written to %s; sha256 %s\\n' \"\$v\" \"\$(printf '%s' \"\$m\" | sha256 -q)\" >&2"
  printf '%s\n' "printf '# NOTE: the firmware rewrites this entry when another medium boots; restore with: stage marker $name $bootvar\\n' >&2"
}

#@help __stage_marker2
# @internal arity-2 sibling of 'stage marker': rewrites to the full command
# with the RECORDED value file (fails early when none is recorded)
#@end
__stage_marker2() {
  local name="$1" op="$2" base="$ELEBAKE_BASE"
  local stageid
  stageid=$(resolve_item stage "$name" strict) || {
    printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage marker: unknown stage $name'"; return 0; }
  local rec="$base/.staging/$stageid/marker"
  [ -f "$rec/file" ] || {
    printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage marker $name: no value file recorded (stage marker $name BootXXXX <filepath>)'"; return 0; }
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage marker '$name' '$op' '$(head -n1 "$rec/file")'"
}

# shared generation-time helper (not dispatchable): read the marker record
stage_read_marker() {
  local d="$1"
  [ -f "$d/marker/bootvar" ] || return 1
  bootvar=$(head -n1 "$d/marker/bootvar")
  mfile=$(head -n1 "$d/marker/file")
}



# ___stage_site_mk1 <stage> — measure THIS machine and write the compiled-in
# expectations into <work>/stand/efi/loader/local/site.mk (symmetric to
# trust mk). The batch resolves the target path at generation time and
# delegates with it as DATA: write, then report. Measurement happens in the
# GENERATOR (World as-is: kenv/efivar/sha256 readable in the invoking
# context -- run it under sudo when efivars need it); the emission is one
# concrete heredoc with the digests baked in. Cross-checks against what a
# booted loader measured (kenv loader.trust.bootlock.*) fail the GENERATION
# -- a disagreement is a bug, not noise.
#@help ___stage_site_mk1
# @command stage site mk <stage>
# @summary Measure THIS machine at generation time; write + report the local/site.mk baselines
# @group   provisioning
# @example sudo sh elebake.sh stage site mk smoke1 | sh
# @see     stage marker
#@end
___stage_site_mk1() {
  local name="$1" base="$ELEBAKE_BASE" stageid
  stageid=$(resolve_item stage "$name" strict) || {
    printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage site mk: unknown stage $name'"; return 0; }
  [ -L "$base/.staging/$stageid/work" ] || {
    printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage site mk $name: not checked out (stage checkout $name <ref>)'"; return 0; }
  local f="$base/.staging/$stageid/work/stand/efi/loader/local/site.mk"
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage site mk '$name' '$f'"
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage site mk report '$name' '$f'"
}

#@help _stage_site_mk2
# @internal measure board/keys/marker NOW and emit the <file> write; arity sibling of the site mk batch
#@end
_stage_site_mk2() {
  local name="$1" f="$2" base="$ELEBAKE_BASE"
  local stageid bootvar mfile
  stageid=$(resolve_item stage "$name" strict) || {
    generate_error "stage site mk: unknown stage '$name'"; return 0; }
  local d="$base/.staging/$stageid"
  [ -L "$d/work" ] || {
    generate_error "stage site mk '$name': not checked out (stage checkout $name <ref>)"; return 0; }
  case "$f" in /*) ;; *)
    generate_error "stage site mk: target file must be absolute: '$f'"; return 0 ;;
  esac
  # board identity: first usable smbios value wins -- measured NOW
  local k id='' hb meas
  for k in smbios.system.uuid smbios.planar.serial smbios.system.serial; do
    id=$(kenv "$k" 2>>"$LOG_FILE") || { id=''; continue; }
    board_usable "$id" && break
    id=''
  done
  [ -n "$id" ] || {
    generate_error "stage site mk '$name': no usable board identity in smbios (can this context read kenv?)"; return 0; }
  hb=$(printf '%s' "$id" | sha256 -q)
  meas=$(kenv loader.trust.bootlock.board.sha256 2>>"$LOG_FILE") || meas=''
  [ -z "$meas" ] || [ "$meas" = "$hb" ] || {
    generate_error "stage site mk '$name': board hash disagrees: loader $meas vs here $hb"; return 0; }
  # key store: PK+KEK+db -- measured NOW (needs a context that may read efivars)
  local g=8be4df61-93ca-11d2-aa0d-00e098032b8c dsig=d719b2cb-3d3a-4596-a3bc-dad00e67656f
  local kt hk
  kt=$(mktemp -d) || { generate_error "stage site mk: mktemp failed"; return 0; }
  if efivar --no-name --name "$g-PK" --binary > "$kt/1" 2>>"$LOG_FILE" \
     && efivar --no-name --name "$g-KEK" --binary > "$kt/2" 2>>"$LOG_FILE" \
     && efivar --no-name --name "$dsig-db" --binary > "$kt/3" 2>>"$LOG_FILE" \
     && [ -s "$kt/1" ] && [ -s "$kt/2" ] && [ -s "$kt/3" ]; then
    hk=$(cat "$kt/1" "$kt/2" "$kt/3" | sha256 -q)
  else
    rm -rf "$kt"
    generate_error "stage site mk '$name': cannot read PK/KEK/db (run the GENERATOR in a context that can, e.g. sudo)"
    return 0
  fi
  meas=$(kenv loader.trust.bootlock.keys.sha256 2>>"$LOG_FILE") || meas=''
  [ -z "$meas" ] || [ "$meas" = "$hk" ] || {
    rm -rf "$kt"
    generate_error "stage site mk '$name': key store hash disagrees: loader $meas vs here $hk"; return 0; }
  # boot marker -- uncritical: unreadable/unbound leaves the gate asleep
  local hm='' off opt m
  if stage_read_marker "$d"; then
    if efivar --no-name --name "$g-$bootvar" --binary > "$kt/opt" 2>>"$LOG_FILE" && off=$(optdata_offset "$kt/opt"); then
      opt=$(dd if="$kt/opt" bs=1 skip="$off" 2>>"$LOG_FILE" | tr -d '\000')
      m=${opt##* }
      [ -n "$m" ] && [ "$m" != RC ] && hm=$(printf '%s' "$m" | sha256 -q)
    fi
  fi
  # load origin -- uncritical like the marker: the ESP partition GUID of
  # the CURRENT boot entry (efibootmgr -v, HD(..,GPT,<guid>,..) of
  # BootCurrent). The loader's measure_origin hashes the SAME canonical
  # lowercase text; unreadable/absent leaves the origin gate asleep.
  local ho='' bootcur oline
  if bootcur=$(efibootmgr -v 2>>"$LOG_FILE" | sed -n 's/^ *BootCurrent: *//p' | head -1)      && [ -n "$bootcur" ]; then
    oline=$(efibootmgr -v 2>>"$LOG_FILE" | grep -A3 "^[ +*]*Boot${bootcur}[^0-9]" | grep -o 'GPT,[0-9a-fA-F-]*' | head -1)
    if [ -n "$oline" ]; then
      ho=$(printf '%s' "${oline#GPT,}" | tr 'A-F' 'a-f' | sha256 -q)
    fi
  fi
  rm -rf "$kt"
  # emission: the exact file, digests baked in (only the hash of the marker
  # value ever reaches the trace, never the value)
  local owner fdir
  owner=$(stat -f %Su "$d" 2>>"$LOG_FILE")
  fdir=${f%/*}
  emit_note "elebake stage site mk '$name' (measured at generation time)"
  printf '%s\n' "$MODIFY_DIR_CREATE '$fdir'"
  printf '%s\n' "cat > '$f' <<'ELVEOF'"
  printf '%s\n' "# Generated by elebake -- this machine trust expectations."
  printf '%s\n' "# Not tracked in git: the values are site fingerprints, not source."
  printf '%s\n' "# Pulled in by stand/efi/loader/Makefile via .-include local/site.mk."
  printf '%s\n' "CFLAGS.foundation.c += -DLOADER_TRUST_BOARD_DIGEST='$(hex_to_bytes "$hb")'"
  printf '%s\n' "CFLAGS.foundation.c += -DLOADER_TRUST_KEYS_DIGEST='$(hex_to_bytes "$hk")'"
  if [ -n "$hm" ]; then
    printf '%s\n' "CFLAGS.foundation.c += -DLOADER_TRUST_MARKER_DIGEST='$(hex_to_bytes "$hm")'"
    printf '%s\n' "CFLAGS.measurement.c += -DLOADER_TRUST_MARKER_DIGEST='$(hex_to_bytes "$hm")'"
  fi
  if [ -n "$ho" ]; then
    printf '%s\n' "CFLAGS.foundation.c += -DLOADER_TRUST_ORIGIN_DIGEST='$(hex_to_bytes "$ho")'"
  fi
  printf '%s\n' "ELVEOF"
  printf '%s\n' "chown '$owner' '$f' 2>/dev/null || true"
  if [ -z "$hm" ]; then
    printf '%s\n' "printf '# note: no boot marker bound/readable -- BootMarker stays asleep (stage marker, then re-run site mk)\\n' >&2"
  fi
  if [ -z "$ho" ]; then
    printf '%s\n' "printf '# note: boot origin not readable (efibootmgr) -- LoadOrigin stays asleep\\n' >&2"
  fi
  printf '%s\n' "printf '# site.mk written for stage %s -- rebuild + sign + deploy to arm it\\n' '$name' >&2"
}

#@help _stage_site_mk_report1
# @command stage site mk report <stage>
# @summary Show the stage's written site.mk (comment lines; the batch shows it after measuring)
# @group   stage
#@end
_stage_site_mk_report1() {
  local name="$1" loc
  loc=$(catalog_dir "$name") || {
    generate_error "stage site mk report: no worktree (stage checkout $name <ref> first)"; return 0; }
  _stage_site_mk_report2 "$name" "$loc/site.mk"
}

#@help _stage_site_mk_report2
# @internal 2-arg batch building block: the written site.mk at an explicit path
#@end
_stage_site_mk_report2() {
  local name="$1" f="$2" line
  [ -f "$f" ] || {
    generate_error "stage site mk report '$name': no site.mk at $f (stage site mk first)"; return 0; }
  printf '%s\n' "# site.mk of stage '$name' ($f):"
  while IFS= read -r line; do
    printf '# %s\n' "$line"
  done < "$f"
}


#-----------------------------------------------------------------------------
# dump & import — database migration (the stage side of 'elebake dump')
#-----------------------------------------------------------------------------
# THE LOGIC LIVES IN THE DUMP (JB): the dump knows the SOURCE database and
# unrolls it, version-aware, into the commands that reproduce each stage in a
# TARGET database. Wherever a CLI command already describes the state, the
# dump emits a replay of it (add, sign-key, filter, device, boot tree); only
# what no command can reproduce is moved as a BASE ELEMENT — directories
# first, then one logic-free 'stage import' line per file/symlink. Build
# artifacts (obj/, destdir/) are not moved at all: the dump closes each
# stage with the idempotent commands that regenerate them.
#
# Cascade (batch combinators; arities 0/1 EXECUTE on the source, the
# cat-pinned BUILDING BLOCKS below emit the dump TEXT):
#   ___stage_dump0            one 'stage dump <stage>' per stage
#   ___stage_dump1 <stage>    check stage, then the parts present in the
#                             source: dump record (always), dump marker,
#                             dump backup, dump boot, dump rebuild
# Paths go through the stage/<name> symlink (the link IS the resolution);
# stage existence is check stage's job — no inline resolve anywhere here.

#@help ___stage_dump0
# @command stage dump [<stage>]
# @summary Emit the dump of all stages (or one) as replayable elebake commands — per stage: check stage, then the cat-pinned building blocks dump record/dump marker/dump backup/dump boot/dump rebuild
# @group   stage
# @returns elebake commands; arities 0/1 unroll ON THE SOURCE, the building
# @returns blocks are cat-pinned so their lines become dump TEXT for 'restore'
# @example elebake dump > backup.sh
# @example elebake stage dump smoke1
# @see     stage import
# @see     dump
#@end
___stage_dump0() {
  local base="$ELEBAKE_BASE" l n=0
  for l in "$base"/stage/*; do
    [ -L "$l" ] || continue
    n=$((n+1))
    printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage dump '$(basename "$l")'"
  done
  [ "$n" -gt 0 ] || printf '%s\n' "# (no stages to dump)"
}

#@help ___stage_dump1
# @internal arity-1 of 'stage dump': the UNCONDITIONAL building-block
# sequence — check stage, then every block; each block inspects its part of
# the World itself and stays silent when absent
#@end
___stage_dump1() {
  local name="$1"
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$name'"
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage dump record '$name'"
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage dump marker '$name'"
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage dump backup '$name'"
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage dump boot '$name'"
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage dump rebuild '$name'"
}

# dump_import_line <stage> <subdir> <absfile> — generation-time helper: emit
# one base-element import line of the dump text. The existence check lives
# HERE (JB): callers state the element UNCONDITIONALLY, an absent source
# simply emits nothing.
dump_import_line() {
  { [ -f "$3" ] || [ -L "$3" ]; } || return 0
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage import '$1' '$2' '$3'"
}

# The record helpers follow the same pattern: called unconditionally, each
# inspects its part of the World itself and stays silent when absent.

# dump_filter_lines <stage> <dir> — one 'stage filter +' replay per entry
dump_filter_lines() {
  local name="$1" d="$2" f
  [ -s "$d/filter" ] || return 0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage filter add '$name' '$f'"
  done < "$d/filter"
}

# dump_keybinding_lines <stage> <dir> — replay sign-/attest-key bindings
# (link target is ../../<backend>/<key>)
dump_keybinding_lines() {
  local name="$1" d="$2" slot target
  for slot in sign-key attest-key; do
    [ -L "$d/$slot" ] || continue
    target=$(readlink "$d/$slot")
    # canonical multi-word command form (the slot FILE keeps its hyphen)
    printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage $(printf '%s' "$slot" | tr '-' ' ') '$name' '$(basename "$(dirname "$target")")' '$(basename "$target")'"
  done
}

# dump_media_lines <stage> <dir> — replay device/boot tree per medium record
dump_media_lines() {
  local name="$1" d="$2" m
  for m in "$d"/media/*/; do
    [ -d "$m" ] || continue
    m=$(basename "$m")
    stage_read_medium "$d" "$m" && \
      printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage device '$name' '$m' '$node' '$mnt'"
    stage_read_boottree "$d" "$m" && \
      printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage boot tree '$name' '$m' '$label' '$ds'"
  done
  return 0
}

# dump_work_lines <stage> <dir> — the work symlink as base element, with the
# re-anchor note
dump_work_lines() {
  local name="$1" d="$2"
  [ -L "$d/work" ] || return 0
  emit_note "work symlink still points into THIS source tree; re-anchor"
  emit_note "later with: stage checkout $name \$(cat checkout) (new worktree)"
  dump_import_line "$name" "." "$d/work"
}

# dump_phase_lines <stage> <dir> — generation-time helper: one check-free
# append replay per phase binding (the checks ran at the original binding;
# foundation check re-verifies before emission — a dump must restore even
# when the worktree is gone)
dump_phase_lines() {
  local name="$1" d="$2" f p
  for f in "$d"/phases/*; do
    [ -f "$f" ] || continue
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage phase policy append '$name' '$(basename "$f")' '$p'"
    done < "$f"
  done
  return 0
}

# dump_prereqs_lines <stage> <dir> — replay the per-stage prerequisites
# lists as idempotent adds
dump_prereqs_lines() {
  local name="$1" d="$2" kind p
  for kind in exist verify; do
    [ -s "$d/prereqs/$kind" ] || continue
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage prerequisites $kind add '$name' '$p'"
    done < "$d/prereqs/$kind"
  done
  return 0
}

# stage_dump_tree_lines <stage> <part> — generation-time helper shared by
# dump backup/dump boot: STRUCTURE FIRST (every directory, find walks top-down
# so parents precede children), then one import line per file or symlink.
stage_dump_tree_lines() {
  local name="$1" part="$2" d="$ELEBAKE_BASE/stage/$1" f target
  find "$d/$part" -type d 2>/dev/null | while IFS= read -r f; do
    printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage import '$name' '${f#"$d/"}'"
  done
  find "$d/$part" \( -type f -o -type l \) 2>/dev/null | while IFS= read -r f; do
    target=$(dirname "${f#"$d/"}")
    dump_import_line "$name" "$target" "$f"
  done
}

#@help ___stage_dump_record1
# @internal building block of 'stage dump' (cat-pinned): the record part —
# stage add + CLI replays (filter, key bindings, device/boot tree) + the
# work/checkout base elements
#@end
___stage_dump_record1() {
  local name="$1" d="$ELEBAKE_BASE/stage/$1"
  printf '%s\n' "# stage '$name' <- $d"
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage add '$name'"
  dump_import_line     "$name" "." "$d/metadata"
  dump_filter_lines     "$name" "$d"
  dump_keybinding_lines "$name" "$d"
  dump_media_lines      "$name" "$d"
  dump_import_line     "$name" "." "$d/checkout"
  dump_work_lines       "$name" "$d"
  dump_phase_lines      "$name" "$d"
  dump_prereqs_lines    "$name" "$d"
}

#@help ___stage_dump_marker1
# @internal building block of 'stage dump' (cat-pinned): the marker records
# as base elements (never a 'stage marker' replay — that would write NVRAM)
#@end
___stage_dump_marker1() {
  local name="$1" d="$ELEBAKE_BASE/stage/$1" f
  [ -d "$d/marker" ] || return 0
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage import '$name' 'marker'"
  for f in "$d"/marker/*; do
    dump_import_line "$name" "marker" "$f"
  done
  return 0
}

#@help ___stage_dump_backup1
# @internal building block of 'stage dump' (cat-pinned): the backup/ tree,
# structure first, then one base element per file
#@end
___stage_dump_backup1() {
  stage_dump_tree_lines "$1" backup
}

#@help ___stage_dump_boot1
# @internal building block of 'stage dump' (cat-pinned): the boot/ tree,
# structure first, then one base element per file or symlink
#@end
___stage_dump_boot1() {
  stage_dump_tree_lines "$1" boot
}

#@help ___stage_dump_rebuild1
# @internal building block of 'stage dump' (cat-pinned): close the stage —
# idempotent regeneration of what the dump does not move (obj/ via build,
# destdir/ via install); pins and STAND_*_SUBDIRS arrive with the prologue
#@end
___stage_dump_rebuild1() {
  local name="$1" d="$ELEBAKE_BASE/stage/$1"
  { [ -n "$(ls -A "$d/obj" 2>/dev/null)" ] || [ -n "$(ls -A "$d/destdir" 2>/dev/null)" ]; } || return 0
  printf '%s\n' "# rebuild of stage '$name' (artifacts are not moved)"
  [ -n "$(ls -A "$d/obj" 2>/dev/null)" ] && \
    printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage build '$name'"
  [ -n "$(ls -A "$d/destdir" 2>/dev/null)" ] && \
    printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage install '$name'"
  return 0
}


# --- the import cascade (JB): the batch combinators are an UNCONDITIONAL
# sequence of commands -- what a function emits is visible at a glance.
# Checking is itself a COMMAND in the sequence (check*, then import*); the
# batch machinery owns stop-at-first-failure, so a failed check stops the
# run before the import acts. Terminals resolve and validate for themselves
# (generate_error, fail early) like every other stage terminal.

# import_rel <path> [dot] — is <path> a valid record-relative path?
# ('.' only accepted with the dot flag: file targets may hit the record
# root, a directory declaration may not)
import_rel() {
  case "$1" in
    .) [ "${2:-}" = "dot" ] ;;
    ""|/*|*..*|*[!A-Za-z0-9_./-]*) return 1 ;;
    *) return 0 ;;
  esac
}

#@help ___stage_import2
# @internal arity-2 of 'stage import': declare ONE directory of the record
# tree — unconditional sequence: check dir, import dir
#@end
___stage_import2() {
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check dir '$1' '$2'"
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage import dir '$1' '$2'"
}

#@help ___stage_import3
# @command stage import <stage> <reldir> [<absfile>]
# @summary Import ONE base element from another database: two args declare a record-tree DIRECTORY, three copy a file/symlink into it — an unconditional check-then-act sequence; the logic lives in the dump that emits these lines
# @group   stage
# @param   reldir   record-relative target ('.' for the record root on the file form); a directory must be declared (2-arg form) before files land in it
# @param   absfile  absolute source path in the OTHER database (file form only)
# @example elebake stage import smoke1 boot/dtb/overlays
# @example elebake stage import smoke1 marker /home/brj/.elvboot/current/.staging/stage-0a1b2c/marker/bootvar
# @see     stage dump
# @see     restore
#@end
___stage_import3() {
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check file '$1' '$2' '$3'"
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage import file '$1' '$2' '$3'"
}

#@help _stage_check_stage1
# @internal check terminal: does the stage exist? First line of every
# import sequence — a failed check stops the batch before anything acts
#@end
_stage_check_stage1() {
  local name="$1"
  resolve_item stage "$name" strict >/dev/null || {
    generate_error "stage import: unknown stage '$name'"; return 0; }
}

#@help _stage_check_dir2
# @internal check terminal of 'stage import <stage> <reldir>': path is
# record-relative (stage existence is check stage's job) — a failed check
# stops the batch before import dir
#@end
_stage_check_dir2() {
  local name="$1" reldir="$2"
  import_rel "$reldir" || {
    generate_error "stage import: invalid directory '$reldir' (record-relative, no ..)"; return 0; }
}

#@help _stage_import_dir2
# @internal act terminal of 'stage import <stage> <reldir>': the bloody
# detail — mkdir + mode via the stage/<name> symlink (the link IS the
# resolution; checked by the preceding check stage/check dir)
#@end
_stage_import_dir2() {
  local name="$1" reldir="$2" base="$ELEBAKE_BASE"
  printf '%s\n' "$MODIFY_DIR_CREATE '$base/stage/$name/$reldir'"
  printf '%s\n' "$MODIFY_FILE_PERMS 0700 '$base/stage/$name/$reldir'"
}

#@help _stage_check_file3
# @internal check terminal of 'stage import <stage> <subdir> <absfile>':
# subdir valid and DECLARED, source is an existing file or symlink — a
# failed check stops the batch before import file. Paths go through the
# stage/<name> symlink (the link IS the resolution); stage existence is
# check stage's job.
#@end
_stage_check_file3() {
  local name="$1" subdir="$2" src="$3" base="$ELEBAKE_BASE"
  import_rel "$subdir" dot || {
    generate_error "stage import: invalid subdir '$subdir' (record-relative, no ..)"; return 0; }
  case "$src" in /*) ;; *)
    generate_error "stage import: source must be absolute: '$src'"; return 0 ;;
  esac
  { [ -e "$src" ] || [ -L "$src" ]; } || {
    generate_error "stage import: no such base element: $src"; return 0; }
  if [ -d "$src" ] && [ ! -L "$src" ]; then
    generate_error "stage import: '$src' is a directory (use: stage import $name <reldir>)"; return 0
  fi
  # No implicit directory creation anywhere: the target must have been
  # declared (2-arg form) before. In a replayed dump the declaring lines ran
  # earlier in the same batch, so this generation-time check sees them.
  [ -d "$base/stage/$name/$subdir" ] || {
    generate_error "stage import: target dir missing: stage/$name/$subdir (check stage + declare first)"; return 0; }
}

#@help _stage_import_file3
# @internal act terminal of 'stage import <stage> <subdir> <absfile>': the
# bloody detail — cp via the stage/<name> symlink (the link IS the
# resolution; checked by the preceding check stage/check file)
#@end
_stage_import_file3() {
  local name="$1" subdir="$2" src="$3" base="$ELEBAKE_BASE"
  # IDEMPOTENT: rm -f first (a bare cp would write THROUGH an existing
  # symlink target instead of replacing the link). -P moves a symlink as a
  # link, -p preserves mode/time of a file.
  printf '%s\n' "rm -f '$base/stage/$name/$subdir/$(basename "$src")' && cp -Pp '$src' '$base/stage/$name/$subdir/' || { printf '# Error: import of %s failed\\n' '$src' >&2; exit 1; }"
}

#-----------------------------------------------------------------------------
# foundation catalogs — READ-ONLY views of what the patch series offers
#-----------------------------------------------------------------------------
# Catalogs come from the World, records hold only decisions (design v3):
# measurements, diagnoses, actions, whens and phases are C facts in the
# stage's WORKTREE headers — parsed at generation time, never cached,
# never duplicated into records. Provenance (the checkout ref) is shown so
# a catalog is always attributable to a patch state. No checkout -> fail
# early. All four are display terminals (cat-pinned).

# catalog_dir <stage> — generation-time helper: echo the local/ header dir
# of the stage's worktree, fail when not checked out.
catalog_dir() {
  local d="$ELEBAKE_BASE/stage/$1"
  [ -L "$d/work" ] && [ -d "$d/work/stand/efi/loader/local" ] || return 1
  printf '%s\n' "$d/work/stand/efi/loader/local"
}

# catalog_header <stage> <title> — provenance line for every catalog
catalog_header() {
  local ref="-"
  [ -f "$ELEBAKE_BASE/stage/$1/checkout" ] && ref=$(head -1 "$ELEBAKE_BASE/stage/$1/checkout")
  printf '# %s of stage '%s' (checkout: %s)\n' "$2" "$1" "$ref"
}

#@help _stage_measure1
# @command stage measure <stage>
# @summary List the measurement (and diagnose) functions the stage's checkout offers — the catalog claims may reference; new offers are C patches, not elebake input
# @group   foundation
# @example elebake stage measure smoke1
# @see     stage phase show
#@end
_stage_measure1() {
  local name="$1" loc
  loc=$(catalog_dir "$name") || {
    generate_error "stage measure: no worktree (stage checkout $name <ref> first)"; return 0; }
  catalog_header "$name" "measurement catalog"
  grep -h 'struct measurement[[:space:]]*measure_' "$loc/measurement.h" \
    | sed 's/.*\(measure_[a-z_0-9]*\)(.*/#   \1/'
  printf '#\n# diagnose functions (optional claim field):\n'
  grep -h 'void[[:space:]]*diagnose_' "$loc/measurement.h" \
    | sed 's/.*\(diagnose_[a-z_0-9]*\)(.*/#   \1/'
}

#@help _stage_action1
# @command stage action <stage>
# @summary List the actions the stage's checkout offers (policy FIRE targets)
# @group   foundation
# @example elebake stage action smoke1
# @see     stage phase show
#@end
_stage_action1() {
  local name="$1" loc
  loc=$(catalog_dir "$name") || {
    generate_error "stage action: no worktree (stage checkout $name <ref> first)"; return 0; }
  catalog_header "$name" "action catalog"
  grep -h 'extern const struct action' "$loc/action.h" \
    | sed 's/.*struct action[[:space:]]*\([a-z_0-9]*_act\);.*/#   \1/'
}

#@help _stage_when1
# @command stage when <stage>
# @summary List the firing predicates the stage's checkout offers
# @group   foundation
# @example elebake stage when smoke1
# @see     stage phase show
#@end
_stage_when1() {
  local name="$1" loc
  loc=$(catalog_dir "$name") || {
    generate_error "stage when: no worktree (stage checkout $name <ref> first)"; return 0; }
  catalog_header "$name" "when catalog"
  grep -h '^bool[[:space:]]*when_' "$loc/policy.h" \
    | sed 's/.*\(when_[a-z_0-9]*\)(.*/#   \1/'
}

# enum_phases <loc> — generation-time: the checkout's enum phase members,
# in declaration order
enum_phases() {
  sed -n '/enum phase {/,/};/p' "$1/policy.h" | grep -o 'PHASE_[A-Z_]*'
}

# phase_in_catalog <stage> <phase> — generation-time: is <phase> a member of
# the checkout's enum phase? (catalog_dir must have succeeded before)
phase_in_catalog() {
  local loc
  loc=$(catalog_dir "$1") || return 1
  enum_phases "$loc" | grep -qx "$2"
}

#@help _stage_phase_show1
# @command stage phase show <stage> [<phase>]
# @summary List the phases the stage's checkout offers, each with its BOUND policies (records); one phase in detail with the 2-arg form
# @group   foundation
# @example elebake stage phase show smoke1
# @see     stage phase policy add
#@end
_stage_phase_show1() {
  local name="$1" loc ph
  loc=$(catalog_dir "$name") || {
    generate_error "stage phase show: no worktree (stage checkout $name <ref> first)"; return 0; }
  catalog_header "$name" "phase catalog"
  for ph in $(enum_phases "$loc"); do
    printf '#   %s\n' "$ph"
    if [ -s "$ELEBAKE_BASE/stage/$name/phases/$ph" ]; then
      sed 's/^/#       policy: /' "$ELEBAKE_BASE/stage/$name/phases/$ph"
    else
      printf '#       (no policies bound)\n'
    fi
  done
}

#@help _stage_phase_show2
# @internal 2-arg sibling of 'stage phase show': ONE phase in detail — the
# bound policy names AND the <phase>_policies[] table exactly as the
# emission writes it (show renders what emission WOULD produce)
#@end
_stage_phase_show2() {
  local name="$1" ph="$2" loc lower p
  loc=$(catalog_dir "$name") || {
    generate_error "stage phase show: no worktree (stage checkout $name <ref> first)"; return 0; }
  phase_in_catalog "$name" "$ph" || {
    generate_error "stage phase show: unknown phase '$ph' (stage phase show $name lists them)"; return 0; }
  catalog_header "$name" "phase $ph"
  if [ -s "$ELEBAKE_BASE/stage/$name/phases/$ph" ]; then
    sed 's/^/#   policy: /' "$ELEBAKE_BASE/stage/$name/phases/$ph"
  else
    printf '#   (no policies bound)\n'
  fi
  lower=$(printf '%s' "${ph#PHASE_}" | tr '[:upper:]' '[:lower:]')
  printf '#\n# static const struct policy %s_policies[] = {\n' "$lower"
  if [ -s "$ELEBAKE_BASE/stage/$name/phases/$ph" ]; then
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      fnd_render_policy_c "$ELEBAKE_BASE" "$p" | sed 's/^/# /'
    done < "$ELEBAKE_BASE/stage/$name/phases/$ph"
  fi
  printf '# \tPOLICY_END,\n# };\n'
}

#-----------------------------------------------------------------------------
# phase policy binding — the BINDING is the contract
#-----------------------------------------------------------------------------
# The arsenal (foundation.sh) is DB-wide and dumb; binding a policy to a
# stage's phase is where the transitive chain is validated against the
# catalog of THAT stage's checkout. Check-then-act as an unconditional
# batch sequence (like the import cascade): check stage -> check policy ->
# append. The append terminal is check-free and idempotent — dumps replay
# it directly (the checks ran at the original binding; foundation check
# re-verifies before emission).

#@help ___stage_phase_policy_add3
# @command stage phase policy add <stage> <phase> <policy> [<position>]
# @summary Bind a policy to a stage's phase — validates the policy's transitive chain (gate, claims, expectations, triggers, whens, actions) against the checkout's catalog, then appends; 4-arg form inserts at a 1-based position
# @group   foundation
# @example elebake stage phase policy add smoke1 PHASE_LOADER watch-strict
# @see     stage phase show
# @see     stage phase policy drop
#@end
___stage_phase_policy_add3() {
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check policy '$1' '$2' '$3'"
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage phase policy append '$1' '$2' '$3'"
}

#@help ___stage_phase_policy_add4
# @internal 4-arg sibling of 'stage phase policy add': insert at a 1-based
# position among the phase's policy lines
#@end
___stage_phase_policy_add4() {
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check policy '$1' '$2' '$3'"
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage phase policy append '$1' '$2' '$3' '$4'"
}

# check_policy_chain <loc> <policy> — generation-time: validate the
# TRANSITIVE chain of <policy> (gate -> claims -> expectations -> macro
# records; triggers -> whens/actions) for internal completeness AND
# membership in the catalog at <loc>. Prints the failure on stdout and
# returns non-zero; silent on success. Shared by the binding check and
# 'stage foundation check'.
check_policy_chain() {
  local loc="$1" policy="$2" base="$ELEBAKE_BASE"
  local gate c line measurement diagnose publish exp when action etype elabel evalue
  [ -f "$base/foundation/policies/$policy" ] || {
    printf "no such policy '%s' (policy add first)\n" "$policy"; return 1; }
  gate=$(sed -n 's/^gate //p' "$base/foundation/policies/$policy" | head -1)
  [ -d "$base/foundation/gates/$gate" ] || {
    printf "policy '%s' references undefined gate '%s'\n" "$policy" "$gate"; return 1; }
  while IFS= read -r c; do
    [ -n "$c" ] || continue
    [ -f "$base/foundation/claims/$c" ] || {
      printf "gate '%s' references undefined claim '%s'\n" "$gate" "$c"; return 1; }
    read -r measurement diagnose publish exp < "$base/foundation/claims/$c"
    grep -q "struct measurement[[:space:]]*$measurement(" "$loc/measurement.h" || {
      printf "claim '%s': measurement '%s' not in this checkout's catalog\n" "$c" "$measurement"; return 1; }
    if [ "$diagnose" != "-" ]; then
      grep -q "void[[:space:]]*$diagnose(" "$loc/measurement.h" || {
        printf "claim '%s': diagnose '%s' not in this checkout's catalog\n" "$c" "$diagnose"; return 1; }
    fi
    [ -f "$base/foundation/expectations/$exp" ] || {
      printf "claim '%s' references undefined expectation '%s'\n" "$c" "$exp"; return 1; }
    read -r etype elabel evalue < "$base/foundation/expectations/$exp"
    if [ "$etype" = "macro" ]; then
      fnd_macro_record_for "$base" "$evalue" > /dev/null || {
        printf "expectation '%s': no macro record defines '%s' (macro add first)\n" "$exp" "$evalue"; return 1; }
    fi
  done < "$base/foundation/gates/$gate/claims"
  for line in $(sed -n 's/^trigger //p' "$base/foundation/policies/$policy"); do
    [ -f "$base/foundation/triggers/$line" ] || {
      printf "policy '%s' references undefined trigger '%s'\n" "$policy" "$line"; return 1; }
    read -r when action < "$base/foundation/triggers/$line"
    grep -q "^bool[[:space:]]*$when(" "$loc/policy.h" || {
      printf "trigger '%s': when '%s' not in this checkout's catalog\n" "$line" "$when"; return 1; }
    grep -q "extern const struct action[[:space:]]*$action;" "$loc/action.h" || {
      printf "trigger '%s': action '%s' not in this checkout's catalog\n" "$line" "$action"; return 1; }
  done
  return 0
}

#@help _stage_check_policy3
# @internal check terminal of 'stage phase policy add': phase in the enum,
# then the transitive chain via check_policy_chain against the checkout's
# catalog. Silent on success; a failure stops the batch before the append
# acts. Stage existence is check stage's job.
#@end
_stage_check_policy3() {
  local name="$1" ph="$2" policy="$3" loc msg
  loc=$(catalog_dir "$name") || {
    generate_error "stage check policy: no worktree (stage checkout $name <ref> first)"; return 0; }
  phase_in_catalog "$name" "$ph" || {
    generate_error "stage check policy: unknown phase '$ph' (stage phase show $name lists them)"; return 0; }
  msg=$(check_policy_chain "$loc" "$policy") || {
    generate_error "stage check policy: $msg"; return 0; }
}

#@help _stage_phase_policy_append3
# @internal act terminal of 'stage phase policy add': the bloody detail —
# check-free, idempotent append of the policy NAME to phases/<PHASE> (dumps
# replay this line directly; the checks ran at the original binding)
#@end
_stage_phase_policy_append3() {
  local name="$1" ph="$2" policy="$3" d="$ELEBAKE_BASE/stage/$1"
  printf '%s\n' "$MODIFY_DIR_CREATE '$d/phases'"
  printf '%s\n' "grep -qxF '$policy' '$d/phases/$ph' 2>/dev/null || printf '%s\\n' '$policy' >> '$d/phases/$ph'"
  emit_note "stage '$name': policy '$policy' bound to $ph"
}

#@help _stage_phase_policy_append4
# @internal 4-arg act sibling: insert at a 1-based position. Position and
# duplicate are validated at generation time (a duplicate binding has no
# meaning — the gate would just fire twice; the NAME stays the address).
#@end
_stage_phase_policy_append4() {
  local name="$1" ph="$2" policy="$3" pos="$4" d="$ELEBAKE_BASE/stage/$1" f n
  f="$d/phases/$ph"
  grep -qxF "$policy" "$f" 2>/dev/null && {
    generate_error "stage phase policy: '$policy' already bound to $ph (position is placement, not a move — drop first)"; return 0; }
  n=$(grep -c '' "$f" 2>/dev/null || true)
  [ -n "$n" ] || n=0
  line_pos_ok "$pos" "$n" || {
    generate_error "stage phase policy: position '$pos' out of range (1..$((n + 1)))"; return 0; }
  printf '%s\n' "$MODIFY_DIR_CREATE '$d/phases'"
  if [ -f "$f" ]; then
    line_insert_emit "$f" "$pos" "$policy"
  else
    printf '%s\n' "printf '%s\\n' '$policy' >> '$f'"
  fi
  emit_note "stage '$name': policy '$policy' bound to $ph at $pos"
}

#@help _stage_phase_policy_drop3
# @command stage phase policy drop <stage> <phase> <policy>
# @summary Unbind a policy from a stage's phase (the policy itself survives)
# @group   foundation
#@end
_stage_phase_policy_drop3() {
  local name="$1" ph="$2" policy="$3" d="$ELEBAKE_BASE/stage/$1" f
  resolve_item stage "$name" strict >/dev/null || {
    generate_error "stage phase policy drop: unknown stage '$name'"; return 0; }
  f="$d/phases/$ph"
  grep -qxF "$policy" "$f" 2>/dev/null || {
    generate_error "stage phase policy drop: '$policy' not bound to $ph"; return 0; }
  printf '%s\n' "grep -vxF '$policy' '$f' > '$f.new'; mv '$f.new' '$f'"
  emit_note "stage '$name': policy '$policy' unbound from $ph"
}

#-----------------------------------------------------------------------------
# foundation emission — foundation.c is GENERATED-ONLY (design §4)
#-----------------------------------------------------------------------------
# The emitter renders ONLY what the stage's bindings transitively reference:
# macro blocks (sorted by name), gate secret blocks (gate first-seen order),
# GATE_DEFINEs (first-seen), one <phase>_policies[] table per enum phase
# (bound phases carry their policies, unbound ones just POLICY_END) and the
# phase_policies() switch (fallback: the last enum phase's table). The
# acceptance baseline is STRUCTURAL equality with the hand-written file
# after comment stripping; the prose moved to policy.h (patch series).

# foundation_bound_policies <stage> <loc> — the bound policies in enum-phase
# order, first-seen deduplicated
foundation_bound_policies() {
  local name="$1" loc="$2" d="$ELEBAKE_BASE/stage/$1" ph p policies=""
  for ph in $(enum_phases "$loc"); do
    [ -s "$d/phases/$ph" ] || continue
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      case " $policies " in *" $p "*) ;; *) policies="$policies $p" ;; esac
    done < "$d/phases/$ph"
  done
  printf '%s\n' "$policies"
}

# foundation_gates_of <policies...> — their gates, first-seen deduplicated
foundation_gates_of() {
  local base="$ELEBAKE_BASE" p g gates=""
  for p in "$@"; do
    g=$(sed -n 's/^gate //p' "$base/foundation/policies/$p" | head -1)
    case " $gates " in *" $g "*) ;; *) gates="$gates $g" ;; esac
  done
  printf '%s\n' "$gates"
}

# foundation_macros_of <gates...> — the macro RECORDS the gates' claims
# reference (via macro expectations), sorted by name
foundation_macros_of() {
  local base="$ELEBAKE_BASE" g c measurement diagnose publish exp
  local etype elabel evalue rec
  for g in "$@"; do
    while IFS= read -r c; do
      [ -n "$c" ] && [ -f "$base/foundation/claims/$c" ] || continue
      read -r measurement diagnose publish exp < "$base/foundation/claims/$c"
      [ -f "$base/foundation/expectations/$exp" ] || continue
      read -r etype elabel evalue < "$base/foundation/expectations/$exp"
      [ "$etype" = "macro" ] || continue
      rec=$(fnd_macro_record_for "$base" "$evalue") || continue
      printf '%s\n' "$rec"
    done < "$base/foundation/gates/$g/claims"
  done | sort -u
}

# render_foundation_c <stage> — generation-time: the complete generated
# foundation.c on stdout (catalog_dir must have succeeded before)
render_foundation_c() {
  local name="$1" base="$ELEBAKE_BASE" d="$ELEBAKE_BASE/stage/$1" loc
  local policies gates macros ph p g m last_ph lower
  loc=$(catalog_dir "$name") || return 1
  policies=$(foundation_bound_policies "$name" "$loc")
  gates=$(foundation_gates_of $policies)
  macros=$(foundation_macros_of $gates)
  # Provenance, DETERMINISTIC only: a timestamp would break the
  # regenerate-identically guarantee; the checkout ref and the worktree's
  # HEAD pin the source state, the stage name survives migration.
  local ref="-" head spdx="${ELEBAKE_SPDX:-}" copyright="${ELEBAKE_COPYRIGHT:-}"
  [ -f "$ELEBAKE_BASE/stage/$name/checkout" ] && ref=$(head -1 "$ELEBAKE_BASE/stage/$name/checkout")
  head=$(git -C "$loc" rev-parse --short HEAD 2>/dev/null) || head=unknown
  if [ -n "$spdx" ] || [ -n "$copyright" ]; then
    printf '/*-\n'
    [ -n "$spdx" ] && printf ' * SPDX-License-Identifier: %s\n' "$spdx"
    [ -n "$spdx" ] && [ -n "$copyright" ] && printf ' *\n'
    [ -n "$copyright" ] && printf ' * Copyright (c) %s\n' "$copyright"
    printf ' */\n\n'
  fi
  printf '/* generated by elebake stage foundation make -- do not edit\n'
  printf ' * stage: %s  checkout: %s (%s) */\n\n' "$name" "$ref" "$head"
  printf '#include "measurement.h"\n'
  printf '#include "claim.h"\n'
  printf '#include "policy.h"\n'
  for m in $macros; do
    printf '\n'
    fnd_render_macro "$base" "$m"
  done
  for g in $gates; do
    [ -f "$base/foundation/gates/$g/secret" ] || continue
    printf '\n'
    fnd_render_secret_block "$base" "$g"
  done
  # prerequisites arrays: emitted exactly when the checkout EXPECTS them
  # (extern declarations in measurement.h — the catalog decides, old
  # checkouts keep their internal arrays and get nothing here). The
  # DECISIONS come from the per-stage lists; empty lists are legal (N=0,
  # the claims skip nothing and count nothing).
  if grep -q 'extern const char \*const[[:space:]]*prerequisites_exist' "$loc/measurement.h" 2>/dev/null; then
    local kind pf n entry
    for kind in exist verify; do
      pf="$ELEBAKE_BASE/stage/$name/prereqs/$kind"
      n=0
      [ -f "$pf" ] && n=$(grep -c . "$pf")
      printf '\n#define\tLOADER_PREREQUISITES_%s_N\t%s\n' "$(printf '%s' "$kind" | tr '[:lower:]' '[:upper:]')" "$n"
      printf 'const char *const prerequisites_%s[] = {\n' "$kind"
      if [ "$n" -gt 0 ]; then
        while IFS= read -r entry; do
          [ -n "$entry" ] || continue
          printf '\t"%s",\n' "$entry"
        done < "$pf"
      fi
      printf '\tNULL\n};\n'
      printf 'const unsigned int prerequisites_%s_n = LOADER_PREREQUISITES_%s_N;\n' "$kind" "$(printf '%s' "$kind" | tr '[:lower:]' '[:upper:]')"
    done
  fi
  for g in $gates; do
    printf '\n'
    fnd_render_gate_c "$base" "$g"
  done
  last_ph=""
  for ph in $(enum_phases "$loc"); do
    last_ph="$ph"
    lower=$(printf '%s' "${ph#PHASE_}" | tr '[:upper:]' '[:lower:]')
    printf '\nstatic const struct policy %s_policies[] = {\n' "$lower"
    if [ -s "$d/phases/$ph" ]; then
      while IFS= read -r p; do
        [ -n "$p" ] || continue
        fnd_render_policy_c "$base" "$p"
      done < "$d/phases/$ph"
    fi
    printf '\tPOLICY_END,\n};\n'
  done
  printf '\nconst struct policy *\nphase_policies(enum phase ph)\n{\n'
  printf '\tswitch (ph) {\n'
  for ph in $(enum_phases "$loc"); do
    lower=$(printf '%s' "${ph#PHASE_}" | tr '[:upper:]' '[:lower:]')
    printf '\tcase %s:\n\t\treturn (%s_policies);\n' "$ph" "$lower"
  done
  printf '\t}\n'
  lower=$(printf '%s' "${last_ph#PHASE_}" | tr '[:upper:]' '[:lower:]')
  printf '\treturn (%s_policies);\n}\n' "$lower"
}

#@help _stage_foundation_check1
# @command stage foundation check <stage>
# @summary Sharp re-verification of every bound phase right before emission: phases still in the enum, every policy chain complete and in the checkout's catalog (the world may have drifted)
# @group   foundation
# @see     stage foundation make
#@end
_stage_foundation_check1() {
  local name="$1" d="$ELEBAKE_BASE/stage/$1" loc f ph p msg phases=0 bindings=0
  resolve_item stage "$name" strict >/dev/null || {
    generate_error "stage foundation check: unknown stage '$name'"; return 0; }
  loc=$(catalog_dir "$name") || {
    generate_error "stage foundation check: no worktree (stage checkout $name <ref> first)"; return 0; }
  for f in "$d"/phases/*; do
    [ -f "$f" ] || continue
    ph=$(basename "$f")
    phases=$((phases + 1))
    phase_in_catalog "$name" "$ph" || {
      generate_error "stage foundation check: bound phase '$ph' is not in this checkout's enum"; return 0; }
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      bindings=$((bindings + 1))
      msg=$(check_policy_chain "$loc" "$p") || {
        generate_error "stage foundation check: $ph/$p: $msg"; return 0; }
    done < "$f"
  done
  # An exposed command answers its caller (unlike the internal check
  # terminals, which stay silent batch building blocks): the count makes
  # the message informative, not an echo.
  if [ "$bindings" -gt 0 ]; then
    emit_note "foundation check ok: $bindings binding(s) across $phases phase(s), every chain in this checkout's catalog"
  else
    emit_note "foundation check: nothing bound yet (stage phase policy add)"
  fi
}

#@help _stage_foundation_make1
# @command stage foundation make <stage>
# @summary Generate foundation.c from the bound policies into the worktree (generated-only file; check first — this terminal renders what the records say)
# @group   foundation
# @example elebake stage foundation make smoke1
# @see     stage foundation check
# @see     stage foundation report
#@end
_stage_foundation_make1() {
  local name="$1" loc target
  resolve_item stage "$name" strict >/dev/null || {
    generate_error "stage foundation make: unknown stage '$name'"; return 0; }
  loc=$(catalog_dir "$name") || {
    generate_error "stage foundation make: no worktree (stage checkout $name <ref> first)"; return 0; }
  target="$loc/foundation/foundation.c"
  printf '%s\n' "$MODIFY_DIR_CREATE '$loc/foundation'"
  printf '%s\n' "cat > '$target' <<'FOUNDATION_C_EOF'"
  render_foundation_c "$name"
  printf '%s\n' "FOUNDATION_C_EOF"
  emit_note "foundation.c generated -> $target"
}

#@help _stage_foundation_report1
# @command stage foundation report <stage>
# @summary Summarize the foundation of a stage: bound phases, their policies, the referenced gates/claims and the emission target
# @group   foundation
#@end
_stage_foundation_report1() {
  local name="$1" d="$ELEBAKE_BASE/stage/$1" loc policies gates macros f ph
  resolve_item stage "$name" strict >/dev/null || {
    generate_error "stage foundation report: unknown stage '$name'"; return 0; }
  loc=$(catalog_dir "$name") || {
    generate_error "stage foundation report: no worktree (stage checkout $name <ref> first)"; return 0; }
  catalog_header "$name" "foundation report"
  policies=$(foundation_bound_policies "$name" "$loc")
  gates=$(foundation_gates_of $policies)
  macros=$(foundation_macros_of $gates)
  for ph in $(enum_phases "$loc"); do
    printf '#   %s\n' "$ph"
    if [ -s "$d/phases/$ph" ]; then
      sed 's/^/#       policy: /' "$d/phases/$ph"
    else
      printf '#       (no policies bound)\n'
    fi
  done
  printf '#   gates:%s\n'  "${gates:- (none)}"
  printf '#   macros:%s\n' "$(printf ' %s' $macros)"
  printf '#   target: %s\n' "$loc/foundation/foundation.c"
}

#@help ___stage_foundation1
# @command stage foundation <stage>
# @summary The foundation batch: check stage -> foundation check -> foundation make -> foundation report
# @group   foundation
# @example elebake stage foundation smoke1
#@end
___stage_foundation1() {
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage foundation check '$1'"
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage foundation make '$1'"
  printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage foundation report '$1'"
}
